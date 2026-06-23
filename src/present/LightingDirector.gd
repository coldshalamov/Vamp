## LightingDirector.gd — dynamic Light2D rig: readable moonlit night + a travelling
## predator follow-light, plus authored world lights (neon, streetlamps, haven sign).
##
## The old version flooded the scene to near-black (#08080c) with 3 tiny lights and NO player
## light, so everything was a black void. We use a readable night ambient and a warm follow-light
## so the world is legible AND moody (chiaroscuro: bright pool around the predator, dark beyond).
## Owned by the vision-capable frontend agent.
extends Node2D
class_name LightingDirector

# Moonlit night: dark enough to read as night, bright enough to SEE the textured street.
# (The old #08080c made the whole frame a void.) Lights ADD warm pools on top of this.
const AMBIENT_NIGHT := Color(0.22, 0.25, 0.31)

var _lights: Array[PointLight2D] = []
var _modulate: CanvasModulate = null
var _player_light: PointLight2D = null


func setup(world: SimWorld) -> void:
	_modulate = CanvasModulate.new()
	_modulate.color = AMBIENT_NIGHT
	add_child(_modulate)

	# Authored world lights (neon / streetlamp / haven sign).
	for light_data in world.lights:
		var light := _make_light(
			light_data["pos"],
			int(light_data["radius"]),
			light_data["color"],
			float(light_data["energy"]) * 1.4)
		add_child(light)
		_lights.append(light)

	# The predator's travelling pool of light — a tighter, brighter pool for real chiaroscuro
	# (bright around the predator, moody dark beyond) instead of a flat wash over everything.
	_player_light = _make_light(Vector2.ZERO, 240, Color(0.95, 0.9, 0.86), 1.35)
	add_child(_player_light)


func _process(_delta: float) -> void:
	if _player_light != null and Sim != null and Sim.player != null:
		_player_light.position = Sim.player.pos


func _make_light(pos: Vector2, radius: int, color: Color, energy: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.position = pos
	light.texture = _make_light_texture(radius)
	light.color = color
	light.energy = energy
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.shadow_enabled = false  # no occluders yet; enable when walls become LightOccluder2D
	return light


func _make_light_texture(radius: int) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = radius * 2
	texture.height = radius * 2
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var gradient := Gradient.new()
	# Soft, slightly front-loaded falloff: bright core, gentle edge — reads as a real light pool.
	gradient.add_point(0.0, Color(1, 1, 1, 1))
	gradient.add_point(0.55, Color(1, 1, 1, 0.45))
	gradient.add_point(1.0, Color(1, 1, 1, 0))
	texture.gradient = gradient
	return texture
