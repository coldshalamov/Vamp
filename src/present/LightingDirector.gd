## LightingDirector.gd — creates dynamic Light2D nodes from SimWorld light anchors.
##
## Adds a CanvasModulate for global darkness and spawns one PointLight2D per
## authored world light. Owned by the vision-capable frontend agent.
extends Node2D
class_name LightingDirector

const AMBIENT_DARKNESS := Color("#08080c")

var _lights: Array[PointLight2D] = []
var _modulate: CanvasModulate = null

func setup(world: SimWorld) -> void:
	# Global darkness so lights cut through.
	_modulate = CanvasModulate.new()
	_modulate.color = AMBIENT_DARKNESS
	add_child(_modulate)

	# Spawn lights from world data.
	for light_data in world.lights:
		var light := PointLight2D.new()
		light.position = light_data["pos"]
		light.texture = _make_light_texture(int(light_data["radius"]))
		light.color = light_data["color"]
		light.energy = light_data["energy"]
		light.shadow_enabled = true
		light.shadow_color = Color(0, 0, 0, 0.6)
		add_child(light)
		_lights.append(light)

func _make_light_texture(radius: int) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = radius * 2
	texture.height = radius * 2
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1))
	gradient.add_point(1.0, Color(1, 1, 1, 0))
	texture.gradient = gradient
	return texture
