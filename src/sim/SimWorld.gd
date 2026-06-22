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
var roads: PackedByteArray = PackedByteArray()
var districts: Array[Dictionary] = []
var pois: Dictionary = {}
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
	pois.clear()
	districts = [
		{ "id": "old_town", "name": "Old Town", "rect": Rect2(Vector2(0, 0), Vector2(1024, 640)), "danger": 0.2 },
		{ "id": "docks", "name": "Docks", "rect": Rect2(Vector2(1024, 0), Vector2(1024, 640)), "danger": 0.45 },
		{ "id": "red_row", "name": "Red Row", "rect": Rect2(Vector2(0, 640), Vector2(1024, 640)), "danger": 0.3 },
		{ "id": "financial", "name": "Financial District", "rect": Rect2(Vector2(1024, 640), Vector2(1024, 640)), "danger": 0.55 },
	]

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
	_set_road_rect(1, 17, 62, 6, true)
	_set_road_rect(1, 34, 62, 4, true)
	_set_road_rect(2, 1, 5, 38, true)
	_set_road_rect(55, 1, 6, 38, true)
	haven_zone = Rect2(Vector2(26 * tile_size, 30 * tile_size), Vector2(8 * tile_size, 5 * tile_size))
	exit_zone = Rect2(Vector2(44 * tile_size, 18 * tile_size), Vector2(18 * tile_size, 6 * tile_size))

	named_points = {
		"player": Vector2(160, 576),
		"civilian": Vector2(245, 576),
		"witness": Vector2(330, 560),
		"enemy": Vector2(560, 560),
		"heat_search": Vector2(335, 560),
		"exit": exit_zone.get_center(),
		"haven": haven_zone.get_center()
	}
	pois = {
		"bloodbank": Vector2(420, 640),
		"shop": Vector2(735, 675),
		"haven": haven_zone.get_center(),
		"mission_board": Vector2(185, 640),
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

func is_road_world(world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos)
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return false
	return roads[_idx(cell)] != 0 and not is_solid(cell)

func district_at(world_pos: Vector2) -> Dictionary:
	for district in districts:
		if (district["rect"] as Rect2).has_point(world_pos):
			return district
	return {}

func poi_pos(poi_id: String) -> Vector2:
	return pois.get(poi_id, named_points.get("player", Vector2.ZERO))

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

func find_path(start_pos: Vector2, target_pos: Vector2, max_expand: int = 2500) -> Array[Vector2]:
	var start := world_to_cell(start_pos)
	var goal := world_to_cell(target_pos)
	if is_solid(start):
		return []
	if is_solid(goal):
		var snap := nearest_walkable_cell(goal, 4)
		if snap == Vector2i(-1, -1):
			return []
		goal = snap
	var open: Array[Vector2i] = [start]
	var came: Dictionary = {}
	var g_score: Dictionary = { start: 0.0 }
	var closed: Dictionary = {}
	var expanded := 0
	while not open.is_empty() and expanded < max_expand:
		open.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return float(g_score.get(a, 999999.0)) + _path_heuristic(a, goal) < float(g_score.get(b, 999999.0)) + _path_heuristic(b, goal)
		)
		var cur: Vector2i = open.pop_front()
		if cur == goal:
			return _reconstruct_path(came, cur)
		closed[cur] = true
		expanded += 1
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var next: Vector2i = cur + off
			if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y or is_solid(next) or closed.has(next):
				continue
			if off.x != 0 and off.y != 0 and (is_solid(Vector2i(cur.x + off.x, cur.y)) or is_solid(Vector2i(cur.x, cur.y + off.y))):
				continue
			var step := 1.414 if off.x != 0 and off.y != 0 else 1.0
			var new_g: float = float(g_score.get(cur, 999999.0)) + step
			if new_g < float(g_score.get(next, 999999.0)):
				came[next] = cur
				g_score[next] = new_g
				if not open.has(next):
					open.append(next)
	return []

func nearest_walkable_cell(cell: Vector2i, radius: int) -> Vector2i:
	for d in range(1, radius + 1):
		for y in range(cell.y - d, cell.y + d + 1):
			for x in range(cell.x - d, cell.x + d + 1):
				if abs(x - cell.x) != d and abs(y - cell.y) != d:
					continue
				var p := Vector2i(x, y)
				if x >= 0 and y >= 0 and x < size.x and y < size.y and not is_solid(p):
					return p
	return Vector2i(-1, -1)

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
	roads = PackedByteArray()
	walls.resize(size.x * size.y)
	surfaces.resize(size.x * size.y)
	roads.resize(size.x * size.y)

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

func _set_road_rect(x: int, y: int, w: int, h: int, road: bool) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < size.x and yy < size.y:
				roads[_idx(Vector2i(xx, yy))] = 1 if road else 0

func _path_heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: int = abs(a.x - b.x)
	var dy: int = abs(a.y - b.y)
	return float(dx + dy) + (1.414 - 2.0) * float(min(dx, dy))

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * float(tile_size), (float(cell.y) + 0.5) * float(tile_size))

func _reconstruct_path(came: Dictionary, cur: Vector2i) -> Array[Vector2]:
	var cells: Array[Vector2i] = [cur]
	while came.has(cur):
		cur = came[cur]
		cells.append(cur)
	cells.reverse()
	var path: Array[Vector2] = []
	for cell in cells:
		path.append(_cell_center(cell))
	if path.size() <= 2:
		return path
	var simplified: Array[Vector2] = [path[0]]
	for i in range(1, path.size() - 1):
		var a := simplified[simplified.size() - 1]
		var b := path[i]
		var c := path[i + 1]
		var cross := (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
		if absf(cross) > 0.001:
			simplified.append(b)
	simplified.append(path[path.size() - 1])
	return simplified
