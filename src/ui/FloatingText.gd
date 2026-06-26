## FloatingText.gd — damage-number / pickup label layer.
##
## Spawns a short-lived Label that floats up and fades. Reduced-motion collapses the tween
## to a single-frame flash. Positions are given in WORLD space; a world_to_screen callback
## (set by Boot.gd, which owns the camera) converts them. If unset we fall back to the
## viewport center so the layer still works in stubbed/test contexts.
extends Control
class_name FloatingText

const MAX_LABELS := 48

var world_to_screen: Callable = Callable()   # Vector2 -> Vector2, set by the game host


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if UIManager != null:
		UIManager.register_floating_layer(self)


func spawn(world_pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	while get_child_count() >= MAX_LABELS:
		_remove_child_now(get_child(0))
	var label := Label.new()
	label.text = text
	label.z_index = 50
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", UIManager.theme_resource.font_size_hud if UIManager != null else 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var screen_pos: Vector2 = world_to_screen.call(world_pos) if world_to_screen.is_valid() else (size * 0.5)
	label.position = screen_pos - label.size * 0.5
	var reduced := UIManager.is_reduced_motion() if UIManager != null else false
	if reduced:
		label.modulate.a = 1.0
		var tw := label.create_tween()
		tw.tween_interval(0.4)
		tw.tween_property(label, "modulate:a", 0.0, 0.1)
		tw.tween_callback(label.queue_free)
		return
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 34.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(label.queue_free)


func _remove_child_now(child: Node) -> void:
	if child == null or not is_instance_valid(child):
		return
	remove_child(child)
	child.queue_free()
