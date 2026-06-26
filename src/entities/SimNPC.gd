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

## Combat roles (archetypes). Each layers a distinct behavior on the shared AI so different enemies
## force DIFFERENT verbs from the player's kit — the cure for "every enemy plays the same".
## "bulwark": frontal block (reuse front_armor) → forces flank / charge / bleed-detonate.
## "choir": backline healer that wards + resurrects downed allies → forces priority kill (mark / shatter).
## "stalker": cloaked until close, then pounce-ambushes → forces aus_senses (detect) / cloak / dash.
## "mortar": lobs fire AoE at the player's predicted position, leaves burning ground → forces reposition / Maw.
const ARCHETYPES := {
	"bulwark": { "hp": 1.8, "armor": 0.15, "speed": 0.78, "damage": 1.2, "front_armor": 0.85, "name": "Bulwark" },
	"choir":   { "hp": 1.2, "armor": 0.05, "speed": 0.9, "damage": 0.5, "warded_mind": true, "name": "Choir" },
	"stalker": { "hp": 1.0, "speed": 1.35, "damage": 1.4, "name": "Stalker" },
	"mortar":  { "hp": 1.1, "armor": 0.10, "speed": 0.7, "damage": 0.8, "name": "Mortar" },
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
# Search brain: LKP-anchored hunt that reads where the player WAS, not where they are.
var _search_mode: int = -1        # -1 = uninitialised; 0 sweep, 1 investigate, 2 lose-the-trail
var _search_target: Vector2 = Vector2.ZERO
var _search_phase_ticks: int = 0
var _search_cued: bool = false

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
	# Blood Grammar resonance — deterministic from id (NOT the RNG stream, so the slice stays stable).
	const HUMOURS := ["sanguine", "choleric", "melancholic", "phlegmatic"]
	e.resonance = HUMOURS[absi(hash([e.id, "resonance"])) % HUMOURS.size()]
	if bool(preset.get("boss", false)):
		e.tags["boss"] = true
		e.tags["warded_mind"] = true
		e.tags["native_warded_mind"] = true
	if preset.has("front_armor"):
		e.tags["front_armor"] = float(preset["front_armor"])
	if opts.has("resist") and opts["resist"] is Dictionary:
		e.tags["resist"] = (opts["resist"] as Dictionary).duplicate(true)
	# Combat role: an optional archetype (bulwark/choir/stalker/mortar) that layers role-specific
	# behavior on top of the shared AI. Set via opts["archetype"] at spawn. Absent = no role (the
	# legacy behavior, so existing spawns are unchanged → determinism-safe).
	if opts.has("archetype"):
		var arch := String(opts["archetype"])
		if ARCHETYPES.has(arch):
			_apply_archetype(e, arch)
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
	# A cloaked Stalker (ambush_cloaked) has NOT committed to combat yet: it does not acquire the
	# player, does not trip the alert/heat transition, and is itself hidden (reads as `cloaked` so
	# witnesses and the player's perception treat it as unseen). It sneaks via _step_stalker only.
	var arch := String(entity.tags.get("archetype", ""))
	var ambush := bool(entity.tags.get("ambush_cloaked", false))
	if ambush:
		entity.tags["cloaked"] = true
		entity.perception_state = "hidden"
		_step_stalker(delta, sim, sees_player)
		return
	entity.tags.erase("cloaked")
	if entity.responder or entity.hostile_to_player:
		if sees_player:
			# A freshly-spotted player pops an alert bubble ("!" noticed / "!!" hostile) so the
			# player reads that this foe has acquired them. Only fire on the state TRANSITION
			# (perception_state wasn't already combat) so it pops once per acquisition, not every tick.
			if entity.perception_state != "combat":
				var was_hunting := entity.ai_state in ["chase", "attack", "search"]
				entity.ai_state = "chase"
				entity.perception_state = "combat"
				sim.emit_cue("enemy.alert", { "entity_id": entity.id, "pos": entity.pos, "alert_level": "hostile" if was_hunting else "noticed" })
		elif entity.search_ticks > 0 and entity.ai_state in ["chase", "attack", "search"]:
			entity.search_ticks -= 1
			if entity.ai_state != "search":
				_begin_search()   # freshly lost the player — re-roll the hunt behavior
			entity.ai_state = "search"
			entity.perception_state = "searching"
		elif entity.responder:
			if entity.ai_state != "search":
				_begin_search()
			entity.ai_state = "search"
			entity.perception_state = "searching"
	if entity.ai_state == "wander" and sees_player:
		_on_calm_sight(sim)
	# Backline roles (Choir/Mortar) fully own their movement + ranged pressure once committed — the
	# base chase/attack would double-move and double-attack (pistol + lob). Let the role drive.
	# The Bulwark has no role step, so it falls through to the base melee loop (its identity IS the
	# frontal block on that melee). The Stalker only reaches here once revealed (ambush cleared).
	var owns_behavior := arch in ["choir", "mortar"] and (entity.hostile_to_player or entity.responder)
	if owns_behavior:
		_step_role(delta, sim, sees_player)
		return
	match entity.ai_state:
		"wander":
			_wander(delta, sim)
		"investigate", "search":
			_search(delta, sim, sees_player)
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

## Combat-role dispatcher. Each role is a self-contained method that adds distinct pressure so the
## player must use a DIFFERENT verb to win. All deterministic: cooldowns are tick counters, the only
## RNG is the LCG via sim.draw_* (never randf). Choir/Mortar reach here via the owns_behavior gate
## (they fully own their movement + ranged pressure); the Bulwark needs no per-tick step (its frontal
## block is the front_armor tag read in Sim.damage_entity); the Stalker is driven while cloaked by
## the ambush branch above and after reveal by the base melee loop.
func _step_role(delta: float, sim, sees_player: bool) -> void:
	var arch := String(entity.tags.get("archetype", ""))
	if arch == "":
		return
	# Backline roles only act when there is a live threat to support against.
	if not (entity.hostile_to_player or entity.responder):
		return
	if arch == "choir":
		_step_choir(delta, sim)
	elif arch == "mortar":
		_step_mortar(delta, sim, sees_player)
	# Bulwark needs no per-tick role step: its identity is the frontal block on its existing melee,
	# enforced by the front_armor tag (read in Sim.damage_entity). It just chases + melees slowly.


## STALKER — cloaked ambusher. While ambush_cloaked it does not acquire the player, reads as `cloaked`
## (hidden from witnesses/perception), and sneaks into pounce range. On reveal it commits a real
## wind-up melee pounce with BONUS damage (the predator's strike). The player counters by keeping
## Auspex (detect) up to see it early and shred the cloak, or by dashing the pounce via i-frames.
## NOTE: a Stalker must be a MELEE type (thug) — a gun unit would shoot from range while "cloaked",
## defeating the ambush fantasy. _step_stalker is called directly from step() while cloaked.
func _step_stalker(delta: float, sim, sees_player: bool) -> void:
	var p: SimEntity = sim.player
	if p == null or p.dead:
		return
	var d := entity.pos.distance_to(p.pos)
	# Auspex detect shreds the cloak early: a player with the detect buff running sees the Stalker
	# before it strikes, forcing the predator-fantasy read of "I sensed it before it bit."
	var detected := false
	if p.behaviour != null:
		var buffs: Dictionary = p.behaviour.get("buffs")
		if buffs.has("aus_senses"):
			detected = d < float(buffs["aus_senses"].get("detect", 140.0))
	# Reveal + commit the pounce: drop the cloak, become hostile, wind up a melee strike.
	if detected or d < 78.0:
		entity.tags.erase("ambush_cloaked")
		entity.tags.erase("cloaked")
		entity.hostile_to_player = true
		entity.ai_state = "attack"
		entity.perception_state = "combat"
		# The pounce: a wind-up telegraph (readable, dodgeable) that deals bonus damage on commit.
		# The bonus is an attacker-side outgoing_bonus tag, read in Sim.damage_entity and decayed
		# here via pounce_bonus_ticks so it expires right after the strike lands.
		var wind := 20
		entity.telegraph_ticks = wind
		entity.tags["outgoing_bonus"] = 0.8   # +80% on the pounce strike
		entity.tags["pounce_bonus_ticks"] = wind + 8   # clear the bonus shortly after the strike lands
		sim.emit_cue("enemy.alert", { "entity_id": entity.id, "pos": entity.pos, "alert_level": "hostile" })
		sim.emit_cue("enemy.telegraph", { "entity_id": entity.id, "pos": entity.pos, "direction": (p.pos - entity.pos).angle(), "attack_type": "pounce", "wind_up_ms": int(wind * 1000.0 / 60.0) })
	else:
		# Still cloaked: sneak toward the player without alerting. No chase flag, no witness trip.
		_move_toward(p.pos, delta, sim, 0.85)


## CHOIR — backline cultist healer. Stays at preferred range, periodically pulses a heal + ward over
## nearby allies (and resurrects one downed thug). Forces priority kill: the player must Mark the
## Choir (aus_mark) or shatter-mesmerize it (dom_mesmer) before it undoes their damage. The ward
## also grants brief empowered buffs to its allies, making the squad deadlier the longer it lives.
func _step_choir(delta: float, sim) -> void:
	var p: SimEntity = sim.player
	# Hold a backline preferred range (~220px): close in if too far, back off if the player is on top.
	if p != null and not p.dead:
		var d := entity.pos.distance_to(p.pos)
		if d < 170.0:
			_move_toward(entity.pos - (p.pos - entity.pos).normalized() * 60.0, delta, sim, 0.85)
		elif d > 280.0:
			_move_toward(p.pos, delta, sim, 0.6)
		else:
			entity.vel = Vector2.ZERO
	# Heal pulse on cooldown. Heals the most-wounded ally in radius + brief empowered + warded_mind.
	if entity.role_tick <= 0:
		entity.role_tick = 150   # ~2.5s between pulses
		var best: SimEntity = null
		var best_deficit := 0.0
		for ally in sim.entities_in_radius(entity.pos, 180.0, func(e): return e != entity and e.kind == "npc" and e.faction == entity.faction and not e.dead and e.hostile_to_player):
			var deficit: float = ally.max_hp - ally.hp
			if deficit > best_deficit:
				best_deficit = deficit
				best = ally
		if best != null and best_deficit > 0.0:
			best.hp = minf(best.max_hp, best.hp + best.max_hp * 0.30)
			# The Choir's blessing also steadies the ally's mind briefly (warded_mind) so social
			# CC (Dominate fear) can't trivially disable the squad it's keeping alive.
			best.tags["warded_mind"] = true
			best.tags["choir_blessed"] = 180   # ticks; cleared below so it isn't permanent
			sim.emit_cue("enemy.heal", { "entity_id": best.id, "pos": best.pos, "amount": best_deficit })
		# Resurrect one downed ally nearby (a thug the player felled) — the Choir "raises" its choir.
		var fallen := sim.nearest_entity(entity.pos, 150.0, func(e): return e != entity and e.kind == "npc" and e.faction == entity.faction and e.downed and not e.dead and not bool(e.tags.get("player_body", false))) as SimEntity
		if fallen != null:
			fallen.downed = false
			fallen.hp = fallen.max_hp * 0.5
			fallen.ai_state = "chase"
			fallen.perception_state = "combat"
			sim.emit_cue("enemy.raised", { "entity_id": fallen.id, "pos": fallen.pos })


## MORTAR — ranged AoE bombardier. Lobs a fire bomb at the player's PREDICTED position (lead the
## velocity), leaving burning ground on impact. Forces constant repositioning and rewards the
## Obtenebration Maw (drag the caster in) or breaking LOS to a wall. Uses the ballistic projectile
## path already built for bs_cauldron (deterministic arc + fire surface).
func _step_mortar(delta: float, sim, sees_player: bool) -> void:
	var p: SimEntity = sim.player
	if p == null or p.dead or not sees_player:
		entity.vel = Vector2.ZERO
		return
	# Hold a long preferred range so it lobs rather than melees.
	var d := entity.pos.distance_to(p.pos)
	if d < 220.0:
		_move_toward(entity.pos - (p.pos - entity.pos).normalized() * 80.0, delta, sim, 0.7)
	else:
		entity.vel = Vector2.ZERO
	# Lob on cooldown: aim at the player's lead position, spawn a ballistic fire-bomb.
	if entity.role_tick <= 0:
		entity.role_tick = 96   # ~1.6s between lobs
		var lead: Vector2 = p.pos + (p.vel if p.vel != null else Vector2.ZERO) * 0.18
		entity.facing = (lead - entity.pos).angle()
		BallisticLaunch.spawn(sim, entity.pos, lead, {
			"kind": "fire_bomb", "faction": entity.faction, "owner_id": entity.id,
			"damage": entity.attack_damage * 1.2, "damage_type": "fire", "status": "burn",
			"aoe_radius": 64.0, "surface_effect": "fire", "surface_radius": 64.0, "flight_ticks": 32,
		})
		sim.emit_cue("enemy.mortar", { "entity_id": entity.id, "pos": entity.pos, "target": lead })


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
	# Taking a hit interrupts any in-progress wind-up: the heavy swing is cancelled, so the player
	# can stagger an NPC out of a telegraph (a fair, readable interrupt) instead of eating the hit.
	entity.telegraph_ticks = 0
	if entity.faction == "civ":
		entity.ai_state = "flee"
		entity.perception_state = "afraid"
	else:
		entity.hostile_to_player = true
		entity.ai_state = "chase"
		entity.perception_state = "combat"

func state_hash() -> int:
	var h := hash([snapped(speed, 0.001), snapped(threat, 0.001), snapped(wander_target.x, 0.001), snapped(wander_target.y, 0.001), _wander_ticks, path_index, path_ticks, _search_mode, snapped(_search_target.x, 0.001), snapped(_search_target.y, 0.001), _search_phase_ticks, _search_cued])
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
			sim.emit_cue("enemy.alert", { "entity_id": entity.id, "pos": entity.pos, "alert_level": "noticed" })
			sim.witnessed_act(entity.pos, "panic", 0.35)
	elif entity.faction == "police" and sim.heat_stars() >= 1:
		entity.hostile_to_player = true
		entity.ai_state = "chase"
		entity.perception_state = "combat"
		sim.emit_cue("enemy.alert", { "entity_id": entity.id, "pos": entity.pos, "alert_level": "hostile" })
	elif entity.faction == "inquis":
		entity.hostile_to_player = true
		entity.ai_state = "chase"
		entity.perception_state = "combat"
		sim.emit_cue("enemy.alert", { "entity_id": entity.id, "pos": entity.pos, "alert_level": "hostile" })

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

## Re-roll the hunt behavior the moment the player is freshly lost. Deterministic: the mode is
## chosen from a per-search draw (the LCG), not from wall-clock or randf.
func _begin_search() -> void:
	_search_mode = -1
	_search_phase_ticks = 0
	_search_cued = false

## The "hunts where you WERE" brain. Reads the last-known-position (LKP) and runs one of three
## legible behaviors. Each emits "ai.search" so a search marker can render at the point of interest.
func _search(delta: float, sim, _sees_player: bool) -> void:
	var lkp: Vector2 = entity.last_seen_pos
	# First tick of a fresh search: pick a behavior off the seeded stream and lock its target.
	if _search_mode < 0:
		# Investigate a body/blood the hunter passed near; otherwise sweep the LKP, or — when the
		# trail has run cold (few search_ticks left) — widen out and prepare to abandon.
		var body: SimEntity = _nearest_evidence(sim, lkp)
		if entity.search_ticks <= 60:
			_search_mode = 2   # lose-the-trail: widen, then give up
			var spread: float = (float(int(sim.draw_index(360))) / 360.0) * TAU
			_search_target = lkp + Vector2.RIGHT.rotated(spread) * (140.0 + float(int(sim.draw_index(80))))
		elif body != null:
			_search_mode = 1   # investigate nearby evidence
			_search_target = body.pos
		else:
			_search_mode = 0   # move to LKP and sweep a vision cone
			_search_target = lkp
		_search_phase_ticks = 0
		# Emit the search cue once per behavior so a marker can render at the point of interest.
		if not _search_cued:
			_search_cued = true
			sim.emit_cue("ai.search", { "entity_id": entity.id, "pos": _search_target, "mode": _search_mode, "faction": entity.faction })

	_search_phase_ticks += 1
	match _search_mode:
		0:
			# (a) SWEEP — drive to the LKP, then pan the facing across a cone to re-acquire.
			if entity.pos.distance_to(_search_target) >= 26.0:
				_move_toward(_search_target, delta, sim, 0.78)
			else:
				# Arrived: stand and sweep a vision cone (deterministic sine pan off the tick).
				entity.vel = Vector2.ZERO
				var sweep: float = sin(float(_search_phase_ticks) * 0.06) * 1.15
				var base_face: float = (lkp - entity.pos).angle() if entity.pos.distance_to(lkp) > 4.0 else entity.facing
				entity.facing = base_face + sweep
				entity.search_ticks = max(0, entity.search_ticks - 1)
		1:
			# (b) INVESTIGATE — go to the body/blood the player left, linger, then fall back to LKP.
			if entity.pos.distance_to(_search_target) >= 26.0:
				_move_toward(_search_target, delta, sim, 0.7)
			else:
				entity.vel = Vector2.ZERO
				if _search_phase_ticks > 70:
					_search_mode = 0          # nothing here — resume sweeping the LKP
					_search_target = lkp
					_search_phase_ticks = 0
				else:
					entity.search_ticks = max(0, entity.search_ticks - 1)
		_:
			# (c) LOSE-THE-TRAIL — widen to a guessed point, then bleed off search and abandon.
			if entity.pos.distance_to(_search_target) >= 30.0 and _search_phase_ticks < 150:
				_move_toward(_search_target, delta, sim, 0.85)
			else:
				entity.vel = Vector2.ZERO
			entity.search_ticks = max(0, entity.search_ticks - 4)

## Nearest spilled-blood pool or downed body near the LKP, so the hunter investigates real evidence
## the player left behind. Returns null when nothing notable is close.
func _nearest_evidence(sim, around: Vector2) -> SimEntity:
	return sim.nearest_entity(around, 130.0, func(e: SimEntity) -> bool:
		return e != entity and not e.dead and e.kind == "npc" and (e.downed or e.ai_state == "downed")) as SimEntity

func _attack(delta: float, sim) -> void:
	var p: SimEntity = sim.player
	var dist := entity.pos.distance_to(p.pos)
	# Out of range: abandon the wind-up and chase back in.
	if dist > max(entity.attack_range, 42.0) + 16.0:
		entity.telegraph_ticks = 0
		entity.ai_state = "chase"
		return
	entity.facing = (p.pos - entity.pos).angle()
	# GUN NPCs: no wind-up. The visible projectile IS the telegraph — the dash beats a bullet by
	# stepping out of its path. Fire immediately on cooldown.
	if _is_gun_npc():
		if entity.attack_cooldown <= 0 and entity.attack_damage > 0.0:
			_fire_at_player(sim, p)
			entity.attack_cooldown = 55
		return
	# MELEE NPCs: wind up a readable, dodgeable heavy strike before connecting.
	if entity.telegraph_ticks <= 0:
		# Start a wind-up (only when ready to commit a strike). Heavier hitters wind longer.
		if entity.attack_cooldown <= 0 and entity.attack_damage > 0.0:
			var wind := _melee_windup_ticks()
			entity.telegraph_ticks = wind
			sim.emit_cue("enemy.telegraph", {
				"entity_id": entity.id,
				"pos": entity.pos,
				"direction": (p.pos - entity.pos).angle(),
				"attack_type": "melee_heavy",
				"wind_up_ms": int(wind * 1000.0 / 60.0),
			})
		# While not winding up, hold facing/position (don't slide through the player).
		entity.vel = Vector2.ZERO
		return
	# Still winding up: hold ground (the strike resolves when telegraph_ticks hits 0, ticked in
	# SimEntity.step). Strike the instant the wind-up completes this frame.
	if entity.telegraph_ticks == 1:
		_commit_melee_strike(sim, p)
		entity.attack_cooldown = 55 if entity.attack_range > 80.0 else 42
	else:
		entity.vel = Vector2.ZERO   # committed to the wind-up: no repositioning mid-swing

## Wind-up length scales with how heavy the NPC hits — a thug's bat snaps fast, a bruiser winds slow.
func _melee_windup_ticks() -> int:
	if entity.attack_damage >= 18.0:
		return 25   # heavy: ~0.42s, readable dodge window
	if entity.attack_damage >= 9.0:
		return 18   # medium: ~0.30s
	return 12       # light: ~0.20s, still readable

## Resolve the telegraphed melee strike. Reads i-frames so a well-timed dash phases the hit.
func _commit_melee_strike(sim, p: SimEntity) -> void:
	var damage := entity.attack_damage
	if p.behaviour != null and int(p.behaviour.get("iframes_remaining")) > 0:
		damage = 0.0
	if damage <= 0.0:
		return
	sim.damage_entity(entity, p, damage, { "cue": "damage.player", "heat": false, "status": "poison" if bool(entity.tags.get("elite_venom", false)) else "", "status_ticks": 180, "status_dps": 1.6 if bool(entity.tags.get("elite_venom", false)) else 0.0 })
	if bool(entity.tags.get("elite_vampiric", false)):
		entity.hp = minf(entity.max_hp, entity.hp + damage * 0.35)

## True for ranged gun NPCs (cop/swat/hunter/elder/gunner/thrall) — pistol or rifle armed.
func _is_gun_npc() -> bool:
	var weapon := String(entity.tags.get("weapon", ""))
	return weapon == "pistol" or weapon == "rifle"

## Spawn a visible bullet from the muzzle toward the player. Faction-tagged so SimProjectile resolves
## it against the player (mirrors the player-fired shot path). Deterministic muzzle scatter via the LCG.
func _fire_at_player(sim, p: SimEntity) -> void:
	var to_player := p.pos - entity.pos
	var aim := to_player.angle() if to_player.length_squared() > 0.01 else entity.facing
	# Tiny deterministic scatter so distant fire is dodgeable, not pinpoint; rifles are tighter.
	var spread := 0.05 if String(entity.tags.get("weapon", "")) == "rifle" else 0.09
	aim += (sim.draw_float() - 0.5) * 2.0 * spread
	var shot_dir := Vector2.RIGHT.rotated(aim)
	entity.facing = aim
	var speed := 560.0 if String(entity.tags.get("weapon", "")) == "rifle" else 500.0
	var start := entity.pos + shot_dir * (entity.radius + 8.0)
	sim.spawn_projectile(start, shot_dir * speed, {
		"owner_id": entity.id,
		"faction": entity.faction,
		"kind": "bullet",
		"damage": entity.attack_damage,
		"radius": 4.0,
		"life_ticks": 110,
		"status": "poison" if bool(entity.tags.get("elite_venom", false)) else "",
		"status_ticks": 180 if bool(entity.tags.get("elite_venom", false)) else 0,
		"status_dps": 1.6 if bool(entity.tags.get("elite_venom", false)) else 0.0,
		"cue": "damage.player",
		"damage_type": "physical",
	})

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

static func _apply_archetype(e: SimEntity, arch_id: String) -> void:
	# Apply a combat role's stat/tune and tag it. The behavior itself runs in _step_role().
	var a: Dictionary = ARCHETYPES[arch_id]
	e.tags["archetype"] = arch_id
	e.max_hp = roundf(e.max_hp * float(a.get("hp", 1.0)))
	e.hp = e.max_hp
	e.armor += float(a.get("armor", 0.0))
	e.attack_damage *= float(a.get("damage", 1.0))
	e.tags["speed_mult"] = float(e.tags.get("speed_mult", 1.0)) * float(a.get("speed", 1.0))
	if a.has("front_armor"):
		e.tags["front_armor"] = float(a["front_armor"])
	if bool(a.get("warded_mind", false)):
		e.tags["warded_mind"] = true
		e.tags["native_warded_mind"] = true
	# The Stalker spawns cloaked: it does not break stealth until it pounces or is detected by Auspex.
	if arch_id == "stalker":
		e.tags["ambush_cloaked"] = true
	# The Choir is a non-combatant backline support — it should not chase into melee.
	if arch_id == "choir":
		e.tags["backline"] = true


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
		e.tags["native_warded_mind"] = true
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
