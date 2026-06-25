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
# Blood Grammar — the SPILL atom: a mutable, deterministic blood-depth layer (0-255 per cell).
# Spilled when blood is shed (hits, kills, feeds); dries over time. The substrate the rest of the
# Blood Grammar (command/react/drink) will read. Integer-only, no RNG, so replay stays bit-exact.
var blood: PackedByteArray = PackedByteArray()
var _wet: Dictionary = {}   # cell index -> true, so decay/render touch only wet cells
# Blood Grammar REACT atom: a FIRE layer (burn-ticks per cell). Fire spreads through spilled blood,
# burns whoever stands in it, and consumes the blood as fuel. Integer-only, deterministic.
var fire: PackedByteArray = PackedByteArray()
var _burning: Dictionary = {}   # cell index -> true
var spawn_points: Array[Vector2] = []
var named_points: Dictionary = {}
var lights: Array[Dictionary] = []
var roads: PackedByteArray = PackedByteArray()
var districts: Array[Dictionary] = []
var pois: Dictionary = {}
var encounter_points: Array[Dictionary] = []
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
	encounter_points.clear()
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

	## CITY GRID — a navigable street network, not a parking lot.
	##
	## Two arterials carve the city into quadrants and double as the load-bearing corridors the
	## tests walk: the MIDWAY (rows 17-20, the E-W main street the player sprints east to escape
	## along) and the SPINE (cols 30-33, the N-S avenue). They cross at the central PLAZA
	## (cols 28-35, rows 16-22) — the open arena where all four districts meet. District character
	## is expressed through building geometry: Old Town irregular & alleyed, Docks open & exposed,
	## Red Row dense & neon-lit, Financial gridded & orderly. Tiles referenced as (col, row).

	# --- OLD TOWN (NW): irregular gothic blocks, winding alleys, easy stealth ---
	_set_wall_rect(3, 2, 6, 5, true)      # OT1 chapel row
	_set_wall_rect(12, 2, 5, 4, true)     # OT2 townhouse
	_set_wall_rect(20, 2, 7, 5, true)     # OT3 guildhall (abuts the Docks border)
	_set_wall_rect(3, 8, 4, 7, true)      # OT4 west tenement
	_set_wall_rect(8, 8, 3, 3, true)      # OT5 kiosk
	_set_wall_rect(15, 8, 4, 3, true)     # OT6 row house
	_set_wall_rect(20, 8, 4, 2, true)     # OT7 guard post (stops at row 9 — leaves (22,10) walkable)
	# OT8: the sightline occluder. It blocks LOS from the hunter perch at (22,10) down to the
	# player spawn at (5,18) so the AI must pathfind around, while staying short of row 15 so the
	# maw/physics tiles (18,15) and (21,15) stay open. A path still exists via the row-16 lip.
	_set_wall_rect(17, 11, 7, 4, true)    # OT8 cloister wall (rows 11-14)

	# --- DOCKS (NE): big open warehouses, wide gaps, long sight lines, exposed ---
	_set_wall_rect(36, 2, 10, 5, true)    # DK1 north warehouse
	_set_wall_rect(48, 7, 12, 6, true)    # DK2 main warehouse (the waterfront landmark)
	_set_wall_rect(36, 8, 8, 7, true)     # DK3 bonded store
	_set_wall_rect(46, 14, 12, 2, true)   # DK4 low quay shed (stops at row 15 — row 16 stays open)

	# --- RED ROW (SW): dense small buildings, narrow streets, neon nightlife ---
	_set_wall_rect(3, 21, 4, 2, true)     # RR1 bar (north face of the strip)
	_set_wall_rect(9, 21, 4, 2, true)     # RR2 club
	_set_wall_rect(15, 21, 3, 2, true)    # RR3 dive
	_set_wall_rect(20, 21, 4, 2, true)    # RR4 cabaret
	_set_wall_rect(3, 27, 3, 3, true)     # RR5 lodging
	_set_wall_rect(8, 27, 4, 4, true)     # RR6 tenement
	_set_wall_rect(14, 27, 3, 3, true)    # RR7 flop house
	_set_wall_rect(3, 31, 5, 4, true)     # RR8 stack
	_set_wall_rect(10, 32, 4, 3, true)    # RR9 annexe
	_set_wall_rect(15, 30, 3, 5, true)    # RR10 narrow row
	_set_wall_rect(20, 31, 4, 4, true)    # RR11 corner block (col 24 left open as the haven approach)

	# --- FINANCIAL (SE): uniform grid blocks, wide straight streets, orderly ---
	_set_wall_rect(36, 24, 6, 6, true)    # FN1 office tower
	_set_wall_rect(44, 27, 6, 5, true)    # FN2 bank (south of the exit corridor)
	_set_wall_rect(52, 24, 7, 6, true)    # FN3 corporate block
	_set_wall_rect(36, 31, 7, 6, true)    # FN4 plaza tower
	_set_wall_rect(46, 33, 7, 5, true)    # FN5 exchange
	_set_wall_rect(54, 31, 6, 6, true)    # FN6 atrium

	# --- HAVEN COURTYARD (cols 26-34, rows 30-35): enclosed, 2 entrances, defensible ---
	# Walls ring the courtyard leaving a north gate (col 30, off the Spine) and a west gate
	# (row 32, off the Red Row approach). Interior stays open and is marked HAVEN surface.
	_set_wall_rect(25, 29, 5, 1, true)    # top wall, west half (gap at col 30 = north gate)
	_set_wall_rect(31, 29, 5, 1, true)    # top wall, east half
	_set_wall_rect(25, 30, 1, 2, true)    # left wall, upper (gap at row 32 = west gate)
	_set_wall_rect(25, 33, 1, 3, true)    # left wall, lower
	_set_wall_rect(35, 30, 1, 6, true)    # right wall
	_set_wall_rect(25, 36, 11, 1, true)   # bottom wall

	# --- SURFACES: shadowed alleys (stealth zones) + the haven floor ---
	_set_surface_rect(7, 8, 1, 6, Surface.SHADOW)     # OT alley behind OT4
	_set_surface_rect(11, 8, 4, 3, Surface.SHADOW)    # OT gap between OT5 and OT6
	_set_surface_rect(24, 11, 2, 4, Surface.SHADOW)   # OT alley east of OT8 -> towards Docks
	_set_surface_rect(4, 15, 5, 1, Surface.SHADOW)    # dark lip just north of the player spawn
	_set_surface_rect(7, 21, 2, 2, Surface.SHADOW)    # RR alley between RR1 and RR2
	_set_surface_rect(13, 21, 2, 2, Surface.SHADOW)   # RR alley between RR2 and RR3
	_set_surface_rect(18, 21, 2, 2, Surface.SHADOW)   # RR alley between RR3 and RR4
	_set_surface_rect(6, 27, 2, 3, Surface.SHADOW)    # RR alley between RR5 and RR6
	_set_surface_rect(12, 27, 2, 3, Surface.SHADOW)   # RR alley between RR6 and RR7
	_set_surface_rect(44, 8, 4, 6, Surface.SHADOW)    # Docks loading gap (the one dark spot)
	_set_surface_rect(26, 30, 8, 5, Surface.HAVEN)    # the safe haven floor

	# --- ROADS: visual treatment only (never blocks movement) ---
	_set_road_rect(1, 17, 62, 4, true)    # MIDWAY: the E-W main street, full width
	_set_road_rect(30, 1, 4, 28, true)    # SPINE: the N-S avenue, down to the haven gate
	_set_road_rect(1, 23, 24, 4, true)    # Red Row nightlife strip (wide sidewalk)
	_set_road_rect(1, 30, 24, 1, true)    # Red Row south lane
	_set_road_rect(32, 7, 4, 9, true)     # Docks waterfront drive
	_set_road_rect(46, 13, 16, 1, true)   # Docks quay road
	_set_road_rect(36, 24, 27, 1, true)   # Financial east-west boulevard
	_set_road_rect(36, 30, 27, 1, true)   # Financial mid boulevard
	_set_road_rect(36, 37, 27, 1, true)   # Financial south boulevard
	_set_road_rect(43, 24, 1, 13, true)   # Financial vertical: col 43
	_set_road_rect(50, 24, 2, 13, true)   # Financial vertical: cols 50-51
	_set_road_rect(60, 24, 2, 13, true)   # Financial vertical: cols 60-61

	haven_zone = Rect2(Vector2(26 * tile_size, 30 * tile_size), Vector2(8 * tile_size, 5 * tile_size))
	exit_zone = Rect2(Vector2(44 * tile_size, 18 * tile_size), Vector2(18 * tile_size, 6 * tile_size))

	# World-space cell centres for the points below: (col,row) -> ((col+0.5)*32, (row+0.5)*32).
	var plaza := _cell_center(Vector2i(31, 19))
	var waterfront := _cell_center(Vector2i(50, 4))
	var strip := _cell_center(Vector2i(12, 25))
	var alley := _cell_center(Vector2i(12, 9))
	var bloodbank := _cell_center(Vector2i(13, 30))
	var shop := _cell_center(Vector2i(46, 10))
	var mission_board := _cell_center(Vector2i(31, 16))
	var rr_strip_enc := _cell_center(Vector2i(19, 25))
	var docks_quay_enc := _cell_center(Vector2i(46, 13))
	var financial_enc := _cell_center(Vector2i(60, 30))

	# named_points: the first seven are test fixtures (coordinates are load-bearing — the slice
	# script and many unit tests spawn relative to them). Thematic extras are appended for patrol
	# anchors and are safe to leave unread.
	named_points = {
		"player": Vector2(160, 576),
		"civilian": Vector2(245, 576),
		"witness": Vector2(330, 560),
		"enemy": Vector2(560, 560),
		"heat_search": Vector2(335, 560),
		"exit": exit_zone.get_center(),
		"haven": haven_zone.get_center(),
		"plaza": plaza,
		"waterfront": waterfront,
		"strip": strip,
		"alley": alley,
	}
	pois = {
		"bloodbank": bloodbank,
		"shop": shop,
		"haven": haven_zone.get_center(),
		"mission_board": mission_board,
	}
	encounter_points = [
		{ "template": "street_thugs", "pos": rr_strip_enc },
		{ "template": "gang_squad", "pos": docks_quay_enc },
		{ "template": "hunter_cell", "pos": financial_enc },
	]
	spawn_points = [
		named_points["player"],
		named_points["civilian"],
		named_points["witness"],
		named_points["enemy"],
		_cell_center(Vector2i(6, 18)),
		_cell_center(Vector2i(15, 18)),
		_cell_center(Vector2i(23, 17)),
		_cell_center(Vector2i(31, 17)),
		_cell_center(Vector2i(41, 21)),
		_cell_center(Vector2i(51, 21)),
		_cell_center(Vector2i(7, 25)),
		_cell_center(Vector2i(19, 26)),
		_cell_center(Vector2i(35, 28)),
		_cell_center(Vector2i(56, 17)),
		_cell_center(Vector2i(31, 6)),
		_cell_center(Vector2i(46, 7)),
		_cell_center(Vector2i(50, 4)),
		_cell_center(Vector2i(30, 21)),
		_cell_center(Vector2i(43, 30)),
		_cell_center(Vector2i(52, 30)),
		_cell_center(Vector2i(17, 28)),
		_cell_center(Vector2i(6, 28)),
	]

	# LIGHTS — strategic, not decorative. ~28 lights across the four districts.
	var amber := Color(1.0, 0.78, 0.45, 1.0)          # warm streetlamp glow
	var neon := Color(0.92, 0.10, 0.40, 1.0)          # crimson/magenta nightlife
	var flood := Color(0.72, 0.82, 1.0, 1.0)          # cold industrial white
	var haven_blue := Color(0.45, 0.65, 1.0, 1.0)     # haven sign
	lights = [
		# Streetlamps along the Midway and at the Plaza (intersections).
		{ "id": "lamp_mid_w1", "pos": _cell_center(Vector2i(10, 18)), "radius": 210.0, "color": amber, "energy": 0.7 },
		{ "id": "lamp_mid_w2", "pos": _cell_center(Vector2i(22, 18)), "radius": 210.0, "color": amber, "energy": 0.7 },
		{ "id": "lamp_plaza", "pos": _cell_center(Vector2i(31, 19)), "radius": 240.0, "color": amber, "energy": 0.85 },
		{ "id": "lamp_mid_e1", "pos": _cell_center(Vector2i(44, 18)), "radius": 210.0, "color": amber, "energy": 0.7 },
		{ "id": "lamp_mid_e2", "pos": _cell_center(Vector2i(56, 18)), "radius": 210.0, "color": amber, "energy": 0.7 },
		# Spine avenue lamps.
		{ "id": "lamp_spine_n", "pos": _cell_center(Vector2i(31, 8)), "radius": 200.0, "color": amber, "energy": 0.65 },
		{ "id": "lamp_spine_s", "pos": _cell_center(Vector2i(31, 25)), "radius": 200.0, "color": amber, "energy": 0.65 },
		# Plaza corner lamps.
		{ "id": "lamp_plaza_sw", "pos": _cell_center(Vector2i(28, 21)), "radius": 180.0, "color": amber, "energy": 0.6 },
		{ "id": "lamp_plaza_se", "pos": _cell_center(Vector2i(34, 21)), "radius": 180.0, "color": amber, "energy": 0.6 },
		{ "id": "lamp_strip_w", "pos": _cell_center(Vector2i(8, 25)), "radius": 190.0, "color": amber, "energy": 0.6 },
		# Neon signs on the Red Row nightlife strip (north face of the bars).
		{ "id": "neon_rr1", "pos": _cell_center(Vector2i(5, 23)), "radius": 130.0, "color": neon, "energy": 0.8 },
		{ "id": "neon_rr2", "pos": _cell_center(Vector2i(11, 23)), "radius": 130.0, "color": neon, "energy": 0.8 },
		{ "id": "neon_rr3", "pos": _cell_center(Vector2i(16, 23)), "radius": 130.0, "color": neon, "energy": 0.8 },
		{ "id": "neon_rr4", "pos": _cell_center(Vector2i(22, 23)), "radius": 130.0, "color": neon, "energy": 0.8 },
		# Neon on the deeper Red Row blocks.
		{ "id": "neon_rr6", "pos": _cell_center(Vector2i(10, 30)), "radius": 135.0, "color": neon, "energy": 0.75 },
		{ "id": "neon_rr7", "pos": _cell_center(Vector2i(15, 30)), "radius": 135.0, "color": neon, "energy": 0.75 },
		{ "id": "neon_rr9", "pos": _cell_center(Vector2i(12, 31)), "radius": 130.0, "color": neon, "energy": 0.7 },
		{ "id": "neon_rr11", "pos": _cell_center(Vector2i(22, 31)), "radius": 130.0, "color": neon, "energy": 0.7 },
		# Industrial floods on the Docks warehouses (cold, exposing).
		{ "id": "flood_dk1a", "pos": _cell_center(Vector2i(41, 7)), "radius": 230.0, "color": flood, "energy": 0.9 },
		{ "id": "flood_dk1b", "pos": _cell_center(Vector2i(40, 12)), "radius": 220.0, "color": flood, "energy": 0.85 },
		{ "id": "flood_dk2", "pos": _cell_center(Vector2i(54, 10)), "radius": 250.0, "color": flood, "energy": 0.95 },
		{ "id": "flood_dk3", "pos": _cell_center(Vector2i(50, 13)), "radius": 220.0, "color": flood, "energy": 0.85 },
		{ "id": "flood_quay", "pos": _cell_center(Vector2i(52, 15)), "radius": 210.0, "color": flood, "energy": 0.8 },
		{ "id": "flood_water", "pos": _cell_center(Vector2i(50, 4)), "radius": 240.0, "color": flood, "energy": 0.9 },
		# The haven sign — the one blue beacon, visible from the plaza.
		{ "id": "haven_sign", "pos": haven_zone.get_center(), "radius": 150.0, "color": haven_blue, "energy": 0.7 },
		# Financial boulevard lamps (orderly, even spacing).
		{ "id": "lamp_fn1", "pos": _cell_center(Vector2i(44, 24)), "radius": 200.0, "color": amber, "energy": 0.7 },
		{ "id": "lamp_fn2", "pos": _cell_center(Vector2i(56, 24)), "radius": 200.0, "color": amber, "energy": 0.7 },
		{ "id": "lamp_fn3", "pos": _cell_center(Vector2i(50, 37)), "radius": 200.0, "color": amber, "energy": 0.65 },
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
	blood = PackedByteArray()
	_wet = {}
	fire = PackedByteArray()
	_burning = {}
	walls.resize(size.x * size.y)
	surfaces.resize(size.x * size.y)
	roads.resize(size.x * size.y)
	blood.resize(size.x * size.y)
	fire.resize(size.x * size.y)


## REACT: ignite spilled blood within a radius (only cells that actually have blood to burn).
func ignite_radius(world_pos: Vector2, radius: float) -> int:
	var c0 := world_to_cell(world_pos)
	var cr: int = int(ceil(radius / float(tile_size)))
	var lit := 0
	for dy in range(-cr, cr + 1):
		for dx in range(-cr, cr + 1):
			var c := c0 + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
				continue
			var i := _idx(c)
			if walls[i] == 0 and blood[i] > 8:
				fire[i] = maxi(fire[i], 45 + blood[i] / 3)
				_burning[i] = true
				lit += 1
	return lit


func fire_at(world_pos: Vector2) -> int:
	var c := world_to_cell(world_pos)
	if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
		return 0
	return fire[_idx(c)]


func cell_index(world_pos: Vector2) -> int:
	return _idx(world_to_cell(world_pos))


## SPILL: deposit blood at a world position (a small pool: centre cell + 4-neighbours).
func spill_blood(world_pos: Vector2, amount: int) -> void:
	var c := world_to_cell(world_pos)
	_add_blood(c, amount)
	_add_blood(c + Vector2i(1, 0), amount / 3)
	_add_blood(c + Vector2i(-1, 0), amount / 3)
	_add_blood(c + Vector2i(0, 1), amount / 3)
	_add_blood(c + Vector2i(0, -1), amount / 3)


func _add_blood(c: Vector2i, amt: int) -> void:
	if amt <= 0 or c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
		return
	var i := _idx(c)
	if walls[i] != 0:
		return
	blood[i] = mini(255, blood[i] + amt)
	_wet[i] = true


func blood_at(world_pos: Vector2) -> int:
	var c := world_to_cell(world_pos)
	if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
		return 0
	return blood[_idx(c)]


## DRINK: pull up to `amount` depth out of the pool at a position. Returns how much was taken.
func siphon_blood(world_pos: Vector2, amount: int) -> int:
	var c := world_to_cell(world_pos)
	if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
		return 0
	var i := _idx(c)
	var take: int = mini(amount, blood[i])
	if take <= 0:
		return 0
	blood[i] -= take
	if blood[i] <= 0:
		_wet.erase(i)
	return take


## Dry the wet cells a notch (deterministic; iterates only wet cells). Call on a slow cadence.
func decay_blood() -> void:
	var dried: Array = []
	for i in _wet:
		var v: int = blood[i] - 1
		if v <= 0:
			v = 0
			dried.append(i)
		blood[i] = v
	for i in dried:
		_wet.erase(i)

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
