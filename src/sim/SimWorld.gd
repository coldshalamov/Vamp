## SimWorld.gd -- deterministic level/district state.
##
## Pure data: tile collision, lighting anchors, spawn points, and named zones. The
## renderer reads this and draws it; gameplay systems use it for collision and line of
## sight. No scene tree, input, wall clock, or non-deterministic calls live here.
extends RefCounted
class_name SimWorld

enum Surface { NONE, BLOOD, FIRE, WATER, SUN, ELECTRIC, SHADOW, HAVEN }

var size: Vector2i = Vector2i(64, 40)
var tile_size: int = 32
var walls: PackedByteArray = PackedByteArray()
var surfaces: PackedByteArray = PackedByteArray()
var spawn_points: Array[Vector2] = []
var named_points: Dictionary = {}
var lights: Array[Dictionary] = []
var exit_zone: Rect2 = Rect2()
var haven_zone: Rect2 = Rect2()

func _init() -> void:
	_reset_arrays()

func load_vertical_slice() -> void:
	size = Vector2i(64, 40)
	tile_size = 32
	_reset_arrays()
	spawn_points.clear()
	named_points.clear()
	lights.clear()

	# Outer bounds.
	_set_wall_rect(0, 0, size.x, 1, true)
	_set_wall_rect(0, size.y - 1, size.x, 1, true)
	_set_wall_rect(0, 0, 1, size.y, true)
	_set_wall_rect(size.x - 1, 0, 1, size.y, true)

	# Two city-block buildings with alleys between them.
	_set_wall_rect(8, 6, 10, 11, true)
	_set_wall_rect(24, 4, 9, 12, true)
	_set_wall_rect(42, 7, 12, 10, true)
	_set_wall_rect(10, 24, 13, 9, true)
	_set_wall_rect(34, 24, 13, 8, true)

	# Shadowed alleys and a safe haven.
	_set_surface_rect(18, 7, 5, 10, Surface.SHADOW)
	_set_surface_rect(33, 8, 7, 7, Surface.SHADOW)
	_set_surface_rect(26, 30, 8, 5, Surface.HAVEN)
	haven_zone = Rect2(Vector2(26 * tile_size, 30 * tile_size), Vector2(8 * tile_size, 5 * tile_size))
	exit_zone = Rect2(Vector2(58 * tile_size, 18 * tile_size), Vector2(4 * tile_size, 6 * tile_size))

	named_points = {
		"player": Vector2(160, 576),
		"civilian": Vector2(245, 576),
		"witness": Vector2(330, 560),
		"enemy": Vector2(560, 560),
		"heat_search": Vector2(335, 560),
		"exit": exit_zone.get_center(),
		"haven": haven_zone.get_center()
	}
	spawn_points = [
		named_points["player"],
		named_points["civilian"],
		named_points["witness"],
		named_points["enemy"]
	]

	lights = [
		{ "id": "street_neon_west", "pos": Vector2(220, 505), "radius": 190.0, "color": Color(0.75, 0.08, 0.18, 1.0), "energy": 0.8 },
		{ "id": "streetlamp_center", "pos": Vector2(520, 520), "radius": 220.0, "color": Color(1.0, 0.78, 0.45, 1.0), "energy": 0.7 },
		{ "id": "haven_sign", "pos": haven_zone.get_center(), "radius": 150.0, "color": Color(0.45, 0.65, 1.0, 1.0), "energy": 0.6 }
	]

func world_size() -> Vector2:
	return Vector2(size.x * tile_size, size.y * tile_size)

func is_solid(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return true
	return walls[_idx(cell)] != 0

func surface_at(world_pos: Vector2) -> int:
	var cell := world_to_cell(world_pos)
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return Surface.NONE
	return int(surfaces[_idx(cell)])

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / tile_size), floori(world_pos.y / tile_size))

func is_blocked_world(world_pos: Vector2, radius: float = 0.0) -> bool:
	if radius <= 0.0:
		return is_solid(world_to_cell(world_pos))
	var samples := [
		world_pos,
		world_pos + Vector2(radius, 0),
		world_pos + Vector2(-radius, 0),
		world_pos + Vector2(0, radius),
		world_pos + Vector2(0, -radius)
	]
	for p in samples:
		if is_solid(world_to_cell(p)):
			return true
	return false

func resolve_motion(from_pos: Vector2, to_pos: Vector2, radius: float) -> Vector2:
	var bounds := world_size()
	var clamped := Vector2(
		clamp(to_pos.x, radius, bounds.x - radius),
		clamp(to_pos.y, radius, bounds.y - radius)
	)
	if not is_blocked_world(clamped, radius):
		return clamped
	var x_only := Vector2(clamped.x, from_pos.y)
	if not is_blocked_world(x_only, radius):
		return x_only
	var y_only := Vector2(from_pos.x, clamped.y)
	if not is_blocked_world(y_only, radius):
		return y_only
	return from_pos

func segment_clear(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var steps: int = max(1, ceili(dist / float(tile_size / 2)))
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / float(steps))
		if is_blocked_world(p, 2.0):
			return false
	return true

func nearest_open_around(center: Vector2, min_radius: float, max_radius: float, ordinal: int) -> Vector2:
	var tries := 32
	for i in range(tries):
		var k := i + ordinal
		var angle := float((k * 137) % 360) * PI / 180.0
		var radius := lerpf(min_radius, max_radius, float((k * 37) % 100) / 99.0)
		var p := center + Vector2(cos(angle), sin(angle)) * radius
		if not is_blocked_world(p, 12.0):
			return p
	return named_points.get("enemy", center)

func is_in_exit(pos: Vector2) -> bool:
	return exit_zone.has_point(pos)

func is_in_haven(pos: Vector2) -> bool:
	return haven_zone.has_point(pos)

func _reset_arrays() -> void:
	walls = PackedByteArray()
	surfaces = PackedByteArray()
	walls.resize(size.x * size.y)
	surfaces.resize(size.x * size.y)

func _idx(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x

func _set_wall_rect(x: int, y: int, w: int, h: int, solid: bool) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < size.x and yy < size.y:
				walls[_idx(Vector2i(xx, yy))] = 1 if solid else 0

func _set_surface_rect(x: int, y: int, w: int, h: int, surface: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < size.x and yy < size.y:
				surfaces[_idx(Vector2i(xx, yy))] = surface
