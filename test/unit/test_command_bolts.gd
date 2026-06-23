## test_command_bolts.gd — Blood Grammar COMMAND atom: casting Blood Bolt while near spilled blood
## commands the pool into a fan of extra free bolts. Deterministic (integer siphon, no RNG).
extends GutTest


func _count_projectiles(sim) -> int:
	var n := 0
	for e in sim.entities:
		if e != null and e.kind == "projectile":
			n += 1
	return n


func _cast(with_pool: bool) -> int:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var pb: SimPlayer = sim.player.behaviour
	pb.blood = 95.0
	sim.meta.known_powers["bs_bolt"] = true
	if with_pool:
		sim.world.spill_blood(sim.player.pos, 240)
	pb.cast_power("bs_bolt", sim)
	return _count_projectiles(sim)


func test_commanding_a_pool_fires_more_bolts() -> void:
	var dry := _cast(false)
	var wet := _cast(true)
	assert_true(dry >= 1, "a normal bolt fires at least one projectile")
	assert_true(wet > dry, "commanding a blood pool fires MORE bolts (%d vs %d)" % [wet, dry])


func test_command_is_deterministic() -> void:
	assert_eq(_cast(true), _cast(true), "same pool -> same bolt count")
