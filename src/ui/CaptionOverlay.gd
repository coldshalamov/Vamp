## CaptionOverlay.gd — subtitle-style overlay for audio cues.
##
## Listens to CueBus.cue_emitted and surfaces the `caption` text of each registered cue
## definition (CueBus already handles the captions_enabled gate before routing to HUD flash,
## so we also independently gate on UIManager.theme_resource.captions_enabled). Directionality
## is computed from payload.pos relative to the player (left/right/center) when available.
##
## This is the accessibility backbone promised in REVAMP_SPEC §13: deaf players must not
## lose information carried only by positional audio.
extends Control
class_name CaptionOverlay

const MAX_LINES := 4
const DWELL := 3.0

var _box: VBoxContainer = null


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if UIManager != null:
		UIManager.register_captions(self)
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func push_caption(text: String, direction: String = "") -> void:
	var enabled := UIManager.theme_resource.captions_enabled if (UIManager != null and UIManager.theme_resource != null) else true
	if not enabled or text.strip_edges() == "":
		return
	if _box == null:
		_build_box()
	while _box.get_child_count() >= MAX_LINES:
		_box.get_child(0).queue_free()
	var label := Label.new()
	# Only annotate OFF-CENTRE sounds with a direction (a center "[center]" tag is just noise).
	var prefix := "[%s] " % direction if direction == "left" or direction == "right" else ""
	label.text = prefix + text
	label.add_theme_font_size_override("font_size", _size())
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# High-contrast backing so captions stay readable over bright scenes.
	var bg := Color(Color.BLACK, 0.55)
	label.add_theme_color_override("font_shadow_color", bg)
	_box.add_child(label)
	var reduced := UIManager.is_reduced_motion() if UIManager != null else false
	if reduced:
		get_tree().create_timer(DWELL).timeout.connect(label.queue_free)
		return
	var tw := create_tween()
	tw.tween_interval(DWELL)
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(label.queue_free)


func _build_box() -> void:
	_box = VBoxContainer.new()
	_box.name = "Captions"
	_box.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_box.offset_left = 40
	_box.offset_right = -40
	_box.offset_top = -180
	_box.offset_bottom = -80
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)


func _size() -> int:
	return UIManager.theme_font_size("font_size", "Label", 16) if UIManager != null else 16


func _on_cue(event_id: String, payload: Dictionary) -> void:
	var caption_text := _caption_for(event_id, payload)
	if caption_text == "":
		return
	push_caption(caption_text, _direction_for(payload))


## Map cues to human caption text. Backend cue defs may also carry a `caption` field; this
## table covers the slice's narrative + feedback cues so captions work even before every
## cue is formally registered in CueBus.
func _caption_for(event_id: String, payload: Dictionary) -> String:
	match event_id:
		"feed.start": return tr("CAP_FEED_START")
		"feed.kill": return tr("CAP_FEED_KILL")
		"feed.spare": return tr("CAP_FEED_SPARE")
		"humanity.lost": return tr("CAP_HUMANITY_LOST")
		"masquerade.broken": return tr("CAP_MASQUERADE_BROKEN")
		"heat.rise": return tr("CAP_HEAT_RISE")
		"frenzy.start": return tr("CAP_FRENZY_START")
		"frenzy.end": return tr("CAP_FRENZY_END")
		"npc.alarm": return tr("CAP_NPC_ALARM")
		"player.spotted": return tr("CAP_SPOTTED")
		"player.lost": return tr("CAP_LOST")
		"dawn.warning": return tr("CAP_DAWN_WARNING")
		"player.torpor": return tr("CAP_TORPOR")
		"power.cast":
			return ""   # the player's own cast is shown by VisualFX; captioning it is redundant clutter
	return ""


func _direction_for(payload: Dictionary) -> String:
	# If the payload carries a world position, derive left/center/right relative to player.
	var pos_v = payload.get("pos", null)
	if pos_v == null or not (pos_v is Vector2):
		return ""
	if Sim == null or Sim.player == null:
		return ""
	var diff := float((pos_v as Vector2).x - Sim.player.pos.x)
	if diff < -24.0:
		return "left"
	if diff > 24.0:
		return "right"
	return "center"
