## UIManager.gd — autoload CanvasLayer owning the UI screen stack and HUD/overlays.
##
## Responsibilities (from docs/PROMPT_FRONTEND_AGENT.md §1):
##   - Own the active screen stack (push/pop/replace).
##   - Handle pause state: the `pause` action opens the PauseMenu unless in title/loading.
##   - Manage UI input mode: when a menu is open, gameplay verbs are suppressed.
##   - Track the current focus owner for keyboard/gamepad navigation.
##   - Expose helpers: open_menu(name), close_menu(), show_hud(bool),
##     show_notification(text, color), show_banner(title, body).
##
## UI NEVER mutates Sim state. It reads Sim.player read-only and listens to CueBus. Any
## gameplay change the player triggers from a menu is routed through callbacks owned by
## the game host (Boot.gd), never written here.
extends CanvasLayer
# NOTE: no class_name — this script IS the `UIManager` autoload singleton.

const RuntimeSafetyScript := preload("res://src/core/RuntimeSafety.gd")

signal screen_stack_changed()
signal gameplay_input_block_changed(blocked: bool)
signal pause_changed(paused: bool)

var theme_resource: UITheme = null
var theme: Theme = null
var _translations_loaded: bool = false

# Scene paths keyed by short name. Lets `open_menu("settings")` resolve without imports.
const SCREEN_SCENES := {
	"main_menu": "res://scenes/ui/MainMenu.tscn",
	"pause": "res://scenes/ui/PauseMenu.tscn",
	"settings": "res://scenes/ui/SettingsMenu.tscn",
	"credits": "res://scenes/ui/CreditsScreen.tscn",
	"skill_tree": "res://scenes/ui/SkillTreeScreen.tscn",
	"inventory": "res://scenes/ui/InventoryScreen.tscn",
	"coterie": "res://scenes/ui/CoterieScreen.tscn",
	"shop": "res://scenes/ui/ShopScreen.tscn",
	"loading": "res://scenes/ui/LoadingScreen.tscn",
}

var _screen_stack: Array[BaseScreen] = []
var _hud: Control = null               # set by HUD on _ready
var _notification_panel: Control = null
var _caption_overlay: Control = null
var _floating_layer: Control = null
var _gameplay_paused: bool = false
var _hud_visible: bool = true

# --- callbacks owned by the game host (Boot.gd). UI calls these instead of mutating Sim. ---
var cb_new_game: Callable = Callable()
var cb_continue_game: Callable = Callable()
var cb_save_game: Callable = Callable()
var cb_quit_to_menu: Callable = Callable()
var cb_quit_to_desktop: Callable = Callable()


func _ready() -> void:
	layer = 100
	theme_resource = UITheme.new()
	_ensure_translations()
	# The Accessibility autoload is OPTIONAL (owned by the vision agent; may be absent during
	# parallel refactors). When present, it's the canonical a11y store and we mirror from it.
	# When absent, UITheme is the canonical store and persists via _save_ui_settings().
	_sync_from_accessibility()
	var a11y := _accessibility_node()
	if a11y != null and a11y.has_signal("settings_changed"):
		a11y.settings_changed.connect(_on_accessibility_changed)
	_load_ui_settings()
	_rebuild_theme()
	_build_layers()
	# CueBus captions/reduced-motion flags mirror our accessibility state.
	_sync_accessibility_to_cuebus()
	# pause + gameplay routing is handled in _unhandled_input below.


## Load UI strings at runtime from the CSV so localization works in headless/test runs
## without needing the editor-compiled .translation binary. Registers an `en` translation.
func _ensure_translations() -> void:
	var path := "res://art/i18n/ui.en.csv"
	if not FileAccess.file_exists(path):
		return
	if _translations_loaded:
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var t := Translation.new()
	t.locale = "en"
	# Skip the header line ("keys,en").
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 2 and String(row[0]) != "":
			t.add_message(String(row[0]), String(row[1]))
	f.close()
	TranslationServer.add_translation(t)
	TranslationServer.set_locale("en")
	_translations_loaded = true


# ---------------------------------------------------------------- screen stack

var selected_difficulty: int = 1   # chosen at the main menu, applied at new game

func open_menu(name: String) -> BaseScreen:
	var path: String = SCREEN_SCENES.get(name, "")
	if path == "":
		push_warning("[UIManager] unknown menu '%s'" % name)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("[UIManager] could not load scene '%s'" % path)
		return null
	var screen := packed.instantiate() as BaseScreen
	if screen == null:
		push_warning("[UIManager] scene '%s' root is not a BaseScreen" % path)
		return null
	_add_screen(screen)
	return screen


func _add_screen(screen: BaseScreen) -> void:
	# Remember focus on the screen we're covering so it can be restored on return.
	if _screen_stack.size() > 0:
		_screen_stack.back().save_focus()
	_screen_stack.append(screen)
	get_node("ScreensLayer").add_child(screen)
	screen.opened.connect(_on_screen_opened)
	screen.closed.connect(_on_screen_closed)
	screen.open()
	_update_input_block()
	screen_stack_changed.emit()


func close_menu() -> void:
	if _screen_stack.is_empty():
		return
	_screen_stack.back().close()


## Tear down the entire screen stack SYNCHRONOUSLY (this frame). The host calls this when
## entering gameplay. Do NOT use `while is_menu_open(): close_menu()` for that — close() is
## animated by default and pops on a later tween frame, so that loop spins forever (it hung the
## New Game button). force_close() pops immediately; the guard guarantees termination even if a
## screen fails to pop itself.
func close_all_menus() -> void:
	var guard := 0
	while not _screen_stack.is_empty() and guard < 64:
		guard += 1
		var screen: BaseScreen = _screen_stack.back()
		if is_instance_valid(screen):
			screen.force_close()
		# If force_close didn't remove it (unexpected), force removal to guarantee progress.
		if not _screen_stack.is_empty() and _screen_stack.back() == screen:
			_screen_stack.pop_back()
			if is_instance_valid(screen):
				screen.queue_free()
	_update_input_block()
	screen_stack_changed.emit()


## Replace the top screen (e.g. open settings from pause without stacking both).
func replace_top(name: String) -> BaseScreen:
	if _screen_stack.is_empty():
		return open_menu(name)
	var top: BaseScreen = _screen_stack.back()
	var new_screen: BaseScreen = open_menu(name)
	# Schedule removal of the previous top after the new one is presented.
	if new_screen != null:
		top.close()
	return new_screen


func pop_screen(screen: BaseScreen) -> void:
	var idx := _screen_stack.rfind(screen)
	if idx == -1:
		return
	_screen_stack.remove_at(idx)
	# Free the node — screens are instantiated fresh on each open(); a popped screen is never
	# reused. Without this they stay parented under ScreensLayer (visible=false) and accumulate
	# every time a menu is opened/closed. queue_free is deferred, so any in-flight close callback
	# on this same screen completes safely first.
	if is_instance_valid(screen):
		screen.queue_free()
	# Restore focus to whatever is now on top.
	if not _screen_stack.is_empty():
		_screen_stack.back().restore_focus()
	_update_input_block()
	screen_stack_changed.emit()


func _on_screen_opened(_screen: BaseScreen) -> void:
	_update_input_block()


func _on_screen_closed(screen: BaseScreen) -> void:
	# pop_screen is also called from within close(); guard against double-removal.
	if _screen_stack.has(screen):
		pop_screen(screen)


func top_screen() -> BaseScreen:
	return _screen_stack.back() if not _screen_stack.is_empty() else null


func is_menu_open() -> bool:
	return not _screen_stack.is_empty()


# ---------------------------------------------------------------- HUD / overlays

func register_hud(hud: Control) -> void:
	_hud = hud

func register_notifications(panel: Control) -> void:
	_notification_panel = panel

func register_captions(overlay: Control) -> void:
	_caption_overlay = overlay

func register_floating_layer(layer: Control) -> void:
	_floating_layer = layer

func show_hud(show: bool) -> void:
	_hud_visible = show
	if _hud != null:
		_hud.visible = show


func show_notification(text: String, color: Color = Color.WHITE) -> void:
	if _notification_panel != null and _notification_panel.has_method("push_notification"):
		_notification_panel.push_notification(text, color)


func show_banner(title: String, body: String, color: Color = Color.WHITE) -> void:
	if _notification_panel != null and _notification_panel.has_method("push_banner"):
		_notification_panel.push_banner(title, body, color)


func spawn_floating_text(world_pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	if _floating_layer != null and _floating_layer.has_method("spawn"):
		_floating_layer.spawn(world_pos, text, color)


# ---------------------------------------------------------------- pause

func _unhandled_input(event: InputEvent) -> void:
	# The pause action toggles the pause menu — unless we're in a non-gameplay screen
	# (title/loading) where pause has no meaning.
	if event.is_action_pressed("pause") and not event.is_echo():
		if _is_in_title_or_loading():
			return
		if Rebind.is_capturing():
			return  # don't hijack a remap capture
		get_viewport().set_input_as_handled()
		toggle_pause()


func toggle_pause() -> void:
	if _gameplay_paused:
		# Close whatever menus are open on top of gameplay (typically pause + settings).
		close_menu()
		return
	open_menu("pause")


func set_gameplay_paused(paused: bool) -> void:
	_gameplay_paused = paused
	pause_changed.emit(paused)
	# The sim's time_scale is the real pause knob. Boot.gd owns the fixed-step loop; we
	# request a pause by setting time_scale and Boot reads it each tick.
	if Sim != null:
		Sim.time_scale = 0.0 if paused else 1.0


func is_gameplay_paused() -> bool:
	return _gameplay_paused


func _is_in_title_or_loading() -> bool:
	var top := top_screen()
	if top == null:
		return false
	return top.is_in_group("title_screen") or top.is_in_group("loading_screen")


# ---------------------------------------------------------------- input routing

func _update_input_block() -> void:
	# While a menu (or remap capture) is active, gameplay verbs should not fire. Boot.gd
	# reads gameplay_input_blocked() to decide whether to capture+forward intents.
	var blocked := is_menu_open() or _gameplay_paused or (Rebind != null and Rebind.is_capturing())
	gameplay_input_block_changed.emit(blocked)


func gameplay_input_blocked() -> bool:
	return is_menu_open() or _gameplay_paused or (Rebind != null and Rebind.is_capturing())


# --- theme item helpers (Godot 4.7 Theme API needs the DataType enum) ---

func theme_has_color(name: String, theme_type: String) -> bool:
	if theme == null:
		return false
	return theme.has_theme_item(Theme.DATA_TYPE_COLOR, name, theme_type)

func theme_get_color(name: String, theme_type: String, fallback: Color = Color.WHITE) -> Color:
	if theme != null and theme.has_theme_item(Theme.DATA_TYPE_COLOR, name, theme_type):
		return theme.get_color(name, theme_type)
	return fallback

func theme_font_size(name: String, theme_type: String, fallback: int = 16) -> int:
	if theme != null and theme.has_theme_item(Theme.DATA_TYPE_FONT_SIZE, name, theme_type):
		return theme.get_font_size(name, theme_type)
	return fallback


# ---------------------------------------------------------------- theme / a11y

func _rebuild_theme() -> void:
	theme = theme_resource.build_theme()
	# Apply to our own layer's children; the scene root + HUD also read this.
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.theme = theme
	_sync_accessibility_to_cuebus()


func is_reduced_motion() -> bool:
	if RuntimeSafetyScript.safe_mode_enabled():
		return true
	# Delegate to the optional Accessibility autoload when present; fall back to our theme.
	var a11y := _accessibility_node()
	if a11y != null:
		return bool(a11y.get("reduced_motion"))
	return theme_resource != null and theme_resource.reduced_motion


func is_reduced_flash() -> bool:
	if RuntimeSafetyScript.safe_mode_enabled():
		return true
	var a11y := _accessibility_node()
	if a11y != null:
		return bool(a11y.get("reduced_flash"))
	return theme_resource != null and theme_resource.reduced_flash


## Safe lookup of the optional Accessibility autoload. Returns null when absent so callers
## can fall back to the local UITheme store. We avoid the bare `Accessibility` identifier
## because Godot fails to parse the script if that autoload isn't registered.
func _accessibility_node() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Accessibility")


func _on_accessibility_changed() -> void:
	# The optional Accessibility autoload is the source of truth; rebuild our theme from its
	# current values whenever it changes.
	_sync_from_accessibility()
	_rebuild_theme()


func _sync_from_accessibility() -> void:
	var a11y := _accessibility_node()
	if a11y == null:
		return
	theme_resource.high_contrast = bool(a11y.get("high_contrast_text"))
	theme_resource.reduced_motion = bool(a11y.get("reduced_motion"))
	theme_resource.reduced_flash = bool(a11y.get("reduced_flash"))
	theme_resource.colorblind_mode = String(a11y.get("colorblind_mode"))
	theme_resource.text_scale = float(a11y.get("text_scale"))
	theme_resource.captions_enabled = bool(a11y.get("captions_enabled"))


# The settings menu calls these setters. They WRITE through the Accessibility autoload when
# present (which persists + emits settings_changed), otherwise through UITheme + ConfigFile.

func set_text_scale(scale: float) -> void:
	var a11y := _accessibility_node()
	if a11y != null and a11y.has_method("set"):
		a11y.set("text_scale", scale)
	else:
		theme_resource.text_scale = clampf(scale, UITheme.MIN_SCALE, UITheme.MAX_SCALE)
		_persist_and_rebuild()


func set_high_contrast(enabled: bool) -> void:
	var a11y := _accessibility_node()
	if a11y != null and a11y.has_method("set"):
		a11y.set("high_contrast_text", enabled)
	else:
		theme_resource.high_contrast = enabled
		_persist_and_rebuild()


func set_reduced_motion(enabled: bool) -> void:
	var a11y := _accessibility_node()
	if a11y != null and a11y.has_method("set"):
		a11y.set("reduced_motion", enabled)
	else:
		theme_resource.reduced_motion = enabled
		_persist_and_rebuild()


func set_reduced_flash(enabled: bool) -> void:
	var a11y := _accessibility_node()
	if a11y != null and a11y.has_method("set"):
		a11y.set("reduced_flash", enabled)
	else:
		theme_resource.reduced_flash = enabled
		_persist_and_rebuild()


func set_colorblind_mode(mode: String) -> void:
	var a11y := _accessibility_node()
	if a11y != null and a11y.has_method("set"):
		a11y.set("colorblind_mode", mode)
	else:
		theme_resource.colorblind_mode = mode
		_persist_and_rebuild()


func set_captions_enabled(enabled: bool) -> void:
	var a11y := _accessibility_node()
	if a11y != null and a11y.has_method("set"):
		a11y.set("captions_enabled", enabled)
	else:
		theme_resource.captions_enabled = enabled
		_persist_and_rebuild()


func _persist_and_rebuild() -> void:
	_save_ui_settings()
	_rebuild_theme()


func _sync_accessibility_to_cuebus() -> void:
	if CueBus != null:
		CueBus.reduced_motion = is_reduced_motion()
		CueBus.reduced_flash = is_reduced_flash()
		var a11y := _accessibility_node()
		if a11y != null:
			CueBus.captions_enabled = bool(a11y.get("captions_enabled"))
		else:
			CueBus.captions_enabled = theme_resource.captions_enabled


# ---------------------------------------------------------------- settings I/O

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_UI := "ui"

func _save_ui_settings() -> void:
	# Read any existing cfg first so we don't clobber Rebind / other sections.
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var d := theme_resource.to_settings_dict()
	for key in d:
		cfg.set_value(SECTION_UI, key, d[key])
	cfg.save(SETTINGS_PATH)
	_sync_accessibility_to_cuebus()


func _load_ui_settings() -> void:
	# When the Accessibility autoload owns the flags, skip — it loads/persists its own
	# section and we mirror from it via _sync_from_accessibility().
	if _accessibility_node() != null:
		return
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section(SECTION_UI):
		var d := {}
		for key in cfg.get_section_keys(SECTION_UI):
			d[key] = cfg.get_value(SECTION_UI, key)
		theme_resource.apply_settings_dict(d)


# ---------------------------------------------------------------- layer setup

func _build_layers() -> void:
	var screens := Control.new()
	screens.name = "ScreensLayer"
	screens.mouse_filter = Control.MOUSE_FILTER_STOP
	screens.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screens)
