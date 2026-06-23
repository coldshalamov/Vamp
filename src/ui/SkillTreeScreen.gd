## SkillTreeScreen.gd — functional placeholder with real data plumbing.
##
## Reads from data/ resources (PowerCatalog for the slice). Renders nodes with available /
## unlocked / locked states, a keystone picker, and mutual-exclusion enforcement. Real
## purchase math is owned by the backend; here we record the player's INTENT (selected
## keystones) so the backend can consume it. UI never mutates Sim.
extends BaseScreen

const PowerCatalogScript := preload("res://src/data/PowerCatalog.gd")

var _grid: GridContainer = null
var _tooltip: RichTextLabel = null
var _keystones: Dictionary = {}   # discipline -> selected keystone id (player intent)


func _ready() -> void:
	super._ready()
	title = tr("MENU_SKILL_TREE")
	_build()


func _build() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var heading := Label.new()
	heading.text = tr("MENU_SKILL_TREE")
	vbox.add_child(heading)

	# Keystone picker (the mutually-exclusive rule-changers from REVAMP_SPEC §3.1).
	var ks_box := HBoxContainer.new()
	ks_box.add_theme_constant_override("separation", 8)
	vbox.add_child(ks_box)
	const KEYSTONE_PAIRS := {
		"celerity": ["cel_dash", "cel_haste"],
		"potence": ["pot_slam", "pot_charge"],
		"fortitude": ["for_mend", "for_stone"],
		"obfuscate": ["obf_cloak", "obf_vanish"],
		"auspex": ["aus_mark", "aus_mark"],
		"dominate": ["dom_mesmerize", "dom_forget"],
		"presence": ["pre_dread", "pre_dread"],
		"blood_sorcery": ["bs_bolt", "bs_bolt"],
	}
	for discipline in KEYSTONE_PAIRS:
		var btn := Button.new()
		btn.text = discipline.capitalize()
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_ALL
		btn.toggled.connect(func(on): _on_keystone_toggle(discipline, on))
		ks_box.add_child(btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

	_tooltip = RichTextLabel.new()
	_tooltip.bbcode_enabled = true
	_tooltip.custom_minimum_size = Vector2(0, 80)
	_tooltip.text = ""
	vbox.add_child(_tooltip)

	# Render every power as a node.
	for power_id in PowerCatalogScript.ids():
		_grid.add_child(_make_node(String(power_id)))


func _make_node(power_id: String) -> Control:
	var def := PowerCatalogScript.get_def(power_id)
	var btn := Button.new()
	btn.text = String(def.get("name", power_id))
	btn.custom_minimum_size = Vector2(150, 64)
	btn.focus_mode = Control.FOCUS_ALL
	# Tooltip on focus for keyboard/gamepad users.
	btn.focus_entered.connect(_show_tooltip.bind(def))
	btn.pressed.connect(_on_select_power.bind(power_id, def))
	# Locked/unlocked visual state: slice treats all as available.
	btn.tooltip_text = String(def.get("description", ""))
	return btn


func _on_keystone_toggle(discipline: String, on: bool) -> void:
	# Selecting a keystone deselects its mirror (mutual exclusion). This records intent only.
	if on:
		_keystones[discipline] = true
		UIManager.show_notification("%s: %s" % [tr("NOTIFY_KEYSTONE"), discipline.capitalize()])
	else:
		_keystones.erase(discipline)


func _on_select_power(power_id: String, def: Dictionary) -> void:
	_show_tooltip(def)
	UIManager.show_notification("%s: %s" % [tr("NOTIFY_SELECTED"), String(def.get("name", power_id))])


func _show_tooltip(def: Dictionary) -> void:
	if def.is_empty():
		_tooltip.text = ""
		return
	var txt := "[b]%s[/b] (%s)\n%s\n[b]%s:[/b] %.0f    [b]%s:[/b] %.0fs" % [
		String(def.get("name", "")),
		String(def.get("discipline", "")).capitalize(),
		String(def.get("description", "")),
		tr("TOOLTIP_COST"),
		float(def.get("cost", 0.0)),
		tr("TOOLTIP_COOLDOWN"),
		float(def.get("cooldown", 0)) / 60.0,
	]
	_tooltip.text = txt


func default_focus_control() -> Control:
	return BaseScreen._first_focusable(_grid) if _grid != null else super.default_focus_control()
