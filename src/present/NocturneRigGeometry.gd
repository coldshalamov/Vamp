## NocturneRigGeometry.gd — continuously posed 2.5D presentation for every SimEntity.
##
## SimEntity remains authoritative. This pooled view consumes fixed-tick snapshots and cues,
## then renders proportioned urban figures from layered facets. Gait, recoil, attacks, casting,
## dash, projectile flight, hit response, death, and vehicle motion are continuous functions;
## there is no sprite-sheet frame ceiling.
extends Node2D

const Palette := preload("res://src/present/NocturnePalette.gd")
const Props := preload("res://src/present/NocturnePropPainter.gd")

const HIT_DURATION := 0.16
const DASH_DURATION := 0.38
const ATTACK_DURATION := 0.30
const CAST_DURATION := 0.42
const EPSILON := 0.0001

var entity: SimEntity = null
var entity_id := 0
var detail_level := 0

var _time := 0.0
var _spawn_age := 0.0
var _attack_timer := 0.0
var _dash_timer := 0.0
var _hit_timer := 0.0
var _cast_timer := 0.0
var _death_age := 0.0
var _gait_target := 0.0
var _gait_visual := 0.0
var _facing_target := 0.0
var _facing_visual := 0.0
var _motion_target := Vector2.ZERO
var _motion_visual := Vector2.ZERO
var _palette: Dictionary = {}
var _palette_key := ""


func _action_pose() -> Vector3:
	var pose := Vector3.ZERO
	if entity.current_action != null and entity.current_action.def != null:
		var def = entity.current_action.def
		var frame := (
			float(entity.action_frame)
			+ clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
		)
		var startup := maxf(float(def.startup), 1.0)
		var active := maxf(float(def.active), 1.0)
		var recovery := maxf(float(def.recovery), 1.0)
		if frame < startup:
			pose.x = _smooth(frame / startup)
		elif frame < startup + active:
			pose.y = _smooth((frame - startup) / active)
			pose.x = 1.0 - pose.y
		else:
			pose.z = 1.0 - _smooth((frame - startup - active) / recovery)
			pose.y = pose.z * 0.42
	elif _attack_timer > 0.0:
		var p := 1.0 - _attack_timer / ATTACK_DURATION
		if p < 0.30:
			pose.x = _smooth(p / 0.30)
		elif p < 0.66:
			pose.y = _smooth((p - 0.30) / 0.36)
		else:
			pose.z = 1.0 - _smooth((p - 0.66) / 0.34)
			pose.y = pose.z * 0.38
	return pose


func _taper(a: Vector2, b: Vector2, wa: float, wb: float, color: Color) -> void:
	var d := b - a
	if d.length_squared() < EPSILON:
		return
	d = d.normalized()
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(
		PackedVector2Array([a - n * wa, b - n * wb, b + n * wb, a + n * wa]), color
	)
	if detail_level == 0 and a.distance_to(b) > 4.0:
		draw_line(a - n * wa * 0.42, b - n * wb * 0.28, color.lightened(0.12), 0.75, true)


func _head_poly(center: Vector2, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			center + Vector2(-w * 0.66, -h),
			center + Vector2(w * 0.50, -h * 0.95),
			center + Vector2(w, -h * 0.30),
			center + Vector2(w * 0.80, h * 0.64),
			center + Vector2(w * 0.25, h),
			center + Vector2(-w * 0.52, h * 0.84),
			center + Vector2(-w, h * 0.12)
		]
	)


func _regular_poly(
	center: Vector2, radius: float, sides: int, rotation := 0.0
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		points.append(center + Vector2.RIGHT.rotated(rotation + TAU * i / float(sides)) * radius)
	return points


func _smooth(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _refresh_palette(force: bool) -> void:
	if entity == null:
		return
	var key := (
		"%s:%s:%s:%s" % [entity.kind, entity.faction, entity.type_id, entity.tags.get("weapon", "")]
	)
	if force or key != _palette_key:
		_palette_key = key
		_palette = Palette.make(entity)
