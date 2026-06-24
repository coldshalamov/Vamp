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


func test_shatter_combo_amps_damage_on_mesmerized() -> void:
	var sim := VCSim.new()
	sim.new_game(5, "brujah")
	var a := sim.spawn_npc("thug", Vector2(600.0, 600.0), {})
	var b := sim.spawn_npc("thug", Vector2(650.0, 600.0), {})
	b.apply_status("mesmerized", 120)   # b is frozen; a is not
	var da := sim.damage_entity(sim.player, a, 20.0, { "crit_chance": 0.0 })
	var db := sim.damage_entity(sim.player, b, 20.0, { "crit_chance": 0.0 })
	assert_gt(db, da, "striking a mesmerized foe (Shatter combo) deals more damage")
	sim.queue_free()


func test_first_hunt_teaches_feeding_first() -> void:
	var sim := VCSim.new()
	sim.new_game(3, "brujah")
	assert_true(sim.current_objective().to_lower().contains("feed"), "a fresh night opens with the First Hunt feed lesson")
	sim.queue_free()


func test_contract_offer_and_complete() -> void:
	var sim := VCSim.new()
	sim.new_game(7, "brujah")
	sim._offer_contract()
	assert_false(sim.contract.is_empty(), "a contract should be offered when a mortal is present")
	var target := sim.get_entity(int(sim.contract["target_id"]))
	assert_not_null(target, "the contract marks a real entity")
	if target != null:
		target.dead = true   # drain the mark
	sim._tick_contract()
	assert_true(sim.contract.is_empty(), "draining the marked mortal completes the contract")
	sim.queue_free()
