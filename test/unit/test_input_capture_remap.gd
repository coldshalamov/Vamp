## test_input_capture_remap.gd — Rebind.capture() + round-trip persistence (acceptance #5).
##
## Two concerns:
##   1. capture() translates real Godot InputEvents into the right InputAction kinds, so the
##      player can actually move / attack / feed / dash / cast. This is the input half of the
##      stop condition: "can be played start-to-finish."
##   2. Input remapping persists: rebind an action -> save -> reload a fresh Rebind instance's
##      settings -> the new binding is restored. (Acceptance criterion #5.)
##
## We drive the input map directly with synthetic InputEvents rather than the OS, so the
## tests run headless and deterministically. Rebind is the live autoload; for the reload
## half we point a second instance at the same settings file.
extends GutTest

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_BINDINGS := "bindings"


func before_each() -> void:
	# Ensure the live autoload has default bindings registered and capture is not mid-remap.
	if Rebind != null:
		Rebind.set_capturing(false)


func after_each() -> void:
	# Flush any held keys from the Input singleton so tests don't poison each other.
	for action in ["move_up", "move_down", "move_left", "move_right", "feed", "sprint", "sneak"]:
		if InputMap.has_action(action):
			Input.action_release(action)


func _press(action: String) -> InputEventKey:
	# Build a key press matching the action's current primary binding.
	assert_true(InputMap.has_action(action), "action exists: %s" % action)
	var events := InputMap.action_get_events(action)
	assert_gt(events.size(), 0, "action has a binding: %s" % action)
	var ev := (events[0] as InputEventKey).duplicate()
	ev.pressed = true
	return ev


func _feed_held(action: String) -> InputEventKey:
	# Feed a key press into the Input singleton so is_action_pressed() reflects it during the
	# next capture() call. Needed for movement aggregation + hold verbs (feed/sprint/sneak).
	var ev := _press(action)
	Input.parse_input_event(ev)
	return ev


func test_capture_translates_move_keys_into_move_intent() -> void:
	# Movement aggregates held keys via Input.is_action_pressed, so we must feed the press.
	_feed_held("move_right")
	# Press a move key to trigger capture's movement branch.
	var ev := _press("move_right")
	var a := Rebind.capture(ev)
	assert_not_null(a, "capture returned an action for move key")
	assert_eq(a.kind, InputAction.Kind.MOVE, "move key -> MOVE intent")
	Input.action_release("move_right")


func test_capture_translates_attack_into_attack_intent() -> void:
	var ev := _press("attack")
	var a := Rebind.capture(ev)
	assert_not_null(a, "capture returned an action for attack")
	assert_eq(a.kind, InputAction.Kind.ATTACK, "attack key -> ATTACK intent")


func test_capture_translates_feed_into_feed_intent_with_held() -> void:
	_feed_held("feed")
	var ev := _press("feed")
	var a := Rebind.capture(ev)
	assert_eq(a.kind, InputAction.Kind.FEED, "feed key -> FEED intent")
	assert_true(a.held, "feed is a hold verb; held=true on press")
	Input.action_release("feed")


func test_capture_translates_dash_into_dash_intent() -> void:
	var ev := _press("dash")
	var a := Rebind.capture(ev)
	assert_eq(a.kind, InputAction.Kind.DASH, "dash key -> DASH intent")


func test_capture_translates_slot_keys_into_power_intent() -> void:
	# Each of slot_1..4 must produce a POWER intent with action_id "slot_N".
	for slot_idx in range(1, 5):
		var action_name := "slot_%d" % slot_idx
		var ev := _press(action_name)
		var a := Rebind.capture(ev)
		assert_not_null(a, "capture returned an action for %s" % action_name)
		assert_eq(a.kind, InputAction.Kind.POWER, "%s -> POWER intent" % action_name)
		assert_eq(a.action_id, action_name, "%s power id is the slot name" % action_name)


func test_capture_returns_null_while_remapping() -> void:
	# While the remap UI is listening for the next input, gameplay capture must be suppressed
	# so the key being captured doesn't also fire a verb.
	Rebind.set_capturing(true)
	var ev := _press("attack")
	assert_null(Rebind.capture(ev), "capture suppressed during remap capture")
	Rebind.set_capturing(false)


func test_capture_returns_null_for_unmapped_event() -> void:
	# A key bound to nothing (e.g. an arbitrary physical keycode) must not crash or produce
	# a spurious intent.
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F12   # not bound to any gameplay action
	ev.pressed = true
	assert_null(Rebind.capture(ev), "unmapped key -> null")


# ---------------------------------------------------------------- remap round-trip

func test_rebind_persists_and_reloads() -> void:
	# Acceptance #5: rebind -> save -> reload -> binding persists.
	# 1. Rebind "interact" to the Q key.
	var q := InputEventKey.new()
	q.physical_keycode = KEY_Q
	var original := Rebind.label_for("interact")
	Rebind.rebind("interact", q)
	assert_eq(Rebind.label_for("interact"), OS.get_keycode_string(KEY_Q),
		"rebind updated the live binding label to Q")

	# 2. The settings file must now carry the serialized Q binding.
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(SETTINGS_PATH), OK, "settings file exists after rebind")
	assert_true(cfg.has_section(SECTION_BINDINGS), "bindings section present")
	assert_true(cfg.has_section_key(SECTION_BINDINGS, "interact"), "interact persisted")

	# 3. Simulate a restart: reload a fresh Rebind's bindings from the same file and confirm
	#    the Q binding is restored into Godot's InputMap.
	var fresh := Rebind.__fresh_for_test(SETTINGS_PATH)
	var restored: String = fresh.label_for("interact")
	assert_eq(restored, OS.get_keycode_string(KEY_Q),
		"binding restored to Q after reload (round-trip): got %s" % restored)

	# 4. The InputMap itself must accept a Q press as "interact".
	var qpress := InputEventKey.new()
	qpress.physical_keycode = KEY_Q
	qpress.pressed = true
	assert_true(qpress.is_action("interact"), "Q press is recognized as interact after reload")

	# 5. Restore the original binding so this test doesn't poison others.
	var orig_key := InputEventKey.new()
	# "interact" default is KEY_E.
	orig_key.physical_keycode = KEY_E
	Rebind.rebind("interact", orig_key)
	assert_eq(Rebind.label_for("interact"), OS.get_keycode_string(KEY_E),
		"interact restored to default E")
	# Clean up the test binding from disk.
	_erase_test_binding()


func _erase_test_binding() -> void:
	# Ensure no stray test bindings leak into the persisted file.
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section_key(SECTION_BINDINGS, "interact"):
		cfg.erase_section_key(SECTION_BINDINGS, "interact")
		cfg.save(SETTINGS_PATH)
