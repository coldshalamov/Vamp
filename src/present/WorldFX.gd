## WorldFX.gd — transient WORLD-SPACE combat & spell visuals (swings, impacts, shockwaves, casts).
##
## VisualFX is screen-space (numbers, flashes, captions). This Node2D lives in the world so effects sit
## on the ground at real positions, pan/zoom with the camera, and read at combat distance. It subscribes
## to CueBus.cue_emitted (read-only) so it's data-driven, not bespoke per call. Before this, casting a
## power produced only a floating "Earthquake!" text — no visual at all.
extends Node2D
class_name WorldFX

var _fx: Array[Dictionary] = []


func _ready() -> void:
	z_index = 50
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _on_cue(event_id: String, payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	match event_id:
		"attack.start":
			_add({ "type": "swing", "pos": pos, "rot": _facing_of(int(payload.get("entity_id", 0))), "t": 0.0, "dur": 0.24, "reach": 42.0 })
		"damage.dealt":
			_add({ "type": "spark", "pos": pos, "t": 0.0, "dur": 0.22, "col": Color("#ffd2a0"), "crit": bool(payload.get("crit", false)) })
		"damage.player":
			_add({ "type": "spark", "pos": pos, "t": 0.0, "dur": 0.22, "col": Color("#ff5a5a"), "crit": false })
		"power.cast":
			_on_power_cast(String(payload.get("power_id", "")), pos)
		"power.potence.quake_hit":
			_add({ "type": "shock", "pos": pos, "t": 0.0, "dur": 0.5, "rmax": 190.0, "col": Color("#e0883a") })
		"power.potence.hit":
			_add({ "type": "shock", "pos": pos, "t": 0.0, "dur": 0.36, "rmax": 105.0, "col": Color("#e0883a") })
		"power.potence.charge_hit":
			_add({ "type": "shock", "pos": pos, "t": 0.0, "dur": 0.3, "rmax": 60.0, "col": Color("#e0a040") })
		"player.heal", "feed.gulp.perfect":
			_add({ "type": "ring", "pos": pos, "t": 0.0, "dur": 0.4, "rmax": 36.0, "col": Color("#7fe0a0") })
		"player.respawn":
			_add({ "type": "shock", "pos": pos, "t": 0.0, "dur": 0.6, "rmax": 90.0, "col": Color("#9a6fff") })


func _on_power_cast(power_id: String, pos: Vector2) -> void:
	match power_id:
		"pot_quake":
			_add({ "type": "shock", "pos": pos, "t": 0.0, "dur": 0.5, "rmax": 190.0, "col": Color("#e0883a") })
		"pot_slam", "pot_charge":
			_add({ "type": "shock", "pos": pos, "t": 0.0, "dur": 0.36, "rmax": 105.0, "col": Color("#e0883a") })
		"bs_storm", "bs_cauldron":
			_add({ "type": "aoe", "pos": pos, "t": 0.0, "dur": 0.7, "rmax": 120.0, "col": Color("#c01028") })
		"cel_dash", "cel_haste", "cel_flurry":
			_add({ "type": "ring", "pos": pos, "t": 0.0, "dur": 0.3, "rmax": 44.0, "col": Color("#8fd6ff") })
		"pre_dread", "pre_majesty", "dom_command", "dom_mesmer":
			_add({ "type": "ring", "pos": pos, "t": 0.0, "dur": 0.5, "rmax": 80.0, "col": Color("#b98cff") })
		_:
			_add({ "type": "cast", "pos": pos, "t": 0.0, "dur": 0.3, "col": Color("#c01028") })


func _add(fx: Dictionary) -> void:
	_fx.append(fx)
	if _fx.size() > 64:
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
		_fx[i]["t"] += delta
		if _fx[i]["t"] >= _fx[i]["dur"]:
			_fx.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for fx in _fx:
		var p: float = clampf(fx["t"] / fx["dur"], 0.0, 1.0)
		var a: float = 1.0 - p
		var pos: Vector2 = fx["pos"]
		match fx["type"]:
			"swing":
				# a bright crescent slash that sweeps across the facing arc
				var reach: float = fx["reach"] * (0.9 + 0.22 * p)
				var rot: float = fx["rot"]
				var from: float = rot - 1.05 + p * 1.25     # leading edge sweeps through the swing
				var to: float = from + 0.95
				var col := Color(1.0, 0.96, 0.86, a * 0.95)
				draw_arc(pos, reach, from, to, 16, col, 5.0 * (1.0 - p) + 2.0, true)
				draw_arc(pos, reach * 0.8, from, to, 12, Color(col.r, col.g, col.b, a * 0.4), 2.0, true)
			"spark":
				var rad: float = (10.0 if fx.get("crit", false) else 6.0)
				var col: Color = fx["col"]
				draw_circle(pos, rad * (1.0 + p), Color(col.r, col.g, col.b, a * 0.5))
				draw_circle(pos, rad * 0.5 * (1.0 - p), Color(1, 1, 1, a))
				# a few radiating shards
				for k in range(6):
					var ang := TAU * float(k) / 6.0 + float(int(pos.x)) * 0.3
					var d := rad + 14.0 * p
					draw_line(pos + Vector2.RIGHT.rotated(ang) * rad, pos + Vector2.RIGHT.rotated(ang) * d, Color(col.r, col.g, col.b, a * 0.7), 2.0)
			"shock":
				var r: float = fx["rmax"] * p
				var col: Color = fx["col"]
				draw_arc(pos, r, 0, TAU, 40, Color(col.r, col.g, col.b, a * 0.85), 5.0 * (1.0 - p) + 1.5, true)
				draw_arc(pos, r * 0.7, 0, TAU, 36, Color(col.r, col.g, col.b, a * 0.4), 2.0, true)
			"aoe":
				var r2: float = fx["rmax"] * (0.4 + 0.6 * p)
				var col2: Color = fx["col"]
				draw_circle(pos, r2, Color(col2.r, col2.g, col2.b, a * 0.18))
				draw_arc(pos, r2, 0, TAU, 40, Color(col2.r, col2.g, col2.b, a * 0.7), 2.5, true)
			"ring":
				var r3: float = fx["rmax"] * p
				var col3: Color = fx["col"]
				draw_arc(pos, r3, 0, TAU, 32, Color(col3.r, col3.g, col3.b, a * 0.8), 3.0, true)
			"cast":
				var r4: float = 26.0 * p
				var col4: Color = fx["col"]
				draw_arc(pos, r4, 0, TAU, 28, Color(col4.r, col4.g, col4.b, a * 0.8), 3.0 * (1.0 - p) + 1.0, true)
