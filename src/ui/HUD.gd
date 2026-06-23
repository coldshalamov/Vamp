## HUD.gd — real-time, data-bound heads-up display.
##
## Reads Sim.player read-only and subscribes to CueBus. It must run without console errors
## even when backend systems are stubbed (no player, empty hotbar, etc.) — every getter
## null-checks.
##
## Elements (PROMPT_FRONTEND_AGENT §2):
##   - Vitae bar (blood / max_blood)   - HP bar (hp / max_hp)
##   - Hunger pips (0-5)               - Heat stars (0-6)
##   - Hotbar (8 slots)                - Active buff/debuff list
##   - Damage numbers                  - Notifications / banners (delegated to overlays)
##   - Captions (CaptionOverlay)       - Combo / action-phase feedback
##   - Minimap placeholder
extends Control
class_name HUD

const HOTBAR_SIZE := 8
const HUNGER_PIPS := 5
const HEAT_STARS := 6

# Bar widgets.
var _vitae_bar: ProgressBar = null
var _hp_bar: ProgressBar = null
var _vitae_label: Label = null
var _hp_label: Label = null
var _hunger_row: HBoxContainer = null
var _heat_row: HBoxContainer = null
var _hotbar: HBoxContainer = null
var _buff_list: VBoxContainer = null
var _phase_label: Label = null
var _combo_label: Label = null
var _minimap: ColorRect = null

var _hunger_pips: Array[ColorRect] = []
var _heat_stars: Array[ColorRect] = []
var _hotbar_slots: Array[Dictionary] = []   # {panel, key_label, name_label, cd_overlay}
var _cached_hunger: int = -1
var _cached_heat: int = -1


func _ready() -> void:
	if UIManager != null:
		UIManager.register_hud(self)
	# Wire CueBus. UI only consumes; never emits these.
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)
	_build_layout()
	_refresh_all()


func _process(_delta: float) -> void:
	# Poll read-only every frame so bars track even when no cue fires. Cheaper than a tween
	# per value and safe because we never write Sim state.
	_refresh_vitals()
	_refresh_action_phase()


# ---------------------------------------------------------------- layout

func _build_layout() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # HUD never eats gameplay input
	# Root margin so HUD hugs the viewport edges; theme can override spacing.
	var margin := 16
	# --- top-left: vitae + HP ---
	var top_left := VBoxContainer.new()
	top_left.name = "TopLeft"
	top_left.set_anchors_preset(PRESET_TOP_LEFT)
	top_left.offset_right = 320
	top_left.offset_bottom = 120
	top_left.offset_left = margin
	top_left.offset_top = margin
	add_child(top_left)

	_vitae_label = _label("VITAE")
	top_left.add_child(_vitae_label)
	_vitae_bar = _bar()
	top_left.add_child(_vitae_bar)

	_hp_label = _label("HEALTH")
	top_left.add_child(_hp_label)
	_hp_bar = _bar()
	top_left.add_child(_hp_bar)

	# --- hunger pips (under bars) ---
	var hunger_box := HBoxContainer.new()
	hunger_box.name = "Hunger"
	hunger_box.add_theme_constant_override("separation", 3)
	top_left.add_child(hunger_box)
	hunger_box.add_child(_label("HUNGER"))
	_hunger_row = HBoxContainer.new()
	_hunger_row.add_theme_constant_override("separation", 2)
	hunger_box.add_child(_hunger_row)
	for i in HUNGER_PIPS:
		var pip := _pip_rect(Color.WHITE)
		_hunger_row.add_child(pip)
		_hunger_pips.append(pip)

	# --- top-right: heat stars ---
	var top_right := HBoxContainer.new()
	top_right.name = "TopRight"
	top_right.set_anchors_preset(PRESET_TOP_RIGHT)
	top_right.anchor_left = 1.0
	top_right.anchor_right = 1.0
	top_right.offset_left = -260
	top_right.offset_right = -margin
	top_right.offset_top = margin
	top_right.alignment = BoxContainer.ALIGNMENT_END
	add_child(top_right)
	top_right.add_child(_label("HEAT"))
	_heat_row = HBoxContainer.new()
	_heat_row.alignment = BoxContainer.ALIGNMENT_END
	_heat_row.add_theme_constant_override("separation", 3)
	top_right.add_child(_heat_row)
	for i in HEAT_STARS:
		var star := _pip_rect(Color.WHITE)
		_heat_row.add_child(star)
		_heat_stars.append(star)

	# --- bottom-center: hotbar (8 slots) ---
	_hotbar = HBoxContainer.new()
	_hotbar.name = "Hotbar"
	_hotbar.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_hotbar.anchor_left = 0.5
	_hotbar.anchor_right = 0.5
	_hotbar.offset_left = -260
	_hotbar.offset_right = 260
	_hotbar.offset_top = -64
	_hotbar.offset_bottom = -16
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar.add_theme_constant_override("separation", 6)
	add_child(_hotbar)
	for i in HOTBAR_SIZE:
		_hotbar_slots.append(_make_hotbar_slot(i + 1))

	# --- bottom-left: active buffs ---
	_buff_list = VBoxContainer.new()
	_buff_list.name = "Buffs"
	_buff_list.set_anchors_preset(PRESET_BOTTOM_LEFT)
	_buff_list.offset_left = margin
	_buff_list.offset_bottom = -margin
	_buff_list.offset_top = -160
	_buff_list.offset_right = 220
	add_child(_buff_list)
	_buff_list.add_child(_label("STATUS"))

	# --- bottom-right: action phase + combo ---
	var bottom_right := VBoxContainer.new()
	bottom_right.name = "ActionFeedback"
	bottom_right.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	bottom_right.anchor_left = 1.0
	bottom_right.anchor_right = 1.0
	bottom_right.offset_left = -180
	bottom_right.offset_right = -margin
	bottom_right.offset_top = -120
	bottom_right.offset_bottom = -margin
	bottom_right.alignment = BoxContainer.ALIGNMENT_END
	add_child(bottom_right)
	_phase_label = _label(" ")
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_right.add_child(_phase_label)
	_combo_label = _label(" ")
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_right.add_child(_combo_label)

	# --- top-center: minimap placeholder ---
	_minimap = ColorRect.new()
	_minimap.name = "MinimapPlaceholder"
	_minimap.color = Color(0.05, 0.05, 0.08, 0.6)
	_minimap.set_anchors_preset(PRESET_CENTER_TOP)
	_minimap.anchor_left = 0.5
	_minimap.anchor_right = 0.5
	_minimap.offset_left = -40
	_minimap.offset_right = 40
	_minimap.offset_top = margin
	_minimap.offset_bottom = margin + 48
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_minimap)


func _label(text_key: String) -> Label:
	var l := Label.new()
	l.text = tr(text_key)
	l.add_theme_font_size_override("font_size", _theme_hud_size())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar() -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 100.0
	b.value = 100.0
	b.custom_minimum_size = Vector2(280, 16)
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _pip_rect(color: Color) -> ColorRect:
	# A small filled rect tinted per pip. Colorblind-safe meaning comes from the row label
	# + count, not color alone.
	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(12, 12)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _make_hotbar_slot(slot_index: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(56, 48)
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	var key_label := Label.new()
	key_label.text = str(slot_index) if slot_index <= 4 else "—"
	key_label.add_theme_font_size_override("font_size", _theme_hud_size())
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(key_label)
	var name_label := Label.new()
	name_label.text = " "
	name_label.add_theme_font_size_override("font_size", _theme_hud_size())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)
	# Cooldown overlay: dark rect that scales with remaining cooldown.
	var cd := ColorRect.new()
	cd.color = Color(0, 0, 0, 0.6)
	cd.set_anchors_preset(PRESET_FULL_RECT)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.visible = false
	panel.add_child(cd)
	_hotbar.add_child(panel)
	return { "panel": panel, "key": key_label, "name": name_label, "cd": cd, "slot": slot_index }


func _theme_hud_size() -> int:
	return UIManager.theme_font_size("font_size", "ProgressBar", 14) if UIManager != null else 14


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
			_vitae_label.text = "%s —" % tr("HUD_VITAE")
			_hp_label.text = "%s —" % tr("HUD_HP")
		return
	var max_b := maxf(b.max_blood, 1.0)
	var ratio := clampf(b.blood / max_b, 0.0, 1.0)
	_vitae_bar.max_value = b.max_blood
	_vitae_bar.value = b.blood
	_vitae_label.text = "%s %d/%d" % [tr("HUD_VITAE"), int(b.blood), int(b.max_blood)]
	var max_hp := maxf(Sim.player.max_hp, 1.0)
	_hp_bar.max_value = Sim.player.max_hp
	_hp_bar.value = Sim.player.hp
	_hp_label.text = "%s %d/%d" % [tr("HUD_HP"), int(Sim.player.hp), int(Sim.player.max_hp)]


func _refresh_hunger() -> void:
	var b := _player_behaviour()
	var h := int(round(b.hunger)) if b != null else 0
	h = clampi(h, 0, HUNGER_PIPS)
	if h == _cached_hunger:
		return
	_cached_hunger = h
	var gold := _accent("gold")
	var dim := _accent("dim")
	for i in HUNGER_PIPS:
		_hunger_pips[i].color = gold if i < h else dim.darkened(0.4)


func _refresh_heat() -> void:
	var stars := 0
	if Sim != null:
		stars = Sim.heat_stars() if Sim.has_method("heat_stars") else 0
	stars = clampi(stars, 0, HEAT_STARS)
	if stars == _cached_heat:
		return
	_cached_heat = stars
	var moon := _accent("moon")
	var dim := _accent("dim")
	for i in HEAT_STARS:
		_heat_stars[i].color = moon if i < stars else dim.darkened(0.4)


func _refresh_hotbar() -> void:
	# 8 slots. slot_1..4 are bound to a small starter set of powers; 5..8 reserved.
	const STARTER := ["bs_bolt", "obf_cloak", "for_mend", "cel_dash"]
	var b := _player_behaviour()
	for i in HOTBAR_SIZE:
		var slot: Dictionary = _hotbar_slots[i]
		var power_id: String = String(STARTER[i]) if i < STARTER.size() else ""
		var key_label: Label = slot["key"]
		var name_label: Label = slot["name"]
		var cd: ColorRect = slot["cd"]
		if power_id == "":
			name_label.text = " "
			cd.visible = false
			continue
		var def := PowerCatalog.get_def(power_id)
		name_label.text = String(def.get("name", power_id)) if not def.is_empty() else power_id
		# Cooldown overlay: visible while on cooldown; alpha scales with remaining fraction.
		if b != null and b.power_cooldowns.has(power_id):
			var remaining := int(b.power_cooldowns[power_id])
			var total := int(def.get("cooldown", remaining)) if not def.is_empty() else remaining
			var frac := clampf(float(remaining) / maxf(float(total), 1.0), 0.0, 1.0)
			cd.visible = remaining > 0
			cd.color = Color(0, 0, 0, 0.25 + 0.55 * frac)
		else:
			cd.visible = false


func _refresh_buffs() -> void:
	# Rebuild the buff list from Sim.player.behaviour.buffs (backend-defined).
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
		var label := Label.new()
		label.text = "%s (%.1fs)" % [_buff_display_name(String(key)), float(rec.get("ticks", 0)) / 60.0]
		label.add_theme_font_size_override("font_size", _theme_hud_size())
		label.color = good
		label.add_theme_color_override("font_color", good)
		_buff_list.add_child(label)
	# Frenzy is a status worth surfacing separately.
	if b.frenzied:
		var label := Label.new()
		label.text = tr("HUD_FRENZY")
		label.add_theme_font_size_override("font_size", _theme_hud_size())
		label.add_theme_color_override("font_color", danger)
		_buff_list.add_child(label)


func _refresh_action_phase() -> void:
	if Sim == null or Sim.player == null or _phase_label == null:
		return
	var phase := Sim.player.action_phase()
	if phase == "":
		_phase_label.text = " "
		return
	_phase_label.text = "%s: %s" % [tr("HUD_ACTION"), tr("HUD_PHASE_" + phase.to_upper())]
	_phase_label.add_theme_color_override("font_color", _accent("gold"))


func _buff_display_name(buff_id: String) -> String:
	const NAMES := {
		"cel_haste": "Fleetness", "pro_beast": "Beast", "for_stone": "Stone Skin",
		"obf_cloak": "Cloak", "obf_vanish": "Vanish",
	}
	return NAMES.get(buff_id, buff_id.capitalize())


func _accent(key: String) -> Color:
	if UIManager != null:
		return UIManager.theme_get_color(key, "UITheme", Color.WHITE)
	match key:
		"gold": return Color(0.90, 0.74, 0.36, 1)
		"moon": return Color(0.74, 0.82, 0.98, 1)
		"good": return Color(0.36, 0.80, 0.50, 1)
		"danger": return Color(0.92, 0.22, 0.22, 1)
		"dim": return Color(0.62, 0.62, 0.70, 1)
	return Color.WHITE


# ---------------------------------------------------------------- cue handling

func _on_cue(event_id: String, payload: Dictionary) -> void:
	# Match on the cue id prefix so related events share a handler. UI only consumes.
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
			pass   # minimap/radar owns these (Phase 2 placeholder)
		"dawn.warning", "dawn.arrive", "player.torpor":
			UIManager.show_notification(_cue_to_notify(event_id), _accent("moon"))
		"ui.notify":
			UIManager.show_notification(String(payload.get("text", "")), payload.get("color", Color.WHITE))
	# Banners/notifications for any cue carrying a caption field route through CaptionOverlay
	# via CueBus itself (captions_enabled). Nothing else to do here.


func _spawn_damage_number(payload: Dictionary, taken: bool) -> void:
	var amount := float(payload.get("amount", 0.0))
	if amount <= 0.0:
		return
	var pos_v = payload.get("pos", Vector2.ZERO)
	var world_pos: Vector2 = pos_v if pos_v is Vector2 else Vector2.ZERO
	var color := _accent("danger") if taken else _accent("good")
	UIManager.spawn_floating_text(world_pos, "%d" % int(amount), color)


func _cue_to_notify(event_id: String) -> String:
	# Map major narrative cues to short notification copy.
	match event_id:
		"dawn.warning": return tr("NOTIFY_DAWN_WARNING")
		"dawn.arrive": return tr("NOTIFY_DAWN_ARRIVE")
		"player.torpor": return tr("NOTIFY_TORPOR")
	return event_id
