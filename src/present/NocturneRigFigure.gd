## NocturneRigFigure.gd — proportioned layered humanoid drawing and continuous posing.
extends "res://src/present/NocturneRigEquipment.gd"

func _draw() -> void:
	if entity == null:
		return
	match entity.kind:
		"projectile":
			Props.draw_projectile(self, entity, _facing_visual, _spawn_age)
		"vehicle":
			Props.draw_vehicle(self, entity, _facing_visual, _time)
		_:
			if entity.dead:
				Props.draw_corpse(self, entity, _facing_visual, _death_age, _palette)
			else:
				_draw_character()


func _draw_character() -> void:
	var r := maxf(entity.radius, 7.0)
	var build := float(_palette.get("build", 1.0))
	var stature := float(_palette.get("stature", 1.0))
	var speed := clampf(_motion_visual.length() / 145.0, 0.0, 1.25)
	var moving := speed > 0.055
	var motion_dir := (
		_motion_visual.normalized() if moving else Vector2.RIGHT.rotated(_facing_visual)
	)
	var face := Vector2.RIGHT.rotated(_facing_visual)
	var action := _action_pose()
	var windup := action.x
	var strike := action.y
	var recovery := action.z
	var dash := clampf(_dash_timer / DASH_DURATION, 0.0, 1.0)
	var hit := clampf(_hit_timer / HIT_DURATION, 0.0, 1.0)
	var cast := clampf(_cast_timer / CAST_DURATION, 0.0, 1.0)
	var downed := entity.downed or entity.ai_state == "downed"
	var crouch := 0.58 if downed else 0.0
	if dash > 0.0:
		crouch = maxf(crouch, sin((1.0 - dash) * PI) * 0.66)
	var gait := sin(_gait_visual)
	var gait_cos := cos(_gait_visual)
	var bob := (
		absf(gait) * r * 0.09 * minf(speed, 1.0)
		if moving
		else sin(_time * 1.55 + entity_id * 0.41) * r * 0.035
	)
	var recoil := hit * hit * r * 0.32
	var attack_lean := (strike * 0.32 - windup * 0.18 + recovery * 0.05) * r
	var lean := Vector2(face.x * (r * 0.10 + attack_lean - recoil), face.y * r * 0.08)

	_draw_ground_marks(r)
	_draw_dash_echoes(r, dash, face)
	_draw_shadow(r, crouch, speed)

	var foot_y := -r * 0.03
	var hip := Vector2(lean.x * 0.34, -r * (1.12 * stature - crouch * 0.50) + bob + lean.y * 0.35)
	var shoulder := Vector2(lean.x, -r * (2.18 * stature - crouch * 0.82) + bob + lean.y)
	var head := Vector2(
		lean.x * 1.12 + face.x * r * 0.08,
		-r * (3.03 * stature - crouch * 1.02) + bob + lean.y * 1.1
	)
	var step := Vector2(motion_dir.x, motion_dir.y * 0.44) * gait * r * 0.54 * minf(speed, 1.0)
	var foot_l := Vector2(-r * 0.29 * build, foot_y) + step
	var foot_r := Vector2(r * 0.29 * build, foot_y) - step
	if downed:
		foot_l += Vector2(-r * 0.18, -r * 0.24)
		foot_r += Vector2(r * 0.28, r * 0.04)
	var hip_l := hip + Vector2(-r * 0.23 * build, 0.0)
	var hip_r := hip + Vector2(r * 0.23 * build, 0.0)
	var knee_l := hip_l.lerp(foot_l, 0.52) + Vector2(-r * 0.08, r * (0.08 + 0.10 * absf(gait_cos)))
	var knee_r := hip_r.lerp(foot_r, 0.52) + Vector2(r * 0.08, r * (0.08 + 0.10 * absf(gait_cos)))
	var pants: Color = _palette["pants"]
	var boots: Color = _palette["boot"]
	if gait < 0.0:
		_draw_leg(hip_l, knee_l, foot_l, r, pants.darkened(0.14), boots, build)
		_draw_leg(hip_r, knee_r, foot_r, r, pants, boots.lightened(0.03), build)
	else:
		_draw_leg(hip_r, knee_r, foot_r, r, pants.darkened(0.14), boots, build)
		_draw_leg(hip_l, knee_l, foot_l, r, pants, boots.lightened(0.03), build)

	var shoulder_l := shoulder + Vector2(-r * 0.54 * build, r * 0.03)
	var shoulder_r := shoulder + Vector2(r * 0.54 * build, r * 0.03)
	var swing := gait * r * 0.33 * minf(speed, 1.0)
	var hand_l := Vector2(shoulder_l.x - r * 0.10, hip.y + r * 0.22 + swing)
	var hand_r := Vector2(shoulder_r.x + r * 0.10, hip.y + r * 0.22 - swing)
	var attack_dir := Vector2(face.x, face.y * 0.48).normalized()
	if attack_dir.length_squared() < EPSILON:
		attack_dir = Vector2.RIGHT
	var extension := strike * r * 1.48 - windup * r * 0.48 + recovery * r * 0.20
	var weapon_right := face.x >= -0.15
	if weapon_right:
		hand_r += attack_dir * extension + Vector2(0.0, -r * 0.18 * strike)
		hand_l += attack_dir * strike * r * 0.42
	else:
		hand_l += attack_dir * extension + Vector2(0.0, -r * 0.18 * strike)
		hand_r += attack_dir * strike * r * 0.42
	if cast > 0.0:
		var lift := sin((1.0 - cast) * PI) * r * 0.75
		hand_l += Vector2(-r * 0.12, -lift)
		hand_r += Vector2(r * 0.12, -lift)
	var elbow_l := shoulder_l.lerp(hand_l, 0.52) + Vector2(-r * 0.18, r * 0.04)
	var elbow_r := shoulder_r.lerp(hand_r, 0.52) + Vector2(r * 0.18, r * 0.04)
	var near_right := face.x >= 0.0
	if near_right:
		_draw_arm(
			shoulder_l, elbow_l, hand_l, r, _palette["coat_shadow"], _palette["skin"], build, false
		)
	else:
		_draw_arm(
			shoulder_r, elbow_r, hand_r, r, _palette["coat_shadow"], _palette["skin"], build, false
		)
	_draw_torso(hip, shoulder, r, build, bob, cast)
	if near_right:
		_draw_arm(shoulder_r, elbow_r, hand_r, r, _palette["coat"], _palette["skin"], build, true)
		_draw_arm(shoulder_l, elbow_l, hand_l, r, _palette["coat"], _palette["skin"], build, true)
	else:
		_draw_arm(shoulder_l, elbow_l, hand_l, r, _palette["coat"], _palette["skin"], build, true)
		_draw_arm(shoulder_r, elbow_r, hand_r, r, _palette["coat"], _palette["skin"], build, true)
	_draw_weapon(hand_r if weapon_right else hand_l, attack_dir, r, strike)
	_draw_head(head, shoulder, face, r, build, hit)
	_draw_gear(hip, shoulder, r)
	_draw_status(head, r)


func _draw_leg(
	hip: Vector2, knee: Vector2, foot: Vector2, r: float, cloth: Color, boot: Color, build: float
) -> void:
	_taper(hip, knee, r * 0.20 * build, r * 0.15 * build, cloth)
	_taper(
		knee,
		foot - Vector2(0.0, r * 0.08),
		r * 0.15 * build,
		r * 0.11 * build,
		cloth.darkened(0.07)
	)
	var d := (
		_motion_visual.normalized()
		if _motion_visual.length_squared() > 9.0
		else Vector2.RIGHT.rotated(_facing_visual)
	)
	d = Vector2(d.x, d.y * 0.25).normalized()
	if d.length_squared() < EPSILON:
		d = Vector2.DOWN
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(
		PackedVector2Array(
			[
				foot - n * r * 0.13,
				foot + d * r * 0.30 - n * r * 0.11,
				foot + d * r * 0.32 + n * r * 0.11,
				foot + n * r * 0.13
			]
		),
		boot
	)
	if detail_level == 0:
		draw_line(foot - n * r * 0.11, foot + n * r * 0.11, boot.lightened(0.16), 1.0, true)


func _draw_arm(
	shoulder: Vector2,
	elbow: Vector2,
	hand: Vector2,
	r: float,
	sleeve: Color,
	skin: Color,
	build: float,
	lit: bool
) -> void:
	_taper(shoulder, elbow, r * 0.18 * build, r * 0.13 * build, sleeve)
	_taper(elbow, hand, r * 0.13 * build, r * 0.09 * build, sleeve.darkened(0.06))
	var d := (hand - elbow).normalized()
	if d.length_squared() < EPSILON:
		d = Vector2.DOWN
	var n := Vector2(-d.y, d.x)
	var hand_col := skin.lightened(0.05) if lit else skin.darkened(0.16)
	draw_colored_polygon(
		PackedVector2Array(
			[
				hand - d * r * 0.08 - n * r * 0.08,
				hand + d * r * 0.14 - n * r * 0.06,
				hand + d * r * 0.15 + n * r * 0.05,
				hand - d * r * 0.06 + n * r * 0.08
			]
		),
		hand_col
	)


func _draw_torso(
	hip: Vector2, shoulder: Vector2, r: float, build: float, bob: float, cast: float
) -> void:
	var coat: Color = _palette["coat"]
	var shadow: Color = _palette["coat_shadow"]
	var left_sh := shoulder + Vector2(-r * 0.58 * build, 0.0)
	var right_sh := shoulder + Vector2(r * 0.58 * build, 0.0)
	var left_waist := hip + Vector2(-r * 0.38 * build, 0.0)
	var right_waist := hip + Vector2(r * 0.38 * build, 0.0)
	var left_hem := Vector2(hip.x - r * 0.49 * build, -r * 0.42 + bob * 0.25)
	var right_hem := Vector2(hip.x + r * 0.49 * build, -r * 0.42 + bob * 0.25)
	draw_colored_polygon(
		PackedVector2Array(
			[
				left_sh,
				right_sh,
				right_waist,
				right_hem,
				hip + Vector2(0, -r * 0.24),
				left_hem,
				left_waist
			]
		),
		coat
	)
	draw_colored_polygon(
		PackedVector2Array(
			[
				left_sh,
				shoulder + Vector2(r * 0.05, -r * 0.03),
				hip + Vector2(-r * 0.02, -r * 0.10),
				left_hem,
				left_waist
			]
		),
		coat.lightened(0.10)
	)
	draw_colored_polygon(
		PackedVector2Array(
			[
				shoulder + Vector2(r * 0.05, -r * 0.03),
				right_sh,
				right_waist,
				right_hem,
				hip + Vector2(-r * 0.02, -r * 0.10)
			]
		),
		shadow
	)
	var sway := clampf(_motion_visual.x / 180.0, -1.0, 1.0) * r * 0.18
	draw_colored_polygon(
		PackedVector2Array(
			[
				left_waist,
				hip + Vector2(-r * 0.04, -r * 0.08),
				hip + Vector2(-r * 0.11 + sway, r * 0.48),
				left_hem
			]
		),
		shadow.darkened(0.06)
	)
	draw_colored_polygon(
		PackedVector2Array(
			[
				hip + Vector2(r * 0.04, -r * 0.08),
				right_waist,
				right_hem,
				hip + Vector2(r * 0.11 + sway, r * 0.48)
			]
		),
		coat.darkened(0.04)
	)
	if detail_level == 0:
		draw_line(
			left_sh.lerp(right_sh, 0.16),
			left_waist.lerp(right_waist, 0.45),
			_palette["rim"],
			1.15,
			true
		)
		draw_line(
			Vector2(left_waist.x, hip.y - r * 0.10),
			Vector2(right_waist.x, hip.y - r * 0.10),
			_palette["leather"],
			1.5,
			true
		)
	if cast > 0.0:
		var pulse := sin((1.0 - cast) * PI)
		var accent: Color = _palette["accent"]
		draw_arc(
			hip + Vector2(0, -r * 0.55),
			r * (0.52 + pulse * 0.25),
			-2.7,
			-0.4,
			20,
			Color(accent.r, accent.g, accent.b, 0.34 * pulse),
			1.4,
			true
		)


func _draw_head(
	center: Vector2, shoulder: Vector2, face: Vector2, r: float, build: float, hit: float
) -> void:
	var skin: Color = _palette["skin"]
	skin = skin.lerp(Color(1.0, 0.93, 0.90), hit * 0.72)
	var w := r * 0.37 * build
	var h := r * 0.48
	_taper(
		shoulder + Vector2(0, -r * 0.02),
		center + Vector2(0, h * 0.62),
		r * 0.12,
		r * 0.10,
		skin.darkened(0.16)
	)
	if bool(_palette.get("hooded", false)):
		draw_colored_polygon(
			PackedVector2Array(
				[
					center + Vector2(-w * 1.28, h * 0.35),
					center + Vector2(-w * 0.98, -h * 0.62),
					center + Vector2(-w * 0.20, -h * 1.12),
					center + Vector2(w * 0.84, -h * 0.66),
					center + Vector2(w * 1.30, h * 0.34),
					center + Vector2(0, h * 0.92)
				]
			),
			_palette["hood"]
		)
		draw_colored_polygon(
			_head_poly(center + Vector2(face.x * w * 0.16, h * 0.02), w * 0.66, h * 0.68),
			skin.darkened(0.14)
		)
	else:
		draw_colored_polygon(_head_poly(center, w, h), skin)
		draw_colored_polygon(
			PackedVector2Array(
				[
					center + Vector2(-w * 0.95, -h * 0.18),
					center + Vector2(-w * 0.55, -h * 0.92),
					center + Vector2(w * 0.44, -h * 1.02),
					center + Vector2(w * 0.90, -h * 0.35),
					center + Vector2(w * 0.48, -h * 0.50),
					center + Vector2(-w * 0.30, -h * 0.47)
				]
			),
			_palette["hair"]
		)
	if detail_level == 0 and face.y > -0.72:
		var eye_y := center.y - h * 0.04
		var sep := w * 0.34
		var shift := face.x * w * 0.12
		draw_line(
			Vector2(center.x - sep + shift, eye_y),
			Vector2(center.x - sep * 0.35 + shift, eye_y),
			_palette["eye"],
			1.15,
			true
		)
		draw_line(
			Vector2(center.x + sep * 0.35 + shift, eye_y),
			Vector2(center.x + sep + shift, eye_y),
			_palette["eye"],
			1.15,
			true
		)
		if entity.kind == "player":
			draw_circle(Vector2(center.x - sep * 0.62 + shift, eye_y), 0.75, Color("#ff3848"))
			draw_circle(Vector2(center.x + sep * 0.62 + shift, eye_y), 0.75, Color("#ff3848"))
