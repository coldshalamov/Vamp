## VisualFX.gd — visual feedback layer: damage numbers, screen flash, captions, hitstop.
##
## CanvasLayer that consumes CueBus events and spawns transient UI/screen effects.
## Respects Accessibility settings.
extends CanvasLayer
class_name VisualFX

const DAMAGE_FONT_SIZE := 18
const DAMAGE_RISE := 48.0
const DAMAGE_DURATION := 0.7
const MAX_FLOATING_TEXTS := 48

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
	# B4 — hit.connect fires hitstop freeze here; directional shake is in CameraDirector.
	# Both register under the same event_id; CueBus.define() MERGES modality keys so both fire.
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
	# B2 — SimPlayer currently emits "feed.gulp.perfect" (dot). The CONTRACT specifies
	# "feed.gulp_perfect" (underscore). Register BOTH so this layer fires regardless of
	# which name the sim team ultimately settles on. The director should reconcile the
	# cue string with the sim team. See CROSS-TEAM CONFLICT note in return summary.
	CueBus.define("feed.gulp.perfect", CueBus.Priority.COMBAT, {
		"vfx": _on_feed_gulp_perfect,
		"duration_ms": 600,
	})
	CueBus.define("feed.gulp_perfect", CueBus.Priority.COMBAT, {
		"vfx": _on_feed_gulp_perfect,
		"duration_ms": 600,
	})
	CueBus.define("feed.gulp.miss", CueBus.Priority.GAMEPLAY, {
		"vfx": _on_feed_gulp_miss,
		"duration_ms": 200,
	})
	CueBus.define("player.xp", CueBus.Priority.GAMEPLAY, {
		"vfx": _on_player_xp,
		"duration_ms": 300,
		"max_concurrent": 6,
	})
	CueBus.define("player.level_up", CueBus.Priority.CRITICAL, {
		"vfx": _on_level_up,
		"duration_ms": 900,
	})
	CueBus.define("flow.perfect", CueBus.Priority.COMBAT, {
		"vfx": _on_flow_perfect,
		"duration_ms": 250,
		"max_concurrent": 4,
	})
	CueBus.define("power.unlocked", CueBus.Priority.CRITICAL, {
		"vfx": _on_power_unlocked,
		"duration_ms": 1400,
	})
	# B5 — kill vs spare distinct reads
	CueBus.define("feed.kill", CueBus.Priority.COMBAT, {
		"vfx": _on_feed_kill,
		"duration_ms": 450,
	})
	CueBus.define("feed.spare", CueBus.Priority.GAMEPLAY, {
		"vfx": _on_feed_spare,
		"duration_ms": 350,
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
	while _floating_texts.size() >= MAX_FLOATING_TEXTS:
		var old: Dictionary = _floating_texts.pop_front()
		var old_label = old.get("label", null)
		if old_label != null and is_instance_valid(old_label):
			old_label.queue_free()
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
	# B19 — size/color from the real crit bool in the payload, NOT from amount > 20.
	var is_crit: bool = bool(payload.get("crit", false))
	var col: Color = Color("#ffdd88") if is_crit else Color("#ffffff")
	spawn_floating_text(pos, "%.0f" % amount, col, is_crit)

func _on_damage_player(payload: Dictionary) -> void:
	var amount: float = payload.get("amount", 0.0)
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	spawn_floating_text(pos, "%.0f" % amount, Color("#ff6a6a"), false)
	flash_screen(Color("#ff0000"), 0.08)

## B4 — MELEE CONNECT hitstop freeze (present-only, via Engine.time_scale).
## Micro-pause: ~3 frames at 60fps. Crit gets a slightly longer snap.
## WorldFX draws the spark (via cue_emitted signal). CameraDirector kicks the camera.
## All three modalities fire together because CueBus.define() merges handlers.
## Flash is crit-only to avoid strobing on normal-hit flurries.
func _on_hit_connect(payload: Dictionary) -> void:
	var is_crit: bool = bool(payload.get("crit", false))
	# Hitstop: brief Engine.time_scale dip. ~0.05s at scale 0.05 ≈ 3 frames of freeze.
	var freeze_dur: float = 0.07 if is_crit else 0.05
	set_time_scale(0.05, freeze_dur)
	# Screen flash: crit only — avoids strobe on flurries. The spark handles normal hits.
	if is_crit:
		flash_screen(Color(1.0, 0.88, 0.72, 1.0), 0.07)

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

## B21 — masquerade flash color/intensity scales CONTINUOUSLY with stars (0-6).
## Low stars (1-2): a muted amber warning. High stars (5-6): a blinding crimson alarm.
## flash_screen() drives alpha from `duration * 3.0` (clamped 0.2-1.0); duration itself
## scales with stars so 1-star is a brief dim tap and 6-star is a long searing blast.
func _on_masquerade_broken(payload: Dictionary) -> void:
	var stars: int = clampi(int(payload.get("stars", 0)), 0, 6)
	# t: 0.0 = 0 stars, 1.0 = 6 stars
	var t: float = float(stars) / 6.0
	# Color lerps from muted amber through gold to hot red as stars rise.
	var low_col := Color(0.83, 0.63, 0.13)   # dim amber (0-2 stars)
	var mid_col := Color(0.94, 0.82, 0.38)   # gold (3 stars)
	var hi_col  := Color(1.0,  0.13, 0.19)   # full alarm red (6 stars)
	var color: Color
	if t < 0.5:
		color = low_col.lerp(mid_col, t * 2.0)
	else:
		color = mid_col.lerp(hi_col, (t - 0.5) * 2.0)
	# Duration scales 0.07 (1-star) to 0.38 (6-star); flash_screen derives alpha from it.
	var duration: float = lerpf(0.07, 0.38, t)
	flash_screen(color, duration)

func _on_feed_gulp_window(payload: Dictionary) -> void:
	# The "tap now" beat — a cyan prompt over the victim telegraphing the timing window.
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	spawn_floating_text(pos + Vector2(0, -34), "GULP", Color("#6fd6e0"), false)


## B2 — PERFECT GULP: present-only slow-mo time-dilation pulse + deep crimson flash.
## The contracting Bleeding Occult Sigil is rendered by WorldFX (world-space, throat position).
## Engine.time_scale is present-only — Sim ticks are fixed and unaffected.
## No sim.time_scale write anywhere in this handler.
func _on_feed_gulp_perfect(payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	var bonus: float = payload.get("bonus", 0.0)
	# Time-dilation pulse: deep slow then snap back. Creates the "kiss lands" feel.
	# Two-phase: plunge to 0.12 for the punch-in, then recover to 0.55 for the linger.
	set_time_scale(0.12, 0.06)    # punch-in freeze (present-only Engine.time_scale)
	# A deep blood-red flash blooms then fades — warmth of the kiss.
	flash_screen(Color(0.55, 0.04, 0.12, 1.0), 0.22)
	# Brief amber number for the bonus vitae (sim already emits the correct amount).
	if bonus > 0.0:
		spawn_floating_text(pos + Vector2(0, -32), "+%.0f" % bonus, Color("#f0c040"), true)
	# A softer second wave of time-dilation — the linger after the snap.
	# Implemented as a tween on Engine.time_scale so it doesn't contend with set_time_scale's
	# await. We start a separate coroutine so this returns immediately.
	_gulp_linger_pulse()


## Present-only linger pulse after perfect gulp. Fires after set_time_scale's freeze ends.
## Uses Engine.time_scale only — never sim.time_scale.
## process_always:true on the timer ensures real-time measurement regardless of time_scale.
func _gulp_linger_pulse() -> void:
	if CueBus != null and CueBus.reduced_motion:
		return
	# Wait 0.09 real seconds (process_always bypasses Engine.time_scale scaling on the timer)
	# so the linger phase starts just as the punch-in freeze snaps back.
	await get_tree().create_timer(0.09, true).timeout
	set_time_scale(0.55, 0.18)


func _on_feed_gulp_miss(payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	spawn_floating_text(pos + Vector2(0, -20), "miss", Color("#7a4a4a"), false)


func _on_player_xp(payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	var amt: int = int(payload.get("amount", 0))
	spawn_floating_text(pos + Vector2(0, -42), "+%d XP" % amt, Color("#f0c040"), false)


func _on_level_up(payload: Dictionary) -> void:
	var lvl: int = int(payload.get("level", 0))
	flash_screen(Color("#3a2e08"), 0.4)
	show_caption("LEVEL %d" % lvl)


func _on_flow_perfect(payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	var stacks: int = int(payload.get("stacks", 1))
	spawn_floating_text(pos + Vector2(0, -34), "FLOW x%d" % stacks, Color("#f0c040"), true)
	set_time_scale(0.55, 0.05)


func _on_power_unlocked(payload: Dictionary) -> void:
	var nm: String = String(payload.get("name", "power"))
	var slot: int = int(payload.get("slot", 0))
	flash_screen(Color("#2a1838"), 0.35)
	show_caption("NEW POWER — %s  [key %d]" % [nm.to_upper(), slot])


## B5 — feed.kill: a final dark pulse — something mortal just ended.
## Deep shadow-black wash, brief and cold. The predator has crossed a line.
func _on_feed_kill(payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	flash_screen(Color(0.02, 0.00, 0.04, 1.0), 0.28)   # near-black shadow pulse
	spawn_floating_text(pos + Vector2(0, -38), "X", Color(0.55, 0.08, 0.14), true)


## B5 — feed.spare: a softer release — the predator pulled back. A breath of silver-blue.
## Lighter than kill: relief, not finality.
func _on_feed_spare(payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	flash_screen(Color(0.18, 0.22, 0.30, 1.0), 0.14)   # cool silver-blue release
	spawn_floating_text(pos + Vector2(0, -38), "~", Color(0.65, 0.78, 0.90), false)
