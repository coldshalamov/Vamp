## CoterieScreen.gd — bound thralls/childer roster (functional placeholder).
##
## Shows member stats and Summon / Dismiss / Assign buttons. Member data is a pluggable
## array; the slice ships a placeholder roster. Real coterie economy is Phase 2.
extends BaseScreen

var _list: VBoxContainer = null
var _members: Array = [
	{ "id": "thrall_1", "name": "Marcus", "level": 2, "loyalty": 4, "job": "Ghoul Guard", "assignment": "Haven" },
	{ "id": "thrall_2", "name": "Lena", "level": 1, "loyalty": 5, "job": "Idle", "assignment": "—" },
]


func _ready() -> void:
	super._ready()
	title = tr("MENU_COTERIE")
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
	heading.text = tr("MENU_COTERIE")
	vbox.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	for m in _members:
		_list.add_child(_make_member_row(m))


func _make_member_row(m: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = "%s  |  %s %d  |  %s %d  |  %s: %s" % [
		String(m.get("name", "?")), tr("COTERIE_LEVEL"), int(m.get("level", 0)),
		tr("COTERIE_LOYALTY"), int(m.get("loyalty", 0)), tr("COTERIE_JOB"), String(m.get("job", "—")),
	]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	_button(row, tr("COTERIE_SUMMON"), _on_summon.bind(m))
	_button(row, tr("COTERIE_DISMISS"), _on_dismiss.bind(m))
	_button(row, tr("COTERIE_ASSIGN"), _on_assign.bind(m))
	return row


func _button(parent: HBoxContainer, label: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(callback)
	parent.add_child(b)


func _on_summon(m: Dictionary) -> void:
	UIManager.show_notification("%s: %s" % [tr("NOTIFY_SUMMONED"), String(m.get("name", ""))])

func _on_dismiss(m: Dictionary) -> void:
	UIManager.show_notification("%s: %s" % [tr("NOTIFY_DISMISSED"), String(m.get("name", ""))])

func _on_assign(m: Dictionary) -> void:
	UIManager.show_notification("%s: %s" % [tr("NOTIFY_ASSIGNED"), String(m.get("name", ""))])


func default_focus_control() -> Control:
	return BaseScreen._first_focusable(_list) if _list != null else super.default_focus_control()
