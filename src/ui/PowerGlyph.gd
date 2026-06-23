## PowerGlyph.gd — a crisp vector emblem per discipline for the hotbar.
##
## Replaces the messy chroma-keyed atlas icons (which rendered as cyan/magenta noise) with clean,
## consistent, readable glyphs drawn per discipline-prefix. Tinted by the discipline colour.
extends Control
class_name PowerGlyph

var _prefix: String = ""
var _col: Color = Color.WHITE
var _empty: bool = true


func set_power(prefix: String, col: Color, empty: bool = false) -> void:
	_prefix = prefix
	_col = col
	_empty = empty
	queue_redraw()


func _draw() -> void:
	if _empty:
		return
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 3.0
	var w: float = maxf(2.0, r * 0.20)
	var col := _col
	match _prefix:
		"cel":  # Celerity — double speed chevron
			for off in [-r * 0.35, r * 0.18]:
				draw_polyline([c + Vector2(off - r * 0.25, -r * 0.55), c + Vector2(off + r * 0.35, 0), c + Vector2(off - r * 0.25, r * 0.55)], col, w, true)
		"pot":  # Potence — fist/impact
			draw_circle(c, r * 0.5, col)
			for k in 4:
				var a := -0.9 + k * 0.6
				draw_line(c + Vector2.RIGHT.rotated(a) * r * 0.5, c + Vector2.RIGHT.rotated(a) * r * 0.85, col, w * 0.8)
		"for":  # Fortitude — shield
			draw_polyline([c + Vector2(0, -r * 0.75), c + Vector2(r * 0.62, -r * 0.32), c + Vector2(r * 0.5, r * 0.45), c + Vector2(0, r * 0.8), c + Vector2(-r * 0.5, r * 0.45), c + Vector2(-r * 0.62, -r * 0.32), c + Vector2(0, -r * 0.75)], col, w, true)
		"obf":  # Obfuscate — crescent veil
			draw_arc(c, r * 0.65, PI * 0.32, PI * 1.68, 22, col, w, true)
		"aus":  # Auspex — eye
			draw_arc(c, r * 0.68, 0, TAU, 26, col, w, true)
			draw_circle(c, r * 0.24, col)
		"dom":  # Dominate — twin rings (control)
			draw_arc(c, r * 0.68, 0, TAU * 0.82, 22, col, w, true)
			draw_arc(c, r * 0.36, PI, PI + TAU * 0.82, 16, col, w, true)
		"pre":  # Presence — radiant star
			for k in 8:
				var ang := TAU * float(k) / 8.0
				draw_line(c + Vector2.RIGHT.rotated(ang) * r * 0.22, c + Vector2.RIGHT.rotated(ang) * r * 0.78, col, w * 0.85)
		"bs":   # Blood Sorcery — vitae droplet
			draw_circle(c + Vector2(0, r * 0.22), r * 0.52, col)
			draw_colored_polygon([c + Vector2(0, -r * 0.78), c + Vector2(r * 0.42, r * 0.12), c + Vector2(-r * 0.42, r * 0.12)], col)
		"pro":  # Protean — claw slashes
			for off in [-r * 0.42, 0.0, r * 0.42]:
				draw_line(c + Vector2(off, -r * 0.62), c + Vector2(off + r * 0.22, r * 0.62), col, w)
		_:
			draw_arc(c, r * 0.55, 0, TAU, 20, col, w, true)
