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
var sigils: Array[Dictionary] = []   # Blood Grammar INSCRIBE: active blood-sigils rewriting local rules
var player_last_attack_tick: int = -999999
var escaped: bool = false
var reached_haven: bool = false
var investigations: Array[Dictionary] = []
var last_body_carried_seen_tick: int = -999999

const CUE_LOG_CAP := 1024  # bound the debug cue log; nothing reads it historically, so trimming is safe. This is the ~30s memory-growth freeze.
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
	investigations.clear()
	last_body_carried_seen_tick = -999999
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
	# Wire the AI car to the road it spawns on (upper horizontal road, rows 17-22) and to its
	# initial heading (faces west -> road_dir -1), so lane-following holds the street instead of
	# relying on defaults. Ambient traffic + axis-inference-from-road is a world-life task later.
	spawn_vehicle("police", Vector2(960, 622), { "angle": PI, "ai": true, "siren": true, "road_axis": 0, "road_dir": -1 })
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
	ImpulsePhysics.resolve(self)   # deterministic momentum/impact pass (throws, knockback, collisions)
	tick_combat()
	if world != null and tick % 18 == 0:
		world.decay_blood()
	if world != null and tick % 5 == 0:
		_tick_fire()
	_tick_sigils()
	if meta != null:
		meta.tick(delta, self)
	_update_body_witnesses()
	_update_investigations(delta)
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
	# Choleric resonance: +melee while the buff lasts (the "feed-on-rage" combat build).
	if attacker == player and player.behaviour != null and not dot:
		var atk_buffs: Dictionary = player.behaviour.get("buffs")
		var dt0 := String(opts.get("damage_type", "physical"))
		if dt0 == "physical" or dt0 == "":
			if atk_buffs.has("res_choleric"):
				dmg *= 1.0 + float(atk_buffs["res_choleric"].get("melee", 0.25))
			var fs := int(player.behaviour.get("flow_stacks"))
			if fs > 0:
				dmg *= 1.0 + float(fs) * 0.08   # gulp-cancel flow rewards the dance
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
		if player_buffs.has("res_phlegmatic"):
			dmg *= max(0.4, 1.0 - float(player_buffs["res_phlegmatic"].get("armor", 0.20)))
		if player_buffs.has("bs_ward"):
			var ward: Dictionary = player_buffs["bs_ward"]
			var absorb := minf(dmg, float(ward.get("shield", 0.0)))
			dmg -= absorb
			ward["shield"] = float(ward.get("shield", 0.0)) - absorb
			player_buffs["bs_ward"] = ward
	dmg = (max(0.0, dmg) if dot else (max(1.0, dmg) if base_damage > 0.0 else 0.0))
	target.hp = max(0.0, target.hp - dmg)
	# SPILL (Blood Grammar): a real wound bleeds onto the ground, scaled by the blow.
	if world != null and not dot and dmg > 0.0 and base_damage > 0.0:
		world.spill_blood(target.pos, clampi(int(dmg * 0.5), 2, 26))
	var hitstop := int(opts.get("hitstop", 0 if dot else 2))
	target.hitstop = max(target.hitstop, hitstop)
	if attacker != null:
		attacker.hitstop = max(attacker.hitstop, hitstop)
		var knockback := float(opts.get("knockback", 0.0))
		if knockback > 0.0:
			# Shove direction: radially out from the attacker (works for melee + AoE blasts).
			var kdir := (target.pos - attacker.pos)
			kdir = kdir.normalized() if kdir.length() > 0.01 else Vector2.RIGHT.rotated(attacker.facing)
			target.knockback_vel += kdir * knockback
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
		if target == player:
			emit_cue("player.died", { "pos": target.pos, "killer_id": attacker.id if attacker != null else 0 })
	elif target == player and meta != null:
		meta.gain_mastery("survival", dmg * 0.18, self)
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

## Wake from torpor: revive the player at their haven/spawn instead of leaving a dead, frozen world.
## Costs Humanity (the Beast claws you back). Called by the death screen on "rise again".
func revive_player() -> void:
	if player == null:
		return
	player.dead = false
	player.downed = false
	player.hp = player.max_hp
	if player.behaviour != null:
		player.behaviour.set("blood", maxf(35.0, float(player.behaviour.get("blood"))))
		player.behaviour.set("frenzied", false)
		player.behaviour.set("humanity", maxf(0.0, float(player.behaviour.get("humanity")) - 0.5))
		player.behaviour.set("feeding_target_id", 0)
	player.pos = player.home_pos
	player.vel = Vector2.ZERO
	heat = maxf(0.0, heat - 2.0)
	# Disperse anyone actively hunting so you don't wake into the same death.
	for e in entities:
		if e != null and e.kind == "npc" and e.hostile_to_player:
			e.ai_state = "wander"
			e.perception_state = "unaware"
	emit_cue("player.respawn", { "pos": player.pos })


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
	var before_heat := heat
	heat = clamp(heat - amount, 0.0, 6.0)
	var after := heat_stars()
	if meta != null and before_heat >= 5.0 and before_heat - heat >= 5.0:
		meta.stats["clearedFiveHeat"] = int(meta.stats.get("clearedFiveHeat", 0)) + 1
		emit_cue("heat.cleared_five", { "heat_before": before_heat, "heat": heat, "reason": reason })
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
			e.tags.erase("witness_alarm_tick")
			e.tags.erase("witness_body_id")
			e.tags.erase("witness_alarm_pos")

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
	if cue_events.size() > CUE_LOG_CAP:
		cue_events = cue_events.slice(cue_events.size() - (CUE_LOG_CAP / 2))
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
		escaped, reached_haven, last_body_carried_seen_tick,
		_hash_variant(investigations)
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
		"investigations": investigations.duplicate(true),
		"last_body_carried_seen_tick": last_body_carried_seen_tick,
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
	investigations = _clean_investigations(data.get("investigations", []))
	last_body_carried_seen_tick = int(data.get("last_body_carried_seen_tick", last_body_carried_seen_tick))
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

## REACT: burning blood damages whoever stands in it (via the burn DoT) and spreads to adjacent
## spilled blood, consuming it as fuel. Deterministic — fixed iteration, no RNG.
func _tick_fire() -> void:
	if world == null or world._burning.is_empty():
		return
	var sx: int = world.size.x
	var sy: int = world.size.y
	for e in entities:
		if e == null or e.dead or (e.kind != "player" and e.kind != "npc"):
			continue
		if world.fire_at(e.pos) > 0:
			e.apply_status("burn", 50, { "dps": 5.0, "damage_type": "fire" })
	var newly: Array = []
	for key in world._burning.keys():
		var i: int = int(key)
		var ft: int = world.fire[i]
		if ft <= 0:
			world._burning.erase(i)
			continue
		var cx: int = i % sx
		var cy: int = i / sx
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or ny < 0 or nx >= sx or ny >= sy:
				continue
			var ni: int = ny * sx + nx
			if world.fire[ni] == 0 and world.walls[ni] == 0 and world.blood[ni] > 10:
				newly.append(ni)
		world.fire[i] = maxi(0, ft - 5)
		if world.fire[i] == 0:
			world._burning.erase(i)
	for ni in newly:
		world.fire[ni] = maxi(world.fire[ni], 40)
		world.blood[ni] = maxi(0, world.blood[ni] - 25)   # fire consumes the blood fuel
		world._burning[ni] = true


## INSCRIBE: paint a blood-sigil that rewrites one rule within its radius until it fades.
func inscribe_sigil(pos: Vector2, rule: String, radius: float, ticks: int) -> void:
	sigils.append({ "pos": pos, "rule": rule, "radius": radius, "ticks": ticks })
	emit_cue("sigil.inscribe", { "pos": pos, "rule": rule, "radius": radius })


func _tick_sigils() -> void:
	if sigils.is_empty():
		return
	for i in range(sigils.size() - 1, -1, -1):
		var s: Dictionary = sigils[i]
		s["ticks"] = int(s["ticks"]) - 1
		if int(s["ticks"]) <= 0:
			sigils.remove_at(i)
			continue
		if tick % 6 != 0:
			continue
		match String(s["rule"]):
			"fear_is_damage":
				# "FEAR IS DAMAGE": within the sigil, a frightened enemy is seared.
				var rad: float = float(s["radius"])
				var c: Vector2 = s["pos"]
				for e in entities:
					if e == null or e.dead or e.kind != "npc" or e.faction == "civ":
						continue
					if e.has_status("fear") and e.pos.distance_to(c) <= rad:
						e.apply_status("burn", 24, { "dps": 7.0, "damage_type": "blood" })


func _kill_xp(target: SimEntity) -> int:
	match target.faction:
		"inquis": return 30
		"police": return 22
		"gang": return 16
		"civ": return 6
	return 10


func _on_entity_killed(attacker: SimEntity, target: SimEntity, _opts: Dictionary) -> void:
	if world != null:
		world.spill_blood(target.pos, 75)   # a death leaves a real pool
	if attacker == player and target.kind == "npc" and not bool(target.tags.get("no_body", false)) and (target.innocent or bool(target.tags.get("fed_on", false))):
		target.tags["player_body"] = true
		target.tags["body_discovered"] = false
	emit_cue("npc.death", { "entity_id": target.id, "type": target.type_id, "pos": target.pos })
	if target.tags.has("nemesis_name") and meta != null:
		meta.on_nemesis_dead(target, self)
	if target.tags.has("bounty") and meta != null:
		meta.claim_bounty(target, self)
	if target.tags.has("baron_of") and meta != null:
		meta.claim_domain(String(target.tags["baron_of"]), self)
	if attacker != null and attacker.tags.has("coterie_id") and meta != null:
		meta.coterie_ally_kill(attacker, self)
	if attacker == player and meta != null:
		meta.gain_mastery("brawn", 5.0, self)
		meta.award_trophy_for(target, self)
		meta.codex_mark("killedKinds", target.faction if target.faction != "" else target.type_id, self)
		var kxp := _kill_xp(target)
		meta.gain_xp(kxp, self)
		emit_cue("player.xp", { "amount": kxp, "pos": target.pos, "reason": "kill" })
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
				meta.gain_mastery("driving", 8.0, self)
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
		if bool(body.tags.get("dumped", false)):
			continue
		if not (body.dead or body.downed):
			continue
		var find_range := 46.0 if bool(body.tags.get("hidden_body", false)) else 132.0
		var witness: SimEntity = nearest_entity(body.pos, find_range, func(e: SimEntity) -> bool:
			return e != body and e.kind == "npc" and not e.dead and not e.downed and e.faction in ["civ", "police"] and not e.hostile_to_player
		) as SimEntity
		if witness == null:
			continue
		if world != null and not world.segment_clear(witness.pos, body.pos):
			continue
		body.tags["body_discovered"] = true
		if meta != null:
			meta.stats["bodiesFound"] = int(meta.stats.get("bodiesFound", 0)) + 1
		_add_investigation(body, witness)
		witnessed_act(body.pos, "body", 1.0)
		if witness.faction == "civ":
			witness.ai_state = "flee"
			witness.perception_state = "afraid"
			witness.tags["witness_alarm_tick"] = tick + 390
			witness.tags["witness_body_id"] = body.id
			witness.tags["witness_alarm_pos"] = body.pos
		else:
			witness.ai_state = "investigate"
			witness.perception_state = "searching"
			witness.last_seen_pos = body.pos
			witness.search_ticks = max(witness.search_ticks, 360)
		emit_cue("body.discovered", { "body_id": body.id, "witness_id": witness.id, "pos": body.pos, "heat": heat })

func _update_investigations(_delta: float) -> void:
	_update_witness_alarms()
	_update_carried_body_witnesses()
	for i in range(investigations.size() - 1, -1, -1):
		var inv: Dictionary = investigations[i]
		var ttl := int(inv.get("ttl_ticks", 1320))
		inv["ticks"] = int(inv.get("ticks", 0)) + 1
		if int(inv["ticks"]) >= ttl or tick - int(inv.get("born_tick", tick)) > ttl * 3:
			emit_cue("investigation.ended", { "body_id": int(inv.get("body_id", 0)), "pos": inv.get("pos", Vector2.ZERO) })
			investigations.remove_at(i)
			continue
		var pos: Vector2 = inv.get("pos", Vector2.ZERO)
		var radius := float(inv.get("radius", 150.0))
		var player_visible := player != null and not bool(player.tags.get("cloaked", false)) and player.pos.distance_to(pos) < radius and player.exposure > 0.30
		if player_visible:
			if not bool(inv.get("hot", false)):
				inv["hot"] = true
				emit_cue("investigation.hot", { "body_id": int(inv.get("body_id", 0)), "pos": pos, "player_pos": player.pos })
			inv["ticks"] = min(int(inv["ticks"]), max(0, ttl - 240))
			last_seen_pos = player.pos
			last_provoke_tick = tick
			for e in entities:
				if e == null or e.dead:
					continue
				if not (e.faction == "police" or e.responder):
					continue
				if e.pos.distance_to(pos) > radius + 240.0:
					continue
				e.hostile_to_player = true
				e.ai_state = "chase"
				e.perception_state = "combat"
				e.last_seen_pos = player.pos
				e.search_ticks = max(e.search_ticks, 360)
		investigations[i] = inv

func _add_investigation(body: SimEntity, witness: SimEntity) -> void:
	var rec := {
		"body_id": body.id,
		"pos": body.pos,
		"radius": 150.0,
		"ticks": 0,
		"ttl_ticks": 1320,
		"born_tick": tick,
		"hot": false,
		"witness_id": witness.id if witness != null else 0,
	}
	investigations.append(rec)
	emit_cue("investigation.started", { "body_id": body.id, "witness_id": rec["witness_id"], "pos": body.pos, "radius": rec["radius"] })

func _update_witness_alarms() -> void:
	for e in entities:
		if e == null or e.kind != "npc" or not e.tags.has("witness_alarm_tick"):
			continue
		if e.dead or e.downed or e.has_status("mesmerized") or e.has_status("stun"):
			_clear_witness_alarm(e)
			emit_cue("witness.silenced", { "witness_id": e.id, "pos": e.pos })
			continue
		var alarm_tick := int(e.tags.get("witness_alarm_tick", 0))
		if tick < alarm_tick:
			continue
		var alarm_pos := e.pos
		if e.tags.get("witness_alarm_pos", null) is Vector2:
			alarm_pos = e.tags["witness_alarm_pos"]
		var domain_mult: float = meta.heat_mult_at(alarm_pos) if meta != null else 1.0
		last_seen_pos = alarm_pos
		last_crime_tick = tick
		last_provoke_tick = tick
		add_heat(1.0 * domain_mult, "witness_alarm")
		emit_cue("witness.alarm", { "witness_id": e.id, "body_id": int(e.tags.get("witness_body_id", 0)), "pos": alarm_pos, "heat": heat })
		_clear_witness_alarm(e)

func _update_carried_body_witnesses() -> void:
	if player == null or player.behaviour == null or bool(player.tags.get("cloaked", false)):
		return
	var carrying_id := int(player.behaviour.get("carrying_body_id"))
	if carrying_id == 0 or tick - last_body_carried_seen_tick < 30:
		return
	var carried_body := get_entity(carrying_id)
	if carried_body == null:
		return
	for e in entities:
		if e == null or e == player or e.dead or e.downed:
			continue
		if not (e.faction == "civ" or e.faction == "police"):
			continue
		if e.tags.has("witness_alarm_tick") or e.pos.distance_to(player.pos) >= 170.0:
			continue
		if world != null and not world.segment_clear(e.pos, player.pos):
			continue
		last_body_carried_seen_tick = tick
		last_seen_pos = player.pos
		last_crime_tick = tick
		last_provoke_tick = tick
		var domain_mult: float = meta.heat_mult_at(player.pos) if meta != null else 1.0
		add_heat(0.30 * domain_mult, "body_carried")
		if e.faction == "civ":
			e.ai_state = "flee"
			e.perception_state = "afraid"
			e.tags["witness_alarm_tick"] = tick + 390
			e.tags["witness_body_id"] = carrying_id
			e.tags["witness_alarm_pos"] = player.pos
		else:
			e.hostile_to_player = true
			e.ai_state = "chase"
			e.perception_state = "combat"
			e.last_seen_pos = player.pos
			e.search_ticks = max(e.search_ticks, 300)
		emit_cue("body.carried_seen", { "body_id": carrying_id, "witness_id": e.id, "pos": player.pos, "heat": heat })
		return

func _clear_witness_alarm(entity: SimEntity) -> void:
	entity.tags.erase("witness_alarm_tick")
	entity.tags.erase("witness_body_id")
	entity.tags.erase("witness_alarm_pos")

func _clean_investigations(source) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (source is Array):
		return out
	for item in source:
		if not (item is Dictionary):
			continue
		var rec: Dictionary = item
		var pos := Vector2.ZERO
		if rec.get("pos", null) is Vector2:
			pos = rec["pos"]
		out.append({
			"body_id": max(0, int(rec.get("body_id", 0))),
			"pos": pos,
			"radius": maxf(1.0, float(rec.get("radius", 150.0))),
			"ticks": max(0, int(rec.get("ticks", 0))),
			"ttl_ticks": max(1, int(rec.get("ttl_ticks", 1320))),
			"born_tick": max(0, int(rec.get("born_tick", tick))),
			"hot": bool(rec.get("hot", false)),
			"witness_id": max(0, int(rec.get("witness_id", 0))),
		})
	return out

func _hash_variant(value) -> int:
	if value is Dictionary:
		var keys := (value as Dictionary).keys()
		keys.sort()
		var h := 0
		for key in keys:
			h = hash([h, key, _hash_variant((value as Dictionary)[key])])
		return h
	if value is Array:
		var h := 0
		for item in value:
			h = hash([h, _hash_variant(item)])
		return h
	if value is Vector2:
		var v: Vector2 = value
		return hash([snapped(v.x, 0.001), snapped(v.y, 0.001)])
	return hash(value)

func _cleanup_dead_transients() -> void:
	for i in range(entities.size() - 1, -1, -1):
		var e := entities[i]
		if e != null and e.dead and e.kind in ["projectile"]:
			entities.remove_at(i)
