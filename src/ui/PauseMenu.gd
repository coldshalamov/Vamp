## PauseMenu.gd — in-game pause overlay.
##
## Resume / Settings / Save Game / Quit to Menu / Quit to Desktop. Pauses Sim time scale
## while open (UIManager.set_gameplay_paused drives Sim.time_scale). The pause key closes
## it again (is_pause_toggle_screen == true).
extends BaseScreen

var _btn_resume: Button = null
var _btn_settings: Button = null
var _btn_save: Button = null
var _btn_quit_menu: Button = null
var _btn_quit_desktop: Button = null


func _ready() -> void:
	super._ready()
	title = tr("MENU_PAUSE_TITLE")
	_build()


func _on_opened() -> void:
	# Entering the pause menu pauses gameplay. Time scale is restored on close.
	UIManager.set_gameplay_paused(true)


func _on_about_to_close() -> void:
	# Only unpause if no menu is left stacked on top (e.g. settings opened from pause).
	if UIManager.is_gameplay_paused():
		UIManager.set_gameplay_paused(false)


func is_pause_toggle_screen() -> bool:
	return true


func _build() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	# Dim the gameplay behind the menu.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := VBoxContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	var heading := Label.new()
	heading.text = tr("MENU_PAUSE_TITLE")
	heading.add_theme_font_size_override("font_size", UIManager.theme_resource.font_size_title if UIManager != null else 36)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(heading)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	center.add_child(spacer)

	_btn_resume = _button(tr("PAUSE_RESUME"), close)
	_btn_settings = _button(tr("PAUSE_SETTINGS"), UIManager.open_menu.bind("settings"))
	_btn_save = _button(tr("PAUSE_SAVE"), _on_save)
	_btn_quit_menu = _button(tr("PAUSE_QUIT_MENU"), _on_quit_menu)
	_btn_quit_desktop = _button(tr("PAUSE_QUIT_DESKTOP"), _on_quit_desktop)
	for b in [_btn_resume, _btn_settings, _btn_save, _btn_quit_menu, _btn_quit_desktop]:
		center.add_child(b)


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 44)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(callback)
	return b


func default_focus_control() -> Control:
	return _btn_resume if _btn_resume != null else super.default_focus_control()


func _on_save() -> void:
	if UIManager.cb_save_game.is_valid():
		UIManager.cb_save_game.call()
	UIManager.show_notification(tr("NOTIFY_SAVED"))


func _on_quit_menu() -> void:
	# Quitting to menu must release the pause lock before the title takes over.
	if UIManager.is_gameplay_paused():
		UIManager.set_gameplay_paused(false)
	if UIManager.cb_quit_to_menu.is_valid():
		UIManager.cb_quit_to_menu.call()


func _on_quit_desktop() -> void:
	if UIManager.is_gameplay_paused():
		UIManager.set_gameplay_paused(false)
	if UIManager.cb_quit_to_desktop.is_valid():
		UIManager.cb_quit_to_desktop.call()
	else:
		get_tree().quit()
