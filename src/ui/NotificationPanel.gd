## NotificationPanel.gd — transient bottom-right toasts + centered banners.
##
## - push_notification(text, color): small toast that slides in/out.
## - push_banner(title, body, color): large centered card for major beats.
##
## Both are reduced-motion aware. Banners get a longer dwell and a higher max queue.
extends Control
class_name NotificationPanel

const MAX_TOASTS := 4
const MAX_BANNERS := 2
const TOAST_DWELL := 2.5
const BANNER_DWELL := 3.0


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if UIManager != null:
		UIManager.register_notifications(self)


func push_notification(text: String, color: Color = Color.WHITE) -> void:
	if text.strip_edges() == "":
		return
	# Trim oldest if at capacity.
	var toast_box := _toast_box()
	while toast_box.get_child_count() >= MAX_TOASTS:
		_remove_child_now(toast_box, toast_box.get_child(0))
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", _size())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(label)
	_fade_out(label, TOAST_DWELL)


func push_banner(title: String, body: String, color: Color = Color.WHITE) -> void:
	var banner_box := _banner_box()
	while banner_box.get_child_count() >= MAX_BANNERS:
		_remove_child_now(banner_box, banner_box.get_child(0))
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", color)
	title_label.add_theme_font_size_override("font_size", _size() + 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)
	if body != "":
		var body_label := Label.new()
		body_label.text = body
		body_label.add_theme_color_override("font_color", color)
		body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(body_label)
	banner_box.add_child(card)
	var reduced := UIManager.is_reduced_motion() if UIManager != null else false
	# A CARD-OWNED tween auto-cancels when the card is freed early (overflow trim or
	# clear_banners() on death), so no stale-reference callback can fire. This replaces the old
	# create_timer(BANNER_DWELL).timeout.connect(_dismiss_banner.bind(card)), which crashed with
	# "Cannot convert argument 1 from Object to Object" whenever the bound card was freed first —
	# the cause of the MASQUERADE BROKEN banner sticking on screen and bleeding onto the death screen.
	var tw := card.create_tween()
	if reduced:
		card.modulate.a = 1.0
		tw.tween_interval(BANNER_DWELL)
	else:
		card.modulate.a = 0.0
		tw.tween_property(card, "modulate:a", 1.0, 0.2)
		tw.tween_interval(BANNER_DWELL)
		tw.tween_property(card, "modulate:a", 0.0, 0.3)
	tw.tween_callback(card.queue_free)


## Immediately clear all live banners (e.g. on death or scene change so banners never bleed
## across the death screen or a fresh night). Toasts are transient enough to leave as-is.
func clear_banners() -> void:
	if _banner_box_cache == null:
		return
	for child in _banner_box_cache.get_children():
		if is_instance_valid(child):
			child.queue_free()


func _fade_out(label: Label, dwell: float) -> void:
	var reduced := UIManager.is_reduced_motion() if UIManager != null else false
	var tw := label.create_tween()
	if reduced:
		tw.tween_interval(dwell)
		tw.tween_callback(label.queue_free)
		return
	tw.tween_interval(dwell)
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(label.queue_free)


func _size() -> int:
	return UIManager.theme_font_size("font_size", "Label", 16) if UIManager != null else 16


func _remove_child_now(parent: Node, child: Node) -> void:
	if parent == null or child == null or not is_instance_valid(child):
		return
	parent.remove_child(child)
	child.queue_free()


# Lazily-built toast (bottom-right) and banner (center) containers. Built on first use so
# headless scenes without the panel visible don't allocate.

var _toast_box_cache: VBoxContainer = null
var _banner_box_cache: VBoxContainer = null

func _toast_box() -> VBoxContainer:
	if _toast_box_cache != null:
		return _toast_box_cache
	var box := VBoxContainer.new()
	box.name = "Toasts"
	box.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.offset_left = -320
	box.offset_right = -16
	box.offset_top = -220
	box.offset_bottom = -16
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_toast_box_cache = box
	return box

func _banner_box() -> VBoxContainer:
	if _banner_box_cache != null:
		return _banner_box_cache
	var box := VBoxContainer.new()
	box.name = "Banners"
	box.set_anchors_preset(PRESET_CENTER)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -240
	box.offset_right = 240
	box.offset_top = 120
	box.offset_bottom = 360
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_banner_box_cache = box
	return box
