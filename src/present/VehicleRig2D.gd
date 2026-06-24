## VehicleRig2D.gd — interpolated top-down vehicle body with layered metal, glass, lights, and damage.
extends Node2D
class_name VehicleRig2D

const FIXED_DT := 1.0 / 60.0
const TELEPORT_DISTANCE := 360.0
const SurfaceShader := preload("res://art/shaders/kinetic_surface.gdshader")

var entity: SimEntity = null
var _prev_pos: Vector2 = Vector2.ZERO
var _curr_pos: Vector2 = Vector2.ZERO
var _prev_facing: float = 0.0
var _curr_facing: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _hit_time: float = 0.0


func setup(e: SimEntity) -> void:
	entity = e
	name = "VehicleRig_%d" % e.id
	_prev_pos = e.pos
	_curr_pos = e.pos
	_prev_facing = e.facing
	_curr_facing = e.facing
	var surface := ShaderMaterial.new()
	surface.shader = SurfaceShader
	surface.set_shader_parameter("grain_seed", float(e.id) * 0.271)
	surface.set_shader_parameter("grain_strength", 0.035)
	surface.set_shader_parameter("directional_relief", 0.060)
	material = surface
	position = e.pos
	rotation = e.facing
	queue_redraw()


func capture_physics() -> void:
	if entity == null:
		return
	_prev_pos = _curr_pos
	_prev_facing = _curr_facing
	_curr_pos = entity.pos
	_curr_facing = entity.facing
	if _prev_pos.distance_to(_curr_pos) > TELEPORT_DISTANCE:
		_prev_pos = _curr_pos
		_prev_facing = _curr_facing
	_velocity = (_curr_pos - _prev_pos) / FIXED_DT


func react(event_id: String, _payload: Dictionary = {}) -> void:
	if event_id in ["vehicle.crash", "damage.dealt", "damage.player"]:
		_hit_time = 0.20


func _process(delta: float) -> void:
	if entity == null:
		return
	_time += delta
	_hit_time = maxf(0.0, _hit_time - delta)
	var interpolation := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	position = _prev_pos.lerp(_curr_pos, interpolation)
	rotation = lerp_angle(_prev_facing, _curr_facing, interpolation)
	queue_redraw()


func _draw() -> void:
	if entity == null:
		return
	var r := maxf(entity.radius, 18.0)
	var length := maxf(r * 2.75, 48.0)
	var width := maxf(r * 1.38, 25.0)
	var police := entity.type_id == "police" or entity.faction == "police"
	var sport := entity.type_id == "sport"
	var speed := clampf(_velocity.length() / 460.0, 0.0, 1.0)
	var flash := sin(clampf(_hit_time / 0.20, 0.0, 1.0) * PI)
	var body := Color("#172136") if police else (Color("#27191b") if sport else Color("#191b22"))
	body = body.lerp(Color(0.92, 0.82, 0.74), flash * 0.70)
	var body_dark := body.darkened(0.38)
	var metal := Color("#657080") if police else Color("#5d5a60")
	var glass := Color(0.055, 0.10, 0.16, 0.92)

	# Long, soft contact shadow and directional speed smear.
	draw_set_transform(Vector2(-length * 0.05, width * 0.14), 0.0, Vector2(1.0 + speed * 0.14, 0.74))
	draw_rect(Rect2(Vector2(-length * 0.54, -width * 0.53), Vector2(length * 1.08, width * 1.06)), Color(0, 0, 0, 0.42), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Headlight cones sit beneath the body and are restrained enough for noir darkness.
	var beam_color := Color(0.92, 0.88, 0.66, 0.10) if not police else Color(0.62, 0.72, 0.92, 0.09)
	for side in [-1.0, 1.0]:
		var beam := PackedVector2Array([
			Vector2(length * 0.45, side * width * 0.28),
			Vector2(length * 1.30, side * width * 0.72),
			Vector2(length * 1.48, side * width * 0.16),
		])
		draw_colored_polygon(beam, beam_color)

	# Wheels are inset black polygons rather than floating circles.
	for axle in [-0.30, 0.30]:
		for side in [-1.0, 1.0]:
			var center := Vector2(length * axle, side * width * 0.53)
			var tire := PackedVector2Array([
				center + Vector2(-length * 0.12, -width * 0.10), center + Vector2(length * 0.12, -width * 0.10),
				center + Vector2(length * 0.12, width * 0.10), center + Vector2(-length * 0.12, width * 0.10),
			])
			draw_colored_polygon(tire, Color("#07080a"))

	var shell := PackedVector2Array([
		Vector2(-length * 0.52, -width * 0.34), Vector2(-length * 0.34, -width * 0.51),
		Vector2(length * 0.31, -width * 0.48), Vector2(length * 0.52, -width * 0.30),
		Vector2(length * 0.54, width * 0.30), Vector2(length * 0.31, width * 0.48),
		Vector2(-length * 0.34, width * 0.51), Vector2(-length * 0.52, width * 0.34),
	])
	_draw_beveled(shell, body, body.lightened(0.22), 1.25)

	# Hood and trunk facets break the silhouette into metal planes.
	var hood := PackedVector2Array([
		Vector2(length * 0.18, -width * 0.37), Vector2(length * 0.47, -width * 0.27),
		Vector2(length * 0.48, width * 0.27), Vector2(length * 0.18, width * 0.37),
	])
	_draw_beveled(hood, body.lightened(0.07), body.lightened(0.26), 0.9)
	var trunk := PackedVector2Array([
		Vector2(-length * 0.48, -width * 0.26), Vector2(-length * 0.26, -width * 0.36),
		Vector2(-length * 0.26, width * 0.36), Vector2(-length * 0.48, width * 0.26),
	])
	_draw_beveled(trunk, body_dark.lightened(0.12), body.lightened(0.10), 0.75)

	# Cabin, windshield specular cut, and central divider.
	var cabin := PackedVector2Array([
		Vector2(-length * 0.22, -width * 0.38), Vector2(length * 0.15, -width * 0.34),
		Vector2(length * 0.22, -width * 0.21), Vector2(length * 0.22, width * 0.21),
		Vector2(length * 0.15, width * 0.34), Vector2(-length * 0.22, width * 0.38),
		Vector2(-length * 0.31, width * 0.21), Vector2(-length * 0.31, -width * 0.21),
	])
	_draw_beveled(cabin, glass, Color(0.37, 0.50, 0.65, 0.55), 1.0)
	draw_line(Vector2(-length * 0.08, -width * 0.35), Vector2(-length * 0.08, width * 0.35), Color(0.08, 0.09, 0.12, 0.92), 1.4, true)
	draw_line(Vector2(length * 0.16, -width * 0.25), Vector2(-length * 0.18, -width * 0.31), Color(0.58, 0.70, 0.82, 0.28), 1.1, true)

	# Lamps and police lightbar. Their small scale and hard geometry avoid toy-car styling.
	for side in [-1.0, 1.0]:
		var lamp := PackedVector2Array([
			Vector2(length * 0.45, side * width * 0.31), Vector2(length * 0.52, side * width * 0.27),
			Vector2(length * 0.52, side * width * 0.12), Vector2(length * 0.45, side * width * 0.17),
		])
		draw_colored_polygon(lamp, Color(0.94, 0.85, 0.58, 0.86))
	if police:
		var pulse := 0.45 + 0.55 * sin(_time * 12.0)
		var bar := Rect2(Vector2(-length * 0.05, -width * 0.44), Vector2(length * 0.18, width * 0.88))
		draw_rect(bar, metal.darkened(0.35), true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x, bar.size.y * 0.5)), Color(0.16, 0.28, 0.95, 0.58 + pulse * 0.28), true)
		draw_rect(Rect2(bar.position + Vector2(0, bar.size.y * 0.5), Vector2(bar.size.x, bar.size.y * 0.5)), Color(0.92, 0.10, 0.16, 0.86 - pulse * 0.28), true)


func _draw_beveled(points: PackedVector2Array, fill: Color, edge: Color, width: float) -> void:
	var shadow := PackedVector2Array()
	for p in points:
		shadow.append(p + Vector2(0.9, 1.1))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.24))
	draw_colored_polygon(points, fill)
	var loop := points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, edge, width, true)
