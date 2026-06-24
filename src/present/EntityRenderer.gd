## EntityRenderer.gd — presentation manager for articulated humanoids and dynamic entities.
##
## Humanoids are individual CharacterRig2D nodes so Godot can interpolate their transforms and
## Y-sort them correctly. Projectiles and vehicles remain batched custom drawing to keep node count
## bounded. This class is a read-only view over Sim.entities.
extends Node2D
class_name EntityRenderer

const CharacterRigScript := preload("res://src/present/CharacterRig2D.gd")
const TRAIL_POINTS := 8

var _entities: Array[SimEntity] = []
var _rigs: Dictionary = {}
var _projectile_trails: Dictionary = {}
var _time: float = 0.0


func setup(entities: Array[SimEntity]) -> void:
	_entities = entities


func _ready() -> void:
	y_sort_enabled = true
	z_index = 20
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)
	physics_sync(0.0)


## Called by GameRenderer after Sim.tick_sim(), guaranteeing presentation sees the completed tick.
func physics_sync(delta: float) -> void:
	var active_rigs: Dictionary = {}
	var active_projectiles: Dictionary = {}
	var player_pos := Sim.player.pos if Sim != null and Sim.player != null else Vector2.ZERO

	for e in _entities:
		if e == null:
			continue
		if e.kind in ["player", "npc"]:
			active_rigs[e.id] = true
			var rig = _rigs.get(e.id, null)
			if rig == null or not is_instance_valid(rig):
				rig = CharacterRigScript.new()
				rig.name = "Rig_%s_%d" % [e.type_id, e.id]
				add_child(rig)
				rig.setup(e)
				_rigs[e.id] = rig
			var distance := e.pos.distance_to(player_pos)
			rig.set_detail_level(2 if distance < 520.0 else (1 if distance < 920.0 else 0))
			rig.physics_sync(delta)
		elif e.kind == "projectile" and not e.dead:
			active_projectiles[e.id] = true
			var trail: Array = _projectile_trails.get(e.id, [])
			trail.append(e.pos)
			while trail.size() > TRAIL_POINTS:
				trail.pop_front()
			_projectile_trails[e.id] = trail

	for id in _rigs.keys():
		if not active_rigs.has(id):
			var rig = _rigs[id]
			if is_instance_valid(rig):
				rig.queue_free()
			_rigs.erase(id)
	for id in _projectile_trails.keys():
		if not active_projectiles.has(id):
			_projectile_trails.erase(id)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	for rig in _rigs.values():
		if is_instance_valid(rig):
			rig.advance_visual(delta)
	queue_redraw()


func _on_cue(event_id: String, payload: Dictionary) -> void:
	# One subscription fans semantic events into the affected rigs; dozens of actors do not each
	# subscribe to the global bus.
	var ids: Array[int] = []
	for key in ["entity_id", "target_id", "attacker_id"]:
		var id := int(payload.get(key, 0))
		if id != 0 and not ids.has(id):
			ids.append(id)
	for id in ids:
		var rig = _rigs.get(id, null)
		if rig != null and is_instance_valid(rig):
			rig.notify_event(event_id, payload)
	if event_id == "player.respawn":
		for rig in _rigs.values():
			if is_instance_valid(rig):
				rig.notify_event(event_id, payload)


func _draw() -> void:
	# Batched non-humanoid entities. Self drawing occurs beneath child rigs, which is desirable for
	# vehicles and projectile shadows; bright projectile cores still read through their additive VFX.
	for e in _entities:
		if e == null or e.dead:
			continue
		if e.kind == "vehicle":
			_draw_vehicle(e)
		elif e.kind == "projectile":
			_draw_projectile(e)


# ----------------------------------------------------------------------------- projectiles

func _draw_projectile(e: SimEntity) -> void:
	var altitude := 0.0
	var vertical_velocity := 0.0
	var ballistic := false
	if e.behaviour != null:
		altitude = float(e.behaviour.get("altitude"))
		vertical_velocity = float(e.behaviour.get("vertical_velocity"))
		ballistic = bool(e.behaviour.get("ballistic"))
	var lift := Vector2(0.0, -altitude * 0.42)
	var pos := e.pos + lift
	var r := maxf(e.radius, 4.0)
	var kind := String(e.type_id)
	var trail: Array = _projectile_trails.get(e.id, [])

	# Ground shadow scales down and softens as the object rises, making the ballistic arc readable.
	var shadow_scale := clampf(1.0 - altitude / 190.0, 0.25, 1.0)
	draw_set_transform(e.pos + Vector2(0, 2), 0.0, Vector2(1.35 * shadow_scale, 0.42 * shadow_scale))
	draw_circle(Vector2.ZERO, r * 1.15, Color(0, 0, 0, 0.34 * shadow_scale))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if trail.size() >= 2:
		for i in range(1, trail.size()):
			var p0: Vector2 = trail[i - 1]
			var p1: Vector2 = trail[i]
			var a := float(i) / float(trail.size())
			var projected_lift := lift * a
			var col := Color(0.70, 0.04, 0.13, a * 0.26)
			draw_line(p0 + projected_lift, p1 + projected_lift, col, maxf(1.0, r * a * 0.65), true)

	if kind.contains("flask") or kind.contains("bomb") or kind.contains("potion"):
		_draw_flask(pos, e.facing, r, vertical_velocity, ballistic)
	elif kind.contains("bullet"):
		var forward := Vector2.RIGHT.rotated(e.facing)
		draw_line(pos - forward * r * 3.0, pos, Color(1.0, 0.78, 0.45, 0.62), maxf(1.2, r * 0.55), true)
		draw_circle(pos, r * 0.48, Color(1.0, 0.93, 0.72))
	else:
		var forward := Vector2.RIGHT.rotated(e.facing)
		draw_line(pos - forward * r * 2.8, pos, Color(0.72, 0.035, 0.13, 0.38), r * 0.75, true)
		draw_circle(pos, r + 2.5, Color(0.78, 0.04, 0.15, 0.28))
		draw_circle(pos, r, Color("df1834"))
		draw_circle(pos - forward * r * 0.25, r * 0.40, Color("ffd0d6"))


func _draw_flask(pos: Vector2, facing: float, r: float, vertical_velocity: float, ballistic: bool) -> void:
	var spin := facing + (_time * 7.0 if ballistic else 0.0) + vertical_velocity * 0.002
	var forward := Vector2.RIGHT.rotated(spin)
	var side := Vector2(-forward.y, forward.x)
	var glass := Color(0.52, 0.72, 0.76, 0.82)
	var liquid := Color(0.66, 0.055, 0.12, 0.92)
	var outline := Color(0.02, 0.03, 0.04, 0.92)
	var body_center := pos - forward * r * 0.25
	var points := PackedVector2Array([
		body_center - forward * r * 0.75 - side * r * 0.55,
		body_center + forward * r * 0.55 - side * r * 0.75,
		body_center + forward * r * 0.95 + side * r * 0.30,
		body_center + forward * r * 0.25 + side * r * 0.82,
		body_center - forward * r * 0.70 + side * r * 0.55,
	])
	draw_colored_polygon(points, outline)
	var inner := PackedVector2Array()
	for p in points:
		inner.append(body_center.lerp(p, 0.78))
	draw_colored_polygon(inner, glass)
	var liquid_center := body_center + side * r * 0.18
	draw_line(liquid_center - forward * r * 0.55, liquid_center + forward * r * 0.35, liquid, r * 0.72, true)
	var neck_a := body_center + forward * r * 0.62
	var neck_b := neck_a + forward * r * 0.92
	draw_line(neck_a, neck_b, outline, r * 0.62, true)
	draw_line(neck_a, neck_b, glass.lightened(0.22), r * 0.36, true)
	draw_line(neck_b - side * r * 0.35, neck_b + side * r * 0.35, Color("c8b49b"), r * 0.42, true)
	draw_line(body_center - side * r * 0.25 - forward * r * 0.35, body_center - side * r * 0.25 + forward * r * 0.20, Color(1, 1, 1, 0.58), maxf(0.8, r * 0.18), true)


# ----------------------------------------------------------------------------- vehicles

func _draw_vehicle(e: SimEntity) -> void:
	var r := e.radius
	var length := maxf(r * 2.8, 48.0)
	var width := maxf(r * 1.45, 23.0)
	var police := _entity_is_police(e)
	var body := Color("17243a") if police else Color("15171d")
	var trim := Color("8095ba") if police else Color("585d66")
	var glass := Color(0.08, 0.14, 0.20, 0.92)
	draw_set_transform(e.pos, e.facing, Vector2.ONE)
	# Long contact shadow and four wheels keep the vehicle planted.
	draw_rect(Rect2(Vector2(-length * 0.52 + 3, -width * 0.53 + 4), Vector2(length * 1.04, width * 1.06)), Color(0, 0, 0, 0.42))
	for wx in [-length * 0.30, length * 0.30]:
		for wy in [-width * 0.55, width * 0.43]:
			draw_rect(Rect2(Vector2(wx - length * 0.10, wy), Vector2(length * 0.20, width * 0.14)), Color("08090c"))
	# Chamfered body rather than two programmer rectangles.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-length * 0.48, -width * 0.42),
		Vector2(length * 0.38, -width * 0.48),
		Vector2(length * 0.50, -width * 0.25),
		Vector2(length * 0.50, width * 0.25),
		Vector2(length * 0.38, width * 0.48),
		Vector2(-length * 0.48, width * 0.42),
	]), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-length * 0.15, -width * 0.34),
		Vector2(length * 0.24, -width * 0.31),
		Vector2(length * 0.30, width * 0.31),
		Vector2(-length * 0.15, width * 0.34),
	]), glass)
	draw_line(Vector2(-length * 0.15, 0), Vector2(length * 0.30, 0), trim.darkened(0.25), 1.2, true)
	draw_line(Vector2(-length * 0.44, -width * 0.38), Vector2(length * 0.38, -width * 0.43), body.lightened(0.16), 1.3, true)
	# Headlights project into the street; police lightbar pulses without touching authoritative time.
	var headlight := Color(1.0, 0.92, 0.68, 0.16)
	draw_colored_polygon(PackedVector2Array([
		Vector2(length * 0.45, -width * 0.31), Vector2(length * 0.45, width * 0.31),
		Vector2(length * 1.18, width * 0.78), Vector2(length * 1.18, -width * 0.78),
	]), headlight)
	if police:
		var pulse := 0.55 + 0.45 * sin(_time * 12.0)
		draw_rect(Rect2(Vector2(-length * 0.02, -width * 0.12), Vector2(length * 0.20, width * 0.24)), Color(0.10, 0.16, 0.22, 0.95))
		draw_circle(Vector2(length * 0.03, -width * 0.15), 2.0, Color(0.25, 0.48, 1.0, pulse))
		draw_circle(Vector2(length * 0.13, width * 0.15), 2.0, Color(1.0, 0.16, 0.18, 1.0 - pulse * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _entity_is_police(e: SimEntity) -> bool:
	return e.type_id == "police" or e.faction == "police"
