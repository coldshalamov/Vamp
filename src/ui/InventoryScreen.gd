## InventoryScreen.gd — the loot + gear center.
##
## Reads the player's LIVE Sim.meta.inventory (the items that actually drop/are bought) and the four
## equipment slots. Clicking an item equips it (meta.equip_item, which swaps the previous item back
## to inventory and recomputes derived stats + pushes them into the running Sim) or sells it
## (meta.sell_item, adds coin). This is where the loot loop's payoff lives.
extends BaseScreen

var _grid: GridContainer = null
var _tooltip: RichTextLabel = null
var _equipment_label: Label = null
var _money_label: Label = null


func _ready() -> void:
	super._ready()
	title = tr("MENU_INVENTORY")
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

	# Header: money + currently-equipped loadout (so the player sees what swapping changes).
	_money_label = Label.new()
	vbox.add_child(_money_label)
	_equipment_label = Label.new()
	_equipment_label.text = ""
	vbox.add_child(_equipment_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	_tooltip = RichTextLabel.new()
	_tooltip.bbcode_enabled = true
	_tooltip.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(_tooltip)

	_refresh()


func _refresh() -> void:
	if Sim == null or Sim.meta == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	# Header: coin + the equipped loadout.
	_money_label.text = "%s: %d" % [tr("MENU_COIN") if tr("MENU_COIN") != "MENU_COIN" else "Coin", int(Sim.meta.money)]
	var eq: Dictionary = Sim.meta.equipment
	var eq_names := []
	for slot in ["weapon", "attire", "charm1", "charm2"]:
		var it = eq.get(slot, null)
		eq_names.append("%s: %s" % [slot.capitalize(), (String(it.get("name", "—")) if it != null else "—")])
	_equipment_label.text = "   |   ".join(eq_names)
	# Grid: one cell per carried item, color-coded by rarity.
	for item in Sim.meta.inventory:
		_grid.add_child(_make_cell(item))


func _rarity_color(item: Dictionary) -> Color:
	# The backend stamps a rarity hex color on every generated item (Catalog.RARITY[rarity].color).
	# Prefer that source of truth over a local mirror, which drifts (e.g. the relic tier was missing).
	var hex := String(item.get("color", ""))
	if hex.begins_with("#") and hex.length() == 7:
		return Color(hex)
	match String(item.get("rarity", "common")):
		"legendary", "relic": return Color(1.0, 0.75, 0.2)
		"epic": return Color(0.75, 0.45, 1.0)
		"rare": return Color(0.35, 0.6, 1.0)
		"uncommon": return Color(0.5, 0.9, 0.5)
		_: return Color(0.85, 0.85, 0.85)


func _make_cell(item: Dictionary) -> Control:
	var btn := Button.new()
	btn.text = "%s\n[%s L%d]" % [String(item.get("name", "?")), String(item.get("rarity", "common")).capitalize(), int(item.get("level", 1))]
	btn.custom_minimum_size = Vector2(150, 80)
	btn.modulate = _rarity_color(item)
	btn.focus_mode = Control.FOCUS_ALL
	btn.focus_entered.connect(_show_item.bind(item))
	btn.pressed.connect(_on_use_or_equip.bind(item))
	return btn


func _show_item(item: Dictionary) -> void:
	if item.is_empty():
		_tooltip.text = ""
		return
	var mods: Dictionary = item.get("mods", { "add": {}, "pct": {} })
	var add: Dictionary = mods.get("add", {})
	var pct: Dictionary = mods.get("pct", {})
	var lines: Array = []
	for k in add:
		lines.append("+%s %s" % [str(add[k]), k])
	for k in pct:
		lines.append("+%d%% %s" % [int(round(float(pct[k]) * 100.0)), k])
	var stat_line := "   ".join(lines) if not lines.is_empty() else "(no mods)"
	var affixes: Array = item.get("affixes", [])
	var affix_line := ", ".join(affixes) if not affixes.is_empty() else ""
	_tooltip.text = "[b]%s[/b]   [%s]   Lv %d\n%s\n[color=gold]%s[/color]\n[color=gray]Sell value: %d[/color]" % [
		String(item.get("name", "")),
		String(item.get("rarity", "")).capitalize(),
		int(item.get("level", 1)),
		stat_line,
		affix_line,
		int(Sim.meta.sell_value(item)),
	]


## Equip (primary action) or Sell (shift-click). Both mutate Sim.meta and push to runtime.
func _on_use_or_equip(item: Dictionary) -> void:
	_show_item(item)
	if Sim == null or Sim.meta == null:
		return
	var item_id := int(item.get("id", -1))
	if item_id < 0:
		return
	# Shift-click (or hold a modifier) sells instead of equipping — a fast way to clear trash loot.
	if Input.is_key_pressed(KEY_SHIFT):
		if Sim.meta.sell_item(item_id, Sim):
			_refresh()
		return
	if Sim.meta.equip_item(item_id, Sim):
		# equip_item already swapped the previous item back, recomputed derived, emitted inventory.equipped.
		_refresh()
	else:
		UIManager.show_notification("Can't equip %s." % String(item.get("name", "")))


func default_focus_control() -> Control:
	return BaseScreen._first_focusable(_grid) if _grid != null else super.default_focus_control()
