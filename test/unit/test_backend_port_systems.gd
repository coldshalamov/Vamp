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
