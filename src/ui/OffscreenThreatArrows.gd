## OffscreenThreatArrows.gd — screen-edge threat indicators (Deliverable 2c).
##
## Full-rect Control overlay (lives under UIManager, persists across screens). Each frame it
## scans for hostile NPCs whose on-screen position falls OUTSIDE the viewport and draws a red
## arrow pinned to the screen edge pointing toward each one. Size and opacity scale with world
## proximity (closer = bigger/brighter). The arrow count is capped (nearest first) to avoid
## clutter. Presentation only: reads Sim each frame, never mutates.
##
## World->screen uses the live viewport canvas transform (position + zoom + offset baked in),
## matching DebugOverlay.gd — NOT VisualFX's zoom-less formula, which would misplace edges at
## the 2.4x gameplay zoom.
extends Control
class_name OffscreenThreatArrows

## Above this world distance an arrow is at min size/alpha; at/below FULL it is full strength.
const PROX_FAR := 1600.0
const PROX_FULL := 600.0
## Most arrows we ever draw at once (nearest hostiles win).
const MAX_ARROWS := 8
## Inset from the literal screen edge so the triangle base isn't clipped.
const EDGE_MARGIN := 18.0
## Arrow triangle sizing (screen pixels) — lerps from MIN (far) to MAX (close).
const ARROW_LEN_MIN := 14.0
const ARROW_LEN_MAX := 26.0
const ARROW_WIDTH_RATIO := 0.62
const ALPHA_MIN := 0.28
const ALPHA_MAX := 0.92
## Gentle proximity pulse (close threats breathe); disabled under reduced motion.
const PULSE_HZ := 2.2
const PULSE_DEPTH := 0.12

var _pulse_t: float = 0.0
## Test hook only: counts _draw() invocations that reached the arrow-drawing body (a hostile
## was actually rendered). Lets the smoke test confirm the draw math ran, not just instantiation.
var _arrows_drawn: int = 0


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	# A full-rect Control with the default STOP filter would swallow every click across the whole
	# screen and break gameplay input. Match NotificationPanel: never intercept the mouse.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_pulse_t += delta
	# Redraw UNCONDITIONALLY. The validity gate lives in _draw() so that the canvas clears on the
	# valid->invalid transition (return to menu); gating queue_redraw() would leave stale arrows
	# painted over the title screen.
	queue_redraw()


func _draw() -> void:
	# No-op over the title screen / between runs, and when hidden.
	if Sim == null or Sim.player == null or not visible:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return  # headless / no gameplay camera — nothing to anchor against.

	var rect := get_rect()
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	var center := rect.size * 0.5
	var half := rect.size * 0.5 - Vector2(EDGE_MARGIN, EDGE_MARGIN)
	if half.x <= 1.0 or half.y <= 1.0:
		return

	var xform := get_viewport().get_canvas_transform()
	var ppos: Vector2 = Sim.player.pos

	# Collect offscreen hostiles with their world distance, nearest-first.
	var threats: Array[Dictionary] = []
	for e in Sim.entities:
		if e == null or e.dead or e.kind != "npc":
			continue
		if not e.hostile_to_player:
			continue
		var screen: Vector2 = xform * e.pos
		# Onscreen entities don't need an edge arrow.
		if rect.has_point(screen):
			continue
		var dist: float = (e.pos - ppos).length()
		threats.append({ "screen": screen, "dist": dist })

	if threats.is_empty():
		return
	threats.sort_custom(_sort_by_dist)

	var reduced: bool = false
	if UIManager != null:
		reduced = UIManager.is_reduced_motion()
	# Proximity pulse multiplier (1.0 when reduced motion).
	var pulse: float = 1.0
	if not reduced:
		pulse = 1.0 + PULSE_DEPTH * sin(_pulse_t * TAU * PULSE_HZ)

	var count: int = mini(threats.size(), MAX_ARROWS)
	for i in range(count):
		var t: Dictionary = threats[i]
		_draw_arrow(center, half, t["screen"], float(t["dist"]), pulse)
		_arrows_drawn += 1


func _draw_arrow(center: Vector2, half: Vector2, target_screen: Vector2, dist: float, pulse: float) -> void:
	var dir: Vector2 = target_screen - center
	if dir == Vector2.ZERO:
		return
	# Clamp the arrow tip to the inset rectangle edge along the direction to the target.
	# Solve the smallest scale s such that center + s*dir lands on a |x|=half.x or |y|=half.y wall.
	var sx: float = INF
	var sy: float = INF
	if absf(dir.x) > 0.0001:
		sx = half.x / absf(dir.x)
	if absf(dir.y) > 0.0001:
		sy = half.y / absf(dir.y)
	var s: float = minf(sx, sy)
	if not is_finite(s):
		return
	var tip: Vector2 = center + dir * s

	# Proximity 0..1: 1.0 at/inside PROX_FULL, 0.0 at/beyond PROX_FAR.
	var prox: float = clampf(inverse_lerp(PROX_FAR, PROX_FULL, dist), 0.0, 1.0)
	var length: float = lerpf(ARROW_LEN_MIN, ARROW_LEN_MAX, prox) * pulse
	var alpha: float = clampf(lerpf(ALPHA_MIN, ALPHA_MAX, prox) * pulse, 0.0, 1.0)
	var col := Color(0.92, 0.16, 0.18, alpha)

	var fwd: Vector2 = dir.normalized()
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var width: float = length * ARROW_WIDTH_RATIO
	# Triangle points OUTWARD (tip at the edge), base pulled back toward the center.
	var base: Vector2 = tip - fwd * length
	var p0: Vector2 = tip
	var p1: Vector2 = base + side * width * 0.5
	var p2: Vector2 = base - side * width * 0.5
	var pts := PackedVector2Array([p0, p1, p2])
	draw_colored_polygon(pts, col)
	# A darker rim so the arrow reads against bright or busy backgrounds.
	var rim := Color(0.18, 0.02, 0.03, alpha)
	draw_polyline(PackedVector2Array([p0, p1, p2, p0]), rim, 1.5)


func _sort_by_dist(a: Dictionary, b: Dictionary) -> bool:
	return float(a["dist"]) < float(b["dist"])
