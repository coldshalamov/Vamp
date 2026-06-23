## PropRenderer.gd — upright billboard street props (gothic lamps, trees, neon signs).
##
## Wires the keyed prop art (assets/props/) into the slice as billboards anchored at their base,
## the standard top-down approach for verticals. Drawn beneath the entity layer so the predator
## walks "in front" of bases. Lamps sit at the world's Light2D anchors so the glow has a source.
extends Node2D
class_name PropRenderer

# {tex, base position (world), scale}. Lamps align to SimWorld.lights so the glow reads as theirs.
const PLACEMENTS := [
	{ "tex": "res://assets/props/lamp.png", "pos": Vector2(520, 545), "scale": 0.36 },
	{ "tex": "res://assets/props/lamp_alt.png", "pos": Vector2(300, 545), "scale": 0.34 },
	{ "tex": "res://assets/props/neon_sign.png", "pos": Vector2(250, 300), "scale": 0.55 },
	{ "tex": "res://assets/props/tree.png", "pos": Vector2(120, 600), "scale": 0.42 },
	{ "tex": "res://assets/props/tree_alt1.png", "pos": Vector2(700, 705), "scale": 0.42 },
	{ "tex": "res://assets/props/tree_alt2.png", "pos": Vector2(1010, 705), "scale": 0.42 },
]

var _items: Array[Dictionary] = []


func setup(_world: SimWorld) -> void:
	for p in PLACEMENTS:
		var path: String = p["tex"]
		if not ResourceLoader.exists(path):
			continue
		var t := load(path) as Texture2D
		if t != null:
			_items.append({ "t": t, "pos": p["pos"], "s": float(p["scale"]) })
	queue_redraw()


func _draw() -> void:
	for it in _items:
		var t: Texture2D = it["t"]
		var pos: Vector2 = it["pos"]
		var s: float = it["s"]
		var w := t.get_width() * s
		var h := t.get_height() * s
		# Soft base shadow.
		draw_circle(pos + Vector2(0, 1), w * 0.42, Color(0, 0, 0, 0.35))
		# Billboard: base at pos, rising upward.
		draw_texture_rect(t, Rect2(pos - Vector2(w * 0.5, h), Vector2(w, h)), false)
