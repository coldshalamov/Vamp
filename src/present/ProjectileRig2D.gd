## ProjectileRig2D.gd — interpolated projectile silhouettes with ballistic height and trails.
##
## Ground-plane motion remains authoritative in SimProjectile. This view reconstructs height from the
## deterministic flight fraction, producing a readable parabolic throw without feeding scene physics
## back into replay state.
extends Node2D
class_name ProjectileRig2D

const FIXED_DT := 1.0 / 60.0
const TELEPORT_DISTANCE := 300.0
const MAX_TRAIL_POINTS := 10

var entity: SimEntity = null
var _prev_pos: Vector2 = Vector2.ZERO
var _curr_pos: Vector2 = Vector2.ZERO
var _physics_ready: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _trail_world: Array[Vector2] = []
var _spawn_flash: float = 1.0


func setup(e: SimEntity) -> void:
	entity = e
	name = "ProjectileRig_%d" % e.id
	_prev_pos = e.pos
	_curr_pos = e.pos
	_physics_ready = true
	position = e.pos
	queue_redraw()


func capture_physics() -> void:
	if entity == null:
		return
	if not _physics_ready:
		_prev_pos = entity.pos
		_curr_pos = entity.pos
		_physics_ready = true
		return
	_prev_pos = _curr_pos
	_curr_pos = entity.pos
	if _prev_pos.distance_to(_curr_pos) > TELEPORT_DISTANCE:
		_prev_pos = _curr_pos
	_velocity = (_curr_pos - _prev_pos) / FIXED_DT
	_trail_world.push_front(_curr_pos)
	while _trail_world.size() > MAX_TRAIL_POINTS:
		_trail_world.pop_back()


func react(event_id: String, _payload: Dictionary = {}) -> void:
	if event_id == "projectile.spawn":
		_spawn_flash = 1.0


func _process(delta: float) -> void:
	if entity == null:
		return
	_time += delta
	_spawn_flash = move_toward(_spawn_flash, 0.0, delta * 6.0)
	var interpolation := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	position = _prev_pos.lerp(_curr_pos, interpolation)
	rotation = _velocity.angle() if _velocity.length_squared() > 0.01 else entity.facing
	queue_redraw()


func _draw() -> void:
	if entity == null:
		return
	var kind := String(entity.type_id)
	var behaviour = entity.behaviour
	var progress := 0.0
	var arc_height := 0.0
	var spin_rate := 0.0
	var ballistic := false
	if behaviour != null:
		progress = float(behaviour.call("flight_fraction")) if behaviour.has_method("flight_fraction") else 0.0
		ballistic = bool(behaviour.get("ballistic"))
		arc_height = float(behaviour.get("arc_height"))
		spin_rate = float(behaviour.get("spin_rate"))
	var height := 4.0 * progress * (1.0 - progress) * arc_height if ballistic else 0.0
	var body_pos := Vector2(0.0, -height)
	var spin := _time * spin_rate

	_draw_trail(height, kind)
	_draw_shadow(height)
	match kind:
		"firebomb", "alchemical_firebomb":
			_draw_firebomb(body_pos, spin)
		"drive_by", "bullet", "test_bolt":
			_draw_bullet(body_pos)
		_:
			_draw_blood_bolt(body_pos, spin)


func _draw_trail(height: float, kind: String) -> void:
	if _trail_world.size() < 2:
		return
	var points := PackedVector2Array()
	for i in range(_trail_world.size()):
		var wp: Vector2 = _trail_world[i]
		var local := to_local(wp)
		var falloff := 1.0 - float(i) / float(maxi(1, _trail_world.size() - 1))
		local.y -= height * falloff * 0.70
		points.append(local)
	var trail_color := Color(0.85, 0.18, 0.08, 0.48) if kind in ["firebomb", "alchemical_firebomb"] else Color(0.66, 0.03, 0.10, 0.48)
	for i in range(points.size() - 1):
		var alpha := 1.0 - float(i) / float(maxi(1, points.size() - 1))
		draw_line(points[i], points[i + 1], Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha), maxf(0.8, 3.2 * alpha), true)


func _draw_shadow(height: float) -> void:
	var r := maxf(entity.radius, 4.0)
	var shrink := clampf(1.0 - height / 160.0, 0.35, 1.0)
	var alpha := clampf(0.50 - height / 260.0, 0.12, 0.50)
	draw_set_transform(Vector2(0.0, r * 0.28), 0.0, Vector2(1.45 * shrink, 0.55 * shrink))
	draw_circle(Vector2.ZERO, r * 1.18, Color(0.0, 0.0, 0.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_firebomb(pos: Vector2, spin: float) -> void:
	var r := maxf(entity.radius, 6.0)
	draw_set_transform(pos, spin, Vector2.ONE)
	# Dark iron cage around a cracked alchemical glass core.
	var bottle := PackedVector2Array([
		Vector2(-r * 0.70, -r * 0.46), Vector2(r * 0.18, -r * 0.66),
		Vector2(r * 0.70, -r * 0.30), Vector2(r * 0.76, r * 0.34),
		Vector2(r * 0.18, r * 0.70), Vector2(-r * 0.72, r * 0.42),
	])
	_draw_beveled(bottle, Color("#241712"), Color(0.78, 0.42, 0.19, 0.72), 1.0)
	var core := PackedVector2Array([
		Vector2(-r * 0.34, -r * 0.28), Vector2(r * 0.20, -r * 0.38),
		Vector2(r * 0.42, r * 0.02), Vector2(r * 0.08, r * 0.43),
		Vector2(-r * 0.42, r * 0.24),
	])
	draw_colored_polygon(core, Color(0.88, 0.18, 0.035, 0.82))
	draw_polyline(PackedVector2Array([core[0], core[1], core[2], core[3], core[4], core[0]]), Color(1.0, 0.64, 0.24, 0.82), 1.0, true)
	# Wick and spark are narrow, directional marks rather than a cartoon fuse ball.
	draw_line(Vector2(-r * 0.52, -r * 0.36), Vector2(-r * 1.02, -r * 0.58), Color("#5b4938"), 1.6, true)
	var spark := Vector2(-r * 1.10, -r * 0.62)
	for i in range(4):
		var angle := _time * 9.0 + float(i) * TAU / 4.0
		draw_line(spark, spark + Vector2.RIGHT.rotated(angle) * r * (0.22 + _spawn_flash * 0.18), Color(1.0, 0.58, 0.16, 0.72), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bullet(pos: Vector2) -> void:
	var r := maxf(entity.radius, 3.0)
	var slug := PackedVector2Array([
		pos + Vector2(-r * 1.25, -r * 0.22), pos + Vector2(r * 0.72, -r * 0.18),
		pos + Vector2(r * 1.12, 0.0), pos + Vector2(r * 0.72, r * 0.18),
		pos + Vector2(-r * 1.25, r * 0.22),
	])
	_draw_beveled(slug, Color("#c9b37a"), Color(1.0, 0.91, 0.62, 0.85), 0.8)


func _draw_blood_bolt(pos: Vector2, spin: float) -> void:
	var r := maxf(entity.radius, 4.0)
	draw_set_transform(pos, spin, Vector2.ONE)
	var shard := PackedVector2Array([
		Vector2(-r * 1.18, 0.0), Vector2(-r * 0.28, -r * 0.54),
		Vector2(r * 1.10, -r * 0.12), Vector2(r * 1.35, 0.0),
		Vector2(r * 0.88, r * 0.20), Vector2(-r * 0.22, r * 0.60),
	])
	_draw_beveled(shard, Color("#7d0818"), Color(1.0, 0.36, 0.42, 0.78), 1.0)
	var core := PackedVector2Array([
		Vector2(-r * 0.38, -r * 0.20), Vector2(r * 0.72, -r * 0.07),
		Vector2(r * 0.52, r * 0.12), Vector2(-r * 0.50, r * 0.22),
	])
	draw_colored_polygon(core, Color(0.96, 0.16, 0.24, 0.76))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_beveled(points: PackedVector2Array, fill: Color, edge: Color, width: float) -> void:
	var shadow := PackedVector2Array()
	for p in points:
		shadow.append(p + Vector2(0.8, 1.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.30))
	draw_colored_polygon(points, fill)
	var loop := points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, edge, width, true)
