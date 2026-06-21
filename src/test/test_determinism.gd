## test_determinism.gd — the keystone test.
##
## REVAMP_SPEC §2.1 DoD: "20 headless runs, same seed = identical hash."
## This is the merge gate for the deterministic sim core. If this fails, every downstream
## test (combat skill-gap, AI search diversity, replay) is meaningless.
##
## Run headless:
##   godot --headless --script res://src/test/test_determinism.gd
## Exit code 0 = pass, 1 = fail.
##
## NOTE on autoloads: `--script` runs as a standalone SceneTree script and does NOT
## initialise project autoloads. So we load Sim.gd explicitly and add it to the tree,
## which is exactly what the autoload system would do at boot. This keeps the test honest
## (it exercises the real Sim class, not a mock) while running fully headless.
##
extends SceneTree

const RUNS := 20
const SEED_VALUE := 42
const TICKS := 600   # 10 seconds of sim at 60Hz

var SimScript: GDScript

func _init() -> void:
	# Load the real Sim script and instantiate it the way the autoload system would.
	SimScript = load("res://src/sim/Sim.gd")
	var first_hash: int = 0
	var passed := true
	for i in RUNS:
		var sim: Node = SimScript.new()
		sim.new_game(SEED_VALUE, "brujah")
		for _t in TICKS:
			sim.tick_sim(1.0 / 60.0)
		var h: int = sim.state_hash()
		if i == 0:
			first_hash = h
			print("[run  1] hash=", h)
		elif h != first_hash:
			push_error("[determinism FAIL] run %2d hash=%d != run 1 hash=%d" % [i + 1, h, first_hash])
			passed = false
			break
		else:
			print("[run %2d] hash=%d (match)" % [i + 1, h])
		sim.queue_free()
	if passed:
		print("\n=== PASS: %d/%d runs identical (seed=%d, %d ticks each) ===" % [RUNS, RUNS, SEED_VALUE, TICKS])
		quit(0)
	else:
		print("\n=== FAIL: nondeterministic sim ===")
		quit(1)
