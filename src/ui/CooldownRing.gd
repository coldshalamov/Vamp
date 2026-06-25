## CooldownRing.gd — a radial cooldown WIPE drawn over a hotbar slot, plus a brief READY pulse when
## the slot transitions from on-cooldown to ready. Presentation only; fed by HUD via set_fraction()
## each frame (fraction = cooldown_remaining / cooldown_total, 1.0 = just cast, 0.0 = ready). No
## class_name (preloaded by HUD) so it needs no global registration.
extends Control

const READY_FLASH_TIME := 0.34

var _frac: float = 0.0          # current cooldown fraction (1.0 fresh cast .. 0.0 ready)
var _prev_frac: float = 0.0     # last frame's fraction, to detect the cooldown->ready edge
var _ready_pulse: float = 0.0   # 0..1 brightness of the just-became-ready flash (decays)
var _shade: Color = Color(0, 0, 0, 0.62)
var _arc_color: Color = Color(0.92, 0.62, 0.22, 0.85)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)   # only ticks while a READY flash is decaying


## HUD calls this each frame. `frac` is the remaining-cooldown ratio in [0,1]; `arc_color` tints the
## wipe + ready flash (usually the slot's discipline color). A drop from >0 to 0 fires the READY pulse.
func set_fraction(frac: float, arc_color: Color = Color(0.92, 0.62, 0.22, 1.0)) -> void:
	var f := clampf(frac, 0.0, 1.0)
	_arc_color = arc_color
	if _prev_frac > 0.0 and f <= 0.0 and not _reduced_motion():
		_ready_pulse = 1.0
		set_process(true)
	_prev_frac = f
	if not is_equal_approx(f, _frac) or _ready_pulse > 0.0:
		_frac = f
		queue_redraw()


## Force the ring to the ready/empty state with no flash (loadout change, slot emptied). Keeps stale
## arcs from lingering when a slot stops pointing at an on-cooldown power.
func clear_ring() -> void:
	_prev_frac = 0.0
	_frac = 0.0
	_ready_pulse = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _ready_pulse <= 0.0:
		set_process(false)
		return
	_ready_pulse = maxf(0.0, _ready_pulse - delta / READY_FLASH_TIME)
	queue_redraw()


func _reduced_motion() -> bool:
	return UIManager != null and UIManager.is_reduced_motion()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 4.0 or h <= 4.0:
		return
	var center := Vector2(w, h) * 0.5
	var radius := minf(w, h) * 0.5 - 2.0
	if radius <= 1.0:
		return
	# --- radial cooldown wipe: a darkening pie that shrinks counter-clockwise as the cooldown elapses ---
	if _frac > 0.001:
		var start := -PI * 0.5                        # 12 o'clock
		var sweep := TAU * _frac
		var pts := PackedVector2Array()
		pts.append(center)
		var steps := maxi(3, int(ceil(sweep / 0.20)))
		for i in steps + 1:
			var a := start + sweep * (float(i) / float(steps))
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(pts, _shade)
		# bright leading edge of the wipe — reads as the "hand" sweeping toward ready
		var edge_a := start + sweep
		draw_line(center, center + Vector2(cos(edge_a), sin(edge_a)) * radius, Color(_arc_color, 0.6), 1.5)
		# thin ring outline of the remaining arc
		draw_arc(center, radius, start, start + sweep, steps, Color(_arc_color, 0.5), 1.5, true)
	# --- READY pulse: an expanding bright ring + flash when the slot just came off cooldown ---
	if _ready_pulse > 0.0:
		var p := _ready_pulse
		var ring_r := radius * (1.0 + (1.0 - p) * 0.35)
		draw_arc(center, ring_r, 0.0, TAU, 28, Color(_arc_color, 0.7 * p), 2.0, true)
		draw_arc(center, radius, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.35 * p), 1.5, true)
