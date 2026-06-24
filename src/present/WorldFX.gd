## WorldFX.gd — transient world-space combat, projectile, and spell visuals.
##
## Effects are semantic-cue driven and deterministic in layout: no random calls, no gameplay state.
## The visual layer can therefore be lavish without contaminating replay/state hashes.
extends Node2D
class_name WorldFX

const MAX_FX := 144
var _fx: Array[Dictionary] = []


func _ready() -> void:
	z_index = 50
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _on_cue(event_id: String, payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	match event_id:
		"attack.start":
			_add({"type": "swing", "pos": pos, "rot": _facing_of(int(payload.get("entity_id", 0))), "t": 0.0, "dur": 0.24, "reach": 42.0})
		"damage.dealt":
			_add({"type": "spark", "pos": pos, "t": 0.0, "dur": 0.22, "col": Color("ffd2a0"), "crit": bool(payload.get("crit", false))})
		"damage.player":
			_add({"type": "spark", "pos": pos, "t": 0.0, "dur": 0.22, "col": Color("ff5a5a"), "crit": false})
		"power.cast":
			_on_power_cast(String(payload.get("power_id", "")), pos)
		"power.potence.quake_hit":
			_add({"type": "shock", "pos": pos, "t": 0.0, "dur": 0.50, "rmax": 190.0, "col": Color("e0883a")})
		"power.potence.hit":
			_add({"type": "shock", "pos": pos, "t": 0.0, "dur": 0.36, "rmax": 105.0, "col": Color("e0883a")})
		"power.potence.charge_hit":
			_add({"type": "shock", "pos": pos, "t": 0.0, "dur": 0.30, "rmax": 60.0, "col": Color("e0a040")})
		"player.heal", "feed.gulp.perfect":
			_add({"type": "ring", "pos": pos, "t": 0.0, "dur": 0.40, "rmax": 36.0, "col": Color("7fe0a0")})
		"blood.drink":
			_add({"type": "ring", "pos": pos, "t": 0.0, "dur": 0.32, "rmax": 22.0, "col": Color("c0304a")})
		"blood.command":
			_add({"type": "ring", "pos": pos, "t": 0.0, "dur": 0.30, "rmax": 52.0, "col": Color("c01028")})
			_add({"type": "aoe", "pos": pos, "t": 0.0, "dur": 0.25, "rmax": 44.0, "col": Color("9a0c20")})
		"projectile.bounce":
			_add({"type": "bounce", "pos": pos, "t": 0.0, "dur": 0.22, "col": Color("ffd08a"), "seed": int(payload.get("entity_id", 0)) + int(payload.get("bounce", 0)) * 17})
		"projectile.explode":
			_on_projectile_explode(payload)
		"projectile.aoe":
			_add({"type": "spark", "pos": pos, "t": 0.0, "dur": 0.24, "col": _damage_color(String(payload.get("damage_type", "physical"))), "crit": false})
		"player.respawn":
			_add({"type": "shock", "pos": pos, "t": 0.0, "dur": 0.60, "rmax": 90.0, "col": Color("9a6fff")})
		"player.level_up":
			if Sim != null and Sim.player != null:
				_add({"type": "shock", "pos": Sim.player.pos, "t": 0.0, "dur": 0.70, "rmax": 95.0, "col": Color("f0c040")})
				_add({"type": "ring", "pos": Sim.player.pos, "t": 0.0, "dur": 0.50, "rmax": 60.0, "col": Color("ffe080")})
		_:
			pass


func _on_power_cast(power_id: String, pos: Vector2) -> void:
	match power_id:
		"pot_quake":
			_add({"type": "shock", "pos": pos, "t": 0.0, "dur": 0.50, "rmax": 190.0, "col": Color("e0883a")})
		"pot_slam", "pot_charge":
			_add({"type": "shock", "pos": pos, "t": 0.0, "dur": 0.36, "rmax": 105.0, "col": Color("e0883a")})
		"bs_storm", "bs_cauldron":
			_add({"type": "aoe", "pos": pos, "t": 0.0, "dur": 0.70, "rmax": 120.0, "col": Color("c01028")})
		"cel_dash", "cel_haste", "cel_flurry":
			_add({"type": "ring", "pos": pos, "t": 0.0, "dur": 0.30, "rmax": 44.0, "col": Color("8fd6ff")})
		"pre_dread", "pre_majesty", "dom_command", "dom_mesmer":
			_add({"type": "ring", "pos": pos, "t": 0.0, "dur": 0.50, "rmax": 80.0, "col": Color("b98cff")})
		_:
			_add({"type": "cast", "pos": pos, "t": 0.0, "dur": 0.30, "col": Color("c01028")})


func _on_projectile_explode(payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	var radius := maxf(24.0, float(payload.get("radius", 42.0)))
	var damage_type := String(payload.get("damage_type", "physical"))
	var status := String(payload.get("status", ""))
	var surface := String(payload.get("surface_effect", ""))
	var col := _damage_color(damage_type)
	var seed := int(payload.get("entity_id", 0)) * 31 + int(payload.get("bounces", 0)) * 7
	_add({"type": "shock", "pos": pos, "t": 0.0, "dur": 0.42, "rmax": radius, "col": col})
	_add({"type": "shards", "pos": pos, "t": 0.0, "dur": 0.52, "rmax": radius * 0.72, "col": col.lightened(0.20), "seed": seed})
	if surface == "fire" or damage_type == "fire":
		_add({"type": "cloud", "pos": pos, "t": 0.0, "dur": 0.72, "rmax": radius * 0.72, "col": Color("f06a2d"), "seed": seed, "hot": true})
	elif status == "poison" or damage_type == "poison":
		_add({"type": "cloud", "pos": pos, "t": 0.0, "dur": 1.05, "rmax": radius, "col": Color("65b968"), "seed": seed, "hot": false})
	elif damage_type == "blood" or surface == "blood":
		_add({"type": "splash", "pos": pos, "t": 0.0, "dur": 0.55, "rmax": radius * 0.70, "col": Color("b30f2a"), "seed": seed})


func _add(fx: Dictionary) -> void:
	_fx.append(fx)
	while _fx.size() > MAX_FX:
		_fx.pop_front()


func _facing_of(id: int) -> float:
	if Sim == null or id == 0:
		return 0.0
	var e: SimEntity = Sim.get_entity(id) as SimEntity
	return e.facing if e != null else 0.0


func _process(delta: float) -> void:
	if _fx.is_empty():
		return
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i]["t"] = float(_fx[i]["t"]) + delta
		if float(_fx[i]["t"]) >= float(_fx[i]["dur"]):
			_fx.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for fx in _fx:
		var p := clampf(float(fx["t"]) / float(fx["dur"]), 0.0, 1.0)
		var a := 1.0 - p
		var pos: Vector2 = fx["pos"]
		match String(fx["type"]):
			"swing":
				var reach := float(fx["reach"]) * (0.90 + 0.22 * p)
				var rot := float(fx["rot"])
				var from := rot - 1.05 + p * 1.25
				var to := from + 0.95
				var col := Color(1.0, 0.96, 0.86, a * 0.95)
				draw_arc(pos, reach, from, to, 18, col, 5.0 * (1.0 - p) + 2.0, true)
				draw_arc(pos, reach * 0.80, from, to, 14, Color(col.r, col.g, col.b, a * 0.38), 2.0, true)
			"spark":
				var rad := 10.0 if bool(fx.get("crit", false)) else 6.0
				var col: Color = fx["col"]
				draw_circle(pos, rad * (1.0 + p), Color(col.r, col.g, col.b, a * 0.42))
				draw_circle(pos, rad * 0.50 * (1.0 - p), Color(1, 1, 1, a))
				for k in range(6):
					var ang := TAU * float(k) / 6.0 + float(int(pos.x)) * 0.3
					var d := rad + 14.0 * p
					draw_line(pos + Vector2.RIGHT.rotated(ang) * rad, pos + Vector2.RIGHT.rotated(ang) * d, Color(col.r, col.g, col.b, a * 0.70), 2.0, true)
			"shock":
				var rr := float(fx["rmax"]) * _ease_out(p)
				var col: Color = fx["col"]
				draw_arc(pos, rr, 0, TAU, 44, Color(col.r, col.g, col.b, a * 0.82), 5.0 * (1.0 - p) + 1.5, true)
				draw_arc(pos, rr * 0.70, 0, TAU, 38, Color(col.r, col.g, col.b, a * 0.34), 2.0, true)
			"aoe":
				var rr := float(fx["rmax"]) * (0.40 + 0.60 * p)
				var col: Color = fx["col"]
				draw_circle(pos, rr, Color(col.r, col.g, col.b, a * 0.16))
				draw_arc(pos, rr, 0, TAU, 42, Color(col.r, col.g, col.b, a * 0.68), 2.5, true)
			"ring":
				var rr := float(fx["rmax"]) * _ease_out(p)
				var col: Color = fx["col"]
				draw_arc(pos, rr, 0, TAU, 34, Color(col.r, col.g, col.b, a * 0.78), 3.0, true)
			"cast":
				var rr := 26.0 * p
				var col: Color = fx["col"]
				draw_arc(pos, rr, 0, TAU, 30, Color(col.r, col.g, col.b, a * 0.78), 3.0 * (1.0 - p) + 1.0, true)
			"bounce":
				_draw_shards(fx, p, a, 5, 18.0)
			"shards":
				_draw_shards(fx, p, a, 11, float(fx["rmax"]))
			"cloud":
				_draw_cloud(fx, p, a)
			"splash":
				_draw_splash(fx, p, a)


func _draw_shards(fx: Dictionary, p: float, a: float, count: int, distance: float) -> void:
	var pos: Vector2 = fx["pos"]
	var col: Color = fx["col"]
	var seed := int(fx.get("seed", 1))
	for k in range(count):
		var ang := TAU * float(k) / float(count) + float((seed * 37 + k * 17) % 100) * 0.011
		var speed_scale := 0.55 + float((seed + k * 23) % 41) / 100.0
		var d := distance * _ease_out(p) * speed_scale
		var gravity_drop := p * p * 12.0
		var center := pos + Vector2.RIGHT.rotated(ang) * d + Vector2(0, gravity_drop)
		var tangent := Vector2.RIGHT.rotated(ang + 0.45) * (4.0 + 5.0 * (1.0 - p))
		draw_line(center - tangent, center + tangent, Color(col.r, col.g, col.b, a * 0.82), 1.7, true)


func _draw_cloud(fx: Dictionary, p: float, a: float) -> void:
	var pos: Vector2 = fx["pos"]
	var col: Color = fx["col"]
	var seed := int(fx.get("seed", 1))
	var rmax := float(fx["rmax"])
	var hot := bool(fx.get("hot", false))
	for k in range(9):
		var ang := TAU * float(k) / 9.0 + float(seed % 19) * 0.07
		var spread := rmax * (0.12 + 0.52 * p) * (0.55 + float((seed + k * 13) % 37) / 100.0)
		var lift := Vector2(0, -p * (18.0 + float(k % 3) * 6.0))
		var center := pos + Vector2.RIGHT.rotated(ang) * spread + lift
		var radius := rmax * (0.16 + 0.10 * float(k % 3)) * (0.45 + 0.75 * p)
		var local_alpha := a * (0.16 if hot else 0.12)
		draw_circle(center, radius, Color(col.r, col.g, col.b, local_alpha))
	if hot:
		draw_circle(pos + Vector2(0, -6.0 * p), rmax * 0.22 * (1.0 - p * 0.45), Color(1.0, 0.78, 0.28, a * 0.32))


func _draw_splash(fx: Dictionary, p: float, a: float) -> void:
	var pos: Vector2 = fx["pos"]
	var col: Color = fx["col"]
	var seed := int(fx.get("seed", 1))
	var rmax := float(fx["rmax"])
	draw_set_transform(pos + Vector2(0, 2), 0.0, Vector2(1.25, 0.52))
	draw_circle(Vector2.ZERO, rmax * _ease_out(p), Color(col.r, col.g, col.b, a * 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in range(8):
		var ang := TAU * float(k) / 8.0 + float(seed % 23) * 0.03
		var end := pos + Vector2.RIGHT.rotated(ang) * rmax * p
		draw_line(pos, end, Color(col.r, col.g, col.b, a * 0.48), 2.2 * (1.0 - p) + 0.6, true)


func _damage_color(damage_type: String) -> Color:
	match damage_type:
		"fire": return Color("f07832")
		"poison": return Color("6bc46d")
		"blood": return Color("d51b38")
		"shadow": return Color("7652a8")
		"sun": return Color("ffe4a0")
	return Color("d7d2c8")


func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)
