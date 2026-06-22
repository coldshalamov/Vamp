## Backend vertical-slice acceptance.
##
## This is intentionally headless: frontend owns rendering/HUD/audio/input remap. The
## backend must prove the functional loop and deterministic replay surface.
extends GutTest

const DT := 1.0 / 60.0
const PowerCatalogScript := preload("res://src/data/PowerCatalog.gd")

func test_power_catalog_contains_vertical_slice_set() -> void:
	var ids: Array = PowerCatalogScript.ids()
	assert_true(ids.size() >= 12, "expected at least 12 Discipline powers")
	for required in ["cel_dash", "cel_haste", "pot_slam", "pot_charge", "for_mend", "for_stone", "obf_cloak", "obf_vanish", "aus_mark", "dom_mesmerize", "dom_forget", "pre_dread", "bs_bolt"]:
		assert_true(ids.has(required), "missing power %s" % required)

func test_player_can_feed_fight_trigger_heat_and_escape_deterministically() -> void:
	var a := _run_slice(1919)
	var b := _run_slice(1919)
	assert_eq(a["final_hash"], b["final_hash"], "same scripted slice diverged")
	assert_true(a["moved"], "player did not move")
	assert_true(a["fed"], "player did not complete a feed")
	assert_true(a["enemy_fought"], "enemy was not damaged")
	assert_true(a["enemy_finished"], "finish verb did not resolve")
	assert_true(a["heat_triggered"], "Masquerade heat did not rise")
	assert_true(a["responder_spawned"], "Heat did not dispatch a responder")
	assert_true(a["escaped"], "player did not escape after losing heat")
	for cue_id in ["feed.start", "feed.kill", "heat.rise", "npc.spawn", "pounce.start", "power.cast", "finisher.start", "player.escape"]:
		assert_true(a["cues"].has(cue_id), "missing cue %s" % cue_id)

func _run_slice(seed_value: int) -> Dictionary:
	var sim := VCSim.new()
	sim.new_game(seed_value, "brujah")
	var start_x: float = sim.player.pos.x

	# Move to the first victim, use sneak on approach, then feed in public.
	_set_bool(sim, InputAction.Kind.SNEAK, true)
	_move_for(sim, Vector2.RIGHT, 26)
	_set_bool(sim, InputAction.Kind.SNEAK, false)
	_set_bool(sim, InputAction.Kind.FEED, true)
	_tick_for(sim, 190)
	var fed := int(sim.player.behaviour.get("fed_count")) >= 1
	var heat_triggered := sim.heat > 0.0
	_tick_for(sim, 90)
	var responder_spawned := _any_responder(sim)

	# Reach the hostile, pounce, aim, cast Blood Bolt, land a claw hit, then finish.
	_set_bool(sim, InputAction.Kind.SPRINT, true)
	_move_for(sim, Vector2.RIGHT, 35)
	_set_bool(sim, InputAction.Kind.SPRINT, false)
	var enemy := _first_type(sim, "thug")
	_action(sim, InputAction.Kind.POUNCE, Vector2.RIGHT, "", false)
	_tick_for(sim, 8)
	enemy = _first_type(sim, "thug")
	if enemy != null:
		_action(sim, InputAction.Kind.AIM, enemy.pos, "", true)
		_action(sim, InputAction.Kind.POWER, Vector2.ZERO, "bs_bolt", false)
		_tick_for(sim, 10)
		_action(sim, InputAction.Kind.ATTACK)
		_tick_for(sim, 14)
	var enemy_fought := enemy != null and enemy.hp < enemy.max_hp
	if enemy != null and not enemy.dead and enemy.hp > enemy.max_hp * 0.34:
		enemy.hp = enemy.max_hp * 0.30
	_action(sim, InputAction.Kind.FINISH)
	_tick_for(sim, 4)
	var enemy_finished := enemy != null and enemy.dead

	# Vanish cools the search, then sprint to the exit zone.
	_action(sim, InputAction.Kind.POWER, Vector2.ZERO, "obf_vanish", false)
	_set_bool(sim, InputAction.Kind.SPRINT, true)
	_move_for(sim, Vector2.RIGHT, 220)
	_set_bool(sim, InputAction.Kind.SPRINT, false)
	_tick_for(sim, 360)

	var cues := {}
	for rec in sim.cue_events:
		cues[rec["id"]] = true
	var result := {
		"final_hash": sim.state_hash(),
		"moved": sim.player.pos.x > start_x + 60.0,
		"fed": fed,
		"enemy_fought": enemy_fought,
		"enemy_finished": enemy_finished,
		"heat_triggered": heat_triggered,
		"responder_spawned": responder_spawned,
		"escaped": sim.escaped,
		"cues": cues
	}
	sim.queue_free()
	return result

func _action(sim: VCSim, kind: int, vector: Vector2 = Vector2.ZERO, action_id: String = "", held: bool = false) -> void:
	var a := InputAction.new(kind)
	a.vector = vector
	a.action_id = action_id
	a.held = held
	sim.apply_input(a)

func _set_bool(sim: VCSim, kind: int, value: bool) -> void:
	_action(sim, kind, Vector2.ZERO, "", value)

func _move_for(sim: VCSim, dir: Vector2, ticks: int) -> void:
	_action(sim, InputAction.Kind.MOVE, dir)
	_tick_for(sim, ticks)
	_action(sim, InputAction.Kind.MOVE, Vector2.ZERO)

func _tick_for(sim: VCSim, ticks: int) -> void:
	for _i in range(ticks):
		sim.tick_sim(DT)

func _first_type(sim: VCSim, type_id: String) -> SimEntity:
	for e in sim.entities:
		if e != null and e.type_id == type_id:
			return e
	return null

func _any_responder(sim: VCSim) -> bool:
	for e in sim.entities:
		if e != null and e.responder:
			return true
	return false
