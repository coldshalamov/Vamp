## KineticDebrisLayer.gd — bounded native-physics debris for impacts and explosions.
##
## These RigidBody2D shards are presentation only: they never collide with or write back to Sim.
## Gameplay outcomes stay deterministic while glass, stone, brass, and blood fragments inherit real
## inertia, damping, and angular motion from Godot's physics server.
extends Node2D
class_name KineticDebrisLayer

const MAX_PIECES := 112

var _pieces: Array[Dictionary] = []


func _ready() -> void:
	z_index = 47
	if CueBus != null and not CueBus.cue_emitted.is_connected(_on_cue):
		CueBus.cue_emitted.connect(_on_cue)


func _exit_tree() -> void:
	if CueBus != null and CueBus.cue_emitted.is_connected(_on_cue):
		CueBus.cue_emitted.disconnect(_on_cue)


func _on_cue(event_id: String, payload: Dictionary) -> void:
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	var seed := int(payload.get("entity_id", payload.get("target_id", 1)))
	match event_id:
		"damage.dealt", "damage.player", "hit.connect", "power.projectile.hit":
			var damage_type := String(payload.get("damage_type", "physical"))
			var kind := "blood" if damage_type in ["blood", "bleed"] else "spark"
			spawn_burst(pos, 4 if bool(payload.get("crit", false)) else 2, kind, 95.0, seed)
		"projectile.explode":
			var projectile_kind := String(payload.get("kind", ""))
			spawn_burst(pos, 18 if projectile_kind == "firebomb" else 10, "glass_fire" if projectile_kind == "firebomb" else "blood", 210.0, seed)
		"power.potence.quake_hit", "power.potence.hit", "power.potence.charge_hit":
			spawn_burst(pos, 14, "stone", 185.0, seed)
		"npc.death", "feed.kill":
			spawn_burst(pos, 7, "blood", 120.0, seed)


func spawn_burst(world_pos: Vector2, count: int, kind: String, energy: float, seed: int) -> void:
	for i in range(maxi(0, count)):
		_trim_oldest()
		var body := RigidBody2D.new()
		body.name = "Debris_%s_%d" % [kind, i]
		body.position = world_pos
		body.gravity_scale = 0.0
		body.linear_damp = 3.1 if kind != "glass_fire" else 2.2
		body.angular_damp = 2.4
		body.mass = 0.08
		body.collision_layer = 0
		body.collision_mask = 0
		body.z_index = i % 3

		var shadow := Polygon2D.new()
		shadow.polygon = PackedVector2Array([Vector2(-3.0, -1.2), Vector2(3.0, -1.2), Vector2(3.0, 1.2), Vector2(-3.0, 1.2)])
		shadow.color = Color(0.0, 0.0, 0.0, 0.32)
		body.add_child(shadow)

		var visual := Polygon2D.new()
		visual.polygon = _shape_for(kind, seed + i * 17)
		visual.color = _color_for(kind, seed + i * 23)
		body.add_child(visual)
		add_child(body)

		var angle := TAU * _unit(seed * 31 + i * 79)
		var speed := energy * lerpf(0.46, 1.0, _unit(seed * 47 + i * 113))
		body.linear_velocity = Vector2.RIGHT.rotated(angle) * speed
		body.angular_velocity = lerpf(-11.0, 11.0, _unit(seed * 59 + i * 137))
		var life := lerpf(0.52, 1.28, _unit(seed * 71 + i * 151))
		_pieces.append({
			"body": body,
			"visual": visual,
			"shadow": shadow,
			"life": life,
			"ttl": life,
			"lift": lerpf(7.0, 28.0, _unit(seed * 83 + i * 167)),
		})


func _process(delta: float) -> void:
	for i in range(_pieces.size() - 1, -1, -1):
		var piece: Dictionary = _pieces[i]
		var body: RigidBody2D = piece["body"]
		if not is_instance_valid(body):
			_pieces.remove_at(i)
			continue
		piece["ttl"] = float(piece["ttl"]) - delta
		var life := maxf(0.001, float(piece["life"]))
		var p := clampf(1.0 - float(piece["ttl"]) / life, 0.0, 1.0)
		var height := sin(p * PI) * float(piece["lift"])
		var visual: Polygon2D = piece["visual"]
		var shadow: Polygon2D = piece["shadow"]
		visual.position = Vector2(0.0, -height)
		visual.modulate.a = clampf((1.0 - p) * 1.45, 0.0, 1.0)
		shadow.scale = Vector2.ONE * clampf(1.0 - height / 70.0, 0.35, 1.0)
		shadow.modulate.a = clampf(0.72 - height / 55.0, 0.12, 0.72)
		_pieces[i] = piece
		if float(piece["ttl"]) <= 0.0:
			body.queue_free()
			_pieces.remove_at(i)


func _trim_oldest() -> void:
	while _pieces.size() >= MAX_PIECES:
		var old: Dictionary = _pieces.pop_front()
		var body: RigidBody2D = old.get("body", null)
		if body != null and is_instance_valid(body):
			body.queue_free()


func _shape_for(kind: String, seed: int) -> PackedVector2Array:
	var scale := lerpf(0.72, 1.28, _unit(seed))
	match kind:
		"glass_fire":
			return _scaled(PackedVector2Array([Vector2(-4.2, -1.1), Vector2(-0.8, -3.4), Vector2(4.6, 0.2), Vector2(0.9, 2.8), Vector2(-3.2, 1.9)]), scale)
		"stone":
			return _scaled(PackedVector2Array([Vector2(-4.0, -2.4), Vector2(1.2, -3.2), Vector2(4.3, -0.6), Vector2(2.4, 3.0), Vector2(-3.6, 2.0)]), scale)
		"spark":
			return _scaled(PackedVector2Array([Vector2(-4.8, -0.6), Vector2(4.6, -0.3), Vector2(5.2, 0.5), Vector2(-4.0, 0.9)]), scale)
		_:
			return _scaled(PackedVector2Array([Vector2(-3.4, -1.8), Vector2(1.0, -2.7), Vector2(3.8, 0.4), Vector2(0.5, 2.8), Vector2(-3.0, 1.4)]), scale)


func _scaled(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(point * factor)
	return out


func _color_for(kind: String, seed: int) -> Color:
	var variation := _unit(seed) * 0.12
	match kind:
		"glass_fire": return Color(0.82 + variation, 0.18 + variation * 0.4, 0.035, 0.94)
		"stone": return Color(0.24 + variation, 0.23 + variation, 0.22 + variation, 0.92)
		"spark": return Color(0.92, 0.64 + variation, 0.22, 0.94)
		_: return Color(0.48 + variation, 0.018, 0.055, 0.94)


func _unit(value: int) -> float:
	var n := absi(value * 1103515245 + 12345)
	return float(n % 10007) / 10006.0
