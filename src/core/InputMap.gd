## InputMap.gd — runtime input remapping.
##
## Loads bindings from saved settings, falls back to the project.godot defaults, and exposes
## a single capture() entry point that the render layer calls each _process to translate
## Godot InputEvents into InputAction intents for Sim.apply_input().
##
## All accessibility remapping routes through here: full keybind changes, gamepad mapping,
## hold-vs-toggle, and (later) one-handed presets.
##
extends Node
# NOTE: no class_name — this script IS the `Rebind` autoload singleton.
# Named `Rebind` (not InputMap) to avoid clashing with Godot's built-in InputMap class.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_BINDINGS := "bindings"   # persisted per-action InputEvents
const SECTION_INPUT := "input"         # misc input prefs

var bindings: Dictionary = {}    # action_name (String) -> InputEvent (current primary)
var gamepad_enabled: bool = true
var _capturing: bool = false     # set true by the remap UI while listening for next input

# Human-readable labels for the verbs (localization keys). The remap UI shows these
# instead of raw action names so the vision/translation pass owns the strings.
const ACTION_LABELS := {
	"move_up": "ACTION_MOVE_UP",
	"move_down": "ACTION_MOVE_DOWN",
	"move_left": "ACTION_MOVE_LEFT",
	"move_right": "ACTION_MOVE_RIGHT",
	"attack": "ACTION_ATTACK",
	"feed": "ACTION_FEED",
	"dash": "ACTION_DASH",
	"interact": "ACTION_INTERACT",
	"slot_1": "ACTION_SLOT_1",
	"slot_2": "ACTION_SLOT_2",
	"slot_3": "ACTION_SLOT_3",
	"slot_4": "ACTION_SLOT_4",
	"pause": "ACTION_PAUSE",
}

# One-handed / lefty presets. Each maps an action to the SAME keycode list shape as
# DEFAULTS. Only keyboard presets ship for the slice; gamepad uses the device's own
# remap surface, so gamepad bindings pass through unchanged here.
const PRESET_DEFAULT := "default"
const PRESET_LEFTY := "lefty"
const PRESET_ONE_HANDED := "one_handed"
const PRESETS := {
	PRESET_DEFAULT: {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"attack": [KEY_SPACE], "feed": [KEY_F], "dash": [KEY_SHIFT],
		"interact": [KEY_E], "slot_1": [KEY_1], "slot_2": [KEY_2],
		"slot_3": [KEY_3], "slot_4": [KEY_4], "pause": [KEY_ESCAPE],
	},
	PRESET_LEFTY: {
		# Mirror to the numpad/arrow cluster so a left-handed mouse user can drive verbs left.
		"move_up": [KEY_I, KEY_UP], "move_down": [KEY_K, KEY_DOWN],
		"move_left": [KEY_J, KEY_LEFT], "move_right": [KEY_L, KEY_RIGHT],
		"attack": [KEY_U], "feed": [KEY_O], "dash": [KEY_PERIOD],
		"interact": [KEY_SEMICOLON], "slot_1": [KEY_7], "slot_2": [KEY_8],
		"slot_3": [KEY_9], "slot_4": [KEY_0], "pause": [KEY_ESCAPE],
	},
	PRESET_ONE_HANDED: {
		# Cluster every verb under the left hand so the game is playable with one hand.
		"move_up": [KEY_W], "move_down": [KEY_S],
		"move_left": [KEY_A], "move_right": [KEY_D],
		"attack": [KEY_Q], "feed": [KEY_E], "dash": [KEY_SPACE],
		"interact": [KEY_R], "slot_1": [KEY_1], "slot_2": [KEY_2],
		"slot_3": [KEY_3], "slot_4": [KEY_4], "pause": [KEY_ESCAPE],
	},
}

func _ready() -> void:
	_load_settings()

# Default physical keycodes per action. Used on first run (no settings.cfg yet) and as
# the "reset to defaults" target. Physical keycodes make bindings keyboard-layout-agnostic.
const DEFAULTS := {
	"move_up":     [KEY_W, KEY_UP],
	"move_down":   [KEY_S, KEY_DOWN],
	"move_left":   [KEY_A, KEY_LEFT],
	"move_right":  [KEY_D, KEY_RIGHT],
	"attack":      [KEY_SPACE],
	"feed":        [KEY_F],
	"dash":        [KEY_SHIFT],
	"interact":    [KEY_E],
	"slot_1":      [KEY_1],
	"slot_2":      [KEY_2],
	"slot_3":      [KEY_3],
	"slot_4":      [KEY_4],
	"pause":       [KEY_ESCAPE],
}

## Register the default bindings into Godot's InputMap. Called on first run.
func register_defaults() -> void:
	_apply_keycode_map(DEFAULTS)

func apply_preset(preset_id: String) -> void:
	# Only keyboard-driven presets exist for the slice. Unknown id -> default.
	var map: Dictionary = PRESETS.get(preset_id, DEFAULTS)
	_apply_keycode_map(map)
	for action in map:
		# Persist the FIRST keycode as the canonical binding for each action.
		bindings[action] = _keycode_event(int(map[action][0]))
	_save_settings()

func _apply_keycode_map(map: Dictionary) -> void:
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for keycode in map[action]:
			InputMap.action_add_event(action, _keycode_event(keycode))

static func _keycode_event(keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	return ev

## Capture the frame's input from the Godot InputEvent stream and return an InputAction
## (or null). Called by the render layer, NOT by sim code.
##
## Order matters: discrete verbs (attack/dash/slots/etc.) are matched first so a move-key
## release never swallows a verb press. Movement is aggregated last from held directional
## state, and ONLY when the event itself is a move key — otherwise a non-move keypress would
## spuriously emit a MOVE intent every time a move key happened to be held.
func capture(event: InputEvent) -> InputAction:
	# While the remap UI is listening, do not consume inputs as gameplay actions.
	if _capturing:
		return null

	# Continuous/hold verbs. Guard with has_action: sprint/sneak are optional verbs that may
	# not be declared in the input map for a given slice. The held state comes from the event
	# itself (event.pressed) rather than re-querying Input, which is only updated next frame.
	if event.is_action("feed"):
		var feed_a := InputAction.new(InputAction.Kind.FEED)
		feed_a.held = event.is_pressed()
		return feed_a
	if InputMap.has_action("sprint") and event.is_action("sprint"):
		var sp := InputAction.new(InputAction.Kind.SPRINT)
		sp.held = event.is_pressed()
		return sp
	if InputMap.has_action("sneak") and event.is_action("sneak"):
		var sn := InputAction.new(InputAction.Kind.SNEAK)
		sn.held = event.is_pressed()
		return sn

	# One-shot verbs (only on press, never on release).
	if event.is_pressed():
		if event.is_action("attack"):
			return InputAction.new(InputAction.Kind.ATTACK)
		if event.is_action("dash"):
			var dash := InputAction.new(InputAction.Kind.DASH)
			dash.vector = _facing_or_move_dir()
			return dash
		if event.is_action("interact"):
			return InputAction.new(InputAction.Kind.INTERACT)
		if InputMap.has_action("pounce") and event.is_action("pounce"):
			var pounce := InputAction.new(InputAction.Kind.POUNCE)
			pounce.vector = _facing_or_move_dir()
			return pounce
		if InputMap.has_action("finish") and event.is_action("finish"):
			return InputAction.new(InputAction.Kind.FINISH)
		# Hotbar slots: emit a POWER intent with action_id "slot_N". Sim.apply_input resolves
		# the slot to the actual power id via the player's hotbar (see SimPlayer/SimMeta).
		for slot_idx in range(1, 5):
			if event.is_action("slot_%d" % slot_idx):
				var power := InputAction.new(InputAction.Kind.POWER)
				power.action_id = "slot_%d" % slot_idx
				return power

	# Movement: aggregate held directional keys into a single MOVE intent. Only when THIS
	# event is a move key, so non-move events don't emit spurious moves.
	if _is_move_event(event):
		var move := Vector2.ZERO
		if Input.is_action_pressed("move_right"): move.x += 1.0
		if Input.is_action_pressed("move_left"): move.x -= 1.0
		if Input.is_action_pressed("move_down"): move.y += 1.0
		if Input.is_action_pressed("move_up"): move.y -= 1.0
		var a := InputAction.new(InputAction.Kind.MOVE)
		a.vector = move
		return a

	# Mouse aim.
	if event is InputEventMouseMotion:
		var cam := get_viewport().get_camera_2d()
		var mouse_pos := get_viewport().get_mouse_position()
		var world_pos := mouse_pos
		if cam != null:
			world_pos = cam.global_position + (mouse_pos - get_viewport().get_visible_rect().size * 0.5) / cam.zoom
		var aim := InputAction.new(InputAction.Kind.AIM)
		aim.vector = world_pos
		aim.held = true
		return aim

	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			return InputAction.new(InputAction.Kind.ATTACK)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var mfeed := InputAction.new(InputAction.Kind.FEED)
			mfeed.held = true
			return mfeed

	return null


func _is_move_event(event: InputEvent) -> bool:
	return event.is_action("move_up") or event.is_action("move_down") \
		or event.is_action("move_left") or event.is_action("move_right")

func _facing_or_move_dir() -> Vector2:
	if Sim == null or Sim.player == null:
		return Vector2.RIGHT
	return Vector2.RIGHT.rotated(Sim.player.facing)

## Replace the primary binding for `action_name`. Persists immediately. Returns OK or an
## error string. When `event` is a keyboard/mouse/gamepad button or axis, the previously
## assigned binding for this action is replaced (not appended).
func rebind(action_name: String, new_event: InputEvent) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, new_event)
	bindings[action_name] = new_event
	_save_settings()

## Set gamepad binding handling on/off (preserved alongside bindings).
func set_gamepad_enabled(enabled: bool) -> void:
	gamepad_enabled = enabled
	_save_settings()

## Begin/stop a remap capture session. While capturing, UIManager routes the next raw input
## here instead of to gameplay.
func set_capturing(capturing: bool) -> void:
	_capturing = capturing

func is_capturing() -> bool:
	return _capturing

## Is `event` already bound to a DIFFERENT action? Used by the remap UI to warn on conflict.
func find_conflict(event: InputEvent, exclude_action: String = "") -> String:
	if event == null:
		return ""
	for action in bindings:
		if action == exclude_action:
			continue
		var ev: InputEvent = bindings[action]
		if _events_match(ev, event):
			return action
	# Also scan InputMap directly in case an action has no persisted binding yet.
	for action in InputMap.get_actions():
		if action.begins_with("ui_") or action == exclude_action:
			continue
		for ev in InputMap.action_get_events(action):
			if _events_match(ev, event):
				return String(action)
	return ""

static func _events_match(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		var ak: InputEventKey = a
		var bk: InputEventKey = b
		# Match on physical keycode (layout-agnostic) when set, else logical keycode.
		if ak.physical_keycode != 0 and bk.physical_keycode != 0:
			return ak.physical_keycode == bk.physical_keycode
		return ak.keycode == bk.keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index \
			and (a as InputEventJoypadButton).device == (b as InputEventJoypadButton).device
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return (a as InputEventJoypadMotion).axis == (b as InputEventJoypadMotion).axis \
			and (a as InputEventJoypadMotion).device == (b as InputEventJoypadMotion).device
	return false

## Human-readable glyph/label for a binding, for the remap UI rows.
func label_for(action_name: String) -> String:
	if bindings.has(action_name):
		return event_label(bindings[action_name])
	for ev in InputMap.action_get_events(action_name):
		return event_label(ev)
	return tr("INPUT_UNBOUND")

func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var k: InputEventKey = event
		var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		if code == 0:
			return tr("INPUT_UNBOUND")
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		var b: InputEventMouseButton = event
		return "Mouse %d" % b.button_index
	if event is InputEventJoypadButton:
		var j: InputEventJoypadButton = event
		return _joy_button_name(j.button_index)
	if event is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = event
		return "%s %s" % [_joy_axis_name(m.axis), "+" if m.axis_value >= 0 else "-"]
	return tr("INPUT_UNBOUND")

static func _joy_button_name(index: int) -> String:
	const names := {
		0: "A / Cross", 1: "B / Circle", 2: "X / Square", 3: "Y / Triangle",
		4: "LB / L1", 5: "RB / R1", 6: "LT / L2", 7: "RT / R2",
		8: "View / Share", 9: "Menu / Options", 10: "L3", 11: "R3",
		12: "D-Up", 13: "D-Down", 14: "D-Left", 15: "D-Right",
		16: "Home", 17: "Guide",
	}
	return names.get(index, "Btn %d" % index)

static func _joy_axis_name(axis: int) -> String:
	const names := { 0: "L Stick X", 1: "L Stick Y", 2: "R Stick X", 3: "R Stick Y", 4: "LT", 5: "RT" }
	return names.get(axis, "Axis %d" % axis)

## All action names we expose for remapping (excludes Godot's ui_* built-ins).
func remappable_actions() -> Array:
	return DEFAULTS.keys()


## Test-only: create a fresh instance that reloads its bindings from `settings_path`,
## simulating a game restart without touching the live autoload. Returns the instance so
## the test can read its restored state (label_for / bindings). Not used in production.
static func __fresh_for_test(settings_path: String) -> Node:
	var inst := new()
	# Swap the const path by loading directly into the fresh instance's InputMap view.
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK and cfg.has_section(SECTION_BINDINGS):
		inst._register_persisted_bindings(cfg)
	else:
		inst.register_defaults()
		for action in DEFAULTS:
			inst.bindings[action] = _keycode_event(int(DEFAULTS[action][0]))
	return inst

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err == OK and cfg.has_section(SECTION_BINDINGS):
		gamepad_enabled = bool(cfg.get_value(SECTION_INPUT, "gamepad", true))
		_register_persisted_bindings(cfg)
	else:
		# first run OR no bindings section yet: register defaults and persist.
		gamepad_enabled = bool(cfg.get_value(SECTION_INPUT, "gamepad", true)) if err == OK else true
		register_defaults()
		for action in DEFAULTS:
			bindings[action] = _keycode_event(int(DEFAULTS[action][0]))
		_save_settings()

func _register_persisted_bindings(cfg: ConfigFile) -> void:
	# Ensure every declared action exists with at least its default, then overlay saved.
	_apply_keycode_map(DEFAULTS)
	for action in cfg.get_section_keys(SECTION_BINDINGS):
		var ev := _deserialize_event(cfg.get_value(SECTION_BINDINGS, action))
		if ev == null:
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		# Replace the default primary with the saved binding (keep others as alternates).
		var existing := InputMap.action_get_events(action)
		if existing.size() > 0:
			InputMap.action_erase_event(action, existing[0])
		InputMap.action_add_event(action, ev)
		bindings[action] = ev

func _save_settings() -> void:
	# Read any existing cfg first so we don't clobber UI settings (UIM/UITheme) that
	# live in their own sections.
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SECTION_INPUT, "gamepad", gamepad_enabled)
	for action in bindings:
		cfg.set_value(SECTION_BINDINGS, action, _serialize_event(bindings[action]))
	cfg.save(SETTINGS_PATH)

# Persist InputEvents as typed dicts so the ConfigFile stays plain-text and diffable.
func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var k: InputEventKey = event
		return { "type": "key", "physical": k.physical_keycode, "keycode": k.keycode }
	if event is InputEventMouseButton:
		return { "type": "mouse", "button": (event as InputEventMouseButton).button_index }
	if event is InputEventJoypadButton:
		var j: InputEventJoypadButton = event
		return { "type": "joybutton", "button": j.button_index, "device": j.device }
	if event is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = event
		return { "type": "joyaxis", "axis": m.axis, "value": m.axis_value, "device": m.device }
	return {}

func _deserialize_event(d) -> InputEvent:
	if not (d is Dictionary):
		return null
	var rec: Dictionary = d
	match String(rec.get("type", "")):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(rec.get("physical", 0))
			k.keycode = int(rec.get("keycode", 0))
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(rec.get("button", 0))
			return m
		"joybutton":
			var j := InputEventJoypadButton.new()
			j.button_index = int(rec.get("button", 0))
			j.device = int(rec.get("device", 0))
			return j
		"joyaxis":
			var a := InputEventJoypadMotion.new()
			a.axis = int(rec.get("axis", 0))
			a.axis_value = float(rec.get("value", 1.0))
			a.device = int(rec.get("device", 0))
			return a
	return null
