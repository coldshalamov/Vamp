## DeathScreen.gd — the torpor/death overlay. Without this, player death silently froze the world.
##
## Shown by GameRenderer when the player dies; "rise again" reviving the player at their haven.
extends CanvasLayer
class_name DeathScreen

const DISPLAY_FONT := "res://art/fonts/Cinzel.ttf"
const MONO_FONT := "res://art/fonts/ShareTechMono.ttf"

var _title: Label
var _prompt: Label
var _blink: float = 0.0


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.0, 0.02, 0.78)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	cc.add_child(vb)

	var kicker := Label.new()
	kicker.text = "NIGHTSHIFT DIVISION // CASE CLOSED"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(kicker, MONO_FONT, 15, Color("#8a8f99"))
	vb.add_child(kicker)

	_title = Label.new()
	_title.text = "THE NIGHT CLAIMS YOU"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(_title, DISPLAY_FONT, 56, Color("#c01028"))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	vb.add_child(_title)

	_prompt = Label.new()
	_prompt.text = "press any key to rise from torpor"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(_prompt, MONO_FONT, 18, Color("#d8d2c4"))
	vb.add_child(_prompt)


func _font(l: Label, path: String, size: int, col: Color) -> void:
	if ResourceLoader.exists(path):
		var f := load(path) as FontFile
		if f != null:
			l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)


func _process(delta: float) -> void:
	if not visible or _prompt == null:
		return
	_blink += delta
	_prompt.modulate.a = 0.5 + 0.5 * sin(_blink * 3.4)


func show_death() -> void:
	visible = true
	_blink = 0.0


func hide_death() -> void:
	visible = false
