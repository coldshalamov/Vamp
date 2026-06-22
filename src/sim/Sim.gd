## Sim.gd -- deterministic authoritative game state.
##
## Scene nodes are views. This singleton owns state mutation, fixed-step simulation,
## AI, collision, combat, blood economy, Heat, responders, and semantic cue events.
extends Node
class_name VCSim

const FIXED_DT := 1.0 / 60.0
const SimNPCScript := preload("res://src/entities/SimNPC.gd")
const SimPlayerScript := preload("res://src/entities/SimPlayer.gd")
const SimProjectileScript := preload("res://src/entities/SimProjectile.gd")
const SimVehicleScript := preload("res://src/entities/SimVehicle.gd")
const SimMetaScript := preload("res://src/sim/SimMeta.gd")

# Sim-owned deterministic draw state. Use draw_* helpers only.
var rng: int = 1

var tick: int = 0
var seed_value: int = 0
var time_scale: float = 1.0
var player: SimEntity = null
var entities: Array[SimEntity] = []
var world: SimWorld = null
var meta = null

var heat: float = 0.0
var last_crime_tick: int = -999999
var last_provoke_tick: int = -999999
var last_seen_pos: Vector2 = Vector2.ZERO
var responder_spawn_ticks: int = 0
var player_last_attack_tick: int = -999999
var escaped: bool = false
var reached_haven: bool = false

var cue_events: Array[Dictionary] = []
var cue_events_this_tick: Array[Dictionary] = []
var _last_vitals_emit_tick: int = -999999
var _next_entity_seq: int = 1

var _recorded_inputs: Array = []
var _replay_queue: Array = []
var _recording: bool = false
var _input_seq: int = 0

func new_game(new_seed_value: int, clan_id: String) -> void:
	seed_value = int(new_seed_value)
	rng = _seed_to_state(seed_value)
	tick = 0
	time_scale = 1.0
	heat = 0.0
	last_crime_tick = -999999
	last_provoke_tick = -999999
	responder_spawn_ticks = 0
	player_last_attack_tick = -999999
	escaped = false
	reached_haven = false
	_next_entity_seq = 1
	entities.clear()
	cue_events.clear()
	cue_events_this_tick.clear()
	_recorded_inputs.clear()
	_replay_queue.clear()
	_recording = false
	_input_seq = 0

	world = SimWorld.new()
	world.load_vertical_slice()
	meta = SimMetaScript.new()
	meta.reset(clan_id)
	last_seen_pos = world.named_points.get("heat_search", Vector2.ZERO)

	player = SimEntity.new(next_entity_id(), "player")
	player.pos = world.named_points.get("player", Vector2(160, 576))
	player.home_pos = player.pos
	player.behaviour = SimPlayerScript.new(player)
	player.tags["clan"] = clan_id
	entities.append(player)

	spawn_npc("ped", world.named_points.get("civilian", Vector2(245, 576)), { "state": "wander" })
	spawn_npc("ped", world.named_points.get("witness", Vector2(330, 560)), { "state": "wander" })
	spawn_npc("thug", world.named_points.get("enemy", Vector2(560, 560)), { "state": "guard", "hostile_to_player": true })
	spawn_vehicle("sedan", Vector2(710, 620), { "angle": 0.0 })
	spawn_vehicle("police", Vector2(960, 622), { "angle": PI, "ai": true, "siren": true })
	meta.generate_mission_offers(self)
	meta.apply_to_runtime(self)
	emit_cue("level.loaded", { "level_id": "vertical_slice_block", "player_spawn": player.pos, "lights": world.lights.size() })

func tick_sim(delta: float) -> void:
	assert(is_equal_approx(delta, FIXED_DT), "Sim.tick_sim must receive the fixed step")
	cue_events_this_tick.clear()
	replay_step()
	tick += 1
	var step_entities := entities.duplicate()
	for e in step_entities:
		if e != null:
			e.step(delta, self)
	tick_combat()
	if meta != null:
		meta.tick(delta, self)
	_update_body_witnesses()
	_update_heat(delta)
	_check_escape()
	_cleanup_dead_transients()

func apply_input(action: InputAction) -> void:
	if _recording:
		_recorded_inputs.append({ "tick": tick, "seq": _input_seq, "action": action.serialize() })
		_input_seq += 1
	if action.kind == InputAction.Kind.INTERACT:
		_try_interact()
		return
	if action.kind == InputAction.Kind.POWER and action.action_id.begins_with("slot_") and meta != null:
		var slot_idx := int(action.action_id.substr(5)) - 1
		var power_id: String = meta.slot_power(slot_idx)
		if power_id != "":
			action = InputAction.new(InputAction.Kind.POWER)
			action.action_id = power_id
	if player != null and player.behaviour != null and player.behaviour.has_method("apply_action"):
		player.behaviour.call("apply_action", action, self)

func tick_combat() -> void:
	for attacker in entities:
		if attacker == null or attacker.dead or attacker.current_action == null:
			continue
		if attacker.action_phase() != "active":
			continue
		var def: ActionDef = attacker.current_action.def
		if def == null or def.damage <= 0.0:
			continue
		var hit_arc := 1.2
		for target in entities:
			if target == attacker or target.dead:
				continue
			if attacker.current_action.hit_targets.has(target.id):
				continue
			var to_target := target.pos - attacker.pos
			var dist := to_target.length()
			if dist > def.range + target.radius:
				continue
			if dist > 1.0:
				var da: float = abs(_angle_diff(to_target.angle(), attacker.facing))
				if da > hit_arc:
					continue
			attacker.current_action.hit_targets.append(target.id)
			attacker.current_action.has_connected = true
			damage_entity(attacker, target, def.damage, {
				"cue": def.cue_on_hit if def.cue_on_hit != "" else "hit.connect",
				"knockback": def.knockback,
				"lifesteal": def.lifesteal,
				"hitstop": def.hitstop_ticks,
				"status": _first_status(def.applies_status),
				"status_ticks": _status_ticks(def.applies_status)
			})

func damage_entity(attacker: SimEntity, target: SimEntity, base_damage: float, opts: Dictionary = {}) -> float:
	if target == null or target.dead:
		return 0.0
	var dmg: float = maxf(0.0, base_damage)
	var dot := bool(opts.get("dot", false))
	if attacker == player and target.tags.has("damage_bonus"):
		dmg *= 1.0 + float(target.tags.get("damage_bonus", 0.0))
	if target.has_status("mark"):
		dmg *= 1.0 + float(target.status_data.get("mark", {}).get("amount", 0.25))
	if target.has_status("shock"):
		dmg *= 1.15
	var crit_chance := float(opts.get("crit_chance", 0.0 if dot else 0.12))
	var crit_mult := 1.5
	if attacker == player and meta != null:
		crit_chance = float(opts.get("crit_chance", meta.derived.get("critChance", crit_chance)))
		crit_mult = float(meta.derived.get("critMult", crit_mult))
	if bool(opts.get("no_crit", false)):
		crit_chance = 0.0
	var crit := false
	if crit_chance > 0.0 and draw_float() < crit_chance:
		dmg *= 1.5
		crit = true
		dmg *= crit_mult / 1.5
	var armor := target.armor
	if target.has_status("weaken"):
		armor = maxf(0.0, armor - float(target.status_data.get("weaken", {}).get("amount", 0.20)))
	if target.tags.has("front_armor") and attacker != null and not dot:
		var hit_angle := float(opts.get("angle", (target.pos - attacker.pos).angle()))
		var da := absf(_angle_diff(hit_angle + PI, target.facing))
		if da < 1.15:
			armor = maxf(armor, float(target.tags["front_armor"]))
	if target.tags.has("resist"):
		var resist: Dictionary = target.tags["resist"]
		var dtype := String(opts.get("damage_type", opts.get("dmgType", "")))
		if dtype != "" and resist.has(dtype):
			dmg *= maxf(0.0, 1.0 - float(resist[dtype]))
	if armor > 0.0:
		dmg *= max(0.15, 1.0 - armor)
	if target == player and player.behaviour != null:
		var player_buffs: Dictionary = player.behaviour.get("buffs")
		if player_buffs.has("for_stone"):
			dmg *= max(0.25, 1.0 - float(player_buffs["for_stone"].get("armor", 0.35)))
		if player_buffs.has("bs_ward"):
			var ward: Dictionary = player_buffs["bs_ward"]
			var absorb := minf(dmg, float(ward.get("shield", 0.0)))
			dmg -= absorb
			ward["shield"] = float(ward.get("shield", 0.0)) - absorb
			player_buffs["bs_ward"] = ward
	dmg = (max(0.0, dmg) if dot else (max(1.0, dmg) if base_damage > 0.0 else 0.0))
	target.hp = max(0.0, target.hp - dmg)
	var hitstop := int(opts.get("hitstop", 0 if dot else 2))
	target.hitstop = max(target.hitstop, hitstop)
	if attacker != null:
		attacker.hitstop = max(attacker.hitstop, hitstop)
		var knockback := float(opts.get("knockback", 0.0))
		if knockback > 0.0:
			target.vel += Vector2.RIGHT.rotated(attacker.facing) * knockback
	var status_id := String(opts.get("status", ""))
	if status_id != "":
		target.apply_status(status_id, int(opts.get("status_ticks", 60)), {
			"dps": float(opts.get("status_dps", _default_status_dps(status_id))),
			"factor": float(opts.get("status_factor", 0.60)),
			"amount": float(opts.get("status_amount", 0.25)),
			"damage_type": String(opts.get("damage_type", status_id)),
			"src_id": attacker.id if attacker != null else 0,
		})
	if attacker != null:
		attacker.on_damage_dealt(dmg)
		if float(opts.get("lifesteal", 0.0)) > 0.0:
			attacker.heal_blood(dmg * float(opts.get("lifesteal", 0.0)))
	target.on_damage_taken(dmg)
	emit_cue(String(opts.get("cue", "damage.dealt")), {
		"attacker_id": attacker.id if attacker != null else 0,
		"target_id": target.id,
		"amount": dmg,
		"pos": target.pos,
		"crit": crit,
		"damage_type": String(opts.get("damage_type", opts.get("dmgType", "physical"))),
	})
	if target.hp <= 0.0:
		if meta != null and meta.try_nemesis_escape(target, self, opts):
			return dmg
		target.dead = true
		_on_entity_killed(attacker, target, opts)
	return dmg

func _default_status_dps(status_id: String) -> float:
	match status_id:
		"burn":
			return 4.0
		"bleed":
			return 2.4
		"poison":
			return 1.8
	return 0.0

func spawn_npc(type_id: String, pos: Vector2, opts: Dictionary = {}) -> SimEntity:
	var e := SimEntity.new(next_entity_id(), "npc")
	e.pos = pos
	e.home_pos = pos
	SimNPCScript.configure(e, type_id, self, opts)
	entities.append(e)
	emit_cue("npc.spawn", { "entity_id": e.id, "type": type_id, "faction": e.faction, "pos": e.pos, "responder": e.responder })
	return e

func spawn_projectile(pos: Vector2, velocity: Vector2, opts: Dictionary = {}) -> SimEntity:
	var e := SimEntity.new(next_entity_id(), "projectile")
	e.pos = pos
	var projectile_opts := opts.duplicate(true)
	projectile_opts["vx"] = velocity.x
	projectile_opts["vy"] = velocity.y
	SimProjectileScript.configure(e, projectile_opts)
	entities.append(e)
	emit_cue("projectile.spawn", { "entity_id": e.id, "kind": e.type_id, "pos": e.pos, "velocity": velocity })
	return e

func spawn_vehicle(type_id: String, pos: Vector2, opts: Dictionary = {}) -> SimEntity:
	var e := SimEntity.new(next_entity_id(), "vehicle")
	e.pos = pos
	SimVehicleScript.configure(e, type_id, opts)
	entities.append(e)
	emit_cue("vehicle.spawn", { "entity_id": e.id, "type": type_id, "pos": pos })
	return e

func get_entity(entity_id: int) -> SimEntity:
	for e in entities:
		if e != null and e.id == entity_id:
			return e
	return null

func nearest_entity(origin: Vector2, radius: float, predicate: Callable) -> SimEntity:
	var best: SimEntity = null
	var best_d2 := radius * radius
	for e in entities:
		if e == null:
			continue
		if not predicate.call(e):
			continue
		var d2 := origin.distance_squared_to(e.pos)
		if d2 <= best_d2:
			best_d2 = d2
			best = e
	return best

func entities_in_radius(origin: Vector2, radius: float, predicate: Callable) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	var r2 := radius * radius
	for e in entities:
		if e == null:
			continue
		if origin.distance_squared_to(e.pos) <= r2 and predicate.call(e):
			out.append(e)
	return out

func witnessed_act(pos: Vector2, act_type: String, amount: float) -> void:
	var witnesses := 0
	var player_cloaked: bool = player != null and bool(player.tags.get("cloaked", false))
	for e in entities:
		if e == null or e.dead or e.downed or e == player:
			continue
		if e.faction in ["civ", "gang", "police", "inquis"] and e.pos.distance_to(pos) < 260.0 and not player_cloaked:
			witnesses += 1
			if e.kind == "npc" and e.faction == "civ":
				e.ai_state = "flee"
				e.perception_state = "afraid"
	var always := act_type in ["kill", "explosion", "body", "combat"]
	if witnesses <= 0 and not always:
		return
	var domain_mult: float = meta.heat_mult_at(pos) if meta != null else 1.0
	var gain: float = minf(1.5, amount * (0.45 + minf(0.8, float(witnesses) * 0.22)) * domain_mult)
	add_heat(gain, act_type)
	last_crime_tick = tick
	last_provoke_tick = tick
	last_seen_pos = pos
	emit_cue("masquerade.broken", { "act": act_type, "witnesses": witnesses, "pos": pos, "heat": heat })

func add_heat(amount: float, reason: String = "") -> void:
	var before := heat_stars()
	heat = clamp(heat + amount, 0.0, 6.0)
	var after := heat_stars()
	if after > before:
		emit_cue("heat.rise", { "stars": after, "heat": heat, "reason": reason, "pos": last_seen_pos })
	else:
		emit_cue("heat.changed", { "stars": after, "heat": heat, "reason": reason })

func reduce_heat(amount: float, reason: String = "") -> void:
	var before := heat_stars()
	heat = clamp(heat - amount, 0.0, 6.0)
	var after := heat_stars()
	if after < before:
		emit_cue("heat.fall", { "stars": after, "heat": heat, "reason": reason })

func heat_stars() -> int:
	return min(6, int(floor(heat)))

func break_responder_locks() -> void:
	for e in entities:
		if e != null and e.responder and not e.dead:
			e.ai_state = "search"
			e.perception_state = "searching"
			e.search_ticks = min(e.search_ticks, 120)
			e.hostile_to_player = false

func clear_witness_panic() -> void:
	for e in entities:
		if e != null and e.kind == "npc" and e.faction == "civ" and e.ai_state == "flee":
			e.ai_state = "wander"
			e.perception_state = "calm"

func emit_vitals_changed() -> void:
	if tick - _last_vitals_emit_tick < 15 or player == null or player.behaviour == null:
		return
	_last_vitals_emit_tick = tick
	emit_cue("blood.changed", {
		"blood": player.behaviour.get("blood"),
		"max_blood": player.behaviour.get("max_blood"),
		"hunger": player.behaviour.get("hunger"),
		"frenzied": player.behaviour.get("frenzied"),
		"hp": player.hp,
		"max_hp": player.max_hp
	})

func emit_cue(event_id: String, payload: Dictionary = {}) -> void:
	var rec := { "tick": tick, "id": event_id, "payload": payload.duplicate(true) }
	cue_events.append(rec)
	cue_events_this_tick.append(rec)
	if meta != null:
		meta.mission_event(event_id, payload, self)
	if is_inside_tree():
		var cue_bus := get_tree().root.get_node_or_null("CueBus")
		if cue_bus != null and cue_bus.has_method("emit_cue"):
			cue_bus.call_deferred("emit_cue", event_id, payload.duplicate(true))

func next_entity_id() -> int:
	var id := _next_entity_seq
	_next_entity_seq += 1
	return id

func draw_u32() -> int:
	rng = int((int(rng) * 1664525 + 1013904223) % 4294967296)
	if rng < 0:
		rng += 4294967296
	return rng

func draw_float() -> float:
	return float(draw_u32()) / 4294967296.0

func draw_index(count: int) -> int:
	if count <= 0:
		return 0
	return int(draw_u32() % count)

func state_hash() -> int:
	var h := hash([
		seed_value, rng, tick, _next_entity_seq, snapped(heat, 0.001), heat_stars(),
		last_crime_tick, last_provoke_tick, snapped(last_seen_pos.x, 0.001),
		snapped(last_seen_pos.y, 0.001), responder_spawn_ticks,
		player_last_attack_tick, _last_vitals_emit_tick, time_scale,
		escaped, reached_haven
	])
	for e in entities:
		if e != null:
			h = hash([h, e.state_hash()])
	if meta != null:
		h = hash([h, meta.state_hash()])
	return h

func serialize_run() -> Dictionary:
	return {
		"seed": seed_value,
		"rng": rng,
		"tick": tick,
		"heat": heat,
		"last_crime_tick": last_crime_tick,
		"last_provoke_tick": last_provoke_tick,
		"last_seen_pos": last_seen_pos,
		"responder_spawn_ticks": responder_spawn_ticks,
		"player_last_attack_tick": player_last_attack_tick,
		"escaped": escaped,
		"reached_haven": reached_haven,
		"meta": meta.serialize(self) if meta != null else {},
	}

func restore_run(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var clan := "brujah"
	if data.has("meta") and data["meta"] is Dictionary:
		clan = String((data["meta"] as Dictionary).get("clan", clan))
	new_game(int(data.get("seed", seed_value)), clan)
	rng = int(data.get("rng", rng))
	tick = int(data.get("tick", tick))
	heat = clamp(float(data.get("heat", heat)), 0.0, 6.0)
	last_crime_tick = int(data.get("last_crime_tick", last_crime_tick))
	last_provoke_tick = int(data.get("last_provoke_tick", last_provoke_tick))
	if data.get("last_seen_pos", null) is Vector2:
		last_seen_pos = data["last_seen_pos"]
	responder_spawn_ticks = int(data.get("responder_spawn_ticks", responder_spawn_ticks))
	player_last_attack_tick = int(data.get("player_last_attack_tick", player_last_attack_tick))
	escaped = bool(data.get("escaped", escaped))
	reached_haven = bool(data.get("reached_haven", reached_haven))
	if data.has("meta") and data["meta"] is Dictionary and meta != null:
		meta.restore(data["meta"], self)
	emit_cue("save.restored", { "tick": tick, "day": meta.day if meta != null else 1 })
	return true

func start_recording() -> void:
	_recording = true
	_recorded_inputs.clear()
	_input_seq = 0

func recorded_inputs() -> Array:
	return _recorded_inputs.duplicate(true)

func replay_step() -> bool:
	while not _replay_queue.is_empty() and int(_replay_queue[0]["tick"]) <= tick:
		var entry: Dictionary = _replay_queue.pop_front()
		var action := InputAction.deserialize(entry["action"])
		if player != null and player.behaviour != null:
			player.behaviour.call("apply_action", action, self)
	return _replay_queue.is_empty()

func load_replay(inputs: Array) -> void:
	_replay_queue = inputs.duplicate(true)
	_replay_queue.sort_custom(func(a, b) -> bool:
		var a_dict: Dictionary = a as Dictionary
		var b_dict: Dictionary = b as Dictionary
		var a_tick: int = int(a_dict.get("tick", 0))
		var b_tick: int = int(b_dict.get("tick", 0))
		if a_tick == b_tick:
			return int(a_dict.get("seq", 0)) < int(b_dict.get("seq", 0))
		return a_tick < b_tick
	)

func _update_heat(delta: float) -> void:
	if heat <= 0.0:
		return
	var seen := false
	var near_responder := false
	for e in entities:
		if e == null or e.dead or not e.responder:
			continue
		var d := e.pos.distance_to(player.pos)
		if d < 720.0:
			near_responder = true
		if e.behaviour != null and e.behaviour.has_method("can_see_player") and d < 380.0 and bool(e.behaviour.call("can_see_player", self)):
			seen = true
			last_seen_pos = player.pos
	var since_provoke := float(tick - last_provoke_tick) / 60.0
	var decay := 0.0
	if seen:
		decay = 0.0
	elif near_responder:
		decay = 0.05
	elif since_provoke < 6.0:
		decay = 0.0
	else:
		decay = 0.30 + min(0.9, (since_provoke - 6.0) * 0.12)
	if player != null and player.tags.get("cloaked", false):
		decay += 0.20
	if world != null and world.is_in_haven(player.pos):
		decay += 0.8
	if decay > 0.0:
		reduce_heat(decay * delta, "evade")
	if heat <= 0.0:
		heat = 0.0
		for e in entities:
			if e != null and e.responder and not e.dead:
				e.responder = false
				e.hostile_to_player = false
				e.ai_state = "wander"
				e.perception_state = "calm"
		emit_cue("heat.lost_them", { "pos": player.pos })
		return
	responder_spawn_ticks -= 1
	var desired := _desired_responders()
	var current := _responder_count()
	var dispatching := seen or float(tick - last_provoke_tick) / 60.0 < 10.0
	if responder_spawn_ticks <= 0 and current < desired and heat_stars() > 0 and dispatching:
		_spawn_responder()
		responder_spawn_ticks = max(48, 156 - heat_stars() * 15)

func _spawn_responder() -> void:
	var stars := heat_stars()
	var type_id := "cop"
	if stars >= 6 and draw_float() < 0.5:
		type_id = "elder"
	elif stars >= 5:
		type_id = "hunter" if draw_float() < 0.6 else "swat"
	elif stars >= 3:
		type_id = "swat" if draw_float() < 0.5 else "cop"
	var pos := world.nearest_open_around(last_seen_pos, 120.0, 520.0, draw_index(997) + _responder_count() * 13)
	var e := spawn_npc(type_id, pos, { "responder": true, "hostile_to_player": true, "state": "chase" })
	e.responder = true
	e.hostile_to_player = true
	e.last_seen_pos = last_seen_pos
	e.search_ticks = 420

func _desired_responders() -> int:
	match heat_stars():
		0:
			return 0
		1:
			return 1
		2:
			return 3
		3:
			return 5
		4:
			return 7
		5:
			return 9
	return 12

func _responder_count() -> int:
	var count := 0
	for e in entities:
		if e != null and e.responder and not e.dead:
			count += 1
	return count

func _check_escape() -> void:
	if player == null or world == null:
		return
	if world.is_in_haven(player.pos):
		reached_haven = true
	if not escaped and world.is_in_exit(player.pos) and heat <= 0.25:
		escaped = true
		emit_cue("player.escape", { "pos": player.pos, "tick": tick })

func _on_entity_killed(attacker: SimEntity, target: SimEntity, _opts: Dictionary) -> void:
	if attacker == player and target.kind == "npc" and not bool(target.tags.get("no_body", false)) and (target.innocent or bool(target.tags.get("fed_on", false))):
		target.tags["player_body"] = true
		target.tags["body_discovered"] = false
	emit_cue("npc.death", { "entity_id": target.id, "type": target.type_id, "pos": target.pos })
	if target.tags.has("nemesis_name") and meta != null:
		meta.on_nemesis_dead(target, self)
	if target.tags.has("baron_of") and meta != null:
		meta.claim_domain(String(target.tags["baron_of"]), self)
	if attacker != null and attacker.tags.has("coterie_id") and meta != null:
		meta.coterie_ally_kill(attacker, self)
	if meta != null and target.faction in ["police", "gang", "inquis"]:
		meta.change_reputation(target.faction, -2.0 if target.faction == "police" else -1.5, self)
	if attacker == player and player.behaviour != null:
		player.behaviour.set("kills", int(player.behaviour.get("kills")) + 1)
		if target.innocent:
			player.behaviour.set("innocent_kills", int(player.behaviour.get("innocent_kills")) + 1)
			player.behaviour.set("humanity", max(0.0, float(player.behaviour.get("humanity")) - 0.25))
			emit_cue("humanity.lost", { "humanity": player.behaviour.get("humanity"), "target_id": target.id })
		if target.faction in ["gang", "police", "inquis"]:
			witnessed_act(target.pos, "combat", 0.5)

func _first_status(statuses: Dictionary) -> String:
	var keys := statuses.keys()
	keys.sort()
	return String(keys[0]) if keys.size() > 0 else ""

func _status_ticks(statuses: Dictionary) -> int:
	var key := _first_status(statuses)
	if key == "":
		return 0
	var rec = statuses[key]
	if rec is Dictionary:
		return int((rec as Dictionary).get("dur_ticks", 60))
	return 60

func _angle_diff(a: float, b: float) -> float:
	var d := fmod(a - b, TAU)
	if d > PI:
		d -= TAU
	elif d < -PI:
		d += TAU
	return d

func _seed_to_state(value: int) -> int:
	var state := int(value) % 4294967296
	if state <= 0:
		state += 1
	return state

func _try_interact() -> bool:
	if player == null:
		return false
	var behaviour = player.behaviour
	if behaviour != null and behaviour.has_method("try_toggle_carry") and bool(behaviour.call("try_toggle_carry", self)):
		return true
	if behaviour != null and int(behaviour.get("vehicle_id")) != 0:
		var current := get_entity(int(behaviour.get("vehicle_id")))
		if current != null and current.behaviour != null and current.behaviour.has_method("exit"):
			current.behaviour.call("exit", player, self)
			behaviour.set("vehicle_id", 0)
			return true
	var vehicle := nearest_entity(player.pos, 58.0, func(e: SimEntity) -> bool: return e.kind == "vehicle" and not e.dead) as SimEntity
	if vehicle != null and vehicle.behaviour != null and vehicle.behaviour.has_method("enter"):
		if bool(vehicle.behaviour.call("enter", player, self)):
			behaviour.set("vehicle_id", vehicle.id)
			if meta != null:
				meta.stats["hijacks"] = int(meta.stats.get("hijacks", 0)) + 1
			return true
	return false

func _update_body_witnesses() -> void:
	if player == null:
		return
	for body in entities:
		if body == null or body.kind != "npc":
			continue
		if not bool(body.tags.get("player_body", false)):
			continue
		if bool(body.tags.get("body_discovered", false)) or bool(body.tags.get("carried", false)):
			continue
		if not (body.dead or body.downed):
			continue
		var witness: SimEntity = nearest_entity(body.pos, 190.0, func(e: SimEntity) -> bool:
			return e != body and e.kind == "npc" and not e.dead and not e.downed and e.faction in ["civ", "gang", "police", "inquis"]
		) as SimEntity
		if witness == null:
			continue
		if world != null and not world.segment_clear(witness.pos, body.pos):
			continue
		body.tags["body_discovered"] = true
		if meta != null:
			meta.stats["bodiesFound"] = int(meta.stats.get("bodiesFound", 0)) + 1
		witnessed_act(body.pos, "body", 1.0)
		emit_cue("body.discovered", { "body_id": body.id, "witness_id": witness.id, "pos": body.pos, "heat": heat })

func _cleanup_dead_transients() -> void:
	for i in range(entities.size() - 1, -1, -1):
		var e := entities[i]
		if e != null and e.dead and e.kind in ["projectile"]:
			entities.remove_at(i)
