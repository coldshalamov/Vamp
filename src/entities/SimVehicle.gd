## SimVehicle.gd -- deterministic arcade vehicle backend.
extends RefCounted
class_name SimVehicle

const Catalog := preload("res://src/data/GameCatalog.gd")

var entity: SimEntity
var vehicle_type: String = "sedan"
var speed: float = 0.0
var angle: float = 0.0
var max_speed: float = 330.0
var accel: float = 240.0
var handling: float = 2.6
var driver_id: int = 0
var last_driver_id: int = 0
var last_drive_tick: int = -999999
var ai: bool = false
var road_axis: int = 0
var road_dir: int = 1
var burn_ticks: int = 0
var siren: bool = false

static func configure(e: SimEntity, type_id: String, opts: Dictionary = {}) -> SimEntity:
	var preset: Dictionary = Catalog.VEHICLE_TYPES.get(type_id, Catalog.VEHICLE_TYPES["sedan"])
	e.kind = "vehicle"
	e.type_id = type_id
	e.faction = "neutral"
	e.radius = maxf(float(preset.get("width", 46.0)), float(preset.get("height", 24.0))) * 0.5
	e.max_hp = float(opts.get("hp", preset.get("hp", 120.0)))
	e.hp = e.max_hp
	e.armor = 0.20
	var behaviour_script: GDScript = load("res://src/entities/SimVehicle.gd") as GDScript
	e.behaviour = behaviour_script.new(e, type_id, opts)
	return e

func _init(e: SimEntity, type_id: String, opts: Dictionary = {}) -> void:
	entity = e
	vehicle_type = type_id
	var preset: Dictionary = Catalog.VEHICLE_TYPES.get(type_id, Catalog.VEHICLE_TYPES["sedan"])
	max_speed = float(preset.get("max_speed", 330.0))
	accel = float(preset.get("accel", 240.0))
	handling = float(preset.get("handling", 2.6))
	angle = float(opts.get("angle", 0.0))
	driver_id = int(opts.get("driver_id", 0))
	ai = bool(opts.get("ai", false))
	road_axis = int(opts.get("road_axis", 0))
	road_dir = int(opts.get("road_dir", 1))
	siren = bool(preset.get("siren", false)) or bool(opts.get("siren", false))

func step(delta: float, sim) -> void:
	if entity.dead:
		return
	if entity.hp <= 0.0:
		if burn_ticks <= 0:
			burn_ticks = 150
			sim.emit_cue("vehicle.burning", { "entity_id": entity.id, "pos": entity.pos, "type": vehicle_type })
		burn_ticks -= 1
		speed *= 0.92
		if burn_ticks <= 0:
			_explode(sim)
		return
	if driver_id == sim.player.id:
		_drive_player(delta, sim)
	elif ai:
		_drive_ai(delta, sim)
	else:
		speed *= pow(0.20, delta)
	var next_pos := entity.pos + Vector2.RIGHT.rotated(angle) * speed * delta
	var resolved: Vector2 = sim.world.resolve_motion(entity.pos, next_pos, entity.radius * 0.72)
	if resolved.distance_squared_to(next_pos) > 1.0:
		var impact := absf(speed)
		if impact > 140.0:
			entity.hp = maxf(0.0, entity.hp - impact * 0.04)
			sim.emit_cue("vehicle.crash", { "entity_id": entity.id, "pos": entity.pos, "magnitude": impact })
		speed *= 0.55
	entity.pos = resolved
	entity.facing = angle
	if driver_id == sim.player.id and absf(speed) > 120.0:
		for target in sim.entities:
			if target == null or target.dead or target.kind != "npc" or target.faction == "player":
				continue
			if entity.pos.distance_to(target.pos) < entity.radius + target.radius:
				sim.damage_entity(sim.player, target, absf(speed) * 0.12, { "cue": "vehicle.impact", "knockback": absf(speed) * 0.5, "crit_chance": 0.0 })
				if target.dead and target.innocent:
					sim.witnessed_act(target.pos, "kill", 2.0)

func enter(driver: SimEntity, sim) -> bool:
	if entity.dead or entity.hp <= 0.0 or driver_id != 0:
		return false
	driver_id = driver.id
	last_driver_id = driver.id
	driver.pos = entity.pos
	sim.emit_cue("vehicle.enter", { "vehicle_id": entity.id, "driver_id": driver.id, "type": vehicle_type, "pos": entity.pos })
	return true

func exit(driver: SimEntity, sim) -> void:
	if driver_id != driver.id:
		return
	driver_id = 0
	last_driver_id = driver.id
	last_drive_tick = sim.tick
	speed *= 0.3
	var offset := Vector2.RIGHT.rotated(angle + PI * 0.5) * (entity.radius + driver.radius + 8.0)
	driver.pos = sim.world.resolve_motion(entity.pos, entity.pos + offset, driver.radius)
	sim.emit_cue("vehicle.exit", { "vehicle_id": entity.id, "driver_id": driver.id, "pos": driver.pos })

func state_hash() -> int:
	return hash([
		vehicle_type, snapped(speed, 0.001), snapped(angle, 0.001),
		snapped(max_speed, 0.001), snapped(accel, 0.001),
		snapped(handling, 0.001), driver_id, last_driver_id,
		last_drive_tick, ai, road_axis, road_dir, burn_ticks, siren
	])

func _drive_player(delta: float, sim) -> void:
	var behaviour = sim.player.behaviour
	var move: Vector2 = behaviour.get("move_dir") if behaviour != null else Vector2.ZERO
	var throttle := -move.y
	var steer := move.x
	var handling_mult := float(sim.meta.derived.get("vehicleHandling", 1.0)) if sim.meta != null else 1.0
	if absf(throttle) > 0.05:
		speed += throttle * accel * handling_mult * delta
	else:
		speed *= pow(0.55, delta)
	speed = clamp(speed, -max_speed * 0.4, max_speed * handling_mult)
	var speed_ratio: float = clamp(absf(speed) / 120.0, 0.0, 1.0)
	angle += steer * handling * handling_mult * delta * speed_ratio * (-1.0 if speed < 0.0 else 1.0)
	sim.player.pos = entity.pos

func _drive_ai(delta: float, sim) -> void:
	var target := max_speed * 0.35
	var probe := entity.pos + Vector2.RIGHT.rotated(angle) * 78.0
	if sim.world.is_blocked_world(probe, entity.radius * 0.6):
		angle += PI * 0.5 * float(road_dir)
		road_dir *= -1
		target *= 0.3
	speed = move_toward(speed, target, accel * delta)

func _explode(sim) -> void:
	entity.dead = true
	sim.emit_cue("vehicle.explode", { "entity_id": entity.id, "pos": entity.pos, "type": vehicle_type })
	for target in sim.entities_in_radius(entity.pos, 90.0, func(e): return e != entity and not e.dead and e.kind != "projectile"):
		var attacker: SimEntity = sim.player if last_driver_id == sim.player.id and sim.tick - last_drive_tick < 360 else null
		sim.damage_entity(attacker, target, 80.0, { "cue": "vehicle.explosion.damage", "crit_chance": 0.0 })
