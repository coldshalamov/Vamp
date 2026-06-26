## WorldFX.gd — cinematic world-space combat, projectile, and discipline effects.
##
## CPU-pooled and draw-call bounded. Effects are procedural and continuously animated; they do
## not depend on short sprite loops. This node remains a read-only CueBus subscriber.
extends Node2D
class_name WorldFX

const MAX_EFFECTS := 96
const MAX_PARTICLES := 280
const LOW_FPS_THRESHOLD := 46

var _effects: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _seed: int = 0x5EED123
var _quality: float = 1.0
var _quality_timer: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	z_index = 50
	if CueBus != null and not CueBus.cue_emitted.is_connected(_on_cue):
		CueBus.cue_emitted.connect(_on_cue)


func _on_cue(event_id: String, payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	match event_id:
		"attack.start":
			_add_effect({
				"kind": "slash", "pos": pos, "rot": _facing_of(int(payload.get("entity_id", 0))),
				"age": 0.0, "life": 0.25, "reach": 43.0, "heavy": bool(payload.get("heavy", false)),
			})
		"damage.dealt", "hit.connect":
			var crit := bool(payload.get("crit", false))
			var dtype := String(payload.get("damage_type", "physical"))
			_add_hit(pos, dtype, crit, false)
		"damage.player":
			_add_hit(pos, String(payload.get("damage_type", "physical")), false, true)
		"projectile.spawn":
			_add_effect({"kind": "projectile_wake", "pos": pos, "age": 0.0, "life": 0.16, "entity_id": int(payload.get("entity_id", 0))})
		"projectile.bounce":
			_add_effect({"kind": "ground_kiss", "pos": pos, "age": 0.0, "life": 0.20, "color": Color("#d4a96d")})
			_emit_sparks(pos, Color("#d4a96d"), 5, 54.0)
		"projectile.explode", "projectile.aoe":
			var dtype2 := String(payload.get("damage_type", "fire"))
			var radius := float(payload.get("radius", 86.0))
			_add_explosion(pos, radius, dtype2)
		"projectile.end":
			_add_effect({"kind": "fade_pop", "pos": pos, "age": 0.0, "life": 0.20, "color": Color("#b8263c")})
		"power.cast":
			_add_power_cast(String(payload.get("power_id", "")), pos)
		"power.potence.quake_hit":
			_add_shock(pos, 190.0, Color("#d67a35"), 0.62)
		"power.potence.hit":
			_add_shock(pos, 110.0, Color("#d67a35"), 0.40)
		"power.potence.charge_hit":
			_add_shock(pos, 70.0, Color("#e0a34a"), 0.34)
		"player.heal", "feed.gulp.perfect":
			_add_effect({"kind": "helix", "pos": pos, "age": 0.0, "life": 0.55, "color": Color("#79d49a"), "radius": 34.0})
		"blood.drink":
			_add_effect({"kind": "siphon", "pos": pos, "age": 0.0, "life": 0.42, "color": Color("#a81831"), "radius": 26.0})
		"blood.command":
			_add_effect({"kind": "blood_rune", "pos": pos, "age": 0.0, "life": 0.58, "color": Color("#ad1028"), "radius": 56.0})
		"player.respawn":
			_add_shock(pos, 94.0, Color("#8b68c7"), 0.68)
		"player.level_up":
			_add_shock(pos, 100.0, Color("#e8c45e"), 0.74)
		"status.burn":
			_emit_embers(pos, 7)
		"status.bleed":
			_emit_blood(pos, Vector2.ZERO, 4, false)


func _add_hit(pos: Vector2, damage_type: String, crit: bool, player_hit: bool) -> void:
	var color := _damage_color(damage_type)
	if player_hit:
		color = Color("#ff4e55")
	_add_effect({
		"kind": "impact", "pos": pos, "age": 0.0, "life": 0.22 if not crit else 0.31,
		"color": color, "crit": crit,
	})
	_emit_sparks(pos, color, 6 if not crit else 13, 95.0 if not crit else 145.0)
	if damage_type in ["physical", "blood", "bleed"]:
		_emit_blood(pos, Vector2.ZERO, 5 if not crit else 10, crit)


func _add_explosion(pos: Vector2, radius: float, damage_type: String) -> void:
	var color := _damage_color(damage_type)
	_add_effect({"kind": "explosion", "pos": pos, "age": 0.0, "life": 0.72, "radius": radius, "color": color})
	_add_effect({"kind": "shock", "pos": pos, "age": 0.0, "life": 0.56, "radius": radius * 1.12, "color": color})
	if damage_type == "fire":
		_emit_embers(pos, 26)
		_emit_smoke(pos, 11)
	elif damage_type == "poison":
		_emit_motes(pos, Color("#6ea543"), 22, 82.0)
	else:
		_emit_sparks(pos, color, 20, 170.0)


func _add_power_cast(power_id: String, pos: Vector2) -> void:
	var prefix := power_id.split("_")[0] if power_id.contains("_") else power_id
	var color := _discipline_color(prefix)
	match prefix:
		"pot":
			_add_effect({"kind": "ground_crack", "pos": pos, "age": 0.0, "life": 0.48, "color": color, "radius": 74.0})
		"cel":
			_add_effect({"kind": "speed_ring", "pos": pos, "age": 0.0, "life": 0.34, "color": color, "radius": 48.0})
		"obf":
			_add_effect({"kind": "veil", "pos": pos, "age": 0.0, "life": 0.72, "color": color, "radius": 52.0})
		"aus":
			_add_effect({"kind": "eye_wave", "pos": pos, "age": 0.0, "life": 0.62, "color": color, "radius": 92.0})
		"dom", "pre":
			_add_effect({"kind": "command_wave", "pos": pos, "age": 0.0, "life": 0.58, "color": color, "radius": 88.0})
		"bs":
			_add_effect({"kind": "blood_rune", "pos": pos, "age": 0.0, "life": 0.62, "color": color, "radius": 62.0})
		"shd":
			_add_effect({"kind": "shadow_tendrils", "pos": pos, "age": 0.0, "life": 0.78, "color": color, "radius": 72.0})
		_:
			_add_effect({"kind": "cast_ring", "pos": pos, "age": 0.0, "life": 0.38, "color": color, "radius": 42.0})


func _add_shock(pos: Vector2, radius: float, color: Color, life: float) -> void:
	_add_effect({"kind": "shock", "pos": pos, "age": 0.0, "life": life, "radius": radius, "color": color})
	_emit_sparks(pos, color, 10, radius * 0.75)


func _add_effect(effect: Dictionary) -> void:
	_effects.append(effect)
	if _effects.size() > MAX_EFFECTS:
		_effects.pop_front()


func _process(delta: float) -> void:
	_time += delta
	_quality_timer += delta
	if _quality_timer >= 0.75:
		_quality_timer = 0.0
		var fps := Engine.get_frames_per_second()
		var target := 0.58 if fps > 0 and fps < LOW_FPS_THRESHOLD else 1.0
		_quality = lerpf(_quality, target, 0.35)

	for i in range(_effects.size() - 1, -1, -1):
		_effects[i]["age"] = float(_effects[i]["age"]) + delta
		if float(_effects[i]["age"]) >= float(_effects[i]["life"]):
			_effects.remove_at(i)

	for i in range(_particles.size() - 1, -1, -1):
		var p := _particles[i]
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= float(p["life"]):
			_particles.remove_at(i)
			continue
		var vel: Vector2 = p["vel"]
		vel.y += float(p.get("gravity", 0.0)) * delta
		vel *= pow(float(p.get("drag", 1.0)), delta * 60.0)
		p["vel"] = vel
		var particle_pos: Vector2 = p["pos"]
		p["pos"] = particle_pos + vel * delta
		if p.has("height"):
			p["height"] = maxf(0.0, float(p["height"]) + float(p.get("vertical_velocity", 0.0)) * delta)
			p["vertical_velocity"] = float(p.get("vertical_velocity", 0.0)) - float(p.get("vertical_gravity", 0.0)) * delta
		_particles[i] = p
	queue_redraw()


func _draw() -> void:
	for effect in _effects:
		_draw_effect(effect)
	for particle in _particles:
		_draw_particle(particle)


func _draw_effect(fx: Dictionary) -> void:
	var age := float(fx["age"])
	var life := maxf(float(fx["life"]), 0.001)
	var p := clampf(age / life, 0.0, 1.0)
	var fade := 1.0 - p
	var pos: Vector2 = fx["pos"]
	var color: Color = fx.get("color", Color.WHITE)
	match String(fx["kind"]):
		"slash":
			var rot := float(fx.get("rot", 0.0))
			var reach := float(fx.get("reach", 42.0)) * (0.80 + p * 0.32)
			var sweep := rot - 1.18 + p * 1.55
			var width := (7.0 if bool(fx.get("heavy", false)) else 4.5) * fade + 1.0
			draw_arc(pos, reach, sweep, sweep + 0.92, 20, Color(0.95, 0.96, 1.0, fade * 0.82), width, true)
			draw_arc(pos, reach * 0.77, sweep + 0.08, sweep + 0.86, 18, Color(0.62, 0.67, 0.76, fade * 0.34), 1.4, true)
		"impact":
			var crit := bool(fx.get("crit", false))
			var radius := (15.0 if crit else 9.0) * (0.35 + p)
			_draw_ellipse(pos, Vector2(radius, radius * 0.72), _alpha(color, fade * 0.22), 18)
			for k in range(5 if not crit else 9):
				var a := TAU * float(k) / float(5 if not crit else 9) + float(int(pos.x + pos.y)) * 0.07
				var inner := Vector2.RIGHT.rotated(a) * radius * 0.30
				var outer := Vector2.RIGHT.rotated(a) * radius * (0.8 + p * 0.65)
				draw_line(pos + inner, pos + outer, _alpha(color, fade * 0.76), 1.7 if not crit else 2.3, true)
		"shock":
			var radius2 := float(fx.get("radius", 90.0)) * _ease(p)
			draw_arc(pos, radius2, 0.0, TAU, 48, _alpha(color, fade * 0.70), 5.5 * fade + 1.0, true)
			draw_arc(pos, radius2 * 0.73, 0.0, TAU, 42, _alpha(color, fade * 0.25), 1.4, true)
		"explosion":
			var max_r := float(fx.get("radius", 84.0))
			var core_r := max_r * (0.12 + 0.52 * sin(minf(p, 0.5) * PI))
			_draw_ellipse(pos, Vector2(core_r, core_r * 0.72), _alpha(color.lightened(0.26), fade * 0.58), 28)
			_draw_ellipse(pos, Vector2(core_r * 0.62, core_r * 0.48), _alpha(Color("#fff0c4"), fade * 0.72), 24)
		"ground_kiss":
			var r := 14.0 * p
			draw_arc(pos, r, PI, TAU, 18, _alpha(color, fade * 0.60), 1.8, true)
		"fade_pop":
			var r2 := 18.0 * p
			draw_arc(pos, r2, 0.0, TAU, 20, _alpha(color, fade * 0.55), 1.5, true)
		"cast_ring":
			_draw_cast_ring(pos, p, fade, float(fx.get("radius", 42.0)), color, 0)
		"speed_ring":
			_draw_cast_ring(pos, p, fade, float(fx.get("radius", 48.0)), color, 3)
		"command_wave":
			var rr := float(fx.get("radius", 88.0)) * _ease(p)
			draw_arc(pos, rr, -1.15, 1.15, 30, _alpha(color, fade * 0.55), 2.1, true)
			draw_arc(pos, rr * 0.72, -0.95, 0.95, 26, _alpha(color, fade * 0.28), 1.2, true)
		"eye_wave":
			var er := float(fx.get("radius", 92.0)) * _ease(p)
			draw_arc(pos, er, -0.55, 0.55, 24, _alpha(color, fade * 0.62), 2.0, true)
			draw_arc(pos, er, PI - 0.55, PI + 0.55, 24, _alpha(color, fade * 0.62), 2.0, true)
			_draw_ellipse(pos, Vector2(er * 0.15, er * 0.09), _alpha(color, fade * 0.28), 18)
		"veil":
			var vr := float(fx.get("radius", 52.0)) * (0.45 + p * 0.55)
			for k in range(4):
				var offset := Vector2(cos(_time * 1.2 + k * 1.7), sin(_time * 0.8 + k * 2.0)) * vr * 0.18
				_draw_ellipse(pos + offset, Vector2(vr * 0.68, vr * 0.32), _alpha(color, fade * 0.045), 24)
		"blood_rune":
			_draw_blood_rune(pos, p, fade, float(fx.get("radius", 58.0)), color)
		"ground_crack":
			_draw_ground_crack(pos, p, fade, float(fx.get("radius", 74.0)), color)
		"shadow_tendrils":
			_draw_tendrils(pos, p, fade, float(fx.get("radius", 72.0)), color)
		"helix":
			_draw_helix(pos, p, fade, float(fx.get("radius", 34.0)), color)
		"siphon":
			_draw_siphon(pos, p, fade, float(fx.get("radius", 26.0)), color)
		"projectile_wake":
			var entity := _entity_by_id(int(fx.get("entity_id", 0)))
			if entity != null:
				draw_line(pos, entity.pos, Color(0.7, 0.08, 0.16, fade * 0.25), 2.0, true)


func _draw_particle(particle: Dictionary) -> void:
	var age := float(particle["age"])
	var life := maxf(float(particle["life"]), 0.001)
	var t := clampf(age / life, 0.0, 1.0)
	var fade := 1.0 - t
	var pos: Vector2 = particle["pos"]
	if particle.has("height"):
		pos.y -= float(particle["height"]) * 0.78
	var color: Color = particle["color"]
	var size := float(particle.get("size", 2.0))
	match String(particle.get("kind", "spark")):
		"spark":
			var vel: Vector2 = particle["vel"]
			var dir := vel.normalized() if vel.length_squared() > 0.1 else Vector2.RIGHT
			draw_line(pos - dir * size * 2.8, pos + dir * size * 0.5, _alpha(color, fade * 0.82), maxf(0.7, size * fade), true)
		"blood":
			_draw_ellipse(pos, Vector2(size * (0.6 + t), size * 0.42), _alpha(color, fade * 0.72), 10)
		"ember":
			draw_line(pos + Vector2(0, size), pos - Vector2(0, size * 1.8), _alpha(color, fade * 0.88), maxf(0.7, size * fade), true)
		"smoke":
			var rr := size * (0.55 + t * 1.45)
			_draw_ellipse(pos, Vector2(rr, rr * 0.66), _alpha(color, fade * 0.16), 16)
		"mote":
			_draw_ellipse(pos, Vector2(size, size * 0.62), _alpha(color, fade * 0.36), 12)


func _draw_cast_ring(pos: Vector2, p: float, fade: float, radius: float, color: Color, spokes: int) -> void:
	var r := radius * _ease(p)
	draw_arc(pos, r, 0.0, TAU, 36, _alpha(color, fade * 0.62), 2.2, true)
	if spokes > 0:
		for k in range(spokes):
			var a := TAU * float(k) / float(spokes) + p * 0.9
			draw_line(pos + Vector2.RIGHT.rotated(a) * r * 0.35, pos + Vector2.RIGHT.rotated(a) * r, _alpha(color, fade * 0.34), 1.2, true)


func _draw_blood_rune(pos: Vector2, p: float, fade: float, radius: float, color: Color) -> void:
	var r := radius * (0.45 + 0.55 * _ease(p))
	draw_arc(pos, r, 0.0, TAU, 42, _alpha(color, fade * 0.52), 2.0, true)
	for k in range(6):
		var a := TAU * float(k) / 6.0 + p * 0.55
		var a2 := a + 2.1
		draw_line(pos + Vector2.RIGHT.rotated(a) * r * 0.28, pos + Vector2.RIGHT.rotated(a2) * r * 0.82, _alpha(color, fade * 0.35), 1.1, true)


func _draw_ground_crack(pos: Vector2, p: float, fade: float, radius: float, color: Color) -> void:
	for k in range(10):
		var a := TAU * float(k) / 10.0 + float(int(pos.x)) * 0.013
		var start := pos + Vector2.RIGHT.rotated(a) * radius * 0.12
		var mid := pos + Vector2.RIGHT.rotated(a + sin(float(k)) * 0.12) * radius * (0.32 + 0.18 * p)
		var end := pos + Vector2.RIGHT.rotated(a - cos(float(k)) * 0.10) * radius * _ease(p)
		draw_polyline(PackedVector2Array([start, mid, end]), _alpha(color, fade * 0.54), 1.5, true)


func _draw_tendrils(pos: Vector2, p: float, fade: float, radius: float, color: Color) -> void:
	for k in range(7):
		var a := TAU * float(k) / 7.0 + float(k % 2) * 0.22
		var pts: Array[Vector2] = [pos]
		for s in range(1, 5):
			var q := float(s) / 4.0
			var wobble := sin(_time * 4.0 + float(k * 3 + s)) * 0.15 * q
			pts.append(pos + Vector2.RIGHT.rotated(a + wobble) * radius * q * _ease(p))
		draw_polyline(PackedVector2Array(pts), _alpha(color, fade * 0.34), 3.2 * (1.0 - p) + 0.8, true)


func _draw_helix(pos: Vector2, p: float, fade: float, radius: float, color: Color) -> void:
	for strand in [-1.0, 1.0]:
		var pts: Array[Vector2] = []
		for i in range(18):
			var q := float(i) / 17.0
			var a: float = q * TAU * 1.8 + strand * PI * 0.5 + p * 2.5
			pts.append(pos + Vector2(cos(a) * radius * (1.0 - q) * 0.45, -q * radius * 1.25))
		draw_polyline(PackedVector2Array(pts), _alpha(color, fade * 0.48), 1.4, true)


func _draw_siphon(pos: Vector2, p: float, fade: float, radius: float, color: Color) -> void:
	for k in range(5):
		var a := TAU * float(k) / 5.0 + p * 1.8
		var outer := pos + Vector2.RIGHT.rotated(a) * radius * (1.0 - p * 0.55)
		var inner := pos + Vector2(0, -14.0 * p)
		draw_line(outer, inner, _alpha(color, fade * 0.42), 1.5, true)


func _emit_sparks(pos: Vector2, color: Color, count: int, speed: float) -> void:
	var actual := maxi(1, int(float(count) * _quality))
	for i in range(actual):
		var a := _rand_range(0.0, TAU)
		var s := _rand_range(speed * 0.45, speed)
		_add_particle({
			"kind": "spark", "pos": pos, "vel": Vector2.RIGHT.rotated(a) * s,
			"age": 0.0, "life": _rand_range(0.12, 0.31), "color": color,
			"size": _rand_range(0.8, 1.9), "gravity": 88.0, "drag": 0.94,
		})


func _emit_blood(pos: Vector2, bias: Vector2, count: int, heavy: bool) -> void:
	var actual := maxi(1, int(float(count) * _quality))
	for i in range(actual):
		var a := _rand_range(-PI, PI)
		var speed := _rand_range(32.0, 105.0 if heavy else 72.0)
		_add_particle({
			"kind": "blood", "pos": pos, "vel": bias + Vector2.RIGHT.rotated(a) * speed,
			"age": 0.0, "life": _rand_range(0.22, 0.48), "color": Color("#8f1026"),
			"size": _rand_range(1.2, 2.7), "gravity": 145.0, "drag": 0.93,
			"height": _rand_range(4.0, 13.0), "vertical_velocity": _rand_range(28.0, 70.0), "vertical_gravity": 135.0,
		})


func _emit_embers(pos: Vector2, count: int) -> void:
	var actual := maxi(1, int(float(count) * _quality))
	for i in range(actual):
		var a := _rand_range(-PI, PI)
		_add_particle({
			"kind": "ember", "pos": pos, "vel": Vector2.RIGHT.rotated(a) * _rand_range(18.0, 95.0) + Vector2(0, -34.0),
			"age": 0.0, "life": _rand_range(0.35, 0.92), "color": Color("#ff8f2d"),
			"size": _rand_range(1.0, 2.2), "gravity": -18.0, "drag": 0.97,
		})


func _emit_smoke(pos: Vector2, count: int) -> void:
	var actual := maxi(1, int(float(count) * _quality))
	for i in range(actual):
		_add_particle({
			"kind": "smoke", "pos": pos + Vector2(_rand_range(-12.0, 12.0), _rand_range(-6.0, 4.0)),
			"vel": Vector2(_rand_range(-14.0, 14.0), _rand_range(-48.0, -18.0)),
			"age": 0.0, "life": _rand_range(0.60, 1.35), "color": Color("#2b2528"),
			"size": _rand_range(5.0, 11.0), "gravity": -4.0, "drag": 0.985,
		})


func _emit_motes(pos: Vector2, color: Color, count: int, speed: float) -> void:
	var actual := maxi(1, int(float(count) * _quality))
	for i in range(actual):
		var a := _rand_range(0.0, TAU)
		_add_particle({
			"kind": "mote", "pos": pos, "vel": Vector2.RIGHT.rotated(a) * _rand_range(speed * 0.25, speed),
			"age": 0.0, "life": _rand_range(0.45, 1.0), "color": color,
			"size": _rand_range(1.8, 4.5), "gravity": -10.0, "drag": 0.97,
		})


func _add_particle(particle: Dictionary) -> void:
	_particles.append(particle)
	if _particles.size() > MAX_PARTICLES:
		_particles.pop_front()


func _facing_of(id: int) -> float:
	var e := _entity_by_id(id)
	return e.facing if e != null else 0.0


func _entity_by_id(id: int) -> SimEntity:
	if Sim == null or id <= 0:
		return null
	return Sim.get_entity(id) as SimEntity


func _damage_color(damage_type: String) -> Color:
	match damage_type:
		"blood", "bleed": return Color("#b51b37")
		"fire", "burn": return Color("#e4772c")
		"poison": return Color("#6b9b3b")
		"shock": return Color("#78bde0")
		"sun": return Color("#f0d797")
		"shadow": return Color("#735a98")
	return Color("#e0d6c4")


func _discipline_color(prefix: String) -> Color:
	match prefix:
		"cel": return Color("#7fbad6")
		"pot": return Color("#c66f32")
		"for": return Color("#6da782")
		"obf": return Color("#77678c")
		"aus": return Color("#91b7c8")
		"dom": return Color("#9b75b8")
		"pre": return Color("#c7a651")
		"bs": return Color("#a50d28")
		"pro": return Color("#718252")
		"shd": return Color("#58486f")
	return Color("#a4112a")


func _rand_u32() -> int:
	_seed = int((_seed ^ (_seed << 13)) & 0x7fffffff)
	_seed = int((_seed ^ (_seed >> 17)) & 0x7fffffff)
	_seed = int((_seed ^ (_seed << 5)) & 0x7fffffff)
	return _seed


func _rand_range(lo: float, hi: float) -> float:
	var unit := float(_rand_u32() & 0xffff) / 65535.0
	return lerpf(lo, hi, unit)


func _ease(v: float) -> float:
	var x := clampf(v, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color, segments: int) -> void:
	var pts: Array[Vector2] = []
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(PackedVector2Array(pts), color)
