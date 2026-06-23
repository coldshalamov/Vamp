## EntityRenderer.gd — fully CODE-ANIMATED top-down characters (no sprites, no chroma halos).
##
## Each actor is a small articulated rig drawn from parts (legs, arms, torso, head) with a real
## gait: legs and arms swing in anti-phase synced to actual movement speed, the body bobs, attacks
## lunge the body + thrust a strike, and a dash reads as a tucked dodge-roll with a motion trail.
## Style: "modern urban predator" — lean hooded figures in dark streetwear, pale skin, faint
## crimson eyes; enemies are people (civilians, gangers, cops, hunters), not fairytale Draculas.
## Animation is driven off real Sim state (velocity) + CueBus (attack.start, move.dash).
extends Node2D
class_name EntityRenderer

const ATK_DUR := 0.26
const DODGE_DUR := 0.34

var _entities: Array[SimEntity] = []
var _last_pos: Dictionary = {}
var _moving: Dictionary = {}
var _phase: Dictionary = {}   # gait phase, advanced by distance travelled
var _atk: Dictionary = {}     # attack-lunge timer per entity
var _dodge: Dictionary = {}   # dodge-roll timer per entity
var _hitflash: Dictionary = {}   # white impact-flash timer per entity
var _t: float = 0.0
const FLASH_DUR := 0.13


func setup(entities: Array[SimEntity]) -> void:
	_entities = entities


func _ready() -> void:
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _on_cue(event_id: String, payload: Dictionary) -> void:
	var id: int = int(payload.get("entity_id", 0))
	if id == 0:
		return
	if event_id == "attack.start":
		_atk[id] = ATK_DUR
	elif event_id == "move.dash":
		_dodge[id] = DODGE_DUR
	elif event_id == "damage.dealt" or event_id == "damage.player":
		var tid: int = int(payload.get("target_id", 0))
		if tid > 0:
			_hitflash[tid] = FLASH_DUR


func _process(delta: float) -> void:
	_t += delta
	for e in _entities:
		if e == null:
			continue
		var lp: Vector2 = _last_pos.get(e.id, e.pos)
		var moved: float = lp.distance_to(e.pos)
		_moving[e.id] = moved > 0.45
		if moved > 0.45:
			_phase[e.id] = float(_phase.get(e.id, 0.0)) + moved * 0.09
		_last_pos[e.id] = e.pos
		if float(_atk.get(e.id, 0.0)) > 0.0:
			_atk[e.id] = maxf(0.0, float(_atk[e.id]) - delta)
		if float(_dodge.get(e.id, 0.0)) > 0.0:
			_dodge[e.id] = maxf(0.0, float(_dodge[e.id]) - delta)
		if float(_hitflash.get(e.id, 0.0)) > 0.0:
			_hitflash[e.id] = maxf(0.0, float(_hitflash[e.id]) - delta)
	queue_redraw()


func _draw() -> void:
	for e in _entities:
		if e == null:
			continue
		if e.dead:
			if e.kind == "player" or e.kind == "npc":
				_draw_corpse(e)
			continue
	for e in _entities:
		if e == null or e.dead:
			continue
		if e.kind == "vehicle":
			_draw_vehicle(e)
		elif e.kind == "projectile":
			_draw_projectile(e)
		else:
			_draw_rig(e)


# ----------------------------------------------------------------- the rig

func _w(origin: Vector2, facing: float, lx: float, ly: float) -> Vector2:
	return origin + Vector2(lx, ly).rotated(facing)


func _draw_rig(e: SimEntity) -> void:
	var id: int = e.id
	var r: float = e.radius
	var f: float = e.facing
	var pal: Dictionary = _palette(e)
	var build: float = pal["build"]
	var moving: bool = bool(_moving.get(id, false))
	var phase: float = float(_phase.get(id, 0.0))
	var atk: float = float(_atk.get(id, 0.0))
	var dodge: float = float(_dodge.get(id, 0.0))

	_draw_shadow(e, 1.0 - dodge * 0.5)

	# body bob: weight bounce while walking, gentle breathing while idle
	var bob: float = absf(sin(phase * 2.0)) * r * 0.12 if moving else sin(_t * 1.8 + float(id)) * r * 0.03
	var origin: Vector2 = e.pos - Vector2(0, bob)

	if dodge > 0.0:
		_draw_dodge(e, origin, pal, dodge)
		_draw_status(e)
		return

	var atk_p: float = clampf(atk / ATK_DUR, 0.0, 1.0)   # 1 at swing start -> 0
	var thrust: float = sin((1.0 - atk_p) * PI)          # 0 -> 1 -> 0 across the swing
	var lunge: float = thrust * r * 0.45
	var ls: float = sin(phase) if moving else 0.0
	var leg_amp: float = r * 0.5 * build
	var arm_amp: float = r * 0.45 * build
	var rim := Color(0.66, 0.74, 0.92, 0.55)   # cool moonlight rim along the top edge
	var flash: float = clampf(float(_hitflash.get(id, 0.0)) / FLASH_DUR, 0.0, 1.0) * 0.8
	var hot := Color(1.0, 0.93, 0.93)
	var coat: Color = pal["coat"].lerp(hot, flash)
	var coat2: Color = pal["coat2"].lerp(hot, flash)
	var hood: Color = pal["hood"].lerp(hot, flash)
	var skin: Color = pal["skin"].lerp(hot, flash)

	# LEGS (only the swing shows past the coat hem)
	draw_circle(_w(origin, f, ls * leg_amp - r * 0.30, r * 0.24 * build), r * 0.22 * build, pal["pants"])
	draw_circle(_w(origin, f, -ls * leg_amp - r * 0.30, -r * 0.24 * build), r * 0.22 * build, pal["pants"])

	# ARMS (anti-phase swing; both thrust forward on attack)
	var armFwdL: float = thrust * r * 0.7 if atk > 0.0 else -ls * arm_amp
	var armFwdR: float = thrust * r * 0.95 if atk > 0.0 else ls * arm_amp
	var handL := _w(origin, f, armFwdL + r * 0.05, r * 0.58 * build)
	var handR := _w(origin, f, armFwdR + r * 0.05, -r * 0.58 * build)
	draw_circle(handL, r * 0.22 * build, coat2)
	draw_circle(handR, r * 0.22 * build, coat2)

	# TORSO — hips, shoulders, a lit cap, and a moonlit rim for form
	var hips := _w(origin, f, -r * 0.26 + lunge * 0.3, 0)
	var sh := _w(origin, f, r * 0.12 + lunge * 0.3, 0)
	draw_circle(hips, r * 0.46 * build, coat2)
	draw_circle(sh, r * 0.62 * build, coat)
	draw_circle(sh + Vector2(-0.4, -0.9) * r * 0.22, r * 0.36 * build, coat.lightened(0.14))
	draw_arc(sh, r * 0.62 * build, PI * 1.05, PI * 1.95, 16, rim, 1.8, true)

	# HOOD — a peaked cowl that points the way the predator faces
	if pal["hooded"]:
		draw_colored_polygon([
			_w(origin, f, -r * 0.05 + lunge * 0.3, 0), _w(origin, f, r * 0.46 + lunge * 0.4, -r * 0.34),
			_w(origin, f, r * 0.46 + lunge * 0.4, r * 0.34),
		], hood)
	var head := _w(origin, f, r * 0.50 + lunge * 0.4, 0)
	draw_circle(head, r * 0.42 * build, hood)
	# only a small face shows past the cowl, shadowed under the hood
	var face_shadow: float = 0.5 if pal["hooded"] else 0.22
	draw_circle(_w(origin, f, r * 0.62 + lunge * 0.4, 0), r * 0.17 * build, skin.darkened(face_shadow))
	draw_arc(head, r * 0.42 * build, PI * 1.05, PI * 1.95, 12, rim, 1.6, true)
	if pal["eyes"]:
		var ec := Color("#ff3a4a")
		draw_circle(_w(origin, f, r * 0.66 + lunge * 0.4, r * 0.105), r * 0.05 * build, ec)
		draw_circle(_w(origin, f, r * 0.66 + lunge * 0.4, -r * 0.105), r * 0.05 * build, ec)

	# CLAWS — a quick bright sweep on the strike, two short claws at rest for the predator
	var claw: Color = pal["accent"] if pal["eyes"] else Color(0.82, 0.82, 0.88)
	if atk > 0.0:
		var tip := _w(origin, f, armFwdR + r * 0.05 + r * 0.9 * thrust, -r * 0.58 * build + r * 0.32)
		draw_line(handR, tip, claw, 3.0)
		draw_line(handL, _w(origin, f, armFwdL + r * 0.05 + r * 0.6 * thrust, r * 0.58 * build - r * 0.2), claw, 2.0)
	elif pal["eyes"]:
		for s in [-1.0, 1.0]:
			draw_line(handR, _w(origin, f, armFwdR + r * 0.28, -r * 0.58 * build + s * r * 0.12), claw, 1.4)

	_draw_status(e)
	_draw_alert(e)


## Stealth legibility: a "!" over alerted enemies, a "?" over searching ones. Makes detection readable
## so stealth is an actual, visible game (was invisible before).
func _draw_alert(e: SimEntity) -> void:
	if e.kind != "npc":
		return
	var st := String(e.ai_state)
	var ps := String(e.perception_state)
	var p := e.pos + Vector2(0, -e.radius * 2.4)
	if st == "chase" or st == "attack" or ps == "alert":
		var c := Color("#ff3a44")
		draw_line(p, p + Vector2(0, 8), c, 2.6)
		draw_circle(p + Vector2(0, 12), 1.9, c)
	elif st == "search" or int(e.search_ticks) > 0:
		var c := Color("#f0c040")
		draw_arc(p + Vector2(0, 4), 4.0, -2.3, 1.3, 12, c, 2.2)
		draw_line(p + Vector2(0, 4), p + Vector2(0, 8), c, 2.2)
		draw_circle(p + Vector2(0, 12), 1.8, c)


func _draw_dodge(e: SimEntity, origin: Vector2, pal: Dictionary, dodge: float) -> void:
	var r: float = e.radius
	var dp: float = clampf(dodge / DODGE_DUR, 0.0, 1.0)   # 1 -> 0
	# motion-trail ghosts trailing the roll
	for k in range(1, 4):
		var gp := _w(origin, e.facing, -float(k) * r * 0.62, 0)
		draw_circle(gp, r * (0.52 - 0.08 * k), Color(pal["coat"].r, pal["coat"].g, pal["coat"].b, 0.16 * dp))
	# tucked rolling body
	draw_circle(origin, r * 0.62, pal["coat"])
	draw_circle(origin, r * 0.40, pal["coat2"])
	# spinning rim to read the roll
	var spin: float = (1.0 - dp) * TAU * 2.0
	draw_arc(origin, r * 0.62, spin, spin + 1.7, 12, Color(1, 1, 1, 0.5 * dp), 2.5, true)


func _draw_shadow(e: SimEntity, scale: float) -> void:
	var r: float = e.radius * maxf(scale, 0.4)
	draw_set_transform(e.pos + Vector2(0, r * 0.34), 0.0, Vector2(1.3, 0.6))
	draw_circle(Vector2.ZERO, r * 1.05, Color(0, 0, 0, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_corpse(e: SimEntity) -> void:
	var r: float = e.radius
	var pal: Dictionary = _palette(e)
	draw_set_transform(e.pos, e.facing, Vector2(1.45, 0.7))
	draw_circle(Vector2.ZERO, r * 1.5, Color(0.16, 0.015, 0.035, 0.55))   # blood pool
	draw_circle(Vector2.ZERO, r * 0.85, pal["coat"].darkened(0.28))       # prone body
	draw_circle(Vector2(r * 0.7, 0.0), r * 0.32, pal["skin"].darkened(0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_status(e: SimEntity) -> void:
	var r: float = e.radius
	var pos: Vector2 = e.pos
	if e.has_status("mesmerized"):
		draw_arc(pos, r + 7, 0, TAU, 16, Color("#b98cff"), 2.0)
	if e.has_status("fear"):
		draw_arc(pos, r + 7, 0, TAU, 16, Color("#ff9ecf"), 2.0)
	if e.has_status("stun"):
		draw_arc(pos, r + 7, 0, TAU, 16, Color("#f0c040"), 2.0)
	if e.tags.get("marked", 0) > 0:
		draw_arc(pos, r + 9, 0, TAU, 16, Color("#aef0ff"), 2.0)


# ----------------------------------------------------------------- palettes (modern urban predator)

func _palette(e: SimEntity) -> Dictionary:
	if e.kind == "player":
		return { "coat": Color("#2b2b38"), "coat2": Color("#1a1a24"), "pants": Color("#131318"), "skin": Color("#d6c8be"), "hood": Color("#15151f"), "accent": Color("#ff3344"), "build": 0.92, "hooded": true, "eyes": true }
	match String(e.faction):
		"civ":
			var civs := [
				{ "coat": Color("#55524a"), "coat2": Color("#3a3832"), "pants": Color("#2a2824"), "skin": Color("#c2a48c"), "hood": Color("#46443c"), "accent": Color("#6a6a72"), "build": 1.0, "hooded": false, "eyes": false },
				{ "coat": Color("#3f4a57"), "coat2": Color("#283038"), "pants": Color("#20262c"), "skin": Color("#cdb09a"), "hood": Color("#333d48"), "accent": Color("#6a7682"), "build": 1.02, "hooded": false, "eyes": false },
				{ "coat": Color("#5e463a"), "coat2": Color("#3c2c24"), "pants": Color("#2a201a"), "skin": Color("#b89072"), "hood": Color("#4c382e"), "accent": Color("#7a6a5a"), "build": 0.98, "hooded": true, "eyes": false },
			]
			return civs[e.id % civs.size()]
		"gang":
			return { "coat": Color("#2c2620"), "coat2": Color("#191510"), "pants": Color("#161310"), "skin": Color("#b68e68"), "hood": Color("#241e16"), "accent": Color("#7a2a2a"), "build": 1.2, "hooded": false, "eyes": false }
		"police":
			return { "coat": Color("#1d2b46"), "coat2": Color("#121d31"), "pants": Color("#10151f"), "skin": Color("#bda08a"), "hood": Color("#16223a"), "accent": Color("#9fb4e0"), "build": 1.12, "hooded": false, "eyes": false }
		"inquis":
			return { "coat": Color("#23232b"), "coat2": Color("#141419"), "pants": Color("#101015"), "skin": Color("#c8bca8"), "hood": Color("#191920"), "accent": Color("#d8d2c4"), "build": 1.06, "hooded": true, "eyes": false }
		"player":
			return { "coat": Color("#352846"), "coat2": Color("#1f1730"), "pants": Color("#181020"), "skin": Color("#b89cc0"), "hood": Color("#22193a"), "accent": Color("#8a5ac0"), "build": 1.0, "hooded": true, "eyes": false }
	return { "coat": Color("#4a4a54"), "coat2": Color("#2a2a30"), "pants": Color("#1c1c20"), "skin": Color("#b0a090"), "hood": Color("#33333a"), "accent": Color("#777"), "build": 1.0, "hooded": false, "eyes": false }


# ----------------------------------------------------------------- projectiles / vehicles

func _draw_projectile(e: SimEntity) -> void:
	# a glowing blood mote with a short tail along its heading
	var r: float = maxf(e.radius, 4.0)
	var tail := e.pos - Vector2.RIGHT.rotated(e.facing) * r * 2.4
	draw_line(tail, e.pos, Color(0.78, 0.06, 0.16, 0.4), r * 0.8)
	draw_circle(e.pos, r + 2.0, Color(0.78, 0.06, 0.16, 0.35))
	draw_circle(e.pos, r, Color("#e8203a"))
	draw_circle(e.pos - Vector2.RIGHT.rotated(e.facing) * r * 0.3, r * 0.45, Color("#ffd0d6"))


func _draw_vehicle(e: SimEntity) -> void:
	var r: float = e.radius
	var pos: Vector2 = e.pos
	var length := maxf(r * 2.6, 44.0)
	var width := maxf(r * 1.4, 22.0)
	var body := Color("#1a2438") if _entity_is_police(e) else Color("#15151c")
	draw_set_transform(pos, e.facing, Vector2.ONE)
	draw_rect(Rect2(Vector2(-length * 0.5 + 2, -width * 0.5 + 3), Vector2(length, width)), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(Vector2(-length * 0.5, -width * 0.5), Vector2(length, width)), body)
	draw_rect(Rect2(Vector2(-length * 0.12, -width * 0.38), Vector2(length * 0.42, width * 0.76)), body.lightened(0.10))
	draw_rect(Rect2(Vector2(length * 0.22, -width * 0.30), Vector2(length * 0.10, width * 0.60)), Color("#3a4a66"))
	var beam := Color(1.0, 0.95, 0.7, 0.5) if not _entity_is_police(e) else Color(0.6, 0.7, 1.0, 0.5)
	draw_colored_polygon([
		Vector2(length * 0.5, -width * 0.4), Vector2(length * 0.5, width * 0.4),
		Vector2(length * 1.1, width * 0.9), Vector2(length * 1.1, -width * 0.9),
	], Color(beam.r, beam.g, beam.b, 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _entity_is_police(e: SimEntity) -> bool:
	return e.type_id == "police" or e.faction == "police"
