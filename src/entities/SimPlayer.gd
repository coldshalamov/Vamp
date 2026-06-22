## SimPlayer.gd -- authoritative player verbs and vampire economy.
##
## Input arrives as serializable InputActions. This delegate mutates only the owned
## SimEntity and Sim-owned systems; rendering, audio, HUD, and input remapping subscribe
## to CueBus/state from outside the sim.
extends RefCounted
class_name SimPlayer

const ACTION_LIGHT := preload("res://data/powers/melee_light.tres")
const ACTION_HEAVY := preload("res://data/powers/melee_heavy.tres")
const ACTION_DASH := preload("res://data/powers/dash.tres")
const PowerCatalogScript := preload("res://src/data/PowerCatalog.gd")

var entity: SimEntity

var move_dir: Vector2 = Vector2.ZERO
var move_speed: float = 220.0
var aim_point: Vector2 = Vector2.ZERO
var aiming: bool = false
var sprinting: bool = false
var sneaking: bool = false
var holding_feed: bool = false

var blood: float = 72.0
var max_blood: float = 100.0
var hunger: float = 1.0
var humanity: float = 7.0
var frenzy: float = 0.0
var frenzy_cooldown: int = 0
var frenzied: bool = false

var feeding_target_id: int = 0
var feed_progress: float = 0.0
var feed_drained: float = 0.0
var feed_lethal: bool = false
var iframes_remaining: int = 0

var power_cooldowns: Dictionary = {}
var buffs: Dictionary = {}
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var fed_count: int = 0
var kills: int = 0
var innocent_kills: int = 0

func _init(e: SimEntity) -> void:
	entity = e
	entity.faction = "player"
	entity.type_id = "player"
	entity.radius = 12.0
	entity.max_hp = 100.0
	entity.hp = 100.0
	entity.exposure = 0.65
	aim_point = entity.pos + Vector2.RIGHT

func apply_action(action: InputAction, sim) -> void:
	match action.kind:
		InputAction.Kind.MOVE:
			move_dir = action.vector.normalized() if action.vector.length() > 0.01 else Vector2.ZERO
			if move_dir != Vector2.ZERO and not aiming:
				entity.facing = move_dir.angle()
		InputAction.Kind.AIM:
			aim_point = action.vector
			aiming = action.held
			if aim_point.distance_squared_to(entity.pos) > 4.0:
				entity.facing = (aim_point - entity.pos).angle()
		InputAction.Kind.ATTACK:
			_try_attack(sim)
		InputAction.Kind.DASH:
			_try_dash(action.vector, sim, ACTION_DASH.range, 12)
		InputAction.Kind.FEED:
			holding_feed = action.held
			if holding_feed:
				_try_feed(sim)
			elif feeding_target_id != 0:
				_try_spare_feed(sim)
		InputAction.Kind.SPRINT:
			sprinting = action.held
		InputAction.Kind.SNEAK:
			sneaking = action.held
		InputAction.Kind.POUNCE:
			_try_pounce(action.vector, sim)
		InputAction.Kind.FINISH:
			_try_finish(sim)
		InputAction.Kind.POWER:
			cast_power(action.action_id, sim)
		InputAction.Kind.RELEASE:
			if action.action_id == "feed":
				holding_feed = false
				_try_spare_feed(sim)

func step(delta: float, sim) -> void:
	_tick_cooldowns()
	_tick_buffs()
	_tick_blood(delta, sim)
	if iframes_remaining > 0:
		iframes_remaining -= 1
	if feeding_target_id != 0:
		_tick_feeding(delta, sim)
	var phase := entity.action_phase()
	var can_move := (phase == "" or phase == "recovery") and feeding_target_id == 0
	if can_move and move_dir != Vector2.ZERO:
		var speed := move_speed
		if buffs.has("cel_haste"):
			speed *= 1.35
		if buffs.has("pro_beast"):
			speed *= 1.25
		if sneaking:
			speed *= 0.52
		if sprinting and blood > 1.0:
			speed *= 1.7
			blood = max(0.0, blood - 6.0 * delta)
			sim.emit_cue("move.sprint", { "entity_id": entity.id, "pos": entity.pos, "magnitude": 0.35 })
		var next_pos := entity.pos + move_dir * speed * delta
		entity.pos = sim.world.resolve_motion(entity.pos, next_pos, entity.radius)
	entity.exposure = _compute_exposure(sim)
	entity.tags["cloaked"] = buffs.has("obf_cloak") or buffs.has("obf_vanish")
	entity.tags["frenzied"] = frenzied

func cast_power(power_id: String, sim) -> bool:
	var def: Dictionary = PowerCatalogScript.get_def(power_id)
	if def.is_empty():
		return false
	if int(power_cooldowns.get(power_id, 0)) > 0:
		sim.emit_cue("power.cooldown", { "power_id": power_id, "remaining": int(power_cooldowns[power_id]) })
		return false
	var cost := float(def.get("cost", 0.0))
	if blood < cost:
		sim.emit_cue("power.failed.no_blood", { "power_id": power_id, "blood": blood })
		return false
	blood -= cost
	power_cooldowns[power_id] = int(def.get("cooldown", 60))
	var ok := true
	match power_id:
		"cel_dash":
			_try_dash(Vector2.RIGHT.rotated(entity.facing), sim, float(def.get("range", 150.0)), 18)
		"cel_haste":
			_apply_buff("cel_haste", int(def.get("duration", 240)), { "move": 1.35 })
		"pot_slam":
			_damage_radius(sim, float(def.get("radius", 100.0)), float(def.get("damage", 20.0)), int(def.get("stun", 0)), "power.potence.hit")
		"pot_charge":
			_try_dash(Vector2.RIGHT.rotated(entity.facing), sim, float(def.get("range", 135.0)), 10)
			_damage_radius(sim, float(def.get("radius", 34.0)), float(def.get("damage", 24.0)), int(def.get("stun", 0)), "power.potence.charge_hit")
		"for_mend":
			var heal := float(def.get("heal", 30.0))
			entity.hp = min(entity.max_hp, entity.hp + heal)
			sim.emit_cue("player.heal", { "amount": heal, "pos": entity.pos })
		"for_stone":
			_apply_buff("for_stone", int(def.get("duration", 240)), { "armor": float(def.get("armor", 0.3)) })
		"obf_cloak":
			_apply_buff("obf_cloak", int(def.get("duration", 300)), {})
		"obf_vanish":
			_apply_buff("obf_vanish", int(def.get("duration", 180)), {})
			sim.reduce_heat(float(def.get("heat_reduction", 0.8)), "power")
			sim.break_responder_locks()
		"aus_mark":
			var target: SimEntity = sim.nearest_entity(entity.pos, float(def.get("range", 360.0)), func(e: SimEntity) -> bool: return _is_hostile_or_feedable(e)) as SimEntity
			if target == null:
				ok = false
			else:
				target.tags["marked"] = int(def.get("duration", 360))
				target.tags["damage_bonus"] = float(def.get("damage_bonus", 0.35))
				sim.emit_cue("power.auspex.marked", { "target_id": target.id, "pos": target.pos })
		"dom_mesmerize":
			var any := false
			for target in sim.entities_in_radius(entity.pos, float(def.get("range", 150.0)), func(e): return e != entity and not e.dead):
				if abs(_angle_diff((target.pos - entity.pos).angle(), entity.facing)) <= float(def.get("arc", 1.35)):
					target.apply_status("mesmerized", int(def.get("stun", 180)))
					any = true
			ok = any
		"dom_forget":
			sim.reduce_heat(float(def.get("heat_reduction", 1.2)), "power")
			sim.clear_witness_panic()
		"pre_dread":
			for target in sim.entities_in_radius(entity.pos, float(def.get("radius", 165.0)), func(e): return e.kind == "npc" and e.faction != "player" and not e.dead):
				target.apply_status("fear", int(def.get("fear", 180)))
				target.hostile_to_player = false
			sim.witnessed_act(entity.pos, "panic", 0.25)
		"bs_bolt":
			var bolt_target := _aim_target(sim, float(def.get("range", 340.0)))
			if bolt_target == null:
				ok = false
			else:
				sim.damage_entity(entity, bolt_target, float(def.get("damage", 24.0)), { "cue": "power.blood_bolt.hit", "status": "bleed", "status_ticks": int(def.get("bleed", 120)) })
		_:
			ok = false
	if ok:
		sim.emit_cue("power.cast", { "power_id": power_id, "name": def.get("name", power_id), "pos": entity.pos, "cue": def.get("cue", "") })
	else:
		blood = min(max_blood, blood + cost)
		power_cooldowns.erase(power_id)
	return ok

func on_damage_dealt(amount: float) -> void:
	damage_dealt += amount

func on_damage_taken(amount: float) -> void:
	damage_taken += amount
	if frenzied:
		frenzy = min(1.0, frenzy + amount * 0.002)

func heal_blood(amount: float) -> void:
	blood = min(max_blood, blood + amount)
	hunger = max(0.0, hunger - amount / max_blood * 2.0)

func state_hash() -> int:
	var h := hash([
		snapped(move_dir.x, 0.001), snapped(move_dir.y, 0.001),
		snapped(aim_point.x, 0.001), snapped(aim_point.y, 0.001),
		snapped(blood, 0.001), snapped(max_blood, 0.001),
		snapped(hunger, 0.001), snapped(humanity, 0.001),
		snapped(frenzy, 0.001), frenzied, feeding_target_id, snapped(feed_drained, 0.001),
		snapped(feed_progress, 0.001), feed_lethal, iframes_remaining,
		frenzy_cooldown, sprinting, sneaking, aiming, holding_feed,
		fed_count, kills, innocent_kills, snapped(damage_dealt, 0.001),
		snapped(damage_taken, 0.001)
	])
	h = _hash_dict(h, power_cooldowns)
	h = _hash_dict(h, buffs)
	return h

func _try_attack(sim) -> void:
	if feeding_target_id != 0:
		return
	if buffs.has("obf_cloak"):
		buffs.erase("obf_cloak")
	var phase := entity.action_phase()
	match phase:
		"":
			if entity.begin_action(ACTION_LIGHT, sim):
				sim.emit_cue("attack.start", { "entity_id": entity.id, "action": "melee_light", "pos": entity.pos })
				sim.player_last_attack_tick = sim.tick
		"recovery":
			if entity.current_action != null:
				var cur_def: ActionDef = entity.current_action.def
				if cur_def.in_combo_window(entity.action_frame) and cur_def.combo_next != "":
					var next_def := _get_action_def(cur_def.combo_next)
					if next_def != null:
						entity.begin_action(next_def, sim)
						sim.emit_cue("attack.start", { "entity_id": entity.id, "action": next_def.id, "pos": entity.pos })
						sim.player_last_attack_tick = sim.tick

func _try_dash(dir: Vector2, sim, distance: float, iframe_ticks: int) -> bool:
	if not entity.can_cancel_into(ACTION_DASH) and entity.action_phase() != "":
		if entity.action_phase() != "recovery":
			return false
	if not entity.begin_action(ACTION_DASH, sim):
		return false
	var dash_dir := dir if dir.length() > 0.01 else Vector2.RIGHT.rotated(entity.facing)
	dash_dir = dash_dir.normalized()
	var next_pos := entity.pos + dash_dir * distance
	entity.pos = sim.world.resolve_motion(entity.pos, next_pos, entity.radius)
	entity.facing = dash_dir.angle()
	iframes_remaining = max(iframes_remaining, iframe_ticks)
	sim.emit_cue("move.dash", { "entity_id": entity.id, "pos": entity.pos, "magnitude": distance })
	return true

func _try_pounce(dir: Vector2, sim) -> bool:
	if int(power_cooldowns.get("pounce", 0)) > 0 or blood < 10.0:
		return false
	var pounce_dir := dir if dir.length() > 0.01 else Vector2.RIGHT.rotated(entity.facing)
	pounce_dir = pounce_dir.normalized()
	blood -= 10.0
	power_cooldowns["pounce"] = 90
	var from_pos := entity.pos
	entity.pos = sim.world.resolve_motion(entity.pos, entity.pos + pounce_dir * 125.0, entity.radius)
	entity.facing = pounce_dir.angle()
	iframes_remaining = max(iframes_remaining, 8)
	sim.emit_cue("pounce.start", { "from": from_pos, "pos": entity.pos, "magnitude": 1.0 })
	var target: SimEntity = sim.nearest_entity(entity.pos, 45.0, func(e: SimEntity) -> bool: return e.kind == "npc" and e.faction != "player" and not e.dead) as SimEntity
	if target != null:
		sim.damage_entity(entity, target, 24.0, { "cue": "pounce.hit", "status": "stun", "status_ticks": 24 })
		if target.innocent or target.downed:
			_start_feeding(target, sim, false)
	return true

func _try_finish(sim) -> bool:
	var target: SimEntity = sim.nearest_entity(entity.pos, 68.0, func(e: SimEntity) -> bool: return e.kind == "npc" and e.faction != "player" and not e.dead and (e.downed or e.hp <= e.max_hp * 0.36 or e.has_status("mesmerized") or e.has_status("stun"))) as SimEntity
	if target == null:
		return false
	target.hp = 0.0
	target.dead = true
	kills += 1
	if target.innocent:
		innocent_kills += 1
		humanity = max(0.0, humanity - 0.5)
		sim.emit_cue("humanity.lost", { "humanity": humanity, "target_id": target.id })
	heal_blood(18.0)
	sim.witnessed_act(target.pos, "kill", 1.5)
	sim.emit_cue("finisher.start", { "target_id": target.id, "pos": target.pos })
	return true

func _try_feed(sim) -> bool:
	if feeding_target_id != 0:
		return true
	var target: SimEntity = sim.nearest_entity(entity.pos, 52.0, func(e: SimEntity) -> bool: return _can_feed(e)) as SimEntity
	if target == null:
		return false
	_start_feeding(target, sim, false)
	return true

func _try_spare_feed(sim) -> void:
	if feeding_target_id == 0:
		return
	if feed_drained >= 8.0:
		_finish_feed(sim, false)
	else:
		_interrupt_feed(sim)

func _start_feeding(target: SimEntity, sim, lethal: bool) -> void:
	feeding_target_id = target.id
	feed_progress = 0.0
	feed_drained = 0.0
	feed_lethal = lethal
	target.ai_state = "downed" if target.downed else "fed"
	target.perception_state = "helpless"
	sim.emit_cue("feed.start", { "target_id": target.id, "pos": target.pos, "lethal": lethal })

func _tick_feeding(delta: float, sim) -> void:
	var target: SimEntity = sim.get_entity(feeding_target_id) as SimEntity
	if target == null or target.dead or entity.pos.distance_to(target.pos) > 58.0:
		_interrupt_feed(sim)
		return
	entity.facing = (target.pos - entity.pos).angle()
	var speed := 1.0 + hunger * 0.10
	feed_progress += delta * speed
	var gain: float = target.blood_yield * 0.55 * delta * speed
	feed_drained += gain
	target.blood_left -= gain
	heal_blood(gain)
	if feed_progress >= 0.45 and int(feed_progress * 10.0) % 7 == 0:
		sim.emit_cue("feed.gulp", { "target_id": target.id, "pos": target.pos, "magnitude": gain })
	if holding_feed and (feed_drained >= target.blood_yield * 1.2 or target.blood_left <= 0.0):
		_finish_feed(sim, true)
	elif not holding_feed and feed_drained >= target.blood_yield * 0.70:
		_finish_feed(sim, false)

func _finish_feed(sim, lethal: bool) -> void:
	var target: SimEntity = sim.get_entity(feeding_target_id) as SimEntity
	feeding_target_id = 0
	feed_progress = 0.0
	holding_feed = false
	if target == null:
		return
	fed_count += 1
	if lethal:
		target.dead = true
		kills += 1
		if target.innocent:
			innocent_kills += 1
			humanity = max(0.0, humanity - 0.4)
			sim.emit_cue("humanity.lost", { "humanity": humanity, "target_id": target.id })
		sim.witnessed_act(target.pos, "kill", 1.5)
		sim.emit_cue("feed.kill", { "target_id": target.id, "pos": target.pos, "blood": feed_drained })
	else:
		target.downed = true
		target.ai_state = "downed"
		target.perception_state = "helpless"
		humanity = min(10.0, humanity + 0.03)
		sim.witnessed_act(target.pos, "feed", 1.0)
		sim.emit_cue("feed.spare", { "target_id": target.id, "pos": target.pos, "blood": feed_drained })
	feed_drained = 0.0

func _interrupt_feed(sim) -> void:
	var target: SimEntity = sim.get_entity(feeding_target_id) as SimEntity
	if target != null and not target.dead and not target.downed:
		target.ai_state = "flee" if target.faction == "civ" else "wander"
	feeding_target_id = 0
	feed_progress = 0.0
	feed_drained = 0.0
	holding_feed = false
	sim.emit_cue("feed.interrupt", { "pos": entity.pos })

func _tick_blood(delta: float, sim) -> void:
	blood = max(0.0, blood - delta * 0.12)
	var ratio: float = blood / maxf(max_blood, 1.0)
	var target_hunger := 0.0
	if ratio > 0.8:
		target_hunger = 0.0
	elif ratio > 0.6:
		target_hunger = 1.0
	elif ratio > 0.4:
		target_hunger = 2.0
	elif ratio > 0.2:
		target_hunger = 3.0
	elif ratio > 0.05:
		target_hunger = 4.0
	else:
		target_hunger = 5.0
	hunger = move_toward(hunger, target_hunger, delta * 0.8)
	if frenzy_cooldown > 0:
		frenzy_cooldown -= 1
	if not frenzied and hunger >= 5.0 and frenzy_cooldown <= 0:
		if sim.draw_float() < delta * 0.15:
			frenzied = true
			frenzy = 1.0
			sim.emit_cue("frenzy.start", { "pos": entity.pos })
	if frenzied:
		frenzy -= delta * 0.06
		if frenzy <= 0.0:
			frenzied = false
			frenzy = 0.0
			frenzy_cooldown = 480
			sim.emit_cue("frenzy.end", { "pos": entity.pos })
	sim.emit_vitals_changed()

func _tick_cooldowns() -> void:
	var expired: Array = []
	for key in power_cooldowns:
		power_cooldowns[key] = int(power_cooldowns[key]) - 1
		if int(power_cooldowns[key]) <= 0:
			expired.append(key)
	for key in expired:
		power_cooldowns.erase(key)

func _tick_buffs() -> void:
	var expired: Array = []
	for key in buffs:
		buffs[key]["ticks"] = int(buffs[key].get("ticks", 0)) - 1
		if int(buffs[key].get("ticks", 0)) <= 0:
			expired.append(key)
	for key in expired:
		buffs.erase(key)

func _apply_buff(buff_id: String, ticks: int, data: Dictionary) -> void:
	var rec := data.duplicate(true)
	rec["ticks"] = ticks
	buffs[buff_id] = rec

func _damage_radius(sim, radius: float, amount: float, stun_ticks: int, cue: String) -> void:
	for target in sim.entities_in_radius(entity.pos, radius, func(e): return e.kind == "npc" and e.faction != "player" and not e.dead):
		sim.damage_entity(entity, target, amount, { "cue": cue, "status": "stun", "status_ticks": stun_ticks })

func _aim_target(sim, max_range: float) -> SimEntity:
	var best: SimEntity = null
	var best_score := 999999.0
	for target in sim.entities:
		if not _is_hostile_or_feedable(target):
			continue
		var to_target: Vector2 = target.pos - entity.pos
		var dist: float = to_target.length()
		if dist > max_range:
			continue
		var off: float = absf(_angle_diff(to_target.angle(), entity.facing))
		if off > 0.55:
			continue
		var score: float = dist + off * 180.0
		if score < best_score:
			best_score = score
			best = target
	return best

func _can_feed(e: SimEntity) -> bool:
	return e != entity and e.kind == "npc" and not e.dead and not e.responder and e.faction != "player"

func _is_hostile_or_feedable(e: SimEntity) -> bool:
	return e != entity and e.kind == "npc" and not e.dead and (e.hostile_to_player or e.faction != "civ" or e.downed)

func _get_action_def(id: String) -> ActionDef:
	match id:
		"melee_light":
			return ACTION_LIGHT
		"melee_heavy":
			return ACTION_HEAVY
		"dash":
			return ACTION_DASH
	return null

func _compute_exposure(sim) -> float:
	var exposure := 0.65
	if sprinting:
		exposure += 0.45
	if sneaking:
		exposure -= 0.35
	if frenzied:
		exposure += 0.35
	if buffs.has("obf_cloak") or buffs.has("obf_vanish"):
		exposure *= 0.25
	if sim.world != null and sim.world.surface_at(entity.pos) == SimWorld.Surface.SHADOW:
		exposure -= 0.18
	return clamp(exposure, 0.08, 1.35)

func _angle_diff(a: float, b: float) -> float:
	var d := fmod(a - b, TAU)
	if d > PI:
		d -= TAU
	elif d < -PI:
		d += TAU
	return d

func _hash_dict(seed_hash: int, dict: Dictionary) -> int:
	var h := seed_hash
	var keys := dict.keys()
	keys.sort()
	for key in keys:
		h = hash([h, key, dict[key]])
	return h
