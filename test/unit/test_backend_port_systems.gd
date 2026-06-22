## Backend port coverage for legacy systems beyond the playable slice.
extends GutTest

const DT := 1.0 / 60.0
const GameCatalog := preload("res://src/data/GameCatalog.gd")
const PowerCatalogScript := preload("res://src/data/PowerCatalog.gd")

func test_catalog_ports_legacy_power_and_progression_data() -> void:
	assert_true(GameCatalog.POWERS.size() >= 35, "legacy power catalog was not ported")
	assert_true(GameCatalog.SKILL_NODES.size() >= 70, "legacy skill tree was not ported")
	assert_true(GameCatalog.WEAPONS.size() >= 6, "legacy weapon bases missing")
	assert_true(GameCatalog.HAVEN_ROOMS.size() >= 6, "legacy haven rooms missing")
	assert_true(GameCatalog.MISSION_TYPES.size() >= 8, "legacy mission types missing")
	for id in ["cel_bullet", "pot_quake", "for_unkill", "obf_mask", "aus_senses", "dom_thrall", "pre_majesty", "pro_beast", "bs_storm", "shd_tendril", "dem_confuse", "vic_horrid"]:
		var def: Dictionary = PowerCatalogScript.get_def(id)
		assert_false(def.is_empty(), "missing ported power %s" % id)
	assert_eq(PowerCatalogScript.get_def("dom_mesmerize").get("id", ""), "dom_mesmer", "legacy power alias did not canonicalize")

func test_skill_tree_hotbar_and_power_cast_are_authoritative_in_meta() -> void:
	var sim := VCSim.new()
	sim.new_game(2201, "brujah")
	var meta: SimMeta = sim.meta
	var start_blood: float = float(sim.player.behaviour.get("blood"))
	assert_true(meta.allocate_skill("pot_p0", sim), "tier 0 passive should allocate")
	assert_true(meta.allocate_skill("pot_n1", sim), "tier 1 power should unlock after branch point")
	assert_true(meta.knows_power("pot_charge"), "allocated power node did not teach the power")
	assert_true(meta.assign_slot(0, "pot_charge"), "known power did not bind to hotbar")
	_apply_action(sim, InputAction.Kind.POWER, Vector2.ZERO, "slot_1", false)
	assert_true(float(sim.player.behaviour.get("blood")) < start_blood, "hotbar cast did not spend vitae")
	assert_true(_has_cue(sim, "power.cast"), "hotbar cast did not emit semantic cue")
	sim.queue_free()

func test_inventory_economy_haven_coterie_domain_and_mission_backend() -> void:
	var sim := VCSim.new()
	sim.new_game(31337, "brujah")
	var meta: SimMeta = sim.meta
	meta.money = 10000
	var old_max_hp: float = sim.player.max_hp
	var item: Dictionary = {
		"id": 9001,
		"slot": "attire",
		"name": "Test Hidden Mail",
		"rarity": "rare",
		"level": 5,
		"mods": { "add": { "maxHP": 50.0 }, "pct": {} },
		"weaponStats": {},
	}
	meta.add_item(item, sim)
	assert_true(meta.equip_item(9001, sim), "equippable item was not equipped")
	assert_true(sim.player.max_hp > old_max_hp, "equipped item did not affect runtime derived stats")
	var old_max_blood: float = float(sim.player.behaviour.get("max_blood"))
	assert_true(meta.upgrade_haven("cellar", sim), "haven room upgrade failed")
	assert_true(float(sim.player.behaviour.get("max_blood")) > old_max_blood, "haven upgrade did not affect runtime stats")
	var member: Dictionary = meta.bind_coterie_member("thrall", sim)
	assert_true(int(member.get("id", 0)) > 0, "coterie member was not created")
	assert_true(meta.assign_coterie(int(member["id"]), "herd", sim), "coterie assignment failed")
	assert_true(int(meta.collect_coterie_jobs().get("vitae", 0)) > 0, "coterie job produced no vitae")
	meta.change_reputation("camarilla", 20.0, sim)
	assert_eq(float(meta.reputation["camarilla"]), 20.0, "faction reputation did not change")
	assert_eq(float(meta.reputation["anarch"]), -10.0, "rival reputation did not move")
	assert_true(meta.contest_domain("docks", sim), "domain contest did not spawn a baron")
	var baron: SimEntity = _first_tagged(sim, "baron_of", "docks")
	assert_not_null(baron, "domain baron was not tagged")
	sim.damage_entity(sim.player, baron, 9999.0, { "crit_chance": 0.0 })
	assert_eq(meta.domains["docks"].get("owner", null), "player", "domain was not claimed when baron died")
	meta.mission_offers = [_feed_mission()]
	assert_true(meta.accept_mission(77, sim), "feed mission did not activate")
	sim.emit_cue("feed.spare", { "target_id": 1 })
	assert_eq(meta.missions_done, 1, "mission did not complete from semantic cue")
	assert_true(meta.active_mission.is_empty(), "completed mission remained active")
	assert_true(_has_cue(sim, "mission.complete"), "mission completion cue missing")
	sim.queue_free()

func test_projectiles_vehicles_day_night_and_save_restore_are_deterministic() -> void:
	var sim := VCSim.new()
	sim.new_game(9009, "brujah")
	var projectile_lane := sim.player.pos + Vector2(0.0, 64.0)
	var target: SimEntity = sim.spawn_npc("thug", projectile_lane + Vector2(150.0, 0.0), { "state": "guard", "hostile_to_player": false })
	sim.spawn_projectile(projectile_lane + Vector2(18.0, 0.0), Vector2(620.0, 0.0), {
		"owner_id": sim.player.id,
		"faction": "player",
		"kind": "test_bolt",
		"damage": 33.0,
		"damage_type": "blood",
		"life_ticks": 60,
	})
	_tick_for(sim, 20)
	assert_true(target.hp < target.max_hp, "deterministic projectile did not damage target")
	var vehicle: SimEntity = sim.spawn_vehicle("sport", sim.player.pos + Vector2(28.0, 0.0), { "angle": 0.0 })
	assert_true(bool(vehicle.behaviour.call("enter", sim.player, sim)), "player could not enter vehicle")
	sim.player.behaviour.set("vehicle_id", vehicle.id)
	_apply_action(sim, InputAction.Kind.MOVE, Vector2(0.0, -1.0), "", false)
	_tick_for(sim, 45)
	assert_true(vehicle.pos.x > sim.world.named_points["player"].x + 35.0, "vehicle did not drive deterministically")
	var old_day: int = sim.meta.day
	sim.meta.clock = 5.99
	sim.player.pos = sim.world.named_points["haven"]
	sim.meta.tick(2.0, sim)
	assert_eq(sim.meta.day, old_day + 1, "dawn did not roll the day forward")
	var save_sim := VCSim.new()
	save_sim.new_game(12345, "toreador")
	save_sim.meta.money = 777
	assert_true(save_sim.meta.learn_power("cel_haste"), "test setup failed to learn power")
	assert_true(save_sim.meta.assign_slot(0, "cel_haste"), "test setup failed to bind slot")
	var snapshot: Dictionary = save_sim.serialize_run()
	var expected_hash: int = save_sim.state_hash()
	var restored := VCSim.new()
	assert_true(restored.restore_run(snapshot), "restore_run rejected serialized state")
	assert_eq(restored.state_hash(), expected_hash, "serialized backend state did not restore to the same hash")
	assert_eq(restored.meta.slot_power(0), "cel_haste", "hotbar slot did not survive save/restore")
	sim.queue_free()
	save_sim.queue_free()
	restored.queue_free()

func test_elite_affixes_combat_statuses_and_resists_are_deterministic() -> void:
	var sim := VCSim.new()
	sim.new_game(4444, "brujah")
	var elite: SimEntity = sim.spawn_npc("swat", Vector2(520.0, 576.0), { "state": "guard", "elite": "juggernaut", "resist": { "blood": 0.50 } })
	assert_eq(String(elite.tags.get("elite", "")), "juggernaut", "elite affix was not applied")
	assert_true(elite.max_hp > 300.0, "elite HP multiplier missing")
	elite.apply_status("fear", 90)
	assert_false(elite.has_status("fear"), "warded elite accepted fear")
	var physical_hp := elite.hp
	var physical_damage: float = sim.damage_entity(sim.player, elite, 100.0, { "crit_chance": 0.0, "damage_type": "physical" })
	elite.hp = physical_hp
	var blood_damage: float = sim.damage_entity(sim.player, elite, 100.0, { "crit_chance": 0.0, "damage_type": "blood" })
	assert_true(blood_damage < physical_damage, "damage-type resist did not reduce blood damage")
	elite.apply_status("weaken", 120, { "amount": 0.50 })
	var weakened_damage: float = sim.damage_entity(sim.player, elite, 100.0, { "crit_chance": 0.0, "damage_type": "physical" })
	assert_true(weakened_damage > physical_damage, "weaken status did not shred armor")
	var hp_after_hit: float = elite.hp
	elite.apply_status("bleed", 90, { "dps": 12.0, "damage_type": "blood", "src_id": sim.player.id })
	_tick_for(sim, 30)
	assert_true(elite.hp < hp_after_hit, "bleed status did not tick deterministic DoT")
	sim.queue_free()

func test_ai_uses_pathfinding_and_thrall_follow_attacks() -> void:
	var sim := VCSim.new()
	sim.new_game(5150, "brujah")
	var hunter: SimEntity = sim.spawn_npc("hunter", Vector2(704.0, 320.0), { "state": "chase", "hostile_to_player": true })
	assert_false(sim.world.segment_clear(hunter.pos, sim.player.pos), "test setup needs an occluded route")
	var start_dist: float = hunter.pos.distance_to(sim.player.pos)
	_tick_for(sim, 90)
	assert_true(hunter.pos.distance_to(sim.player.pos) < start_dist, "path-backed hunter did not close distance")
	var hunter_path: Array = hunter.behaviour.get("path")
	assert_true(hunter_path.size() > 0 or sim.world.segment_clear(hunter.pos, sim.player.pos), "hunter never built or completed a path")
	var target: SimEntity = sim.spawn_npc("thug", sim.player.pos + Vector2(135.0, 0.0), { "state": "guard", "hostile_to_player": true })
	var thrall: SimEntity = sim.spawn_npc("thrall", sim.player.pos + Vector2(-80.0, 0.0), { "state": "follow" })
	thrall.faction = "player"
	_tick_for(sim, 160)
	assert_true(target.hp < target.max_hp, "follow-state thrall did not attack a hostile")
	sim.queue_free()

func test_body_carry_and_evidence_heat_are_authoritative() -> void:
	var sim := VCSim.new()
	sim.new_game(7001, "brujah")
	var body_pos: Vector2 = sim.world.nearest_open_around(sim.world.named_points["exit"], 180.0, 260.0, 41)
	sim.player.pos = body_pos + Vector2(-28.0, 0.0)
	var body: SimEntity = sim.spawn_npc("ped", body_pos, { "state": "guard" })
	body.downed = true
	body.ai_state = "downed"
	body.perception_state = "helpless"
	body.tags["player_body"] = true
	body.tags["body_discovered"] = false
	_apply_action(sim, InputAction.Kind.INTERACT)
	assert_eq(int(sim.player.behaviour.get("carrying_body_id")), body.id, "interact did not pick up the nearby body")
	assert_true(bool(body.tags.get("carried", false)), "body was not marked as carried")
	_apply_action(sim, InputAction.Kind.MOVE, Vector2(1.0, 0.0))
	_tick_for(sim, 20)
	assert_true(body.pos.distance_to(sim.player.pos) < 48.0, "carried body did not follow player state")
	_apply_action(sim, InputAction.Kind.ATTACK)
	assert_null(sim.player.current_action, "player started a melee action while carrying a body")
	_apply_action(sim, InputAction.Kind.INTERACT)
	assert_eq(int(sim.player.behaviour.get("carrying_body_id")), 0, "second interact did not drop the body")
	var witness: SimEntity = sim.spawn_npc("ped", body.pos + Vector2(36.0, 0.0), { "state": "guard" })
	var heat_before := sim.heat
	_tick_for(sim, 2)
	assert_true(bool(body.tags.get("body_discovered", false)), "nearby witness did not discover the dropped evidence")
	assert_true(sim.heat > heat_before, "body discovery did not raise Heat")
	assert_true(_has_cue(sim, "body.discovered"), "body discovery cue missing")
	assert_true(witness.ai_state == "flee" or witness.perception_state == "afraid", "witness did not react to discovered evidence")
	sim.queue_free()

func test_business_legend_progress_and_domain_caps() -> void:
	var sim := VCSim.new()
	sim.new_game(8128, "brujah")
	var meta: SimMeta = sim.meta
	meta.money = 20000
	assert_true(meta.progress_is_revealed("move"), "initial progress did not reveal movement")
	assert_true(meta.buy_business("bloodbank", sim), "business purchase failed")
	assert_eq(int(meta.businesses["bloodbank"].get("tier", -1)), 0, "new business tier should start at zero")
	assert_true(meta.progress_is_revealed("businesses"), "business progress flag was not revealed")
	var base_income: Dictionary = meta.collect_business_income()
	assert_true(int(base_income.get("vitae", 0)) >= 16, "owned blood bank did not produce vitae")
	assert_true(meta.upgrade_business("bloodbank", sim), "business upgrade failed")
	var upgraded_income: Dictionary = meta.collect_business_income()
	assert_true(int(upgraded_income.get("cash", 0)) > int(base_income.get("cash", 0)), "business tier did not multiply cash")
	assert_true(meta.claim_domain("old_town", sim), "first domain should fit Fledgling cap")
	assert_false(meta.contest_domain("docks", sim), "domain contest ignored legend cap")
	meta.add_legend(8, sim, "test")
	assert_true(meta.legend_domain_cap() >= 2, "legend title did not raise domain cap")
	assert_true(meta.contest_domain("docks", sim), "raised legend cap did not permit another contest")
	assert_true(_has_cue(sim, "legend.changed"), "legend cue missing")
	var restored_meta := SimMeta.new()
	assert_true(restored_meta.restore(meta.serialize()), "meta restore rejected business/legend save data")
	assert_eq(restored_meta.legend, meta.legend, "legend did not survive meta restore")
	assert_true(restored_meta.progress_is_revealed("businesses"), "progress flags did not survive meta restore")
	assert_eq(int(restored_meta.businesses["bloodbank"].get("tier", -1)), 1, "business tier did not survive meta restore")
	sim.queue_free()

func test_nemesis_escape_return_and_death_are_persistent_backend_state() -> void:
	var sim := VCSim.new()
	sim.new_game(9911, "brujah")
	var hunter: SimEntity = sim.spawn_npc("hunter", sim.player.pos + Vector2(150.0, 0.0), { "state": "guard", "hostile_to_player": true })
	sim.damage_entity(sim.player, hunter, 9999.0, { "crit_chance": 0.0, "damage_type": "blood", "force_nemesis": true })
	assert_false(hunter.dead, "forced nemesis escape still killed the hunter")
	assert_eq(sim.meta.nemeses.size(), 1, "nemesis record was not saved")
	assert_true(_has_cue(sim, "nemesis.escaped"), "nemesis escape cue missing")
	var restored_meta := SimMeta.new()
	assert_true(restored_meta.restore(sim.meta.serialize()), "meta restore rejected nemesis save data")
	assert_eq(restored_meta.nemeses.size(), 1, "nemesis record did not survive meta restore")
	assert_eq(String(restored_meta.nemeses[0].get("resistType", "")), "blood", "nemesis adaptive damage type did not survive restore")
	var returning: SimEntity = sim.meta.maybe_inject_nemesis(sim)
	assert_not_null(returning, "saved nemesis did not reinject")
	assert_true(returning.tags.has("nemesis_name"), "returning hunter was not tagged as nemesis")
	assert_true((returning.tags.get("resist", {}) as Dictionary).has("blood"), "returning nemesis did not adapt to last damage type")
	sim.damage_entity(sim.player, returning, 99999.0, { "crit_chance": 0.0, "damage_type": "physical" })
	assert_true(returning.dead, "returning nemesis survived lethal damage")
	assert_true(sim.meta.nemeses.is_empty(), "nemesis record was not cleared on death")
	assert_true(_has_cue(sim, "nemesis.dead"), "nemesis death cue missing")
	sim.queue_free()

func test_emergent_events_domain_raids_and_childer_backend() -> void:
	var sim := VCSim.new()
	sim.new_game(42424, "brujah")
	var meta: SimMeta = sim.meta
	meta.legend = 300
	meta.money = 5000
	assert_true(meta.claim_domain("old_town", sim), "test setup could not claim a domain")
	var terror_before := float(meta.district_state["old_town"].get("terror", 0.0))
	assert_true(meta.trigger_event("domainraid", sim), "domain raid event did not spawn")
	assert_eq(meta.pending_raids.size(), 1, "domain raid did not register a pending deadline")
	var raid_id := int(meta.pending_raids[0].get("event_id", 0))
	assert_true(_count_tagged_int(sim, "raid_id", raid_id) >= 4, "raid did not tag spawned raiders")
	meta.pending_raids[0]["deadline_tick"] = sim.tick + 1
	_tick_for(sim, 2)
	assert_true(float(meta.district_state["old_town"].get("terror", 0.0)) > terror_before, "unanswered raid did not raise domain terror")
	assert_true(_has_cue(sim, "domain.raid_failed"), "raid failure cue missing")
	assert_true(meta.trigger_event("bloodhunt", sim), "blood hunt event did not spawn")
	assert_true(_has_cue(sim, "event.bloodhunt"), "blood hunt cue missing")
	var noble: SimEntity = sim.spawn_npc("ped", sim.player.pos + Vector2(48.0, 0.0), { "state": "guard" })
	noble.victim_type = "noble"
	sim.player.behaviour.set("blood", 100.0)
	var childe: Dictionary = meta.embrace(noble.id, sim)
	assert_false(childe.is_empty(), "valid noble embrace did not create a childe")
	assert_true(noble.dead, "embraced target was not removed from runtime")
	assert_true(meta.progress_is_revealed("childer"), "childer progress flag was not revealed")
	var ally: SimEntity = meta.summon_coterie(int(childe["id"]), sim)
	assert_not_null(ally, "summon_coterie did not spawn an ally")
	assert_eq(ally.faction, "player", "summoned coterie member was not allied")
	assert_true(bool(ally.tags.get("childe", false)), "summoned childe did not carry childe tag")
	var previous_level := int(meta.coterie[meta.coterie.size() - 1].get("level", 0))
	for _i in range(16):
		assert_true(meta.coterie_ally_kill(ally, sim), "ally kill did not route to coterie XP")
	assert_true(int(meta.coterie[meta.coterie.size() - 1].get("level", 0)) > previous_level, "coterie ally XP did not level the childe")
	var restored_meta := SimMeta.new()
	assert_true(restored_meta.restore(meta.serialize()), "meta restore rejected event/childe save data")
	assert_eq(restored_meta.active_events.size(), meta.active_events.size(), "active event state did not survive restore")
	assert_true(_has_cue(sim, "coterie.embraced"), "embrace cue missing")
	sim.queue_free()

func _apply_action(sim: VCSim, kind: int, vector: Vector2 = Vector2.ZERO, action_id: String = "", held: bool = false) -> void:
	var action := InputAction.new(kind)
	action.vector = vector
	action.action_id = action_id
	action.held = held
	sim.apply_input(action)

func _tick_for(sim: VCSim, ticks: int) -> void:
	for _i in range(ticks):
		sim.tick_sim(DT)

func _has_cue(sim: VCSim, cue_id: String) -> bool:
	for rec in sim.cue_events:
		if String(rec["id"]) == cue_id:
			return true
	return false

func _first_tagged(sim: VCSim, tag_id: String, tag_value: String) -> SimEntity:
	for e in sim.entities:
		if e != null and e.tags.has(tag_id) and String(e.tags[tag_id]) == tag_value:
			return e
	return null

func _count_tagged_int(sim: VCSim, tag_id: String, tag_value: int) -> int:
	var count := 0
	for e in sim.entities:
		if e != null and int(e.tags.get(tag_id, -1)) == tag_value:
			count += 1
	return count

func _feed_mission() -> Dictionary:
	return {
		"id": 77,
		"type": "feed",
		"name": "Backend Feed",
		"icon": "feed",
		"color": "#c0303a",
		"level": 1,
		"need": 1,
		"progress": 0,
		"state": "available",
		"targetName": "Probe",
		"modifier": { "id": "none", "bonus": 0.0 },
		"reward": { "xp": 10, "money": 20, "itemChance": 0.0 },
		"time_limit": 0.0,
		"timer": 0.0,
		"markers": [],
	}
