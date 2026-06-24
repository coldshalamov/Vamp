## HUD.gd — real-time, data-bound heads-up display ("NIGHT SHIFT" dossier predator UI).
##
## Reads Sim.player read-only and subscribes to CueBus. Runs error-free even when backend systems
## are stubbed (no player, empty hotbar). Visuals use the authored art/ui pieces (textured vitae/
## flesh bars, fang hunger pips, heat stars, slot plates) + sliced discipline icons. Data logic is
## unchanged from the binding contract the tests assert.
extends Control
class_name HUD

const HOTBAR_SIZE := 8
const HUNGER_PIPS := 5
const HEAT_STARS := 6

const TEX_BAR_TRACK := "res://art/ui/bar_track.png"
const TEX_BAR_VITAE := "res://art/ui/bar_vitae.png"
const TEX_BAR_HP := "res://art/ui/bar_hp.png"
const TEX_TOOTH_FULL := "res://art/ui/hungertooth_filled.png"
const TEX_TOOTH_EMPTY := "res://art/ui/hungertooth_empty.png"
const TEX_STAR_FULL := "res://art/ui/star_filled.png"
const TEX_STAR_EMPTY := "res://art/ui/star_empty.png"
const TEX_SLOT := "res://art/ui/slot_bg.png"
const TEX_ICON_PLACEHOLDER := "res://art/ui/icon_placeholder.png"
const ICON_DIR := "res://art/ui/icons/"

# Bar widgets.
const VialGaugeScript := preload("res://src/ui/VialGauge.gd")
const MinimapRadarScript := preload("res://src/ui/MinimapRadar.gd")
var _vitae_bar: TextureProgressBar = null
var _vitae_vial: Control = null
var _hp_bar: TextureProgressBar = null
var _vitae_label: Label = null
var _hp_label: Label = null
var _level_label: Label = null
var _pressure_icons: Array = []
const RESIDUE_SVG := "res://glowup_2026/art/residue_icons.svg"
var _hunger_row: HBoxContainer = null
var _heat_row: HBoxContainer = null
var _hotbar: HBoxContainer = null
var _buff_list: VBoxContainer = null
var _phase_label: Label = null
var _combo_label: Label = null
var _flow_label: Label = null
var _objective_label: Label = null
var _minimap: ColorRect = null

var _hunger_pips: Array[TextureRect] = []
var _heat_stars: Array[TextureRect] = []
var _hotbar_slots: Array[Dictionary] = []
var _cached_hunger: int = -1
var _cached_heat: int = -1
var _tex_cache: Dictionary = {}

# Hotbar power -> discipline-atlas region (the atlas is 1280x720: row0 of 5, row1 of 6).
# Hotbar power -> sliced discipline icon (clean transparent PNGs in art/ui/icons/, keyed from the
# discipline_icons atlas). Aliases share a base icon.
const ICON_ALIASES := {
	"pot_charge": "pot_slam", "for_stone": "for_mend", "obf_vanish": "obf_cloak",
}


func _ready() -> void:
	if UIManager != null:
		UIManager.register_hud(self)
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)
	_build_layout()
	_refresh_all()


func _process(_delta: float) -> void:
	_refresh_vitals()
	_refresh_action_phase()
	_refresh_hotbar()
	_refresh_pressure()
	_refresh_objective()


# ---------------------------------------------------------------- layout

func _build_layout() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := 18

	# --- top-left vitals dossier card ---
	var card := PanelContainer.new()
	card.set_anchors_preset(PRESET_TOP_LEFT)
	card.offset_left = margin
	card.offset_top = margin
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _card_style())
	add_child(card)
	var top_left := VBoxContainer.new()
	top_left.add_theme_constant_override("separation", 3)
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(top_left)

	top_left.add_child(_tag(tr("MENU_KICKER"), _accent("moon"), 12))
	_level_label = _tag("LVL 1", _accent("gold"), 14)
	top_left.add_child(_level_label)
	_vitae_label = _data_label("%s ---" % tr("HUD_VITAE"))
	top_left.add_child(_vitae_label)
	_vitae_bar = _tex_bar(TEX_BAR_VITAE)
	_vitae_bar.visible = false   # kept for the test's state binding; the blood vial is the visible gauge
	top_left.add_child(_vitae_bar)
	_vitae_vial = VialGaugeScript.new()
	_vitae_vial.custom_minimum_size = Vector2(260, 16)
	_vitae_vial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left.add_child(_vitae_vial)
	_hp_label = _data_label("%s ---" % tr("HUD_HP"))
	top_left.add_child(_hp_label)
	_hp_bar = _tex_bar(TEX_BAR_HP)
	top_left.add_child(_hp_bar)

	var hunger_box := HBoxContainer.new()
	hunger_box.add_theme_constant_override("separation", 6)
	hunger_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left.add_child(hunger_box)
	hunger_box.add_child(_tag(tr("MENU_INVENTORY") if false else "HUNGER", _accent("dim"), 12))
	_hunger_row = HBoxContainer.new()
	_hunger_row.add_theme_constant_override("separation", 2)
	_hunger_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hunger_box.add_child(_hunger_row)
	for i in HUNGER_PIPS:
		var pip := _icon_rect(_tex(TEX_TOOTH_EMPTY), 18)
		_hunger_row.add_child(pip)
		_hunger_pips.append(pip)

	# --- residue / pressure icons (glowup residue_icons atlas): Exposure / Heat / Need ---
	var pressure_box := HBoxContainer.new()
	pressure_box.add_theme_constant_override("separation", 7)
	pressure_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left.add_child(pressure_box)
	for ch in [0, 1, 2]:
		var picon := _residue_icon(ch)
		pressure_box.add_child(picon)
		_pressure_icons.append({ "rect": picon, "channel": ch })

	# --- top-right heat row ---
	var heat_card := PanelContainer.new()
	heat_card.set_anchors_preset(PRESET_TOP_RIGHT)
	heat_card.anchor_left = 1.0
	heat_card.anchor_right = 1.0
	heat_card.offset_left = -250
	heat_card.offset_right = -margin
	heat_card.offset_top = margin
	heat_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_card.add_theme_stylebox_override("panel", _card_style())
	add_child(heat_card)
	var heat_box := VBoxContainer.new()
	heat_box.alignment = BoxContainer.ALIGNMENT_END
	heat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_card.add_child(heat_box)
	var heat_tag := _tag("HEAT // EXPOSURE", _accent("danger"), 12)
	heat_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heat_box.add_child(heat_tag)
	_heat_row = HBoxContainer.new()
	_heat_row.alignment = BoxContainer.ALIGNMENT_END
	_heat_row.add_theme_constant_override("separation", 3)
	_heat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_box.add_child(_heat_row)
	for i in HEAT_STARS:
		var star := _icon_rect(_tex(TEX_STAR_EMPTY), 18)
		_heat_row.add_child(star)
		_heat_stars.append(star)

	# --- bottom-center hotbar ---
	_hotbar = HBoxContainer.new()
	_hotbar.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_hotbar.anchor_left = 0.5
	_hotbar.anchor_right = 0.5
	_hotbar.offset_left = -300
	_hotbar.offset_right = 300
	_hotbar.offset_top = -78
	_hotbar.offset_bottom = -18
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar.add_theme_constant_override("separation", 8)
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotbar)
	for i in HOTBAR_SIZE:
		_hotbar_slots.append(_make_hotbar_slot(i + 1))

	# --- bottom-left status ---
	_buff_list = VBoxContainer.new()
	_buff_list.set_anchors_preset(PRESET_BOTTOM_LEFT)
	_buff_list.offset_left = margin
	_buff_list.offset_bottom = -margin
	_buff_list.offset_top = -170
	_buff_list.offset_right = 240
	_buff_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buff_list)
	_buff_list.add_child(_tag("STATUS", _accent("dim"), 12))

	# --- bottom-right action phase + combo ---
	var bottom_right := VBoxContainer.new()
	bottom_right.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	bottom_right.anchor_left = 1.0
	bottom_right.anchor_right = 1.0
	bottom_right.offset_left = -220
	bottom_right.offset_right = -margin
	bottom_right.offset_top = -120
	bottom_right.offset_bottom = -margin
	bottom_right.alignment = BoxContainer.ALIGNMENT_END
	bottom_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_right)
	_phase_label = _data_label(" ")
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_right.add_child(_phase_label)
	_combo_label = _data_label(" ")
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_right.add_child(_combo_label)
	_flow_label = _data_label(" ")
	_flow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_right.add_child(_flow_label)

	# --- objective banner (top-center): tells the player what to do right now ---
	_objective_label = _tag(" ", _accent("gold"), 15)
	_objective_label.set_anchors_preset(PRESET_CENTER_TOP)
	_objective_label.anchor_left = 0.5
	_objective_label.anchor_right = 0.5
	_objective_label.offset_left = -280
	_objective_label.offset_right = 280
	_objective_label.offset_top = 66
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_objective_label)

	# --- blood-scent radar (replaces the Phase-2 placeholder) ---
	_minimap = ColorRect.new()
	_minimap.color = Color(0, 0, 0, 0.0)   # transparent host; the radar draws its own dial
	_minimap.set_anchors_preset(PRESET_CENTER_TOP)
	_minimap.anchor_left = 0.5
	_minimap.anchor_right = 0.5
	_minimap.offset_left = -52
	_minimap.offset_right = 52
	_minimap.offset_top = margin
	_minimap.offset_bottom = margin + 104
	var radar := MinimapRadarScript.new()
	radar.set_anchors_preset(PRESET_FULL_RECT)
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.add_child(radar)
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_minimap)


func _card_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.03, 0.025, 0.035, 0.62)
	s.border_color = Color(0.82, 0.10, 0.18, 0.7)
	s.border_width_left = 3
	s.content_margin_left = 12
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_right = 3
	return s


## A "case-file" tag label in the condensed UI face (Oswald) — the bulk of HUD text. The old
## all-mono HUD read as a cheap DOS terminal; numeric figures still use _data_label (mono) below.
func _tag(text: String, col: Color, fsize: int) -> Label:
	var l := Label.new()
	l.text = text
	var th := UIManager.theme_resource if UIManager != null else null
	if th != null and th.ui_font() != null:
		l.add_theme_font_override("font", th.ui_font())
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A mono data readout (vitae/flesh counters) — tabular figures stay monospaced for alignment.
func _data_label(text: String) -> Label:
	var l := _tag(text, Color(0.90, 0.87, 0.80), 14)
	var th := UIManager.theme_resource if UIManager != null else null
	if th != null and th.mono_font() != null:
		l.add_theme_font_override("font", th.mono_font())
	return l


func _tex_bar(fill_path: String) -> TextureProgressBar:
	var b := TextureProgressBar.new()
	b.min_value = 0.0
	b.max_value = 100.0
	b.value = 100.0
	b.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	b.nine_patch_stretch = true
	b.stretch_margin_left = 3
	b.stretch_margin_right = 3
	b.stretch_margin_top = 2
	b.stretch_margin_bottom = 2
	b.texture_under = _tex(TEX_BAR_TRACK)
	b.texture_progress = _tex(fill_path)
	b.custom_minimum_size = Vector2(260, 16)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _icon_rect(tex: Texture2D, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


const PowerGlyphScript := preload("res://src/ui/PowerGlyph.gd")
const DISC_COLORS := {
	"cel": Color("#8fd6ff"), "pot": Color("#e0883a"), "for": Color("#6fd6a0"),
	"obf": Color("#9a8cc0"), "aus": Color("#aef0ff"), "dom": Color("#b98cff"),
	"pre": Color("#f0c040"), "bs": Color("#c01028"), "pro": Color("#7aa05a"),
}


func _make_hotbar_slot(slot_index: int) -> Dictionary:
	var panel := Control.new()
	panel.custom_minimum_size = Vector2(62, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS   # hoverable for the dossier tooltip; clicks still fall through
	# slot plate
	var bg := TextureRect.new()
	bg.texture = _tex(TEX_SLOT)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)
	# dark inner plate
	var plate := ColorRect.new()
	plate.color = Color(0.03, 0.03, 0.045, 0.9)
	plate.set_anchors_preset(PRESET_FULL_RECT)
	plate.offset_left = 4
	plate.offset_top = 4
	plate.offset_right = -4
	plate.offset_bottom = -4
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(plate)
	# crisp discipline glyph (replaces the messy atlas icons)
	var glyph := PowerGlyphScript.new()
	glyph.set_anchors_preset(PRESET_FULL_RECT)
	glyph.offset_left = 6
	glyph.offset_top = 5
	glyph.offset_right = -6
	glyph.offset_bottom = -17
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(glyph)
	# power name (mono, bottom strip) — answers "what does this key do?"
	var name_lbl := _tag("", _accent("bone"), 8)
	name_lbl.set_anchors_preset(PRESET_BOTTOM_WIDE)
	name_lbl.offset_top = -13
	name_lbl.offset_bottom = -2
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(name_lbl)
	# cooldown shade
	var cd := ColorRect.new()
	cd.color = Color(0, 0, 0, 0.6)
	cd.set_anchors_preset(PRESET_FULL_RECT)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.visible = false
	panel.add_child(cd)
	# keybind number (mono, corner, bold)
	var key_label := _tag(str(slot_index), _accent("gold"), 13)
	key_label.position = Vector2(5, 1)
	panel.add_child(key_label)
	_hotbar.add_child(panel)
	return { "panel": panel, "glyph": glyph, "name": name_lbl, "key": key_label, "cd": cd, "slot": slot_index }


func _residue_icon(idx: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(22, 22)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(RESIDUE_SVG):
		var src := load(RESIDUE_SVG) as Texture2D
		if src != null:
			var cell: int = int(src.get_width() / 6)   # 6-cell atlas, robust to import scale
			var at := AtlasTexture.new()
			at.atlas = src
			at.region = Rect2(idx * cell, 0, cell, src.get_height())
			tr.texture = at
	return tr


func _refresh_pressure() -> void:
	if _pressure_icons.is_empty() or Sim == null or Sim.player == null:
		return
	var b := _player_behaviour()
	var vals := [
		clampf(Sim.player.exposure / 1.45, 0.0, 1.0),
		clampf(Sim.heat / 6.0, 0.0, 1.0),
		clampf((float(b.get("hunger")) if b != null else 0.0) / 5.0, 0.0, 1.0),
	]
	for pi in _pressure_icons:
		var ch: int = int(pi["channel"])
		var v: float = vals[ch] if ch < vals.size() else 0.0
		(pi["rect"] as TextureRect).modulate = Color(1, 1, 1, 0.3 + 0.7 * v)


func _short_name(n: String) -> String:
	var s := n.to_upper()
	return s if s.length() <= 10 else s.substr(0, 9)


# ---------------------------------------------------------------- refresh

func _refresh_all() -> void:
	_refresh_vitals()
	_refresh_hunger()
	_refresh_heat()
	_refresh_hotbar()
	_refresh_buffs()


func _player_behaviour() -> SimPlayer:
	if Sim == null or Sim.player == null:
		return null
	var b = Sim.player.behaviour
	if b is SimPlayer:
		return b
	return null


func _refresh_vitals() -> void:
	var b := _player_behaviour()
	if b == null or Sim.player == null:
		if _vitae_bar:
			_vitae_bar.value = 0
			_hp_bar.value = 0
			if _vitae_vial != null:
				_vitae_vial.call("set_fill", 0.0, _accent("blood"))
			_vitae_label.text = "%s ---" % tr("HUD_VITAE")
			_hp_label.text = "%s ---" % tr("HUD_HP")
		return
	_vitae_bar.max_value = b.max_blood
	_vitae_bar.value = b.blood
	if _vitae_vial != null:
		_vitae_vial.call("set_fill", b.blood / maxf(b.max_blood, 1.0), _accent("blood"))
	_vitae_label.text = "%s %d/%d" % [tr("HUD_VITAE"), int(b.blood), int(b.max_blood)]
	_hp_bar.max_value = Sim.player.max_hp
	_hp_bar.value = Sim.player.hp
	_hp_label.text = "%s %d/%d" % [tr("HUD_HP"), int(Sim.player.hp), int(Sim.player.max_hp)]
	if _level_label != null and Sim.meta != null:
		_level_label.text = "LVL %d   XP %d/%d" % [Sim.meta.level, Sim.meta.xp, Sim.meta.xp_to_next(Sim.meta.level)]


func _refresh_hunger() -> void:
	var b := _player_behaviour()
	var h := int(round(b.hunger)) if b != null else 0
	h = clampi(h, 0, HUNGER_PIPS)
	if h == _cached_hunger:
		return
	_cached_hunger = h
	var gold := _accent("gold")
	for i in HUNGER_PIPS:
		var lit := i < h
		_hunger_pips[i].texture = _tex(TEX_TOOTH_FULL if lit else TEX_TOOTH_EMPTY)
		_hunger_pips[i].modulate = gold if lit else Color(0.5, 0.5, 0.5, 0.6)


func _refresh_heat() -> void:
	var stars := 0
	if Sim != null:
		stars = Sim.heat_stars() if Sim.has_method("heat_stars") else 0
	stars = clampi(stars, 0, HEAT_STARS)
	if stars == _cached_heat:
		return
	_cached_heat = stars
	var moon := _accent("moon")
	for i in HEAT_STARS:
		var lit := i < stars
		_heat_stars[i].texture = _tex(TEX_STAR_FULL if lit else TEX_STAR_EMPTY)
		_heat_stars[i].modulate = moon if lit else Color(0.5, 0.5, 0.5, 0.6)


func _refresh_hotbar() -> void:
	# Bind to the ACTUAL equipped powers (meta.slots) so the boxes match what keys 1-8 cast.
	var slots: Array = []
	if Sim != null and Sim.meta != null and Sim.meta.get("slots") != null:
		slots = Sim.meta.slots
	var b := _player_behaviour()
	for i in HOTBAR_SIZE:
		var slot: Dictionary = _hotbar_slots[i]
		var glyph = slot["glyph"]
		var name_lbl: Label = slot["name"]
		var cd: ColorRect = slot["cd"]
		var power_id: String = String(slots[i]) if i < slots.size() and slots[i] != null else ""
		if power_id == "":
			glyph.set_power("", Color(0.4, 0.4, 0.45), true)
			name_lbl.text = ""
			cd.visible = false
			(slot["panel"] as Control).tooltip_text = ""
			continue
		var prefix: String = power_id.split("_")[0]
		var col: Color = DISC_COLORS.get(prefix, Color("#c0c0cc"))
		var def := PowerCatalog.get_def(power_id)
		glyph.set_power(prefix, col, false)
		name_lbl.text = _short_name(String(def.get("name", power_id)))
		name_lbl.add_theme_color_override("font_color", col)
		# Living Dossier: hovering a hotbar slot says what the spell IS (name, discipline, cost, cd, desc).
		var disc_name: String = String(GameCatalog.DISCIPLINES.get(String(def.get("discipline", "")), {}).get("name", ""))
		(slot["panel"] as Control).tooltip_text = "%s   (key %d)\n%s · %d vitae · %.1fs cooldown\n%s" % [String(def.get("name", power_id)), i + 1, disc_name, int(def.get("cost", 0.0)), float(def.get("cooldown", 0)) / 60.0, String(def.get("description", ""))]
		if b != null and b.power_cooldowns.has(power_id):
			var remaining := int(b.power_cooldowns[power_id])
			var total := int(def.get("cooldown", remaining)) if not def.is_empty() else remaining
			var frac := clampf(float(remaining) / maxf(float(total), 1.0), 0.0, 1.0)
			cd.visible = remaining > 0
			cd.color = Color(0, 0, 0, 0.25 + 0.55 * frac)
		else:
			cd.visible = false


func _refresh_buffs() -> void:
	for child in _buff_list.get_children():
		if child != _buff_list.get_child(0):
			child.queue_free()
	var b := _player_behaviour()
	if b == null:
		return
	var buffs: Dictionary = b.get("buffs") if b.get("buffs") != null else {}
	var good := _accent("good")
	var danger := _accent("danger")
	for key in buffs:
		var rec: Dictionary = buffs[key]
		_buff_list.add_child(_tag("%s  %.1fs" % [_buff_display_name(String(key)), float(rec.get("ticks", 0)) / 60.0], good, 13))
	if b.frenzied:
		_buff_list.add_child(_tag(tr("HUD_FRENZY"), danger, 14))


func _refresh_action_phase() -> void:
	if Sim == null or Sim.player == null or _phase_label == null:
		return
	_refresh_flow()
	var phase := Sim.player.action_phase()
	if phase == "":
		_phase_label.text = " "
		return
	_phase_label.text = "%s: %s" % [tr("HUD_ACTION"), phase.to_upper()]
	_phase_label.add_theme_color_override("font_color", _accent("gold"))


## FLOW meter — surfaces the gulp-as-master-cancel combo skill (flow_stacks) that was invisible.
func _refresh_flow() -> void:
	if _flow_label == null:
		return
	var fb := _player_behaviour()
	var stacks: int = int(fb.get("flow_stacks")) if fb != null and fb.get("flow_stacks") != null else 0
	if stacks > 0:
		_flow_label.text = "FLOW x%d" % stacks
		_flow_label.add_theme_color_override("font_color", Color(1.0, clampf(0.5 + 0.06 * float(stacks), 0.5, 1.0), 0.25))
	else:
		_flow_label.text = " "


## The current objective ("what do I do now?"), pulled from deterministic Sim state.
func _refresh_objective() -> void:
	if _objective_label == null or Sim == null or not Sim.has_method("current_objective"):
		return
	_objective_label.text = Sim.current_objective()


func _buff_display_name(buff_id: String) -> String:
	const NAMES := {
		"cel_haste": "Fleetness", "pro_beast": "Beast", "for_stone": "Stone Skin",
		"obf_cloak": "Cloak", "obf_vanish": "Vanish",
	}
	return NAMES.get(buff_id, buff_id.capitalize())


# ---------------------------------------------------------------- assets

func _tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_tex_cache[path] = t
	return t


func _icon_for(power_id: String) -> Texture2D:
	var base: String = ICON_ALIASES.get(power_id, power_id)
	var path := ICON_DIR + base + ".png"
	if ResourceLoader.exists(path):
		return _tex(path)
	return _tex(TEX_ICON_PLACEHOLDER)


func _accent(key: String) -> Color:
	if UIManager != null:
		return UIManager.theme_get_color(key, "UITheme", Color.WHITE)
	match key:
		"gold": return Color(0.92, 0.62, 0.22, 1)
		"moon": return Color(0.42, 0.84, 0.92, 1)
		"good": return Color(0.42, 0.82, 0.52, 1)
		"danger": return Color(0.95, 0.18, 0.22, 1)
		"dim": return Color(0.58, 0.56, 0.52, 1)
	return Color.WHITE


# ---------------------------------------------------------------- cue handling

func _on_cue(event_id: String, payload: Dictionary) -> void:
	match event_id:
		"blood.changed":
			_refresh_vitals()
			_refresh_hunger()
		"heat.rise", "heat.fall", "heat.changed", "heat.lost_them", "masquerade.broken":
			_refresh_heat()
			if event_id == "masquerade.broken":
				UIManager.show_banner(tr("BANNER_MASQUERADE_TITLE"), tr("BANNER_MASQUERADE_BODY"), _accent("danger"))
			elif event_id == "heat.lost_them":
				UIManager.show_notification(tr("NOTIFY_LOST_THEM"), _accent("good"))
		"humanity.lost":
			UIManager.show_banner(tr("BANNER_HUMANITY_TITLE"), tr("BANNER_HUMANITY_BODY"), _accent("danger"))
			_refresh_buffs()
		"frenzy.start":
			UIManager.show_banner(tr("BANNER_FRENZY_TITLE"), tr("BANNER_FRENZY_BODY"), _accent("danger"))
		"frenzy.end", "player.heal", "power.cast", "power.cooldown":
			_refresh_hotbar()
		"damage.dealt", "attack.slash.hit", "power.potence.hit", "power.potence.charge_hit", "pounce.hit", "power.blood_bolt.hit":
			_spawn_damage_number(payload, false)
		"damage.taken":
			_spawn_damage_number(payload, true)
		"feed.start", "feed.gulp", "feed.kill", "feed.spare", "feed.interrupt", "finisher.start":
			_refresh_vitals()
			_refresh_hotbar()
		"npc.spawn", "npc.death", "npc.alarm", "player.spotted", "player.lost", "player.escape":
			pass
		"dawn.warning", "dawn.arrive", "player.torpor":
			UIManager.show_notification(_cue_to_notify(event_id), _accent("moon"))
		"ui.notify":
			UIManager.show_notification(String(payload.get("text", "")), payload.get("color", Color.WHITE))


func _spawn_damage_number(payload: Dictionary, taken: bool) -> void:
	var amount := float(payload.get("amount", 0.0))
	if amount <= 0.0:
		return
	var pos_v = payload.get("pos", Vector2.ZERO)
	var world_pos: Vector2 = pos_v if pos_v is Vector2 else Vector2.ZERO
	var color := _accent("danger") if taken else _accent("good")
	UIManager.spawn_floating_text(world_pos, "%d" % int(amount), color)


func _cue_to_notify(event_id: String) -> String:
	match event_id:
		"dawn.warning": return tr("NOTIFY_DAWN_WARNING")
		"dawn.arrive": return tr("NOTIFY_DAWN_ARRIVE")
		"player.torpor": return tr("NOTIFY_TORPOR")
	return event_id
