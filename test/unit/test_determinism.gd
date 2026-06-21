## test_determinism.gd — the keystone test, in GUT form.
##
## REVAMP_SPEC §2.1 DoD: "20 headless runs, same seed = identical hash."
## The merge gate for the deterministic sim core. If this fails, every downstream test
## (combat skill-gap, AI diversity, replay) is meaningless.
##
## Run via GUT headless:
##   godot --headless -s addons/gut/gut_cmdln.gd
##
## Uses the VCSim type directly (VCSim.new()) rather than the global `Sim` autoload,
## because GUT's CLI entry point does not always initialise project autoloads. Each run
## gets a fresh instance; new_game() fully resets all state.
##
extends GutTest

const RUNS := 20
const SEED_VALUE := 42
const TICKS := 600   # 10 seconds of sim at 60Hz


## 20 fresh runs from the same seed must produce byte-identical state hashes.
func test_state_hash_identical_across_runs() -> void:
	var first_hash: int = 0
	for i in RUNS:
		var sim := VCSim.new()
		sim.new_game(SEED_VALUE, "brujah")
		for _t in TICKS:
			sim.tick_sim(1.0 / 60.0)
		var h: int = sim.state_hash()
		if i == 0:
			first_hash = h
		else:
			assert_eq(h, first_hash,
				"run %d diverged from run 1 — sim is nondeterministic" % (i + 1))
		sim.queue_free()
	pass_test("20/20 runs produced identical hash %d" % first_hash)


## Two different seeds must produce different hashes — sanity check the seed actually drives it.
func test_different_seeds_diverge() -> void:
	var h_a := _hash_for_seed(42)
	var h_b := _hash_for_seed(9999)
	assert_ne(h_a, h_b, "different seeds produced identical hashes — seed not driving sim")


func _hash_for_seed(s: int) -> int:
	var sim := VCSim.new()
	sim.new_game(s, "brujah")
	for _t in TICKS:
		sim.tick_sim(1.0 / 60.0)
	var h: int = sim.state_hash()
	sim.queue_free()
	return h
