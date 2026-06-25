## SpellParticles.gd — per-discipline GPU particle spectacle on every spell cast.
##
## This ADDS real GPUParticles2D flair ON TOP of SpellFX's archetype line-art (both consume the same
## power.cast cue, in their own seams). SpellFX draws the unmistakable shape; this throws the matching
## MOTION of particles — a directional streak for PROJECTILE, a radial burst for NOVA, kicked-up debris
## for GROUND_AOE, a fan for CONE, a line origin->target for ENTITY_TARGET/TETHER, a backward speed
## smear for DASH, rising motes for SELF_BUFF, and a descending fall for DEBUFF. The discipline is
## already encoded in the payload's color hex, so we TINT by it.
##
## Presentation-only: subscribes to CueBus read-only, never touches Sim or Sim.rng. GL Compatibility
## note — emit_particle() is unsupported, so each burst is a POOLED one-shot GPUParticles2D re-fired
## with restart(); fixed pools bound the node + particle counts (freeze-safe). No _process: the GPU
## simulates the particles itself, so this file is just _ready (build) + _on_cue (fire).
##
## The cardinal pooling rule (GL Compat): ParticleProcessMaterials are SHARED resources, so we pool BY
## MOTION — each emitter is pre-assigned its motion material once at _ready and NEVER reassigned.
## Mutating process_material.color forces a particle reset and would clobber every concurrent cast, so
## per cast we mutate ONLY node-level state: position, rotation, modulate (the discipline tint), then
## restart(). The material color stays white and the color_ramp fades white->transparent (alpha only),
## leaving modulate as the single source of hue (a colored ramp would double-tint against modulate).
extends Node2D
class_name SpellParticles

# Two emitters per motion family, cycled — 7 families x 2 = 14 nodes, under the ~16 budget.
const POOL_PER := 2

# Motion families (the archetypes collapse onto these; tint + node transform do the rest).
const M_STREAK := "streak"     # PROJECTILE / DASH — directional smear along local +X
const M_RADIAL := "radial"     # NOVA — outward ring from origin
const M_DEBRIS := "debris"     # GROUND_AOE — grit kicked up off the target spot
const M_CONE := "cone"         # CONE — a fanned wedge along aim
const M_LINE := "line"         # ENTITY_TARGET / TETHER — a drawn line origin->target
const M_RISE := "rise"         # SELF_BUFF — motes rising off the body (no ground ring)
const M_FALL := "fall"         # DEBUFF — a brand descending onto the target

var _pools: Dictionary = {}    # family -> Array[GPUParticles2D]
var _idx: Dictionary = {}      # family -> next index to fire (round-robin)


func _ready() -> void:
	z_index = 53   # above SpellFX line-art (52) and ParticleFX (51), below the mood grade + HUD
	var dot := _dot_texture(16)
	# One shared material + one shared additive CanvasItemMaterial per family; emitters reuse them.
	var glow := _additive_material()
	_build_pool(M_STREAK, dot, glow, 16, 0.34, _streak_material())
	_build_pool(M_RADIAL, dot, glow, 22, 0.46, _radial_material())
	_build_pool(M_DEBRIS, dot, glow, 18, 0.60, _debris_material())
	_build_pool(M_CONE, dot, glow, 20, 0.42, _cone_material())
	_build_pool(M_LINE, dot, glow, 16, 0.40, _line_material())
	_build_pool(M_RISE, dot, glow, 14, 0.80, _rise_material())
	_build_pool(M_FALL, dot, glow, 14, 0.62, _fall_material())
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _build_pool(family: String, tex: Texture2D, glow: CanvasItemMaterial, count: int, life: float, mat: ParticleProcessMaterial) -> void:
	var arr: Array[GPUParticles2D] = []
	for i in range(POOL_PER):
		arr.append(_make_emitter(tex, glow, count, life, mat))
	_pools[family] = arr
	_idx[family] = 0


func _on_cue(event_id: String, payload: Dictionary) -> void:
	if event_id != "power.cast":
		return
	var origin: Vector2 = payload.get("origin", payload.get("pos", Vector2.ZERO))
	var target: Vector2 = payload.get("target_pos", origin)
	var aim: float = float(payload.get("aim_dir", 0.0))
	var tint := _parse_color(String(payload.get("color", "#c01028")))
	var arch := String(payload.get("archetype", "NOVA"))

	# Direction toward the aimed target, falling back to facing when the cast resolved to self
	# (mirrors SpellFX's guard so a self/buff cast still points somewhere sane).
	var to_target: Vector2 = target - origin
	var aim_to_target: float = to_target.angle() if to_target.length_squared() > 1.0 else aim

	match arch:
		"PROJECTILE":
			_fire(M_STREAK, origin, aim_to_target, tint)
		"DASH":
			# Speed smear trailing BEHIND the lunge — emit backward along -aim.
			_fire(M_STREAK, origin, aim + PI, tint)
		"NOVA":
			_fire(M_RADIAL, origin, 0.0, tint)
		"GROUND_AOE":
			_fire(M_DEBRIS, target, 0.0, tint)
		"CONE":
			_fire(M_CONE, origin, aim, tint)
		"ENTITY_TARGET", "TETHER":
			_fire(M_LINE, origin, aim_to_target, tint)
		"SELF_BUFF":
			_fire(M_RISE, origin, 0.0, tint)
		"DEBUFF":
			_fire(M_FALL, target, 0.0, tint)
		_:
			# Unknown archetype still shows something — a radial burst at the caster.
			_fire(M_RADIAL, origin, 0.0, tint)


## Fire the next emitter in a family's pool. Only node-level state is touched (never the shared
## material), so concurrent casts in the same family don't disturb each other's tint.
func _fire(family: String, pos: Vector2, rot: float, tint: Color) -> void:
	var pool: Array = _pools.get(family, [])
	if pool.is_empty():
		return
	var i: int = int(_idx[family])
	var p: GPUParticles2D = pool[i]
	p.position = pos
	p.rotation = rot
	p.modulate = tint
	p.restart()
	_idx[family] = (i + 1) % pool.size()


func _make_emitter(tex: Texture2D, glow: CanvasItemMaterial, count: int, life: float, mat: ParticleProcessMaterial) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.texture = tex
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0       # whole burst fires at once
	p.emitting = false
	p.local_coords = false      # particles keep simulating in world space after the emitter moves
	p.process_material = mat
	p.material = glow           # additive blend — reads as energy/glow against the night grade
	add_child(p)
	return p


# --- particle process materials (one shared instance per motion family; color stays WHITE) ---

## A tight, fast directional smear along local +X (the node's rotation aims it). PROJECTILE + DASH.
func _streak_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 3.0
	m.direction = Vector3(1.0, 0.0, 0.0)
	m.spread = 12.0
	m.initial_velocity_min = 260.0
	m.initial_velocity_max = 520.0
	m.damping_min = 120.0
	m.damping_max = 300.0
	m.scale_min = 0.14
	m.scale_max = 0.42
	m.color = Color(1, 1, 1, 1)
	m.color_ramp = _alpha_ramp(0.95)
	return m


## A radial outward ring from origin (no preferred direction). NOVA.
func _radial_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 6.0
	m.direction = Vector3(1.0, 0.0, 0.0)
	m.spread = 180.0            # full ring outward in every direction
	m.initial_velocity_min = 180.0
	m.initial_velocity_max = 380.0
	m.damping_min = 90.0
	m.damping_max = 220.0
	m.scale_min = 0.18
	m.scale_max = 0.5
	m.color = Color(1, 1, 1, 1)
	m.color_ramp = _alpha_ramp(0.9)
	return m


## Grit kicked UP and out off the target spot, then settling under gravity. GROUND_AOE.
func _debris_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 10.0
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 65.0
	m.initial_velocity_min = 120.0
	m.initial_velocity_max = 300.0
	m.gravity = Vector3(0.0, 540.0, 0.0)   # thrown up, falls back down
	m.damping_min = 30.0
	m.damping_max = 90.0
	m.scale_min = 0.2
	m.scale_max = 0.7
	m.color = Color(1, 1, 1, 1)
	m.color_ramp = _alpha_ramp(0.85)
	return m


## A fanned wedge along local +X (node rotation = aim). Fixed spread approximates the cast arc —
## arc can't vary per cast without mutating the shared material. CONE.
func _cone_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 4.0
	m.direction = Vector3(1.0, 0.0, 0.0)
	m.spread = 38.0            # the fan half-angle (fixed; SpellFX owns the exact arc shape)
	m.initial_velocity_min = 180.0
	m.initial_velocity_max = 360.0
	m.damping_min = 80.0
	m.damping_max = 200.0
	m.scale_min = 0.18
	m.scale_max = 0.52
	m.color = Color(1, 1, 1, 1)
	m.color_ramp = _alpha_ramp(0.9)
	return m


## A drawn line of particles streaming along local +X (node rotation = origin->target). The
## elongated emission box gives it length; particles drift forward and fade. ENTITY_TARGET / TETHER.
func _line_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(150.0, 3.0, 1.0)   # long, thin — laid along +X before rotation
	m.direction = Vector3(1.0, 0.0, 0.0)
	m.spread = 6.0
	m.initial_velocity_min = 60.0
	m.initial_velocity_max = 150.0
	m.damping_min = 60.0
	m.damping_max = 160.0
	m.scale_min = 0.14
	m.scale_max = 0.4
	m.color = Color(1, 1, 1, 1)
	m.color_ramp = _alpha_ramp(0.9)
	return m


## Motes rising off the body, no ground component (negative gravity = lift). SELF_BUFF.
func _rise_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 14.0
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 25.0
	m.initial_velocity_min = 30.0
	m.initial_velocity_max = 80.0
	m.gravity = Vector3(0.0, -60.0, 0.0)   # gentle lift, so motes climb and never paint a ring
	m.damping_min = 20.0
	m.damping_max = 60.0
	m.scale_min = 0.16
	m.scale_max = 0.42
	m.color = Color(1, 1, 1, 1)
	m.color_ramp = _alpha_ramp(0.85)
	return m


## A brand descending onto the marked target (spawns above, falls down). DEBUFF.
func _fall_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(20.0, 4.0, 1.0)
	m.direction = Vector3(0.0, -1.0, 0.0)   # initial flick upward, gravity drags them down onto target
	m.spread = 30.0
	m.initial_velocity_min = 20.0
	m.initial_velocity_max = 70.0
	m.gravity = Vector3(0.0, 420.0, 0.0)
	m.damping_min = 30.0
	m.damping_max = 80.0
	m.scale_min = 0.16
	m.scale_max = 0.46
	m.color = Color(1, 1, 1, 1)
	m.color_ramp = _alpha_ramp(0.85)
	return m


# --- texture / ramp helpers ---

## A soft round dot with a genuinely transparent edge (per-pixel alpha falloff). GradientTexture2D
## FILL_RADIAL leaves opaque square corners, so particles read as hard tinted squares — this
## guarantees a feathered circle. (Mirrors ParticleFX._dot_texture.)
func _dot_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	var r := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - c, float(y) - c).length() / r
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a   # solid core, feathered rim
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


## A WHITE -> transparent alpha-only ramp. Kept white so the discipline hue comes solely from the
## emitter's modulate (a colored ramp would multiply against modulate and double-tint).
func _alpha_ramp(start_alpha: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, start_alpha))
	g.set_color(1, Color(1, 1, 1, 0.0))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## Additive blend — particle energy/glow reads against the dark night grade. Shared across emitters.
func _additive_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _parse_color(hex: String) -> Color:
	if hex.is_empty():
		return Color("#c01028")
	return Color(hex)
