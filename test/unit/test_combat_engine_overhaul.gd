## test_combat_engine_overhaul.gd -- held casts, melee rhythm, enemy roles, and feed contract.
extends GutTest

const SimTest := preload("res://test/unit/sim_test_helpers.gd")
const DT := 1.0 / 60.0


func test_charged_potence_cast_hits_harder_than_quick_cast() -> void:
	var quick := SimTest.new_sim(8101, "brujah")
	var quick_target := quick.spawn_npc("ped", quick.player.pos + Vector2(60.0, 0.0), { "state": "guard" })
	quick_target.max_hp = 200.0
	quick_target.hp = 200.0
	quick_target.armor = 0.0
	quick.meta.derived["critChance"] = 0.0
	quick.player.facing = 0.0
	quick.player.behaviour.cast_power("pot_slam", quick)
	var quick_damage := quick_target.max_hp - quick_target.hp
	SimTest.free_sim(quick)

	var charged := SimTest.new_sim(8101, "brujah")
	var charged_target := charged.spawn_npc("ped", charged.player.pos + Vector2(60.0, 0.0), { "state": "guard" })
	charged_target.max_hp = 200.0
	charged_target.hp = 200.0
	charged_target.armor = 0.0
	charged.meta.derived["critChance"] = 0.0
	charged.player.facing = 0.0
	var hold := InputAction.new(InputAction.Kind.POWER)
	hold.action_id = "pot_slam"
	hold.held = true
	charged.apply_input(hold)
	for _i in range(96):
		charged.tick_sim(DT)
	var release := InputAction.new(InputAction.Kind.RELEASE)
	release.action_id = "pot_slam"
	charged.apply_input(release)
	var charged_damage := charged_target.max_hp - charged_target.hp

	assert_gt(charged_damage, quick_damage * 1.5, "charged Earthshock should reward a safe wind-up")
	assert_true(_has_cue(charged, "attack.telegraph"), "charged cast emits a readable wind-up cue")
	SimTest.free_sim(charged)


func test_channeled_blood_bolt_drains_blood_and_ticks_damage() -> void:
	var sim := SimTest.new_sim(8102, "brujah")
	var target := sim.spawn_npc("rusher", sim.player.pos + Vector2(180.0, 0.0), { "state": "guard", "hostile_to_player": false })
	target.armor = 0.0
	sim.meta.derived["critChance"] = 0.0
	sim.player.facing = 0.0
	sim.player.behaviour.aim_point = target.pos
	var start_blood: float = sim.player.behaviour.blood
	var hold := InputAction.new(InputAction.Kind.POWER)
	hold.action_id = "bs_bolt"
	hold.held = true
	sim.apply_input(hold)
	for _i in range(36):
		sim.tick_sim(DT)
	var release := InputAction.new(InputAction.Kind.RELEASE)
	release.action_id = "bs_bolt"
	sim.apply_input(release)

	assert_lt(target.hp, target.max_hp, "channeled Blood Bolt should pulse damage while held")
	assert_lt(float(sim.player.behaviour.blood), start_blood, "channeled Blood Bolt should drain vitae over time")
	assert_true(target.has_status("bleeding"), "channeled Blood Bolt keeps the bleed primitive alive")
	SimTest.free_sim(sim)


func test_hold_attack_releases_a_heavy_telegraphed_melee() -> void:
	var sim := SimTest.new_sim(8103, "brujah")
	var hold := InputAction.new(InputAction.Kind.ATTACK)
	hold.held = true
	sim.apply_input(hold)
	for _i in range(12):
		sim.tick_sim(DT)
	var release := InputAction.new(InputAction.Kind.RELEASE)
	release.action_id = "attack"
	sim.apply_input(release)

	assert_not_null(sim.player.current_action, "held heavy should begin an action on release")
	assert_eq(sim.player.current_action.def.id, "melee_heavy", "held attack releases the heavy attack")
	assert_true(_has_cue(sim, "attack.telegraph"), "held heavy emits a wind-up cue")
	assert_true(_has_cue(sim, "attack.start"), "held heavy emits attack.start")
	SimTest.free_sim(sim)


func test_enemy_archetypes_rusher_closes_and_healer_supports() -> void:
	var sim := SimTest.new_sim(8104, "brujah")
	var rusher := sim.spawn_npc("rusher", sim.player.pos + Vector2(220.0, 0.0), { "state": "chase", "hostile_to_player": true })
	var start_dist := rusher.pos.distance_to(sim.player.pos)
	for _i in range(20):
		sim.tick_sim(DT)
	assert_lt(rusher.pos.distance_to(sim.player.pos), start_dist - 20.0, "rusher should aggressively close distance")

	var ally := sim.spawn_npc("tank", sim.player.pos + Vector2(180.0, 72.0), { "state": "guard", "hostile_to_player": true })
	var healer := sim.spawn_npc("healer", sim.player.pos + Vector2(150.0, 90.0), { "state": "chase", "hostile_to_player": true })
	ally.hp = ally.max_hp * 0.35
	var wounded_hp := ally.hp
	for _i in range(10):
		healer.behaviour.step(DT, sim)
	assert_gt(ally.hp, wounded_hp, "healer should restore a wounded ally")
	assert_true(ally.has_status("empowered"), "healer should briefly empower the ally it saves")
	SimTest.free_sim(sim)


func test_feeding_emits_progress_choice_verdict_and_end_contract() -> void:
	var sim := SimTest.new_sim(8105, "brujah")
	var civ := sim.spawn_npc("ped", sim.player.pos + Vector2(12.0, 0.0), { "state": "guard" })
	var feed := InputAction.new(InputAction.Kind.FEED)
	feed.held = true
	sim.apply_input(feed)
	for _i in range(180):
		sim.tick_sim(DT)
		if _has_cue(sim, "feed.choice"):
			break
	assert_true(_has_cue(sim, "feed.progress"), "feeding should stream progress")
	assert_true(_has_cue(sim, "feed.choice"), "feeding should announce the spare/kill choice threshold")
	var release := InputAction.new(InputAction.Kind.FEED)
	release.held = false
	sim.apply_input(release)

	assert_false(civ.dead, "release at the choice point should spare the victim")
	assert_true(_has_cue(sim, "feed.spare"), "spare verdict cue emitted")
	assert_true(_has_cue(sim, "feed.end"), "feed.end cue emitted")
	assert_true(_cue_payload_has(sim, "feed.spare", "blood_gained"), "feed.spare carries blood_gained")
	assert_true(_cue_payload_has(sim, "feed.end", "blood_total"), "feed.end carries blood_total")
	SimTest.free_sim(sim)


func _has_cue(sim: VCSim, event_id: String) -> bool:
	for rec in sim.cue_events:
		if String(rec["id"]) == event_id:
			return true
	return false


func _cue_payload_has(sim: VCSim, event_id: String, key: String) -> bool:
	for rec in sim.cue_events:
		if String(rec["id"]) == event_id and (rec["payload"] as Dictionary).has(key):
			return true
	return false
