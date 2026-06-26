## SkillTreeScreen.gd — the character-build center.
##
## Reads the REAL skill tree (Catalog.SKILL_NODES, 78 nodes) and the player's live Sim.meta state.
## Clicking a node calls meta.allocate_skill(), which spends a skill point, applies the node's mods,
## learns any granted power, and pushes the result into the running Sim via apply_to_runtime — so
## the player's actual HP/damage/speed/kit move the instant they spend. This is the growth engine.
## Determinism: the screen only calls existing tested backend methods; it mutates no Sim state directly.
extends BaseScreen

const CatalogScript := preload("res://src/data/GameCatalog.gd")

var _grid: GridContainer = null
var _tooltip: RichTextLabel = null
var _points_label: Label = null
var _attr_box: HBoxContainer = null
var _branch_filter: String = ""   # "" = all branches
var _node_buttons: Dictionary = {}   # node_id -> Button (for re-render on spend)


func _ready() -> void:
	super._ready()
	title = tr("MENU_SKILL_TREE")
	_build()


func _build() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	# Header: points available + a respec button.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)
	_points_label = Label.new()
	header.add_child(_points_label)
	var respec_btn := Button.new()
	respec_btn.text = tr("MENU_RESPEC") if tr("MENU_RESPEC") != "MENU_RESPEC" else "Respec"
	respec_btn.tooltip_text = "Refund all spent skill points (cost applies when bought as a haven service)."
	respec_btn.pressed.connect(_on_respec)
	header.add_child(respec_btn)

	# Branch filter row: discipline buttons that narrow the grid.
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	vbox.add_child(filter_row)
	_append_filter_btn(filter_row, "All", "")
	for branch in CatalogScript.DISCIPLINES:
		_append_filter_btn(filter_row, String(CatalogScript.DISCIPLINES[branch].get("name", branch)).capitalize(), branch)

	# Attribute spend row: the 6 attributes, each +1 on click (calls meta.spend_attribute).
	_attr_box = HBoxContainer.new()
	_attr_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_attr_box)

	# Scrollable node grid.
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
	_tooltip.custom_minimum_size = Vector2(0, 70)
	_tooltip.text = ""
	vbox.add_child(_tooltip)

	_refresh()


func _append_filter_btn(parent: HBoxContainer, label_text: String, branch: String) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.toggle_mode = true
	btn.button_pressed = (branch == "")
	btn.focus_mode = Control.FOCUS_ALL
	btn.toggled.connect(func(on):
		if on:
			_branch_filter = branch
			for child in parent.get_children():
				if child is Button and child != btn:
					(child as Button).set_pressed_no_signal(false)
			_rebuild_grid())
	parent.add_child(btn)


## Rebuild the attribute row + node grid from live Sim.meta state. Called on build and after every
## spend so the screen always reflects the player's current build.
func _refresh() -> void:
	_refresh_points()
	_rebuild_attr()
	_rebuild_grid()


func _refresh_points() -> void:
	if Sim == null or Sim.meta == null:
		_points_label.text = ""
		return
	var sp := int(Sim.meta.skill_points)
	var ap := int(Sim.meta.attr_points)
	var lv := int(Sim.meta.level)
	_points_label.text = "Lv %d   |   %s: %d   |   %s: %d" % [lv, tr("MENU_SKILL_POINTS") if tr("MENU_SKILL_POINTS") != "MENU_SKILL_POINTS" else "Skill Pts", sp, tr("MENU_ATTR_POINTS") if tr("MENU_ATTR_POINTS") != "MENU_ATTR_POINTS" else "Attr Pts", ap]


func _rebuild_attr() -> void:
	for c in _attr_box.get_children():
		c.queue_free()
	if Sim == null or Sim.meta == null:
		return
	for adef in CatalogScript.ATTRIBUTES:
		var attr_id := String(adef.get("id", ""))
		var val := int(Sim.meta.attributes.get(attr_id, 1))
		var btn := Button.new()
		btn.text = "%s  %d  +" % [String(adef.get("name", attr_id)), val]
		btn.tooltip_text = String(adef.get("desc", ""))
		btn.disabled = int(Sim.meta.attr_points) <= 0 or val >= 50
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(_on_spend_attribute.bind(attr_id))
		_attr_box.add_child(btn)


func _rebuild_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_node_buttons.clear()
	if Sim == null or Sim.meta == null:
		return
	var owned: Dictionary = Sim.meta.tree_nodes
	var rank: int = 0
	for node_id in CatalogScript.SKILL_NODES:
		var node: Dictionary = CatalogScript.SKILL_NODES[node_id]
		if _branch_filter != "" and String(node.get("branch", "")) != _branch_filter:
			continue
		rank = int(owned.get(node_id, 0))
		var btn := _make_node(String(node_id), node, rank)
		_grid.add_child(btn)
		_node_buttons[node_id] = btn


func _make_node(node_id: String, node: Dictionary, rank: int) -> Control:
	var btn := Button.new()
	var name := String(node.get("name", node_id))
	var max_rank := int(node.get("maxRank", 1))
	btn.text = "%s\n%s/%d" % [name, rank, max_rank]
	btn.custom_minimum_size = Vector2(150, 64)
	btn.focus_mode = Control.FOCUS_ALL
	btn.tooltip_text = String(node.get("desc", ""))
	btn.focus_entered.connect(_show_tooltip.bind(node))
	btn.pressed.connect(_on_select_node.bind(node_id, node))
	# Visual state from the live backend gating verdict: owned / available / locked.
	var verdict: Dictionary = Sim.meta.can_allocate(node_id)
	if rank >= max_rank:
		btn.modulate = Color(0.55, 0.9, 0.55)      # maxed — green
		btn.disabled = true
	elif bool(verdict.get("ok", false)):
		btn.modulate = Color(1.0, 0.95, 0.6)        # available — gold
	elif rank > 0:
		btn.modulate = Color(0.7, 0.8, 1.0)         # partially owned but can't add now — blue
	else:
		btn.modulate = Color(0.5, 0.5, 0.55)        # locked — grey
		btn.disabled = true
	return btn


func _on_spend_attribute(attr_id: String) -> void:
	if Sim == null or Sim.meta == null:
		return
	if Sim.meta.spend_attribute(attr_id):
		Sim.meta.apply_to_runtime(Sim)
		Sim.emit_cue("attr.spent", { "attr_id": attr_id })
	_refresh()


## THE core action: spend a skill point on a node. Calls the real backend, which mutates tree_nodes,
## skill_points, derived stats, and (for power nodes) the player's known powers + hotbar.
func _on_select_node(node_id: String, node: Dictionary) -> void:
	_show_tooltip(node)
	if Sim == null or Sim.meta == null:
		return
	var verdict: Dictionary = Sim.meta.can_allocate(node_id)
	if not bool(verdict.get("ok", false)):
		# Tell the player WHY they can't take it (no points / needs branch points / conflicts / maxed).
		UIManager.show_notification("%s: %s" % [String(node.get("name", node_id)), String(verdict.get("why", "locked"))])
		return
	if Sim.meta.allocate_skill(node_id, Sim):
		# allocate_skill already emitted "skill.allocated" and pushed runtime. Refresh to show new state.
		_refresh()
	else:
		UIManager.show_notification("Could not allocate %s." % String(node.get("name", node_id)))


func _on_respec() -> void:
	if Sim == null or Sim.meta == null:
		return
	Sim.meta.respec_tree(Sim)
	Sim.meta.apply_to_runtime(Sim)
	Sim.emit_cue("skill.respec", {})
	_refresh()


func _show_tooltip(node: Dictionary) -> void:
	if node.is_empty():
		_tooltip.text = ""
		return
	var txt := "[b]%s[/b]   (%s, tier %d)\n%s" % [
		String(node.get("name", "")),
		String(node.get("branch", "")).capitalize(),
		int(node.get("tier", 0)),
		String(node.get("desc", "")),
	]
	if node.has("power"):
		txt += "\n[b]Grants power:[/b] %s" % String(node["power"])
	if node.has("conflicts"):
		txt += "\n[color=red]Conflicts with:[/color] %s" % ", ".join(node["conflicts"])
	_tooltip.text = txt


func default_focus_control() -> Control:
	return BaseScreen._first_focusable(_grid) if _grid != null else super.default_focus_control()
