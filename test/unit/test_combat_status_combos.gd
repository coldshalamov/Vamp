## test_combat_status_combos.gd -- B1 status framework and combo trigger contract.
extends GutTest

const SimTest := preload("res://test/unit/sim_test_helpers.gd")
const DT := 1.0 / 60.0


func test_status_apply_stack_and_expire_emit_contract_cues() -> void:
	var sim := SimTest.new_sim(42, "brujah")
	var target := sim.spawn_npc("ped", Vector2(430, 576), { "state": "guard" })
	target.apply_status("bleed", 3, { "dps": 0.0, "src_id": sim.player.id }, sim)
	target.apply_status("bleeding", 5, { "dps": 0.0, "src_id": sim.player.id }, sim)
	assert_true(target.has_status("bleed"), "legacy bleed alias resolves to canonical bleeding")
	assert_true(target.has_status("bleeding"), "canonical bleeding status is active")
	assert_eq(int(target.status_record("bleeding").get("stack_count", 0)), 2, "bleeding stacks")
	assert_true(_has_cue(sim, "status.applied", "status", "bleeding"), "status.applied cue emitted")
	for _i in range(6):
		sim.tick_sim(DT)
	assert_false(target.has_status("bleeding"), "status expires after ticking down")
	assert_true(_has_cue(sim, "status.expired", "status", "bleeding"), "status.expired cue emitted")
	SimTest.free_sim(sim)


func test_hemorrhage_combo_bonus_consumes_bleeding_and_emits_contract_cues() -> void:
	var sim := SimTest.new_sim(42, "brujah")
	var target := sim.spawn_npc("ped", Vector2(430, 576), { "state": "guard" })
	target.max_hp = 100.0
	target.hp = 100.0
	target.armor = 0.0
	target.apply_status("bleeding", 120, { "dps": 0.0, "src_id": sim.player.id }, sim)
	var dealt := sim.damage_entity(sim.player, target, 10.0, {
		"ability_id": "bs_bolt",
		"damage_type": "blood",
		"crit_chance": 0.0,
		"no_crit": true,
	})
	assert_almost_eq(dealt, 15.0, 0.01, "hemorrhage turns a 10 damage bolt into 15")
	assert_false(target.has_status("bleeding"), "hemorrhage consumes bleeding")
	assert_true(_has_cue(sim, "combo.trigger", "combo_name", "hemorrhage"), "combo.trigger cue emitted")
	assert_true(_has_cue(sim, "status.detonated", "status", "bleeding"), "status.detonated cue emitted")
	SimTest.free_sim(sim)


func test_combo_status_path_is_deterministic() -> void:
	var a := _combo_hash()
	var b := _combo_hash()
	assert_eq(a["hash"], b["hash"], "same combo scenario produces identical hash")
	assert_eq(a["cues"], b["cues"], "same combo scenario produces identical cue ids")


func _combo_hash() -> Dictionary:
	var sim := SimTest.new_sim(777, "brujah")
	var target := sim.spawn_npc("ped", Vector2(430, 576), { "state": "guard" })
	target.max_hp = 100.0
	target.hp = 100.0
	target.armor = 0.0
	target.apply_status("bleed", 120, { "dps": 0.0, "src_id": sim.player.id }, sim)
	sim.damage_entity(sim.player, target, 10.0, {
		"ability_id": "bs_bolt",
		"damage_type": "blood",
		"crit_chance": 0.0,
		"no_crit": true,
	})
	for _i in range(12):
		sim.tick_sim(DT)
	var cue_ids: Array[String] = []
	for rec in sim.cue_events:
		cue_ids.append(String(rec["id"]))
	var result := { "hash": sim.state_hash(), "cues": cue_ids }
	SimTest.free_sim(sim)
	return result


func _has_cue(sim: VCSim, event_id: String, field: String, value) -> bool:
	for rec in sim.cue_events:
		if String(rec["id"]) != event_id:
			continue
		var payload: Dictionary = rec["payload"]
		if payload.get(field) == value:
			return true
	return false
