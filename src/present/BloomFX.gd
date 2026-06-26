## BloomFX.gd — fake additive bloom on authored light sources (no HDR-2D).
##
## GL Compatibility has no HDR 2D, so WorldEnvironment glow can't selectively bloom bright pixels.
## Instead we cheat it cheaply: drop ONE large, soft, ADDITIVE glow Sprite2D over each authored
## light/neon so lamps and signs visibly bleed. There is NO blur pass and NO per-frame work — the
## sprites are static (LightingDirector owns the actual Light2D rig and the moving follow-light; this
## seam is pure cosmetic bleed layered above the world, below the actors).
##
## Presentation-only: reads world.lights READ-ONLY (never writes), references NOTHING under src/sim
## or src/entities. Bounded by the authored light count (a handful), so it is effectively free after
## setup(). Build is one shared soft texture + one shared additive material + N scaled sprites.
extends Node2D
class_name BloomFX

# Glow sprite half-extent relative to the light's radius. ~1.4x so the bleed spills past the lit pool.
const GLOW_SCALE := 1.3
# Soft-radial texture resolution (one shared texture, scaled per light — small is plenty when blurred).
const TEX_SIZE := 64
# Additive overlap blows to white fast, so keep the per-light gain restrained: this reads as "bleed",
# not a blown highlight. Final modulate = color * (BASE_GAIN + ENERGY_GAIN * energy).
const BASE_GAIN := 0.075
const ENERGY_GAIN := 0.09
# Hard cap so a malformed world can never spawn an unbounded number of nodes (freeze-safe).
const MAX_GLOWS := 64

var _glows: Array[Sprite2D] = []


## Called by the integrator AFTER add_child(self) (note: opposite order to LightingDirector). All the
## work happens here so node-ordering never matters. `world` is intentionally UNTYPED — type-hinting
## SimWorld would reference a src/sim symbol, which this presentation seam must never do.
func setup(world) -> void:
	z_index = 15   # above the world/props, below the actors (z ~20)
	if world == null:
		return
	var lights = world.get("lights")
	if lights == null or not (lights is Array):
		return

	# One shared soft-alpha texture (genuinely transparent corners — see _glow_texture) and one shared
	# additive material. Every glow sprite reuses both; per-light variation is position/scale/modulate.
	var tex := _glow_texture(TEX_SIZE)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var half := float(TEX_SIZE) * 0.5
	for light_data in lights:
		if _glows.size() >= MAX_GLOWS:
			break
		if not (light_data is Dictionary):
			continue
		var pos: Vector2 = light_data.get("pos", Vector2.ZERO)
		var radius: float = float(light_data.get("radius", 0.0))
		if radius <= 0.0:
			continue
		var col: Color = light_data.get("color", Color(1, 1, 1, 1))
		var energy: float = float(light_data.get("energy", 1.0))

		var s := Sprite2D.new()
		s.texture = tex
		s.material = add_mat
		s.position = pos
		# Scale the shared texture so its half-extent ≈ GLOW_SCALE * radius (texture half-extent = half).
		s.scale = Vector2.ONE * ((radius * GLOW_SCALE) / half)
		# Boosted, alpha-1 additive tint: additive ignores alpha for "amount", so the RGB gain is the
		# knob. Restrained gain keeps overlaps from clipping straight to white.
		var gain: float = BASE_GAIN + ENERGY_GAIN * energy
		s.modulate = Color(col.r * gain, col.g * gain, col.b * gain, 1.0)
		add_child(s)
		_glows.append(s)


## A soft round glow with a genuinely transparent edge (per-pixel alpha falloff). GradientTexture2D
## FILL_RADIAL leaves opaque square corners unless tuned exactly, so we bake the disc directly to be
## safe — the rim feathers fully to alpha 0 and the core stays bright for a believable bleed.
func _glow_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	var r := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - c, float(y) - c).length() / r
			var a := clampf(1.0 - d, 0.0, 1.0)
			# Cube the falloff: a tight bright core that bleeds into a long, soft, fully-transparent rim.
			a = a * a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
