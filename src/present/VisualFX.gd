## VisualFX.gd — visual feedback layer: damage numbers, screen flash, captions, hitstop.
##
## CanvasLayer that consumes CueBus events and spawns transient UI/screen effects.
## Respects Accessibility settings.
extends CanvasLayer
class_name VisualFX

const DAMAGE_FONT_SIZE := 18
const DAMAGE_RISE := 48.0
const DAMAGE_DURATION := 0.7

@export var flash_overlay: ColorRect = null
@export var caption_label: Label = null

var _floating_texts: Array[Dictionary] = []
var _caption_queue: Array[String] = []
var _caption_timer: float = 0.0

func _ready() -> void:
	_create_flash_overlay()
	_create_caption_label()
	_register_cues()

func _register_cues() -> void:
	if CueBus == null:
		return
	CueBus.define("damage.dealt", CueBus.Priority.COMBAT, {
		"vfx": _on_damage_dealt,
		"duration_ms": 400,
	})
	CueBus.define("damage.player", CueBus.Priority.COMBAT, {
		"vfx": _on_damage_player,
		"duration_ms": 400,
	})
	CueBus.define("hit.connect", CueBus.Priority.COMBAT, {
		"vfx": _on_hit_connect,
		"duration_ms": 200,
	})
	CueBus.define("power.cast", CueBus.Priority.COMBAT, {
		"vfx": _on_power_cast,
		"duration_ms": 300,
	})
	CueBus.define("frenzy.start", CueBus.Priority.CRITICAL, {
		"vfx": _on_frenzy_start,
		"duration_ms": 800,
	})
	CueBus.define("humanity.lost", CueBus.Priority.CRITICAL, {
		"vfx": _on_humanity_lost,
		"duration_ms": 600,
	})
	CueBus.define("npc.flinch", CueBus.Priority.GAMEPLAY, {
		"vfx": _on_npc_flinch,
		"duration_ms": 300,
		"max_concurrent": 6,
	})
	CueBus.define("masquerade.broken", CueBus.Priority.CRITICAL, {
		"vfx": _on_masquerade_broken,
		"duration_ms": 400,
	})
	CueBus.define("feed.gulp", CueBus.Priority.GAMEPLAY, {
		"vfx": _on_feed_gulp_window,
		"duration_ms": 250,
	})
	CueBus.define("feed.gulp.perfect", CueBus.Priority.COMBAT, {
		"vfx": _on_feed_gulp_perfect,
		"duration_ms": 250,
	})
	CueBus.define("feed.gulp.miss", CueBus.Priority.GAMEPLAY, {
		"vfx": _on_feed_gulp_miss,
		"duration_ms": 200,
	})

func _create_flash_overlay() -> void:
	flash_overlay = ColorRect.new()
	flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_overlay)

func _create_caption_label() -> void:
	caption_label = Label.new()
	caption_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	caption_label.position = Vector2(-320, -80)
	caption_label.size = Vector2(640, 60)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	caption_label.add_theme_font_size_override("font_size", 16)
	caption_label.add_theme_color_override("font_color", Color("#e8e8f0"))
	caption_label.add_theme_color_override("font_shadow_color", Color("#000000"))
	caption_label.add_theme_constant_override("shadow_offset_x", 1)
	caption_label.add_theme_constant_override("shadow_offset_y", 1)
	caption_label.text = ""
	add_child(caption_label)

func _process(delta: float) -> void:
	_update_floating_texts(delta)
	_update_captions(delta)
	if flash_overlay != null:
		flash_overlay.color.a = move_toward(flash_overlay.color.a, 0.0, delta * 3.0)

func _update_floating_texts(delta: float) -> void:
	for i in range(_floating_texts.size() - 1, -1, -1):
		var ft: Dictionary = _floating_texts[i]
		ft.t += delta
		var progress: float = ft.t / ft.duration
		if progress >= 1.0:
			ft.label.queue_free()
			_floating_texts.remove_at(i)
			continue
		var base_pos: Vector2 = ft.start
		ft.label.position = base_pos - Vector2(0, progress * DAMAGE_RISE)
		ft.label.modulate.a = 1.0 - progress

func _update_captions(delta: float) -> void:
	if caption_label == null:
		return
	if _caption_timer > 0.0:
		_caption_timer -= delta
		if _caption_timer <= 0.0:
			if _caption_queue.is_empty():
				caption_label.text = ""
			else:
				caption_label.text = _caption_queue.pop_front()
				_caption_timer = 3.0

func spawn_floating_text(world_pos: Vector2, text: String, color: Color, is_crit: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", DAMAGE_FONT_SIZE + (4 if is_crit else 0))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#000000"))
	label.add_theme_constant_override("outline_size", 2 if is_crit else 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var screen_pos := _world_to_screen(world_pos)
	label.position = screen_pos
	_floating_texts.append({
		"label": label,
		"start": screen_pos,
		"t": 0.0,
		"duration": DAMAGE_DURATION,
	})

func show_caption(text: String) -> void:
	if CueBus != null and not CueBus.captions_enabled:
		return
	if caption_label == null:
		return
	if caption_label.text == "":
		caption_label.text = text
		_caption_timer = 3.0
	else:
		_caption_queue.append(text)
		if _caption_queue.size() > 4:
			_caption_queue.pop_front()

func flash_screen(color: Color, duration: float = 0.15) -> void:
	if CueBus != null and CueBus.reduced_flash:
		return
	if flash_overlay == null:
		return
	flash_overlay.color = color
	# Decay rate calibrated so alpha reaches ~0 in duration seconds.
	# alpha -= delta * 3.0, so from 1.0 to 0.0 takes ~0.33s. Tune by setting alpha.
	flash_overlay.color.a = clampf(duration * 3.0, 0.2, 1.0)

func set_time_scale(scale: float, duration: float) -> void:
	if CueBus != null and CueBus.reduced_motion:
		return
	Engine.time_scale = scale
	await get_tree().create_timer(duration * scale).timeout
	Engine.time_scale = 1.0

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return world_pos
	return world_pos - cam.global_position + get_viewport().get_visible_rect().size * 0.5

func _on_damage_dealt(payload: Dictionary) -> void:
	var amount: float = payload.get("amount", 0.0)
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	var is_crit: bool = amount > 20.0
	spawn_floating_text(pos, "%.0f" % amount, Color("#ffaaaa") if is_crit else Color("#ffffff"), is_crit)

func _on_damage_player(payload: Dictionary) -> void:
	var amount: float = payload.get("amount", 0.0)
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	spawn_floating_text(pos, "%.0f" % amount, Color("#ff6a6a"), false)
	flash_screen(Color("#ff0000"), 0.08)

func _on_hit_connect(_payload: Dictionary) -> void:
	set_time_scale(0.1, 0.033)

func _on_power_cast(payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	var name: String = payload.get("name", "")
	spawn_floating_text(pos + Vector2(0, -30), name, Color("#c79bff"), false)

func _on_frenzy_start(_payload: Dictionary) -> void:
	flash_screen(Color("#5a0010"), 0.4)
	set_time_scale(0.6, 0.3)

func _on_humanity_lost(_payload: Dictionary) -> void:
	# The world cools when something human dies in you — a desaturated blue-grey wash.
	flash_screen(Color("#243240"), 0.38)


func _on_npc_flinch(payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	spawn_floating_text(pos + Vector2(0, -26), "!", Color("#cfe6ff"), false)

func _on_masquerade_broken(payload: Dictionary) -> void:
	var stars: int = payload.get("stars", 0)
	var color := Color("#f0d060") if stars < 3 else Color("#ff2030")
	flash_screen(color, 0.2)

func _on_feed_gulp_window(payload: Dictionary) -> void:
	# The "tap now" beat — a cyan prompt over the victim telegraphing the timing window.
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	spawn_floating_text(pos + Vector2(0, -34), "GULP", Color("#6fd6e0"), false)


func _on_feed_gulp_perfect(payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	var bonus: float = payload.get("bonus", 0.0)
	spawn_floating_text(pos + Vector2(0, -26), "+%.0f" % bonus, Color("#f0c040"), true)
	set_time_scale(0.45, 0.08)   # brief slowmo reward (present-only; Sim ticks fixed)
	flash_screen(Color("#3a1010"), 0.05)


func _on_feed_gulp_miss(payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	spawn_floating_text(pos + Vector2(0, -20), "miss", Color("#7a4a4a"), false)
