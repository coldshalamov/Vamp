## CreditsScreen.gd — a simple credits screen (ship hygiene), reachable from the main menu and
## dismissed with BACK (pops back to the menu via UIManager.close_menu()).
extends BaseScreen

var _back_button: Button = null


func _ready() -> void:
	super._ready()
	title = "CREDITS"
	_build()


func _build() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.01, 0.03, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(PRESET_CENTER)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	var lines := [
		"VAMPIRE CITY", "",
		"A top-down vampire action-RPG", "",
		"Predator. Rise. Cost. Continuous.", "",
		"Built on Godot 4", "",
		"Inspired by VtM: Bloodlines, GTA, Hotline Miami, Hades", "",
		"v0.9.0",
	]
	for i in range(lines.size()):
		var l := Label.new()
		l.text = String(lines[i])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 30 if i == 0 else 16)
		l.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82) if i == 0 else Color(0.70, 0.68, 0.64))
		vb.add_child(l)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	vb.add_child(gap)

	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.custom_minimum_size = Vector2(200, 44)
	_back_button.pressed.connect(_on_back)
	vb.add_child(_back_button)


func _on_back() -> void:
	UIManager.close_menu()


func default_focus_control() -> Control:
	return _back_button
