## test_blood_drink.gd — the Blood Grammar DRINK atom + Open Vein loop (SPILL -> DRINK).
##
## Standing in a pool reclaims vitae and drains the pool; casting opens a wound that spills.
## All deterministic (integer depth, no RNG), so two identical runs match exactly.
extends GutTest

const DT := 1.0 / 60.0


func test_drink_reclaims_vitae_and_drains_the_pool() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var p: SimEntity = sim.player
	var pb: SimPlayer = p.behaviour
	pb.blood = 20.0
	sim.world.spill_blood(p.pos, 200)
	var pool0: int = sim.world.blood_at(p.pos)
	var blood0: float = pb.blood
	assert_true(pool0 > 0, "a pool exists under the player")
	for i in range(60):
		sim.tick_sim(DT)
	assert_true(pb.blood > blood0, "drinking the pool raised vitae (%.1f -> %.1f)" % [blood0, pb.blood])
	assert_true(sim.world.blood_at(p.pos) < pool0, "the pool was siphoned down (%d -> %d)" % [pool0, sim.world.blood_at(p.pos)])


func test_spill_then_drink_is_deterministic() -> void:
	var a := _run()
	var b := _run()
	assert_eq(a["blood"], b["blood"], "same seed -> identical reclaimed vitae")
	assert_eq(a["pool"], b["pool"], "same seed -> identical pool depth")


func _run() -> Dictionary:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var pb: SimPlayer = sim.player.behaviour
	pb.blood = 15.0
	sim.world.spill_blood(sim.player.pos, 180)
	for i in range(45):
		sim.tick_sim(DT)
	return { "blood": pb.blood, "pool": sim.world.blood_at(sim.player.pos) }
