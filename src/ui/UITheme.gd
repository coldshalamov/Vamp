## UITheme.gd — programmatic theme + accessibility flags for the UI layer.
##
## Why a Resource and not a .tres? The vertical-slice frontend must be trivially restylable
## by the vision agent WITHOUT touching scene files. A programmatic theme means every color,
## font size, and spacing value is a single, documented, overridable property. The vision
## agent (or a future UI_STYLE_GUIDE.tres) swaps these constants; nothing else changes.
##
## Accessibility flags live here too, because they are presentation-layer concerns that the
## HUD, menus, captions, and every tween must read uniformly. UIManager owns the live
## instance and pushes changes (reduced_motion -> CueBus, text_scale -> theme rebuild).
extends Resource
class_name UITheme

# --- accessibility flags (persisted via UIManager -> user://settings.cfg) ---
@export var text_scale: float = 1.0           # 0.75 .. 1.50
@export var high_contrast: bool = false
@export var reduced_motion: bool = false
@export var reduced_flash: bool = false
@export var colorblind_mode: String = "off"   # off | protanopia | deuteranopia | tritanopia
@export var captions_enabled: bool = true

# --- palette: "NIGHT SHIFT" — occult police-scanner / crime-dossier predator UI ---
# Charcoal base, blood-crimson + sodium-amber accents, cold scanner-cyan for system text.
@export var color_bg: Color = Color(0.035, 0.030, 0.042, 0.95)    # charcoal void
@export var color_panel: Color = Color(0.06, 0.05, 0.065, 0.97)   # dossier card
@export var color_blood: Color = Color(0.82, 0.10, 0.18, 1.0)     # vitae / HP — crimson
@export var color_gold: Color = Color(0.92, 0.62, 0.22, 1.0)      # hunger / sodium amber
@export var color_moon: Color = Color(0.42, 0.84, 0.92, 1.0)      # heat / scanner cyan
@export var color_text: Color = Color(0.91, 0.88, 0.80, 1.0)      # bone white
@export var color_text_dim: Color = Color(0.58, 0.56, 0.52, 1.0)  # redacted grey
@export var color_focus: Color = Color(0.92, 0.62, 0.22, 1.0)     # amber focus ring
@export var color_danger: Color = Color(0.95, 0.18, 0.22, 1.0)
@export var color_good: Color = Color(0.42, 0.82, 0.52, 1.0)

# --- type scale (base px at 100%) ---
@export var font_size_body: int = 16
@export var font_size_title: int = 36
@export var font_size_hud: int = 14

# --- spacing tokens (theme constants) ---
@export var space_tight: int = 4
@export var space_normal: int = 8
@export var space_wide: int = 16

# --- animation tokens (seconds). Honoured only when reduced_motion == false. ---
@export var anim_open: float = 0.18
@export var anim_close: float = 0.12
@export var anim_floating: float = 0.7

const MIN_SCALE := 0.75
const MAX_SCALE := 1.50

# --- type system (NIGHT SHIFT): Cinzel = engraved occult display, Oswald = condensed UI,
#     ShareTechMono = scanner/dossier data readouts. Loaded lazily + cached. ---
const DISPLAY_FONT_PATH := "res://art/fonts/Cinzel.ttf"
const UI_FONT_PATH := "res://art/fonts/Oswald.ttf"
const MONO_FONT_PATH := "res://art/fonts/ShareTechMono.ttf"
var _display_font: Font = null
var _ui_font: Font = null
var _mono_font: Font = null


func display_font() -> Font:
	if _display_font == null and ResourceLoader.exists(DISPLAY_FONT_PATH):
		_display_font = load(DISPLAY_FONT_PATH)
	return _display_font


func ui_font() -> Font:
	if _ui_font == null and ResourceLoader.exists(UI_FONT_PATH):
		_ui_font = load(UI_FONT_PATH)
	return _ui_font


func mono_font() -> Font:
	if _mono_font == null and ResourceLoader.exists(MONO_FONT_PATH):
		_mono_font = load(MONO_FONT_PATH)
	return _mono_font


## Build a Godot Theme from the current tokens. Called whenever accessibility flags change.
func build_theme() -> Theme:
	var t := Theme.new()
	var scale := clampf(text_scale, MIN_SCALE, MAX_SCALE)
	var body := int(round(font_size_body * scale))
	var title := int(round(font_size_title * scale))
	var hud := int(round(font_size_hud * scale))
	var txt := color_text if not high_contrast else Color(1, 1, 1, 1)
	var txt_dim := color_text_dim if not high_contrast else Color(0.92, 0.92, 0.92, 1)
	var contrast_panel := color_panel
	if high_contrast:
		contrast_panel = Color(0.0, 0.0, 0.0, 0.98)

	# Colorblind retint: shift the accent hues so status never relies on red/green alone.
	# (Icons + shapes still carry meaning; this only adjusts the tint.)
	var blood := color_blood
	var gold := color_gold
	match colorblind_mode:
		"protanopia", "deuteranopia":
			blood = Color(0.90, 0.50, 0.10, 1.0)   # red -> amber
			gold = Color(0.95, 0.95, 0.40, 1.0)    # gold -> bright yellow
		"tritanopia":
			blood = Color(0.85, 0.20, 0.55, 1.0)   # red -> magenta
			gold = Color(0.30, 0.85, 0.95, 1.0)    # gold -> cyan

	# --- fonts: Oswald everywhere by default; ShareTechMono for numeric/data controls ---
	var uif := ui_font()
	if uif != null:
		t.set_default_font(uif)
		t.set_font("font", "Label", uif)
		t.set_font("font", "Button", uif)
		t.set_font("font", "OptionButton", uif)
		t.set_font("font", "CheckButton", uif)
		t.set_font("font", "TabContainer", uif)
	var mf := mono_font()
	if mf != null:
		t.set_font("font", "ProgressBar", mf)
		t.set_font("font", "LineEdit", mf)
	t.set_default_font_size(body)

	t.set_color("font_color", "Label", txt)
	t.set_color("font_color", "Button", txt)
	t.set_color("font_color", "RichTextLabel", txt)
	t.set_color("font_hover_color", "Button", color_focus)
	t.set_color("font_pressed_color", "Button", color_focus)
	t.set_color("font_focus_color", "Button", color_focus)
	t.set_color("font_disabled_color", "Button", txt_dim)
	t.set_font_size("font_size", "Label", body)
	t.set_font_size("font_size", "Button", body)
	t.set_font_size("font_size", "RichTextLabel", body)
	t.set_font_size("font_size", "LineEdit", body)
	t.set_font_size("font_size", "OptionButton", body)
	t.set_font_size("font_size", "Slider", body)
	t.set_font_size("title_size", "Label", title)

	# ProgressBar (vitae / HP bars).
	t.set_color("font_color", "ProgressBar", txt_dim)
	t.set_font_size("font_size", "ProgressBar", hud)
	t.set_color("fill_color", "ProgressBar", blood)

	# Buttons: flat placeholder panel + focus ring. Vision agent overrides StyleBoxes.
	var btn := StyleBoxFlat.new()
	btn.bg_color = contrast_panel
	btn.border_color = color_focus
	btn.set_border_width_all(1)
	btn.set_corner_radius_all(2)
	btn.content_margin_left = space_wide
	btn.content_margin_right = space_wide
	btn.content_margin_top = space_normal
	btn.content_margin_bottom = space_normal
	t.set_stylebox("normal", "Button", btn)
	var btn_hover := btn.duplicate()
	btn_hover.border_color = color_focus
	btn_hover.bg_color = contrast_panel.lightened(0.10)
	t.set_stylebox("hover", "Button", btn_hover)
	var btn_focus := btn.duplicate()
	btn_focus.border_color = color_focus
	btn_focus.set_border_width_all(2)
	t.set_stylebox("focus", "Button", btn_focus)
	var btn_pressed := btn.duplicate()
	btn_pressed.bg_color = contrast_panel.lightened(0.18)
	t.set_stylebox("pressed", "Button", btn_pressed)
	var btn_disabled := btn.duplicate()
	btn_disabled.bg_color = contrast_panel.darkened(0.3)
	t.set_stylebox("disabled", "Button", btn_disabled)

	# Panels.
	var panel := StyleBoxFlat.new()
	panel.bg_color = contrast_panel
	panel.border_color = color_focus.darkened(0.4)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(3)
	panel.content_margin_left = space_wide
	panel.content_margin_right = space_wide
	panel.content_margin_top = space_wide
	panel.content_margin_bottom = space_wide
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)

	# ProgressBar track + fill.
	var track := StyleBoxFlat.new()
	track.bg_color = contrast_panel.darkened(0.2)
	track.set_corner_radius_all(2)
	t.set_stylebox("background", "ProgressBar", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = blood
	fill.set_corner_radius_all(2)
	t.set_stylebox("fill", "ProgressBar", fill)

	# Spacing constants exposed for containers that read theme constants.
	t.set_constant("separation", "VBoxContainer", space_normal)
	t.set_constant("separation", "HBoxContainer", space_normal)
	t.set_constant("separation", "GridContainer", space_normal)

	# Stash the retinted accents so HUD scripts can fetch them without recomputing.
	t.set_color("blood", "UITheme", blood)
	t.set_color("gold", "UITheme", gold)
	t.set_color("moon", "UITheme", color_moon)
	t.set_color("danger", "UITheme", color_danger)
	t.set_color("good", "UITheme", color_good)
	t.set_color("dim", "UITheme", txt_dim)
	return t


## Serialize the accessibility/user-facing flags to a plain dict for ConfigFile.
func to_settings_dict() -> Dictionary:
	return {
		"text_scale": text_scale,
		"high_contrast": high_contrast,
		"reduced_motion": reduced_motion,
		"reduced_flash": reduced_flash,
		"colorblind_mode": colorblind_mode,
		"captions_enabled": captions_enabled,
	}


func apply_settings_dict(d: Dictionary) -> void:
	text_scale = clampf(float(d.get("text_scale", text_scale)), MIN_SCALE, MAX_SCALE)
	high_contrast = bool(d.get("high_contrast", high_contrast))
	reduced_motion = bool(d.get("reduced_motion", reduced_motion))
	reduced_flash = bool(d.get("reduced_flash", reduced_flash))
	colorblind_mode = String(d.get("colorblind_mode", colorblind_mode))
	captions_enabled = bool(d.get("captions_enabled", captions_enabled))
