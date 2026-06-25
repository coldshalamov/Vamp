## test_feeding_hud.gd — smoke test for the FeedingHUD feeding-experience overlay.
##
## Drives the full feed beat sequence through CueBus + the polled player state and asserts the
## node renders without crashing: resonance reveal (feed.start), progress bands + meter pulse
## (polled feed_progress via feed.progress), choice prompt (feed.choice), and the kill/spare
## outcome numbers (feed.kill / feed.spare), then clears on feed.end. Camera is null in headless;
## the node must tolerate that.
extends GutTest

var _hud: FeedingHUD = null


func before_each() -> void:
	_hud = FeedingHUD.new()
	add_child_autofree(_hud)
	# _ready() runs on add_child; pump one frame so it's fully in-tree.
	await get_tree().process_frame


func after_each() -> void:
	if Sim != null:
		Sim.player = null
		Sim.entities.clear()
		Sim.world = null
		Sim.meta = null
		Sim.cue_events.clear()
		Sim.cue_events_this_tick.clear()


func _fire(event_id: String, payload: Dictionary) -> void:
	if CueBus != null:
		CueBus.emit_cue(event_id, payload)


func test_noop_without_player_does_not_crash() -> void:
	# With no Sim.player the overlay must idle silently (it persists over the title screen).
	assert_null(Sim.player, "no player before new_game")
	for i in range(3):
		await get_tree().process_frame
	assert_false(_hud._feeding, "not feeding without a player")
	pass_test("idle with no player, no crash")


func test_full_feed_sequence_no_crash() -> void:
	Sim.new_game(1, "brujah")
	assert_not_null(Sim.player, "player exists after new_game")

	# feed.start — resonance reveal (choleric -> orange / +25% Melee).
	var target_id: int = 0
	for e in Sim.entities:
		if e != null and e.kind == "npc":
			target_id = e.id
			break
	_fire("feed.start", {
		"entity_id": Sim.player.id, "target_id": target_id,
		"pos": Sim.player.pos, "hunger": 3, "lethal": false,
		"seize": true, "resonance": "choleric",
	})
	await get_tree().process_frame
	assert_eq(_hud._resonance, "choleric", "resonance captured from feed.start")

	# Walk progress through the three bands by driving the polled field + the cue.
	for pct in [0.2, 0.5, 0.85]:
		Sim.player.behaviour.feeding_target_id = (target_id if target_id != 0 else 1)
		Sim.player.behaviour.feed_progress = pct
		_fire("feed.progress", {
			"entity_id": Sim.player.id, "target_id": target_id,
			"progress_pct": pct, "blood_gained": pct * 80.0, "resonance": "choleric",
		})
		await get_tree().process_frame

	assert_true(_hud._feeding, "feeding active while polled target is set")
	assert_eq(_hud._victim_state(0.2), "Struggling", "low band label")
	assert_eq(_hud._victim_state(0.5), "Weakening", "mid band label")
	assert_eq(_hud._victim_state(0.85), "Fading", "high band label")

	# feed.choice — choice prompt latches on.
	_fire("feed.choice", {
		"entity_id": Sim.player.id, "target_id": target_id,
		"can_spare": true, "blood_pct": 0.72,
	})
	await get_tree().process_frame
	assert_true(_hud._choice_active, "choice prompt armed by feed.choice")

	# feed.spare — green +N Blood popup.
	_fire("feed.spare", {
		"entity_id": Sim.player.id, "target_id": target_id, "pos": Sim.player.pos,
		"blood": 70.0, "blood_gained": 70.0, "humanity_kept": true,
		"gulp_bonus": 0.0, "resonance": "choleric",
	})
	await get_tree().process_frame
	assert_gt(_hud._outcomes.size(), 0, "spare spawned an outcome popup")

	# feed.kill — red +N Blood + Humanity -X.X (two labels).
	_fire("feed.kill", {
		"entity_id": Sim.player.id, "target_id": target_id, "pos": Sim.player.pos,
		"blood": 100.0, "blood_gained": 100.0, "humanity_lost": 0.5, "resonance": "choleric",
	})
	await get_tree().process_frame
	assert_gte(_hud._outcomes.size(), 2, "kill spawned blood + humanity popups")

	# feed.end — clear meter + reset feed state.
	Sim.player.behaviour.feeding_target_id = 0
	Sim.player.behaviour.feed_progress = 0.0
	_fire("feed.end", { "entity_id": Sim.player.id, "blood_total": 120.0 })
	await get_tree().process_frame
	assert_false(_hud._feeding, "feed cleared on feed.end")
	assert_eq(_hud._resonance, "", "resonance cleared on feed.end")

	# Let outcome popups age out — they should free without error.
	for i in range(4):
		await get_tree().process_frame
	pass_test("full feed sequence completed without crash")


func test_reduced_motion_static_meter_no_crash() -> void:
	# Reduced motion: no heartbeat pulse advance; the meter is static but still draws.
	var prev := UIManager.is_reduced_motion() if UIManager != null else false
	if UIManager != null:
		UIManager.theme_resource.reduced_motion = true
	Sim.new_game(2, "brujah")
	Sim.player.behaviour.feeding_target_id = 999
	Sim.player.behaviour.feed_progress = 0.5
	for i in range(3):
		await get_tree().process_frame
	assert_eq(_hud._pulse_phase, 0.0, "pulse phase frozen under reduced motion")
	if UIManager != null:
		UIManager.theme_resource.reduced_motion = prev
	pass_test("reduced-motion static meter, no crash")
