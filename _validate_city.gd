## TEMPORARY city-layout validator. Run headless, then delete. Not part of the game/test suite.
extends SceneTree

func _init() -> void:
	var w := SimWorld.new()
	w.load_vertical_slice()
	var fails: Array[String] = []
	var tc := func(c: int, r: int) -> Vector2:
		return Vector2((float(c) + 0.5) * float(w.tile_size), (float(r) + 0.5) * float(w.tile_size))

	# 1. Every named_point on a walkable tile.
	for key in w.named_points.keys():
		if w.is_solid(w.world_to_cell(w.named_points[key])):
			fails.append("named_point '%s' at %s is inside a wall" % [key, w.named_points[key]])
	# 2. Every POI on a walkable tile.
	for key in w.pois.keys():
		if w.is_solid(w.world_to_cell(w.pois[key])):
			fails.append("poi '%s' at %s is inside a wall" % [key, w.pois[key]])
	# 3. No spawn point inside a wall.
	for i in range(w.spawn_points.size()):
		if w.is_solid(w.world_to_cell(w.spawn_points[i])):
			fails.append("spawn_points[%d] at %s is inside a wall" % [i, w.spawn_points[i]])
	# 4. Haven zone must not overlap any wall tile.
	var hz: Rect2 = w.haven_zone
	var hc0 := w.world_to_cell(hz.position)
	var hc1 := w.world_to_cell(hz.position + hz.size - Vector2(1, 1))
	for yy in range(hc0.y, hc1.y + 1):
		for xx in range(hc0.x, hc1.x + 1):
			if w.is_solid(Vector2i(xx, yy)):
				fails.append("haven_zone overlaps wall at cell (%d,%d)" % [xx, yy])
	# 5. Exit zone walkable corridor (sample every tile).
	var ez: Rect2 = w.exit_zone
	var ec0 := w.world_to_cell(ez.position)
	var ec1 := w.world_to_cell(ez.position + ez.size - Vector2(1, 1))
	for yy in range(ec0.y, ec1.y + 1):
		for xx in range(ec0.x, ec1.x + 1):
			if w.is_solid(Vector2i(xx, yy)):
				fails.append("exit_zone overlaps wall at cell (%d,%d)" % [xx, yy])

	# 6. Path connectivity: player spawn <-> haven, and player <-> every enemy spawn.
	var player: Vector2 = w.named_points["player"]
	var haven: Vector2 = w.named_points["haven"]
	if w.find_path(player, haven).is_empty():
		fails.append("find_path player->haven returned EMPTY")
	# Enemy spawns are the last entries with hostile intent; validate ALL spawns instead.
	for i in range(w.spawn_points.size()):
		var p := w.find_path(player, w.spawn_points[i])
		if p.is_empty():
			fails.append("find_path player->spawn[%d] (%s) returned EMPTY" % [i, w.spawn_points[i]])

	# 7. Test-fixture coordinates the unit suite hardcodes must be walkable.
	var fixtures := {
		"react_fire(400,600)": Vector2(400, 600),
		"physics_a(600,600)": Vector2(600, 600),
		"physics_b(648,600)": Vector2(648, 600),
		"maw_e(700,500)": Vector2(700, 500),
		"maw_center(600,500)": Vector2(600, 500),
		"firebomb_tgt(560,600)": Vector2(560, 600),
		"combo(430,576)": Vector2(430, 576),
		"shatter_b(650,600)": Vector2(650, 600),
		"resonance(400,400)": Vector2(400, 400),
		"flow(420,400)": Vector2(420, 400),
	}
	for label in fixtures.keys():
		if w.is_solid(w.world_to_cell(fixtures[label])):
			fails.append("fixture %s is inside a wall" % label)

	# 8. Hunter perch (704,320)=(22,10) walkable + occluded LOS to player, but path exists.
	var perch := Vector2(704, 320)
	if w.is_solid(w.world_to_cell(perch)):
		fails.append("hunter perch (22,10) is inside a wall")
	if w.segment_clear(perch, player):
		fails.append("hunter perch has CLEAR LOS to player (test needs it occluded)")
	if w.find_path(perch, player).is_empty():
		fails.append("find_path hunter_perch->player returned EMPTY")

	# 9. Maw/physics tiles (18,15) and (21,15) walkable.
	for cell in [Vector2i(18, 15), Vector2i(21, 15)]:
		if w.is_solid(cell):
			fails.append("physics tile %s is inside a wall" % cell)

	# 10. Midway corridor rows 17-20 fully open east-to-west (slice walks & vehicle drives east).
	for row in range(17, 21):
		for col in range(1, 63):
			if w.is_solid(Vector2i(col, row)):
				fails.append("MIDWAY corridor blocked at (%d,%d) — slice/vehicle tests need it clear" % [col, row])

	# 11. Outer boundary intact.
	for col in range(w.size.x):
		if not w.is_solid(Vector2i(col, 0)) or not w.is_solid(Vector2i(col, w.size.y - 1)):
			fails.append("outer boundary breach row at col %d" % col)
	for row in range(w.size.y):
		if not w.is_solid(Vector2i(0, row)) or not w.is_solid(Vector2i(w.size.x - 1, row)):
			fails.append("outer boundary breach col at row %d" % row)

	# 12. Light count in target band.
	if w.lights.size() < 25 or w.lights.size() > 40:
		fails.append("lights count %d outside 25-40 band" % w.lights.size())

	# 13. Wall ratio sanity (not so dense A* blows the node budget; not a parking lot either).
	var wall_count := 0
	for i in range(w.walls.size()):
		if w.walls[i] != 0:
			wall_count += 1
	var pct := float(wall_count) / float(w.walls.size()) * 100.0

	print("---- CITY VALIDATION ----")
	print("tiles: %d  walls: %d (%.1f%%)  lights: %d  spawns: %d  named: %d  pois: %d" % [
		w.walls.size(), wall_count, pct, w.lights.size(), w.spawn_points.size(), w.named_points.size(), w.pois.size()])
	if fails.is_empty():
		print("RESULT: ALL CHECKS PASSED")
	else:
		print("RESULT: %d FAILURES:" % fails.size())
		for f in fails:
			print("  FAIL: %s" % f)
	quit(0 if fails.is_empty() else 1)
