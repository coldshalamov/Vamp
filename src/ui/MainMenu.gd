## MainMenu.gd — title screen.
##
## New Game / Continue (disabled if no save) / Settings / Quit. Routes all intent through
## UIManager callbacks (owned by Boot.gd), never mutating Sim itself. Adds itself to the
## `title_screen` group so UIManager knows `pause` should be ignored here.
extends BaseScreen

var _btn_new: Button = null
var _btn_continue: Button = null
var _btn_settings: Button = null
var _btn_quit: Button = null


func _ready() -> void:
	super._ready()
	add_to_group("title_screen")
	title = tr("MENU_TITLE")
	_build()


func _build() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var center := VBoxContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	var heading := Label.new()
	heading.text = tr("GAME_TITLE")
	heading.add_theme_font_size_override("font_size", UIManager.theme_resource.font_size_title if UIManager != null else 36)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(heading)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	center.add_child(spacer)

	_btn_new = _button(tr("MENU_NEW_GAME"), _on_new_game)
	_btn_continue = _button(tr("MENU_CONTINUE"), _on_continue)
	_btn_continue.disabled = not _has_save()
	_btn_settings = _button(tr("MENU_SETTINGS"), _on_settings)
	_btn_quit = _button(tr("MENU_QUIT"), _on_quit)
	for b in [_btn_new, _btn_continue, _btn_settings, _btn_quit]:
		center.add_child(b)


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 48)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(callback)
	return b


func default_focus_control() -> Control:
	return _btn_new if _btn_new != null else super.default_focus_control()


func _has_save() -> bool:
	return SaveSystem.save_exists()


# --- intent (routed through UIManager; no Sim mutation here) ---

func _on_new_game() -> void:
	if UIManager.cb_new_game.is_valid():
		UIManager.cb_new_game.call()

func _on_continue() -> void:
	if UIManager.cb_continue_game.is_valid():
		UIManager.cb_continue_game.call()

func _on_settings() -> void:
	UIManager.open_menu("settings")

func _on_quit() -> void:
	if UIManager.cb_quit_to_desktop.is_valid():
		UIManager.cb_quit_to_desktop.call()
	else:
		get_tree().quit()
