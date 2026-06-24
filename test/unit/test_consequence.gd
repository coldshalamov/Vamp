## Consequence loop — the StyleLedger profiles how you play and the city dispatches hunters that
## counter it (a Tracker for the unseen, a bruiser for the brute). Deterministic + save-safe.
extends GutTest


func test_ledger_counters_player_style() -> void:
	var stealthy := StyleLedger.new()
	stealthy.record("stealth", 5.0)
	stealthy.record("force", 1.0)
	assert_eq(stealthy.dominant(), "stealth")
	assert_eq(stealthy.counter_type(5, 0.9), "hunter", "a stealth player draws a Tracker (hunter)")

	var brute := StyleLedger.new()
	brute.record("force", 5.0)
	assert_ne(brute.counter_type(5, 0.9), "hunter", "a force player draws a bruiser, not a Tracker")


func test_casting_records_style() -> void:
	var sim := VCSim.new()
	sim.new_game(3, "brujah")
	sim.player.behaviour.set("blood", 100.0)
	var a := InputAction.new(InputAction.Kind.POWER)
	a.action_id = "obf_cloak"   # an Obfuscate power -> stealth style
	sim.apply_input(a)
	assert_gt(float(sim.style_ledger.tallies["stealth"]), 0.0, "casting Obfuscate records the stealth style")
	sim.queue_free()


func test_objective_guides_the_player() -> void:
	var sim := VCSim.new()
	sim.new_game(3, "brujah")
	sim.player.behaviour.set("blood", 5.0)   # nearly dry
	assert_true(sim.current_objective().to_lower().contains("feed"), "low vitae should point the player at feeding")
	sim.queue_free()
