## BloodRenderer.gd — draws the Blood Grammar SPILL layer (dynamic blood pools) under the actors.
##
## Kept separate from the static WorldRenderer (which draws once) so only the few wet cells redraw
## each frame. Reads SimWorld.blood (read-only); lit by the Light2D rig like any CanvasItem.
extends Node2D
class_name BloodRenderer

var _world: SimWorld = null
var _t: float = 0.0


func setup(world: SimWorld) -> void:
	_world = world


func _process(delta: float) -> void:
	_t += delta
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
