## Projectile, vehicle, and corpse facets shared by pooled Nocturne rigs.
extends RefCounted

const Palette := preload("res://src/present/NocturnePalette.gd")
const EPSILON := 0.0001


static func draw_projectile(
	canvas: Node2D, entity: SimEntity, facing: float, spawn_age: float
) -> void:
	var r := maxf(entity.radius, 3.2)
	var velocity := entity.vel
	var direction := (
		velocity.normalized()
		if velocity.length_squared() > EPSILON
		else Vector2.RIGHT.rotated(facing)
	)
	var normal := Vector2(-direction.y, direction.x)
	var kind := entity.type_id.to_lower()
	var damage_type := "physical"
	if entity.behaviour != null and entity.behaviour.get("damage_type") != null:
		damage_type = String(entity.behaviour.get("damage_type"))
	var thrown := (
		kind.contains("bomb")
		or kind.contains("grenade")
		or kind.contains("vial")
		or kind.contains("potion")
		or kind.contains("flask")
	)
	var height := r * (1.15 + absf(sin(spawn_age * 4.1)) * 2.5) if thrown else r * 0.72
	var pos := Vector2(0, -height)
	var color := Palette.projectile_color(damage_type, kind)
	canvas.draw_set_transform(Vector2(0, r * 0.18), 0.0, Vector2(1.35, 0.46))
	canvas.draw_circle(Vector2.ZERO, r * (0.62 if thrown else 0.42), Color(0, 0, 0, 0.34))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var trail := clampf(velocity.length() * 0.055, r * 1.8, r * 7.0)
	canvas.draw_line(
		pos - direction * trail,
		pos,
		Color(color.r, color.g, color.b, 0.22),
		maxf(1.2, r * 0.62),
		true
	)
	canvas.draw_line(
		pos - direction * trail * 0.55,
		pos,
		Color(color.r, color.g, color.b, 0.58),
		maxf(0.8, r * 0.24),
		true
	)
	if thrown:
		canvas.draw_set_transform(pos, spawn_age * 9.0, Vector2.ONE)
		if kind.contains("vial") or kind.contains("potion") or kind.contains("flask"):
			canvas.draw_colored_polygon(
				PackedVector2Array(
					[
						Vector2(-r * 0.34, -r * 0.44),
						Vector2(r * 0.34, -r * 0.44),
						Vector2(r * 0.44, r * 0.28),
						Vector2(0, r * 0.56),
						Vector2(-r * 0.44, r * 0.28)
					]
				),
				Color(color.r, color.g, color.b, 0.84)
			)
			canvas.draw_rect(
				Rect2(Vector2(-r * 0.16, -r * 0.70), Vector2(r * 0.32, r * 0.28)),
				Color("#8b765e"),
				true
			)
		else:
			canvas.draw_colored_polygon(
				_regular_polygon(Vector2.ZERO, r * 0.62, 7, -PI * 0.5), color.darkened(0.15)
			)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var nose := pos + direction * r * 0.90
		var back := pos - direction * r * 0.55
		canvas.draw_colored_polygon(
			PackedVector2Array([back - normal * r * 0.32, nose, back + normal * r * 0.32]), color
		)
		canvas.draw_line(back, nose, color.lightened(0.46), 1.0, true)
		canvas.draw_arc(
			pos, r * 0.84, 0, TAU, 14, Color(color.r, color.g, color.b, 0.24), 1.2, true
		)


static func draw_vehicle(canvas: Node2D, entity: SimEntity, facing: float, time: float) -> void:
	var r := maxf(entity.radius, 16.0)
	var police := entity.type_id.contains("police") or entity.faction == "police"
	var body := Color("#172033") if police else Color("#17171d")
	var length := maxf(r * 2.85, 48.0)
	var width := maxf(r * 1.42, 24.0)
	canvas.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	canvas.draw_colored_polygon(
		PackedVector2Array(
			[
				Vector2(-length * 0.54, -width * 0.55) + Vector2(2, 3),
				Vector2(length * 0.54, -width * 0.55) + Vector2(2, 3),
				Vector2(length * 0.54, width * 0.55) + Vector2(2, 3),
				Vector2(-length * 0.54, width * 0.55) + Vector2(2, 3)
			]
		),
		Color(0, 0, 0, 0.38)
	)
	for side in [-1.0, 1.0]:
		canvas.draw_rect(
			Rect2(
				Vector2(-length * 0.36, side * width * 0.48 - width * 0.11),
				Vector2(length * 0.28, width * 0.22)
			),
			Color("#09090c"),
			true
		)
		canvas.draw_rect(
			Rect2(
				Vector2(length * 0.15, side * width * 0.48 - width * 0.11),
				Vector2(length * 0.25, width * 0.22)
			),
			Color("#09090c"),
			true
		)
	var shell := PackedVector2Array(
		[
			Vector2(-length * 0.52, -width * 0.36),
			Vector2(-length * 0.40, -width * 0.53),
			Vector2(length * 0.30, -width * 0.53),
			Vector2(length * 0.52, -width * 0.32),
			Vector2(length * 0.52, width * 0.32),
			Vector2(length * 0.30, width * 0.53),
			Vector2(-length * 0.40, width * 0.53),
			Vector2(-length * 0.52, width * 0.36)
		]
	)
	canvas.draw_colored_polygon(shell, body)
	canvas.draw_colored_polygon(
		PackedVector2Array(
			[
				Vector2(-length * 0.10, -width * 0.43),
				Vector2(length * 0.25, -width * 0.40),
				Vector2(length * 0.31, width * 0.40),
				Vector2(-length * 0.10, width * 0.43)
			]
		),
		body.lightened(0.13)
	)
	canvas.draw_colored_polygon(
		PackedVector2Array(
			[
				Vector2(-length * 0.05, -width * 0.34),
				Vector2(length * 0.20, -width * 0.31),
				Vector2(length * 0.23, width * 0.31),
				Vector2(-length * 0.05, width * 0.34)
			]
		),
		Color("#29384a")
	)
	if police:
		var flash := sin(time * 9.0) > 0.0
		canvas.draw_rect(
			Rect2(Vector2(-length * 0.02, -width * 0.50), Vector2(length * 0.12, width * 0.16)),
			Color(0.26, 0.45, 0.92, 0.78 if flash else 0.20),
			true
		)
		canvas.draw_rect(
			Rect2(Vector2(length * 0.10, -width * 0.50), Vector2(length * 0.12, width * 0.16)),
			Color(0.90, 0.22, 0.25, 0.20 if flash else 0.78),
			true
		)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_corpse(
	canvas: Node2D, entity: SimEntity, facing: float, death_age: float, palette: Dictionary
) -> void:
	var r := maxf(entity.radius, 7.0)
	var direction := Vector2.RIGHT.rotated(facing)
	var normal := Vector2(-direction.y, direction.x)
	var center := Vector2(0, r * 0.05)
	var coat: Color = palette.get("coat", Color("#24242b"))
	var skin: Color = palette.get("skin", Color("#b8a899"))
	canvas.draw_set_transform(Vector2(0, r * 0.20), 0.0, Vector2(1.55, 0.50))
	canvas.draw_circle(Vector2.ZERO, r * 0.90, Color(0, 0, 0, 0.42))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var length := r * (2.10 + minf(1.0, death_age / 0.42) * 0.18)
	canvas.draw_colored_polygon(
		PackedVector2Array(
			[
				center - direction * length * 0.52 - normal * r * 0.50,
				center + direction * length * 0.48 - normal * r * 0.40,
				center + direction * length * 0.55 + normal * r * 0.34,
				center - direction * length * 0.50 + normal * r * 0.52
			]
		),
		coat
	)
	canvas.draw_colored_polygon(
		_head_polygon(center + direction * length * 0.70, r * 0.32, r * 0.38), skin.darkened(0.24)
	)


static func _regular_polygon(
	center: Vector2, radius: float, sides: int, rotation: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		points.append(center + Vector2.RIGHT.rotated(rotation + TAU * i / float(sides)) * radius)
	return points


static func _head_polygon(center: Vector2, width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			center + Vector2(-width * 0.66, -height),
			center + Vector2(width * 0.50, -height * 0.95),
			center + Vector2(width, -height * 0.30),
			center + Vector2(width * 0.80, height * 0.64),
			center + Vector2(width * 0.25, height),
			center + Vector2(-width * 0.52, height * 0.84),
			center + Vector2(-width, height * 0.12)
		]
	)
