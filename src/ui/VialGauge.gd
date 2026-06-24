## VialGauge.gd — a horizontal blood-phial vitae gauge (a corked glass vial that fills with blood),
## replacing the plain progress bar for the vampire's vitae. Presentation only; fed by HUD via
## set_fill(ratio, color). No class_name (preloaded by HUD) so it needs no global registration.
extends Control

var ratio: float = 1.0
var fill_color: Color = Color("c01028")


func set_fill(r: float, col: Color) -> void:
	ratio = clampf(r, 0.0, 1.0)
	fill_color = col
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 4.0 or h <= 2.0:
		return
	var pad := 2.0
	var cork_w := 9.0
	var glass := Color(0.72, 0.78, 0.88, 0.45)
	# blood fills from the left, up to the cork
	var span := w - pad * 2.0 - cork_w
	var fw := span * ratio
	if fw > 0.0:
		draw_rect(Rect2(pad, pad, fw, h - pad * 2.0), Color(fill_color, 0.9), true)
		# meniscus highlight at the blood's surface
		draw_line(Vector2(pad + fw, pad), Vector2(pad + fw, h - pad), Color(1.0, 0.55, 0.6, 0.7), 1.5)
	# glass body outline
	draw_rect(Rect2(1, 1, w - cork_w - 2, h - 2), glass, false, 1.5)
	# cork at the right end
	draw_rect(Rect2(w - cork_w, 1, cork_w - 1, h - 2), Color(0.45, 0.30, 0.18, 0.95), true)
	# long glass shine
	draw_line(Vector2(4, h * 0.3), Vector2(w - cork_w - 3, h * 0.3), Color(1, 1, 1, 0.10), 1.5)
