## SimProjectile.gd -- deterministic bullets, spell bolts, and ballistic thrown objects.
##
## Ballistic mode adds a simulated vertical channel (height, gravity, bounce, fuse) while keeping
## the authoritative world collision on the existing 2D ground plane. The renderer reads height
## only for presentation. Legacy projectile options remain byte-for-byte compatible by default.
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

# Ballistic extension. All values are deterministic and included in state_hash().
var ballistic: bool = false
var height: float = 0.0
var vertical_velocity: float = 0.0
var gravity: float = 620.0
var bounces_remaining: int = 0
var bounce_factor: float = 0.34
var ground_friction: float = 0.76
var detonate_on_ground: bool = true
var fuse_ticks: int = -1
var collision_height: float = 22.0
var spin: float = 0.0
var spin_velocity: float = 0.0
var surface_effect: String = ""


static func configure(e: SimEntity, opts: Dictionary) -> SimEntity:
	e.kind = "projectile"
	e.type_id = String(opts.get("kind", "bolt"))
	e.faction = String(opts.get("faction", "player"))
	e.radius = float(opts.get("radius", 5.0))
	e.vel = Vector2(float(opts.get("vx", 0.0)), float(opts.get("vy", 0.0)))
	if e.vel.length_squared() > 0.001:
		e.facing = e.vel.angle()
	e.dead = false
	var behaviour_script: GDScript = load("res://src/entities/SimProjectile.gd") as GDScript
	e.behaviour = behaviour_script.new(e, opts)
	e.tags["projectile_damage_type"] = String(opts.get("damage_type", "physical"))
	e.tags["projectile_trail"] = String(opts.get("trail", ""))
	e.tags["projectile_ballistic"] = bool(opts.get("ballistic", false)) or opts.has("vertical_velocity") or opts.has("launch_height")
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

	ballistic = bool(opts.get("ballistic", false)) or opts.has("vertical_velocity") or opts.has("launch_height")
	height = maxf(0.0, float(opts.get("height", opts.get("launch_height", 0.0))))
	vertical_velocity = float(opts.get("vertical_velocity", 0.0))
	gravity = maxf(0.0, float(opts.get("gravity", 620.0)))
	bounces_remaining = maxi(0, int(opts.get("bounces", opts.get("ground_bounces", 0))))
	bounce_factor = clampf(float(opts.get("bounce_factor", 0.34)), 0.0, 0.95)
	ground_friction = clampf(float(opts.get("ground_friction", 0.76)), 0.0, 1.0)
	detonate_on_ground = bool(opts.get("detonate_on_ground", true))
	fuse_ticks = int(opts.get("fuse_ticks", -1))
	collision_height = maxf(0.0, float(opts.get("collision_height", 22.0)))
	spin = float(opts.get("spin", 0.0))
	spin_velocity = float(opts.get("spin_velocity", 8.0 if ballistic else 0.0))
	surface_effect = String(opts.get("surface_effect", damage_type if damage_type in ["fire", "poison"] else ""))


func step(delta: float, sim) -> void:
	life_ticks -= 1
	if fuse_ticks >= 0:
		fuse_ticks -= 1
		if fuse_ticks <= 0:
			_explode(sim)
			entity.dead = true
			return
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
	if entity.vel.length_squared() > 0.001:
		entity.facing = entity.vel.angle()

	if ballistic:
		vertical_velocity -= gravity * delta
		height += vertical_velocity * delta
		spin = fposmod(spin + spin_velocity * delta, TAU)
		if height <= 0.0:
			height = 0.0
			if bounces_remaining > 0 and absf(vertical_velocity) > 45.0:
				vertical_velocity = absf(vertical_velocity) * bounce_factor
				entity.vel *= ground_friction
				bounces_remaining -= 1
				sim.emit_cue("projectile.bounce", {
					"entity_id": entity.id,
					"pos": entity.pos,
					"kind": entity.type_id,
					"remaining": bounces_remaining,
					"speed": entity.vel.length(),
				})
			elif detonate_on_ground:
				_explode(sim)
				entity.dead = true
				return
			else:
				vertical_velocity = 0.0
				ballistic = false

	# Thrown objects can pass above bodies until they descend into collision height.
	var can_contact_targets := not ballistic or height <= collision_height
	if not can_contact_targets:
		return
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
		snapped(aoe_radius, 0.001), snapped(aoe_damage, 0.001), cue_id,
		ballistic, snapped(height, 0.001), snapped(vertical_velocity, 0.001), snapped(gravity, 0.001),
		bounces_remaining, snapped(bounce_factor, 0.001), snapped(ground_friction, 0.001),
		detonate_on_ground, fuse_ticks, snapped(collision_height, 0.001),
		snapped(spin, 0.001), snapped(spin_velocity, 0.001), surface_effect,
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
	_apply_surface_effect(sim)
	if aoe_radius <= 0.0:
		sim.emit_cue("projectile.end", {
			"entity_id": entity.id,
			"pos": entity.pos,
			"kind": entity.type_id,
			"damage_type": damage_type,
		})
		return

	var attacker: SimEntity = sim.get_entity(owner_id)
	for target in sim.entities_in_radius(entity.pos, aoe_radius, func(e): return e != entity and e.kind != "projectile" and not e.dead and e.faction != entity.faction):
		sim.damage_entity(attacker, target, aoe_damage if aoe_damage > 0.0 else damage * 0.6, {
			"cue": "projectile.aoe",
			"status": status_id,
			"status_ticks": status_ticks,
			"damage_type": damage_type,
			"knockback": minf(180.0, 44.0 + aoe_radius * 0.72),
		})
	sim.emit_cue("projectile.explode", {
		"entity_id": entity.id,
		"pos": entity.pos,
		"radius": aoe_radius,
		"kind": entity.type_id,
		"damage_type": damage_type,
		"status": status_id,
	})


func _apply_surface_effect(sim) -> void:
	if sim == null or sim.world == null:
		return
	var radius := maxf(aoe_radius, 46.0)
	if surface_effect == "fire" and sim.world.has_method("ignite_radius"):
		sim.world.ignite_radius(entity.pos, radius)
	elif surface_effect == "blood" and sim.world.has_method("spill_blood"):
		sim.world.spill_blood(entity.pos, clampi(int(radius * 0.16), 5, 28))


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
