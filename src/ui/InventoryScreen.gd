## InventoryScreen.gd — grid + tooltips + equip/use verbs (functional placeholder).
##
## Reads item data from a pluggable source (`items` array, set by the game host). The slice
## ships with a small placeholder catalog so the screen renders without a backend economy.
extends BaseScreen

var _grid: GridContainer = null
var _tooltip: RichTextLabel = null
var _items: Array = [
	{ "id": "vial", "name": "Blood Vial", "lore": "Stored vitae. Restores 20 blood.", "stat": "+20 vitae", "usable": true },
	{ "id": "stake", "name": "Wooden Stake", "lore": "A classic. Pincushion a vampire.", "stat": "Stun on hit", "equippable": true },
	{ "id": "cloak_pin", "name": "Cloak Pin", "lore": "A petty Obfuscate focus.", "stat": "+10% cloak", "equippable": true },
	{ "id": "uv_grenade", "name": "UV Grenade", "lore": "Sunlight in a can.", "stat": "150 sun dmg", "usable": true },
]


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

	var heading := Label.new()
	heading.text = tr("MENU_INVENTORY")
	vbox.add_child(heading)

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

	for item in _items:
		_grid.add_child(_make_cell(item))


func _make_cell(item: Dictionary) -> Control:
	var btn := Button.new()
	btn.text = String(item.get("name", item.get("id", "?")))
	btn.custom_minimum_size = Vector2(120, 80)
	btn.focus_mode = Control.FOCUS_ALL
	btn.focus_entered.connect(_show_item.bind(item))
	btn.pressed.connect(_on_use_or_equip.bind(item))
	return btn


func _show_item(item: Dictionary) -> void:
	_tooltip.text = "[b]%s[/b]\n%s\n[color=gold]%s[/color]" % [
		String(item.get("name", "")),
		String(item.get("lore", "")),
		String(item.get("stat", "")),
	]


func _on_use_or_equip(item: Dictionary) -> void:
	_show_item(item)
	if bool(item.get("usable", false)):
		UIManager.show_notification("%s: %s" % [tr("NOTIFY_USED"), String(item.get("name", ""))])
	elif bool(item.get("equippable", false)):
		UIManager.show_notification("%s: %s" % [tr("NOTIFY_EQUIPPED"), String(item.get("name", ""))])


func default_focus_control() -> Control:
	return BaseScreen._first_focusable(_grid) if _grid != null else super.default_focus_control()
