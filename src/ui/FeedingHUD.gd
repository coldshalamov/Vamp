## FeedingHUD.gd — the feeding experience UX (Track C deliverable 3).
##
## A full-rect, mouse-ignoring Control parented under UIManager (a persistent CanvasLayer).
## It surfaces the felt beats of a feed: a circular blood-drain meter with a heartbeat pulse,
## a victim-state label, the spare/drain choice prompt, the victim's blood-resonance reveal,
## and the kill/spare outcome numbers.
##
## Driven PRIMARILY by polling Sim.player.behaviour each frame (the most reliable source of the
## live feed state) plus a few cues for the discrete beats (resonance reveal on feed.start, the
## choice latch on feed.choice, and the outcome numbers on feed.kill / feed.spare / feed.end).
##
## OWNERSHIP (single-source-per-cue): this node owns the feed meter, the victim-state + choice
## labels, the resonance reveal, and the kill/spare "+N Blood" / "Humanity -X.X" numbers. The
## kill/spare SCREEN FLASH is owned by VisualFX — this node never flashes the screen.
##
## No-ops entirely when Sim == null or Sim.player == null so it never renders over the title /
## main menu while the persistent CanvasLayer is alive.
extends Control
class_name FeedingHUD

# Victim-state band thresholds on feed_progress (0..1).
const BAND_WEAKENING := 0.30
const BAND_FADING := 0.70

# Meter geometry. Drawn in screen space, centered a bit below screen center.
const METER_RADIUS := 54.0
const METER_THICKNESS := 9.0
const METER_BELOW_CENTER := 70.0   # px below screen center

# Heartbeat pulse: scale oscillation amplitude + base/peak beats-per-second by progress.
const PULSE_AMPLITUDE := 0.10
const PULSE_HZ_LOW := 1.1    # slow thump near the start of a feed
const PULSE_HZ_HIGH := 3.4   # racing pulse as the victim fades

# Outcome popup lifetime.
const OUTCOME_DURATION := 1.6
const OUTCOME_RISE := 40.0

# Resonance color + buff text map (verbatim from the deliverable spec).
const RESONANCE := {
	"sanguine":    { "color": "#c01028", "label": "SANGUINE",    "buff": "+Regen" },
	"choleric":    { "color": "#e0883a", "label": "CHOLERIC",    "buff": "+25% Melee" },
	"melancholic": { "color": "#6a8cff", "label": "MELANCHOLIC", "buff": "+25% Spell" },
	"phlegmatic":  { "color": "#6fd6a0", "label": "PHLEGMATIC",  "buff": "+20% Armor" },
}

# --- live feed state, refreshed each frame while feeding ---
var _feeding: bool = false
var _poll_confirmed: bool = false      # true once polling has actually seen the live feed target
var _progress: float = 0.0
var _pulse_phase: float = 0.0

# --- discrete-beat state set by cues ---
var _resonance: String = ""           # set on feed.start; cleared on feed.end
var _choice_active: bool = false       # latched by feed.choice; held while in the choice band

# Lightweight self-managed labels (no scene). Built lazily on first feed.
var _state_label: Label = null
var _choice_label: Label = null
var _resonance_label: Label = null

# Transient outcome popups: [{ label, t, start }].
var _outcomes: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_labels()
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _build_labels() -> void:
	_resonance_label = _make_label(_font_size() + 2, HORIZONTAL_ALIGNMENT_CENTER)
	_state_label = _make_label(_font_size() + 4, HORIZONTAL_ALIGNMENT_CENTER)
	_choice_label = _make_label(_font_size(), HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_resonance_label)
	add_child(_state_label)
	add_child(_choice_label)
	_resonance_label.visible = false
	_state_label.visible = false
	_choice_label.visible = false


func _make_label(size: int, align: int) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", _color("hud_text", Color(0.95, 0.95, 0.98)))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.horizontal_alignment = align
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _process(delta: float) -> void:
	# Hard no-op when there is no live game: keeps this off the title/menu screens.
	if Sim == null or Sim.player == null:
		if _feeding:
			_end_feed()
		return

	_poll_feed()

	if not _feeding:
		# Outcome popups can outlive the feed (they pop on kill/spare just as feeding ends).
		_update_outcomes(delta)
		if not _outcomes.is_empty():
			queue_redraw()
		return

	# Advance the heartbeat pulse, accelerating with progress (skip when reduced motion).
	if not _reduced_motion():
		var hz: float = lerpf(PULSE_HZ_LOW, PULSE_HZ_HIGH, clampf(_progress, 0.0, 1.0))
		_pulse_phase += delta * hz * TAU
	_update_outcomes(delta)
	_update_labels()
	queue_redraw()


## Read the live feed straight off the player behaviour. This is the authoritative source for
## whether a feed is active and how far it has progressed.
func _poll_feed() -> void:
	var beh = Sim.player.behaviour
	var active: bool = beh != null and int(beh.get("feeding_target_id")) != 0
	if active:
		_feeding = true
		_poll_confirmed = true
		_progress = clampf(float(beh.get("feed_progress")), 0.0, 1.0)
		# The choice latch holds while progress sits in the fading band; release below it.
		if _progress < BAND_FADING:
			_choice_active = false
		else:
			# Polling fallback: arm the prompt even if the feed.choice cue was missed.
			_choice_active = true
	elif _feeding and _poll_confirmed:
		# Target gone / feed interrupted without a kill/spare cue (e.g. walked away).
		# Only tear down once polling has actually seen the feed: feed.start cues arrive
		# (deferred) a frame before the polled feeding_target_id flips on, so a freshly
		# cue-started feed must survive its first un-confirmed poll.
		_end_feed()


func _end_feed() -> void:
	_feeding = false
	_poll_confirmed = false
	_progress = 0.0
	_pulse_phase = 0.0
	_resonance = ""
	_choice_active = false
	if _resonance_label != null:
		_resonance_label.visible = false
	if _state_label != null:
		_state_label.visible = false
	if _choice_label != null:
		_choice_label.visible = false
	queue_redraw()


func _update_labels() -> void:
	var center := _meter_center()

	# Victim state band.
	_state_label.text = _victim_state(_progress)
	_state_label.size = Vector2(260, 28)
	_state_label.position = center + Vector2(-130, METER_RADIUS + 12.0)
	_state_label.visible = true

	# Resonance reveal sits just above the meter.
	if _resonance != "" and RESONANCE.has(_resonance):
		var info: Dictionary = RESONANCE[_resonance]
		_resonance_label.text = "%s — %s" % [info["label"], info["buff"]]
		_resonance_label.add_theme_color_override("font_color", Color(info["color"]))
		_resonance_label.size = Vector2(320, 26)
		_resonance_label.position = center + Vector2(-160, -METER_RADIUS - 40.0)
		_resonance_label.visible = true
	else:
		_resonance_label.visible = false

	# Choice prompt below the state label, only while in the choice band.
	if _choice_active:
		_choice_label.text = "Release [F] to spare  /  Hold to drain fully"
		_choice_label.size = Vector2(420, 24)
		_choice_label.position = center + Vector2(-210, METER_RADIUS + 42.0)
		_choice_label.visible = true
	else:
		_choice_label.visible = false


func _victim_state(progress: float) -> String:
	if progress < BAND_WEAKENING:
		return "Struggling"
	if progress < BAND_FADING:
		return "Weakening"
	return "Fading"


func _update_outcomes(delta: float) -> void:
	for i in range(_outcomes.size() - 1, -1, -1):
		var o: Dictionary = _outcomes[i]
		o.t += delta
		var p: float = o.t / OUTCOME_DURATION
		if p >= 1.0:
			if is_instance_valid(o.label):
				o.label.queue_free()
			_outcomes.remove_at(i)
			continue
		if is_instance_valid(o.label):
			o.label.position = o.start - Vector2(0, p * OUTCOME_RISE)
			o.label.modulate.a = 1.0 - p


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if not _feeding:
		return
	var center := _meter_center()
	var scale_mul := 1.0
	if not _reduced_motion():
		scale_mul = 1.0 + sin(_pulse_phase) * PULSE_AMPLITUDE
	var r := METER_RADIUS * scale_mul

	# Resonance tints the meter when known; otherwise a default blood crimson.
	var fill_col := _color("hud_accent", Color("#c01028"))
	if _resonance != "" and RESONANCE.has(_resonance):
		fill_col = Color((RESONANCE[_resonance] as Dictionary)["color"])

	# Track (unfilled remainder) — a dim ring.
	var track_col := Color(0.12, 0.10, 0.12, 0.7)
	draw_arc(center, r, 0.0, TAU, 64, track_col, METER_THICKNESS, true)

	# Filled arc clockwise from the top (12 o'clock = -PI/2).
	var start_ang := -PI * 0.5
	var end_ang := start_ang + TAU * clampf(_progress, 0.0, 1.0)
	draw_arc(center, r, start_ang, end_ang, 64, fill_col, METER_THICKNESS, true)

	# A small inner pip at the leading edge so the fill reads even at low progress.
	var lead := center + Vector2(cos(end_ang), sin(end_ang)) * r
	draw_circle(lead, METER_THICKNESS * 0.55, Color(1, 1, 1, 0.9))


func _meter_center() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(vp.x * 0.5, vp.y * 0.5 + METER_BELOW_CENTER)


# ------------------------------------------------------------------ cues

func _on_cue(event_id: String, payload: Dictionary) -> void:
	if Sim == null or Sim.player == null:
		return
	match event_id:
		"feed.start":
			_resonance = String(payload.get("resonance", ""))
			_feeding = true
			_poll_confirmed = false   # let polling confirm the live target before any teardown
			_choice_active = false
		"feed.choice":
			_choice_active = true
		"feed.kill":
			_pop_outcome(payload, true)
		"feed.spare":
			_pop_outcome(payload, false)
		"feed.end":
			_end_feed()


## Spawn the kill/spare outcome numbers near screen center. Kill is red and also reports the
## humanity cost; spare is green. (The screen flash for both is owned by VisualFX.)
func _pop_outcome(payload: Dictionary, killed: bool) -> void:
	var blood_gained: float = float(payload.get("blood_gained", 0.0))
	var center := _meter_center()
	var col := Color("#c01028") if killed else Color("#6fd6a0")
	var anchor := center + Vector2(0, -METER_RADIUS - 70.0)
	_spawn_outcome_label("+%d Blood" % int(round(blood_gained)), col, anchor)
	if killed:
		var humanity_lost: float = float(payload.get("humanity_lost", 0.0))
		if humanity_lost > 0.0:
			_spawn_outcome_label("Humanity -%.1f" % humanity_lost, Color("#9a7bd0"),
				anchor + Vector2(0, 26.0))


func _spawn_outcome_label(text: String, color: Color, screen_pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _font_size() + 6)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(220, 30)
	lbl.position = screen_pos - Vector2(110, 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	_outcomes.append({ "label": lbl, "t": 0.0, "start": lbl.position })


# ------------------------------------------------------------------ helpers

func _reduced_motion() -> bool:
	return UIManager.is_reduced_motion() if UIManager != null else false


func _font_size() -> int:
	return UIManager.theme_font_size("font_size", "Label", 16) if UIManager != null else 16


func _color(key: String, fallback: Color) -> Color:
	return UIManager.theme_get_color(key, "UITheme", fallback) if UIManager != null else fallback
