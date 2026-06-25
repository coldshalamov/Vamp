## VialGauge.gd — a horizontal blood-phial vitae gauge (a corked glass vial that fills with blood),
## replacing the plain progress bar for the vampire's vitae. Presentation only; fed by HUD via
## set_fill(ratio, color). No class_name (preloaded by HUD) so it needs no global registration.
##
## Feel: the displayed fill LERPS toward the real ratio (so a cast drains smoothly instead of
## snapping); the vial PULSES when blood < 20%; and a feed SURGE flashes a bright glow when vitae
## refills. All animation is reduced-motion aware (snaps + no throb/glow when reduced).
extends Control

const LOW_THRESHOLD := 0.20
const SURGE_TIME := 0.7

var ratio: float = 1.0            # target ratio (set by HUD; the test/contract reads this)
var fill_color: Color = Color("c01028")

var _display_ratio: float = 1.0   # smoothed ratio actually drawn
var _pulse_phase: float = 0.0     # advances the low-blood throb
var _surge: float = 0.0           # 0..1 feed-glow brightness (decays)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display_ratio = ratio


## HUD calls this every frame with the true ratio. The displayed fill eases toward it; under reduced
## motion it snaps. Signature is preserved (HUD calls via .call("set_fill", r, col)).
func set_fill(r: float, col: Color) -> void:
	ratio = clampf(r, 0.0, 1.0)
	fill_color = col
	if _reduced_motion():
		_display_ratio = ratio
	queue_redraw()


## Flash a bright surge over the vial — call when vitae refills (feed.kill / feed.spare / feed.end).
## No-op under reduced motion.
func surge() -> void:
	if _reduced_motion():
		return
	_surge = 1.0
	queue_redraw()


func _reduced_motion() -> bool:
	return UIManager != null and UIManager.is_reduced_motion()


func _process(delta: float) -> void:
	var dirty := false
	# Ease the displayed fill toward the real ratio (smooth drain on cast / climb on feed).
	if not _reduced_motion() and not is_equal_approx(_display_ratio, ratio):
		_display_ratio = lerpf(_display_ratio, ratio, clampf(delta * 8.0, 0.0, 1.0))
		if absf(_display_ratio - ratio) < 0.002:
			_display_ratio = ratio
		dirty = true
	# Low-blood throb: only while there IS blood (0 < ratio < 20%) so it never throbs over a menu
	# (null player / death both pin ratio to exactly 0.0) and reduced motion holds it steady.
	if not _reduced_motion() and ratio > 0.0 and ratio < LOW_THRESHOLD:
		_pulse_phase += delta * 6.0
		dirty = true
	elif _pulse_phase != 0.0:
		_pulse_phase = 0.0
		dirty = true
	# Decay the feed surge.
	if _surge > 0.0:
		_surge = maxf(0.0, _surge - delta / SURGE_TIME)
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 4.0 or h <= 2.0:
		return
	var pad := 2.0
	var cork_w := 9.0
	var glass := Color(0.72, 0.78, 0.88, 0.45)
	var draw_ratio := _display_ratio
	# blood fills from the left, up to the cork
	var span := w - pad * 2.0 - cork_w
	var fw := span * draw_ratio
	# low-blood throb modulates the blood alpha + a faint red bloom behind the glass
	var throb := 0.0
	if _pulse_phase > 0.0:
		throb = 0.5 + 0.5 * sin(_pulse_phase)
	if fw > 0.0:
		var blood_a := 0.9
		if throb > 0.0:
			blood_a = lerpf(0.55, 1.0, throb)
		draw_rect(Rect2(pad, pad, fw, h - pad * 2.0), Color(fill_color, blood_a), true)
		# meniscus highlight at the blood's surface
		draw_line(Vector2(pad + fw, pad), Vector2(pad + fw, h - pad), Color(1.0, 0.55, 0.6, 0.7), 1.5)
	# low-blood warning bloom (a red wash over the empty span)
	if throb > 0.0:
		draw_rect(Rect2(pad, pad, span, h - pad * 2.0), Color(0.9, 0.1, 0.15, 0.10 + 0.18 * throb), false, 2.0)
	# feed surge: a bright warm glow sweeping the whole vial
	if _surge > 0.0:
		var glow := Color(1.0, 0.78, 0.55, 0.45 * _surge)
		draw_rect(Rect2(pad, pad, span, h - pad * 2.0), glow, true)
		draw_rect(Rect2(1, 1, w - cork_w - 2, h - 2), Color(1.0, 0.85, 0.6, 0.7 * _surge), false, 2.0)
	# glass body outline
	draw_rect(Rect2(1, 1, w - cork_w - 2, h - 2), glass, false, 1.5)
	# cork at the right end
	draw_rect(Rect2(w - cork_w, 1, cork_w - 1, h - 2), Color(0.45, 0.30, 0.18, 0.95), true)
	# long glass shine
	draw_line(Vector2(4, h * 0.3), Vector2(w - cork_w - 3, h * 0.3), Color(1, 1, 1, 0.10), 1.5)
