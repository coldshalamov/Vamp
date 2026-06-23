## MainMenu.gd — "NIGHT SHIFT" title screen.
##
## A crime-dossier / occult-noir title: the gothic city splash (title_bg) under a darkening scrim,
## the predator portrait (player_vampire, pink-keyed) standing at the right, an engraved Cinzel
## wordmark with a blood underglow, ShareTechMono case-file labels, scanline atmosphere, and a
## staggered reveal on open. Routes intent through UIManager callbacks (no Sim mutation).
extends BaseScreen

const BG_PATH := "res://assets/images/title_bg.jpg"
const PORTRAIT_PATH := "res://assets/images/menu_portrait.png"
const CHROMA_SHADER := "res://art/shaders/chroma_key.gdshader"
const SCAN_SHADER := "res://art/shaders/scanlines.gdshader"

var _btn_new: Button = null
var _btn_continue: Button = null
var _btn_settings: Button = null
var _btn_quit: Button = null
var _reveal: Array[Control] = []


func _ready() -> void:
	super._ready()
	add_to_group("title_screen")
	title = tr("MENU_TITLE")
	_build()


func _theme() -> UITheme:
	return UIManager.theme_resource if UIManager != null else null


func _build() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var th := _theme()

	# --- background splash (covered) ---
	var bg := TextureRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = _tex(BG_PATH)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# --- darkening scrim: left column legibility + bottom grade ---
	var scrim := TextureRect.new()
	scrim.set_anchors_preset(PRESET_FULL_RECT)
	scrim.texture = _h_gradient(Color(0.02, 0.01, 0.03, 0.92), Color(0.02, 0.01, 0.03, 0.05))
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var scrim_b := TextureRect.new()
	scrim_b.set_anchors_preset(PRESET_FULL_RECT)
	scrim_b.texture = _v_gradient(Color(0.02, 0.01, 0.03, 0.0), Color(0.02, 0.01, 0.03, 0.85))
	scrim_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim_b)

	# --- predator portrait (pink-keyed), anchored bottom-right ---
	var portrait := TextureRect.new()
	portrait.texture = _tex(PORTRAIT_PATH)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.anchor_left = 1.0
	portrait.anchor_top = 1.0
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait.offset_left = -680
	portrait.offset_top = -680
	portrait.offset_right = -30
	portrait.offset_bottom = -10
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Modern-urban-predator portrait is pre-feathered (alpha), so no chroma key needed.
	add_child(portrait)
	_reveal.append(portrait)

	# --- left dossier column ---
	var margin := MarginContainer.new()
	margin.anchor_left = 0.0
	margin.anchor_top = 1.0
	margin.anchor_right = 0.0
	margin.anchor_bottom = 1.0
	margin.offset_left = 0
	margin.offset_top = -500
	margin.offset_right = 660
	margin.offset_bottom = 0
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_bottom", 64)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	var kicker := _label(tr("MENU_KICKER"), th.mono_font() if th else null, 15, th.color_moon if th else Color.CYAN)
	kicker.add_theme_constant_override("line_spacing", 2)
	col.add_child(kicker)
	_reveal.append(kicker)

	var titlelbl := Label.new()
	titlelbl.text = tr("GAME_TITLE")
	if th != null and th.display_font() != null:
		titlelbl.add_theme_font_override("font", th.display_font())
	titlelbl.add_theme_font_size_override("font_size", 96)
	titlelbl.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
	titlelbl.add_theme_color_override("font_shadow_color", Color(0.82, 0.05, 0.12, 0.85))
	titlelbl.add_theme_constant_override("shadow_offset_x", 0)
	titlelbl.add_theme_constant_override("shadow_offset_y", 6)
	titlelbl.add_theme_constant_override("shadow_outline_size", 10)
	col.add_child(titlelbl)
	_reveal.append(titlelbl)

	var tagline := _label(tr("MENU_TAGLINE"), th.mono_font() if th else null, 16, th.color_text_dim if th else Color.GRAY)
	col.add_child(tagline)
	_reveal.append(tagline)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	col.add_child(gap)

	_btn_new = _dossier_button("01", tr("MENU_NEW_GAME"), _on_new_game)
	_btn_continue = _dossier_button("02", tr("MENU_CONTINUE"), _on_continue)
	_btn_continue.disabled = not _has_save()
	_btn_settings = _dossier_button("03", tr("MENU_SETTINGS"), _on_settings)
	_btn_quit = _dossier_button("04", tr("MENU_QUIT"), _on_quit)
	for b in [_btn_new, _btn_continue, _btn_settings, _btn_quit]:
		col.add_child(b)
		_reveal.append(b)

	# --- scanline / vignette atmosphere overlay (top) ---
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	overlay.color = Color(1, 1, 1, 1)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(SCAN_SHADER):
		var m := ShaderMaterial.new()
		m.shader = load(SCAN_SHADER)
		overlay.material = m
	add_child(overlay)


func _label(text: String, font: Font, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	return l


## A left-aligned dossier row: mono index + Oswald label, amber focus. Hover slides + brightens.
func _dossier_button(index: String, text: String, callback: Callable) -> Button:
	var th := _theme()
	var b := Button.new()
	b.text = "%s    %s" % [index, text]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(440, 54)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_color_override("font_color", Color(0.86, 0.83, 0.76))
	b.add_theme_color_override("font_hover_color", th.color_gold if th else Color(0.92, 0.62, 0.22))
	b.add_theme_color_override("font_focus_color", th.color_gold if th else Color(0.92, 0.62, 0.22))
	b.add_theme_font_size_override("font_size", 22)
	# Dossier card styleboxes: thin left blood-bar, translucent black, amber edge on focus/hover.
	b.add_theme_stylebox_override("normal", _row_style(Color(0.04, 0.03, 0.045, 0.55), Color(0.82, 0.10, 0.18), 1.0))
	b.add_theme_stylebox_override("hover", _row_style(Color(0.10, 0.06, 0.06, 0.70), Color(0.92, 0.62, 0.22), 3.0))
	b.add_theme_stylebox_override("focus", _row_style(Color(0.10, 0.06, 0.06, 0.70), Color(0.92, 0.62, 0.22), 3.0))
	b.add_theme_stylebox_override("pressed", _row_style(Color(0.14, 0.07, 0.07, 0.80), Color(0.95, 0.18, 0.22), 4.0))
	b.add_theme_stylebox_override("disabled", _row_style(Color(0.03, 0.03, 0.03, 0.40), Color(0.25, 0.25, 0.25), 1.0))
	b.pressed.connect(callback)
	return b


func _row_style(bg: Color, bar: Color, bar_w: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bar
	s.border_width_left = int(bar_w * 4.0)
	s.content_margin_left = 22
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_right = 2
	return s


func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _chroma_material(key: Color) -> ShaderMaterial:
	if not ResourceLoader.exists(CHROMA_SHADER):
		return null
	var m := ShaderMaterial.new()
	m.shader = load(CHROMA_SHADER)
	m.set_shader_parameter("key_color", Vector3(key.r, key.g, key.b))
	m.set_shader_parameter("threshold", 0.42)
	m.set_shader_parameter("softness", 0.16)
	return m


func _h_gradient(left: Color, right: Color) -> GradientTexture2D:
	return _gradient(left, right, Vector2(0, 0.5), Vector2(1, 0.5))


func _v_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	return _gradient(top, bottom, Vector2(0.5, 0), Vector2(0.5, 1))


func _gradient(a: Color, b: Color, from: Vector2, to: Vector2) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill_from = from
	t.fill_to = to
	return t


## Staggered fade-in reveal once the screen has opened (respects reduced motion).
## Modulate-only — position tweens would fight the VBox/anchored layout.
func _on_opened() -> void:
	if UIManager != null and UIManager.is_reduced_motion():
		return
	var delay := 0.0
	for node in _reveal:
		if node == null:
			continue
		node.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(node, "modulate:a", 1.0, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		delay += 0.08


func _button(text: String, callback: Callable) -> Button:
	return _dossier_button("--", text, callback)


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
