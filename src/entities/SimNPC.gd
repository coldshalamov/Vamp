## SimNPC.gd -- deterministic NPC AI for the vertical-slice backend.
##
## Ports the legacy wander/chase/flee/search loop into pure sim logic. Perception reads
## player exposure, line-of-sight, faction, heat, and responder state.
extends RefCounted
class_name SimNPC

const PRESETS := {
	"ped": { "hp": 28.0, "speed": 78.0, "radius": 9.0, "faction": "civ", "innocent": true, "threat": 0.0, "damage": 0.0, "range": 0.0 },
	"thug": { "hp": 60.0, "speed": 96.0, "radius": 10.0, "faction": "gang", "innocent": false, "threat": 1.0, "damage": 7.0, "range": 42.0 },
	"gunner": { "hp": 55.0, "speed": 92.0, "radius": 10.0, "faction": "gang", "innocent": false, "threat": 1.2, "damage": 9.0, "range": 155.0 },
	"cop": { "hp": 85.0, "speed": 122.0, "radius": 10.0, "faction": "police", "innocent": false, "threat": 1.5, "damage": 9.0, "range": 160.0 },
	"swat": { "hp": 150.0, "speed": 120.0, "radius": 11.0, "faction": "police", "innocent": false, "threat": 2.4, "damage": 13.0, "range": 185.0, "armor": 0.25 },
	"hunter": { "hp": 180.0, "speed": 132.0, "radius": 11.0, "faction": "inquis", "innocent": false, "threat": 3.2, "damage": 15.0, "range": 205.0, "armor": 0.30 },
	"elder": { "hp": 420.0, "speed": 120.0, "radius": 13.0, "faction": "inquis", "innocent": false, "threat": 5.0, "damage": 24.0, "range": 220.0, "armor": 0.40 },
	"thrall": { "hp": 70.0, "speed": 118.0, "radius": 9.0, "faction": "player", "innocent": false, "threat": 1.0, "damage": 8.0, "range": 155.0 }
}

const VICTIM_YIELD := {
	"civilian": 22.0,
	"junkie": 18.0,
	"addict": 24.0,
	"athlete": 30.0,
	"noble": 34.0,
	"thug": 26.0,
	"cop": 28.0,
	"hunter": 32.0
}

var entity: SimEntity
var speed: float = 80.0
var threat: float = 0.0
var wander_target: Vector2 = Vector2.ZERO
var _wander_ticks: int = 0

static func configure(e: SimEntity, type_id: String, sim, opts: Dictionary = {}) -> SimEntity:
	var preset: Dictionary = PRESETS.get(type_id, PRESETS["ped"])
	e.kind = "npc"
	e.type_id = type_id
	e.faction = String(preset.get("faction", "civ"))
	e.radius = float(preset.get("radius", 10.0))
	e.max_hp = float(opts.get("hp", preset.get("hp", 40.0)))
	e.hp = e.max_hp
	e.armor = float(preset.get("armor", 0.0))
	e.attack_damage = float(preset.get("damage", 0.0))
	e.attack_range = float(preset.get("range", 0.0))
	e.innocent = bool(preset.get("innocent", false))
	e.hostile_to_player = bool(opts.get("hostile_to_player", e.faction == "inquis"))
	e.responder = bool(opts.get("responder", false))
	e.ai_state = String(opts.get("state", "wander"))
	e.perception_state = "alert" if e.hostile_to_player else "calm"
	e.victim_type = _victim_for_type(type_id, sim)
	e.blood_yield = float(VICTIM_YIELD.get(e.victim_type, 22.0))
	e.blood_left = e.blood_yield * 1.55
	e.home_pos = e.pos
	e.last_seen_pos = e.pos
	var behaviour_script: GDScript = load("res://src/entities/SimNPC.gd") as GDScript
	e.behaviour = behaviour_script.new(e, float(preset.get("speed", 80.0)), float(preset.get("threat", 0.0))) as RefCounted
	return e

func _init(e: SimEntity, npc_speed: float = 80.0, npc_threat: float = 0.0) -> void:
	entity = e
	speed = npc_speed
	threat = npc_threat
	wander_target = entity.pos

func step(delta: float, sim) -> void:
	if entity.dead:
		return
	if entity.ai_state == "fed":
		entity.perception_state = "helpless"
		entity.vel = Vector2.ZERO
		return
	if entity.downed:
		entity.ai_state = "downed"
		entity.perception_state = "helpless"
		return
	if entity.has_status("mesmerized") or entity.has_status("stun"):
		entity.perception_state = "disabled"
		return
	var player: SimEntity = sim.player
	var sees_player := can_see_player(sim)
	if sees_player:
		entity.last_seen_pos = player.pos
		entity.search_ticks = 300
	if entity.responder or entity.hostile_to_player:
		if sees_player:
			entity.ai_state = "chase"
			entity.perception_state = "combat"
		elif entity.search_ticks > 0 and entity.ai_state in ["chase", "attack", "search"]:
			entity.search_ticks -= 1
			entity.ai_state = "search"
			entity.perception_state = "searching"
		elif entity.responder:
			entity.ai_state = "search"
			entity.perception_state = "searching"
	if entity.ai_state == "wander" and sees_player:
		_on_calm_sight(sim)
	match entity.ai_state:
		"wander":
			_wander(delta, sim)
		"investigate", "search":
			_move_toward(entity.last_seen_pos, delta, sim, 0.75)
			if entity.pos.distance_to(entity.last_seen_pos) < 28.0 and not sees_player:
				entity.search_ticks = max(0, entity.search_ticks - 6)
		"guard":
			pass
		"chase":
			_chase(delta, sim)
		"attack":
			_attack(delta, sim)
		"flee":
			_flee(delta, sim)
		_:
			entity.ai_state = "wander"

func can_see_player(sim) -> bool:
	if sim == null or sim.player == null or sim.player.dead:
		return false
	var p: SimEntity = sim.player
	var d := entity.pos.distance_to(p.pos)
	var range := 230.0
	if entity.faction == "police" or entity.faction == "inquis" or entity.responder:
		range = 330.0
	range *= 0.45 + 0.65 * clamp(p.exposure, 0.0, 1.5)
	if p.tags.get("cloaked", false):
		range *= 0.25
	if d > range:
		return false
	if not entity.hostile_to_player and entity.ai_state == "wander" and d > 58.0:
		var off: float = absf(_angle_diff((p.pos - entity.pos).angle(), entity.facing))
		if off > 1.25:
			return false
	if d > 40.0 and sim.world != null and not sim.world.segment_clear(entity.pos, p.pos):
		return false
	return true

func on_damage_taken(_amount: float) -> void:
	if entity.faction == "civ":
		entity.ai_state = "flee"
		entity.perception_state = "afraid"
	else:
		entity.hostile_to_player = true
		entity.ai_state = "chase"
		entity.perception_state = "combat"

func state_hash() -> int:
	return hash([snapped(speed, 0.001), snapped(threat, 0.001), snapped(wander_target.x, 0.001), snapped(wander_target.y, 0.001), _wander_ticks])

static func _victim_for_type(type_id: String, sim) -> String:
	match type_id:
		"cop", "swat":
			return "cop"
		"hunter", "elder":
			return "hunter"
		"thug", "gunner":
			return "thug"
	var pool: Array[String] = ["civilian", "civilian", "junkie", "addict", "athlete", "noble"]
	if sim == null:
		return "civilian"
	return pool[int(sim.draw_index(pool.size()))]

func _on_calm_sight(sim) -> void:
	var p: SimEntity = sim.player
	if entity.faction == "civ":
		if p.tags.get("frenzied", false) or p.exposure > 1.15 or sim.heat_stars() >= 2:
			entity.ai_state = "flee"
			entity.perception_state = "afraid"
			sim.witnessed_act(entity.pos, "panic", 0.35)
	elif entity.faction == "police" and sim.heat_stars() >= 1:
		entity.hostile_to_player = true
		entity.ai_state = "chase"
		entity.perception_state = "combat"
	elif entity.faction == "inquis":
		entity.hostile_to_player = true
		entity.ai_state = "chase"
		entity.perception_state = "combat"

func _wander(delta: float, sim) -> void:
	_wander_ticks -= 1
	if _wander_ticks <= 0 or entity.pos.distance_to(wander_target) < 18.0:
		_wander_ticks = 90 + int(sim.draw_index(150))
		var ordinal: int = int(sim.draw_index(97)) + entity.id
		wander_target = sim.world.nearest_open_around(entity.home_pos, 40.0, 210.0, ordinal)
	_move_toward(wander_target, delta, sim, 0.45)

func _chase(delta: float, sim) -> void:
	var p: SimEntity = sim.player
	if entity.pos.distance_to(p.pos) <= max(entity.attack_range, 42.0):
		entity.ai_state = "attack"
		_attack(delta, sim)
		return
	_move_toward(p.pos, delta, sim, 1.0)

func _attack(delta: float, sim) -> void:
	var p: SimEntity = sim.player
	var dist := entity.pos.distance_to(p.pos)
	if dist > max(entity.attack_range, 42.0) + 16.0:
		entity.ai_state = "chase"
		return
	entity.facing = (p.pos - entity.pos).angle()
	if entity.attack_cooldown <= 0 and entity.attack_damage > 0.0:
		var damage := entity.attack_damage
		if p.behaviour != null and int(p.behaviour.get("iframes_remaining")) > 0:
			damage = 0.0
		if damage > 0.0:
			sim.damage_entity(entity, p, damage, { "cue": "damage.player", "heat": false })
		entity.attack_cooldown = 55 if entity.attack_range > 80.0 else 42

func _flee(delta: float, sim) -> void:
	var player: SimEntity = sim.player as SimEntity
	var away: Vector2 = entity.pos - player.pos
	if away.length_squared() < 1.0:
		away = Vector2.RIGHT.rotated(float(entity.id % 8) * PI * 0.25)
	_move_toward(entity.pos + away.normalized() * 110.0, delta, sim, 1.15)
	if entity.pos.distance_to(player.pos) > 320.0 and not entity.responder:
		entity.ai_state = "wander"
		entity.perception_state = "calm"

func _move_toward(target: Vector2, delta: float, sim, speed_mult: float) -> void:
	var to_target := target - entity.pos
	if to_target.length_squared() < 4.0:
		return
	var dir := to_target.normalized()
	entity.facing = dir.angle()
	var next_pos := entity.pos + dir * speed * speed_mult * delta
	entity.pos = sim.world.resolve_motion(entity.pos, next_pos, entity.radius)

func _angle_diff(a: float, b: float) -> float:
	var d := fmod(a - b, TAU)
	if d > PI:
		d -= TAU
	elif d < -PI:
		d += TAU
	return d
