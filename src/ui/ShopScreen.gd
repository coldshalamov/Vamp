## ShopScreen.gd — the haven fence / supplier.
##
## Generates a live item STOCK (rolled via the same SimMeta generator that drops loot, so the shop
## and the world share an economy) and offers the haven SERVICES (heal, refill blood, bribe/clear
## heat, respec). Buy calls meta.buy_item (deducts coin scaled by priceMult, adds to inventory);
## services call meta.use_service. Prices reflect the player's real price multiplier.
extends BaseScreen

const CatalogScript := preload("res://src/data/GameCatalog.gd")

var _list: VBoxContainer = null
var _gold_label: Label = null
var _stock: Array = []   # generated item dicts, fixed on open (NOT regenerated per purchase)
var _sold_ids: Dictionary = {}   # item_id -> true, so a bought item greys out instead of vanishing


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

	_refresh_gold()
	# Roll stock ONCE on open. Regenerating per purchase would let the player reroll the shop for
	# free by buying cheap items — a real economy bug. Stock is fixed for the visit; bought items
	# grey out instead of being replaced.
	_generate_stock()


func _refresh_gold() -> void:
	if Sim == null or Sim.meta == null:
		return
	_gold_label.text = "%s: %d" % [tr("SHOP_GOLD"), int(Sim.meta.money)]


## Re-render the list WITHOUT regenerating stock (preserves the visit's fixed offering; only marks
## purchased items as sold). Called after each buy so gold updates and buttons grey out.
func _refresh_list() -> void:
	if Sim == null or Sim.meta == null:
		return
	_refresh_gold()
	for c in _list.get_children():
		c.queue_free()
	for item in _stock:
		_list.add_child(_make_item_row(item))
	_list.add_child(_make_section_label("— Services —"))
	for service_id in CatalogScript.ECONOMY_SERVICES:
		_list.add_child(_make_service_row(service_id))


func _generate_stock() -> void:
	if Sim == null or Sim.meta == null:
		return
	_stock.clear()
	_sold_ids.clear()
	# Pass Sim so the generator uses the REAL LCG (varied, level-scaled stock). Without sim the RNG
	# is degenerate (always common). The rolls advance next_item_id, but the player opening a haven
	# shop is an authored event, not a per-tick sim mutation — acceptable.
	var level := int(Sim.meta.level)
	for i in range(6):
		var rarity: String = Sim.meta.roll_rarity(level, 0.08 + float(i) * 0.03, Sim)   # bias slightly better as the row goes
		var slot_pref: String = ["weapon", "attire", "charm"][i % 3]
		var item: Dictionary = Sim.meta.generate_item(level, rarity, slot_pref, Sim)
		_stock.append(item)
	for item in _stock:
		_list.add_child(_make_item_row(item))
	_list.add_child(_make_section_label("— Services —"))
	for service_id in CatalogScript.ECONOMY_SERVICES:
		_list.add_child(_make_service_row(service_id))


func _make_section_label(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.modulate = Color(0.7, 0.7, 0.75)
	return l


func _price_of(item: Dictionary) -> int:
	# Source of truth is the backend: price() already applies the player's priceMult AND the real
	# Catalog.RARITY multipliers. Never mirror it locally — the mirror drifts and mis-advertises.
	return Sim.meta.price(item) if Sim != null and Sim.meta != null else 0


func _make_item_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = "%s   [%s L%d] — %d %s" % [String(item.get("name", "?")), String(item.get("rarity", "")).capitalize(), int(item.get("level", 1)), _price_of(item), tr("SHOP_GOLD")]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.modulate = _rarity_color(item)
	row.add_child(l)
	var buy_btn := Button.new()
	buy_btn.text = tr("SHOP_BUY")
	buy_btn.focus_mode = Control.FOCUS_ALL
	buy_btn.disabled = _sold_ids.has(int(item.get("id", -1)))
	buy_btn.pressed.connect(_on_buy.bind(item))
	row.add_child(buy_btn)
	return row


func _make_service_row(service_id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var sdef: Dictionary = CatalogScript.ECONOMY_SERVICES.get(service_id, {})
	var cost: int = Sim.meta.service_cost(service_id)
	var l := Label.new()
	l.text = "%s — %d %s" % [String(sdef.get("name", service_id)), cost, tr("SHOP_GOLD")]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	_button(row, tr("SHOP_SERVICE"), _on_service.bind(service_id))
	return row


func _rarity_color(item: Dictionary) -> Color:
	# Prefer the rarity hex the backend stamps on every generated item (Catalog.RARITY[rarity].color).
	var hex := String(item.get("color", ""))
	if hex.begins_with("#") and hex.length() == 7:
		return Color(hex)
	match String(item.get("rarity", "common")):
		"legendary", "relic": return Color(1.0, 0.75, 0.2)
		"epic": return Color(0.75, 0.45, 1.0)
		"rare": return Color(0.35, 0.6, 1.0)
		"uncommon": return Color(0.5, 0.9, 0.5)
		_: return Color(0.85, 0.85, 0.85)


func _button(parent: HBoxContainer, label: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(callback)
	parent.add_child(b)


## Buy an item: meta.buy_item deducts coin, adds to inventory (auto-selling overflow to coin), emits
## economy.bought. Refresh the stock so the next visit shows new gear.
func _on_buy(item: Dictionary) -> void:
	if Sim == null or Sim.meta == null:
		return
	if _sold_ids.has(int(item.get("id", -1))):
		return   # already bought this visit — stock is fixed, no dupes
	if Sim.meta.buy_item(item, Sim):
		_sold_ids[int(item.get("id", -1))] = true
		_refresh_list()
	else:
		UIManager.show_notification("Not enough coin.")


func _on_service(service_id: String) -> void:
	if Sim == null or Sim.meta == null:
		return
	if Sim.meta.use_service(service_id, Sim):
		_refresh_list()
	else:
		UIManager.show_notification("Not enough coin.")


func default_focus_control() -> Control:
	return BaseScreen._first_focusable(_list) if _list != null else super.default_focus_control()
