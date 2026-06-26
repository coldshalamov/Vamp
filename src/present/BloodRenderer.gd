## BloodRenderer.gd — draws the Blood Grammar SPILL layer (dynamic blood pools) under the actors.
##
## Kept separate from the static WorldRenderer (which draws once) so only the few wet cells redraw
## each frame. Reads SimWorld.blood (read-only); lit by the Light2D rig like any CanvasItem.
extends Node2D
class_name BloodRenderer

var _world: SimWorld = null
var _t: float = 0.0
var _was_drawing: bool = false


func setup(world: SimWorld) -> void:
	_world = world


func _process(delta: float) -> void:
	_t += delta
	if _world == null:
		return
	var has_sigils := Sim != null and not Sim.sigils.is_empty()
	if _world._wet.is_empty() and _world._burning.is_empty() and not has_sigils:
		if _was_drawing:
			_was_drawing = false
			queue_redraw()
		return
	_was_drawing = true
	queue_redraw()


func _draw() -> void:
	if _world == null:
		return
	var ts: int = _world.tile_size
	var sx: int = _world.size.x
	for key in _world._wet:
		var i: int = int(key)
		var bd: int = _world.blood[i]
		if bd <= 0:
			continue
		var cx: int = i % sx
		var cy: int = i / sx
		var c := Vector2((float(cx) + 0.5) * ts, (float(cy) + 0.5) * ts)
		var a: float = clampf(float(bd) / 230.0, 0.10, 0.5)
		# dark congealed blood — small, low-opacity discs that merge into an organic stain
		draw_circle(c, ts * 0.52, Color(0.09, 0.004, 0.015, a * 0.85))
		draw_circle(c, ts * 0.34, Color(0.24, 0.015, 0.035, a))
		if bd > 150:
			draw_circle(c - Vector2(ts * 0.1, ts * 0.1), ts * 0.12, Color(0.45, 0.06, 0.1, a * 0.45))
	# REACT — burning blood: flickering flames on top of the pools
	for key in _world._burning:
		var fi: int = int(key)
		var ft: int = _world.fire[fi]
		if ft <= 0:
			continue
		var fx: int = fi % sx
		var fy: int = fi / sx
		var fc := Vector2((float(fx) + 0.5) * ts, (float(fy) + 0.5) * ts)
		var flick: float = 0.7 + 0.3 * sin(_t * 13.0 + float(fi))
		var life: float = clampf(float(ft) / 50.0, 0.3, 1.0)
		draw_circle(fc, ts * 0.5 * flick, Color(0.85, 0.30, 0.06, 0.42 * life))
		draw_circle(fc + Vector2(0, -ts * 0.08), ts * 0.32 * flick, Color(1.0, 0.62, 0.16, 0.55 * life))
		draw_circle(fc + Vector2(0, -ts * 0.18 * flick), ts * 0.16 * flick, Color(1.0, 0.92, 0.55, 0.7 * life))
	# INSCRIBE — glowing blood-sigils that rewrite a room's rule
	if Sim != null:
		for s in Sim.sigils:
			var sp: Vector2 = s["pos"]
			var sr: float = float(s["radius"])
			var slife: float = clampf(float(s["ticks"]) / 360.0, 0.15, 1.0)
			var spulse: float = 0.6 + 0.4 * sin(_t * 3.0)
			var scol := Color(0.86, 0.07, 0.17, 0.32 * slife * spulse)
			draw_arc(sp, sr, 0, TAU, 44, scol, 2.6, true)
			draw_arc(sp, sr * 0.6, 0, TAU, 34, Color(scol.r, scol.g, scol.b, 0.18 * slife), 1.6, true)
			for k in range(3):
				var ang: float = _t * 0.5 + float(k) * TAU / 3.0
				draw_line(sp + Vector2.RIGHT.rotated(ang) * sr * 0.16, sp + Vector2.RIGHT.rotated(ang) * sr * 0.46, Color(scol.r, scol.g, scol.b, 0.5 * slife), 1.6)
