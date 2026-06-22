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


func test_recorded_inputs_replay_to_identical_state_and_cues() -> void:
	var recorded := _run_replay_script(true, [])
	var replayed := _run_replay_script(false, recorded["inputs"])
	assert_true(recorded["inputs"].size() > 0, "script did not record any player inputs")
	assert_eq(replayed["hash"], recorded["hash"], "recorded inputs replayed to a different state")
	assert_eq(replayed["cues"], recorded["cues"], "recorded inputs replayed to different CueBus events")


func _hash_for_seed(s: int) -> int:
	var sim := VCSim.new()
	sim.new_game(s, "brujah")
	for _t in TICKS:
		sim.tick_sim(1.0 / 60.0)
	var h: int = sim.state_hash()
	sim.queue_free()
	return h


func _run_replay_script(recording: bool, replay_inputs: Array) -> Dictionary:
	var sim := VCSim.new()
	sim.new_game(1337, "brujah")
	if recording:
		sim.start_recording()
	else:
		sim.load_replay(replay_inputs)
	for t in range(180):
		if recording:
			_apply_replay_script_input(sim, t)
		sim.tick_sim(1.0 / 60.0)
	var cue_ids: Array[String] = []
	for rec in sim.cue_events:
		cue_ids.append(String(rec["id"]))
	var result := {
		"hash": sim.state_hash(),
		"inputs": sim.recorded_inputs(),
		"cues": cue_ids
	}
	sim.queue_free()
	return result


func _apply_replay_script_input(sim: VCSim, tick_index: int) -> void:
	match tick_index:
		0:
			_apply_action(sim, InputAction.Kind.MOVE, Vector2.RIGHT)
		24:
			_apply_action(sim, InputAction.Kind.SPRINT, Vector2.ZERO, "", true)
		48:
			_apply_action(sim, InputAction.Kind.SPRINT, Vector2.ZERO, "", false)
		54:
			_apply_action(sim, InputAction.Kind.AIM, sim.player.pos + Vector2.RIGHT * 220.0, "", true)
		55:
			_apply_action(sim, InputAction.Kind.POWER, Vector2.ZERO, "cel_haste", false)
		96:
			_apply_action(sim, InputAction.Kind.DASH, Vector2.RIGHT)
		132:
			_apply_action(sim, InputAction.Kind.MOVE, Vector2.ZERO)
		_:
			pass


func _apply_action(sim: VCSim, kind: int, vector: Vector2 = Vector2.ZERO, action_id: String = "", held: bool = false) -> void:
	var action := InputAction.new(kind)
	action.vector = vector
	action.action_id = action_id
	action.held = held
	sim.apply_input(action)
