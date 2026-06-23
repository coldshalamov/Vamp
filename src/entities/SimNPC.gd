## SimNPC.gd -- deterministic NPC AI for the vertical-slice backend.
##
## Ports the legacy wander/chase/flee/search loop into pure sim logic. Perception reads
## player exposure, line-of-sight, faction, heat, and responder state.
extends RefCounted
class_name SimNPC

const PRESETS := {
	"ped": { "hp": 28.0, "speed": 78.0, "radius": 9.0, "faction": "civ", "innocent": true, "threat": 0.0, "damage": 0.0, "range": 0.0 },
	"thug": { "hp": 60.0, "speed": 96.0, "radius": 10.0, "faction": "gang", "innocent": false, "threat": 1.0, "damage": 7.0, "range": 42.0, "armor": 0.05, "weapon": "bat" },
	"gunner": { "hp": 55.0, "speed": 92.0, "radius": 10.0, "faction": "gang", "innocent": false, "threat": 1.2, "damage": 9.0, "range": 155.0, "armor": 0.05, "weapon": "pistol", "burst": true },
	"cop": { "hp": 85.0, "speed": 122.0, "radius": 10.0, "faction": "police", "innocent": false, "threat": 1.5, "damage": 9.0, "range": 160.0, "armor": 0.10, "weapon": "pistol" },
	"swat": { "hp": 150.0, "speed": 120.0, "radius": 11.0, "faction": "police", "innocent": false, "threat": 2.4, "damage": 13.0, "range": 185.0, "armor": 0.25, "front_armor": 0.72, "weapon": "rifle" },
	"hunter": { "hp": 180.0, "speed": 132.0, "radius": 11.0, "faction": "inquis", "innocent": false, "threat": 3.2, "damage": 15.0, "range": 205.0, "armor": 0.30, "weapon": "rifle", "potent": true },
	"elder": { "hp": 420.0, "speed": 120.0, "radius": 13.0, "faction": "inquis", "innocent": false, "threat": 5.0, "damage": 24.0, "range": 220.0, "armor": 0.40, "weapon": "rifle", "boss": true, "potent": true },
	"thrall": { "hp": 70.0, "speed": 118.0, "radius": 9.0, "faction": "player", "innocent": false, "threat": 1.0, "damage": 8.0, "range": 155.0, "armor": 0.10, "weapon": "pistol" },
	"rat": { "hp": 8.0, "speed": 64.0, "radius": 5.0, "faction": "animal", "innocent": true, "threat": 0.0, "damage": 0.0, "range": 0.0, "animal": true },
}

const ELITE_AFFIXES := {
	"brute": { "name": "Brute", "hp": 2.2, "damage": 1.5, "radius": 1.3, "armor": 0.10 },
	"swift": { "name": "Swift", "hp": 1.4, "speed": 1.45 },
	"warded": { "name": "Warded", "hp": 1.6, "armor": 0.35, "warded_mind": true },
	"venomous": { "name": "Venomous", "hp": 1.4, "venom": true },
	"vampiric": { "name": "Vampiric", "hp": 1.8, "vampiric": true },
	"juggernaut": { "name": "Juggernaut", "hp": 3.0, "damage": 1.6, "radius": 1.4, "armor": 0.25, "speed": 0.85, "warded_mind": true },
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
var path: Array[Vector2] = []
var path_index: int = 0
var path_ticks: int = 0
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
	e.tags["weapon"] = String(preset.get("weapon", ""))
	e.tags["threat"] = float(preset.get("threat", 0.0))
	if bool(preset.get("boss", false)):
		e.tags["boss"] = true
		e.tags["warded_mind"] = true
	if preset.has("front_armor"):
		e.tags["front_armor"] = float(preset["front_armor"])
	if opts.has("resist") and opts["resist"] is Dictionary:
		e.tags["resist"] = (opts["resist"] as Dictionary).duplicate(true)
	e.victim_type = _victim_for_type(type_id, sim)
	e.blood_yield = float(VICTIM_YIELD.get(e.victim_type, 22.0))
	e.blood_left = e.blood_yield * 1.55
	e.home_pos = e.pos
	e.last_seen_pos = e.pos
	_apply_elite(e, sim, opts)
	var behaviour_script: GDScript = load("res://src/entities/SimNPC.gd") as GDScript
	e.behaviour = behaviour_script.new(e, float(preset.get("speed", 80.0)) * float(e.tags.get("speed_mult", 1.0)), float(e.tags.get("threat", preset.get("threat", 0.0)))) as RefCounted
	return e

func _init(e: SimEntity, npc_speed: float = 80.0, npc_threat: float = 0.0) -> void:
	entity = e
	speed = npc_speed
	threat = npc_threat
	wander_target = entity.pos

func step(delta: float, sim) -> void:
	if entity.dead:
		return
	# Being shoved: let the knockback fly instead of immediately pursuing through it (hit-reaction feel).
	if entity.knockback_vel.length_squared() > 900.0:
		entity.vel = Vector2.ZERO
		return
	if bool(entity.tags.get("carried", false)):
		entity.ai_state = "carried"
		entity.perception_state = "hidden"
		entity.vel = Vector2.ZERO
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
	if entity.ai_state == "follow" and entity.faction == "player":
		_follow(delta, sim)
		return
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
		"follow":
			_follow(delta, sim)
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
	var h := hash([snapped(speed, 0.001), snapped(threat, 0.001), snapped(wander_target.x, 0.001), snapped(wander_target.y, 0.001), _wander_ticks, path_index, path_ticks])
	for p in path:
		h = hash([h, snapped(p.x, 0.001), snapped(p.y, 0.001)])
	return h

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

func _follow(delta: float, sim) -> void:
	var target: SimEntity = sim.nearest_entity(entity.pos, 300.0, func(e: SimEntity) -> bool: return e.kind == "npc" and e.faction != "player" and not e.dead and e.hostile_to_player) as SimEntity
	if target != null:
		if entity.pos.distance_to(target.pos) <= max(entity.attack_range, 42.0):
			_attack_npc(target, sim)
		else:
			_move_toward(target.pos, delta, sim, 1.0)
		return
	var desired: Vector2 = sim.player.pos - Vector2.RIGHT.rotated(sim.player.facing) * 42.0
	if entity.pos.distance_to(desired) > 72.0:
		_move_toward(desired, delta, sim, 0.9)
	else:
		path.clear()
		entity.perception_state = "loyal"

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
			sim.damage_entity(entity, p, damage, { "cue": "damage.player", "heat": false, "status": "poison" if bool(entity.tags.get("elite_venom", false)) else "", "status_ticks": 180, "status_dps": 1.6 if bool(entity.tags.get("elite_venom", false)) else 0.0 })
			if bool(entity.tags.get("elite_vampiric", false)):
				entity.hp = minf(entity.max_hp, entity.hp + damage * 0.35)
		entity.attack_cooldown = 55 if entity.attack_range > 80.0 else 42

func _attack_npc(target: SimEntity, sim) -> void:
	entity.facing = (target.pos - entity.pos).angle()
	if entity.attack_cooldown <= 0 and entity.attack_damage > 0.0:
		sim.damage_entity(entity, target, entity.attack_damage, { "cue": "damage.npc", "crit_chance": 0.0, "knockback": 35.0 })
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
	var destination := target
	if sim.world != null and not sim.world.segment_clear(entity.pos, target):
		path_ticks -= 1
		if path.is_empty() or path_ticks <= 0:
			path = sim.world.find_path(entity.pos, target, 1400)
			path_index = min(1, path.size() - 1)
			path_ticks = 30 + int(entity.id % 17)
		if path.size() > 0:
			if path_index >= path.size():
				path.clear()
			else:
				destination = path[path_index]
				if entity.pos.distance_to(destination) < 18.0:
					path_index += 1
					if path_index < path.size():
						destination = path[path_index]
	else:
		path.clear()
	var to_target := target - entity.pos
	if destination != target:
		to_target = destination - entity.pos
	if to_target.length_squared() < 4.0:
		return
	var dir := to_target.normalized()
	entity.facing = dir.angle()
	var next_pos: Vector2 = entity.pos + dir * speed * speed_mult * entity.speed_factor() * delta
	entity.pos = sim.world.resolve_motion(entity.pos, next_pos, entity.radius)

static func _apply_elite(e: SimEntity, sim, opts: Dictionary) -> void:
	if not opts.has("elite"):
		return
	var raw_elite = opts["elite"]
	if raw_elite is bool and not bool(raw_elite):
		return
	var elite_id := "" if raw_elite is bool else String(raw_elite)
	if elite_id == "" or not ELITE_AFFIXES.has(elite_id):
		var keys := ELITE_AFFIXES.keys()
		keys.sort()
		elite_id = String(keys[sim.draw_index(keys.size())]) if sim != null else String(keys[0])
	var affix: Dictionary = ELITE_AFFIXES.get(elite_id, {})
	if affix.is_empty():
		return
	e.tags["elite"] = elite_id
	e.tags["elite_name"] = String(affix.get("name", elite_id))
	e.max_hp = roundf(e.max_hp * float(affix.get("hp", 1.0)))
	e.hp = e.max_hp
	e.attack_damage *= float(affix.get("damage", 1.0))
	e.armor += float(affix.get("armor", 0.0))
	e.radius *= float(affix.get("radius", 1.0))
	e.tags["speed_mult"] = float(affix.get("speed", 1.0))
	if bool(affix.get("warded_mind", false)):
		e.tags["warded_mind"] = true
	if bool(affix.get("venom", false)):
		e.tags["elite_venom"] = true
	if bool(affix.get("vampiric", false)):
		e.tags["elite_vampiric"] = true
	e.tags["threat"] = float(e.tags.get("threat", 1.0)) + 1.5

func _angle_diff(a: float, b: float) -> float:
	var d := fmod(a - b, TAU)
	if d > PI:
		d -= TAU
	elif d < -PI:
		d += TAU
	return d
