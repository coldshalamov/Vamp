## CharacterRig2D.gd — continuous 2.5D cutout character presentation.
##
## This node is deliberately a VIEW. It reads SimEntity snapshots and semantic cues, but never
## mutates simulation state. The silhouette is built from articulated, beveled polygons rather than
## the old stack of circles. Poses are continuous functions of distance travelled and ActionDef frame
## data, so movement/attacks remain smooth at any render refresh rate without sprite-sheet stepping.
extends Node2D
class_name CharacterRig2D

const FIXED_DT := 1.0 / 60.0
const TELEPORT_DISTANCE := 220.0
const HIT_RESPONSE_SECONDS := 0.18
const DASH_RESPONSE_SECONDS := 0.34
const SurfaceShader := preload("res://art/shaders/kinetic_surface.gdshader")

var entity: SimEntity = null

var _prev_pos: Vector2 = Vector2.ZERO
var _curr_pos: Vector2 = Vector2.ZERO
var _prev_facing: float = 0.0
var _curr_facing: float = 0.0
var _physics_ready: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _walk_phase: float = 0.0
var _move_blend: float = 0.0
var _hit_time: float = 0.0
var _dash_time: float = 0.0
var _feed_pulse: float = 0.0
var _death_blend: float = 0.0
var _time: float = 0.0
var _palette: Dictionary = {}


func setup(e: SimEntity) -> void:
	entity = e
	name = "CharacterRig_%d" % e.id
	_prev_pos = e.pos
	_curr_pos = e.pos
	_prev_facing = e.facing
	_curr_facing = e.facing
	_physics_ready = true
	_palette = _make_palette(e)
	var surface := ShaderMaterial.new()
	surface.shader = SurfaceShader
	surface.set_shader_parameter("grain_seed", float(e.id) * 0.173)
	surface.set_shader_parameter("grain_strength", 0.072 if e.kind == "player" else 0.058)
	surface.set_shader_parameter("directional_relief", 0.086)
	material = surface
	position = e.pos
	rotation = e.facing
	queue_redraw()


## Called from EntityRenderer on the fixed step, after Sim has advanced.
func capture_physics() -> void:
	if entity == null:
		return
	if not _physics_ready:
		_prev_pos = entity.pos
		_curr_pos = entity.pos
		_prev_facing = entity.facing
		_curr_facing = entity.facing
		_physics_ready = true
		return
	_prev_pos = _curr_pos
	_prev_facing = _curr_facing
	_curr_pos = entity.pos
	_curr_facing = entity.facing
	var travelled := _prev_pos.distance_to(_curr_pos)
	if travelled > TELEPORT_DISTANCE:
		_prev_pos = _curr_pos
		_prev_facing = _curr_facing
		travelled = 0.0
	_velocity = (_curr_pos - _prev_pos) / FIXED_DT
	if travelled > 0.02:
		# Distance-driven phase prevents foot skating when time scale changes.
		_walk_phase += travelled * 0.19


func react(event_id: String, _payload: Dictionary = {}) -> void:
	match event_id:
		"move.dash", "pounce.start":
			_dash_time = DASH_RESPONSE_SECONDS
		"damage.dealt", "damage.player", "hit.connect", "power.projectile.hit":
			_hit_time = HIT_RESPONSE_SECONDS
		"feed.start", "feed.drain", "feed.gulp", "feed.gulp.perfect":
			_feed_pulse = 1.0
		"player.respawn":
			_prev_pos = entity.pos if entity != null else _curr_pos
			_curr_pos = _prev_pos
			_death_blend = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if entity == null:
		return
	_time += delta
	var interpolation := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	position = _prev_pos.lerp(_curr_pos, interpolation)
	rotation = lerp_angle(_prev_facing, _curr_facing, interpolation)
	var speed_ratio := clampf(_velocity.length() / 220.0, 0.0, 1.35)
	_move_blend = move_toward(_move_blend, speed_ratio, delta * 7.5)
	_hit_time = maxf(0.0, _hit_time - delta)
	_dash_time = maxf(0.0, _dash_time - delta)
	_feed_pulse = move_toward(_feed_pulse, 0.0, delta * 2.8)
	_death_blend = move_toward(_death_blend, 1.0 if entity.dead else 0.0, delta * 4.5)
	queue_redraw()


func _draw() -> void:
	if entity == null:
		return
	if entity.dead or _death_blend > 0.82:
		_draw_corpse()
		return

	_draw_resonance()
	_draw_contact_shadow()

	var r := maxf(entity.radius, 10.0)
	var build := float(_palette.get("build", 1.0))
	var action := _action_pose()
	var stride := sin(_walk_phase) * _move_blend
	var cadence := absf(sin(_walk_phase * 2.0)) * _move_blend
	var breathing := sin(_time * 1.75 + float(entity.id) * 0.61) * (1.0 - clampf(_move_blend, 0.0, 1.0))
	var bob := cadence * r * 0.08 + breathing * r * 0.025
	var dash_ratio := clampf(_dash_time / DASH_RESPONSE_SECONDS, 0.0, 1.0)
	var hit_ratio := clampf(_hit_time / HIT_RESPONSE_SECONDS, 0.0, 1.0)
	var recoil := sin(hit_ratio * PI) * r * 0.26
	var lean := clampf(_move_blend, 0.0, 1.0) * r * 0.10 + float(action["lunge"]) * r * 0.34 - recoil
	var root := Vector2(lean - r * 0.08, -bob)
	var twist := float(action["twist"])
	var crouch := sin((1.0 - dash_ratio) * PI) * r * 0.28 if dash_ratio > 0.0 else 0.0
	root.x -= crouch

	# A dash leaves stretched cloth echoes rather than turning the actor into a ball.
	if dash_ratio > 0.0:
		_draw_dash_echoes(root, dash_ratio, r)

	var cloth: Color = _flash(_palette["cloth"], hit_ratio)
	var cloth_dark: Color = _flash(_palette["cloth_dark"], hit_ratio)
	var leather: Color = _flash(_palette["leather"], hit_ratio)
	var metal: Color = _flash(_palette["metal"], hit_ratio)
	var skin: Color = _flash(_palette["skin"], hit_ratio)
	var accent: Color = _palette["accent"]
	var rim: Color = _palette["rim"]

	# Lower body. Feet are planted wider than the old circular rig and move on distinct arcs.
	var hip := root + Vector2(-r * 0.16, twist * r * 0.14)
	var left_knee := hip + Vector2(-r * (0.52 - stride * 0.26), r * (0.28 + stride * 0.06))
	var right_knee := hip + Vector2(-r * (0.52 + stride * 0.26), -r * (0.28 - stride * 0.06))
	var left_foot := left_knee + Vector2(-r * (0.48 - stride * 0.20), r * 0.05)
	var right_foot := right_knee + Vector2(-r * (0.48 + stride * 0.20), -r * 0.05)

	_draw_coat_tails(hip, stride, twist, r, cloth_dark)
	_draw_limb(hip + Vector2(-r * 0.05, r * 0.19), left_knee, r * 0.29 * build, cloth_dark, rim, 0.32)
	_draw_limb(left_knee, left_foot, r * 0.25 * build, leather, rim, 0.20)
	_draw_boot(left_foot, r, leather, rim, stride)
	_draw_limb(hip + Vector2(-r * 0.05, -r * 0.19), right_knee, r * 0.29 * build, cloth_dark.darkened(0.08), rim, 0.20)
	_draw_limb(right_knee, right_foot, r * 0.25 * build, leather.darkened(0.06), rim, 0.14)
	_draw_boot(right_foot, r, leather.darkened(0.04), rim, -stride)

	# Torso and shoulders are angular, layered, and faction-specific.
	var shoulder := root + Vector2(r * (0.36 + float(action["lunge"]) * 0.18), twist * r * 0.28)
	_draw_torso(hip, shoulder, r, build, cloth, cloth_dark, leather, metal, rim)

	# Articulated arms: upper arm and forearm are independently posed.
	var attack_reach := float(action["reach"])
	var guard := float(action["guard"])
	var left_shoulder := shoulder + Vector2(-r * 0.03, r * 0.57 * build)
	var right_shoulder := shoulder + Vector2(-r * 0.03, -r * 0.57 * build)
	var left_elbow := left_shoulder + Vector2(r * (0.08 - stride * 0.20), r * (0.40 - guard * 0.18))
	var right_elbow := right_shoulder + Vector2(r * (0.08 + stride * 0.20), -r * (0.40 - guard * 0.18))
	var left_hand := left_elbow + Vector2(r * (0.22 + attack_reach * 0.58), r * (0.06 - attack_reach * 0.28))
	var right_hand := right_elbow + Vector2(r * (0.22 + attack_reach * 0.92), -r * (0.06 - attack_reach * 0.18))
	if _is_feeding():
		left_elbow = left_shoulder + Vector2(r * 0.42, r * 0.12)
		right_elbow = right_shoulder + Vector2(r * 0.42, -r * 0.12)
		left_hand = left_elbow + Vector2(r * 0.48, -r * 0.10)
		right_hand = right_elbow + Vector2(r * 0.48, r * 0.10)

	_draw_limb(left_shoulder, left_elbow, r * 0.27 * build, cloth, rim, 0.34)
	_draw_limb(left_elbow, left_hand, r * 0.23 * build, cloth_dark, rim, 0.24)
	_draw_glove(left_hand, r, leather, rim)
	_draw_limb(right_shoulder, right_elbow, r * 0.27 * build, cloth.darkened(0.05), rim, 0.22)
	_draw_limb(right_elbow, right_hand, r * 0.23 * build, cloth_dark.darkened(0.05), rim, 0.16)
	_draw_glove(right_hand, r, leather.darkened(0.04), rim)

	# Head/hood/helmet. The face is a narrow shadowed wedge, not a smiling icon.
	var head := shoulder + Vector2(r * (0.72 + float(action["lunge"]) * 0.16), twist * r * 0.12)
	_draw_head(head, r, skin, cloth_dark, metal, accent, rim)
	_draw_weapon(right_hand, left_hand, r, attack_reach, leather, metal, accent, rim)
	_draw_status_language(r)
	_draw_alert_language(r)


func _action_pose() -> Dictionary:
	var pose := {"twist": 0.0, "reach": 0.0, "lunge": 0.0, "guard": 0.0}
	if entity == null or entity.current_action == null or entity.current_action.def == null:
		return pose
	var def: ActionDef = entity.current_action.def
	var frame := float(entity.action_frame)
	var startup := maxf(1.0, float(def.startup))
	var active := maxf(1.0, float(def.active))
	var recovery := maxf(1.0, float(def.recovery))
	if frame < startup:
		var p0 := _smooth(frame / startup)
		pose["twist"] = -0.52 * p0
		pose["guard"] = 0.35 + 0.45 * p0
	elif frame < startup + active:
		var p1 := _smooth((frame - startup) / active)
		pose["twist"] = lerpf(-0.52, 0.72, p1)
		pose["reach"] = sin(p1 * PI) * (1.22 if def.id == "melee_heavy" else 1.0)
		pose["lunge"] = sin(p1 * PI)
		pose["guard"] = 1.0 - p1
	else:
		var p2 := _smooth((frame - startup - active) / recovery)
		pose["twist"] = lerpf(0.72, 0.0, p2)
		pose["reach"] = (1.0 - p2) * 0.28
		pose["lunge"] = (1.0 - p2) * 0.18
	return pose


func _draw_contact_shadow() -> void:
	var r := maxf(entity.radius, 10.0)
	var dash_ratio := clampf(_dash_time / DASH_RESPONSE_SECONDS, 0.0, 1.0)
	var flatten := 0.58 + dash_ratio * 0.12
	draw_set_transform(Vector2(-r * 0.12, r * 0.22), 0.0, Vector2(1.55 + dash_ratio * 0.40, flatten))
	draw_circle(Vector2.ZERO, r * 1.18, Color(0.005, 0.006, 0.010, 0.58))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_dash_echoes(root: Vector2, ratio: float, r: float) -> void:
	var cloth: Color = _palette["cloth"]
	for i in range(1, 5):
		var alpha := ratio * (0.16 - float(i) * 0.024)
		var off := Vector2(-r * float(i) * 0.72, sin(float(i) * 2.1 + _time * 12.0) * r * 0.12)
		var pts := PackedVector2Array([
			root + off + Vector2(-r * 0.72, -r * 0.52),
			root + off + Vector2(r * 0.42, -r * 0.44),
			root + off + Vector2(r * 0.64, r * 0.18),
			root + off + Vector2(-r * 0.86, r * 0.50),
		])
		draw_colored_polygon(pts, Color(cloth.r, cloth.g, cloth.b, maxf(0.0, alpha)))


func _draw_coat_tails(hip: Vector2, stride: float, twist: float, r: float, color: Color) -> void:
	var speed_sway := clampf(_move_blend, 0.0, 1.2)
	var flutter := sin(_time * 8.0 + float(entity.id)) * speed_sway * r * 0.16
	var left := PackedVector2Array([
		hip + Vector2(-r * 0.18, r * 0.14),
		hip + Vector2(-r * 0.18, r * 0.62),
		hip + Vector2(-r * (1.18 + speed_sway * 0.22), r * (0.74 + stride * 0.12) + flutter),
		hip + Vector2(-r * 0.94, r * 0.08),
	])
	var right := PackedVector2Array([
		hip + Vector2(-r * 0.18, -r * 0.14),
		hip + Vector2(-r * 0.18, -r * 0.62),
		hip + Vector2(-r * (1.08 + speed_sway * 0.24), -r * (0.72 - stride * 0.12) - flutter),
		hip + Vector2(-r * 0.88, -r * 0.08),
	])
	_draw_beveled(left, color.darkened(0.08), color.lightened(0.13), 1.15)
	_draw_beveled(right, color.darkened(0.16 + twist * 0.03), color.lightened(0.05), 1.0)
	# Long player/inquisitor coats have a torn center flap for a harsher silhouette.
	if bool(_palette.get("long_coat", false)):
		var center := PackedVector2Array([
			hip + Vector2(-r * 0.28, -r * 0.16),
			hip + Vector2(-r * 0.24, r * 0.18),
			hip + Vector2(-r * 1.30, r * 0.08 + flutter * 0.5),
			hip + Vector2(-r * 1.08, -r * 0.20),
		])
		_draw_beveled(center, color.darkened(0.22), color.lightened(0.02), 0.9)


func _draw_torso(hip: Vector2, shoulder: Vector2, r: float, build: float, cloth: Color, cloth_dark: Color, leather: Color, metal: Color, rim: Color) -> void:
	var side := r * 0.62 * build
	var torso := PackedVector2Array([
		hip + Vector2(-r * 0.18, side * 0.65),
		shoulder + Vector2(-r * 0.10, side),
		shoulder + Vector2(r * 0.48, side * 0.64),
		shoulder + Vector2(r * 0.58, -side * 0.64),
		shoulder + Vector2(-r * 0.10, -side),
		hip + Vector2(-r * 0.18, -side * 0.65),
	])
	_draw_beveled(torso, cloth, rim, 1.35)
	# Chest panels create a light-catching pseudo-normal without requiring a texture asset.
	var panel := PackedVector2Array([
		shoulder + Vector2(-r * 0.24, side * 0.50),
		shoulder + Vector2(r * 0.36, side * 0.32),
		shoulder + Vector2(r * 0.42, -side * 0.24),
		shoulder + Vector2(-r * 0.24, -side * 0.36),
	])
	var gear := String(_palette.get("gear", "coat"))
	if gear in ["armor", "hunter"]:
		_draw_beveled(panel, metal.darkened(0.28), metal.lightened(0.20), 1.0)
		var plate_line := shoulder + Vector2(r * 0.03, 0.0)
		draw_line(plate_line + Vector2(0, -side * 0.42), plate_line + Vector2(0, side * 0.42), metal.lightened(0.28), 1.2, true)
	else:
		_draw_beveled(panel, cloth_dark, cloth.lightened(0.18), 0.85)
	# Belt, buckle, pouches.
	_draw_limb(hip + Vector2(-r * 0.05, -side * 0.72), hip + Vector2(-r * 0.05, side * 0.72), r * 0.13, leather, rim, 0.18)
	var buckle := PackedVector2Array([
		hip + Vector2(-r * 0.17, -r * 0.17), hip + Vector2(r * 0.12, -r * 0.17),
		hip + Vector2(r * 0.12, r * 0.17), hip + Vector2(-r * 0.17, r * 0.17),
	])
	_draw_beveled(buckle, metal.darkened(0.10), metal.lightened(0.35), 0.8)


func _draw_head(head: Vector2, r: float, skin: Color, hood_color: Color, metal: Color, accent: Color, rim: Color) -> void:
	var hooded := bool(_palette.get("hooded", false))
	var helmeted := bool(_palette.get("helmeted", false))
	var head_poly := PackedVector2Array([
		head + Vector2(-r * 0.40, r * 0.35),
		head + Vector2(r * 0.02, r * 0.46),
		head + Vector2(r * 0.46, r * 0.22),
		head + Vector2(r * 0.58, 0.0),
		head + Vector2(r * 0.42, -r * 0.26),
		head + Vector2(-r * 0.05, -r * 0.44),
		head + Vector2(-r * 0.43, -r * 0.30),
	])
	if helmeted:
		_draw_beveled(head_poly, metal.darkened(0.30), metal.lightened(0.25), 1.2)
	elif hooded:
		_draw_beveled(head_poly, hood_color, rim, 1.2)
	else:
		_draw_beveled(head_poly, skin.darkened(0.16), skin.lightened(0.18), 1.0)

	var face := PackedVector2Array([
		head + Vector2(r * 0.07, r * 0.26),
		head + Vector2(r * 0.50, r * 0.15),
		head + Vector2(r * 0.55, -r * 0.13),
		head + Vector2(r * 0.08, -r * 0.25),
	])
	_draw_beveled(face, skin.darkened(0.34 if hooded or helmeted else 0.20), skin.lightened(0.08), 0.75)
	# Brow and nose plane: thin, hard marks keep the face severe at gameplay scale.
	draw_line(head + Vector2(r * 0.20, -r * 0.20), head + Vector2(r * 0.48, -r * 0.08), Color(0, 0, 0, 0.48), 1.15, true)
	draw_line(head + Vector2(r * 0.20, r * 0.20), head + Vector2(r * 0.48, r * 0.08), Color(0, 0, 0, 0.48), 1.15, true)
	if bool(_palette.get("predator_eyes", false)):
		draw_line(head + Vector2(r * 0.36, -r * 0.12), head + Vector2(r * 0.51, -r * 0.07), accent, 1.8, true)
		draw_line(head + Vector2(r * 0.36, r * 0.12), head + Vector2(r * 0.51, r * 0.07), accent, 1.8, true)
	if helmeted:
		var visor := PackedVector2Array([
			head + Vector2(r * 0.12, -r * 0.30), head + Vector2(r * 0.48, -r * 0.18),
			head + Vector2(r * 0.50, r * 0.16), head + Vector2(r * 0.12, r * 0.28),
		])
		draw_colored_polygon(visor, Color(0.03, 0.05, 0.07, 0.80))


func _draw_weapon(right_hand: Vector2, left_hand: Vector2, r: float, reach: float, leather: Color, metal: Color, accent: Color, rim: Color) -> void:
	var weapon := String(_palette.get("weapon", "hands"))
	match weapon:
		"claws":
			var extension := r * (0.58 + reach * 0.62)
			for hand in [right_hand, left_hand]:
				for i in range(3):
					var lateral := (float(i) - 1.0) * r * 0.13
					var tip := hand + Vector2(extension, lateral)
					draw_line(hand + Vector2(r * 0.04, lateral * 0.5), tip, accent.lightened(0.24), 1.45 + reach, true)
		"bat":
			var end := right_hand + Vector2(r * (1.38 + reach * 0.48), r * 0.12)
			_draw_limb(right_hand, end, r * 0.17, leather.darkened(0.12), rim, 0.25)
			_draw_limb(end - Vector2(r * 0.35, 0), end, r * 0.27, metal.darkened(0.18), metal.lightened(0.24), 0.28)
		"pistol":
			var muzzle := right_hand + Vector2(r * (0.92 + reach * 0.32), 0)
			var body := _segment_points(right_hand, muzzle, r * 0.23)
			_draw_beveled(body, metal.darkened(0.30), metal.lightened(0.25), 0.9)
			var grip := PackedVector2Array([
				right_hand + Vector2(-r * 0.03, -r * 0.07), right_hand + Vector2(r * 0.28, -r * 0.03),
				right_hand + Vector2(r * 0.15, r * 0.30), right_hand + Vector2(-r * 0.13, r * 0.23),
			])
			draw_colored_polygon(grip, leather)
		"shotgun":
			var muzzle2 := right_hand + Vector2(r * (1.55 + reach * 0.35), 0)
			_draw_limb(right_hand - Vector2(r * 0.22, 0), muzzle2, r * 0.19, metal.darkened(0.32), metal.lightened(0.25), 0.25)
			_draw_limb(left_hand, right_hand + Vector2(r * 0.55, 0), r * 0.20, leather, rim, 0.2)
		"knife":
			var blade := PackedVector2Array([
				right_hand + Vector2(r * 0.10, -r * 0.10),
				right_hand + Vector2(r * (0.92 + reach * 0.48), 0),
				right_hand + Vector2(r * 0.10, r * 0.11),
			])
			_draw_beveled(blade, metal.lightened(0.08), Color(0.90, 0.94, 1.0, 0.72), 0.9)
		_:
			pass


func _draw_status_language(r: float) -> void:
	if entity == null:
		return
	var base := Vector2(-r * 0.05, 0.0)
	if entity.has_status("stun"):
		_draw_segmented_ring(base, r * 1.30, Color(0.92, 0.68, 0.20, 0.86), 6, _time * 1.8)
	if entity.has_status("fear"):
		_draw_segmented_ring(base, r * 1.42, Color(0.62, 0.24, 0.42, 0.76), 8, -_time * 1.2)
	if entity.has_status("mesmerized"):
		_draw_segmented_ring(base, r * 1.38, Color(0.55, 0.38, 0.82, 0.76), 5, _time * 0.7)
	if entity.tags.get("marked", 0) > 0:
		_draw_segmented_ring(base, r * 1.55, Color(0.42, 0.78, 0.88, 0.70), 4, 0.0)


func _draw_alert_language(r: float) -> void:
	if entity == null or entity.kind != "npc" or not (entity.hostile_to_player or entity.responder):
		return
	var state := String(entity.ai_state)
	var perception := String(entity.perception_state)
	var p := Vector2(r * 0.18, -r * 1.72)
	if state in ["chase", "attack"] or perception == "alert":
		# Two inward threat chevrons read as acquisition without a comic-book exclamation mark.
		var c := Color(0.95, 0.15, 0.18, 0.90)
		for side in [-1.0, 1.0]:
			var tri := PackedVector2Array([
				p + Vector2(-r * 0.18, side * r * 0.42),
				p + Vector2(r * 0.32, side * r * 0.18),
				p + Vector2(-r * 0.02, side * r * 0.05),
			])
			draw_colored_polygon(tri, c)
	elif state == "search" or int(entity.search_ticks) > 0:
		var c2 := Color(0.86, 0.67, 0.24, 0.76)
		var sweep := _time * 1.8 + float(entity.id)
		draw_arc(p, r * 0.42, sweep, sweep + 1.8, 14, c2, 1.8, true)
		draw_line(p, p + Vector2.RIGHT.rotated(sweep + 1.8) * r * 0.62, c2, 1.1, true)


func _draw_resonance() -> void:
	if entity == null or entity.resonance == "" or not (entity.faction == "civ" or entity.downed):
		return
	var col := _resonance_color(entity.resonance)
	var pulse := 0.5 + 0.5 * sin(_time * 2.1 + float(entity.id))
	var r := entity.radius * (1.42 + pulse * 0.08)
	_draw_segmented_ring(Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.25 + pulse * 0.24), 8, _time * 0.22)
	# Shape coding keeps resonance readable without relying only on hue.
	var sides := 3
	match entity.resonance:
		"sanguine": sides = 4
		"choleric": sides = 3
		"melancholic": sides = 6
		"phlegmatic": sides = 8
	var glyph := PackedVector2Array()
	for i in range(sides):
		glyph.append(Vector2.RIGHT.rotated(TAU * float(i) / float(sides) + _time * 0.10) * r * 0.67)
	glyph.append(glyph[0])
	draw_polyline(glyph, Color(col.r, col.g, col.b, 0.22 + pulse * 0.18), 1.2, true)


func _draw_corpse() -> void:
	var r := maxf(entity.radius, 10.0)
	var cloth: Color = _palette.get("cloth", Color(0.15, 0.15, 0.18))
	var skin: Color = _palette.get("skin", Color(0.55, 0.48, 0.44))
	# Pool and grounded shadow are ellipses; the body itself remains an angular, readable silhouette.
	draw_set_transform(Vector2(-r * 0.05, r * 0.12), 0.0, Vector2(1.65, 0.62))
	draw_circle(Vector2.ZERO, r * 1.12, Color(0.16, 0.005, 0.018, 0.54))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := PackedVector2Array([
		Vector2(-r * 1.30, -r * 0.30), Vector2(-r * 0.48, -r * 0.62),
		Vector2(r * 0.62, -r * 0.52), Vector2(r * 1.06, -r * 0.10),
		Vector2(r * 0.82, r * 0.48), Vector2(-r * 0.42, r * 0.56),
	])
	_draw_beveled(body, cloth.darkened(0.26), cloth.lightened(0.04), 1.0)
	var head := PackedVector2Array([
		Vector2(r * 0.78, -r * 0.38), Vector2(r * 1.30, -r * 0.22),
		Vector2(r * 1.36, r * 0.18), Vector2(r * 0.88, r * 0.35),
	])
	_draw_beveled(head, skin.darkened(0.34), skin.darkened(0.12), 0.75)
	# One displaced arm and bent leg prevent the corpse reading as a single icon.
	_draw_limb(Vector2(r * 0.28, r * 0.42), Vector2(r * 0.86, r * 0.92), r * 0.22, cloth.darkened(0.30), cloth, 0.12)
	_draw_limb(Vector2(-r * 0.72, -r * 0.34), Vector2(-r * 1.42, -r * 0.78), r * 0.25, cloth.darkened(0.32), cloth, 0.10)


func _draw_limb(a: Vector2, b: Vector2, width: float, color: Color, rim: Color, rim_alpha: float) -> void:
	var pts := _segment_points(a, b, width)
	_draw_beveled(pts, color, Color(rim.r, rim.g, rim.b, rim.a * rim_alpha), maxf(0.7, width * 0.10))


func _draw_boot(pos: Vector2, r: float, color: Color, rim: Color, stride: float) -> void:
	var toe := r * (0.42 + maxf(0.0, stride) * 0.08)
	var pts := PackedVector2Array([
		pos + Vector2(-r * 0.22, -r * 0.22),
		pos + Vector2(toe, -r * 0.18),
		pos + Vector2(toe + r * 0.14, 0.0),
		pos + Vector2(toe, r * 0.18),
		pos + Vector2(-r * 0.22, r * 0.22),
	])
	_draw_beveled(pts, color.darkened(0.12), Color(rim.r, rim.g, rim.b, rim.a * 0.25), 0.9)


func _draw_glove(pos: Vector2, r: float, color: Color, rim: Color) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(-r * 0.16, -r * 0.22), pos + Vector2(r * 0.25, -r * 0.18),
		pos + Vector2(r * 0.34, 0.0), pos + Vector2(r * 0.22, r * 0.20),
		pos + Vector2(-r * 0.16, r * 0.18),
	])
	_draw_beveled(pts, color, Color(rim.r, rim.g, rim.b, rim.a * 0.20), 0.75)


func _draw_beveled(points: PackedVector2Array, fill: Color, edge: Color, width: float) -> void:
	if points.size() < 3:
		return
	var shadow := PackedVector2Array()
	for p in points:
		shadow.append(p + Vector2(0.8, 1.1))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.26 * fill.a))
	draw_colored_polygon(points, fill)
	var loop := points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, edge, width, true)


func _segment_points(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var delta := b - a
	var dir := delta.normalized() if delta.length_squared() > 0.0001 else Vector2.RIGHT
	var n := Vector2(-dir.y, dir.x) * width * 0.5
	var cap := dir * width * 0.22
	return PackedVector2Array([a - cap + n, b + cap + n, b + cap - n, a - cap - n])


func _draw_segmented_ring(center: Vector2, radius: float, color: Color, segments: int, rotation_offset: float) -> void:
	for i in range(segments):
		var a0 := rotation_offset + TAU * float(i) / float(segments)
		var a1 := a0 + TAU / float(segments) * 0.58
		draw_arc(center, radius, a0, a1, 8, color, 1.5, true)


func _is_feeding() -> bool:
	if entity == null or entity.behaviour == null:
		return false
	if entity.kind == "player":
		return int(entity.behaviour.get("feeding_target_id")) != 0
	return entity.ai_state == "fed"


func _flash(color: Color, hit_ratio: float) -> Color:
	var amount := sin(hit_ratio * PI) * 0.82
	return color.lerp(Color(1.0, 0.88, 0.86, color.a), amount)


func _smooth(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _resonance_color(humour: String) -> Color:
	match humour:
		"sanguine": return Color("#b93448")
		"choleric": return Color("#b56a2b")
		"melancholic": return Color("#52689e")
		"phlegmatic": return Color("#4f8e71")
	return Color("#707078")


func _make_palette(e: SimEntity) -> Dictionary:
	var variation := float((e.id * 37) % 13) / 100.0
	if e.kind == "player":
		return {
			"cloth": Color("#25252e").lightened(variation), "cloth_dark": Color("#101116"),
			"leather": Color("#171519"), "metal": Color("#59606b"), "skin": Color("#b9aaa2"),
			"accent": Color("#d32237"), "rim": Color(0.54, 0.66, 0.82, 0.64),
			"build": 1.0, "gear": "coat", "weapon": "claws", "hooded": true,
			"helmeted": false, "predator_eyes": true, "long_coat": true,
		}
	match String(e.faction):
		"civ":
			var civs := [
				{"cloth": Color("#4a4843"), "cloth_dark": Color("#292825"), "leather": Color("#25221f"), "metal": Color("#686866"), "skin": Color("#b9957d"), "accent": Color("#765f4a"), "rim": Color(0.54, 0.59, 0.66, 0.45), "build": 0.94, "gear": "coat", "weapon": "hands", "hooded": false, "helmeted": false, "predator_eyes": false, "long_coat": false},
				{"cloth": Color("#35414c"), "cloth_dark": Color("#202831"), "leather": Color("#24282a"), "metal": Color("#747c82"), "skin": Color("#c1a087"), "accent": Color("#526a78"), "rim": Color(0.56, 0.64, 0.73, 0.46), "build": 1.0, "gear": "coat", "weapon": "hands", "hooded": true, "helmeted": false, "predator_eyes": false, "long_coat": false},
				{"cloth": Color("#524039"), "cloth_dark": Color("#2d2421"), "leather": Color("#2b211d"), "metal": Color("#6a635e"), "skin": Color("#9f765d"), "accent": Color("#73513e"), "rim": Color(0.62, 0.57, 0.55, 0.42), "build": 1.06, "gear": "coat", "weapon": "hands", "hooded": false, "helmeted": false, "predator_eyes": false, "long_coat": false},
			]
			return civs[e.id % civs.size()]
		"gang":
			return {"cloth": Color("#342b25").lightened(variation), "cloth_dark": Color("#171411"), "leather": Color("#241b16"), "metal": Color("#67605a"), "skin": Color("#9d7358"), "accent": Color("#8a2b2b"), "rim": Color(0.61, 0.52, 0.47, 0.48), "build": 1.18, "gear": "vest", "weapon": "bat" if e.id % 2 == 0 else "knife", "hooded": false, "helmeted": false, "predator_eyes": false, "long_coat": false}
		"police":
			return {"cloth": Color("#17243a").lightened(variation), "cloth_dark": Color("#0b111c"), "leather": Color("#11151b"), "metal": Color("#58677b"), "skin": Color("#aa8974"), "accent": Color("#a8b9d4"), "rim": Color(0.58, 0.69, 0.86, 0.62), "build": 1.12, "gear": "armor", "weapon": "pistol", "hooded": false, "helmeted": true, "predator_eyes": false, "long_coat": false}
		"inquis":
			return {"cloth": Color("#202027").lightened(variation), "cloth_dark": Color("#0d0d11"), "leather": Color("#191617"), "metal": Color("#807b70"), "skin": Color("#b2a58f"), "accent": Color("#d1c4a7"), "rim": Color(0.69, 0.70, 0.70, 0.60), "build": 1.08, "gear": "hunter", "weapon": "shotgun", "hooded": true, "helmeted": false, "predator_eyes": false, "long_coat": true}
		"player":
			return {"cloth": Color("#30253b"), "cloth_dark": Color("#17101f"), "leather": Color("#1d1624"), "metal": Color("#635779"), "skin": Color("#aa91ad"), "accent": Color("#8250b1"), "rim": Color(0.66, 0.58, 0.78, 0.58), "build": 1.0, "gear": "coat", "weapon": "claws", "hooded": true, "helmeted": false, "predator_eyes": true, "long_coat": true}
	return {"cloth": Color("#3a3a42"), "cloth_dark": Color("#1c1c22"), "leather": Color("#222228"), "metal": Color("#6a6a72"), "skin": Color("#a18f82"), "accent": Color("#777982"), "rim": Color(0.58, 0.62, 0.70, 0.48), "build": 1.0, "gear": "coat", "weapon": "hands", "hooded": false, "helmeted": false, "predator_eyes": false, "long_coat": false}
