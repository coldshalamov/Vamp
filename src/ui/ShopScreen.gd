## ShopScreen.gd — haven services / buy-sell (functional placeholder).
##
## Lists items/services with prices and buy/sell buttons. Cost display is adjusted by the
## player's price multiplier (placeholder 1.0). Real economy math is backend-owned.
extends BaseScreen

const PRICE_MULT := 1.0   # backend will supply SimPlayer.price_multiplier; placeholder 1.0

var _list: VBoxContainer = null
var _gold_label: Label = null
var _catalog: Array = [
	{ "id": "vial", "name": "Blood Vial", "price": 40, "kind": "buy" },
	{ "id": "stake", "name": "Wooden Stake", "price": 25, "kind": "buy" },
	{ "id": "uv_grenade", "name": "UV Grenade", "price": 120, "kind": "buy" },
	{ "id": "heal_rite", "name": "Healing Rite", "price": 80, "kind": "service" },
]


func _ready() -> void:
	super._ready()
	title = tr("MENU_SHOP")
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

	var heading := HBoxContainer.new()
	var title_l := Label.new()
	title_l.text = tr("MENU_SHOP")
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title_l)
	_gold_label = Label.new()
	_gold_label.text = "%s: —" % tr("SHOP_GOLD")
	heading.add_child(_gold_label)
	vbox.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	for item in _catalog:
		_list.add_child(_make_row(item))


func _make_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	var price := int(round(float(item.get("price", 0)) * PRICE_MULT))
	l.text = "%s — %d %s" % [String(item.get("name", "?")), price, tr("SHOP_GOLD")]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if String(item.get("kind", "buy")) == "service":
		_button(row, tr("SHOP_SERVICE"), _on_service.bind(item))
	else:
		_button(row, tr("SHOP_BUY"), _on_buy.bind(item))
		_button(row, tr("SHOP_SELL"), _on_sell.bind(item))
	return row


func _button(parent: HBoxContainer, label: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(callback)
	parent.add_child(b)


func _on_buy(item: Dictionary) -> void:
	UIManager.show_notification("%s: %s" % [tr("NOTIFY_BOUGHT"), String(item.get("name", ""))])

func _on_sell(item: Dictionary) -> void:
	UIManager.show_notification("%s: %s" % [tr("NOTIFY_SOLD"), String(item.get("name", ""))])

func _on_service(item: Dictionary) -> void:
	UIManager.show_notification("%s: %s" % [tr("NOTIFY_SERVICE"), String(item.get("name", ""))])


func default_focus_control() -> Control:
	return BaseScreen._first_focusable(_list) if _list != null else super.default_focus_control()
