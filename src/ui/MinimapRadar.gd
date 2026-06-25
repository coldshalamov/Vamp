## MinimapRadar.gd — a small blood-scent radar: the player at center, nearby NPCs as blips (crimson
## for hostiles, rose for feedable prey, grey for neutrals). Presentation only; reads Sim each frame.
## No class_name (preloaded by HUD) so it needs no global registration.
extends Control

const RANGE := 720.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 1.0
	if r < 4.0:
		return
	draw_circle(c, r, Color(0.04, 0.05, 0.07, 0.66))
	draw_arc(c, r, 0, TAU, 36, Color(0.42, 0.52, 0.62, 0.35), 1.0)
	if Sim == null or Sim.player == null:
		return
	var ppos: Vector2 = Sim.player.pos
	for e in Sim.entities:
		if e == null or e.dead or e.kind != "npc":
			continue
		var rel: Vector2 = e.pos - ppos
		if rel.length() > RANGE:
			continue
		var blip := c + rel / RANGE * r
		var col: Color
		if e.hostile_to_player:
			col = Color(0.88, 0.18, 0.20, 0.95)
		elif e.faction == "civ":
			col = Color(0.82, 0.42, 0.46, 0.85)
		else:
			col = Color(0.50, 0.52, 0.58, 0.70)
		draw_circle(blip, 2.2, col)
	draw_circle(c, 2.8, Color(0.92, 0.85, 0.60, 1.0))   # the predator, at center
	_draw_waypoint(c, r, ppos)


## A single objective arrow clamped to the radar ring. The night's spine is "reach your haven
## before dawn", so while you have not yet made the haven it points cyan to the haven; once reached
## it falls back to a gold arrow toward the nearest feedable mortal (the "find someone to feed"
## goal). Note: reached_haven stays false until you physically enter the haven, so in practice the
## haven arrow leads the whole hunt and the gold feed arrow surfaces only after you have arrived.
func _draw_waypoint(c: Vector2, r: float, ppos: Vector2) -> void:
	var target := Vector2.ZERO
	var col := Color(0.55, 0.85, 1.0, 0.95)   # cyan: head for the haven
	var have_target := false
	if Sim.world != null and not Sim.reached_haven:
		target = Sim.world.haven_zone.get_center()
		have_target = Sim.world.haven_zone.get_area() > 0.0
	if not have_target:
		# Point at the nearest mortal worth feeding on.
		var best_d := INF
		for e in Sim.entities:
			if e == null or e.dead or e.kind != "npc" or e.hostile_to_player:
				continue
			var d: float = e.pos.distance_to(ppos)
			if d < best_d:
				best_d = d
				target = e.pos
				have_target = true
		col = Color(0.95, 0.78, 0.30, 0.95)   # gold: prey to feed on
	if not have_target:
		return
	var rel: Vector2 = target - ppos
	if rel.length() < 0.5:
		return
	var dir := rel.normalized()
	# Clamp to just inside the ring so the arrow always sits on the radar edge, pointing the way.
	var tip: Vector2 = c + dir * (r - 1.0)
	var back: Vector2 = tip - dir * 9.0
	var side: Vector2 = Vector2(-dir.y, dir.x) * 4.0
	var pts: PackedVector2Array = [tip, back + side, back - side]
	draw_colored_polygon(pts, col)
