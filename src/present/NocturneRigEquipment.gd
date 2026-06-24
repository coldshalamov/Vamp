## NocturneRigEquipment.gd — weapons, gear, ground marks, status and action poses.
extends "res://src/present/NocturneRigGeometry.gd"

func _draw_weapon(hand: Vector2, direction: Vector2, r: float, strike: float) -> void:
	var weapon := String(_palette.get("weapon", ""))
	if weapon == "":
		return
	var d := direction.normalized()
	var n := Vector2(-d.y, d.x)
	var metal: Color = _palette["metal"]
	var leather: Color = _palette["leather"]
	match weapon:
		"claws":
			for offset in [-0.10, 0.0, 0.10]:
				var base := hand + n * r * float(offset)
				draw_line(
					base, base + d * r * (0.38 + strike * 0.30), metal.lightened(0.24), 1.25, true
				)
		"knife", "stake":
			draw_line(hand - d * r * 0.22, hand + d * r * 0.14, leather, 2.4, true)
			var base := hand + d * r * 0.12
			var tip := hand + d * r * (0.80 if weapon == "stake" else 0.62)
			draw_colored_polygon(
				PackedVector2Array([base - n * r * 0.08, tip, base + n * r * 0.07]), metal
			)
		"bat", "baton":
			var length := r * (1.10 if weapon == "bat" else 0.86)
			draw_line(
				hand - d * r * 0.22, hand + d * length, leather.darkened(0.10), r * 0.18, true
			)
			draw_line(
				hand + d * r * 0.10,
				hand + d * length,
				metal.darkened(0.24) if weapon == "baton" else leather.lightened(0.10),
				r * 0.10,
				true
			)
		"pistol":
			var muzzle := hand + d * r * 0.48
			draw_colored_polygon(
				PackedVector2Array(
					[
						hand - n * r * 0.10,
						muzzle - n * r * 0.09,
						muzzle + n * r * 0.09,
						hand + n * r * 0.10
					]
				),
				metal.darkened(0.12)
			)
			draw_line(hand, hand - n * r * 0.24 - d * r * 0.12, leather, 2.2, true)
			if strike > 0.72:
				draw_colored_polygon(
					PackedVector2Array(
						[
							muzzle,
							muzzle + d * r * 0.36 - n * r * 0.16,
							muzzle + d * r * 0.58,
							muzzle + d * r * 0.36 + n * r * 0.16
						]
					),
					Color(1.0, 0.82, 0.42, 0.72)
				)
		"rifle":
			draw_line(
				hand - d * r * 0.55, hand + d * r * 1.02, metal.darkened(0.16), r * 0.16, true
			)
			draw_line(hand - d * r * 0.55, hand + d * r * 0.08, leather, r * 0.21, true)


func _draw_gear(hip: Vector2, shoulder: Vector2, r: float) -> void:
	if detail_level > 0:
		return
	match String(_palette.get("gear", "")):
		"badge":
			var p := shoulder + Vector2(r * 0.25, r * 0.30)
			draw_colored_polygon(
				PackedVector2Array(
					[
						p + Vector2(0, -2.2),
						p + Vector2(2, 0),
						p + Vector2(0, 2.4),
						p + Vector2(-2, 0)
					]
				),
				_palette["metal"]
			)
		"bandolier", "cross":
			draw_line(
				shoulder + Vector2(-r * 0.35, r * 0.08),
				hip + Vector2(r * 0.34, -r * 0.05),
				_palette["leather"],
				2.0,
				true
			)
			if _palette["gear"] == "cross":
				var c := shoulder.lerp(hip, 0.52)
				draw_line(c + Vector2(0, -2.5), c + Vector2(0, 3.0), _palette["metal"], 1.1, true)
				draw_line(c + Vector2(-2, 0), c + Vector2(2, 0), _palette["metal"], 1.1, true)
		"satchel":
			draw_rect(
				Rect2(hip + Vector2(-r * 0.62, r * 0.04), Vector2(r * 0.36, r * 0.32)),
				_palette["leather"].darkened(0.12),
				true
			)


func _draw_ground_marks(r: float) -> void:
	if entity.resonance != "" and (entity.faction == "civ" or entity.downed):
		var col := Palette.resonance_color(entity.resonance)
		var pulse := 0.62 + 0.38 * sin(_time * 2.1 + entity_id * 0.37)
		for i in range(4):
			var start := i * TAU / 4.0 + 0.16
			draw_arc(
				Vector2(0, r * 0.13),
				r * (1.30 + pulse * 0.09),
				start,
				start + 0.72,
				8,
				Color(col.r, col.g, col.b, 0.24 * pulse),
				1.25,
				true
			)


func _draw_status(head: Vector2, r: float) -> void:
	if entity.hostile_to_player or entity.perception_state in ["combat", "alert", "searching"]:
		var col := Color("#a34a3f") if entity.hostile_to_player else Color("#a78c52")
		draw_colored_polygon(
			PackedVector2Array(
				[
					head + Vector2(0, -r * 0.92),
					head + Vector2(r * 0.16, -r * 0.64),
					head + Vector2(-r * 0.16, -r * 0.64)
				]
			),
			col
		)
	if entity.has_status("burn"):
		_draw_broken_ring(Vector2.ZERO, r * 1.18, Color("#b9632d"))
	elif entity.has_status("poison"):
		_draw_broken_ring(Vector2.ZERO, r * 1.18, Color("#668a49"))
	elif entity.has_status("stun") or entity.has_status("mesmerized"):
		_draw_broken_ring(head, r * 0.54, Color("#79629a"))


func _draw_broken_ring(center: Vector2, radius: float, color: Color) -> void:
	for i in range(3):
		var a := i * TAU / 3.0 + _time * 0.45
		draw_arc(center, radius, a, a + 1.12, 7, Color(color.r, color.g, color.b, 0.64), 1.25, true)


func _draw_shadow(r: float, crouch: float, speed: float) -> void:
	draw_set_transform(
		Vector2(0, r * 0.18),
		0.0,
		Vector2(1.22 + minf(speed, 1.0) * 0.15 + crouch * 0.34, 0.42 + crouch * 0.12)
	)
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.46))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_dash_echoes(r: float, dash: float, face: Vector2) -> void:
	if dash <= 0.0:
		return
	var trail := -_motion_visual.normalized() if _motion_visual.length_squared() > 16.0 else -face
	var col: Color = _palette["coat"]
	for i in range(1, 4):
		var p := trail * r * i * 0.72
		var alpha := maxf(dash * (0.16 - i * 0.025), 0.02)
		draw_colored_polygon(
			PackedVector2Array(
				[
					p + Vector2(-r * 0.45, -r * 1.95),
					p + Vector2(r * 0.42, -r * 1.90),
					p + Vector2(r * 0.50, -r * 0.28),
					p + Vector2(-r * 0.53, -r * 0.30)
				]
			),
			Color(col.r, col.g, col.b, alpha)
		)
