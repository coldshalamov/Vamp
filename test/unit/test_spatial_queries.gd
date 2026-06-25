## test_spatial_queries.gd — deterministic guard for VCSim's spatial query grid.
##
## The grid is an optimization behind existing APIs. These tests compare it to the old brute-force
## behavior so radius powers, AI perception, and hover targeting keep their semantics.
extends GutTest


func test_entities_in_radius_matches_bruteforce_order() -> void:
	var sim := VCSim.new()
	sim.new_game(123, "brujah")
	for i in range(80):
		var e := sim.spawn_npc("ped", Vector2(80.0 + float(i % 10) * 73.0, 120.0 + float(i / 10) * 61.0), {})
		e.tags["spatial_probe"] = true
		e.downed = i % 9 == 0
		e.dead = i % 17 == 0
	sim.mark_spatial_dirty()
	var origin := Vector2(420.0, 360.0)
	var radius := 255.0
	var pred := func(e): return e != null and not e.dead and not e.downed and bool(e.tags.get("spatial_probe", false))
	assert_eq(_ids(sim.entities_in_radius(origin, radius, pred)), _ids(_brute_entities_in_radius(sim, origin, radius, pred)),
		"grid-backed entities_in_radius matches brute-force ids and order")
	sim.free()


func test_nearest_entity_keeps_later_tie_wins_behavior() -> void:
	var sim := VCSim.new()
	sim.new_game(456, "brujah")
	var origin := Vector2(920.0, 920.0)
	var a := sim.spawn_npc("ped", origin + Vector2(40.0, 0.0), {})
	var b := sim.spawn_npc("ped", origin + Vector2(-40.0, 0.0), {})
	a.tags["tie_probe"] = true
	b.tags["tie_probe"] = true
	sim.mark_spatial_dirty()
	var found := sim.nearest_entity(origin, 90.0, func(e): return bool(e.tags.get("tie_probe", false)))
	assert_eq(found, b, "nearest_entity keeps old <= tie behavior: later entity wins equal distance")
	sim.free()


func test_spatial_queries_do_not_mutate_authoritative_state() -> void:
	var sim := VCSim.new()
	sim.new_game(789, "brujah")
	var before := sim.state_hash()
	for i in range(12):
		var origin := Vector2(100.0 + float(i) * 33.0, 500.0)
		sim.entities_in_radius(origin, 220.0, func(e): return e != null and not e.dead)
		sim.nearest_entity(origin, 240.0, func(e): return e != null and e.kind == "npc")
	assert_eq(sim.state_hash(), before, "query cache rebuilds do not affect deterministic state")
	sim.free()


func _brute_entities_in_radius(sim: VCSim, origin: Vector2, radius: float, predicate: Callable) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	var r2 := radius * radius
	for e in sim.entities:
		if e == null:
			continue
		if origin.distance_squared_to(e.pos) <= r2 and predicate.call(e):
			out.append(e)
	return out


func _ids(items: Array[SimEntity]) -> Array[int]:
	var out: Array[int] = []
	for e in items:
		out.append(e.id)
	return out
