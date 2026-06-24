## SimEntity.gd -- base sim object for player, NPCs, projectiles, and props.
##
## Pure data plus deterministic logic. Rendering mirrors these objects but never owns
## their mutation. Behaviour delegates (SimPlayer, SimNPC, etc.) add per-kind brains.
extends RefCounted
class_name SimEntity

var id: int
var kind: String
var type_id: String = ""
var faction: String = "neutral"
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var facing: float = 0.0
var radius: float = 12.0
var dead: bool = false
var downed: bool = false

# Action/frame-data state.
var current_action: ActionState = null
var action_frame: int = 0
var cooldowns: Dictionary = {}
var stun: int = 0
var hitstop: int = 0
var knockback_vel: Vector2 = Vector2.ZERO   # impulse channel the AI can't erase (real hit shoves)
var resonance: String = ""   # Blood Grammar: victim's humour (sanguine/choleric/melancholic/phlegmatic)
var mass: float = 1.0   # ImpulsePhysics: heavier bodies resist shoves and deal more impact damage
var tumble_ticks: int = 0   # >0 = TUMBLING from a hard impact: AI suppressed, the rig spins

# Health, combat, and status state.
var hp: float = 100.0
var max_hp: float = 100.0
var armor: float = 0.0
var attack_damage: float = 8.0
var attack_range: float = 44.0
var attack_cooldown: int = 0
var statuses: Dictionary = {}
var status_data: Dictionary = {}
var tags: Dictionary = {}

# AI/perception state.
var ai_state: String = "idle"
var perception_state: String = "calm"
var hostile_to_player: bool = false
var responder: bool = false
var target_id: int = 0
var home_pos: Vector2 = Vector2.ZERO
var last_seen_pos: Vector2 = Vector2.ZERO
var search_ticks: int = 0
var idle_ticks: int = 0
var exposure: float = 0.65

# Feeding/victim data.
var victim_type: String = ""
var blood_yield: float = 22.0
var blood_left: float = 34.0
var innocent: bool = false

var behaviour: RefCounted = null

signal damage_dealt(amount: float)
signal damage_taken(amount: float)

func _init(entity_id: int, entity_kind: String) -> void:
	id = entity_id
	kind = entity_kind
	type_id = entity_kind
	home_pos = pos

func step(delta: float, sim) -> void:
	if dead:
		return
	_tick_statuses(delta, sim)
	if hitstop > 0:
		hitstop -= 1
		return
	if stun > 0:
		stun -= 1
	if attack_cooldown > 0:
		attack_cooldown -= 1
	if current_action != null:
		action_frame += 1
		if action_frame >= current_action.def.total_ticks():
			current_action = null
			action_frame = 0
	var expired: Array = []
	for key in cooldowns:
		cooldowns[key] = int(cooldowns[key]) - 1
		if int(cooldowns[key]) <= 0:
			expired.append(key)
	for key in expired:
		cooldowns.erase(key)
	if kind != "projectile":
		if vel.length_squared() > 0.01:
			var next_pos := pos + vel * delta
			pos = sim.world.resolve_motion(pos, next_pos, radius) if sim != null and sim.world != null else next_pos
			vel *= 0.86
		else:
			vel = Vector2.ZERO
		# Knockback impulse: integrated separately so AI velocity-zeroing can't erase a real shove.
		if knockback_vel.length_squared() > 4.0:
			var kn := pos + knockback_vel * delta
			pos = sim.world.resolve_motion(pos, kn, radius) if sim != null and sim.world != null else kn
			knockback_vel *= 0.80
		else:
			knockback_vel = Vector2.ZERO
	if tumble_ticks > 0 and kind == "npc":
		tumble_ticks -= 1   # tumbling from an impact: physics carries the body, the brain is suppressed
	elif behaviour != null and behaviour.has_method("step"):
		behaviour.step(delta, sim)

func on_damage_dealt(amount: float) -> void:
	damage_dealt.emit(amount)
	if behaviour != null and behaviour.has_method("on_damage_dealt"):
		behaviour.on_damage_dealt(amount)

func on_damage_taken(amount: float) -> void:
	damage_taken.emit(amount)
	if behaviour != null and behaviour.has_method("on_damage_taken"):
		behaviour.on_damage_taken(amount)

func heal_blood(amount: float) -> void:
	if behaviour != null and behaviour.has_method("heal_blood"):
		behaviour.heal_blood(amount)

func begin_action(def: ActionDef, _sim) -> bool:
	if def == null or stun > 0 or hitstop > 0:
		return false
	if cooldowns.has(def.id) and int(cooldowns[def.id]) > 0:
		return false
	current_action = ActionState.new(def)
	action_frame = 0
	cooldowns[def.id] = def.cooldown_ticks
	return true

func action_phase() -> String:
	if current_action == null:
		return ""
	var def := current_action.def
	if action_frame < def.startup:
		return "startup"
	if action_frame < def.startup + def.active:
		return "active"
	if action_frame < def.startup + def.active + def.recovery:
		return "recovery"
	return "done"

func can_cancel_into(next_def: ActionDef) -> bool:
	if current_action == null:
		return true
	if action_phase() != "recovery":
		return false
	return current_action.def.cancel_into.has(next_def.id)

func apply_status(status_id: String, ticks: int, data: Dictionary = {}) -> void:
	if status_id == "" or ticks <= 0:
		return
	if bool(tags.get("warded_mind", false)) and status_id == "fear":
		statuses["warded"] = max(int(statuses.get("warded", 0)), 30)
		return
	statuses[status_id] = max(int(statuses.get(status_id, 0)), ticks)
	if not data.is_empty():
		status_data[status_id] = data.duplicate(true)
	match status_id:
		"stun", "mesmerized":
			stun = max(stun, ticks)
		"fear":
			ai_state = "flee"
			perception_state = "afraid"
		"root":
			stun = max(stun, min(ticks, 12))

func has_status(status_id: String) -> bool:
	return int(statuses.get(status_id, 0)) > 0

func speed_factor() -> float:
	var factor := 1.0
	if has_status("slow"):
		factor *= float(status_data.get("slow", {}).get("factor", 0.60))
	if has_status("shock"):
		factor *= 0.80
	if has_status("root") or has_status("stun"):
		factor *= 0.0
	return factor

func state_hash() -> int:
	var action_id := ""
	if current_action != null and current_action.def != null:
		action_id = current_action.def.id
	var h := hash([
		id, kind, type_id, faction, resonance, snapped(pos.x, 0.001), snapped(pos.y, 0.001),
		snapped(vel.x, 0.001), snapped(vel.y, 0.001),
		snapped(knockback_vel.x, 0.001), snapped(knockback_vel.y, 0.001), snapped(facing, 0.001),
		snapped(hp, 0.001), snapped(max_hp, 0.001), snapped(armor, 0.001),
		snapped(attack_damage, 0.001), snapped(attack_range, 0.001),
		attack_cooldown, dead, downed, action_id, action_frame, stun, hitstop,
		ai_state, perception_state, responder, hostile_to_player, target_id,
		snapped(home_pos.x, 0.001), snapped(home_pos.y, 0.001),
		snapped(last_seen_pos.x, 0.001), snapped(last_seen_pos.y, 0.001),
		search_ticks, idle_ticks, snapped(exposure, 0.001),
		victim_type, snapped(blood_yield, 0.001), snapped(blood_left, 0.001),
		innocent, snapped(mass, 0.001), tumble_ticks
	])
	h = _hash_dict(h, cooldowns)
	h = _hash_dict(h, statuses)
	h = _hash_dict(h, status_data)
	h = _hash_dict(h, tags)
	if behaviour != null and behaviour.has_method("state_hash"):
		h = hash([h, behaviour.state_hash()])
	return h

func _tick_statuses(delta: float, sim) -> void:
	var expired: Array = []
	for key in statuses:
		statuses[key] = int(statuses[key]) - 1
		if int(statuses[key]) <= 0:
			expired.append(key)
			continue
		if key in ["burn", "bleed", "poison"]:
			var data: Dictionary = status_data.get(key, {})
			var dps := float(data.get("dps", 0.0))
			if dps > 0.0 and sim != null and sim.has_method("damage_entity"):
				var src: SimEntity = sim.get_entity(int(data.get("src_id", 0))) if data.has("src_id") else null
				sim.damage_entity(src, self, dps * delta, {
					"cue": "status.%s" % key,
					"crit_chance": 0.0,
					"dot": true,
					"damage_type": String(data.get("damage_type", key)),
				})
	for key in expired:
		statuses.erase(key)
		status_data.erase(key)

func _hash_dict(seed_hash: int, dict: Dictionary) -> int:
	var h := seed_hash
	var keys := dict.keys()
	keys.sort()
	for key in keys:
		h = hash([h, key, dict[key]])
	return h
