## WorldFXPainter.gd — world-space combat, ballistic debris, and reactive surface presentation.
##
## The simulation owns hits, projectile collision, AoE, statuses, knockback, and blood/fire
## state. This node makes that truth visible with render-rate pseudo-3D particles: fragments
## carry horizontal velocity, height, gravity, bounce, drag, and a ground shadow. It consumes
## CueBus only and therefore cannot perturb determinism.
extends Node2D

const MAX_FX := 96
const MAX_PARTICLES := 240
const MAX_SURFACES := 32

var _fx: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _surfaces: Array[Dictionary] = []
var _time: float = 0.0
var _serial: int = 1


func _draw() -> void:
	_draw_surfaces()
	_draw_reticle()
	for fx in _fx:
		_draw_fx(fx)
	_draw_particles()


func _draw_reticle() -> void:
	var m := get_global_mouse_position()
	var col := Color(0.72, 0.18, 0.23, 0.78)
	if Sim != null and Sim.player != null and not Sim.player.dead:
		draw_line(Sim.player.pos, m, Color(col.r, col.g, col.b, 0.10), 1.0, true)
	for k in range(4):
		var ang := TAU * float(k) / 4.0
		var d := Vector2.RIGHT.rotated(ang)
		var n := Vector2(-d.y, d.x)
		var inner := m + d * 7.0
		var outer := m + d * 13.0
		draw_line(inner, outer, col, 1.35, true)
		draw_line(outer, outer - n * 3.0, col, 1.35, true)


func _draw_fx(fx: Dictionary) -> void:
	var p := clampf(float(fx["t"]) / float(fx["dur"]), 0.0, 1.0)
	var a := 1.0 - p
	var pos: Vector2 = fx["pos"]
	match String(fx["type"]):
		"swing":
			var reach := float(fx["reach"]) * (0.88 + 0.24 * p)
			var rot := float(fx["rot"])
			var from := rot - 1.08 + p * 1.34
			var to := from + 0.88
			var col := Color(0.92, 0.89, 0.80, a * 0.82)
			draw_arc(pos, reach, from, to, 18, col, 4.2 * (1.0 - p) + 1.2, true)
			draw_arc(pos, reach * 0.78, from + 0.06, to - 0.04, 14, Color(col.r, col.g, col.b, a * 0.28), 1.4, true)
		"wake":
			var wd := Vector2.RIGHT.rotated(float(fx["rot"]))
			var wn := Vector2(-wd.y, wd.x)
			var wake_col: Color = fx["col"]
			var back := pos - wd * float(fx["reach"]) * p
			draw_colored_polygon(PackedVector2Array([pos - wn * 8.0, pos + wn * 8.0, back + wn * 18.0, back - wn * 18.0]), Color(wake_col.r, wake_col.g, wake_col.b, a * 0.10))
		"spark":
			var rad := 11.0 if bool(fx.get("crit", false)) else 6.5
			var spark_col: Color = fx["col"]
			draw_circle(pos, rad * (0.45 + p), Color(spark_col.r, spark_col.g, spark_col.b, a * 0.28))
			for k in range(7):
				var ang := TAU * float(k) / 7.0 + _noise_angle(int(pos.x * 7.0 + pos.y * 3.0))
				var d := rad + 16.0 * p
				draw_line(pos + Vector2.RIGHT.rotated(ang) * rad * 0.42, pos + Vector2.RIGHT.rotated(ang) * d, Color(spark_col.r, spark_col.g, spark_col.b, a * 0.62), 1.4, true)
		"shock":
			var sr := float(fx["rmax"]) * _smooth01(p)
			var shock_col: Color = fx["col"]
			for i in range(3):
				var start := float(i) * TAU / 3.0 + p * 0.28
				draw_arc(pos, sr, start, start + 1.72, 18, Color(shock_col.r, shock_col.g, shock_col.b, a * 0.66), 4.0 * (1.0 - p) + 1.0, true)
		"aoe":
			var ar := float(fx["rmax"]) * (0.35 + 0.65 * _smooth01(p))
			var aoe_col: Color = fx["col"]
			draw_circle(pos, ar, Color(aoe_col.r, aoe_col.g, aoe_col.b, a * 0.11))
			for i in range(5):
				var start2 := float(i) * TAU / 5.0 + p * 0.20
				draw_arc(pos, ar, start2, start2 + 0.82, 10, Color(aoe_col.r, aoe_col.g, aoe_col.b, a * 0.52), 1.8, true)
		"ring":
			var rr := float(fx["rmax"]) * _smooth01(p)
			var ring_col: Color = fx["col"]
			for i in range(4):
				var start3 := float(i) * TAU / 4.0 + 0.12
				draw_arc(pos, rr, start3, start3 + 1.08, 12, Color(ring_col.r, ring_col.g, ring_col.b, a * 0.62), 2.4, true)
		"cast":
			var cr := 28.0 * _smooth01(p)
			var cast_col: Color = fx["col"]
			draw_arc(pos, cr, -2.8, -0.35, 20, Color(cast_col.r, cast_col.g, cast_col.b, a * 0.66), 2.4 * (1.0 - p) + 0.8, true)


func _draw_particles() -> void:
	for particle in _particles:
		var age_ratio := clampf(float(particle["age"]) / float(particle["life"]), 0.0, 1.0)
		var alpha := 1.0 - _smooth01(age_ratio)
		var ground: Vector2 = particle["pos"]
		var z := float(particle.get("z", 0.0))
		var p := ground - Vector2(0.0, z)
		var size := float(particle["size"])
		var col: Color = particle["col"]
		var kind := String(particle["kind"])
		if z > 1.0:
			draw_set_transform(ground, 0.0, Vector2(1.3, 0.42))
			draw_circle(Vector2.ZERO, maxf(0.8, size * 0.55), Color(0, 0, 0, 0.16 * alpha))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		match kind:
			"shard":
				var vel: Vector2 = particle["vel"]
				var d := vel.normalized() if vel.length_squared() > 0.1 else Vector2.RIGHT
				var n := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([p + d * size * 1.4, p - d * size - n * size * 0.45, p - d * size + n * size * 0.45]), Color(col.r, col.g, col.b, alpha))
			"drop":
				var vel2: Vector2 = particle["vel"]
				var d2 := vel2.normalized() if vel2.length_squared() > 0.1 else Vector2.DOWN
				draw_line(p - d2 * size * 1.6, p + d2 * size * 0.3, Color(col.r, col.g, col.b, alpha), maxf(1.0, size * 0.72), true)
			"ember":
				draw_circle(p, size * (0.55 + sin(_time * 18.0 + float(particle["serial"])) * 0.12), Color(col.r, col.g, col.b, alpha))
				draw_circle(p, size * 0.28, Color(1.0, 0.78, 0.42, alpha * 0.82))
			"mist", "smoke":
				draw_circle(p, size * (0.75 + age_ratio * 0.85), Color(col.r, col.g, col.b, alpha * 0.14))
				draw_arc(p, size * (0.55 + age_ratio), 0.2, 3.9, 10, Color(col.r, col.g, col.b, alpha * 0.20), 1.0, true)


func _draw_surfaces() -> void:
	for surface in _surfaces:
		var p := clampf(float(surface["age"]) / float(surface["life"]), 0.0, 1.0)
		var fade := minf(_smooth01(p / 0.12), 1.0 - _smooth01((p - 0.72) / 0.28))
		var pos: Vector2 = surface["pos"]
		var radius := float(surface["radius"]) * (0.76 + 0.24 * _smooth01(minf(p * 2.0, 1.0)))
		var seed := int(surface["seed"])
		match String(surface["type"]):
			"fire", "burn":
				draw_circle(pos, radius, Color(0.32, 0.12, 0.04, 0.10 * fade))
				for i in range(11):
					var a := _noise_angle(seed + i * 17)
					var dist := radius * sqrt(_noise01(seed + i * 19 + 3))
					var base := pos + Vector2.RIGHT.rotated(a) * dist
					var lick := (5.0 + 10.0 * _noise01(seed + i * 23)) * (0.55 + 0.45 * sin(_time * 8.0 + float(i)))
					draw_line(base, base + Vector2(_noise01(seed + i) * 4.0 - 2.0, -lick), Color(0.76, 0.31, 0.09, 0.45 * fade), 2.0, true)
			"poison", "toxic":
				draw_circle(pos, radius, Color(0.25, 0.38, 0.19, 0.12 * fade))
				for i in range(5):
					var a2 := _noise_angle(seed + i * 31) + _time * (0.08 + float(i) * 0.01)
					var rr := radius * (0.32 + float(i) * 0.12)
					draw_arc(pos, rr, a2, a2 + 1.30, 12, Color(0.46, 0.61, 0.32, 0.25 * fade), 1.2, true)
			_:
				draw_circle(pos, radius, Color(0.42, 0.08, 0.12, 0.08 * fade))


func _facing_of(id: int) -> float:
	if Sim == null or id == 0:
		return 0.0
	var e: SimEntity = Sim.get_entity(id) as SimEntity
	return e.facing if e != null else 0.0


func _damage_color(damage_type: String) -> Color:
	match damage_type:
		"blood", "bleed":
			return Color("#9f1c35")
		"fire", "burn":
			return Color("#b65c29")
		"poison":
			return Color("#66844b")
		"shock":
			return Color("#719ab8")
		"shadow":
			return Color("#6c5480")
	return Color("#b7ab96")


func _smooth01(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _noise01(seed: int) -> float:
	var value := sin(float(seed) * 12.9898 + 78.233) * 43758.5453
	return value - floor(value)


func _noise_angle(seed: int) -> float:
	return _noise01(seed) * TAU
