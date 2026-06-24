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
