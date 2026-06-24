## SettingsMenu.gd — tabbed settings (Video / Audio / Gameplay / Accessibility / Controls).
##
## Every control persists its value to user://settings.cfg on change (via UIManager for
## accessibility flags, ConfigFile directly for audio/video/gameplay). All settings must
## survive a restart (acceptance criterion #4). All strings are localized.
extends BaseScreen

const SECTION_VIDEO := "video"
const SECTION_AUDIO := "audio"
const SECTION_GAMEPLAY := "gameplay"

var _tab_bar: TabContainer = null
var _remap_panel: InputRemapPanel = null


func _ready() -> void:
	super._ready()
	title = tr("MENU_SETTINGS")
	_build()


## Add a section as a tab. _section() returns the populated VBox; its parent is the named
## ScrollContainer that should be the actual TabContainer child (the tab title comes from its name).
func _add_tab(section_box: Control) -> void:
	var root: Node = section_box.get_parent()
	_tab_bar.add_child(root if root != null else section_box)


func _build() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	_tab_bar = TabContainer.new()
	margin.add_child(_tab_bar)

	# _section() returns the inner VBox (so the _toggle/_option helpers can populate it), but the
	# tab root is its parent ScrollContainer (named after the tab). Add the ROOT to the tab — adding
	# the already-parented VBox fails ("already has a parent") and silently drops the tab.
	_add_tab(_build_video())
	_add_tab(_build_audio())
	_add_tab(_build_gameplay())
	_add_tab(_build_accessibility())
	# Controls tab hosts the full remap panel.
	_remap_panel = preload("res://src/ui/InputRemapPanel.gd").new()
	_remap_panel.build(self)
	_tab_bar.add_child(_remap_panel)


func default_focus_control() -> Control:
	# Focus the first interactive control on the active tab.
	return BaseScreen._first_focusable(_tab_bar.get_current_tab_control())


# ---------------------------------------------------------------- Video

func _build_video() -> Control:
	var box := _section(tr("SETTINGS_VIDEO"))
	_toggle(box, tr("SET_FULLSCREEN"), _cfg_bool(SECTION_VIDEO, "fullscreen", false), _on_fullscreen)
	_option(box, tr("SET_RESOLUTION"), ["1280x720", "1600x900", "1920x1080"], _cfg_str(SECTION_VIDEO, "resolution", "1280x720"), _on_resolution)
	_toggle(box, tr("SET_VSYNC"), _cfg_bool(SECTION_VIDEO, "vsync", true), _on_vsync)
	_toggle(box, tr("SET_PIXEL_SNAP"), _cfg_bool(SECTION_VIDEO, "pixel_snap", true), _on_pixel_snap)
	return box


func _on_fullscreen(on: bool) -> void:
	_cfg_set(SECTION_VIDEO, "fullscreen", on)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _on_resolution(value: String) -> void:
	_cfg_set(SECTION_VIDEO, "resolution", value)
	var parts := value.split("x")
	if parts.size() == 2:
		DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))

func _on_vsync(on: bool) -> void:
	_cfg_set(SECTION_VIDEO, "vsync", on)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)

func _on_pixel_snap(on: bool) -> void:
	_cfg_set(SECTION_VIDEO, "pixel_snap", on)


# ---------------------------------------------------------------- Audio

func _build_audio() -> Control:
	var box := _section(tr("SETTINGS_AUDIO"))
	_slider(box, tr("SET_VOL_MASTER"), _cfg_float(SECTION_AUDIO, "master", 1.0), _on_master)
	_slider(box, tr("SET_VOL_MUSIC"), _cfg_float(SECTION_AUDIO, "music", 0.8), _on_music)
	_slider(box, tr("SET_VOL_SFX"), _cfg_float(SECTION_AUDIO, "sfx", 1.0), _on_sfx)
	_slider(box, tr("SET_VOL_VOICE"), _cfg_float(SECTION_AUDIO, "voice", 1.0), _on_voice)
	_slider(box, tr("SET_VOL_AMBIENT"), _cfg_float(SECTION_AUDIO, "ambient", 0.8), _on_ambient)
	return box


func _on_master(v: float) -> void: _cfg_set(SECTION_AUDIO, "master", v); _apply_bus("Master", v)
func _on_music(v: float) -> void: _cfg_set(SECTION_AUDIO, "music", v); _apply_bus("Music", v)
func _on_sfx(v: float) -> void: _cfg_set(SECTION_AUDIO, "sfx", v); _apply_bus("SFX", v)
func _on_voice(v: float) -> void: _cfg_set(SECTION_AUDIO, "voice", v); _apply_bus("Voice", v)
func _on_ambient(v: float) -> void: _cfg_set(SECTION_AUDIO, "ambient", v); _apply_bus("Ambient", v)

## Apply a linear (0..1) volume to a bus.
## For Music and Ambient: delegates to AudioDirector.set_bus_volume_linear so the ducking baseline
## is also updated — without this, _update_duck() would clobber the new level on the next frame.
## For Master, SFX, Voice: sets AudioServer directly (they are not duckable buses).
func _apply_bus(bus_name: String, v: float) -> void:
	if AudioDirector != null:
		AudioDirector.set_bus_volume_linear(bus_name, v)
	else:
		# Fallback for headless / early boot before AudioDirector is ready.
		var idx := AudioServer.get_bus_index(bus_name)
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.0, 1.0)))


# ---------------------------------------------------------------- Gameplay

func _build_gameplay() -> Control:
	var box := _section(tr("SETTINGS_GAMEPLAY"))
	_option(box, tr("SET_DIFFICULTY"), [tr("DIFF_MASQUERADE"), tr("DIFF_NEONATE"), tr("DIFF_ELDER")], _cfg_str(SECTION_GAMEPLAY, "difficulty", tr("DIFF_NEONATE")), func(v): _cfg_set(SECTION_GAMEPLAY, "difficulty", v))
	_option(box, tr("SET_LANGUAGE"), ["en"], "en", func(v): _cfg_set(SECTION_GAMEPLAY, "language", v))
	_option(box, tr("SET_SPRINT"), [tr("HOLD"), tr("TOGGLE")], _cfg_str(SECTION_GAMEPLAY, "sprint", tr("HOLD")), func(v): _cfg_set(SECTION_GAMEPLAY, "sprint", v))
	_option(box, tr("SET_FEED"), [tr("HOLD"), tr("TOGGLE")], _cfg_str(SECTION_GAMEPLAY, "feed", tr("HOLD")), func(v): _cfg_set(SECTION_GAMEPLAY, "feed", v))
	_option(box, tr("SET_CLOAK"), [tr("HOLD"), tr("TOGGLE")], _cfg_str(SECTION_GAMEPLAY, "cloak", tr("HOLD")), func(v): _cfg_set(SECTION_GAMEPLAY, "cloak", v))
	return box


# ---------------------------------------------------------------- Accessibility

func _build_accessibility() -> Control:
	var box := _section(tr("SETTINGS_ACCESSIBILITY"))
	var a11y := UIManager.theme_resource
	_slider(box, tr("SET_TEXT_SCALE"), a11y.text_scale, func(v: float) -> void:
		UIManager.set_text_scale(v)
		_refresh_slider_default(box))
	_toggle(box, tr("SET_HIGH_CONTRAST"), a11y.high_contrast, UIManager.set_high_contrast)
	_toggle(box, tr("SET_REDUCED_MOTION"), a11y.reduced_motion, UIManager.set_reduced_motion)
	_toggle(box, tr("SET_REDUCED_FLASH"), a11y.reduced_flash, UIManager.set_reduced_flash)
	_option(box, tr("SET_COLORBLIND"), ["off", "protanopia", "deuteranopia", "tritanopia"], a11y.colorblind_mode, UIManager.set_colorblind_mode)
	_toggle(box, tr("SET_CAPTIONS"), a11y.captions_enabled, UIManager.set_captions_enabled)
	return box


func _refresh_slider_default(_box: VBoxContainer) -> void:
	pass   # sliders remain valid; theme rebuild only affects sizing.


# ---------------------------------------------------------------- Control factories

func _section(tab_label: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_label
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	return box


func _toggle(parent: VBoxContainer, label: String, current: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var chk := CheckBox.new()
	chk.button_pressed = current
	chk.toggled.connect(callback)
	row.add_child(chk)
	parent.add_child(row)


func _slider(parent: VBoxContainer, label: String, current: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = current
	s.custom_minimum_size = Vector2(220, 16)
	s.value_changed.connect(callback)
	row.add_child(s)
	parent.add_child(row)


func _option(parent: VBoxContainer, label: String, options: Array, current: String, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var ob := OptionButton.new()
	for o in options:
		ob.add_item(str(o))
	var idx := options.find(current)
	if idx >= 0:
		ob.select(idx)
	ob.item_selected.connect(func(i): callback.call(options[i]))
	row.add_child(ob)
	parent.add_child(row)


# ---------------------------------------------------------------- ConfigFile I/O

const SETTINGS_PATH := "user://settings.cfg"

func _cfg_set(section: String, key: String, value) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(section, key, value)
	cfg.save(SETTINGS_PATH)

func _cfg_bool(section: String, key: String, fallback: bool) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section_key(section, key):
		return bool(cfg.get_value(section, key))
	return fallback

func _cfg_float(section: String, key: String, fallback: float) -> float:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section_key(section, key):
		return float(cfg.get_value(section, key))
	return fallback

func _cfg_str(section: String, key: String, fallback: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section_key(section, key):
		return String(cfg.get_value(section, key))
	return fallback
