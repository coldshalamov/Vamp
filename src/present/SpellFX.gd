## SpellFX.gd — distinct, archetype-driven spell visuals (the end of "every spell is a circle").
##
## Reads the enriched power.cast cue (archetype + origin + target_pos + color + range/radius/arc) and
## renders a UNIQUE anticipation -> impact -> aftermath effect per archetype: a directional blood lance
## for PROJECTILE, ragged radial spikes for NOVA, ground cracks + debris for GROUND_AOE, a sweeping
## wedge for CONE, a taut beam for ENTITY_TARGET, a descending brand for DEBUFF, speed streaks for DASH,
## a clawed tendril for TETHER, and a body-hugging aura (no ground ring) for SELF_BUFF.
##
## Presentation-only: subscribes to CueBus read-only, never touches Sim or Sim.rng (variation comes
## from a stable hash of cast position + serial). A fixed-size ring buffer bounds it (freeze-safe).
## Lives in its OWN node — WorldFX (owned by the ballistics/graphics pass) is left untouched.
extends Node2D
class_name SpellFX

const MAX_FX := 32

var _fx: Array[Dictionary] = []
var _serial: int = 0
var _was_active: bool = false


func _ready() -> void:
	z_index = 52   # above world/blood/swing FX, below the HUD
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _on_cue(event_id: String, payload: Dictionary) -> void:
	if event_id != "power.cast":
		return
	var origin: Vector2 = payload.get("origin", payload.get("pos", Vector2.ZERO))
	var target: Vector2 = payload.get("target_pos", origin)
	var col := _parse_color(String(payload.get("color", "#c01028")))
	var arch := String(payload.get("archetype", "NOVA"))
	_serial += 1
	_fx.append({
		"arch": arch,
		"origin": origin,
		"target": target,
		"col": col,
		"rng": float(payload.get("range", 0.0)),
		"rad": float(payload.get("radius", 0.0)),
		"arc": float(payload.get("arc", 0.0)),
		"aim": float(payload.get("aim_dir", 0.0)),
		"age": 0.0,
		"dur": _duration_for(arch),
		"seed": (int(origin.x) * 73856093) ^ (int(origin.y) * 19349663) ^ (_serial * 83492791),
	})
	if _fx.size() > MAX_FX:
		_fx.remove_at(0)
	_was_active = true
	queue_redraw()


func _duration_for(arch: String) -> float:
	match arch:
		"PROJECTILE": return 0.36
		"DASH": return 0.30
		"CONE": return 0.40
		"DEBUFF": return 0.70
		"SELF_BUFF": return 0.85
		"GROUND_AOE": return 0.70
		"TETHER": return 0.45
		"ENTITY_TARGET": return 0.42
		_: return 0.55   # NOVA


func _process(delta: float) -> void:
	if _fx.is_empty():
		if _was_active:
			_was_active = false
			queue_redraw()   # one final frame to clear the last effect
		return
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i]["age"] += delta
		if _fx[i]["age"] >= _fx[i]["dur"]:
			_fx.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for e in _fx:
		var t: float = clampf(e["age"] / e["dur"], 0.0, 1.0)
		match e["arch"]:
			"PROJECTILE": _draw_projectile(e, t)
			"NOVA": _draw_nova(e, t)
			"GROUND_AOE": _draw_ground_aoe(e, t)
			"CONE": _draw_cone(e, t)
			"ENTITY_TARGET": _draw_beam(e, t)
			"DEBUFF": _draw_debuff(e, t)
			"DASH": _draw_dash(e, t)
			"TETHER": _draw_tether(e, t)
			_: _draw_self_buff(e, t)   # SELF_BUFF


# --- per-archetype renderers (each visually unmistakable) ---

## A tapered blood lance racing from caster to the aimed point, with a muzzle burst.
func _draw_projectile(e: Dictionary, t: float) -> void:
	var o: Vector2 = e["origin"]
	var dir: Vector2 = (e["target"] - o)
	if dir.length() < 1.0:
		dir = Vector2.RIGHT.rotated(e["aim"]) * 220.0
	var col: Color = e["col"]
	var reach: float = _ease_out(minf(t / 0.7, 1.0))
	var tip: Vector2 = o + dir * reach
	var fade: float = 1.0 - t
	# three offset ribbons -> a thick tapered streak, not a line
	var perp: Vector2 = dir.normalized().orthogonal()
	for k in range(3):
		var w: float = (3.0 - float(k)) * 1.4
		var off: Vector2 = perp * float(k - 1) * 2.4
		draw_line(o + off, tip + off, Color(col, fade * (0.85 - 0.2 * k)), w)
	# muzzle burst at the origin (short radial shards)
	if t < 0.45:
		var mb: float = 1.0 - t / 0.45
		for k in range(6):
			var a: float = TAU * float(k) / 6.0 + _n(e["seed"], k)
			draw_line(o, o + Vector2.RIGHT.rotated(a) * (10.0 * mb), Color(col, mb * 0.7), 1.6)
	# leading impact spark at the tip
	draw_circle(tip, 4.0 * fade + 1.0, Color(1, 1, 1, fade * 0.9))


## A ragged expanding shock plus radial spikes from the caster (never a clean circle).
func _draw_nova(e: Dictionary, t: float) -> void:
	var o: Vector2 = e["origin"]
	var col: Color = e["col"]
	var maxr: float = maxf(e["rad"], 120.0)
	# anticipation: a quick inward gather
	if t < 0.18:
		var g: float = 1.0 - t / 0.18
		draw_arc(o, 26.0 * g + 6.0, 0, TAU, 24, Color(col, 0.5 * g), 2.0)
	var r: float = _ease_out(t) * maxr
	var fade: float = 1.0 - t
	# broken ring: arcs with gaps
	for k in range(7):
		var a0: float = TAU * float(k) / 7.0 + _n(e["seed"], k) * 0.3
		draw_arc(o, r, a0, a0 + 0.62, 8, Color(col, fade * 0.8), 3.0 * fade + 1.0)
	# radial spikes
	var spikes: int = 9 + (e["seed"] & 3)
	for k in range(spikes):
		var a: float = TAU * float(k) / float(spikes) + _n(e["seed"], k + 11) * 0.2
		var len0: float = r * (0.78 + 0.28 * _n(e["seed"], k + 31))
		var inner: Vector2 = o + Vector2.RIGHT.rotated(a) * (r * 0.55)
		var outer: Vector2 = o + Vector2.RIGHT.rotated(a) * len0
		draw_line(inner, outer, Color(col, fade * 0.85), 2.2)


## A telegraphed slam at the target: snapping reticle -> jagged cracks + debris -> scorch.
func _draw_ground_aoe(e: Dictionary, t: float) -> void:
	var c: Vector2 = e["target"]
	var col: Color = e["col"]
	var rad: float = maxf(e["rad"], 70.0)
	# anticipation: a reticle that snaps inward onto the spot
	if t < 0.25:
		var p: float = t / 0.25
		var rr: float = rad * (1.6 - 0.6 * p)
		draw_arc(c, rr, 0, TAU, 28, Color(col, 0.35 + 0.3 * p), 1.5)
		return
	var u: float = (t - 0.25) / 0.75
	var fade: float = 1.0 - u
	# a low dust disc
	draw_circle(c, rad * (0.5 + 0.6 * _ease_out(u)), Color(col.r, col.g, col.b, fade * 0.12))
	# jagged radial cracks
	for k in range(8):
		var a: float = TAU * float(k) / 8.0 + _n(e["seed"], k) * 0.25
		var pts := PackedVector2Array()
		var steps := 4
		for s in range(steps + 1):
			var rr2: float = rad * (float(s) / float(steps)) * _ease_out(minf(u * 1.4, 1.0))
			var jit: float = (_n(e["seed"], k * 7 + s) - 0.5) * 10.0
			pts.append(c + Vector2.RIGHT.rotated(a) * rr2 + Vector2.RIGHT.rotated(a + PI * 0.5) * jit)
		if pts.size() >= 2:
			draw_polyline(pts, Color(0.05, 0.04, 0.05, fade * 0.85), 2.0)
			draw_polyline(pts, Color(col, fade * 0.5), 1.0)
	# flung debris
	for k in range(7):
		var a2: float = TAU * float(k) / 7.0 + _n(e["seed"], k + 50)
		var d: float = rad * (0.4 + 0.8 * u)
		draw_circle(c + Vector2.RIGHT.rotated(a2) * d, 2.0 * fade + 0.6, Color(0.1, 0.08, 0.09, fade))


## A frontal wedge that sweeps across its arc (mesmerize/dominate cone).
func _draw_cone(e: Dictionary, t: float) -> void:
	var o: Vector2 = e["origin"]
	var col: Color = e["col"]
	var half: float = maxf(e["arc"], 0.7)
	var reach: float = maxf(e["rad"], maxf(e["rng"], 130.0))
	var sweep: float = _ease_out(t)
	var fade: float = 1.0 - t * 0.8
	var poly := PackedVector2Array()
	poly.append(o)
	var seg := 12
	for s in range(seg + 1):
		var a: float = e["aim"] - half + (2.0 * half) * (float(s) / float(seg))
		poly.append(o + Vector2.RIGHT.rotated(a) * reach * sweep)
	draw_colored_polygon(poly, Color(col.r, col.g, col.b, fade * 0.16))
	# bright leading edge sweeping through the arc
	var edge: float = e["aim"] - half + (2.0 * half) * sweep
	draw_line(o, o + Vector2.RIGHT.rotated(edge) * reach * sweep, Color(col, fade * 0.8), 2.5)
	draw_arc(o, reach * sweep, e["aim"] - half, e["aim"] + half, 16, Color(col, fade * 0.6), 2.0)


## A taut, slightly wavering beam from caster to a locked target point, with an impact mark.
func _draw_beam(e: Dictionary, t: float) -> void:
	var o: Vector2 = e["origin"]
	var tg: Vector2 = e["target"]
	var col: Color = e["col"]
	var fade: float = 1.0 - t
	var n := 14
	var pts := PackedVector2Array()
	var perp: Vector2 = (tg - o).normalized().orthogonal()
	for s in range(n + 1):
		var f: float = float(s) / float(n)
		var w: float = sin(f * PI) * 6.0 * (1.0 - t) * sin(t * 22.0 + f * 8.0)
		pts.append(o.lerp(tg, f) + perp * w)
	draw_polyline(pts, Color(col, fade * 0.9), 2.6 * fade + 0.8)
	# impact mark (a small cross-burst) at the target
	for k in range(4):
		var a: float = PI * 0.25 + TAU * float(k) / 4.0
		draw_line(tg, tg + Vector2.RIGHT.rotated(a) * (8.0 * fade + 3.0), Color(1, 1, 1, fade * 0.8), 1.6)


## A cold sigil/brand that descends and shrinks onto a marked target, then lingers and pulses.
func _draw_debuff(e: Dictionary, t: float) -> void:
	var c: Vector2 = e["target"]
	# desaturated, cooled discipline color
	var base: Color = e["col"]
	var col := Color(base.r * 0.6 + 0.2, base.g * 0.6 + 0.25, base.b * 0.6 + 0.3, 1.0)
	if t < 0.4:
		var p: float = t / 0.4
		var r: float = 40.0 * (1.0 - p) + 14.0
		var rot: float = p * PI
		_draw_triangle(c, r, rot, Color(col, 0.5 + 0.5 * p))
		_draw_triangle(c, r, rot + PI, Color(col, 0.5 + 0.5 * p))
	else:
		var u: float = (t - 0.4) / 0.6
		var pulse: float = 0.6 + 0.4 * sin(u * 12.0)
		var fade: float = 1.0 - u
		_draw_triangle(c, 14.0, 0.0, Color(col, fade * pulse))
		_draw_triangle(c, 14.0, PI, Color(col, fade * pulse))
		draw_arc(c, 17.0, 0, TAU, 20, Color(col, fade * 0.5), 1.2)


## Hard directional speed streaks + a launch puff (the blink/lunge).
func _draw_dash(e: Dictionary, t: float) -> void:
	var o: Vector2 = e["origin"]
	var dir: Vector2 = Vector2.RIGHT.rotated(e["aim"])
	var col: Color = e["col"]
	var fade: float = 1.0 - t
	var perp: Vector2 = dir.orthogonal()
	for k in range(5):
		var off: Vector2 = perp * float(k - 2) * 5.0
		var l: float = (60.0 + 30.0 * _n(e["seed"], k)) * (0.5 + 0.5 * _ease_out(t))
		draw_line(o + off - dir * 6.0, o + off - dir * l, Color(col, fade * 0.6), 1.8)
	draw_circle(o, 9.0 * fade + 2.0, Color(col, fade * 0.4))


## A clawed, jagged tendril snapping out to grab a body and yank (the Tether telekinesis verb).
func _draw_tether(e: Dictionary, t: float) -> void:
	var o: Vector2 = e["origin"]
	var tg: Vector2 = e["target"]
	var col := Color(e["col"].r * 0.5, e["col"].g * 0.4, e["col"].b * 0.6, 1.0)   # darker, shadowy
	var reach: float = _ease_out(minf(t / 0.55, 1.0))
	var tip: Vector2 = o.lerp(tg, reach)
	var perp: Vector2 = (tg - o).normalized().orthogonal()
	var pts := PackedVector2Array()
	var n := 10
	for s in range(n + 1):
		var f: float = float(s) / float(n)
		var wob: float = (_n(e["seed"], s) - 0.5) * 16.0 * (1.0 - f)
		pts.append(o.lerp(tip, f) + perp * wob)
	draw_polyline(pts, Color(col, (1.0 - t) * 0.95), 3.0)
	# claw barbs near the tip
	if reach > 0.85:
		for k in range(3):
			var a: float = e["aim"] + (float(k) - 1.0) * 0.6
			draw_line(tip, tip + Vector2.RIGHT.rotated(a) * 12.0, Color(col, (1.0 - t)), 2.0)


## A body-hugging aura: rising motes + a brief overhead halo. Deliberately NO ground ring.
func _draw_self_buff(e: Dictionary, t: float) -> void:
	var o: Vector2 = e["origin"]
	var col: Color = e["col"]
	var fade: float = 1.0 - t
	# overhead halo arc (reads as "empowered", not "attack")
	draw_arc(o + Vector2(0, -22), 16.0 + 6.0 * sin(t * 6.0), PI * 1.15, PI * 1.85, 14, Color(col, fade * 0.7), 2.0)
	# rising motes around the body
	for k in range(8):
		var a: float = TAU * float(k) / 8.0 + _n(e["seed"], k) * 0.5
		var ph: float = fmod(t + _n(e["seed"], k + 20), 1.0)
		var rise: float = ph * 34.0
		var rr: float = 13.0 + 3.0 * sin(t * 8.0 + float(k))
		var p: Vector2 = o + Vector2.RIGHT.rotated(a) * rr - Vector2(0, rise)
		draw_circle(p, 1.8 * (1.0 - ph), Color(col, fade * (1.0 - ph) * 0.9))


# --- helpers ---

func _draw_triangle(c: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(3):
		pts.append(c + Vector2.RIGHT.rotated(rot + TAU * float(k) / 3.0) * r)
	pts.append(pts[0])
	draw_polyline(pts, col, 1.8)


func _ease_out(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - c) * (1.0 - c)


## Deterministic, presentation-only pseudo-noise in [0,1) — NEVER Sim.rng (keeps replays clean).
func _n(seed_val: int, i: int) -> float:
	var x: int = absi((seed_val * 1103515245 + i * 12345 + 1013904223))
	return float(x % 100003) / 100003.0


func _parse_color(hex: String) -> Color:
	if hex.is_empty():
		return Color("#c01028")
	return Color(hex)
