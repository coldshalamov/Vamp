## SimProjectile.gd -- deterministic bullets and spell bolts.
extends RefCounted
class_name SimProjectile

var entity: SimEntity
var owner_id: int = 0
var damage: float = 10.0
var life_ticks: int = 90
var pierce: int = 0
var hits: int = 0
var hit_ids: Array[int] = []
var damage_type: String = "physical"
var status_id: String = ""
var status_ticks: int = 0
var aoe_radius: float = 0.0
var aoe_damage: float = 0.0
var cue_id: String = "projectile.hit"

static func configure(e: SimEntity, opts: Dictionary) -> SimEntity:
	e.kind = "projectile"
	e.type_id = String(opts.get("kind", "bolt"))
	e.faction = String(opts.get("faction", "player"))
	e.radius = float(opts.get("radius", 5.0))
	e.vel = Vector2(float(opts.get("vx", 0.0)), float(opts.get("vy", 0.0)))
	e.dead = false
	var behaviour_script: GDScript = load("res://src/entities/SimProjectile.gd") as GDScript
	e.behaviour = behaviour_script.new(e, opts)
	return e

func _init(e: SimEntity, opts: Dictionary) -> void:
	entity = e
	owner_id = int(opts.get("owner_id", 0))
	damage = float(opts.get("damage", 10.0))
	life_ticks = int(opts.get("life_ticks", 90))
	pierce = int(opts.get("pierce", 0))
	damage_type = String(opts.get("damage_type", "physical"))
	status_id = String(opts.get("status", ""))
	status_ticks = int(opts.get("status_ticks", 0))
	aoe_radius = float(opts.get("aoe_radius", 0.0))
	aoe_damage = float(opts.get("aoe_damage", 0.0))
	cue_id = String(opts.get("cue", "projectile.hit"))

func step(delta: float, sim) -> void:
	life_ticks -= 1
	if life_ticks <= 0:
		_explode(sim)
		entity.dead = true
		return
	var from_pos := entity.pos
	var next_pos := entity.pos + entity.vel * delta
	if sim.world != null and sim.world.is_blocked_world(next_pos, entity.radius):
		_explode(sim)
		entity.dead = true
		return
	entity.pos = next_pos
	if entity.faction == "player":
		for target in sim.entities:
			if target == null or target.dead or target == entity or target.kind == "projectile" or target.kind == "vehicle":
				continue
			if target.faction == "player" or hit_ids.has(target.id):
				continue
			if _seg_circle(from_pos, entity.pos, target.pos, entity.radius + target.radius):
				_hit(target, sim)
				if entity.dead:
					return
	else:
		var player: SimEntity = sim.player
		if player != null and not player.dead and _seg_circle(from_pos, entity.pos, player.pos, entity.radius + player.radius):
			_hit(player, sim)

func state_hash() -> int:
	return hash([
		owner_id, snapped(damage, 0.001), life_ticks, pierce, hits,
		_hash_array(hit_ids), damage_type, status_id, status_ticks,
		snapped(aoe_radius, 0.001), snapped(aoe_damage, 0.001), cue_id
	])

func _hit(target: SimEntity, sim) -> void:
	hit_ids.append(target.id)
	hits += 1
	var attacker: SimEntity = sim.get_entity(owner_id)
	sim.damage_entity(attacker, target, damage, {
		"cue": cue_id,
		"status": status_id,
		"status_ticks": status_ticks,
		"damage_type": damage_type,
		"knockback": 60.0,
	})
	if hits > pierce:
		_explode(sim)
		entity.dead = true

func _explode(sim) -> void:
	if aoe_radius <= 0.0:
		sim.emit_cue("projectile.end", { "entity_id": entity.id, "pos": entity.pos, "kind": entity.type_id })
		return
	var attacker: SimEntity = sim.get_entity(owner_id)
	for target in sim.entities_in_radius(entity.pos, aoe_radius, func(e): return e != entity and e.kind != "projectile" and not e.dead and e.faction != entity.faction):
		sim.damage_entity(attacker, target, aoe_damage if aoe_damage > 0.0 else damage * 0.6, {
			"cue": "projectile.aoe",
			"status": status_id,
			"status_ticks": status_ticks,
			"damage_type": damage_type,
		})
	sim.emit_cue("projectile.explode", { "entity_id": entity.id, "pos": entity.pos, "radius": aoe_radius })

func _seg_circle(a: Vector2, b: Vector2, c: Vector2, radius: float) -> bool:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.0001:
		return a.distance_to(c) <= radius
	var t: float = clamp((c - a).dot(ab) / denom, 0.0, 1.0)
	return a.lerp(b, t).distance_to(c) <= radius

func _hash_array(arr: Array) -> int:
	var h := 0
	for item in arr:
		h = hash([h, item])
	return h
