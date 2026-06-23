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

# --- Gulp timing mini-game (deterministic, tick-based) ---
const GULP_PERIOD := 42        # ticks between gulp windows (~0.7s @ 60Hz)
const GULP_WINDOW := 15        # window-open duration (~0.25s) — the "tap now" beat
const GULP_HIT_BONUS := 0.12   # fraction of victim blood_yield healed per perfect gulp
const GULP_MISS_SLOW := 0.6    # drain-speed factor while penalised after a miss (longer exposure)
const GULP_SLOW_TICKS := 30

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
var gulp_window_active: bool = false
var gulp_window_ticks: int = 0
var gulp_period_ticks: int = 0
var gulp_hits: int = 0
var gulp_misses: int = 0
var gulp_bonus_vitae: float = 0.0
var gulp_slow_ticks: int = 0
var iframes_remaining: int = 0
var vehicle_id: int = 0
var carrying_body_id: int = 0

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
			# While feeding, the attack input is the GULP tap (hit the open window for bonus vitae).
			if feeding_target_id != 0:
				_gulp_tap(sim)
			else:
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
	_tick_buffs(delta, sim)
	_tick_blood(delta, sim)
	if iframes_remaining > 0:
		iframes_remaining -= 1
	if vehicle_id != 0:
		var vehicle: SimEntity = sim.get_entity(vehicle_id)
		if vehicle == null or vehicle.dead:
			vehicle_id = 0
		else:
			entity.pos = vehicle.pos
			entity.facing = vehicle.facing
			entity.exposure = 1.15
			return
	if carrying_body_id != 0:
		_sync_carried_body(sim)
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
		if carrying_body_id != 0:
			speed *= 0.60
		if sprinting and carrying_body_id == 0 and blood > 1.0:
			speed *= 1.7
			blood = max(0.0, blood - 6.0 * delta)
			sim.emit_cue("move.sprint", { "entity_id": entity.id, "pos": entity.pos, "magnitude": 0.35 })
		var next_pos := entity.pos + move_dir * speed * delta
		entity.pos = sim.world.resolve_motion(entity.pos, next_pos, entity.radius)
	_tick_drink(sim)
	entity.exposure = _compute_exposure(sim)
	entity.tags["cloaked"] = buffs.has("obf_cloak") or buffs.has("obf_vanish")
	entity.tags["frenzied"] = frenzied


## DRINK (Blood Grammar): reclaim vitae from a pool you're standing in — closes the Open Vein loop.
## Reclaim is lossy (≈half), so spilling to cast still has a net cost; fresh feeding remains primary.
func _tick_drink(sim) -> void:
	if feeding_target_id != 0 or sim.world == null or blood >= max_blood:
		return
	if sim.world.blood_at(entity.pos) < 6:
		return
	var taken: int = sim.world.siphon_blood(entity.pos, 3)
	if taken > 0:
		heal_blood(float(taken) * 0.5)
		if sim.tick % 12 == 0:
			sim.emit_cue("blood.drink", { "pos": entity.pos, "amount": taken })

func cast_power(power_id: String, sim) -> bool:
	var def: Dictionary = PowerCatalogScript.get_def(power_id)
	if def.is_empty():
		return false
	power_id = String(def.get("id", power_id))
	if carrying_body_id != 0 and power_id in ["cel_dash", "pot_charge", "pro_mist"]:
		sim.emit_cue("power.failed.carrying", { "power_id": power_id, "body_id": carrying_body_id })
		return false
	if sim.meta != null and not sim.meta.knows_power(power_id):
		sim.emit_cue("power.failed.unknown", { "power_id": power_id })
		return false
	if String(def.get("type", "active")) == "toggle" and buffs.has(power_id):
		buffs.erase(power_id)
		sim.emit_cue("power.toggle", { "power_id": power_id, "enabled": false, "pos": entity.pos })
		return true
	if int(power_cooldowns.get(power_id, 0)) > 0:
		sim.emit_cue("power.cooldown", { "power_id": power_id, "remaining": int(power_cooldowns[power_id]) })
		return false
	var cost: float = sim.meta.effective_power_cost(power_id) if sim.meta != null else float(def.get("cost", 0.0))
	if blood < cost:
		sim.emit_cue("power.failed.no_blood", { "power_id": power_id, "blood": blood })
		return false
	blood -= cost
	power_cooldowns[power_id] = sim.meta.effective_power_cooldown(power_id) if sim.meta != null else int(def.get("cooldown", 60))
	var ok := true
	match power_id:
		"cel_dash":
			_try_dash(Vector2.RIGHT.rotated(entity.facing), sim, float(def.get("range", 150.0)), int(def.get("iframes", 18)))
		"cel_haste":
			_apply_buff(power_id, int(def.get("duration", -1)), { "move": 1.40, "upkeep": float(def.get("upkeep", 0.0)), "toggle": true })
		"cel_flurry":
			_apply_buff(power_id, int(def.get("duration", 210)), { "attackSpeed": 1.40, "damage": 0.25 })
		"cel_bullet":
			_apply_buff(power_id, int(def.get("duration", 240)), { "slowmo": 0.32, "attackSpeed": 0.30 })
			sim.time_scale = 0.32
		"pot_slam":
			var slam_r := float(def.get("radius", 100.0))
			_damage_radius(sim, slam_r, _spell_damage(def), int(def.get("stun", 0)), "power.potence.hit")
			if sim.world != null:
				sim.world.ignite_radius(entity.pos, slam_r)   # REACT: spark the spilled blood alight
		"pot_charge":
			_try_dash(Vector2.RIGHT.rotated(entity.facing), sim, float(def.get("range", 135.0)), 10)
			_damage_radius(sim, float(def.get("radius", 34.0)), _spell_damage(def), int(def.get("stun", 0)), "power.potence.charge_hit")
		"pot_quake":
			var quake_r := float(def.get("radius", 185.0))
			_damage_radius(sim, quake_r, _spell_damage(def), int(def.get("stun", 0)), "power.potence.quake_hit")
			if sim.world != null:
				sim.world.ignite_radius(entity.pos, quake_r)   # REACT: spark the spilled blood alight
		"for_mend":
			var heal := float(def.get("heal", 30.0))
			if sim.meta != null:
				heal *= 1.0 + float(sim.meta.derived.get("spellPower", 1.0)) * 0.35
			entity.hp = min(entity.max_hp, entity.hp + heal)
			sim.emit_cue("player.heal", { "amount": heal, "pos": entity.pos })
		"for_stone":
			_apply_buff("for_stone", int(def.get("duration", 240)), { "armor": float(def.get("armor", 0.3)) })
		"for_unkill":
			_apply_buff("for_unkill", int(def.get("duration", 156)), { "invulnerable": true })
			iframes_remaining = max(iframes_remaining, int(def.get("duration", 156)))
		"obf_cloak":
			_apply_buff(power_id, int(def.get("duration", -1)), { "upkeep": float(def.get("upkeep", 0.0)), "toggle": true })
		"obf_vanish":
			_apply_buff("obf_vanish", int(def.get("duration", 180)), {})
			var drop: float = maxf(float(def.get("heat_reduction", 0.8)), sim.heat - 0.20)
			sim.reduce_heat(drop, "power")
			sim.break_responder_locks()
		"obf_mask":
			sim.reduce_heat(float(def.get("heat_reduction", 2.0)), "power")
			sim.clear_witness_panic()
		"aus_senses":
			_apply_buff(power_id, int(def.get("duration", -1)), { "upkeep": float(def.get("upkeep", 0.0)), "crit": 0.10, "detect": 140.0, "toggle": true })
		"aus_premon":
			_apply_buff(power_id, int(def.get("duration", 360)), { "dodge": float(def.get("dodge", 0.4)) })
		"aus_mark":
			var target: SimEntity = sim.nearest_entity(entity.pos, float(def.get("range", 360.0)), func(e: SimEntity) -> bool: return _is_hostile_or_feedable(e)) as SimEntity
			if target == null:
				ok = false
			else:
				target.tags["marked"] = int(def.get("duration", 360))
				target.tags["damage_bonus"] = float(def.get("damage_bonus", 0.35))
				sim.emit_cue("power.auspex.marked", { "target_id": target.id, "pos": target.pos })
		"dom_mesmer":
			var any := false
			for target in sim.entities_in_radius(entity.pos, float(def.get("radius", def.get("range", 150.0))), func(e): return e != entity and not e.dead):
				if abs(_angle_diff((target.pos - entity.pos).angle(), entity.facing)) <= float(def.get("arc", 1.35)):
					target.apply_status("mesmerized", int(def.get("stun", 180)))
					any = true
			ok = any
		"dom_command":
			var command_target := _aim_target(sim, float(def.get("range", 220.0)))
			if command_target == null:
				ok = false
			else:
				command_target.apply_status("fear", int(def.get("fear", 300)))
				sim.emit_cue("power.dominate.commanded", { "target_id": command_target.id, "pos": command_target.pos })
		"dom_forget":
			sim.reduce_heat(float(def.get("heat_reduction", 1.2)), "power")
			sim.clear_witness_panic()
		"dom_thrall":
			var thrall_target: SimEntity = sim.nearest_entity(entity.pos, float(def.get("range", 95.0)), func(e: SimEntity) -> bool: return e.kind == "npc" and e.faction != "player" and not e.dead and (e.hp < e.max_hp * 0.5 or e.has_status("mesmerized") or e.faction == "civ")) as SimEntity
			if thrall_target == null or sim.meta == null:
				ok = false
			else:
				thrall_target.faction = "player"
				thrall_target.hostile_to_player = false
				thrall_target.ai_state = "follow"
				var member: Dictionary = sim.meta.bind_coterie_member(thrall_target.victim_type if thrall_target.victim_type != "" else "thrall", sim)
				thrall_target.tags["coterie_id"] = member.get("id", 0)
		"pre_dread":
			for target in sim.entities_in_radius(entity.pos, float(def.get("radius", 165.0)), func(e): return e.kind == "npc" and e.faction != "player" and not e.dead):
				target.apply_status("fear", int(def.get("fear", 180)))
				target.hostile_to_player = false
			sim.witnessed_act(entity.pos, "panic", 0.25)
		"pre_majesty":
			_apply_buff(power_id, int(def.get("duration", 360)), { "majesty": true })
		"pre_entr":
			var charmed := false
			for target in sim.entities_in_radius(entity.pos, float(def.get("radius", 185.0)), func(e): return e.kind == "npc" and e.faction == "civ" and not e.dead):
				target.apply_status("mesmerized", int(def.get("stun", 480)))
				charmed = true
			ok = charmed
		"pro_claws":
			_apply_buff(power_id, int(def.get("duration", -1)), { "damage": float(def.get("damage_bonus", 0.5)), "lifesteal": float(def.get("lifesteal", 0.08)), "upkeep": float(def.get("upkeep", 0.0)), "toggle": true })
		"pro_mist":
			_apply_buff(power_id, int(def.get("duration", 180)), { "mist": true, "move": 1.30 })
			iframes_remaining = max(iframes_remaining, int(def.get("duration", 180)))
		"pro_beast":
			_apply_buff(power_id, int(def.get("duration", 600)), { "move": 1.35, "damage": 0.60, "maxHP": 0.30 })
			entity.hp = min(entity.max_hp, entity.hp + entity.max_hp * 0.30)
		"bs_bolt":
			_command_blood_bolts(sim, def)   # COMMAND: spilled blood -> free fan of extra bolts
			var bolt_target := _aim_target(sim, float(def.get("range", 340.0)))
			if bolt_target == null:
				_fire_projectile(sim, def, Vector2.RIGHT.rotated(entity.facing), "blood")
			else:
				sim.damage_entity(entity, bolt_target, _spell_damage(def), {
					"cue": "power.blood_sorcery.bolt",
					"status": "bleed",
					"status_ticks": int(def.get("bleed", 180)),
					"damage_type": "blood",
					"knockback": 0.0,
				})
		"bs_cauldron":
			var cauldron_target := _aim_target(sim, float(def.get("range", 320.0)))
			if cauldron_target == null:
				ok = false
			else:
				sim.damage_entity(entity, cauldron_target, _spell_damage(def), { "cue": "power.blood.cauldron", "status": "bleed", "status_ticks": int(def.get("duration", 300)), "aoe_radius": float(def.get("splash", 70.0)) })
				for spill in sim.entities_in_radius(cauldron_target.pos, float(def.get("splash", 70.0)), func(e): return e.kind == "npc" and e != cauldron_target and not e.dead):
					spill.apply_status("bleed", int(def.get("duration", 300)) / 2)
		"bs_ward":
			_apply_buff(power_id, int(def.get("duration", 720)), { "shield": float(def.get("shield", 60.0)) })
		"bs_theft":
			var theft_target := _aim_target(sim, float(def.get("range", 300.0)))
			if theft_target == null:
				ok = false
			else:
				var dealt: float = sim.damage_entity(entity, theft_target, _spell_damage(def), { "cue": "power.blood.theft" })
				heal_blood(dealt * float(def.get("steal", 0.6)))
		"bs_storm":
			var bolts := int(def.get("bolts", 14))
			for i in range(bolts):
				_fire_projectile(sim, def, Vector2.RIGHT.rotated(float(i) / float(bolts) * TAU), "blood")
		"shd_tendril":
			var tendril_target := _aim_target(sim, float(def.get("range", 280.0)))
			var center := tendril_target.pos if tendril_target != null else entity.pos + Vector2.RIGHT.rotated(entity.facing) * 120.0
			for target in sim.entities_in_radius(center, float(def.get("radius", 95.0)), func(e): return e.kind == "npc" and e.faction != "player" and not e.dead):
				target.apply_status("root", int(def.get("duration", 180)))
				sim.damage_entity(entity, target, _spell_damage(def), { "cue": "power.dark.tendril" })
		"shd_arms":
			var arms_target := _aim_target(sim, float(def.get("range", 340.0)))
			if arms_target == null:
				ok = false
			else:
				sim.damage_entity(entity, arms_target, _spell_damage(def), { "cue": "power.dark.arms", "status": "root", "status_ticks": 60 })
				arms_target.pos = sim.world.resolve_motion(arms_target.pos, arms_target.pos.move_toward(entity.pos, float(def.get("pull", 130.0))), arms_target.radius)
		"dem_confuse":
			var any_confused := false
			for target in sim.entities_in_radius(entity.pos, float(def.get("radius", 190.0)), func(e): return e.kind == "npc" and e.faction != "player" and not e.dead):
				target.apply_status("confuse", int(def.get("duration", 360)))
				target.tags["confused"] = int(def.get("duration", 360))
				any_confused = true
			ok = any_confused
		"vic_horrid":
			_apply_buff(power_id, int(def.get("duration", 720)), { "damage": 0.50, "armor": 0.30, "maxHP": 0.60, "move": 0.85 })
		_:
			ok = false
	if ok:
		sim.emit_cue("power.cast", { "power_id": power_id, "name": def.get("name", power_id), "pos": entity.pos, "cue": def.get("cue", "") })
		# Open Vein: paying vitae for power opens a small wound that spills at your feet.
		if sim.world != null and cost > 0.0:
			sim.world.spill_blood(entity.pos, clampi(int(cost * 0.5), 2, 14))
		if String(def.get("type", "active")) == "toggle":
			sim.emit_cue("power.toggle", { "power_id": power_id, "enabled": true, "pos": entity.pos })
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

func try_toggle_carry(sim) -> bool:
	if vehicle_id != 0 or feeding_target_id != 0:
		return false
	if carrying_body_id != 0:
		return _drop_body(sim)
	var target: SimEntity = sim.nearest_entity(entity.pos, 64.0, func(e: SimEntity) -> bool:
		return e.kind == "npc" and e.faction != "player" and not bool(e.tags.get("carried", false)) and (e.dead or e.downed or e.ai_state == "downed")
	) as SimEntity
	if target == null:
		return false
	carrying_body_id = target.id
	target.tags["carried"] = true
	target.tags["body_carrier_id"] = entity.id
	target.tags["player_body"] = true
	target.tags["body_discovered"] = false
	target.vel = Vector2.ZERO
	target.current_action = null
	target.action_frame = 0
	target.downed = true
	target.ai_state = "carried"
	target.perception_state = "hidden"
	if sim.meta != null:
		sim.meta.stats["bodiesCarried"] = int(sim.meta.stats.get("bodiesCarried", 0)) + 1
	_sync_carried_body(sim)
	sim.emit_cue("body.pickup", { "body_id": target.id, "pos": target.pos })
	return true

func state_hash() -> int:
	var h := hash([
		snapped(move_dir.x, 0.001), snapped(move_dir.y, 0.001),
		snapped(aim_point.x, 0.001), snapped(aim_point.y, 0.001),
		snapped(blood, 0.001), snapped(max_blood, 0.001),
		snapped(hunger, 0.001), snapped(humanity, 0.001),
		snapped(frenzy, 0.001), frenzied, feeding_target_id, snapped(feed_drained, 0.001),
		snapped(feed_progress, 0.001), feed_lethal, iframes_remaining,
		gulp_window_active, gulp_window_ticks, gulp_period_ticks,
		gulp_hits, gulp_misses, snapped(gulp_bonus_vitae, 0.001), gulp_slow_ticks,
		vehicle_id, carrying_body_id,
		frenzy_cooldown, sprinting, sneaking, aiming, holding_feed,
		fed_count, kills, innocent_kills, snapped(damage_dealt, 0.001),
		snapped(damage_taken, 0.001)
	])
	h = _hash_dict(h, power_cooldowns)
	h = _hash_dict(h, buffs)
	return h

func _sync_carried_body(sim) -> void:
	var body: SimEntity = sim.get_entity(carrying_body_id) as SimEntity
	if body == null or bool(body.tags.get("body_discovered", false)) or (not body.dead and not body.downed and body.ai_state != "carried"):
		carrying_body_id = 0
		return
	body.tags["carried"] = true
	body.tags["body_carrier_id"] = entity.id
	body.vel = Vector2.ZERO
	body.ai_state = "carried"
	body.perception_state = "hidden"
	body.pos = entity.pos - Vector2.RIGHT.rotated(entity.facing) * (entity.radius + body.radius + 6.0)
	body.facing = entity.facing

func _drop_body(sim) -> bool:
	var body: SimEntity = sim.get_entity(carrying_body_id) as SimEntity
	if body == null:
		carrying_body_id = 0
		return false
	body.tags.erase("carried")
	body.tags.erase("body_carrier_id")
	body.vel = Vector2.ZERO
	body.pos = sim.world.resolve_motion(body.pos, entity.pos - Vector2.RIGHT.rotated(entity.facing) * (entity.radius + body.radius + 8.0), body.radius)
	body.ai_state = "downed" if body.downed and not body.dead else "corpse"
	body.perception_state = "helpless" if body.downed and not body.dead else "silent"
	body.tags["hidden_body"] = sim.world != null and sim.world.surface_at(body.pos) == SimWorld.Surface.SHADOW
	var dumped: bool = sim.world != null and (sim.world.is_in_haven(entity.pos) or sim.world.is_in_exit(entity.pos))
	if dumped:
		body.tags["dumped"] = true
		if sim.meta != null:
			sim.meta.stats["bodiesDumped"] = int(sim.meta.stats.get("bodiesDumped", 0)) + 1
		sim.emit_cue("body.dumped", { "body_id": body.id, "pos": body.pos })
	else:
		sim.emit_cue("body.drop", { "body_id": body.id, "pos": body.pos })
	carrying_body_id = 0
	return true

func _try_attack(sim) -> void:
	if feeding_target_id != 0 or carrying_body_id != 0:
		return
	if vehicle_id != 0:
		_shoot_from_vehicle(sim)
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
	if carrying_body_id != 0:
		return false
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
	if carrying_body_id != 0 or int(power_cooldowns.get("pounce", 0)) > 0 or blood < 10.0:
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
	if carrying_body_id != 0:
		return false
	var target: SimEntity = sim.nearest_entity(entity.pos, 96.0, func(e: SimEntity) -> bool: return e.kind == "npc" and e.faction != "player" and not e.dead and (e.downed or e.hp <= e.max_hp * 0.36 or e.has_status("mesmerized") or e.has_status("stun"))) as SimEntity
	if target == null:
		return false
	target.hp = 0.0
	target.dead = true
	if target.innocent or target.downed or bool(target.tags.get("fed_on", false)):
		target.tags["player_body"] = true
		target.tags["body_discovered"] = false
	kills += 1
	if target.innocent:
		innocent_kills += 1
		humanity = max(0.0, humanity - 0.5)
		sim.emit_cue("humanity.lost", { "humanity": humanity, "target_id": target.id })
	heal_blood(18.0)
	sim.witnessed_act(target.pos, "kill", 1.5)
	if sim.meta != null and target.tags.has("nemesis_name"):
		sim.meta.on_nemesis_dead(target, sim)
	if sim.meta != null and target.tags.has("baron_of"):
		sim.meta.claim_domain(String(target.tags["baron_of"]), sim)
	if sim.meta != null:
		sim.meta.gain_mastery("brawn", 5.0, sim)
		sim.meta.award_trophy_for(target, sim)
		sim.meta.codex_mark("killedKinds", target.faction if target.faction != "" else target.type_id, sim)
	sim.emit_cue("npc.death", { "entity_id": target.id, "type": target.type_id, "pos": target.pos, "finisher": true })
	sim.emit_cue("finisher.start", { "target_id": target.id, "pos": target.pos })
	return true

func _try_feed(sim) -> bool:
	if carrying_body_id != 0:
		return false
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
	_reset_gulp(GULP_PERIOD)
	target.ai_state = "downed" if target.downed else "fed"
	target.perception_state = "helpless"
	sim.emit_cue("feed.start", { "target_id": target.id, "pos": target.pos, "lethal": lethal })

func _tick_feeding(delta: float, sim) -> void:
	var target: SimEntity = sim.get_entity(feeding_target_id) as SimEntity
	if target == null or target.dead or entity.pos.distance_to(target.pos) > 58.0:
		_interrupt_feed(sim)
		return
	entity.facing = (target.pos - entity.pos).angle()
	_tick_gulp(sim, target)
	var speed := 1.0 + hunger * 0.10
	if gulp_slow_ticks > 0:
		speed *= GULP_MISS_SLOW   # a missed gulp slows the feed → longer exposure
		gulp_slow_ticks -= 1
	feed_progress += delta * speed
	var gain: float = target.blood_yield * 0.55 * delta * speed
	feed_drained += gain
	target.blood_left -= gain
	heal_blood(gain)
	# Heartbeat / drain pulse cue (audio + vignette), distinct from the gulp window beat.
	if feed_progress >= 0.2 and int(feed_progress * 10.0) % 7 == 0:
		sim.emit_cue("feed.drain", { "target_id": target.id, "pos": target.pos, "magnitude": gain, "hunger": hunger })
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
		target.downed = false
		target.tags["player_body"] = true
		target.tags["body_discovered"] = false
		target.tags["fed_on"] = true
		kills += 1
		if target.innocent:
			innocent_kills += 1
			humanity = max(0.0, humanity - 0.4)
			sim.emit_cue("humanity.lost", { "humanity": humanity, "target_id": target.id, "pos": target.pos })
			_react_to_humanity_drop(sim, target.pos)
		sim.witnessed_act(target.pos, "kill", 1.5)
		sim.emit_cue("feed.kill", { "target_id": target.id, "pos": target.pos, "blood": feed_drained })
	else:
		target.downed = true
		target.ai_state = "downed"
		target.perception_state = "helpless"
		target.tags["player_body"] = true
		target.tags["body_discovered"] = false
		target.tags["fed_on"] = true
		humanity = min(10.0, humanity + 0.03)
		sim.witnessed_act(target.pos, "feed", 1.0)
		sim.emit_cue("feed.spare", { "target_id": target.id, "pos": target.pos, "blood": feed_drained, "gulp_bonus": gulp_bonus_vitae, "gulp_hits": gulp_hits })
	if sim.meta != null:
		var fxp: int = 14 if lethal else 8
		sim.meta.gain_xp(fxp, sim)
		sim.emit_cue("player.xp", { "amount": fxp, "pos": entity.pos, "reason": "feed" })
	if target.resonance != "":
		_apply_resonance(sim, target.resonance, target.blood_yield)
	feed_drained = 0.0
	_reset_gulp(0)


## Resonance (Blood Grammar): the victim's humour grants a matching 30s buff — so WHO you feed on,
## not just whether, is a build decision. Buffs are read in combat (choleric melee, phlegmatic armor,
## melancholic spell) and economy (sanguine vitae).
func _apply_resonance(sim, humour: String, yield_amount: float) -> void:
	const DUR := 1800
	match humour:
		"sanguine":
			heal_blood(yield_amount * 0.30)
			buffs["res_sanguine"] = { "ticks": DUR }
		"choleric":
			buffs["res_choleric"] = { "ticks": DUR, "melee": 0.25 }
		"melancholic":
			buffs["res_melancholic"] = { "ticks": DUR, "spell": 0.25 }
		"phlegmatic":
			buffs["res_phlegmatic"] = { "ticks": DUR, "armor": 0.20 }
	sim.emit_cue("feed.resonance", { "humour": humour, "pos": entity.pos })

## The city feels the monster within a second of a lethal sin: nearby mortals recoil and flee.
## Deterministic — iterates entities by distance, no RNG.
func _react_to_humanity_drop(sim, pos: Vector2) -> void:
	for e in sim.entities:
		if e == null or e.dead or e == entity:
			continue
		if e.kind != "npc" or e.faction != "civ" or e.downed:
			continue
		if e.pos.distance_to(pos) > 200.0:
			continue
		e.ai_state = "flee"
		e.perception_state = "alert"
		e.tags["scared_ticks"] = 120
		sim.emit_cue("npc.flinch", { "entity_id": e.id, "pos": e.pos })


func _interrupt_feed(sim) -> void:
	var target: SimEntity = sim.get_entity(feeding_target_id) as SimEntity
	if target != null and not target.dead and not target.downed:
		target.ai_state = "flee" if target.faction == "civ" else "wander"
	feeding_target_id = 0
	feed_progress = 0.0
	feed_drained = 0.0
	holding_feed = false
	_reset_gulp(0)
	sim.emit_cue("feed.interrupt", { "pos": entity.pos })


# --- Gulp timing mini-game: deterministic windows; a well-timed ATTACK during a window grants bonus
# vitae + slowmo; a miss (or tap outside the window) slows the feed (longer exposure). The tap arrives
# through the normal InputAction stream, so replay stays deterministic. ---

func _reset_gulp(period: int) -> void:
	gulp_window_active = false
	gulp_window_ticks = 0
	gulp_period_ticks = period
	gulp_hits = 0
	gulp_misses = 0
	gulp_bonus_vitae = 0.0
	gulp_slow_ticks = 0


func _tick_gulp(sim, target: SimEntity) -> void:
	if gulp_window_active:
		gulp_window_ticks -= 1
		if gulp_window_ticks <= 0:
			# Window closed with no tap — a miss.
			gulp_window_active = false
			gulp_misses += 1
			gulp_slow_ticks = GULP_SLOW_TICKS
			gulp_period_ticks = GULP_PERIOD
			sim.emit_cue("feed.gulp.miss", { "target_id": target.id, "pos": target.pos, "reason": "timeout" })
	else:
		gulp_period_ticks -= 1
		if gulp_period_ticks <= 0:
			gulp_window_active = true
			gulp_window_ticks = GULP_WINDOW
			gulp_period_ticks = GULP_PERIOD
			sim.emit_cue("feed.gulp", { "target_id": target.id, "pos": target.pos, "window": true, "ticks": GULP_WINDOW })


func _gulp_tap(sim) -> void:
	if feeding_target_id == 0:
		return
	var target: SimEntity = sim.get_entity(feeding_target_id) as SimEntity
	if target == null:
		return
	if gulp_window_active:
		gulp_window_active = false
		gulp_hits += 1
		gulp_period_ticks = GULP_PERIOD
		var bonus: float = target.blood_yield * GULP_HIT_BONUS
		gulp_bonus_vitae += bonus
		heal_blood(bonus)
		sim.emit_cue("feed.gulp.perfect", { "target_id": target.id, "pos": target.pos, "bonus": bonus, "hits": gulp_hits })
	else:
		# Tapped outside the window — mistimed; light penalty.
		gulp_misses += 1
		gulp_slow_ticks = GULP_SLOW_TICKS
		sim.emit_cue("feed.gulp.miss", { "target_id": target.id, "pos": target.pos, "reason": "early" })

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

func _tick_buffs(delta: float, sim) -> void:
	var expired: Array = []
	for key in buffs:
		if float(buffs[key].get("upkeep", 0.0)) > 0.0:
			blood -= float(buffs[key].get("upkeep", 0.0)) * delta
			if blood <= 0.0:
				blood = 0.0
				expired.append(key)
				continue
		if int(buffs[key].get("ticks", 0)) > 0:
			buffs[key]["ticks"] = int(buffs[key].get("ticks", 0)) - 1
		if int(buffs[key].get("ticks", 0)) == 0:
			expired.append(key)
	for key in expired:
		buffs.erase(key)
		sim.emit_cue("power.toggle", { "power_id": key, "enabled": false, "pos": entity.pos })
	if not buffs.has("cel_bullet") and sim.time_scale != 1.0:
		sim.time_scale = 1.0

func _apply_buff(buff_id: String, ticks: int, data: Dictionary) -> void:
	var rec := data.duplicate(true)
	rec["ticks"] = ticks
	buffs[buff_id] = rec

func _damage_radius(sim, radius: float, amount: float, stun_ticks: int, cue: String, knockback: float = 360.0) -> void:
	for target in sim.entities_in_radius(entity.pos, radius, func(e): return e.kind == "npc" and e.faction != "player" and not e.dead):
		sim.damage_entity(entity, target, amount, { "cue": cue, "status": "stun", "status_ticks": stun_ticks, "knockback": knockback, "hitstop": 3 })

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
	# Humanity as lived state: the further you fall, the more the Beast shows — you read as a
	# predator and become more conspicuous. Only bites below 5 so a fresh (humanity 7) hunt is calm.
	if humanity < 5.0:
		exposure += (5.0 - humanity) * 0.06   # up to +0.30 at Humanity 0
	return clamp(exposure, 0.08, 1.45)

func _spell_damage(def: Dictionary) -> float:
	var amount := float(def.get("damage", def.get("dmg", 0.0)))
	if buffs.has("res_melancholic"):
		amount *= 1.0 + float(buffs["res_melancholic"].get("spell", 0.25))
	return amount

## COMMAND atom (hemokinesis): if you're near spilled blood, Blood Bolt commands it into a fan of
## extra free bolts (the medium is already paid for). Rewards fighting in your own carnage.
func _command_blood_bolts(sim, def: Dictionary) -> int:
	if sim.world == null:
		return 0
	var probe := entity.pos + Vector2.RIGHT.rotated(entity.facing) * 56.0
	var pool: int = sim.world.blood_at(probe)
	if pool < 20:
		probe = entity.pos
		pool = sim.world.blood_at(probe)
	if pool < 20:
		return 0
	var bolts: int = clampi(pool / 40, 1, 4)
	sim.world.siphon_blood(probe, bolts * 40)
	for i in range(bolts):
		var spread: float = (float(i) - float(bolts - 1) * 0.5) * 0.22
		_fire_projectile(sim, def, Vector2.RIGHT.rotated(entity.facing + spread), "blood")
	sim.emit_cue("blood.command", { "pos": entity.pos, "count": bolts })
	return bolts


func _fire_projectile(sim, def: Dictionary, dir: Vector2, kind: String) -> void:
	var shot_dir := dir.normalized()
	var speed := float(def.get("speed", 540.0))
	var start := entity.pos + shot_dir * (entity.radius + 8.0)
	sim.spawn_projectile(start, shot_dir * speed, {
		"owner_id": entity.id,
		"faction": "player",
		"kind": kind,
		"damage": _spell_damage(def),
		"radius": 6.0,
		"life_ticks": 96,
		"pierce": int(def.get("pierce", 0)),
		"status": "bleed" if def.has("bleed") else "",
		"status_ticks": int(def.get("bleed", 0)),
		"cue": "power.projectile.hit",
		"damage_type": kind,
	})

func _shoot_from_vehicle(sim) -> void:
	var vehicle: SimEntity = sim.get_entity(vehicle_id)
	if vehicle == null:
		vehicle_id = 0
		return
	var dir := Vector2.RIGHT.rotated(vehicle.facing)
	sim.spawn_projectile(vehicle.pos + dir * (vehicle.radius + 8.0), dir * 720.0, {
		"owner_id": entity.id,
		"faction": "player",
		"kind": "drive_by",
		"damage": 14.0,
		"radius": 4.0,
		"life_ticks": 70,
		"cue": "vehicle.drive_by.hit",
	})
	sim.emit_cue("vehicle.drive_by", { "vehicle_id": vehicle_id, "pos": vehicle.pos })
	sim.witnessed_act(vehicle.pos, "combat", 0.45)

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
