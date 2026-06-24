## SimProjectile.gd -- deterministic bullets, spell bolts, and ballistic thrown payloads.
##
## Horizontal motion and vertical arc state are both authoritative and hashable. Rendering reads
## altitude to project the object above its ground shadow; it never invents gameplay trajectory.
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
var status_dps: float = 0.0
var aoe_radius: float = 0.0
var aoe_damage: float = 0.0
var cue_id: String = "projectile.hit"

# Ballistic channel. These are simulation units, not pixels: the renderer applies projection.
var ballistic: bool = false
var altitude: float = 0.0
var vertical_velocity: float = 0.0
var gravity: float = 0.0
var ground_restitution: float = 0.34
var max_bounces: int = 0
var bounces: int = 0
var explode_on_ground: bool = true
var collision_height: float = 18.0
var surface_effect: String = ""
var surface_radius: float = 0.0
var _exploded: bool = false


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
	status_dps = float(opts.get("status_dps", 0.0))
	aoe_radius = float(opts.get("aoe_radius", 0.0))
	aoe_damage = float(opts.get("aoe_damage", 0.0))
	cue_id = String(opts.get("cue", "projectile.hit"))

	altitude = maxf(0.0, float(opts.get("altitude", 0.0)))
	vertical_velocity = float(opts.get("vertical_velocity", 0.0))
	gravity = maxf(0.0, float(opts.get("gravity", 0.0)))
	ballistic = bool(opts.get("ballistic", gravity > 0.0 or altitude > 0.0 or not is_zero_approx(vertical_velocity)))
	ground_restitution = clampf(float(opts.get("ground_restitution", 0.34)), 0.0, 0.95)
	max_bounces = maxi(0, int(opts.get("max_bounces", 0)))
	explode_on_ground = bool(opts.get("explode_on_ground", ballistic))
	collision_height = maxf(0.0, float(opts.get("collision_height", 18.0)))
	surface_effect = String(opts.get("surface_effect", ""))
	surface_radius = maxf(0.0, float(opts.get("surface_radius", aoe_radius)))


func step(delta: float, sim) -> void:
	life_ticks -= 1
	if life_ticks <= 0:
		_explode(sim, "timeout")
		entity.dead = true
		return

	var from_pos := entity.pos
	var next_pos := entity.pos + entity.vel * delta
	if sim.world != null and sim.world.is_blocked_world(next_pos, entity.radius):
		_explode(sim, "wall")
		entity.dead = true
		return
	entity.pos = next_pos
	if entity.vel.length_squared() > 0.001:
		entity.facing = entity.vel.angle()

	if ballistic and _advance_vertical(delta, sim):
		return

	if entity.faction == "player":
		for target in sim.entities:
			if target == null or target.dead or target == entity or target.kind == "projectile" or target.kind == "vehicle":
				continue
			if target.faction == "player" or hit_ids.has(target.id):
				continue
			if ballistic and altitude > maxf(collision_height, target.radius * 1.45):
				continue
			if _seg_circle(from_pos, entity.pos, target.pos, entity.radius + target.radius):
				_hit(target, sim)
				if entity.dead:
					return
	else:
		var player: SimEntity = sim.player
		if player != null and not player.dead:
			if (not ballistic or altitude <= maxf(collision_height, player.radius * 1.45)) \
					and _seg_circle(from_pos, entity.pos, player.pos, entity.radius + player.radius):
				_hit(player, sim)


## Returns true when the projectile ended during the vertical update.
func _advance_vertical(delta: float, sim) -> bool:
	var previous_altitude := altitude
	altitude += vertical_velocity * delta
	vertical_velocity -= gravity * delta
	if altitude > 0.0 or previous_altitude <= 0.0:
		return false
	altitude = 0.0
	var impact_speed := absf(vertical_velocity)
	if bounces < max_bounces and impact_speed > 55.0 and ground_restitution > 0.0:
		bounces += 1
		vertical_velocity = impact_speed * ground_restitution
		entity.vel *= 0.74
		sim.emit_cue("projectile.bounce", {
			"entity_id": entity.id,
			"pos": entity.pos,
			"kind": entity.type_id,
			"bounce": bounces,
			"impact_speed": impact_speed,
		})
		return false
	if explode_on_ground:
		_explode(sim, "ground")
		entity.dead = true
		return true
	vertical_velocity = 0.0
	ballistic = false
	return false


func state_hash() -> int:
	return hash([
		owner_id, snapped(damage, 0.001), life_ticks, pierce, hits,
		_hash_array(hit_ids), damage_type, status_id, status_ticks, snapped(status_dps, 0.001),
		snapped(aoe_radius, 0.001), snapped(aoe_damage, 0.001), cue_id,
		ballistic, snapped(altitude, 0.001), snapped(vertical_velocity, 0.001),
		snapped(gravity, 0.001), snapped(ground_restitution, 0.001),
		max_bounces, bounces, explode_on_ground, snapped(collision_height, 0.001),
		surface_effect, snapped(surface_radius, 0.001), _exploded,
	])


func _hit(target: SimEntity, sim) -> void:
	hit_ids.append(target.id)
	hits += 1
	var attacker: SimEntity = sim.get_entity(owner_id)
	sim.damage_entity(attacker, target, damage, {
		"cue": cue_id,
		"status": status_id,
		"status_ticks": status_ticks,
		"status_dps": status_dps,
		"damage_type": damage_type,
		"knockback": 60.0,
	})
	if hits > pierce:
		_explode(sim, "target")
		entity.dead = true


func _explode(sim, reason: String) -> void:
	if _exploded:
		return
	_exploded = true
	var attacker: SimEntity = sim.get_entity(owner_id)
	if aoe_radius > 0.0:
		for target in sim.entities_in_radius(entity.pos, aoe_radius, func(e): return e != entity and e.kind != "projectile" and not e.dead and e.faction != entity.faction):
			sim.damage_entity(attacker, target, aoe_damage if aoe_damage > 0.0 else damage * 0.6, {
				"cue": "projectile.aoe",
				"status": status_id,
				"status_ticks": status_ticks,
				"status_dps": status_dps,
				"damage_type": damage_type,
			})

	var effect_radius := surface_radius if surface_radius > 0.0 else aoe_radius
	if sim.world != null and effect_radius > 0.0:
		match surface_effect:
			"fire":
				# Alchemical fire carries its own viscous fuel, so a flask visibly burns even on dry
				# pavement while still using the existing deterministic blood/fire substrate.
				if sim.world.blood_at(entity.pos) < 12:
					sim.world.spill_blood(entity.pos, clampi(int(effect_radius * 0.45), 18, 96))
				sim.world.ignite_radius(entity.pos, effect_radius)
			"blood":
				sim.world.spill_blood(entity.pos, clampi(int(effect_radius * 0.35), 8, 80))
			_:
				pass

	if aoe_radius <= 0.0 and surface_effect == "":
		sim.emit_cue("projectile.end", {
			"entity_id": entity.id,
			"pos": entity.pos,
			"kind": entity.type_id,
			"reason": reason,
		})
		return
	sim.emit_cue("projectile.explode", {
		"entity_id": entity.id,
		"owner_id": owner_id,
		"pos": entity.pos,
		"kind": entity.type_id,
		"radius": maxf(aoe_radius, effect_radius),
		"damage_type": damage_type,
		"status": status_id,
		"surface_effect": surface_effect,
		"bounces": bounces,
		"reason": reason,
	})


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
