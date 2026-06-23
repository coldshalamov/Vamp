## test_react_fire.gd — Blood Grammar REACT atom: igniting spilled blood creates fire that burns
## whoever stands in it and spreads through connected blood. Deterministic (integer, no RNG).
extends GutTest

const DT := 1.0 / 60.0
const POS := Vector2(400, 600)   # open road cell (not inside a building)


func test_igniting_blood_burns_an_occupant() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	sim.world.spill_blood(POS, 220)
	sim.world.spill_blood(POS + Vector2(32, 0), 160)
	var lit: int = sim.world.ignite_radius(POS, 48.0)
	assert_true(lit > 0, "blood ignited into fire")
	assert_true(sim.world.fire_at(POS) > 0, "the cell is on fire")
	var npc: SimEntity = sim.spawn_npc("ped", POS, {})
	var hp0: float = npc.hp
	for i in range(45):
		sim.tick_sim(DT)
	assert_true(npc.hp < hp0, "standing in burning blood deals damage (%.1f -> %.1f)" % [hp0, npc.hp])


func test_fire_is_deterministic() -> void:
	var a := _run()
	var b := _run()
	assert_eq(a, b, "same ignition + ticks -> identical burn outcome")


func _run() -> float:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	sim.world.spill_blood(POS, 220)
	sim.world.ignite_radius(POS, 48.0)
	var npc: SimEntity = sim.spawn_npc("ped", POS, {})
	for i in range(45):
		sim.tick_sim(DT)
	return npc.hp
