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

var bindings: Dictionary = {}    # action_name (String) -> InputEvent
var gamepad_enabled: bool = true

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
	for action in DEFAULTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for keycode in DEFAULTS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)

## Capture the frame's input from the Godot InputEvent stream and return an InputAction
## (or null). Called by the render layer, NOT by sim code.
func capture(event: InputEvent) -> InputAction:
	# TODO(input): translate move/aim/attack/feed/dash/slots into InputActions.
	# Movement aggregates held keys into a single MOVE intent per tick.
	return null

func rebind(action_name: String, new_event: InputEvent) -> void:
	bindings[action_name] = new_event
	_save_settings()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		gamepad_enabled = bool(cfg.get_value("input", "gamepad", true))
		# TODO: load persisted per-action bindings and register them.
		# Until persistence is implemented, fall through to defaults.
		register_defaults()
	else:
		# first run — register the default keybindings.
		register_defaults()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "gamepad", gamepad_enabled)
	# TODO: persist per-action bindings.
	cfg.save(SETTINGS_PATH)
