## test_tutorial_director.gd — smoke test for the one-time onboarding director.
##
## Confirms: (1) the first processed frame in an active run arms the spawn hint; (2) each cue-driven
## hint flag flips on its first cue and STAYS flipped (firing the same cue twice is a harmless no-op,
## no crash, no re-show); (3) the proximity poll arms the feed hint when a living NPC is in range; and
## (4) nothing crashes when Sim has no player (title-screen guard). No camera is required.
extends GutTest

const TutorialScript := preload("res://src/ui/TutorialDirector.gd")


func after_each() -> void:
	if Sim != null:
		Sim.player = null
		Sim.entities.clear()
		Sim.world = null
		Sim.meta = null
		Sim.cue_events.clear()
		Sim.cue_events_this_tick.clear()


func _make_director() -> Node:
	var td := TutorialScript.new()
	add_child_autofree(td)   # fires _ready(): connects to CueBus.cue_emitted
	return td


func test_spawn_hint_arms_on_first_frame() -> void:
	Sim.new_game(1, "brujah")
	var td := _make_director()
	assert_false(td.has_seen_spawn, "spawn hint not armed before processing")
	td._process(0.016)
	assert_true(td.has_seen_spawn, "first processed frame arms the spawn hint")
	# Re-processing must not re-arm or crash.
	td._process(0.016)
	assert_true(td.has_seen_spawn, "spawn flag stays true on subsequent frames")


func test_noop_without_player() -> void:
	# Title-screen guard: no Sim.player => no flags flip, no crash.
	Sim.player = null
	var td := _make_director()
	td._process(0.016)
	assert_false(td.has_seen_spawn, "spawn hint does not arm without a player (title screen)")
	# A stray cue on the title screen must also be ignored.
	CueBus.emit_cue("feed.end", { "entity_id": 1, "blood_total": 5.0 })
	assert_false(td.has_seen_first_feed, "feed hint does not arm without a player")


func test_cue_driven_hints_fire_once_each() -> void:
	Sim.new_game(1, "brujah")
	var td := _make_director()

	# #3 first feed. feed.end / feed.spare / feed.kill share one match arm; fire all three so the
	# aliases are exercised (the later two no-op on the already-set flag, proving idempotency).
	CueBus.emit_cue("feed.end", { "entity_id": 1, "blood_total": 7.0 })
	assert_true(td.has_seen_first_feed, "feed.end arms the first-feed hint")
	CueBus.emit_cue("feed.spare", { "entity_id": 0, "target_id": 5, "pos": Vector2.ZERO, "blood": 4.0, "blood_gained": 4.0, "humanity_kept": true, "gulp_bonus": 0.0, "resonance": "sanguine" })
	CueBus.emit_cue("feed.kill", { "entity_id": 0, "target_id": 6, "pos": Vector2.ZERO, "blood": 8.0, "blood_gained": 8.0, "humanity_lost": 1.0, "resonance": "choleric" })
	assert_true(td.has_seen_first_feed, "feed.spare / feed.kill aliases do not crash or reset the flag")

	# #4 first ability.
	CueBus.emit_cue("power.cast", { "power_id": "blood_bolt", "name": "Blood Bolt", "pos": Vector2.ZERO, "discipline": "thaumaturgy", "color": "ff0000", "cast_type": "projectile" })
	assert_true(td.has_seen_first_ability, "power.cast arms the first-ability hint")

	# #5 first combo.
	CueBus.emit_cue("combo.trigger", { "entity_id": 0, "target_id": 9, "combo_name": "ignite", "bonus_damage": 12.0, "pos": Vector2.ZERO })
	assert_true(td.has_seen_first_combo, "combo.trigger arms the first-combo hint")

	# #6 first kill (via npc.death; kill/enemy.death are aliases).
	CueBus.emit_cue("npc.death", { "entity_id": 9, "type": "civ", "pos": Vector2.ZERO, "finisher": false })
	assert_true(td.has_seen_first_kill, "npc.death arms the first-kill hint")

	# Fire every cue a SECOND time: flags remain true, nothing errors, no re-show.
	CueBus.emit_cue("feed.end", { "entity_id": 1, "blood_total": 9.0 })
	CueBus.emit_cue("power.cast", { "power_id": "blood_bolt", "name": "Blood Bolt", "pos": Vector2.ZERO, "discipline": "thaumaturgy", "color": "ff0000", "cast_type": "projectile" })
	CueBus.emit_cue("combo.trigger", { "entity_id": 0, "target_id": 9, "combo_name": "ignite", "bonus_damage": 12.0, "pos": Vector2.ZERO })
	CueBus.emit_cue("kill", { "entity_id": 9, "type": "civ", "pos": Vector2.ZERO, "finisher": false })
	CueBus.emit_cue("enemy.death", { "entity_id": 9, "type": "thug", "pos": Vector2.ZERO, "finisher": true })
	assert_true(td.has_seen_first_feed and td.has_seen_first_ability and td.has_seen_first_combo and td.has_seen_first_kill,
		"all cue-driven flags stay true after repeat cues (idempotent, no re-show)")
	pass_test("repeat cues fired without crashing")


func test_feed_proximity_hint_arms_when_npc_in_range() -> void:
	Sim.new_game(1, "brujah")
	var td := _make_director()
	# Arm the spawn hint first (#2 is gated behind #1).
	td._process(0.016)
	assert_true(td.has_seen_spawn, "spawn hint armed")
	# Place a living NPC well within FEED_HINT_RANGE of the player.
	var npc := Sim.spawn_npc("civ", Sim.player.pos + Vector2(40.0, 0.0), {})
	assert_not_null(npc, "spawned a feedable NPC")
	td._process(0.016)
	assert_true(td.has_seen_feed_hint, "feed hint arms when a living NPC is within range")
