## LightingDirector.gd — dynamic Light2D rig: readable moonlit night + a travelling
## predator follow-light, plus authored world lights (neon, streetlamps, haven sign).
##
## The old version flooded the scene to near-black (#08080c) with 3 tiny lights and NO player
## light, so everything was a black void. We use a readable night ambient and a warm follow-light
## so the world is legible AND moody (chiaroscuro: bright pool around the predator, dark beyond).
## Owned by the vision-capable frontend agent.
extends Node2D
class_name LightingDirector

# Moonlit night. Lowered from 0.22 -> 0.16 (deliberate, rim-light-enabled): 0.22 was raised to fix a
# "black void" before characters had a rim. Now the rim shader keeps ACTORS readable in any light, so
# a darker base buys more noir chiaroscuro — kept at 0.16 (not deeper) so street/walls/props/blood
# stay legible. Lights ADD warm pools on top. Re-tune from a real playtest. See [[visual-night-legibility]].
const AMBIENT_NIGHT := Color(0.16, 0.18, 0.225)

var _lights: Array[PointLight2D] = []
var _occluders: Array[LightOccluder2D] = []
var _modulate: CanvasModulate = null
var _player_light: PointLight2D = null


func setup(world: SimWorld) -> void:
	_modulate = CanvasModulate.new()
	_modulate.color = AMBIENT_NIGHT
	add_child(_modulate)

	# Buildings become real shadow casters so the predator's follow-light pool is SHAPED by the
	# architecture: light spills down the street and stops at the wall, carving dark pockets behind
	# buildings (stealth) and bright pools in the open (danger). Light/shadow becomes tactical.
	_build_occluders(world)

	# Authored world lights (neon / streetlamp / haven sign). STATIC and many, so they do NOT cast
	# shadows — N shadow-casting lights against the occluders would cost FPS on the iGPU for little
	# gain (their shadows fall behind buildings, already dark). Only the predator's light casts.
	for light_data in world.lights:
		var light := _make_light(
			light_data["pos"],
			int(light_data["radius"]),
			light_data["color"],
			float(light_data["energy"]) * 1.4,
			false)
		add_child(light)
		_lights.append(light)

	# The predator's travelling pool of light — a tighter, brighter pool for real chiaroscuro. This
	# ONE light casts shadows, so the pool is carved by the architecture as the predator moves.
	_player_light = _make_light(Vector2.ZERO, 240, Color(0.95, 0.9, 0.86), 1.35, true)
	add_child(_player_light)


## Greedy-mesh the solid wall cells into a handful of large rectangular LightOccluder2D nodes.
## Per-cell occluders (2560 cells) would melt an Intel iGPU once a moving shadow-casting light is
## added; merging solid runs into maximal rectangles keeps the occluder edge count tiny.
func _build_occluders(world: SimWorld) -> void:
	var ts: int = world.tile_size
	var w: int = int(world.size.x)
	var h: int = int(world.size.y)
	var covered: Dictionary = {}
	var rects := 0
	for y in range(h):
		for x in range(w):
			var cell := Vector2i(x, y)
			if covered.has(cell) or not world.is_solid(cell):
				continue
			var x2 := x
			while x2 + 1 < w and world.is_solid(Vector2i(x2 + 1, y)) and not covered.has(Vector2i(x2 + 1, y)):
				x2 += 1
			var y2 := y
			var growing := true
			while growing and y2 + 1 < h:
				for xx in range(x, x2 + 1):
					var c := Vector2i(xx, y2 + 1)
					if not world.is_solid(c) or covered.has(c):
						growing = false
						break
				if growing:
					y2 += 1
			for yy in range(y, y2 + 1):
				for xx in range(x, x2 + 1):
					covered[Vector2i(xx, yy)] = true
			_add_occluder(Rect2(
				float(x * ts), float(y * ts),
				float((x2 - x + 1) * ts), float((y2 - y + 1) * ts)))
			rects += 1
	print("[LightingDirector] built ", rects, " merged wall occluders")


func _add_occluder(rect: Rect2) -> void:
	var poly := OccluderPolygon2D.new()
	poly.closed = true
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	poly.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	])
	var occ := LightOccluder2D.new()
	occ.occluder = poly
	occ.occluder_light_mask = 1
	add_child(occ)
	_occluders.append(occ)


func _process(_delta: float) -> void:
	if _player_light != null and Sim != null and Sim.player != null:
		_player_light.position = Sim.player.pos


func _make_light(pos: Vector2, radius: int, color: Color, energy: float, cast_shadow: bool = false) -> PointLight2D:
	var light := PointLight2D.new()
	light.position = pos
	light.texture = _make_light_texture(radius)
	light.color = color
	light.energy = energy
	light.blend_mode = Light2D.BLEND_MODE_ADD
	if cast_shadow:
		light.shadow_enabled = true
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		light.shadow_filter_smooth = 1.5
		light.shadow_item_cull_mask = 1
		light.shadow_color = Color(0.0, 0.0, 0.0, 0.92)
	else:
		light.shadow_enabled = false
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
