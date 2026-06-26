## EntityRenderer.gd — cinematic procedural 2.5D character presentation.
##
## Drop-in replacement for the previous circle-based renderer. It preserves the Sim/view
## contract: this node only reads SimEntity state and CueBus events. Every living actor is
## rendered as an articulated, faceted mesh with continuous pose curves, faction silhouettes,
## equipment, contact shadows, hit reactions, action-frame timing, and render interpolation.
## No sprite sheets and no 3–4 frame animation loops are used.
extends Node2D
class_name EntityRenderer

const BASE_RADIUS := 12.0
const HEIGHT_SCALE := 0.78
const SIDE_SCALE := 0.82
const TRACK_RESPONSE := 22.0
const HIT_REACTION_DUR := 0.20
const DASH_GHOST_DUR := 0.38
const MUZZLE_DUR := 0.075
const MAX_TRAIL_POINTS := 7
const HIGH_DETAIL_CAP := 56

var _entities: Array[SimEntity] = []
var _tracks: Dictionary = {}
var _t: float = 0.0
var _frame_counter: int = 0


func setup(entities: Array[SimEntity]) -> void:
	_entities = entities


func _ready() -> void:
	z_index = 20
	if CueBus != null and not CueBus.cue_emitted.is_connected(_on_cue):
		CueBus.cue_emitted.connect(_on_cue)


func _on_cue(event_id: String, payload: Dictionary) -> void:
	var id := int(payload.get("entity_id", payload.get("target_id", 0)))
	if id <= 0:
		return
	var tr := _track_for_id(id)
	match event_id:
		"move.dash":
			tr["dash"] = DASH_GHOST_DUR
		"attack.start":
			tr["attack_pulse"] = 0.18
			var actor := _entity_by_id(id)
			if actor != null and String(actor.tags.get("weapon", "")) in ["pistol", "rifle"]:
				tr["muzzle"] = MUZZLE_DUR
		"damage.dealt", "damage.player", "hit.connect":
			var target_id := int(payload.get("target_id", id))
			if target_id > 0:
				var hit_tr := _track_for_id(target_id)
				hit_tr["hit"] = HIT_REACTION_DUR
				hit_tr["hit_dir"] = _impact_direction(payload, target_id)
		"projectile.bounce":
			tr["bounce"] = 0.12
	_tracks[id] = tr


func _impact_direction(payload: Dictionary, target_id: int) -> Vector2:
	var target := _entity_by_id(target_id)
	var attacker := _entity_by_id(int(payload.get("attacker_id", 0)))
	if target != null and attacker != null:
		var delta := target.pos - attacker.pos
		if delta.length_squared() > 0.01:
			return delta.normalized()
	return Vector2.RIGHT


func _track_for_id(id: int) -> Dictionary:
	if _tracks.has(id):
		return _tracks[id]
	var actor := _entity_by_id(id)
	var p := actor.pos if actor != null else Vector2.ZERO
	var tr := {
		"visual_pos": p,
		"last_sim_pos": p,
		"phase": float(id % 17) * 0.37,
		"speed": 0.0,
		"hit": 0.0,
		"hit_dir": Vector2.RIGHT,
		"dash": 0.0,
		"muzzle": 0.0,
		"bounce": 0.0,
		"attack_pulse": 0.0,
		"trail": [],
		"trail_clock": 0.0,
	}
	_tracks[id] = tr
	return tr


func _entity_by_id(id: int) -> SimEntity:
	if id <= 0:
		return null
	for e in _entities:
		if e != null and e.id == id:
			return e
	return null


func _process(delta: float) -> void:
	_t += delta
	_frame_counter += 1
	var live_ids: Dictionary = {}
	for e in _entities:
		if e == null:
			continue
		live_ids[e.id] = true
		var tr := _track_for_id(e.id)
		var last_sim: Vector2 = tr["last_sim_pos"]
		var moved := last_sim.distance_to(e.pos)
		var measured_speed := moved / maxf(delta, 0.0001)
		tr["speed"] = lerpf(float(tr["speed"]), measured_speed, 1.0 - exp(-delta * 12.0))
		if moved > 0.02:
			tr["phase"] = float(tr["phase"]) + moved * 0.115
		tr["last_sim_pos"] = e.pos

		var visual: Vector2 = tr["visual_pos"]
		if visual.distance_to(e.pos) > 180.0:
			visual = e.pos
		else:
			visual = visual.lerp(e.pos, 1.0 - exp(-delta * TRACK_RESPONSE))
		tr["visual_pos"] = visual

		for key in ["hit", "dash", "muzzle", "bounce", "attack_pulse"]:
			tr[key] = maxf(0.0, float(tr[key]) - delta)

		tr["trail_clock"] = float(tr["trail_clock"]) + delta
		if float(tr["dash"]) > 0.0 and float(tr["trail_clock"]) >= 0.035:
			tr["trail_clock"] = 0.0
			var trail: Array = tr["trail"]
			trail.push_front(visual)
			if trail.size() > MAX_TRAIL_POINTS:
				trail.resize(MAX_TRAIL_POINTS)
			tr["trail"] = trail
		elif float(tr["dash"]) <= 0.0 and not tr["trail"].is_empty():
			var trail2: Array = tr["trail"]
			trail2.pop_back()
			tr["trail"] = trail2
		_tracks[e.id] = tr

	if _frame_counter % 120 == 0:
		for id in _tracks.keys():
			if not live_ids.has(id):
				_tracks.erase(id)
	queue_redraw()


func _draw() -> void:
	var actors: Array = []
	var vehicles: Array = []
	var projectiles: Array = []
	for e in _entities:
		if e == null:
			continue
		if e.kind == "vehicle":
			vehicles.append(e)
		elif e.kind == "projectile":
			projectiles.append(e)
		else:
			actors.append(e)

	actors.sort_custom(func(a, b): return _visual_pos(a).y < _visual_pos(b).y)
	vehicles.sort_custom(func(a, b): return a.pos.y < b.pos.y)

	for e in vehicles:
		if not e.dead:
			_draw_vehicle(e)
	for e in actors:
		if e.dead:
			_draw_corpse(e)
		elif e.downed or e.ai_state in ["downed", "fed", "carried"]:
			_draw_downed(e)
		else:
			_draw_actor(e, actors.size() <= HIGH_DETAIL_CAP)
	for e in projectiles:
		if not e.dead:
			_draw_projectile(e)


func _visual_pos(e: SimEntity) -> Vector2:
	if _tracks.has(e.id):
		return _tracks[e.id].get("visual_pos", e.pos)
	return e.pos


# -----------------------------------------------------------------------------
# Pose generation

func _draw_actor(e: SimEntity, high_detail: bool) -> void:
	var tr := _track_for_id(e.id)
	var root := _visual_pos(e)
	var pal := _palette(e)
	var pose := _build_pose(e, tr)
	var scale := (e.radius / BASE_RADIUS) * float(pal.get("build", 1.0))

	_draw_resonance(e, root)
	_draw_dash_trail(e, tr, pal, scale)
	_draw_contact_shadow(root, e.radius * float(pal.get("build", 1.0)), float(tr["dash"]))
	_draw_coat_back(e, pose, root, scale, pal)

	var joints := _project_pose(pose, root, e.facing, scale)
	var far_side := -1 if cos(e.facing) >= 0.0 else 1
	var far_leg := "l" if far_side < 0 else "r"
	var near_leg := "r" if far_side < 0 else "l"
	var far_arm := far_leg
	var near_arm := near_leg

	_draw_leg(joints, far_leg, pal, 0.78)
	_draw_arm(joints, far_arm, pal, 0.76)
	_draw_torso(e, joints, pal, high_detail)
	_draw_leg(joints, near_leg, pal, 1.0)
	_draw_arm(joints, near_arm, pal, 1.0)
	_draw_head(e, joints, pal, high_detail)
	_draw_weapon(e, joints, pal, float(tr["muzzle"]))
	_draw_status(e, root)
	_draw_alert(e, root)


func _build_pose(e: SimEntity, tr: Dictionary) -> Dictionary:
	var phase := float(tr["phase"])
	var speed := clampf(float(tr["speed"]) / 220.0, 0.0, 1.45)
	var gait := sin(phase)
	var gait_opposite := sin(phase + PI)
	var bob := absf(sin(phase * 2.0)) * 1.35 * minf(speed, 1.0)
	var breath := sin(_t * 1.75 + float(e.id) * 0.41) * 0.38
	var dash := clampf(float(tr["dash"]) / DASH_GHOST_DUR, 0.0, 1.0)
	var hit := clampf(float(tr["hit"]) / HIT_REACTION_DUR, 0.0, 1.0)
	var action := _action_envelope(e)
	var attack_drive := float(action.get("drive", 0.0))
	var windup := float(action.get("windup", 0.0))
	var heavy := bool(action.get("heavy", false))
	var crouch := dash * 7.0
	var lean := speed * 2.3 + attack_drive * (5.2 if heavy else 3.7) - windup * 2.8
	lean -= hit * 4.8

	var hit_side := signf((_track_hit_dir(tr)).rotated(-e.facing).y)
	var hip_z := 11.0 - crouch + bob * 0.45
	var chest_z := 25.0 - crouch * 0.55 + bob + breath
	var shoulder_z := chest_z + 3.2
	var stride := minf(speed, 1.0)

	var pose := {
		"pelvis": Vector3(lean * 0.18, 0.0, hip_z),
		"chest": Vector3(lean, hit_side * hit * 1.5, chest_z),
		"neck": Vector3(lean + 1.2, 0.0, chest_z + 6.2),
		"head": Vector3(lean + 2.2, -hit_side * hit * 1.0, chest_z + 12.0),
		"hip_l": Vector3(-1.5, -3.2, hip_z - 1.0),
		"hip_r": Vector3(-1.5, 3.2, hip_z - 1.0),
		"shoulder_l": Vector3(lean - 0.2, -6.1, shoulder_z),
		"shoulder_r": Vector3(lean - 0.2, 6.1, shoulder_z),
	}

	pose["knee_l"] = Vector3(-2.0 + gait * 5.2 * stride, -3.5, 5.6 + maxf(0.0, -gait) * 2.2 * stride)
	pose["foot_l"] = Vector3(-5.0 + gait * 8.2 * stride, -3.8, 0.7 + maxf(0.0, -gait) * 1.1 * stride)
	pose["knee_r"] = Vector3(-2.0 + gait_opposite * 5.2 * stride, 3.5, 5.6 + maxf(0.0, -gait_opposite) * 2.2 * stride)
	pose["foot_r"] = Vector3(-5.0 + gait_opposite * 8.2 * stride, 3.8, 0.7 + maxf(0.0, -gait_opposite) * 1.1 * stride)

	var arm_swing := 6.0 * stride
	var hand_l := Vector3(-1.0 - gait * arm_swing, -7.2, 16.0 + gait_opposite * 1.6 * stride)
	var hand_r := Vector3(-1.0 - gait_opposite * arm_swing, 7.2, 16.0 + gait * 1.6 * stride)

	var weapon := String(e.tags.get("weapon", ""))
	if weapon in ["rifle", "pistol"] and e.hostile_to_player:
		var aim_raise := 1.0 if e.ai_state in ["attack", "chase"] else 0.45
		hand_r = hand_r.lerp(Vector3(13.5, 4.5, 23.0), aim_raise)
		hand_l = hand_l.lerp(Vector3(9.0, -3.0, 22.0), aim_raise if weapon == "rifle" else 0.35)
	elif weapon == "bat" and e.ai_state in ["attack", "chase"]:
		hand_r = hand_r.lerp(Vector3(5.0 - windup * 8.0 + attack_drive * 13.0, 6.0, 22.0 + windup * 5.0), maxf(windup, attack_drive))

	if attack_drive > 0.0 or windup > 0.0:
		var attack_weight := clampf(maxf(attack_drive, windup), 0.0, 1.0)
		var reach := 17.0 + (5.0 if heavy else 0.0)
		hand_r = hand_r.lerp(Vector3(reach * attack_drive - 8.0 * windup, 4.2 - attack_drive * 2.5, 22.0 + windup * 4.0), attack_weight)
		hand_l = hand_l.lerp(Vector3((reach - 3.0) * attack_drive - 5.0 * windup, -4.8 + attack_drive * 2.0, 21.0 + windup * 3.0), attack_weight * (0.75 if heavy else 0.48))

	if dash > 0.0:
		hand_l = Vector3(0.0, -4.5, 13.5)
		hand_r = Vector3(1.0, 4.5, 13.0)
		pose["knee_l"] = Vector3(2.5, -3.0, 5.0)
		pose["knee_r"] = Vector3(-1.0, 3.0, 4.0)
		pose["foot_l"] = Vector3(-2.0, -3.4, 1.0)
		pose["foot_r"] = Vector3(-5.0, 3.4, 0.7)

	if hit > 0.0:
		hand_l += Vector3(-5.0 * hit, -4.0 * hit_side, 5.0 * hit)
		hand_r += Vector3(-6.0 * hit, 4.0 * hit_side, 4.0 * hit)

	pose["hand_l"] = hand_l
	pose["hand_r"] = hand_r
	pose["elbow_l"] = _elbow(Vector3(pose["shoulder_l"]), hand_l, -1.0, 3.4)
	pose["elbow_r"] = _elbow(Vector3(pose["shoulder_r"]), hand_r, 1.0, 3.4)
	pose["coat_sway"] = clampf(gait * speed * 2.8 - attack_drive * 2.0, -4.0, 4.0)
	pose["dash"] = dash
	return pose


func _track_hit_dir(tr: Dictionary) -> Vector2:
	var d: Vector2 = tr.get("hit_dir", Vector2.RIGHT)
	return d.normalized() if d.length_squared() > 0.001 else Vector2.RIGHT


func _elbow(shoulder: Vector3, hand: Vector3, side: float, bend: float) -> Vector3:
	var midpoint := (shoulder + hand) * 0.5
	var dx := hand.x - shoulder.x
	var dy := hand.y - shoulder.y
	var planar_len := maxf(sqrt(dx * dx + dy * dy), 0.001)
	midpoint.x += (-dy / planar_len) * bend * side
	midpoint.y += (dx / planar_len) * bend * side
	midpoint.z += 1.8
	return midpoint


func _action_envelope(e: SimEntity) -> Dictionary:
	if e.current_action == null or e.current_action.def == null:
		return {"drive": 0.0, "windup": 0.0, "heavy": false}
	var def: ActionDef = e.current_action.def
	var frame := float(e.action_frame)
	var startup := maxf(float(def.startup), 1.0)
	var active := maxf(float(def.active), 1.0)
	var recovery := maxf(float(def.recovery), 1.0)
	var drive := 0.0
	var windup := 0.0
	if frame < startup:
		windup = _ease(frame / startup)
	elif frame < startup + active:
		var p := (frame - startup) / active
		drive = 0.72 + 0.28 * sin(p * PI)
		windup = 1.0 - _ease(p)
	else:
		var p2 := clampf((frame - startup - active) / recovery, 0.0, 1.0)
		drive = 1.0 - _ease(p2)
	return {
		"drive": drive,
		"windup": windup,
		"heavy": String(def.id).contains("heavy") or def.damage >= 20.0,
	}


func _ease(v: float) -> float:
	var x := clampf(v, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _project_pose(pose: Dictionary, root: Vector2, facing: float, scale: float) -> Dictionary:
	var out: Dictionary = {}
	for key in pose.keys():
		if pose[key] is Vector3:
			out[key] = _project(root, facing, pose[key], scale)
	return out


func _project(root: Vector2, facing: float, local: Vector3, scale: float) -> Vector2:
	var planar := Vector2(local.x, local.y * SIDE_SCALE).rotated(facing) * scale
	return root + planar + Vector2(0.0, -local.z * HEIGHT_SCALE * scale)


# -----------------------------------------------------------------------------
# Mesh rendering

func _draw_contact_shadow(root: Vector2, radius: float, dash_time: float) -> void:
	var squash := 0.72 + clampf(dash_time / DASH_GHOST_DUR, 0.0, 1.0) * 0.35
	_draw_ellipse(root + Vector2(0, 2.0), Vector2(radius * 1.15 * squash, radius * 0.43), Color(0.0, 0.0, 0.0, 0.48), 24)
	_draw_ellipse(root + Vector2(1.5, 1.0), Vector2(radius * 0.62, radius * 0.20), Color(0.0, 0.0, 0.0, 0.32), 18)


func _draw_dash_trail(e: SimEntity, tr: Dictionary, pal: Dictionary, scale: float) -> void:
	var trail: Array = tr["trail"]
	if trail.is_empty():
		return
	var alpha := clampf(float(tr["dash"]) / DASH_GHOST_DUR, 0.0, 1.0)
	for i in range(trail.size() - 1, -1, -1):
		var p: Vector2 = trail[i]
		var fade := alpha * (1.0 - float(i) / float(maxi(1, trail.size()))) * 0.16
		var forward := Vector2.RIGHT.rotated(e.facing)
		var side := Vector2(-forward.y, forward.x)
		var h := 22.0 * scale
		var w := 6.5 * scale
		_poly([
			p - forward * 6.0 * scale - side * w,
			p + forward * 4.0 * scale - side * w * 0.75 - Vector2(0, h),
			p + forward * 7.0 * scale + side * w * 0.75 - Vector2(0, h),
			p - forward * 7.0 * scale + side * w,
		], _with_alpha(_color(pal["cloth"]), fade))


func _draw_coat_back(e: SimEntity, pose: Dictionary, root: Vector2, scale: float, pal: Dictionary) -> void:
	if not bool(pal.get("long_coat", false)):
		return
	var sway := float(pose.get("coat_sway", 0.0))
	var pelvis := _project(root, e.facing, pose["pelvis"], scale)
	var chest := _project(root, e.facing, pose["chest"], scale)
	var back := Vector2.LEFT.rotated(e.facing)
	var side := Vector2(-back.y, back.x)
	var tail_end := pelvis + back * (12.0 + absf(sway)) * scale + side * sway * scale + Vector2(0, 5.5 * scale)
	var poly := [
		chest + side * 6.2 * scale,
		chest - side * 6.2 * scale,
		tail_end - side * 6.6 * scale,
		tail_end + side * 6.6 * scale,
	]
	_poly(poly, _color(pal["cloth_shadow"]))
	var seam := tail_end - back * 3.0 * scale
	draw_line(chest, seam, _with_alpha(_color(pal["cloth_light"]), 0.34), 0.8 * scale, true)


func _draw_leg(j: Dictionary, side: String, pal: Dictionary, opacity: float) -> void:
	var hip: Vector2 = j["hip_%s" % side]
	var knee: Vector2 = j["knee_%s" % side]
	var foot: Vector2 = j["foot_%s" % side]
	var pants := _with_alpha(_color(pal["pants"]), opacity)
	_draw_limb(hip, knee, 3.2, 2.55, pants, _color(pal["outline"]), opacity)
	_draw_limb(knee, foot, 2.55, 2.0, pants.darkened(0.10), _color(pal["outline"]), opacity)
	_draw_boot(knee, foot, pal, opacity)


func _draw_boot(knee: Vector2, foot: Vector2, pal: Dictionary, opacity: float) -> void:
	var d := foot - knee
	if d.length_squared() < 0.001:
		return
	var dir := d.normalized()
	var n := Vector2(-dir.y, dir.x)
	var toe := foot + dir * 3.2
	_poly([foot - n * 2.3, toe - n * 1.8, toe + n * 1.8, foot + n * 2.3], _with_alpha(_color(pal["boot"]), opacity))


func _draw_arm(j: Dictionary, side: String, pal: Dictionary, opacity: float) -> void:
	var shoulder: Vector2 = j["shoulder_%s" % side]
	var elbow: Vector2 = j["elbow_%s" % side]
	var hand: Vector2 = j["hand_%s" % side]
	var sleeve := _with_alpha(_color(pal["cloth_shadow"] if opacity < 0.9 else pal["cloth"]), opacity)
	_draw_limb(shoulder, elbow, 3.0, 2.35, sleeve, _color(pal["outline"]), opacity)
	_draw_limb(elbow, hand, 2.35, 1.65, sleeve.darkened(0.06), _color(pal["outline"]), opacity)
	_draw_facet(hand, 2.25, _with_alpha(_color(pal["skin"]), opacity), _color(pal["outline"]), 5)


func _draw_torso(e: SimEntity, j: Dictionary, pal: Dictionary, high_detail: bool) -> void:
	var sl: Vector2 = j["shoulder_l"]
	var sr: Vector2 = j["shoulder_r"]
	var hl: Vector2 = j["hip_l"]
	var hr: Vector2 = j["hip_r"]
	var chest: Vector2 = j["chest"]
	var outline := _color(pal["outline"])
	_poly([sl, sr, hr, hl], outline)
	var inset := 0.90
	_poly([
		chest.lerp(sl, inset), chest.lerp(sr, inset),
		chest.lerp(hr, inset), chest.lerp(hl, inset),
	], _color(pal["cloth"]))

	# Asymmetric light planes produce volume without spherical body parts.
	_poly([sl, chest, hl], _with_alpha(_color(pal["cloth_light"]), 0.52))
	_poly([sr, hr, chest], _with_alpha(_color(pal["cloth_shadow"]), 0.72))
	if bool(pal.get("armor", false)):
		var plate_top := sl.lerp(sr, 0.20)
		var plate_top_r := sl.lerp(sr, 0.80)
		var plate_bottom := hl.lerp(hr, 0.27)
		var plate_bottom_r := hl.lerp(hr, 0.73)
		_poly([plate_top, plate_top_r, plate_bottom_r, plate_bottom], _color(pal["armor_plate"]))
		draw_polyline(PackedVector2Array([plate_top, plate_bottom_r]), _with_alpha(_color(pal["metal"]), 0.38), 1.0, true)
	if high_detail:
		draw_line(sl.lerp(sr, 0.5), hl.lerp(hr, 0.5), _with_alpha(_color(pal["accent"]), 0.46), 0.9, true)
		if e.kind == "player":
			var clasp := sl.lerp(sr, 0.5).lerp(hl.lerp(hr, 0.5), 0.28)
			_draw_facet(clasp, 1.7, _color(pal["accent"]), outline, 4)


func _draw_head(e: SimEntity, j: Dictionary, pal: Dictionary, high_detail: bool) -> void:
	var head: Vector2 = j["head"]
	var neck: Vector2 = j["neck"]
	var forward := Vector2.RIGHT.rotated(e.facing)
	var side := Vector2(-forward.y, forward.x)
	var radius := e.radius / BASE_RADIUS * float(pal.get("build", 1.0))
	var rx := 4.8 * radius
	var ry := 5.6 * radius
	var outline := _color(pal["outline"])
	var silhouette := [
		head + forward * rx,
		head + forward * rx * 0.25 + side * ry,
		head - forward * rx * 0.72 + side * ry * 0.72,
		head - forward * rx,
		head - forward * rx * 0.72 - side * ry * 0.72,
		head + forward * rx * 0.25 - side * ry,
	]
	_poly(silhouette, outline)
	var inset: Array[Vector2] = []
	for p in silhouette:
		inset.append(head.lerp(p, 0.87))
	_poly(inset, _color(pal["hood"] if pal.get("hooded", false) else pal["skin"]))

	if bool(pal.get("hooded", false)):
		var cowl := [
			neck - side * 7.4 * radius,
			head - forward * 4.6 * radius - side * 5.7 * radius,
			head - forward * 6.7 * radius,
			head - forward * 4.6 * radius + side * 5.7 * radius,
			neck + side * 7.4 * radius,
		]
		_poly(cowl, _color(pal["hood"]))
		_poly([head + forward * 4.0 * radius, head + side * 3.3 * radius, head - side * 3.3 * radius], _color(pal["face_shadow"]))
	else:
		_poly([head + forward * 4.0 * radius, head + side * 3.6 * radius, head - side * 3.6 * radius], _color(pal["skin_light"]))

	if bool(pal.get("eyes", false)):
		var eye_center := head + forward * 3.4 * radius
		for s in [-1.0, 1.0]:
			var eye := eye_center + side * s * 1.65 * radius
			draw_line(eye - side * 0.9 * radius, eye + side * 0.9 * radius, _color(pal["eye"]), 1.45 * radius, true)
			if high_detail:
				_draw_ellipse(eye, Vector2(2.0, 1.1) * radius, _with_alpha(_color(pal["eye"]), 0.23), 10)
	elif high_detail:
		var brow := head + forward * 3.0 * radius
		draw_line(brow - side * 1.8 * radius, brow + side * 1.8 * radius, _color(pal["face_shadow"]), 0.8 * radius, true)


func _draw_weapon(e: SimEntity, j: Dictionary, pal: Dictionary, muzzle_time: float) -> void:
	var weapon := String(e.tags.get("weapon", ""))
	var hand_r: Vector2 = j["hand_r"]
	var hand_l: Vector2 = j["hand_l"]
	var forward := Vector2.RIGHT.rotated(e.facing)
	var side := Vector2(-forward.y, forward.x)
	var metal := _color(pal["metal"])
	match weapon:
		"bat":
			var tip := hand_r + forward * 17.0 - side * 2.0
			_draw_limb(hand_r, tip, 2.2, 1.55, Color("#69584a"), _color(pal["outline"]), 1.0)
			draw_line(hand_r.lerp(tip, 0.25), tip, Color("#a99680"), 0.75, true)
		"pistol":
			var muzzle := hand_r + forward * 8.5
			_poly([hand_r - side * 2.0, muzzle - side * 1.25, muzzle + side * 1.25, hand_r + side * 2.0], metal)
			var grip := hand_r - forward * 0.5 + side * 2.0
			draw_line(hand_r, grip + Vector2(0, 3), _color(pal["outline"]), 2.2, true)
			_draw_muzzle_flash(muzzle, forward, side, muzzle_time, pal)
		"rifle":
			var muzzle2 := hand_r + forward * 18.0
			var stock := hand_l - forward * 5.0
			_draw_limb(stock, muzzle2, 2.3, 1.35, metal, _color(pal["outline"]), 1.0)
			_poly([stock - side * 2.7, stock - forward * 5.5, stock + side * 2.7], _color(pal["cloth_shadow"]))
			_draw_muzzle_flash(muzzle2, forward, side, muzzle_time, pal)
		_:
			if e.kind == "player" or bool(pal.get("claws", false)):
				for hand in [hand_l, hand_r]:
					for k in range(3):
						var offset := (float(k) - 1.0) * 1.55
						var base := hand + side * offset
						var tip2 := base + forward * (8.0 + (1.5 if k == 1 else 0.0))
						draw_line(base, tip2, _color(pal["claw"]), 1.15, true)


func _draw_muzzle_flash(origin: Vector2, forward: Vector2, side: Vector2, time_left: float, pal: Dictionary) -> void:
	if time_left <= 0.0:
		return
	var p := clampf(time_left / MUZZLE_DUR, 0.0, 1.0)
	var length := 11.0 * p
	_poly([
		origin,
		origin + forward * length + side * 3.2 * p,
		origin + forward * length * 0.65,
		origin + forward * length - side * 3.2 * p,
	], _with_alpha(Color("#ffd898"), 0.92 * p))
	_draw_ellipse(origin + forward * 3.0, Vector2(4.0, 2.2) * p, _with_alpha(_color(pal["accent"]), 0.35 * p), 12)


func _draw_limb(a: Vector2, b: Vector2, width_a: float, width_b: float, fill: Color, outline: Color, opacity: float) -> void:
	var d := b - a
	if d.length_squared() < 0.001:
		return
	var dir := d.normalized()
	var n := Vector2(-dir.y, dir.x)
	var outline_poly := [a + n * (width_a + 1.2), a - n * (width_a + 1.2), b - n * (width_b + 1.0), b + n * (width_b + 1.0)]
	_poly(outline_poly, _with_alpha(outline, opacity))
	var inner := [a + n * width_a, a - n * width_a, b - n * width_b, b + n * width_b]
	_poly(inner, fill)
	var light := _with_alpha(fill.lightened(0.20), 0.40 * opacity)
	draw_line(a + n * width_a * 0.43, b + n * width_b * 0.43, light, 0.75, true)


func _draw_facet(center: Vector2, radius: float, fill: Color, outline: Color, sides: int = 6) -> void:
	var outer: Array[Vector2] = []
	var inner: Array[Vector2] = []
	for i in range(sides):
		var a := TAU * float(i) / float(sides) - PI * 0.5
		outer.append(center + Vector2.RIGHT.rotated(a) * (radius + 0.8))
		inner.append(center + Vector2.RIGHT.rotated(a) * radius)
	_poly(outer, outline)
	_poly(inner, fill)


func _poly(points: Array, color: Color) -> void:
	if points.size() >= 3:
		draw_colored_polygon(PackedVector2Array(points), color)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color, segments: int) -> void:
	var pts: Array[Vector2] = []
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	_poly(pts, color)


func _color(value: Variant) -> Color:
	var color: Color = value
	return color


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


# -----------------------------------------------------------------------------
# Downed, corpse, projectiles, vehicles, status readability

func _draw_downed(e: SimEntity) -> void:
	var root := _visual_pos(e)
	var pal := _palette(e)
	var forward := Vector2.RIGHT.rotated(e.facing)
	var side := Vector2(-forward.y, forward.x)
	_draw_contact_shadow(root, e.radius * 1.15, 0.0)
	var body_center := root - forward * 2.0 + Vector2(0, -4.0)
	_poly([
		body_center - forward * 8.0 - side * 5.5,
		body_center + forward * 7.0 - side * 4.4,
		body_center + forward * 8.0 + side * 4.4,
		body_center - forward * 8.0 + side * 5.5,
	], _color(pal["cloth_shadow"]))
	var head := body_center + forward * 9.0 - Vector2(0, 3.0)
	_draw_facet(head, 4.0, _color(pal["hood"] if pal.get("hooded", false) else pal["skin"]), _color(pal["outline"]), 6)
	for s in [-1.0, 1.0]:
		draw_line(body_center - side * s * 2.5, root - forward * 5.0 + side * s * 7.0, _color(pal["pants"]), 4.2, true)
	_draw_status(e, root)


func _draw_corpse(e: SimEntity) -> void:
	var root := _visual_pos(e)
	var pal := _palette(e)
	var forward := Vector2.RIGHT.rotated(e.facing + 0.45)
	var side := Vector2(-forward.y, forward.x)
	var blood := Color(0.17, 0.008, 0.022, 0.58)
	var pool: Array[Vector2] = []
	for i in range(18):
		var a := TAU * float(i) / 18.0
		var wobble := 1.0 + 0.12 * sin(float(i * 7 + e.id) * 1.31)
		pool.append(root + Vector2(cos(a) * e.radius * 1.65 * wobble, sin(a) * e.radius * 0.68 * wobble))
	_poly(pool, blood)
	var torso := root - Vector2(0, 3.0)
	_poly([
		torso - forward * 9.0 - side * 5.0,
		torso + forward * 8.0 - side * 5.5,
		torso + forward * 9.0 + side * 5.5,
		torso - forward * 9.0 + side * 5.0,
	], _color(pal["cloth_shadow"]).darkened(0.22))
	var head := torso + forward * 12.0
	_draw_facet(head, 4.2, _color(pal["skin"]).darkened(0.25), _color(pal["outline"]), 6)
	for s in [-1.0, 1.0]:
		draw_line(torso - forward * 5.0 + side * s * 3.0, torso - forward * 13.0 + side * s * 7.0, _color(pal["pants"]).darkened(0.18), 4.0, true)


func _draw_projectile(e: SimEntity) -> void:
	var height := 0.0
	var spin := 0.0
	var ballistic := false
	if e.behaviour != null:
		var h = e.behaviour.get("height")
		if h != null:
			height = float(h)
			ballistic = bool(e.behaviour.get("ballistic"))
		spin = float(e.behaviour.get("spin")) if e.behaviour.get("spin") != null else 0.0
	var ground := e.pos
	var airborne := ground + Vector2(0.0, -height * HEIGHT_SCALE)
	var r := maxf(e.radius, 4.0)
	var shadow_scale := clampf(1.0 - height / 160.0, 0.28, 1.0)
	_draw_ellipse(ground + Vector2(0, 1.0), Vector2(r * 1.15 * shadow_scale, r * 0.42 * shadow_scale), Color(0, 0, 0, 0.42 * shadow_scale), 16)

	var kind := String(e.type_id)
	if ballistic or kind.contains("bomb") or kind.contains("flask") or kind.contains("grenade"):
		var f := Vector2.RIGHT.rotated(spin)
		var s := Vector2(-f.y, f.x)
		_poly([
			airborne - f * r * 0.9 - s * r * 0.58,
			airborne + f * r * 0.8 - s * r * 0.48,
			airborne + f * r * 1.0 + s * r * 0.48,
			airborne - f * r * 0.9 + s * r * 0.58,
		], Color("#44202a"))
		_poly([
			airborne - f * r * 0.55 - s * r * 0.38,
			airborne + f * r * 0.55 - s * r * 0.32,
			airborne + f * r * 0.72 + s * r * 0.32,
			airborne - f * r * 0.55 + s * r * 0.38,
		], Color("#a52336"))
		draw_line(airborne + f * r * 0.78, airborne + f * r * 1.38, Color("#d5b07b"), 1.6, true)
	else:
		var forward := e.vel.normalized() if e.vel.length_squared() > 0.01 else Vector2.RIGHT.rotated(e.facing)
		var tail := airborne - forward * r * 4.0
		draw_line(tail, airborne, Color(0.75, 0.02, 0.11, 0.28), r * 1.15, true)
		draw_line(airborne - forward * r * 2.4, airborne, Color("#ff3650"), r * 0.56, true)
		_draw_facet(airborne, r, Color("#d91432"), Color("#3b0710"), 6)
		_draw_facet(airborne - forward * r * 0.2, r * 0.42, Color("#ffd2d8"), Color("#ff6b79"), 5)


func _draw_vehicle(e: SimEntity) -> void:
	var r := e.radius
	var pos := e.pos
	var length := maxf(r * 2.75, 46.0)
	var width := maxf(r * 1.45, 23.0)
	var police := e.type_id == "police" or e.faction == "police"
	var body := Color("#17233a") if police else Color("#111218")
	draw_set_transform(pos, e.facing, Vector2.ONE)
	draw_rect(Rect2(Vector2(-length * 0.5 + 3, -width * 0.5 + 4), Vector2(length, width)), Color(0, 0, 0, 0.46))
	draw_rect(Rect2(Vector2(-length * 0.5, -width * 0.5), Vector2(length, width)), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-length * 0.18, -width * 0.39), Vector2(length * 0.29, -width * 0.39),
		Vector2(length * 0.20, width * 0.39), Vector2(-length * 0.10, width * 0.39),
	]), body.lightened(0.13))
	draw_rect(Rect2(Vector2(length * 0.05, -width * 0.31), Vector2(length * 0.20, width * 0.62)), Color("#283851"))
	for x in [-length * 0.31, length * 0.31]:
		draw_rect(Rect2(Vector2(x - 4.0, -width * 0.58), Vector2(8.0, 4.0)), Color("#07080b"))
		draw_rect(Rect2(Vector2(x - 4.0, width * 0.40), Vector2(8.0, 4.0)), Color("#07080b"))
	if police:
		draw_rect(Rect2(Vector2(-2.8, -width * 0.60), Vector2(5.6, width * 0.17)), Color("#304a78"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_status(e: SimEntity, pos: Vector2) -> void:
	var radius := e.radius + 7.0
	if e.has_status("burn"):
		draw_arc(pos, radius, -PI * 0.2, PI * 1.2, 22, Color(1.0, 0.34, 0.10, 0.72), 1.6, true)
	if e.has_status("bleed"):
		draw_arc(pos, radius + 2.0, PI * 0.6, PI * 1.85, 22, Color(0.72, 0.02, 0.10, 0.65), 1.4, true)
	if e.has_status("poison"):
		draw_arc(pos, radius + 1.0, 0.0, TAU, 24, Color(0.45, 0.72, 0.22, 0.55), 1.3, true)
	if e.has_status("stun") or e.has_status("mesmerized"):
		var c := Color("#d9b8ff") if e.has_status("mesmerized") else Color("#e8c15b")
		for k in range(3):
			var a := _t * 2.3 + TAU * float(k) / 3.0
			var p := pos + Vector2(cos(a) * radius, sin(a) * radius * 0.34) - Vector2(0, 20)
			_draw_facet(p, 1.4, c, Color(0, 0, 0, 0.5), 4)


func _draw_alert(e: SimEntity, pos: Vector2) -> void:
	if e.kind != "npc" or not (e.hostile_to_player or e.responder):
		return
	var top := pos - Vector2(0, e.radius * 2.6 + 8.0)
	if e.ai_state in ["attack", "chase"] or e.perception_state in ["alert", "combat"]:
		var c := Color(0.95, 0.12, 0.17, 0.82)
		draw_polyline(PackedVector2Array([top + Vector2(-6, 2), top, top + Vector2(6, 2)]), c, 1.8, true)
		draw_line(top, top + Vector2(0, 5), c, 1.2, true)
	elif e.ai_state == "search" or int(e.search_ticks) > 0:
		var c2 := Color(0.82, 0.65, 0.26, 0.72)
		draw_arc(top, 5.2, PI * 1.08, PI * 1.92, 14, c2, 1.5, true)


func _draw_resonance(e: SimEntity, root: Vector2) -> void:
	if e.resonance == "" or not (e.faction == "civ" or e.downed):
		return
	var col := _resonance_color(e.resonance)
	var pulse := 0.55 + 0.45 * sin(_t * 2.1 + float(e.id) * 0.37)
	var radius := e.radius * (1.55 + 0.08 * pulse)
	_draw_ellipse(root + Vector2(0, 1), Vector2(radius, radius * 0.34), _with_alpha(col, 0.055 + 0.035 * pulse), 28)
	draw_arc(root, radius, 0.0, TAU, 30, _with_alpha(col, 0.26 + 0.12 * pulse), 1.25, true)


func _resonance_color(humour: String) -> Color:
	match humour:
		"sanguine": return Color("#c83a4d")
		"choleric": return Color("#d47a35")
		"melancholic": return Color("#617dcc")
		"phlegmatic": return Color("#5aa77d")
	return Color("#777b86")


# -----------------------------------------------------------------------------
# Art direction profiles. Dark, material-led, and faction-readable at combat distance.

func _palette(e: SimEntity) -> Dictionary:
	if e.kind == "player":
		return {
			"outline": Color("#07080c"), "cloth": Color("#20232c"), "cloth_shadow": Color("#11131a"),
			"cloth_light": Color("#424855"), "pants": Color("#101218"), "boot": Color("#090a0e"),
			"skin": Color("#c9beb7"), "skin_light": Color("#e0d6cf"), "face_shadow": Color("#403a40"),
			"hood": Color("#0d0f16"), "accent": Color("#a80f2a"), "metal": Color("#9aa3af"),
			"claw": Color("#d9e1e8"), "eye": Color("#ff263f"), "build": 1.02,
			"hooded": true, "eyes": true, "claws": true, "long_coat": true, "armor": false,
			"armor_plate": Color("#242833"),
		}

	var variant := e.id % 3
	match String(e.faction):
		"civ":
			var coats := [Color("#4c4b47"), Color("#394652"), Color("#59443b")]
			var shadows := [Color("#2a2a27"), Color("#202b34"), Color("#31251f")]
			var skins := [Color("#bd9479"), Color("#d0af98"), Color("#9d715b")]
			return {
				"outline": Color("#111113"), "cloth": coats[variant], "cloth_shadow": shadows[variant],
				"cloth_light": coats[variant].lightened(0.18), "pants": Color("#222329"), "boot": Color("#121317"),
				"skin": skins[variant], "skin_light": skins[variant].lightened(0.16), "face_shadow": skins[variant].darkened(0.42),
				"hood": shadows[variant], "accent": Color("#77746e"), "metal": Color("#85858a"),
				"claw": Color("#c7c7c7"), "eye": Color("#111111"), "build": [0.93, 1.0, 1.06][variant],
				"hooded": variant == 2, "eyes": false, "claws": false, "long_coat": false, "armor": false,
				"armor_plate": Color("#303238"),
			}
		"gang":
			return {
				"outline": Color("#0e0c0a"), "cloth": Color("#302821"), "cloth_shadow": Color("#17130f"),
				"cloth_light": Color("#514238"), "pants": Color("#171616"), "boot": Color("#0b0b0b"),
				"skin": Color("#b18468"), "skin_light": Color("#c79c7e"), "face_shadow": Color("#523c2e"),
				"hood": Color("#211b17"), "accent": Color("#7e1825"), "metal": Color("#807b72"),
				"claw": Color("#c8c8c8"), "eye": Color("#15100d"), "build": 1.16,
				"hooded": false, "eyes": false, "claws": false, "long_coat": false, "armor": false,
				"armor_plate": Color("#2d2924"),
			}
		"police":
			return {
				"outline": Color("#06080d"), "cloth": Color("#17253b"), "cloth_shadow": Color("#0c1422"),
				"cloth_light": Color("#314765"), "pants": Color("#101722"), "boot": Color("#070a0f"),
				"skin": Color("#b99a84"), "skin_light": Color("#d2b39c"), "face_shadow": Color("#55463c"),
				"hood": Color("#101a2a"), "accent": Color("#8ca6d0"), "metal": Color("#9ca8b9"),
				"claw": Color("#d0d5dc"), "eye": Color("#141821"), "build": 1.10,
				"hooded": e.type_id == "swat", "eyes": false, "claws": false, "long_coat": false,
				"armor": e.type_id == "swat", "armor_plate": Color("#26364d"),
			}
		"inquis":
			return {
				"outline": Color("#050507"), "cloth": Color("#1d1e23"), "cloth_shadow": Color("#0c0d10"),
				"cloth_light": Color("#393b43"), "pants": Color("#101115"), "boot": Color("#07080a"),
				"skin": Color("#c5b8a7"), "skin_light": Color("#ddd1c1"), "face_shadow": Color("#4d4841"),
				"hood": Color("#0b0c0f"), "accent": Color("#a79873"), "metal": Color("#b0aaa0"),
				"claw": Color("#d7d1c8"), "eye": Color("#221712"), "build": 1.08 if e.type_id != "elder" else 1.28,
				"hooded": true, "eyes": false, "claws": false, "long_coat": true, "armor": true,
				"armor_plate": Color("#28292e"),
			}
		"player":
			return {
				"outline": Color("#08070b"), "cloth": Color("#2b2235"), "cloth_shadow": Color("#16111c"),
				"cloth_light": Color("#51405f"), "pants": Color("#18121e"), "boot": Color("#0b0910"),
				"skin": Color("#b69aba"), "skin_light": Color("#d0b6d4"), "face_shadow": Color("#47394b"),
				"hood": Color("#17111e"), "accent": Color("#76549b"), "metal": Color("#aaa0b7"),
				"claw": Color("#d5cedd"), "eye": Color("#7a52a3"), "build": 1.0,
				"hooded": true, "eyes": false, "claws": false, "long_coat": true, "armor": false,
				"armor_plate": Color("#30253a"),
			}
	return {
		"outline": Color("#0c0c0f"), "cloth": Color("#3f4148"), "cloth_shadow": Color("#202126"),
		"cloth_light": Color("#585b64"), "pants": Color("#202126"), "boot": Color("#111216"),
		"skin": Color("#ad9583"), "skin_light": Color("#c4ad9a"), "face_shadow": Color("#4f4339"),
		"hood": Color("#282a30"), "accent": Color("#777982"), "metal": Color("#92969e"),
		"claw": Color("#d0d3d8"), "eye": Color("#18181b"), "build": 1.0,
		"hooded": false, "eyes": false, "claws": false, "long_coat": false, "armor": false,
		"armor_plate": Color("#30323a"),
	}
