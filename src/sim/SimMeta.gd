## SimMeta.gd -- deterministic persistent/backend game systems.
##
## This ports the non-rendering legacy systems that are larger than one combat tick:
## stats, skill tree, hotbar, inventory/equipment, economy, haven, coterie,
## domains, reputation, missions, day/night, and plain-data save/load.
extends RefCounted
class_name SimMeta

const Catalog := preload("res://src/data/GameCatalog.gd")

const MAX_LEVEL := 60
const ELDER_XP := 2000
const NIGHT_START := 21.0
const DAWN_HOUR := 6.0
const NIGHT_HOURS := 9.0
const NIGHT_SECONDS := 18.0 * 60.0

var clan_id: String = "brujah"
var difficulty: String = "normal"
var day: int = 1
var clock: float = NIGHT_START
var dawn_warning_sent: bool = false

var level: int = 1
var xp: int = 0
var xp_total: int = 0
var elder_vitae: int = 0
var elder_progress: float = 0.0
var attributes: Dictionary = {}
var attr_points: int = 0
var skill_points: int = 4
var tree_nodes: Dictionary = {}
var known_powers: Dictionary = {}
var slots: Array = []
var money: int = 600
var respecs: int = 0
var influence: float = 3.0

var derived: Dictionary = {}
var mods: Dictionary = {}
var inventory: Array[Dictionary] = []
var equipment: Dictionary = {}
var next_item_id: int = 1

var haven: Dictionary = {}
var reputation: Dictionary = {}
var coterie: Array[Dictionary] = []
var next_coterie_id: int = 1
var domains: Dictionary = {}
var district_state: Dictionary = {}
var businesses: Dictionary = {}
var active_mission: Dictionary = {}
var mission_offers: Array[Dictionary] = []
var missions_done: int = 0
var next_mission_id: int = 1
var chain_progress: Dictionary = {}
var chain_titles: Dictionary = {}
var achievements: Dictionary = {}
var stats: Dictionary = {}

func reset(new_clan_id: String) -> void:
	clan_id = _clean_clan(new_clan_id)
	difficulty = "normal"
	day = 1
	clock = NIGHT_START
	dawn_warning_sent = false
	level = 1
	xp = 0
	xp_total = 0
	elder_vitae = 0
	elder_progress = 0.0
	attributes = new_attributes()
	attr_points = 0
	skill_points = 4
	tree_nodes.clear()
	known_powers.clear()
	for id in ["cel_dash", "pot_slam", "for_mend", "obf_cloak", "aus_mark", "dom_mesmer", "pre_dread", "bs_bolt"]:
		known_powers[id] = true
	slots = ["cel_dash", "pot_slam", "for_mend", "obf_cloak", "aus_mark", "dom_mesmer", "pre_dread", "bs_bolt"]
	money = 600
	respecs = 0
	inventory.clear()
	equipment = {
		"weapon": { "kind": "claws", "name": "Vampiric Claws", "slot": "weapon", "rarity": "innate", "mods": { "add": {}, "pct": {} }, "weaponStats": { "damage": 14.0, "range": 44.0 } },
		"attire": null,
		"charm1": null,
		"charm2": null,
	}
	next_item_id = 1
	_ensure_haven()
	_ensure_reputation()
	_ensure_domains()
	businesses.clear()
	coterie.clear()
	next_coterie_id = 1
	active_mission.clear()
	mission_offers.clear()
	missions_done = 0
	next_mission_id = 1
	chain_progress.clear()
	chain_titles.clear()
	achievements.clear()
	stats = { "kills": 0, "feeds": 0, "castsTotal": 0, "hijacks": 0 }
	recompute()

func tick(delta: float, sim) -> void:
	clock += delta * (NIGHT_HOURS / NIGHT_SECONDS)
	if not dawn_warning_sent and clock >= 5.5 and clock < NIGHT_START:
		dawn_warning_sent = true
		sim.emit_cue("dawn.warning", { "clock": clock, "day": day, "caption": "Dawn is close." })
	if clock >= 24.0:
		clock -= 24.0
	if clock >= DAWN_HOUR and clock < NIGHT_START:
		resolve_dawn(sim)
	_update_influence(delta)
	_update_active_mission(delta, sim)

func recompute() -> Dictionary:
	var a := attributes
	var bp := blood_potency(level)
	var bag := blank_mods()
	add_mods(bag, aggregate_tree_mods())
	add_mods(bag, aggregate_equipment_mods())
	add_mods(bag, aggregate_haven_mods())
	add_mods(bag, aggregate_reputation_mods())
	add_mods(bag, Catalog.CLAN_BANES.get(clan_id, {}))
	add_mods(bag, Catalog.CLAN_BOONS.get(clan_id, {}))
	mods = bag
	var add: Dictionary = bag["add"]
	var pct: Dictionary = bag["pct"]
	derived = {
		"bloodPotency": bp,
		"generation": 13 - bp,
		"maxHP": roundi((100.0 + (float(a["vitality"]) - 1.0) * 9.0 + float(level - 1) * 4.0 + float(add.get("maxHP", 0.0))) * (1.0 + float(pct.get("maxHP", 0.0)))),
		"maxBlood": roundi((100.0 + (float(a["bloodcraft"]) - 1.0) * 6.0 + float(bp) * 12.0 + float(level - 1) * 3.0 + float(add.get("maxBlood", 0.0))) * (1.0 + float(pct.get("maxBlood", 0.0)))),
		"moveSpeed": (158.0 + (float(a["finesse"]) - 1.0) * 1.6 + float(add.get("moveSpeed", 0.0))) * (1.0 + float(pct.get("moveSpeed", 0.0))),
		"attackSpeed": clamp((1.0 + (float(a["finesse"]) - 1.0) * 0.012 + float(add.get("attackSpeed", 0.0))) * (1.0 + float(pct.get("attackSpeed", 0.0))), 0.4, 4.0),
		"meleeDmg": (14.0 + (float(a["might"]) - 1.0) * 2.6 + float(bp) * 3.0 + float(add.get("meleeDmg", 0.0))) * (1.0 + float(pct.get("meleeDmg", 0.0))),
		"spellPower": (1.0 + (float(a["bloodcraft"]) - 1.0) * 0.05 + float(bp) * 0.08) * (1.0 + float(pct.get("spellPower", 0.0))) + float(add.get("spellPower", 0.0)) * 0.01,
		"critChance": clamp(0.05 + (float(a["wits"]) - 1.0) * 0.004 + float(pct.get("critChance", 0.0)) + float(add.get("critChance", 0.0)) * 0.01, 0.0, 0.85),
		"critMult": 1.8 + float(pct.get("critMult", 0.0)) + float(add.get("critMult", 0.0)) * 0.01,
		"cooldownMult": 1.0 - clamp((float(a["wits"]) - 1.0) * 0.006 + float(pct.get("cdr", 0.0)), 0.0, 0.7),
		"armor": clamp(float(pct.get("armor", 0.0)) + float(add.get("armor", 0.0)) * 0.01, 0.0, 0.85),
		"dodge": clamp((float(a["finesse"]) - 1.0) * 0.0035 + float(pct.get("dodge", 0.0)) + float(add.get("dodge", 0.0)) * 0.01, 0.0, 0.7),
		"lifesteal": float(pct.get("lifesteal", 0.0)) + float(add.get("lifesteal", 0.0)) * 0.01,
		"hpRegen": (0.4 + (float(a["vitality"]) - 1.0) * 0.18 + float(add.get("hpRegen", 0.0))) * (1.0 + float(pct.get("hpRegen", 0.0))),
		"bloodRegen": (0.55 + (float(a["bloodcraft"]) - 1.0) * 0.12 + float(add.get("bloodRegen", 0.0))) * (1.0 + float(pct.get("bloodRegen", 0.0))),
		"xpMult": (1.0 + (float(a["presence"]) - 1.0) * 0.012 + float(pct.get("xpMult", 0.0))) * (1.0 + float(add.get("xpMult", 0.0)) * 0.01),
		"feedSpeed": (1.0 + (float(a["presence"]) - 1.0) * 0.02 + float(add.get("feedSpeed", 0.0))) * (1.0 + float(pct.get("feedSpeed", 0.0))),
		"feedYield": maxf(0.1, (1.0 + (float(a["presence"]) - 1.0) * 0.015 + float(bp) * 0.05 + float(add.get("feedYield", 0.0))) * (1.0 + float(pct.get("feedYield", 0.0)))),
		"priceMult": clamp(1.0 - (float(a["presence"]) - 1.0) * 0.008 - float(pct.get("discount", 0.0)), 0.4, 1.0),
		"influenceMax": 3.0 + maxf(0.0, (float(a["presence"]) - 1.0) + float(add.get("influence", 0.0))),
		"detectRange": 220.0 + (float(a["wits"]) - 1.0) * 4.0 + float(add.get("detectRange", 0.0)),
		"frenzyResist": clamp(0.3 + (float(a["vitality"]) - 1.0) * 0.02 + float(pct.get("frenzyResist", 0.0)), 0.0, 0.95),
		"sunResist": clamp(float(pct.get("sunResist", 0.0)) + float(add.get("sunResist", 0.0)) * 0.01, 0.0, 0.95),
		"vehicleHandling": 1.0 + float(pct.get("vehicle", 0.0)),
		"bloodEff": clamp(float(pct.get("bloodEff", 0.0)), 0.0, 0.6),
	}
	influence = min(influence, float(derived["influenceMax"]))
	return derived

func apply_to_runtime(sim) -> void:
	if sim.player == null or sim.player.behaviour == null:
		return
	recompute()
	sim.player.max_hp = float(derived["maxHP"])
	sim.player.hp = clamp(sim.player.hp, 0.0, sim.player.max_hp)
	sim.player.armor = float(derived["armor"])
	sim.player.attack_damage = float(derived["meleeDmg"])
	var behaviour = sim.player.behaviour
	behaviour.set("max_blood", float(derived["maxBlood"]))
	behaviour.set("blood", min(float(behaviour.get("blood")), float(derived["maxBlood"])))
	behaviour.set("move_speed", maxf(150.0, float(derived["moveSpeed"])))

func xp_to_next(lv: int) -> int:
	var cl: int = min(lv, 45)
	return floori(70.0 * pow(1.085, float(cl - 1)) + 55.0 * float(cl) + 40.0 * max(0.0, float(lv - 45)))

func blood_potency(lv: int) -> int:
	return min(9, floori(float(lv - 1) / 7.0))

func gain_xp(amount: int, sim = null) -> Array:
	var gained: int = max(0, roundi(float(amount) * float(derived.get("xpMult", 1.0))))
	xp += gained
	xp_total += gained
	var ups: Array = []
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		attr_points += 2
		skill_points += 1
		if level % 5 == 0:
			skill_points += 1
		ups.append({ "level": level, "attr_points": 2, "skill_points": 2 if level % 5 == 0 else 1, "blood_potency": blood_potency(level) })
	if level >= MAX_LEVEL and xp > 0:
		elder_progress += xp
		xp = 0
		while elder_progress >= ELDER_XP:
			elder_progress -= ELDER_XP
			elder_vitae += 1
	if ups.size() > 0:
		recompute()
		if sim != null:
			apply_to_runtime(sim)
			sim.emit_cue("player.level_up", { "level": level, "ups": ups.duplicate(true) })
	return ups

func spend_attribute(attr_id: String) -> bool:
	if attr_points <= 0 or not attributes.has(attr_id) or int(attributes[attr_id]) >= 50:
		return false
	attributes[attr_id] = int(attributes[attr_id]) + 1
	attr_points -= 1
	recompute()
	return true

func can_allocate(node_id: String) -> Dictionary:
	if not Catalog.SKILL_NODES.has(node_id):
		return { "ok": false, "why": "no node" }
	if skill_points <= 0:
		return { "ok": false, "why": "no skill points" }
	var node: Dictionary = Catalog.SKILL_NODES[node_id]
	if int(tree_nodes.get(node_id, 0)) >= int(node.get("maxRank", 1)):
		return { "ok": false, "why": "maxed" }
	var tier := int(node.get("tier", 0))
	var need := int(Catalog.SKILL_TIER_REQ[min(tier, Catalog.SKILL_TIER_REQ.size() - 1)])
	if branch_points(String(node.get("branch", ""))) < need:
		return { "ok": false, "why": "needs branch points" }
	if node.has("conflicts"):
		for conflict in node["conflicts"]:
			if int(tree_nodes.get(String(conflict), 0)) > 0:
				return { "ok": false, "why": "conflicts" }
	return { "ok": true }

func allocate_skill(node_id: String, sim = null) -> bool:
	var check := can_allocate(node_id)
	if not bool(check["ok"]):
		return false
	var node: Dictionary = Catalog.SKILL_NODES[node_id]
	var was_zero := int(tree_nodes.get(node_id, 0)) == 0
	tree_nodes[node_id] = int(tree_nodes.get(node_id, 0)) + 1
	skill_points -= 1
	if String(node.get("type", "")) == "power" and was_zero:
		learn_power(String(node.get("power", "")))
	recompute()
	if sim != null:
		apply_to_runtime(sim)
		sim.emit_cue("skill.allocated", { "node_id": node_id, "power": node.get("power", "") })
	return true

func branch_points(branch_id: String) -> int:
	var points := 0
	for id in tree_nodes:
		var node: Dictionary = Catalog.SKILL_NODES.get(String(id), {})
		if String(node.get("branch", "")) == branch_id:
			points += int(tree_nodes[id])
	return points

func learn_power(power_id: String) -> bool:
	var id := Catalog.canonical_power_id(power_id)
	if id == "" or not Catalog.POWERS.has(id) or known_powers.has(id):
		return false
	known_powers[id] = true
	auto_slot(id)
	return true

func knows_power(power_id: String) -> bool:
	return known_powers.has(Catalog.canonical_power_id(power_id))

func assign_slot(slot_index: int, power_id: String) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var id := Catalog.canonical_power_id(power_id)
	if id != "" and not knows_power(id):
		return false
	for i in range(slots.size()):
		if slots[i] == id:
			slots[i] = null
	slots[slot_index] = id if id != "" else null
	return true

func auto_slot(power_id: String) -> void:
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = power_id
			return

func slot_power(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= slots.size() or slots[slot_index] == null:
		return ""
	return String(slots[slot_index])

func effective_power_cost(power_id: String) -> float:
	var def: Dictionary = Catalog.POWERS.get(Catalog.canonical_power_id(power_id), {})
	var cost := float(def.get("cost", 0.0))
	if int(tree_nodes.get("bs_key", 0)) > 0:
		cost *= 0.5
	return maxf(0.0, cost * (1.0 - float(derived.get("bloodEff", 0.0))))

func effective_power_cooldown(power_id: String) -> int:
	var def: Dictionary = Catalog.POWERS.get(Catalog.canonical_power_id(power_id), {})
	return max(1, roundi(float(def.get("cooldown", 60)) * float(derived.get("cooldownMult", 1.0))))

func respec_tree(sim = null) -> int:
	var refund := 0
	for id in tree_nodes:
		refund += int(tree_nodes[id])
	tree_nodes.clear()
	skill_points += refund
	known_powers.clear()
	for id in ["cel_dash", "pot_slam", "for_mend", "obf_cloak", "aus_mark", "dom_mesmer", "pre_dread", "bs_bolt"]:
		known_powers[id] = true
	slots = ["cel_dash", "pot_slam", "for_mend", "obf_cloak", "aus_mark", "dom_mesmer", "pre_dread", "bs_bolt"]
	recompute()
	if sim != null:
		apply_to_runtime(sim)
	return refund

func generate_item(level_hint: int, rarity_key: String = "", slot_pref: String = "", sim = null) -> Dictionary:
	var item_level: int = max(1, level_hint)
	var rarity: String = rarity_key if rarity_key != "" else roll_rarity(item_level, 0.0, sim)
	var rinfo: Dictionary = Catalog.RARITY.get(rarity, Catalog.RARITY["common"])
	var slots_pool := ["weapon", "attire", "charm"]
	var slot: String = slot_pref if slot_pref != "" else String(slots_pool[_draw_index(sim, slots_pool.size())])
	var base: Dictionary = {}
	if slot == "weapon":
		base = (Catalog.WEAPONS[_draw_index(sim, Catalog.WEAPONS.size())] as Dictionary).duplicate(true)
	elif slot == "attire":
		base = (Catalog.ATTIRE[_draw_index(sim, Catalog.ATTIRE.size())] as Dictionary).duplicate(true)
	else:
		base = (Catalog.CHARMS[_draw_index(sim, Catalog.CHARMS.size())] as Dictionary).duplicate(true)
		slot = "charm"
	var mods := blank_mods()
	if base.has("base"):
		add_mods(mods, _scale_mods(base["base"], item_level, float(rinfo["mult"])))
	var weapon_stats := {}
	if slot == "weapon":
		weapon_stats = {
			"kind": base["kind"],
			"name": base["name"],
			"damage": roundi(float(base["damage"]) * (1.0 + float(item_level) * 0.06) * float(rinfo["mult"])),
			"fire_rate": base.get("fire_rate", 0.35),
			"spread": base.get("spread", 0.04),
			"speed": base.get("speed", 620.0),
			"pellets": base.get("pellets", 1),
			"pierce": base.get("pierce", 0),
		}
	var affixes: Array[String] = []
	var pool := Catalog.AFFIXES.duplicate(true)
	for _i in range(min(int(rinfo["affixes"]), pool.size())):
		var ix := _draw_index(sim, pool.size())
		var affix: Dictionary = pool.pop_at(ix)
		add_mods(mods, _affix_mods(affix, item_level))
		affixes.append(String(affix["name"]))
	var name_prefix := "" if rarity == "common" else String(rinfo["name"]) + " "
	var item := {
		"id": next_item_id,
		"slot": slot,
		"rarity": rarity,
		"level": item_level,
		"name": name_prefix + String(base["name"]),
		"baseName": String(base["name"]),
		"mods": mods,
		"affixes": affixes,
		"color": rinfo["color"],
		"weaponStats": weapon_stats,
	}
	next_item_id += 1
	return item

func roll_rarity(level_hint: int, luck: float = 0.0, sim = null) -> String:
	var roll := _draw_float(sim) + luck + float(level_hint) * 0.002
	if roll > 0.985:
		return "legendary"
	if roll > 0.93:
		return "epic"
	if roll > 0.80:
		return "rare"
	if roll > 0.52:
		return "uncommon"
	return "common"

func add_item(item: Dictionary, sim = null) -> void:
	inventory.append(item.duplicate(true))
	if inventory.size() > 40:
		inventory.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return sell_value(a) < sell_value(b))
		var sold: Dictionary = inventory.pop_front()
		money += sell_value(sold)
		if sim != null:
			sim.emit_cue("inventory.auto_sold", { "item": sold["name"], "money": money })

func equip_item(item_id: int, sim = null) -> bool:
	var idx := _inventory_index(item_id)
	if idx < 0:
		return false
	var item: Dictionary = inventory[idx]
	var slot := String(item.get("slot", "charm"))
	var slot_key := slot
	if slot == "charm":
		slot_key = "charm1" if equipment.get("charm1") == null else "charm2"
	var previous = equipment.get(slot_key)
	equipment[slot_key] = item.duplicate(true)
	inventory.remove_at(idx)
	if previous != null:
		inventory.append((previous as Dictionary).duplicate(true))
	recompute()
	if sim != null:
		apply_to_runtime(sim)
		sim.emit_cue("inventory.equipped", { "slot": slot_key, "item_id": item_id, "name": item.get("name", "") })
	return true

func sell_item(item_id: int, sim = null) -> bool:
	var idx := _inventory_index(item_id)
	if idx < 0:
		return false
	var item: Dictionary = inventory[idx]
	var value := sell_value(item)
	inventory.remove_at(idx)
	money += value
	if sim != null:
		sim.emit_cue("economy.sold", { "item_id": item_id, "value": value, "money": money })
	return true

func sell_value(item: Dictionary) -> int:
	var rarity := String(item.get("rarity", "common"))
	var r: Dictionary = Catalog.RARITY.get(rarity, Catalog.RARITY["common"])
	return roundi(20.0 * float(r.get("mult", 1.0)) * (1.0 + float(item.get("level", 1)) * 0.4))

func buy_item(item: Dictionary, sim = null) -> bool:
	var cost := roundi(price(item) * float(derived.get("priceMult", 1.0)))
	if money < cost:
		return false
	money -= cost
	add_item(item, sim)
	if sim != null:
		sim.emit_cue("economy.bought", { "item_id": item.get("id", 0), "cost": cost, "money": money })
	return true

func price(item: Dictionary) -> int:
	var rarity := String(item.get("rarity", "common"))
	var r: Dictionary = Catalog.RARITY.get(rarity, Catalog.RARITY["common"])
	return roundi(60.0 * float(r.get("mult", 1.0)) * (1.0 + float(item.get("level", 1)) * 0.6))

func use_service(service_id: String, sim) -> bool:
	if not Catalog.ECONOMY_SERVICES.has(service_id):
		return false
	var cost := service_cost(service_id)
	if money < cost:
		return false
	money -= cost
	match service_id:
		"refillBlood":
			if sim.player != null and sim.player.behaviour != null:
				sim.player.behaviour.set("blood", sim.player.behaviour.get("max_blood"))
				sim.player.behaviour.set("hunger", 0.0)
		"heal":
			if sim.player != null:
				sim.player.hp = sim.player.max_hp
		"respecTree":
			respecs += 1
			respec_tree(sim)
		"clearHeat":
			sim.reduce_heat(sim.heat, "service")
		"bribe":
			sim.reduce_heat(2.0, "service")
	sim.emit_cue("economy.service", { "service_id": service_id, "cost": cost, "money": money })
	return true

func service_cost(service_id: String) -> int:
	if service_id == "respecTree":
		return 200 + respecs * 175
	var service: Dictionary = Catalog.ECONOMY_SERVICES.get(service_id, {})
	return roundi(float(service.get("cost", 0)) * float(derived.get("priceMult", 1.0)))

func haven_cost(room_id: String) -> int:
	var room: Dictionary = Catalog.HAVEN_ROOMS.get(room_id, {})
	var current := int(haven.get("rooms", {}).get(room_id, 0))
	return int(room.get("cost_base", 0)) + current * int(room.get("cost_step", 0))

func upgrade_haven(room_id: String, sim = null) -> bool:
	_ensure_haven()
	if not Catalog.HAVEN_ROOMS.has(room_id):
		return false
	var room: Dictionary = Catalog.HAVEN_ROOMS[room_id]
	var current := int(haven["rooms"].get(room_id, 0))
	if current >= int(room.get("max", 0)):
		return false
	var cost := haven_cost(room_id)
	if money < cost:
		return false
	money -= cost
	haven["rooms"][room_id] = current + 1
	recompute()
	if sim != null:
		apply_to_runtime(sim)
		sim.emit_cue("haven.upgraded", { "room_id": room_id, "level": current + 1, "money": money })
	return true

func deposit_vitae(amount: float) -> float:
	_ensure_haven()
	var cap := 200.0 + float(haven["rooms"].get("cellar", 0)) * 400.0
	var before := float(haven.get("cellarVitae", 0.0))
	haven["cellarVitae"] = minf(cap, before + maxf(0.0, amount))
	return float(haven["cellarVitae"]) - before

func collect_vitae(sim) -> float:
	_ensure_haven()
	if sim.player == null or sim.player.behaviour == null:
		return 0.0
	var stored := float(haven.get("cellarVitae", 0.0))
	var headroom := float(sim.player.behaviour.get("max_blood")) - float(sim.player.behaviour.get("blood"))
	var drawn := minf(stored, headroom)
	sim.player.behaviour.set("blood", float(sim.player.behaviour.get("blood")) + drawn)
	haven["cellarVitae"] = stored - drawn
	return drawn

func coterie_cap() -> int:
	_ensure_haven()
	return 3 + int(haven["rooms"].get("barracks", 0)) + (1 if int(attributes.get("presence", 1)) > 6 else 0)

func bind_coterie_member(archetype: String, sim = null, childe: bool = false) -> Dictionary:
	if coterie.size() >= 12:
		return {}
	var first: String = Catalog.FIRST_NAMES[_draw_index(sim, Catalog.FIRST_NAMES.size())]
	var last: String = Catalog.LAST_NAMES[_draw_index(sim, Catalog.LAST_NAMES.size())]
	var member := {
		"id": next_coterie_id,
		"name": String(first) + " " + String(last),
		"archetype": archetype,
		"level": 3 if childe else 1,
		"xp": 0,
		"loyalty": 80 if childe else 50,
		"assignment": "none",
		"isChilde": childe,
	}
	next_coterie_id += 1
	coterie.append(member)
	if sim != null:
		sim.emit_cue("coterie.bound", member.duplicate(true))
	return member

func assign_coterie(member_id: int, job_id: String, sim = null) -> bool:
	if not Catalog.COTERIE_JOBS.has(job_id):
		return false
	for i in range(coterie.size()):
		if int(coterie[i].get("id", 0)) == member_id:
			coterie[i]["assignment"] = job_id
			if sim != null:
				sim.emit_cue("coterie.assigned", { "member_id": member_id, "job_id": job_id })
			return true
	return false

func collect_coterie_jobs() -> Dictionary:
	var cash := 0
	var vitae := 0
	for member in coterie:
		var job: Dictionary = Catalog.COTERIE_JOBS.get(String(member.get("assignment", "none")), {})
		var mult := 1.0 + float(member.get("level", 1)) * 0.15 + float(member.get("loyalty", 50)) * 0.004
		cash += roundi(float(job.get("cash", 0)) * mult)
		vitae += roundi(float(job.get("vitae", 0)) * mult)
	return { "cash": cash, "vitae": vitae }

func change_reputation(faction: String, amount: float, sim = null, apply_rival: bool = true) -> void:
	_ensure_reputation()
	if not reputation.has(faction):
		return
	reputation[faction] = clamp(float(reputation[faction]) + amount, -100.0, 100.0)
	if apply_rival and amount > 0.0 and Catalog.RIVALS.has(faction):
		change_reputation(String(Catalog.RIVALS[faction]), -amount * 0.5, sim, false)
	recompute()
	if sim != null:
		apply_to_runtime(sim)
		sim.emit_cue("reputation.changed", { "faction": faction, "value": reputation[faction] })

func contest_domain(domain_id: String, sim) -> bool:
	_ensure_domains()
	if not domains.has(domain_id) or domains[domain_id].get("owner", null) == "player":
		return false
	domains[domain_id]["contesting"] = true
	var pos: Vector2 = sim.world.named_points.get("enemy", sim.player.pos + Vector2(220, 0))
	var baron: SimEntity = sim.spawn_npc("elder", pos, { "state": "chase", "hostile_to_player": true })
	baron.tags["baron_of"] = domain_id
	sim.emit_cue("domain.contested", { "domain_id": domain_id, "baron_id": baron.id })
	return true

func claim_domain(domain_id: String, sim = null) -> bool:
	_ensure_domains()
	if not domains.has(domain_id):
		return false
	domains[domain_id]["owner"] = "player"
	domains[domain_id]["contesting"] = false
	district_state[domain_id]["prosperity"] = 1.0
	district_state[domain_id]["terror"] = 0.0
	if sim != null:
		sim.emit_cue("domain.claimed", { "domain_id": domain_id })
	return true

func collect_domain_tithe() -> Dictionary:
	_ensure_domains()
	var cash := 0
	var vitae := 0
	for d in Catalog.DISTRICTS:
		var id := String(d["id"])
		if domains[id].get("owner", null) == "player":
			var state: Dictionary = district_state[id]
			var mult := (1.0 + float(d["danger"])) * (1.0 + float(state.get("prosperity", 0.0))) * maxf(0.1, 1.0 - float(state.get("terror", 0.0)) * 0.6)
			cash += roundi(45.0 * mult)
			vitae += roundi(8.0 * mult)
	return { "cash": cash, "vitae": vitae }

func heat_mult_at(_pos: Vector2) -> float:
	_ensure_domains()
	if domains.get("old_town", {}).get("owner", null) == "player":
		return 0.4
	return 1.0

func generate_mission_offers(sim = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var types := Catalog.MISSION_TYPES.keys()
	types.sort()
	for i in range(min(4, types.size())):
		var type_id := String(types[(_draw_index(sim, types.size()) + i) % types.size()])
		out.append(_build_mission(type_id, sim))
	mission_offers = out.duplicate(true)
	return mission_offers

func accept_mission(mission_id: int, sim = null) -> bool:
	if not active_mission.is_empty():
		return false
	for offer in mission_offers:
		if int(offer.get("id", 0)) == mission_id:
			active_mission = offer.duplicate(true)
			active_mission["state"] = "active"
			active_mission["snap_innocent"] = int(stats.get("innocent_kills", 0))
			active_mission["violated"] = false
			if sim != null:
				_setup_mission(sim)
				sim.emit_cue("mission.accepted", active_mission.duplicate(true))
			return true
	return false

func mission_event(event_id: String, data: Dictionary, sim) -> void:
	if active_mission.is_empty() or String(active_mission.get("state", "")) != "active":
		return
	var type_id := String(active_mission["type"])
	if event_id == "feed.spare" or event_id == "feed.kill":
		stats["feeds"] = int(stats.get("feeds", 0)) + 1
		if type_id == "feed":
			_mission_progress(1, sim)
	if event_id == "npc.death":
		stats["kills"] = int(stats.get("kills", 0)) + 1
		if type_id in ["assassinate", "cleanse", "survive"]:
			_mission_progress(1, sim)
	if event_id == "player.escape" and type_id in ["heist", "courier", "escort"]:
		complete_mission(sim)
	if String(active_mission.get("modifier", {}).get("id", "")) == "silent" and sim.heat_stars() > 0:
		active_mission["violated"] = true

func complete_mission(sim) -> bool:
	if active_mission.is_empty():
		return false
	active_mission["state"] = "complete"
	missions_done += 1
	var modifier: Dictionary = active_mission.get("modifier", {})
	var bonus := 1.0 + (float(modifier.get("bonus", 0.0)) if not bool(active_mission.get("violated", false)) else 0.0)
	var reward: Dictionary = active_mission["reward"]
	var xp_reward := roundi(float(reward["xp"]) * bonus)
	var money_reward := roundi(float(reward["money"]) * bonus)
	money += money_reward
	gain_xp(xp_reward, sim)
	if _draw_float(sim) < float(reward.get("itemChance", 0.6)):
		add_item(generate_item(level + 2, roll_rarity(level, 0.3, sim), "", sim), sim)
	sim.emit_cue("mission.complete", { "mission": active_mission.duplicate(true), "xp": xp_reward, "money": money_reward })
	active_mission.clear()
	return true

func fail_mission(sim, why: String) -> void:
	if active_mission.is_empty():
		return
	var failed := active_mission.duplicate(true)
	active_mission.clear()
	sim.emit_cue("mission.failed", { "mission": failed, "why": why })

func serialize(sim = null) -> Dictionary:
	var runtime := {}
	if sim != null and sim.player != null and sim.player.behaviour != null:
		runtime = {
			"player_pos": sim.player.pos,
			"player_hp": sim.player.hp,
			"blood": sim.player.behaviour.get("blood"),
			"hunger": sim.player.behaviour.get("hunger"),
			"humanity": sim.player.behaviour.get("humanity"),
			"heat": sim.heat,
			"rng": sim.rng,
			"tick": sim.tick,
		}
	return {
		"v": 1,
		"clan": clan_id,
		"difficulty": difficulty,
		"day": day,
		"clock": clock,
		"level": level,
		"xp": xp,
		"xp_total": xp_total,
		"elder_vitae": elder_vitae,
		"elder_progress": elder_progress,
		"attributes": attributes.duplicate(true),
		"attr_points": attr_points,
		"skill_points": skill_points,
		"tree_nodes": tree_nodes.duplicate(true),
		"known_powers": known_powers.duplicate(true),
		"slots": slots.duplicate(true),
		"money": money,
		"respecs": respecs,
		"influence": influence,
		"inventory": inventory.duplicate(true),
		"equipment": equipment.duplicate(true),
		"next_item_id": next_item_id,
		"haven": haven.duplicate(true),
		"reputation": reputation.duplicate(true),
		"coterie": coterie.duplicate(true),
		"next_coterie_id": next_coterie_id,
		"domains": domains.duplicate(true),
		"district_state": district_state.duplicate(true),
		"businesses": businesses.duplicate(true),
		"active_mission": active_mission.duplicate(true),
		"mission_offers": mission_offers.duplicate(true),
		"missions_done": missions_done,
		"next_mission_id": next_mission_id,
		"chain_progress": chain_progress.duplicate(true),
		"chain_titles": chain_titles.duplicate(true),
		"achievements": achievements.duplicate(true),
		"stats": stats.duplicate(true),
		"runtime": runtime,
	}

func restore(data: Dictionary, sim = null) -> bool:
	if data.is_empty():
		return false
	clan_id = _clean_clan(String(data.get("clan", "brujah")))
	difficulty = String(data.get("difficulty", "normal"))
	day = max(1, int(data.get("day", 1)))
	clock = clamp(float(data.get("clock", NIGHT_START)), 0.0, 24.0)
	level = clamp(int(data.get("level", 1)), 1, MAX_LEVEL)
	xp = max(0, int(data.get("xp", 0)))
	xp_total = max(0, int(data.get("xp_total", xp)))
	elder_vitae = max(0, int(data.get("elder_vitae", 0)))
	elder_progress = clamp(float(data.get("elder_progress", 0.0)), 0.0, float(ELDER_XP))
	attributes = _clean_attributes(data.get("attributes", {}))
	attr_points = max(0, int(data.get("attr_points", 0)))
	skill_points = max(0, int(data.get("skill_points", 0)))
	tree_nodes = _clean_tree_nodes(data.get("tree_nodes", {}))
	known_powers = _clean_known_powers(data.get("known_powers", {}))
	slots = _clean_slots(data.get("slots", []))
	money = max(0, int(data.get("money", 0)))
	respecs = max(0, int(data.get("respecs", 0)))
	influence = maxf(0.0, float(data.get("influence", 3.0)))
	inventory = _clean_inventory(data.get("inventory", []))
	equipment = data.get("equipment", {}).duplicate(true) if data.get("equipment", {}) is Dictionary else {}
	next_item_id = max(1, int(data.get("next_item_id", 1)))
	haven = data.get("haven", {}).duplicate(true) if data.get("haven", {}) is Dictionary else {}
	reputation = data.get("reputation", {}).duplicate(true) if data.get("reputation", {}) is Dictionary else {}
	coterie = data.get("coterie", []).duplicate(true) if data.get("coterie", []) is Array else []
	next_coterie_id = max(1, int(data.get("next_coterie_id", 1)))
	domains = data.get("domains", {}).duplicate(true) if data.get("domains", {}) is Dictionary else {}
	district_state = data.get("district_state", {}).duplicate(true) if data.get("district_state", {}) is Dictionary else {}
	businesses = data.get("businesses", {}).duplicate(true) if data.get("businesses", {}) is Dictionary else {}
	active_mission = data.get("active_mission", {}).duplicate(true) if data.get("active_mission", {}) is Dictionary else {}
	mission_offers = data.get("mission_offers", []).duplicate(true) if data.get("mission_offers", []) is Array else []
	missions_done = max(0, int(data.get("missions_done", 0)))
	next_mission_id = max(1, int(data.get("next_mission_id", 1)))
	chain_progress = data.get("chain_progress", {}).duplicate(true) if data.get("chain_progress", {}) is Dictionary else {}
	chain_titles = data.get("chain_titles", {}).duplicate(true) if data.get("chain_titles", {}) is Dictionary else {}
	achievements = data.get("achievements", {}).duplicate(true) if data.get("achievements", {}) is Dictionary else {}
	stats = data.get("stats", {}).duplicate(true) if data.get("stats", {}) is Dictionary else {}
	_ensure_haven()
	_ensure_reputation()
	_ensure_domains()
	recompute()
	if sim != null:
		var runtime: Dictionary = data.get("runtime", {})
		if runtime.has("rng"):
			sim.rng = int(runtime["rng"])
		if runtime.has("tick"):
			sim.tick = int(runtime["tick"])
		if runtime.has("heat"):
			sim.heat = clamp(float(runtime["heat"]), 0.0, 6.0)
		if sim.player != null:
			if runtime.has("player_pos") and runtime["player_pos"] is Vector2:
				sim.player.pos = runtime["player_pos"]
			if runtime.has("player_hp"):
				sim.player.hp = clamp(float(runtime["player_hp"]), 0.0, sim.player.max_hp)
			if sim.player.behaviour != null:
				if runtime.has("blood"):
					sim.player.behaviour.set("blood", float(runtime["blood"]))
				if runtime.has("hunger"):
					sim.player.behaviour.set("hunger", float(runtime["hunger"]))
				if runtime.has("humanity"):
					sim.player.behaviour.set("humanity", float(runtime["humanity"]))
		apply_to_runtime(sim)
	return true

func state_hash() -> int:
	return hash([
		clan_id, difficulty, day, snapped(clock, 0.001), level, xp, xp_total,
		elder_vitae, snapped(elder_progress, 0.001), attr_points, skill_points,
		money, respecs, snapped(influence, 0.001), next_item_id,
		next_coterie_id, missions_done, next_mission_id, dawn_warning_sent,
		_hash_variant(attributes), _hash_variant(tree_nodes), _hash_variant(known_powers),
		_hash_variant(slots), _hash_variant(derived), _hash_variant(inventory),
		_hash_variant(equipment), _hash_variant(haven), _hash_variant(reputation),
		_hash_variant(coterie), _hash_variant(domains), _hash_variant(district_state),
		_hash_variant(businesses), _hash_variant(active_mission),
		_hash_variant(mission_offers), _hash_variant(chain_progress),
		_hash_variant(chain_titles), _hash_variant(achievements), _hash_variant(stats)
	])

static func new_attributes() -> Dictionary:
	return { "might": 1, "finesse": 1, "vitality": 1, "bloodcraft": 1, "wits": 1, "presence": 1 }

static func blank_mods() -> Dictionary:
	return { "add": {}, "pct": {} }

static func add_mods(dst: Dictionary, src) -> void:
	if not (src is Dictionary):
		return
	var bag: Dictionary = src
	if bag.has("add") and bag["add"] is Dictionary:
		for key in bag["add"]:
			dst["add"][key] = float(dst["add"].get(key, 0.0)) + float(bag["add"][key])
	if bag.has("pct") and bag["pct"] is Dictionary:
		for key in bag["pct"]:
			dst["pct"][key] = float(dst["pct"].get(key, 0.0)) + float(bag["pct"][key])

func aggregate_tree_mods() -> Dictionary:
	var out := blank_mods()
	for id in tree_nodes:
		var node: Dictionary = Catalog.SKILL_NODES.get(String(id), {})
		var rank := int(tree_nodes[id])
		if node.has("mods"):
			var scaled := _multiply_mods(node["mods"], float(rank))
			add_mods(out, scaled)
	return out

func aggregate_equipment_mods() -> Dictionary:
	var out := blank_mods()
	for key in equipment:
		var item = equipment[key]
		if item is Dictionary:
			add_mods(out, (item as Dictionary).get("mods", {}))
	return out

func aggregate_haven_mods() -> Dictionary:
	_ensure_haven()
	var out := blank_mods()
	for room_id in Catalog.HAVEN_ROOMS:
		var lv := int(haven["rooms"].get(room_id, 0))
		if lv <= 0:
			continue
		var room: Dictionary = Catalog.HAVEN_ROOMS[room_id]
		add_mods(out, _multiply_mods(room.get("mods_per_level", {}), float(lv)))
	return out

func aggregate_reputation_mods() -> Dictionary:
	_ensure_reputation()
	var out := blank_mods()
	var pos := 0.0
	for f in reputation:
		pos += maxf(0.0, float(reputation[f]))
	out["pct"]["discount"] = minf(0.18, pos / 1000.0)
	out["pct"]["xpMult"] = minf(0.10, pos / 2000.0)
	return out

func resolve_dawn(sim) -> void:
	var coterie_pay := collect_coterie_jobs()
	var domain_pay := collect_domain_tithe()
	var business_pay := _collect_businesses()
	var cash := int(coterie_pay["cash"]) + int(domain_pay["cash"]) + int(business_pay["cash"])
	var vitae := int(coterie_pay["vitae"]) + int(domain_pay["vitae"]) + int(business_pay["vitae"])
	money += cash
	deposit_vitae(float(vitae))
	day += 1
	clock = NIGHT_START
	dawn_warning_sent = false
	if sim.player != null:
		if sim.world == null or not sim.world.is_in_haven(sim.player.pos):
			var sun_damage := 38.0 * (1.0 - float(derived.get("sunResist", 0.0)))
			sim.damage_entity(null, sim.player, sun_damage, { "cue": "dawn.damage", "crit_chance": 0.0 })
			if sim.player.hp <= 0.0:
				sim.emit_cue("player.torpor", { "day": day, "pos": sim.player.pos })
	sim.reduce_heat(1.5, "dawn")
	sim.emit_cue("dawn.arrive", { "day": day, "cash": cash, "vitae": vitae, "clock": clock })

func _update_active_mission(delta: float, sim) -> void:
	if active_mission.is_empty() or String(active_mission.get("state", "")) != "active":
		return
	if float(active_mission.get("time_limit", 0.0)) > 0.0:
		active_mission["timer"] = maxf(0.0, float(active_mission.get("timer", 0.0)) - delta)
		if float(active_mission["timer"]) <= 0.0:
			fail_mission(sim, "Out of time.")

func _mission_progress(amount: int, sim) -> void:
	active_mission["progress"] = int(active_mission.get("progress", 0)) + amount
	sim.emit_cue("mission.progress", { "mission_id": active_mission.get("id", 0), "progress": active_mission["progress"], "need": active_mission.get("need", 1) })
	if int(active_mission["progress"]) >= int(active_mission.get("need", 1)):
		complete_mission(sim)

func _build_mission(type_id: String, sim = null) -> Dictionary:
	var def: Dictionary = Catalog.MISSION_TYPES[type_id]
	var need := 1
	match type_id:
		"feed", "collect":
			need = 3 + int(level / 8)
		"cleanse", "survive":
			need = 4 + int(level / 6)
	var modifier: Dictionary = Catalog.MISSION_MODIFIERS[_draw_index(sim, Catalog.MISSION_MODIFIERS.size())]
	var mission := {
		"id": next_mission_id,
		"type": type_id,
		"name": def["name"],
		"icon": def["icon"],
		"color": def["color"],
		"level": level,
		"need": need,
		"progress": 0,
		"state": "available",
		"targetName": _roll_name(sim),
		"modifier": modifier.duplicate(true),
		"reward": {
			"xp": roundi(float(def["base_xp"]) * (1.0 + float(level) * 0.12)),
			"money": roundi(float(def["base_money"]) * (1.0 + float(level) * 0.15)),
			"itemChance": 0.6,
		},
		"time_limit": 0.0,
		"timer": 0.0,
		"markers": [],
	}
	if type_id == "courier":
		mission["time_limit"] = 60.0 + float(level) * 1.5
		mission["timer"] = mission["time_limit"]
	next_mission_id += 1
	return mission

func _setup_mission(sim) -> void:
	var type_id := String(active_mission.get("type", ""))
	match type_id:
		"assassinate":
			var target: SimEntity = sim.spawn_npc("gunner", sim.world.nearest_open_around(sim.player.pos, 300.0, 760.0, next_mission_id), { "state": "wander", "hostile_to_player": false, "hp": 130.0 + float(level) * 8.0 })
			target.tags["mission_id"] = active_mission["id"]
			target.tags["mission_target"] = true
			active_mission["target_id"] = target.id
		"cleanse", "survive":
			for i in range(int(active_mission.get("need", 1))):
				var e: SimEntity = sim.spawn_npc("hunter" if level > 15 and i % 3 == 0 else "gunner", sim.world.nearest_open_around(sim.player.pos, 260.0, 820.0, i + next_mission_id), { "state": "wander", "hostile_to_player": true })
				e.tags["mission_id"] = active_mission["id"]
		"escort":
			var member := bind_coterie_member("courier", sim)
			active_mission["courier_member_id"] = member.get("id", 0)
		"heist":
			sim.add_heat(0.8, "mission")

func _collect_businesses() -> Dictionary:
	var cash := 0
	var vitae := 0
	for id in businesses:
		if not bool(businesses[id].get("owned", false)):
			continue
		var def: Dictionary = Catalog.BUSINESSES.get(String(id), {})
		var tier := int(businesses[id].get("tier", 0))
		var mult := 1.0 + float(tier) * 0.35
		cash += roundi(float(def.get("cash", 0)) * mult)
		vitae += roundi(float(def.get("vitae", 0)) * mult)
	return { "cash": cash, "vitae": vitae }

func _update_influence(delta: float) -> void:
	influence = minf(float(derived.get("influenceMax", 3.0)), influence + delta * 0.07)

func _ensure_haven() -> void:
	if haven.is_empty():
		haven = { "rooms": {}, "cellarVitae": 0.0 }
	if not haven.has("rooms") or not (haven["rooms"] is Dictionary):
		haven["rooms"] = {}
	for id in Catalog.HAVEN_ROOMS:
		if not haven["rooms"].has(id):
			haven["rooms"][id] = 0
	if not haven.has("cellarVitae"):
		haven["cellarVitae"] = 0.0

func _ensure_reputation() -> void:
	if reputation.is_empty():
		reputation = {}
	for f in Catalog.FACTIONS:
		if not reputation.has(f):
			reputation[f] = 0.0

func _ensure_domains() -> void:
	if domains.is_empty():
		domains = {}
	if district_state.is_empty():
		district_state = {}
	for d in Catalog.DISTRICTS:
		var id := String(d["id"])
		if not domains.has(id):
			domains[id] = { "owner": null, "contesting": false }
		if not district_state.has(id):
			district_state[id] = { "terror": 0.0, "prosperity": 0.0 }

func _inventory_index(item_id: int) -> int:
	for i in range(inventory.size()):
		if int(inventory[i].get("id", 0)) == item_id:
			return i
	return -1

func _draw_index(sim, count: int) -> int:
	if count <= 0:
		return 0
	return sim.draw_index(count) if sim != null else 0

func _draw_float(sim) -> float:
	return sim.draw_float() if sim != null else 0.0

func _roll_name(sim = null) -> String:
	return String(Catalog.FIRST_NAMES[_draw_index(sim, Catalog.FIRST_NAMES.size())]) + " " + String(Catalog.LAST_NAMES[_draw_index(sim, Catalog.LAST_NAMES.size())])

func _scale_mods(source, level_hint: int, mult: float) -> Dictionary:
	var out := blank_mods()
	if not (source is Dictionary):
		return out
	var src: Dictionary = source
	if src.has("add"):
		for key in src["add"]:
			out["add"][key] = float(src["add"][key]) * (1.0 + float(level_hint) * 0.05) * mult
	if src.has("pct"):
		for key in src["pct"]:
			out["pct"][key] = float(src["pct"][key]) * mult
	return out

func _affix_mods(affix: Dictionary, level_hint: int) -> Dictionary:
	var out := blank_mods()
	add_mods(out, affix.get("mods", {}))
	var scale: Dictionary = affix.get("scale", {})
	if scale.has("add"):
		for key in scale["add"]:
			out["add"][key] = float(out["add"].get(key, 0.0)) + float(scale["add"][key]) * float(level_hint)
	if scale.has("pct"):
		for key in scale["pct"]:
			out["pct"][key] = float(out["pct"].get(key, 0.0)) + float(scale["pct"][key]) * float(level_hint)
	return out

func _multiply_mods(source, amount: float) -> Dictionary:
	var out := blank_mods()
	if not (source is Dictionary):
		return out
	var src: Dictionary = source
	if src.has("add"):
		for key in src["add"]:
			out["add"][key] = float(src["add"][key]) * amount
	if src.has("pct"):
		for key in src["pct"]:
			out["pct"][key] = float(src["pct"][key]) * amount
	return out

func _clean_clan(value: String) -> String:
	var id := value.to_lower()
	return id if Catalog.CLAN_BOONS.has(id) else "brujah"

func _clean_attributes(source) -> Dictionary:
	var out := new_attributes()
	if source is Dictionary:
		for attr in out:
			out[attr] = clamp(int((source as Dictionary).get(attr, out[attr])), 1, 50)
	return out

func _clean_tree_nodes(source) -> Dictionary:
	var out := {}
	if source is Dictionary:
		for id in source:
			if Catalog.SKILL_NODES.has(String(id)):
				out[String(id)] = clamp(int(source[id]), 1, int(Catalog.SKILL_NODES[String(id)].get("maxRank", 1)))
	return out

func _clean_known_powers(source) -> Dictionary:
	var out := {}
	if source is Dictionary:
		for id in source:
			var power_id := Catalog.canonical_power_id(String(id))
			if bool(source[id]) and Catalog.POWERS.has(power_id):
				out[power_id] = true
	if out.is_empty():
		for id in ["cel_dash", "pot_slam", "for_mend", "obf_cloak", "aus_mark", "dom_mesmer", "pre_dread", "bs_bolt"]:
			out[id] = true
	return out

func _clean_slots(source) -> Array:
	var out: Array = [null, null, null, null, null, null, null, null]
	if source is Array:
		for i in range(min(8, (source as Array).size())):
			if source[i] == null:
				continue
			var id := Catalog.canonical_power_id(String(source[i]))
			if known_powers.has(id):
				out[i] = id
	return out

func _clean_inventory(source) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if source is Array:
		for item in source:
			if item is Dictionary and out.size() < 40:
				out.append((item as Dictionary).duplicate(true))
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
