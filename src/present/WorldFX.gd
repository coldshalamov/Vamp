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
		# B4 — melee connect: a directional impact spark oriented along the attack direction.
		# Larger and brighter on crit. WorldFX receives this via cue_emitted signal so it fires
		# alongside VisualFX hitstop and CameraDirector kick without extra wiring.
		"hit.connect":
			var dir: Vector2 = payload.get("dir", Vector2.ZERO)
			var is_crit: bool = bool(payload.get("crit", false))
			var dur: float = 0.30 if is_crit else 0.22
			# A directional burst: spark centered at impact pos, pushed slightly along dir
			_add({"type": "impact_burst", "pos": pos, "dir": dir, "t": 0.0, "dur": dur,
				"col": Color("ffcc88") if is_crit else Color("ffd2a0"), "crit": is_crit})
		"damage.dealt":
			_add({"type": "spark", "pos": pos, "t": 0.0, "dur": 0.22, "col": Color("ffd2a0"), "crit": bool(payload.get("crit", false))})
		"damage.player":
			_add({"type": "spark", "pos": pos, "t": 0.0, "dur": 0.22, "col": Color("ff5a5a"), "crit": false})
		# power.cast is now owned by SpellFX (distinct per-archetype visuals); WorldFX no longer draws
		# the generic expanding ring that made every spell look identical. (_on_power_cast retained
		# for the potence hit cues below.)
		"power.potence.quake_hit":
			_add({"type": "shock", "pos": pos, "t": 0.0, "dur": 0.50, "rmax": 190.0, "col": Color("e0883a")})
		"power.potence.hit":
			_add({"type": "shock", "pos": pos, "t": 0.0, "dur": 0.36, "rmax": 105.0, "col": Color("e0883a")})
		"power.potence.charge_hit":
			_add({"type": "shock", "pos": pos, "t": 0.0, "dur": 0.30, "rmax": 60.0, "col": Color("e0a040")})
		"player.heal":
			_add({"type": "ring", "pos": pos, "t": 0.0, "dur": 0.40, "rmax": 36.0, "col": Color("7fe0a0")})
		# B2 — perfect gulp: Bleeding Occult Sigil contracts over the throat at pos.
		# Registered for BOTH cue strings to survive the dot/underscore naming conflict
		# (SimPlayer currently emits "feed.gulp.perfect"; contract says "feed.gulp_perfect").
		"feed.gulp.perfect", "feed.gulp_perfect":
			_add({"type": "sigil", "pos": pos, "t": 0.0, "dur": 0.58,
				"rmax": 28.0, "col": Color("c0304a")})
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


## The Predator cursor: a context mark that reads what's under it — fangs over prey, a target-lock
## over a hostile, a sharp predatory diamond otherwise. Replaces the incongruous "bullseye".
func _draw_reticle() -> void:
	var m := get_global_mouse_position()
	if Sim == null or Sim.player == null or Sim.player.dead:
		return
	var crimson := Color(0.86, 0.14, 0.20, 0.9)
	draw_line(Sim.player.pos, m, Color(0.86, 0.14, 0.20, 0.10), 1.0)   # faint aim line from the predator
	var hover := _hover_entity(m)
	if hover != null and (hover.faction == "civ" or hover.downed):
		# PREY: fangs over a feedable mortal + a soft highlight on them
		draw_arc(hover.pos, hover.radius + 5.0, 0, TAU, 20, Color(0.86, 0.14, 0.20, 0.5), 1.4)
		var fcol := Color(0.96, 0.86, 0.86, 0.95)
		draw_line(m + Vector2(-4, -7), m + Vector2(-2, 2), fcol, 1.8)   # left fang
		draw_line(m + Vector2(4, -7), m + Vector2(2, 2), fcol, 1.8)     # right fang
		draw_line(m + Vector2(-5, -7), m + Vector2(5, -7), fcol, 1.2)   # gumline
	elif hover != null and hover.hostile_to_player:
		# ENEMY: a target lock (corner brackets) — kill this one
		var r := 11.0
		for ix in range(2):
			for iy in range(2):
				var sx := -1.0 if ix == 0 else 1.0
				var sy := -1.0 if iy == 0 else 1.0
				var c := m + Vector2(sx * r, sy * r)
				draw_line(c, c - Vector2(sx * 5.0, 0.0), crimson, 1.8)
				draw_line(c, c - Vector2(0.0, sy * 5.0), crimson, 1.8)
	else:
		# DEFAULT: a sharp predatory diamond mark, no bullseye
		for k in range(4):
			var a := PI * 0.5 * float(k) + PI * 0.25
			draw_line(m + Vector2.RIGHT.rotated(a) * 4.0, m + Vector2.RIGHT.rotated(a) * 10.0, crimson, 1.6)
		draw_circle(m, 1.4, crimson)


## The NPC the cursor is over (for the context cursor + future hover dossier). Presentation read only.
func _hover_entity(m: Vector2) -> SimEntity:
	if Sim == null:
		return null
	var best: SimEntity = null
	var best_d := 99999.0
	for e in Sim.entities:
		if e == null or e.dead or e.kind != "npc":
			continue
		var d: float = e.pos.distance_to(m)
		if d <= float(e.radius) + 14.0 and d < best_d:
			best_d = d
			best = e
	return best


func _facing_of(id: int) -> float:
	if Sim == null or id == 0:
		return 0.0
	var e: SimEntity = Sim.get_entity(id) as SimEntity
	return e.facing if e != null else 0.0


func _process(delta: float) -> void:
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i]["t"] = float(_fx[i]["t"]) + delta
		if float(_fx[i]["t"]) >= float(_fx[i]["dur"]):
			_fx.remove_at(i)
	queue_redraw()   # always, so the aim reticle tracks the cursor


func _draw() -> void:
	_draw_reticle()
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
			# B4 — directional impact burst on melee connect. Sparks fan outward along dir
			# with a secondary burst in the opposite direction (recoil spray).
			"impact_burst":
				var is_crit: bool = bool(fx.get("crit", false))
				var rad2 := 12.0 if is_crit else 7.0
				var col2: Color = fx["col"]
				var dir2: Vector2 = fx.get("dir", Vector2.RIGHT)
				if dir2.length_squared() < 0.01:
					dir2 = Vector2.RIGHT
				# Core flash at impact
				draw_circle(pos, rad2 * (0.9 + 0.5 * p), Color(1, 1, 1, a * 0.60))
				# Directional sparks fan in a 90-degree cone along dir
				var fan_count := 7 if is_crit else 5
				for k in range(fan_count):
					var spread := lerpf(-0.7, 0.7, float(k) / float(fan_count - 1))
					var ang3 := dir2.angle() + spread
					var d3 := (rad2 + 18.0 * p) * (0.65 + 0.35 * float(k % 2))
					var from3 := pos + Vector2.RIGHT.rotated(ang3) * rad2 * 0.6
					var to3 := pos + Vector2.RIGHT.rotated(ang3) * d3
					draw_line(from3, to3, Color(col2.r, col2.g, col2.b, a * 0.85), 2.2 if is_crit else 1.6, true)
				# Recoil sparks opposite dir (smaller)
				for k in range(3):
					var spread2 := lerpf(-0.35, 0.35, float(k) / 2.0)
					var ang4 := dir2.angle() + PI + spread2
					var d4 := (rad2 * 0.5 + 10.0 * p)
					draw_line(pos, pos + Vector2.RIGHT.rotated(ang4) * d4, Color(col2.r, col2.g, col2.b, a * 0.45), 1.4, true)
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
			# B2 — Bleeding Occult Sigil: a contracting occult circle with radial glyphs
			# that contracts inward toward pos (the throat) as the kiss "lands."
			# Pure draw-math — no random, no sim reads. Deterministic for a given p.
			"sigil":
				_draw_sigil(fx, p, a)


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


## B2 — Bleeding Occult Sigil: a contracting blood-red occult circle with radial rune-strokes
## that collapses inward toward pos (the throat) over the gulp duration.
## No random calls — all geometry is pure deterministic math on p, k, pos.
## Contracts from rmax down to 0 as p goes 0 -> 1, creating the "kiss lands" convergence.
func _draw_sigil(fx: Dictionary, p: float, a: float) -> void:
	var pos: Vector2 = fx["pos"]
	var col: Color = fx["col"]
	var rmax: float = float(fx["rmax"])
	# The ring contracts inward: radius starts at rmax and shrinks to 0 as p approaches 1.
	# ease_in so it accelerates into the kiss.
	var contract_p: float = p * p   # ease-in
	var r: float = rmax * (1.0 - contract_p)
	if r < 1.0:
		return
	# Outer occult ring — thick, bleeds outward
	draw_arc(pos, r, 0, TAU, 40, Color(col.r, col.g, col.b, a * 0.88), 3.2 * (1.0 - p) + 0.8, true)
	# Inner ring — thinner, slightly offset rotation for depth
	draw_arc(pos, r * 0.72, 0, TAU, 32, Color(col.r, col.g, col.b, a * 0.52), 1.6, true)
	# Radial rune-strokes: 8 spokes connecting outer to inner ring, like a sigil wheel.
	var spoke_count := 8
	for k in range(spoke_count):
		var ang := TAU * float(k) / float(spoke_count) + p * 0.8   # slow rotation as it contracts
		var outer := pos + Vector2.RIGHT.rotated(ang) * r
		var inner := pos + Vector2.RIGHT.rotated(ang + 0.22) * r * 0.72
		draw_line(outer, inner, Color(col.r, col.g, col.b, a * 0.72), 1.8, true)
	# Heartbeat dot at center — pulses brighter as sigil contracts
	var core_r: float = 3.0 * contract_p
	if core_r > 0.5:
		draw_circle(pos, core_r, Color(1.0, 0.55, 0.65, a * 0.90))
