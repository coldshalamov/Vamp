## CharacterRig2D.gd — continuously animated 2.5D character mesh.
##
## This is a presentation-only articulated rig. It reads SimEntity state but never mutates the
## authoritative simulation. The body is assembled from shaded polygons and jointed limb segments,
## then posed every rendered frame from velocity, facing, ActionDef frame data, hitstop, knockback,
## statuses, and semantic CueBus events. There are no sprite-frame animations and no three-circle
## fallback: every humanoid receives the same full rig with faction-specific clothing and weapons.
extends Node2D
class_name CharacterRig2D

const HIT_REACT_DURATION := 0.24
const DASH_TRAIL_DURATION := 0.30
const TELEPORT_DISTANCE := 180.0
const MAX_AFTERIMAGES := 6

var entity: SimEntity = null
var detail_level: int = 2

var _profile: Dictionary = {}
var _facing: float = 0.0
var _speed_target: float = 0.0
var _speed_blend: float = 0.0
var _gait_phase: float = 0.0
var _time: float = 0.0
var _action_subframe: float = 0.0
var _last_action_frame: int = -1
var _hit_react: float = 0.0
var _hit_side: float = 1.0
var _dash_timer: float = 0.0
var _flash: float = 0.0
var _last_sim_pos: Vector2 = Vector2.ZERO
var _afterimages: Array[Dictionary] = []
var _trail_accum: float = 0.0


func setup(sim_entity: SimEntity) -> void:
	entity = sim_entity
	_profile = _make_profile()
	if entity != null:
		position = entity.pos
		_facing = entity.facing
		_last_sim_pos = entity.pos
		reset_physics_interpolation()
	queue_redraw()


## Called exactly once after each authoritative Sim tick by EntityRenderer.
## Transform writes stay on the physics cadence so Godot's interpolation can smooth them safely.
func physics_sync(delta: float) -> void:
	if entity == null:
		return
	var moved := _last_sim_pos.distance_to(entity.pos)
	var teleported := moved > TELEPORT_DISTANCE
	position = entity.pos
	if teleported:
		reset_physics_interpolation()
	_facing = entity.facing
	_speed_target = clampf(moved / maxf(delta, 0.0001) / 230.0, 0.0, 1.65) if delta > 0.0 else 0.0
	_last_sim_pos = entity.pos

	var frame := entity.action_frame
	if frame != _last_action_frame:
		_last_action_frame = frame
		_action_subframe = 0.0

	if _dash_timer > 0.0 and moved > 2.0:
		_trail_accum += moved
		if _trail_accum >= 7.0:
			_trail_accum = 0.0
			_afterimages.push_back({
				"pos": entity.pos,
				"facing": _facing,
				"age": 0.0,
			})
			while _afterimages.size() > MAX_AFTERIMAGES:
				_afterimages.pop_front()

	# A profile can change at runtime when Dominate converts a target into a thrall.
	var profile_key := "%s:%s:%s" % [entity.kind, entity.faction, entity.type_id]
	if String(_profile.get("key", "")) != profile_key:
		_profile = _make_profile()


## Render-cadence pose blending. This changes only draw parameters, never the node transform or Sim.
func advance_visual(delta: float) -> void:
	if entity == null:
		return
	_time += delta
	var blend := 1.0 - exp(-12.0 * delta)
	_speed_blend = lerpf(_speed_blend, _speed_target, blend)
	if entity.hitstop <= 0:
		_gait_phase += delta * lerpf(2.0, 10.5, clampf(_speed_blend, 0.0, 1.0))
		_action_subframe = minf(_action_subframe + delta * 60.0, 1.0)
	_hit_react = maxf(0.0, _hit_react - delta)
	_dash_timer = maxf(0.0, _dash_timer - delta)
	_flash = maxf(0.0, _flash - delta * 5.8)
	for i in range(_afterimages.size() - 1, -1, -1):
		_afterimages[i]["age"] = float(_afterimages[i]["age"]) + delta
		if float(_afterimages[i]["age"]) >= DASH_TRAIL_DURATION:
			_afterimages.remove_at(i)
	queue_redraw()


func notify_event(event_id: String, payload: Dictionary) -> void:
	if entity == null:
		return
	match event_id:
		"move.dash":
			if int(payload.get("entity_id", 0)) == entity.id:
				_dash_timer = 0.34
				_trail_accum = 99.0
		"damage.dealt", "damage.player", "hit.connect", "projectile.hit":
			if int(payload.get("target_id", 0)) == entity.id:
				_hit_react = HIT_REACT_DURATION
				_flash = 1.0
				var attacker_id := int(payload.get("attacker_id", 0))
				var attacker := Sim.get_entity(attacker_id) if Sim != null and attacker_id != 0 else null
				if attacker != null:
					_hit_side = signf((entity.pos - attacker.pos).cross(Vector2.RIGHT.rotated(_facing)))
					if is_zero_approx(_hit_side):
						_hit_side = 1.0
		"player.respawn":
			if entity.kind == "player":
				position = entity.pos
				reset_physics_interpolation()
				_afterimages.clear()
		_:
			pass


func set_detail_level(level: int) -> void:
	detail_level = clampi(level, 0, 2)


func _draw() -> void:
	if entity == null:
		return
	if entity.dead:
		_draw_corpse()
		return
	if entity.downed or entity.ai_state in ["downed", "fed", "carried"]:
		_draw_downed()
		return
	_draw_resonance()
	_draw_afterimages()
	var pose := _build_pose()
	_draw_shadow(pose)
	_draw_character(pose, 1.0, Vector2.ZERO, false)
	_draw_status()
	_draw_alert()


# ----------------------------------------------------------------------------- pose construction

func _build_pose() -> Dictionary:
	# stature multiplies vertical extents; shoulders multiplies lateral span only.
	var stature := clampf(float(_profile.get("stature", 1.0)), 0.70, 1.40)
	var shoulder_mult := clampf(float(_profile.get("shoulders", 1.0)), 0.80, 1.40)
	var scale_factor := maxf(entity.radius / 12.0, 0.62) * stature
	var build := float(_profile.get("build", 1.0)) * shoulder_mult
	var raw_forward := Vector2.RIGHT.rotated(_facing)
	# Billboarded pseudo-3D projection: preserve world heading but compress depth so figures remain
	# upright and readable rather than looking like paper dolls lying flat on the street.
	var forward := Vector2(raw_forward.x, raw_forward.y * 0.48)
	if forward.length_squared() < 0.001:
		forward = Vector2.RIGHT
	forward = forward.normalized()
	var side := Vector2(-forward.y, forward.x)

	var action := _action_pose()
	var gait := sin(_gait_phase)
	var gait_cos := cos(_gait_phase)
	var locomotion := clampf(_speed_blend, 0.0, 1.0)
	var stride := gait * 5.5 * scale_factor * locomotion
	var lift_l := maxf(0.0, gait_cos) * 2.0 * scale_factor * locomotion
	var lift_r := maxf(0.0, -gait_cos) * 2.0 * scale_factor * locomotion
	var idle_breath := sin(_time * 1.65 + float(entity.id) * 0.37) * 0.65 * scale_factor
	var bob := absf(gait_cos) * 1.25 * scale_factor * locomotion + idle_breath * (1.0 - locomotion)
	if entity.hitstop > 0:
		bob = 0.0

	var hit_amount := _hit_curve()
	var crouch := float(action["crouch"]) + clampf(_dash_timer / 0.34, 0.0, 1.0) * 4.0
	var lunge := float(action["lunge"])
	var recoil := float(action["recoil"])
	var torso_shift := forward * (lunge * 5.0 - recoil * 2.5 - hit_amount * 4.0) * scale_factor
	torso_shift += side * (_hit_side * hit_amount * 2.4 * scale_factor)

	var ground_y := 0.0
	var pelvis := Vector2(0.0, -10.5 * scale_factor + crouch + bob) + torso_shift * 0.35
	var chest := Vector2(0.0, -22.0 * scale_factor + crouch * 0.55 + bob) + torso_shift
	var neck := Vector2(0.0, -28.2 * scale_factor + crouch * 0.40 + bob) + torso_shift * 1.08
	var head := Vector2(0.0, -34.0 * scale_factor + crouch * 0.34 + bob) + torso_shift * 1.12 + forward * 1.3 * scale_factor

	var hip_width := 3.4 * scale_factor * build
	var shoulder_width := 6.2 * scale_factor * build
	var hip_l := pelvis - side * hip_width
	var hip_r := pelvis + side * hip_width
	var shoulder_l := chest - side * shoulder_width
	var shoulder_r := chest + side * shoulder_width

	var foot_l := -side * 3.1 * scale_factor + forward * stride + Vector2(0.0, -lift_l)
	var foot_r := side * 3.1 * scale_factor - forward * stride + Vector2(0.0, -lift_r)
	foot_l.y += ground_y
	foot_r.y += ground_y
	var knee_l := hip_l.lerp(foot_l, 0.52) - forward * 1.8 * scale_factor + Vector2(0.0, -1.5 * scale_factor)
	var knee_r := hip_r.lerp(foot_r, 0.52) + forward * 1.8 * scale_factor + Vector2(0.0, -1.5 * scale_factor)

	var arm_swing := -gait * 4.0 * scale_factor * locomotion
	var hand_l := shoulder_l + Vector2(0.0, 11.5 * scale_factor) + forward * arm_swing
	var hand_r := shoulder_r + Vector2(0.0, 11.5 * scale_factor) - forward * arm_swing
	var elbow_l := shoulder_l.lerp(hand_l, 0.48) - side * 1.7 * scale_factor
	var elbow_r := shoulder_r.lerp(hand_r, 0.48) + side * 1.7 * scale_factor

	var weapon := String(entity.tags.get("weapon", ""))
	var is_ranged := weapon in ["pistol", "rifle"]
	var combat_ready := entity.hostile_to_player or entity.responder or entity.ai_state in ["chase", "attack"]
	if is_ranged and combat_ready and entity.current_action == null:
		hand_r = chest + forward * (10.5 if weapon == "rifle" else 8.0) * scale_factor + side * 1.5 * scale_factor
		hand_l = chest + forward * (7.0 if weapon == "rifle" else 5.2) * scale_factor - side * 1.0 * scale_factor
		elbow_r = shoulder_r.lerp(hand_r, 0.48) + side * 2.2 * scale_factor
		elbow_l = shoulder_l.lerp(hand_l, 0.50) - side * 2.2 * scale_factor

	var anticipate := float(action["anticipate"])
	var strike := float(action["strike"])
	var recover := float(action["recover"])
	var heavy := float(action["heavy"])
	if anticipate + strike + recover > 0.001:
		var attack_reach := (14.0 + heavy * 5.0) * scale_factor
		hand_r = shoulder_r + forward * (attack_reach * strike - 6.0 * anticipate + 5.0 * recover) + side * (4.0 * anticipate - 2.5 * strike) * scale_factor
		hand_l = shoulder_l + forward * ((attack_reach - 4.0 * scale_factor) * strike - 3.5 * anticipate) - side * (3.0 * anticipate) * scale_factor
		elbow_r = shoulder_r.lerp(hand_r, 0.42) + side * (4.0 * anticipate - 1.0 * strike) * scale_factor
		elbow_l = shoulder_l.lerp(hand_l, 0.46) - side * (2.5 * anticipate) * scale_factor

	if entity.stun > 0 or entity.has_status("stun"):
		hand_l = shoulder_l - side * 5.0 * scale_factor + Vector2(0.0, 2.0 * scale_factor)
		hand_r = shoulder_r + side * 5.0 * scale_factor + Vector2(0.0, 2.0 * scale_factor)
		elbow_l = shoulder_l.lerp(hand_l, 0.5) + Vector2(0.0, 3.0 * scale_factor)
		elbow_r = shoulder_r.lerp(hand_r, 0.5) + Vector2(0.0, 3.0 * scale_factor)

	return {
		"s": scale_factor,
		"build": build,
		"forward": forward,
		"side": side,
		"pelvis": pelvis,
		"chest": chest,
		"neck": neck,
		"head": head,
		"hip_l": hip_l,
		"hip_r": hip_r,
		"shoulder_l": shoulder_l,
		"shoulder_r": shoulder_r,
		"knee_l": knee_l,
		"knee_r": knee_r,
		"foot_l": foot_l,
		"foot_r": foot_r,
		"elbow_l": elbow_l,
		"elbow_r": elbow_r,
		"hand_l": hand_l,
		"hand_r": hand_r,
		"strike": strike,
		"anticipate": anticipate,
		"heavy": heavy,
		"weapon": weapon,
		"locomotion": locomotion,
		"hit": hit_amount,
		"head_scale": clampf(float(_profile.get("head_scale", 1.0)), 0.80, 1.25),
	}


func _action_pose() -> Dictionary:
	var out := {
		"anticipate": 0.0,
		"strike": 0.0,
		"recover": 0.0,
		"lunge": 0.0,
		"recoil": 0.0,
		"crouch": 0.0,
		"heavy": 0.0,
	}
	if entity == null or entity.current_action == null or entity.current_action.def == null:
		return out
	var def: ActionDef = entity.current_action.def
	var frame := float(entity.action_frame) + _action_subframe
	var action_id := String(def.id)
	out["heavy"] = 1.0 if action_id.contains("heavy") or action_id.contains("slam") else 0.0
	if action_id == "dash" or action_id.contains("dash"):
		out["crouch"] = 5.0 * _pulse(frame / maxf(float(def.total_ticks()), 1.0))
		out["lunge"] = 0.8
		return out
	if frame < float(def.startup):
		var p := frame / maxf(float(def.startup), 1.0)
		out["anticipate"] = _smoothstep(p)
		out["crouch"] = _smoothstep(p) * (2.0 + float(out["heavy"]) * 2.0)
		out["recoil"] = _smoothstep(p)
	elif frame < float(def.startup + def.active):
		var p := (frame - float(def.startup)) / maxf(float(def.active), 1.0)
		out["strike"] = _ease_out_cubic(p)
		out["lunge"] = sin(p * PI) * (1.0 + float(out["heavy"]) * 0.5)
	else:
		var p := (frame - float(def.startup + def.active)) / maxf(float(def.recovery), 1.0)
		out["recover"] = 1.0 - _smoothstep(clampf(p, 0.0, 1.0))
		out["lunge"] = float(out["recover"]) * 0.35
	return out


func _hit_curve() -> float:
	if _hit_react <= 0.0:
		return 0.0
	var elapsed := 1.0 - _hit_react / HIT_REACT_DURATION
	return sin(clampf(elapsed, 0.0, 1.0) * PI)


# ----------------------------------------------------------------------------- drawing

func _draw_character(pose: Dictionary, alpha: float, offset: Vector2, ghost: bool) -> void:
	var s := float(pose["s"])
	var forward: Vector2 = pose["forward"]
	var side: Vector2 = pose["side"]
	var flash_amount := clampf(_flash, 0.0, 1.0) * (0.0 if ghost else 0.78)
	var base_coat: Color = _profile["coat"]
	var coat: Color = _with_alpha(base_coat.lerp(Color(1.0, 0.92, 0.92), flash_amount), alpha)
	var base_coat_shadow: Color = _profile["coat_shadow"]
	var coat_shadow: Color = _with_alpha(base_coat_shadow.lerp(Color(1.0, 0.88, 0.88), flash_amount), alpha)
	var pants: Color = _with_alpha(_profile["pants"], alpha)
	var base_skin: Color = _profile["skin"]
	var skin: Color = _with_alpha(base_skin.lerp(Color.WHITE, flash_amount * 0.65), alpha)
	var base_hood: Color = _profile["hood"]
	var hood: Color = _with_alpha(base_hood.lerp(Color.WHITE, flash_amount * 0.5), alpha)
	var accent: Color = _with_alpha(_profile["accent"], alpha)
	var metal: Color = _with_alpha(_profile["metal"], alpha)
	var outline := _with_alpha(Color(0.015, 0.018, 0.025, 0.95), alpha)
	var rim := _with_alpha(Color(0.55, 0.67, 0.86, 0.62), alpha * (0.45 if ghost else 1.0))

	var hip_l: Vector2 = pose["hip_l"] + offset
	var hip_r: Vector2 = pose["hip_r"] + offset
	var knee_l: Vector2 = pose["knee_l"] + offset
	var knee_r: Vector2 = pose["knee_r"] + offset
	var foot_l: Vector2 = pose["foot_l"] + offset
	var foot_r: Vector2 = pose["foot_r"] + offset
	var shoulder_l: Vector2 = pose["shoulder_l"] + offset
	var shoulder_r: Vector2 = pose["shoulder_r"] + offset
	var elbow_l: Vector2 = pose["elbow_l"] + offset
	var elbow_r: Vector2 = pose["elbow_r"] + offset
	var hand_l: Vector2 = pose["hand_l"] + offset
	var hand_r: Vector2 = pose["hand_r"] + offset
	var pelvis: Vector2 = pose["pelvis"] + offset
	var chest: Vector2 = pose["chest"] + offset
	var neck: Vector2 = pose["neck"] + offset
	var head: Vector2 = pose["head"] + offset

	# Coat tails/cloth are drawn first. Velocity bends them opposite travel; a restrained secondary
	# oscillation prevents the old "rigid stack of balls" look without turning into a cape cartoon.
	if bool(_profile.get("long_coat", false)) and not ghost:
		var cloth_drag := -forward * (2.0 + 4.0 * clampf(_speed_blend, 0.0, 1.0)) * s
		# Clamp lateral wave so tail vertices never cross each other.
		var raw_wave := sin(_time * 5.2 + float(entity.id)) * 1.2 * s * clampf(_speed_blend, 0.0, 1.0)
		var cloth_wave := side * clampf(raw_wave, -2.8 * s, 2.8 * s)
		var tail_l := pelvis - side * 3.0 * s + Vector2(0.0, 9.5 * s) + cloth_drag + cloth_wave
		var tail_r := pelvis + side * 3.0 * s + Vector2(0.0, 9.5 * s) + cloth_drag - cloth_wave
		_poly([pelvis - side * 4.5 * s, pelvis + side * 0.2 * s, tail_r, tail_l], coat_shadow)

	# Far limbs.
	_draw_leg(hip_l, knee_l, foot_l, s, pants, outline, rim, alpha, ghost)
	_draw_arm(shoulder_l, elbow_l, hand_l, s, coat_shadow, skin, outline, rim, alpha, ghost)

	# Torso is an angular tapered mesh with separate lit and shadow planes.
	var shoulder_span := 6.5 * s * float(pose["build"])
	var waist_span := 3.8 * s * float(pose["build"])
	# Clamp inner insets so they can never exceed 85% of the outer span — prevents the inner quads
	# from crossing each other (bowtie) when build is small or forward compression is large.
	var top_inset := minf(0.7 * s, shoulder_span * 0.85)
	var bot_inset := minf(0.45 * s, waist_span * 0.85)
	var torso_top_l := chest - side * shoulder_span - forward * 0.7 * s
	var torso_top_r := chest + side * shoulder_span + forward * 0.7 * s
	var torso_bottom_l := pelvis - side * waist_span
	var torso_bottom_r := pelvis + side * waist_span
	_poly([torso_top_l, torso_top_r, torso_bottom_r, torso_bottom_l], outline)
	_poly([
		torso_top_l + side * top_inset,
		torso_top_r - side * top_inset,
		torso_bottom_r - side * bot_inset,
		torso_bottom_l + side * bot_inset,
	], coat)
	_poly([
		torso_top_l + side * top_inset,
		chest - side * minf(0.4 * s, shoulder_span * 0.85),
		pelvis - side * minf(0.15 * s, waist_span * 0.85),
		torso_bottom_l + side * bot_inset,
	], coat.lightened(0.10))
	_poly([
		chest + side * minf(0.3 * s, shoulder_span * 0.85),
		torso_top_r - side * top_inset,
		torso_bottom_r - side * bot_inset,
		pelvis + side * minf(0.1 * s, waist_span * 0.85),
	], coat_shadow)
	# Lapels, harness, belt, and faction accent create readable material breaks at game scale.
	if detail_level >= 1 and not ghost:
		draw_line(neck, chest + side * 1.4 * s + Vector2(0.0, 4.0 * s), accent, 1.15 * s, true)
		draw_line(neck, chest - side * 1.4 * s + Vector2(0.0, 4.0 * s), coat_shadow.lightened(0.16), 1.0 * s, true)
		draw_line(torso_bottom_l, torso_bottom_r, outline.lightened(0.12), 1.35 * s, true)
		if bool(_profile.get("armor", false)):
			_draw_armor_plate(chest, side, forward, s, metal, outline)

	# Near limbs and weapon.
	_draw_leg(hip_r, knee_r, foot_r, s, pants.lightened(0.035), outline, rim, alpha, ghost)
	_draw_arm(shoulder_r, elbow_r, hand_r, s, coat, skin, outline, rim, alpha, ghost)
	if not ghost:
		_draw_weapon(String(pose["weapon"]), hand_l, hand_r, forward, side, s, accent, metal, outline, float(pose["strike"]))

	# Neck and angular head planes.
	_segment(neck + Vector2(0, 1.0 * s), head + Vector2(0, 2.5 * s), 3.4 * s, skin.darkened(0.18), outline, false)
	_draw_head(head, forward, side, s * float(pose.get("head_scale", 1.0)), skin, hood, outline, rim, accent, ghost)

	# Silhouette rim lights — thin edge catches that separate the dark figure from dark asphalt.
	# Near side shoulder→elbow: most visible edge from camera-right.
	# Torso top cross-light: gives coat shoulders a defined roof line.
	# Far-side outer coat edge (shoulder_l → torso_bottom_l): the single line that reads "long coat"
	#   from behind/three-quarter views without any extra geometry.
	if detail_level >= 1 and not ghost:
		draw_line(shoulder_r, elbow_r, rim, maxf(0.7, 0.8 * s), true)
		draw_line(torso_top_l, torso_top_r, _with_alpha(rim, rim.a * 0.72), maxf(0.65, 0.75 * s), true)
		# Outer coat-edge rim on far side.
		var outer_coat_top := torso_top_l
		var outer_coat_bot := torso_bottom_l
		draw_line(outer_coat_top, outer_coat_bot, _with_alpha(rim, rim.a * 0.42), maxf(0.55, 0.65 * s), true)
		# Hip-to-knee far leg rim so legs don't merge into the coat shadow.
		draw_line(hip_l, knee_l, _with_alpha(rim, rim.a * 0.28), maxf(0.5, 0.6 * s), true)


func _draw_leg(hip: Vector2, knee: Vector2, foot: Vector2, s: float, color: Color, outline: Color, rim: Color, alpha: float, ghost: bool) -> void:
	_segment(hip, knee, 4.2 * s, color, outline, true)
	_segment(knee, foot + Vector2(0.0, -1.0 * s), 3.7 * s, color.darkened(0.08), outline, true)
	var boot_end := foot + Vector2(2.8 * s, 0.2 * s)
	_segment(foot - Vector2(0.0, 1.0 * s), boot_end, 3.4 * s, _with_alpha(Color(0.045, 0.052, 0.065), alpha), outline, true)
	if detail_level >= 2 and not ghost:
		draw_line(hip, knee, _with_alpha(rim, rim.a * 0.35), 0.65 * s, true)


func _draw_arm(shoulder: Vector2, elbow: Vector2, hand: Vector2, s: float, sleeve: Color, skin: Color, outline: Color, rim: Color, alpha: float, ghost: bool) -> void:
	_segment(shoulder, elbow, 3.7 * s, sleeve, outline, true)
	_segment(elbow, hand, 3.1 * s, sleeve.darkened(0.04), outline, true)
	if not ghost:
		draw_circle(hand, 1.65 * s, outline)
		draw_circle(hand, 1.15 * s, skin)
		if detail_level >= 2:
			draw_line(shoulder, elbow, _with_alpha(rim, rim.a * 0.38), 0.62 * s, true)


func _draw_head(head: Vector2, forward: Vector2, side: Vector2, s: float, skin: Color, hood: Color, outline: Color, rim: Color, accent: Color, ghost: bool) -> void:
	var hw := 4.1 * s
	var hh := 5.4 * s
	var face_push := forward * 1.15 * s
	if bool(_profile.get("hooded", false)):
		_poly([
			head + Vector2(0, -hh * 1.15) - side * hw * 0.65,
			head + Vector2(0, -hh * 1.25) + side * hw * 0.42,
			head + side * hw * 1.1 + Vector2(0, hh * 0.40),
			head + Vector2(0, hh * 0.92),
			head - side * hw * 1.0 + Vector2(0, hh * 0.36),
		], outline)
		_poly([
			head + Vector2(0, -hh) - side * hw * 0.50,
			head + Vector2(0, -hh * 1.06) + side * hw * 0.32,
			head + side * hw * 0.88 + Vector2(0, hh * 0.32),
			head + Vector2(0, hh * 0.72),
			head - side * hw * 0.80 + Vector2(0, hh * 0.28),
		], hood)
	var face := head + face_push
	var face_points := [
		face + Vector2(0, -hh * 0.68) - side * hw * 0.48,
		face + Vector2(0, -hh * 0.82) + side * hw * 0.26,
		face + side * hw * 0.62 + Vector2(0, hh * 0.05),
		face + side * hw * 0.26 + Vector2(0, hh * 0.68),
		face - side * hw * 0.45 + Vector2(0, hh * 0.52),
	]
	_poly(face_points, outline)
	var inset: Array[Vector2] = []
	for p in face_points:
		inset.append(face.lerp(p, 0.84))
	_poly(inset, skin.darkened(0.22 if bool(_profile.get("hooded", false)) else 0.08))
	# One lit facial plane gives the head a faceted, not toy-like, volume.
	_poly([
		face + Vector2(0, -hh * 0.60),
		face + side * hw * 0.35 + Vector2(0, -hh * 0.25),
		face + side * hw * 0.18 + Vector2(0, hh * 0.38),
		face - side * hw * 0.08 + Vector2(0, hh * 0.20),
	], skin.lightened(0.10))
	if not ghost and detail_level >= 1:
		var eye_center := face + forward * 0.8 * s + Vector2(0, -0.8 * s)
		var eye_color: Color = accent if bool(_profile.get("eyes", false)) else Color(0.08, 0.07, 0.065, 0.95)
		draw_line(eye_center - side * 1.35 * s, eye_center - side * 0.25 * s, eye_color, 0.9 * s, true)
		draw_line(eye_center + side * 0.25 * s, eye_center + side * 1.35 * s, eye_color, 0.9 * s, true)
		if bool(_profile.get("mask", false)):
			draw_line(face - side * 2.0 * s + Vector2(0, 1.6 * s), face + side * 2.0 * s + Vector2(0, 1.6 * s), hood.lightened(0.18), 1.8 * s, true)
		draw_line(head - side * hw * 0.55 + Vector2(0, -hh * 0.70), head + side * hw * 0.35 + Vector2(0, -hh * 0.85), rim, 0.85 * s, true)


func _draw_weapon(weapon: String, hand_l: Vector2, hand_r: Vector2, forward: Vector2, side: Vector2, s: float, accent: Color, metal: Color, outline: Color, strike: float) -> void:
	match weapon:
		"bat":
			var grip := hand_r
			var tip := grip + forward * (15.5 + 4.0 * strike) * s - side * 1.0 * s
			draw_line(grip, tip, outline, 3.2 * s, true)
			draw_line(grip + forward * 1.2 * s, tip - forward * 0.8 * s, Color(0.36, 0.31, 0.25), 2.25 * s, true)
			draw_line(tip - forward * 2.5 * s, tip, metal, 1.25 * s, true)
		"pistol":
			var muzzle := hand_r + forward * 7.8 * s
			_oriented_box(hand_r + forward * 3.4 * s, forward, side, 7.8 * s, 2.5 * s, outline)
			_oriented_box(hand_r + forward * 3.6 * s, forward, side, 6.8 * s, 1.55 * s, metal.darkened(0.32))
			_oriented_box(hand_r - forward * 0.4 * s + Vector2(0, 2.1 * s), Vector2(0, 1), Vector2(1, 0), 3.2 * s, 1.8 * s, outline)
			draw_circle(muzzle, 0.8 * s, metal.lightened(0.25))
		"rifle":
			var center := hand_r + forward * 5.5 * s
			_oriented_box(center, forward, side, 18.5 * s, 3.0 * s, outline)
			_oriented_box(center + forward * 1.0 * s, forward, side, 16.0 * s, 1.7 * s, metal.darkened(0.30))
			_oriented_box(center - forward * 7.5 * s + side * 0.4 * s, forward, side, 5.5 * s, 4.1 * s, outline)
			draw_line(hand_l, hand_r + forward * 3.5 * s, accent.darkened(0.12), 1.3 * s, true)
		"":
			if entity.kind == "player" or bool(_profile.get("claws", false)):
				for i in range(3):
					var lateral := (float(i) - 1.0) * 1.25 * s
					var base := hand_r + side * lateral
					var tip := base + forward * (5.5 + strike * 5.0) * s + side * lateral * 0.25
					draw_line(base, tip, outline, 1.55 * s, true)
					draw_line(base + forward * 0.6 * s, tip, metal.lightened(0.30), 0.72 * s, true)
		_:
			pass


func _draw_armor_plate(chest: Vector2, side: Vector2, forward: Vector2, s: float, metal: Color, outline: Color) -> void:
	var plate_center := chest + Vector2(0, 3.2 * s) + forward * 0.5 * s
	var w := 4.5 * s
	var h := 4.0 * s
	_poly([
		plate_center - side * w + Vector2(0, -h),
		plate_center + side * w + Vector2(0, -h),
		plate_center + side * w * 0.75 + Vector2(0, h),
		plate_center - side * w * 0.75 + Vector2(0, h),
	], outline)
	_poly([
		plate_center - side * w * 0.78 + Vector2(0, -h * 0.78),
		plate_center + side * w * 0.78 + Vector2(0, -h * 0.78),
		plate_center + side * w * 0.57 + Vector2(0, h * 0.72),
		plate_center - side * w * 0.57 + Vector2(0, h * 0.72),
	], metal.darkened(0.18))


func _draw_shadow(pose: Dictionary) -> void:
	var s := float(pose["s"])
	var dash_scale := 1.0 - 0.25 * clampf(_dash_timer / 0.34, 0.0, 1.0)
	# Tight contact shadow under the feet: narrower X and flatter Y than the old blob so it reads
	# as "feet on asphalt" rather than a floating orb of doom.
	draw_set_transform(Vector2(0.0, 0.5 * s), 0.0, Vector2(0.82 * dash_scale, 0.22 * dash_scale))
	draw_circle(Vector2.ZERO, 5.8 * s, Color(0.0, 0.0, 0.0, 0.62))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_afterimages() -> void:
	if _afterimages.is_empty() or entity == null:
		return
	for snap in _afterimages:
		var age := float(snap["age"])
		var alpha := pow(1.0 - clampf(age / DASH_TRAIL_DURATION, 0.0, 1.0), 1.7) * 0.28
		if alpha <= 0.005:
			continue
		var offset: Vector2 = snap["pos"] - entity.pos
		var saved_facing := _facing
		_facing = float(snap["facing"])
		var pose := _build_pose()
		_facing = saved_facing
		_draw_character(pose, alpha, offset, true)


func _draw_resonance() -> void:
	if entity.resonance == "" or not (entity.faction == "civ" or entity.downed):
		return
	var col := _resonance_color(entity.resonance)
	var pulse := 0.62 + 0.38 * sin(_time * 2.2 + float(entity.id))
	var rr := entity.radius * (1.55 + 0.12 * sin(_time * 2.2 + float(entity.id)))
	draw_arc(Vector2(0, 2.0), rr, 0, TAU, 28, Color(col.r, col.g, col.b, 0.38 * pulse), 1.8, true)
	draw_arc(Vector2(0, 2.0), rr * 0.72, 0, TAU, 24, Color(col.r, col.g, col.b, 0.16 * pulse), 1.1, true)


func _draw_status() -> void:
	var r := entity.radius + 8.0
	if entity.has_status("mesmerized"):
		draw_arc(Vector2.ZERO, r, 0, TAU, 22, Color("b98cff"), 1.8, true)
	if entity.has_status("fear"):
		draw_arc(Vector2.ZERO, r, 0, TAU, 22, Color("ff9ecf"), 1.8, true)
	if entity.has_status("stun"):
		for i in range(3):
			var a := _time * 3.5 + float(i) * TAU / 3.0
			draw_line(Vector2.RIGHT.rotated(a) * (r - 2.0), Vector2.RIGHT.rotated(a) * (r + 4.0), Color("f0c040"), 1.8, true)
	if int(entity.tags.get("marked", 0)) > 0:
		draw_arc(Vector2.ZERO, r + 2.0, 0, TAU, 24, Color("aef0ff"), 1.8, true)


func _draw_alert() -> void:
	if entity.kind != "npc" or not (entity.hostile_to_player or entity.responder):
		return
	var p := Vector2(0.0, -48.0 * maxf(entity.radius / 12.0, 0.62))
	var st := String(entity.ai_state)
	var ps := String(entity.perception_state)
	if st in ["chase", "attack"] or ps in ["alert", "combat"]:
		var c := Color("ff3a44")
		draw_line(p, p + Vector2(0, 7), c, 2.2, true)
		draw_circle(p + Vector2(0, 11), 1.5, c)
	elif st == "search" or int(entity.search_ticks) > 0:
		var c := Color("f0c040")
		draw_arc(p + Vector2(0, 3), 3.8, -2.3, 1.2, 12, c, 1.9, true)
		draw_line(p + Vector2(0, 3), p + Vector2(0, 7), c, 1.9, true)
		draw_circle(p + Vector2(0, 10), 1.35, c)


func _draw_corpse() -> void:
	var s := maxf(entity.radius / 12.0, 0.62)
	var pal := _profile
	draw_set_transform(Vector2.ZERO, entity.facing, Vector2.ONE)
	draw_set_transform(Vector2(0, 1.0 * s), entity.facing, Vector2(1.55, 0.55))
	draw_circle(Vector2.ZERO, 10.5 * s, Color(0.16, 0.012, 0.028, 0.58))
	draw_set_transform(Vector2.ZERO, entity.facing, Vector2.ONE)
	var outline := Color(0.012, 0.014, 0.02, 0.95)
	_poly([
		Vector2(-13, -4) * s,
		Vector2(9, -5) * s,
		Vector2(14, 1) * s,
		Vector2(7, 5) * s,
		Vector2(-12, 4) * s,
	], outline)
	_poly([
		Vector2(-11, -2.8) * s,
		Vector2(8, -3.5) * s,
		Vector2(11, 0.8) * s,
		Vector2(6, 3.4) * s,
		Vector2(-10, 2.8) * s,
	], _profile_color(pal, "coat").darkened(0.28))
	var head := Vector2(13.0, 0.0) * s
	_poly([
		head + Vector2(-2.5, -3.0) * s,
		head + Vector2(3.0, -2.0) * s,
		head + Vector2(3.2, 2.4) * s,
		head + Vector2(-2.4, 3.0) * s,
	], _profile_color(pal, "skin").darkened(0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_downed() -> void:
	var s := maxf(entity.radius / 12.0, 0.62)
	_draw_shadow({"s": s})
	# Clamp sway so the breathing motion can never shear the quad past convex.
	var sway := clampf(sin(_time * 1.2 + float(entity.id)) * 1.2 * s, -1.1 * s, 1.1 * s)
	var outline := Color(0.012, 0.014, 0.02, 0.95)
	var coat: Color = _profile["coat"]
	var skin: Color = _profile["skin"]
	_poly([
		Vector2(-8, -2 + sway) * s,
		Vector2(6, -5) * s,
		Vector2(9, 2) * s,
		Vector2(-6, 5 + sway) * s,
	], outline)
	_poly([
		Vector2(-6.5, -1.4 + sway) * s,
		Vector2(5, -3.5) * s,
		Vector2(7, 1.5) * s,
		Vector2(-5, 3.4 + sway) * s,
	], coat.darkened(0.16))
	_poly([
		Vector2(6, -5) * s,
		Vector2(11, -4) * s,
		Vector2(12, 1) * s,
		Vector2(8, 3) * s,
	], skin.darkened(0.12))
	_draw_status()


# ----------------------------------------------------------------------------- primitives / palette

func _segment(a: Vector2, b: Vector2, width: float, color: Color, outline: Color, caps: bool) -> void:
	var ow := width + maxf(1.4, width * 0.34)
	draw_line(a, b, outline, ow, true)
	draw_line(a, b, color, width, true)
	if caps:
		draw_circle(a, ow * 0.48, outline)
		draw_circle(b, ow * 0.48, outline)
		draw_circle(a, width * 0.46, color)
		draw_circle(b, width * 0.46, color)


func _oriented_box(center: Vector2, forward: Vector2, side: Vector2, length: float, width: float, color: Color) -> void:
	var hf := forward * length * 0.5
	var hs := side * width * 0.5
	_poly([center - hf - hs, center + hf - hs, center + hf + hs, center - hf + hs], color)


func _poly(points: Array, color: Color) -> void:
	if points.size() < 3:
		return
	# Reject any polygon where a vertex has leaked NaN or Inf.
	for p in points:
		var v: Vector2 = p
		if not (is_finite(v.x) and is_finite(v.y)):
			return
	# Reject degenerate (zero-area) polygons — avoids bowtie self-intersections that crash the
	# triangulator and contributes nothing to the image anyway.
	var area := 0.0
	var n := points.size()
	for i in range(n):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % n]
		area += a.cross(b)
	if absf(area) < 0.08:
		return
	# 4-point quads: split into two explicit triangles.  A triangle cannot self-intersect, so
	# draw_colored_polygon's triangulator can never fail on it.  draw_colored_polygon handles
	# 3-point arrays efficiently via a single triangle, so this is also the fast path.
	if points.size() == 4:
		var pa := PackedVector2Array([points[0], points[1], points[2]])
		var pb := PackedVector2Array([points[0], points[2], points[3]])
		draw_colored_polygon(pa, color)
		draw_colored_polygon(pb, color)
		return
	# 5+ points: pass through; these are pre-authored convex pentagons (head, corpse outline) that
	# have never triggered a failure in practice.
	var packed := PackedVector2Array()
	for p in points:
		packed.append(p)
	draw_colored_polygon(packed, color)


func _profile_color(profile: Dictionary, key: String) -> Color:
	var color: Color = profile.get(key, Color.WHITE)
	return color


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)


func _smoothstep(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _ease_out_cubic(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


func _pulse(x: float) -> float:
	return sin(clampf(x, 0.0, 1.0) * PI)


func _resonance_color(humour: String) -> Color:
	match humour:
		"sanguine": return Color("d23a52")
		"choleric": return Color("e08838")
		"melancholic": return Color("6f8ce0")
		"phlegmatic": return Color("6fd6a0")
	return Color("a0a0a8")


func _make_profile() -> Dictionary:
	# CharacterVisualProfile is the authoritative art-direction source.  We adapt its richer schema
	# to the flat key contract that the 800 lines below expect, rather than rewriting every read
	# site.  Keys that map: coat_dark→coat_shadow, cloth→hood, coat_length→long_coat (float→bool),
	# armored→armor, masked→mask.  Shape keys stature/shoulders/coat_length are forwarded as-is so
	# _build_pose can honour them.
	if entity == null:
		return _default_profile("")
	var key := "%s:%s:%s" % [entity.kind, entity.faction, entity.type_id]
	var p: Dictionary = CharacterVisualProfile.for_entity(entity)
	return {
		"key": key,
		# colours
		"coat":        p.get("coat",      Color("3d4046")),
		"coat_shadow": p.get("coat_dark", Color("181a1e")),
		"pants":       p.get("pants",     Color("17191d")),
		"skin":        p.get("skin",      Color("b99d87")),
		"hood":        p.get("cloth",     Color("2b2e33")),
		"accent":      p.get("accent",    Color("6b6260")),
		"metal":       p.get("metal",     Color("777b82")),
		# shape / silhouette
		"build":       float(p.get("build",    1.0)),
		"stature":     float(p.get("stature",  1.0)),
		"shoulders":   float(p.get("shoulders", 1.0)),
		"coat_length": float(p.get("coat_length", 0.86)),
		"head_scale":  float(p.get("head_scale", 1.0)),
		# flags
		"hooded":    bool(p.get("hooded",   false)),
		"eyes":      bool(p.get("eyes",     false)),
		"mask":      bool(p.get("masked",   false)),
		"armor":     bool(p.get("armored",  false)),
		"long_coat": float(p.get("coat_length", 0.86)) >= 1.0,
		"claws":     bool(p.get("claws",    false)),
	}


func _default_profile(key: String) -> Dictionary:
	return {
		"key": key,
		"coat": Color("454954"),
		"coat_shadow": Color("252832"),
		"pants": Color("1b1d24"),
		"skin": Color("b29f90"),
		"hood": Color("323640"),
		"accent": Color("7b818d"),
		"metal": Color("999fa8"),
		"build": 1.0,
		"stature": 1.0,
		"shoulders": 1.0,
		"coat_length": 0.86,
		"head_scale": 1.0,
		"hooded": false,
		"eyes": false,
		"mask": false,
		"armor": false,
		"long_coat": false,
		"claws": false,
	}
