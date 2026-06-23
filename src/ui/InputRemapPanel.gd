## InputRemapPanel.gd — full input remapping UI (the Controls tab of Settings).
##
## Requirements (PROMPT_FRONTEND_AGENT §4):
##   - List all remappable actions from the project input map.
##   - Show the current primary binding per action.
##   - Click/activate a row -> listen for next input -> assign -> save.
##   - Detect conflicts and warn before overwriting.
##   - Support keyboard, mouse buttons, and gamepad buttons/axes.
##   - Preset buttons: Default, Lefty, One-Handed.
##   - Show controller glyphs when a gamepad binding is active.
##
## All binding changes go through Rebind (the InputMap autoload), which persists them. We
## never touch InputMap except via Rebind's API.
extends Control
class_name InputRemapPanel

var _rows: Dictionary = {}     # action_name -> { button, label }
var _pending_action: String = ""
var _preset_row: HBoxContainer = null


func _ready() -> void:
	# Tabs add this as a child; title shows on the tab strip.
	name = tr("SETTINGS_CONTROLS")
	set_anchors_preset(PRESET_FULL_RECT)


func build(_owner: Node) -> void:
	# Called by SettingsMenu after instantiation (our _ready may not have run yet because
	# we add ourselves to the tab container directly).
	name = tr("SETTINGS_CONTROLS")
	set_anchors_preset(PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	# Preset buttons row.
	_preset_row = HBoxContainer.new()
	_preset_row.add_theme_constant_override("separation", 8)
	box.add_child(_preset_row)
	_preset_button(tr("PRESET_DEFAULT"), Rebind.PRESET_DEFAULT)
	_preset_button(tr("PRESET_LEFTY"), Rebind.PRESET_LEFTY)
	_preset_button(tr("PRESET_ONE_HANDED"), Rebind.PRESET_ONE_HANDED)

	# Header.
	box.add_child(_header(tr("INPUT_ACTION"), tr("INPUT_BINDING")))
	# One row per action.
	for action in Rebind.remappable_actions():
		box.add_child(_make_row(String(action)))


func _preset_button(label: String, preset_id: String) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Rebind.apply_preset(preset_id)
		_refresh_all_rows())
	_preset_row.add_child(b)


func _header(a: String, b: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var la := Label.new()
	la.text = a
	la.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	la.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70, 1))
	row.add_child(la)
	var lb := Label.new()
	lb.text = b
	lb.custom_minimum_size = Vector2(160, 0)
	lb.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70, 1))
	row.add_child(lb)
	return row


func _make_row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	var display := Rebind.ACTION_LABELS.get(action, action) as String
	label.text = tr(display) if display != "" else action
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.text = Rebind.label_for(action)
	button.custom_minimum_size = Vector2(160, 32)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_begin_capture.bind(action, button))
	row.add_child(button)
	_rows[action] = { "button": button, "label": label }
	return row


func _refresh_all_rows() -> void:
	for action in _rows:
		var rec: Dictionary = _rows[action]
		(rec["button"] as Button).text = Rebind.label_for(action)


func _begin_capture(action: String, _button: Button) -> void:
	_pending_action = action
	Rebind.set_capturing(true)
	UIManager.show_notification(tr("NOTIFY_LISTENING"))


# Capture is driven from _unhandled_input so the next raw input event becomes the binding.
func _unhandled_input(event: InputEvent) -> void:
	if _pending_action == "" or not Rebind.is_capturing():
		return
	if not _is_assignable(event):
		return
	var conflict := Rebind.find_conflict(event, _pending_action)
	if conflict != "":
		# Warn before overwriting: ask via banner + abort this capture.
		UIManager.show_banner(tr("BANNER_CONFLICT_TITLE"), tr("BANNER_CONFLICT_BODY") % Rebind.label_for(conflict), Color(0.92, 0.22, 0.22, 1))
		_cancel_capture()
		get_viewport().set_input_as_handled()
		return
	Rebind.rebind(_pending_action, event)
	_refresh_all_rows()
	_cancel_capture()
	get_viewport().set_input_as_handled()


func _cancel_capture() -> void:
	_pending_action = ""
	Rebind.set_capturing(false)


func _is_assignable(event: InputEvent) -> bool:
	# Accept a single press of a key / mouse button / joypad button / joypad axis motion.
	if event is InputEventKey:
		return event.pressed and event.physical_keycode != 0
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) > 0.5
	return false


func _notification(what: int) -> void:
	# If the panel leaves the tree mid-capture, release the capture lock.
	if what == NOTIFICATION_PREDELETE and Rebind != null and Rebind.is_capturing():
		Rebind.set_capturing(false)
