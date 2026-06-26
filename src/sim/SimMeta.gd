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
const BUSINESS_MAX_TIER := 4

const LEGEND_TITLES := [
	{ "id": "fledgling", "name": "Fledgling", "min": 0, "domainCap": 1, "coterieCap": 0 },
	{ "id": "neonate", "name": "Neonate", "min": 30, "domainCap": 2, "coterieCap": 0 },
	{ "id": "anarch", "name": "Anarch", "min": 75, "domainCap": 3, "coterieCap": 1 },
	{ "id": "ancilla", "name": "Ancilla", "min": 150, "domainCap": 4, "coterieCap": 1 },
	{ "id": "baron", "name": "Baron", "min": 260, "domainCap": 5, "coterieCap": 2 },
	{ "id": "elder", "name": "Elder", "min": 420, "domainCap": 6, "coterieCap": 3 },
	{ "id": "prince", "name": "Prince of the City", "min": 650, "domainCap": 7, "coterieCap": 4 },
]

const PROGRESS_ORDER := [
	"move", "feed", "powers", "attributes", "pounce", "finisher", "missions",
	"vehicles", "havenUpgrade", "mastery", "reputation", "thralls", "legend",
	"domains", "businesses", "coterieJobs", "codex", "nemesis", "childer",
	"elder", "prestige", "alchemy",
]

const NEMESIS_SCARS := ["ash-burned", "fang-split", "blood-warded", "sun-scarred", "silver-pinned"]
const EVENT_DEFS := {
	"gangwar": { "weight": 3, "minStars": 0, "name": "Gang War" },
	"crackdown": { "weight": 2, "minStars": 2, "name": "Police Crackdown" },
	"bloodhunt": { "weight": 2, "minStars": 3, "name": "Blood Hunt" },
	"vip": { "weight": 2, "minStars": 0, "name": "Aristocrat Sighting" },
	"faint": { "weight": 2, "minStars": 0, "name": "Fainting Mortals" },
	"bounty": { "weight": 2, "minStars": 0, "name": "Bounty" },
	"domainraid": { "weight": 2, "minStars": 0, "name": "Rival Domain Raid", "needsDomain": true },
}
const MASTERY_CAP := 12
const MASTERY_TRACKS := {
	"predation": { "name": "Predation", "per": { "pct": { "feedYield": 0.02, "feedSpeed": 0.02 } } },
	"sorcery": { "name": "Hemomancy", "per": { "pct": { "spellPower": 0.025 } } },
	"brawn": { "name": "Brutality", "per": { "pct": { "meleeDmg": 0.025 } } },
	"survival": { "name": "Fortitude", "per": { "pct": { "maxHP": 0.02, "armor": 0.01 } } },
	"driving": { "name": "Road Reaver", "per": { "pct": { "vehicle": 0.03 } } },
	"nightstalker": { "name": "Nightstalker", "per": { "add": { "critChance": 1.0 }, "pct": { "moveSpeed": 0.01 } } },
}
const TROPHY_DEFS := {
	"hunter": { "name": "Hunter's Fang", "mod": { "pct": { "sunResist": 0.08 } }, "desc": "+8% sun resistance" },
	"inquis": { "name": "Inquisitor's Badge", "mod": { "pct": { "armor": 0.05 } }, "desc": "+5% armor" },
	"elder": { "name": "Elder's Skull", "mod": { "pct": { "maxHP": 0.08 } }, "desc": "+8% max HP" },
	"baron": { "name": "Baron's Sigil", "mod": { "pct": { "discount": 0.06, "maxBlood": 0.05 } }, "desc": "-6% prices, +5% vitae" },
	"nemesis": { "name": "Nemesis' Heart", "mod": { "pct": { "meleeDmg": 0.08, "spellPower": 0.08 } }, "desc": "+8% all damage" },
}
const CODEX_TOTALS := { "fedTypes": 6, "killedKinds": 5, "relicsSeen": 5, "districts": 4, "powers": 20 }
const CODEX_MODS := {
	"fedTypes": { "pct": { "feedYield": 0.10, "maxBlood": 0.05 } },
	"killedKinds": { "pct": { "meleeDmg": 0.08 } },
	"relicsSeen": { "pct": { "spellPower": 0.08, "meleeDmg": 0.08 } },
	"districts": { "pct": { "moveSpeed": 0.06 }, "add": { "critChance": 3.0 } },
	"powers": { "pct": { "cdr": 0.06 } },
}
const ALCHEMY_RECIPES := {
	"refine": { "inRarity": "common", "outRarity": "uncommon", "need": 3, "minWorkshop": 1 },
	"distill": { "inRarity": "uncommon", "outRarity": "rare", "need": 3, "minWorkshop": 2 },
	"sublime": { "inRarity": "rare", "outRarity": "epic", "need": 3, "minWorkshop": 3 },
	"extract": { "inRarity": "", "outRarity": "", "need": 1, "minWorkshop": 1 },
}
const EXTRACT_VITAE := { "common": 4, "uncommon": 10, "rare": 22, "epic": 48, "legendary": 100, "relic": 200 }

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
var achievement_check_ticks: int = 0
var stats: Dictionary = {}
var legend: int = 0
var progress: Dictionary = {}
var nemeses: Array[Dictionary] = []
var event_timer: float = 75.0
var active_events: Array[Dictionary] = []
var pending_raids: Array[Dictionary] = []
var next_event_id: int = 1
const ACTIVE_EVENT_CAP := 16
const PENDING_RAID_CAP := 8
var mastery: Dictionary = {}
var trophies: Dictionary = {}
var codex: Dictionary = {}
var bloodline: Dictionary = {}

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
	for id in ["cel_dash", "pot_slam", "for_mend", "obf_cloak", "obf_vanish", "aus_mark", "dom_mesmer", "pre_dread", "bs_bolt"]:
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
	achievement_check_ticks = 0
	legend = 0
	progress.clear()
	nemeses.clear()
	event_timer = 75.0
	active_events.clear()
	pending_raids.clear()
	next_event_id = 1
	mastery.clear()
	trophies.clear()
	codex.clear()
	bloodline = { "generation": 1, "bonus": 0.0, "ledger": [] }
	_ensure_mastery()
	_ensure_codex()
	stats = {
		"kills": 0,
		"feeds": 0,
		"castsTotal": 0,
		"hijacks": 0,
		"bodiesCarried": 0,
		"bodiesDumped": 0,
		"bodiesFound": 0,
		"businessesBought": 0,
		"businessesUpgraded": 0,
		"domainsClaimed": 0,
		"nemesisEscapes": 0,
		"nemesisKills": 0,
		"bounties": 0,
		"thralls": 0,
		"clearedFiveHeat": 0,
	}
	progress_reveal("move", null, true)
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
	_update_event_director(delta, sim)
	progress_check(sim)
	_update_achievements(sim)

func recompute() -> Dictionary:
	var a := attributes
	var bp := blood_potency(level)
	var bag := blank_mods()
	add_mods(bag, aggregate_tree_mods())
	add_mods(bag, aggregate_equipment_mods())
	add_mods(bag, aggregate_haven_mods())
	add_mods(bag, aggregate_reputation_mods())
	add_mods(bag, aggregate_mastery_mods())
	add_mods(bag, aggregate_trophy_mods())
	add_mods(bag, aggregate_codex_mods())
	add_mods(bag, aggregate_bloodline_mods())
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
		_apply_power_upgrade(level, sim)
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

# Leveling visibly UPGRADES your kit — a stronger power replaces a starting slot. The hotbar
# (which reads `slots`) updates automatically, so levelling changes how the game plays.
const POWER_UPGRADES := {
	3: [1, "pot_quake"],    # slot 2: Earthshock -> Earthquake (bigger quake)
	4: [7, "bs_storm"],     # slot 8: Blood Bolt -> Blood Storm (a salvo)
	5: [0, "cel_flurry"],   # slot 1: Quicken -> Celerity Flurry
	6: [4, "aus_premon"],   # slot 5: Aura -> Premonition
	8: [6, "pre_majesty"],  # slot 7: Dread Gaze -> Majesty
}


func _apply_power_upgrade(lv: int, sim) -> void:
	if not POWER_UPGRADES.has(lv):
		return
	var u: Array = POWER_UPGRADES[lv]
	var slot_idx: int = int(u[0])
	var pid: String = String(u[1])
	if slot_idx < 0 or slot_idx >= slots.size() or not Catalog.POWERS.has(pid):
		return
	learn_power(pid)
	slots[slot_idx] = pid
	if sim != null:
		sim.emit_cue("power.unlocked", { "power_id": pid, "slot": slot_idx + 1, "name": Catalog.POWERS[pid].get("name", pid) })


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

# ---------------------------------------------------------------------------------------------
# CLAN KEYSTONES (B13) — the three slice clans play differently at the VERB level. Each keystone
# below is a real RUNTIME RULE-CHANGE (like bs_key halving cost in effective_power_cost), not a
# stat node. The action paths (SimPlayer.cast_power / _try_attack / feed verdict, Sim damage/CC)
# READ these deterministic predicates and change behaviour. A keystone is "owned" when its node
# is allocated in the tree (tree_nodes) AND the player is of that clan — clan identity is the gate
# so the keystone is genuinely a clan signature, not a generic node. All pure tree/clan reads:
# nothing here touches the RNG, the clock, or state_hash, so determinism is preserved.

const BLOOD_RAGE_DAMAGE_MULT := 1.40   # Brujah pot_key: +40% melee while raging
const BLOOD_RAGE_UPKEEP := 1.8         # vitae/sec drained as the cost of holding the Beast open
const SHADOW_KILL_CLOAK_TICKS := 120   # Nosferatu obf_key: ~2s cloaked after a stealth feed-kill

func has_keystone(node_id: String) -> bool:
	return int(tree_nodes.get(node_id, 0)) > 0

# --- Brujah BLOOD RAGE (pot_key): frenzy is an opt-in brawl mode. Raging trades the discipline
#     hotbar + a vitae drip for a damage multiplier and crowd-control immunity. ----------------
func blood_rage_unlocked() -> bool:
	return clan_id == "brujah" and has_keystone("pot_key")

## TRUE only while the keystone is owned AND the Beast is loose. The attack/CC paths read this.
func blood_rage_active(frenzied: bool) -> bool:
	return frenzied and blood_rage_unlocked()

## Melee multiplier applied on top of derived meleeDmg while raging (1.0 otherwise). Read in the
## damage path. Deterministic constant — no draw.
func blood_rage_damage_mult(frenzied: bool) -> float:
	return BLOOD_RAGE_DAMAGE_MULT if blood_rage_active(frenzied) else 1.0

## While raging, the Brujah ignores stun/fear/knockback — read by apply_status / mesmerize / fear.
func blood_rage_cc_immune(frenzied: bool) -> bool:
	return blood_rage_active(frenzied)

## The cost side of the toggle: raging blocks Disciplines (the cast verb refuses) and drips vitae.
## cast_power reads blood_rage_blocks_disciplines(); _tick_buffs/_update_frenzy reads the upkeep.
func blood_rage_blocks_disciplines(frenzied: bool) -> bool:
	return blood_rage_active(frenzied)

func blood_rage_upkeep(frenzied: bool) -> float:
	return BLOOD_RAGE_UPKEEP if blood_rage_active(frenzied) else 0.0

# --- Nosferatu ONE WITH SHADOW (obf_key): a stealth feed-kill keeps you cloaked instead of
#     breaking it. The feed-kill verdict reads keeps_cloak_on_kill() and, if true, re-arms cloak
#     for shadow_kill_cloak_ticks() instead of clearing it. -------------------------------------
func stealth_kill_keeps_cloak() -> bool:
	return clan_id == "nosferatu" and has_keystone("obf_key")

func shadow_kill_cloak_ticks() -> int:
	return SHADOW_KILL_CLOAK_TICKS if stealth_kill_keeps_cloak() else 0

# --- Tremere VITAE ALCHEMY (bs_key): blood costs are already halved in effective_power_cost.
#     This rule lets the cast verb proceed when vitae is short by paying the shortfall as
#     aggravated HP — "the other half drains from HP". cast_power reads cast_hp_shortfall():
#     if blood < cost but blood + that HP can cover it, deduct the blood it has, deal the rest as
#     aggravated HP, and allow the cast. Pure arithmetic on the (already keystone-discounted) cost.
func cast_from_hp_unlocked() -> bool:
	return clan_id == "tremere" and has_keystone("bs_key")

## HP (aggravated) to pay so a cast can fire when vitae is short. 0 when the rule is off, when
## blood already covers the cost, or when even HP can't (the caller still gates lethality).
func cast_hp_shortfall(power_id: String, available_blood: float) -> float:
	if not cast_from_hp_unlocked():
		return 0.0
	var cost := effective_power_cost(power_id)
	if available_blood >= cost:
		return 0.0
	return maxf(0.0, cost - maxf(0.0, available_blood))

func respec_tree(sim = null) -> int:
	var refund := 0
	for id in tree_nodes:
		refund += int(tree_nodes[id])
	tree_nodes.clear()
	skill_points += refund
	known_powers.clear()
	for id in ["cel_dash", "pot_slam", "for_mend", "obf_cloak", "obf_vanish", "aus_mark", "dom_mesmer", "pre_dread", "bs_bolt"]:
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

func legend_title() -> Dictionary:
	var best: Dictionary = (LEGEND_TITLES[0] as Dictionary)
	for title in LEGEND_TITLES:
		var rec: Dictionary = title
		if legend >= int(rec["min"]):
			best = rec
	return best.duplicate(true)

func legend_domain_cap() -> int:
	return int(legend_title().get("domainCap", 1))

func legend_coterie_cap() -> int:
	return int(legend_title().get("coterieCap", 0))

func add_legend(amount: int, sim = null, reason: String = "") -> void:
	if amount <= 0:
		return
	var before_title := String(legend_title().get("id", "fledgling"))
	legend += amount
	var after_title := legend_title()
	if sim != null:
		sim.emit_cue("legend.changed", { "legend": legend, "amount": amount, "reason": reason, "title": after_title.duplicate(true) })
		if String(after_title.get("id", "")) != before_title:
			sim.emit_cue("legend.title", { "legend": legend, "title": after_title.duplicate(true) })
	progress_reveal("legend", sim)

func owned_domain_count() -> int:
	_ensure_domains()
	var count := 0
	for id in domains:
		if domains[id].get("owner", null) == "player":
			count += 1
	return count

func business_cost(business_id: String) -> int:
	var def: Dictionary = Catalog.BUSINESSES.get(business_id, {})
	return int(def.get("cost", 0))

func business_upgrade_cost(business_id: String) -> int:
	var def: Dictionary = Catalog.BUSINESSES.get(business_id, {})
	var tier := int(businesses.get(business_id, {}).get("tier", 0))
	return roundi(float(def.get("cost", 0)) * 0.6 * float(tier + 1))

func buy_business(business_id: String, sim = null) -> bool:
	if not Catalog.BUSINESSES.has(business_id):
		return false
	if bool(businesses.get(business_id, {}).get("owned", false)):
		return upgrade_business(business_id, sim)
	var cost := business_cost(business_id)
	if money < cost:
		return false
	money -= cost
	businesses[business_id] = { "owned": true, "tier": 0, "bought_day": day }
	stats["businessesBought"] = int(stats.get("businessesBought", 0)) + 1
	add_legend(4, sim, "business")
	progress_reveal("businesses", sim)
	if sim != null:
		sim.emit_cue("business.bought", { "business_id": business_id, "cost": cost, "money": money, "tier": 0 })
	return true

func upgrade_business(business_id: String, sim = null) -> bool:
	if not Catalog.BUSINESSES.has(business_id):
		return false
	if not bool(businesses.get(business_id, {}).get("owned", false)):
		return false
	var tier := int(businesses[business_id].get("tier", 0))
	if tier >= BUSINESS_MAX_TIER:
		return false
	var cost := business_upgrade_cost(business_id)
	if money < cost:
		return false
	money -= cost
	businesses[business_id]["tier"] = tier + 1
	businesses[business_id]["upgraded_day"] = day
	stats["businessesUpgraded"] = int(stats.get("businessesUpgraded", 0)) + 1
	add_legend(2 + tier, sim, "business_upgrade")
	if sim != null:
		sim.emit_cue("business.upgraded", { "business_id": business_id, "cost": cost, "money": money, "tier": tier + 1 })
	return true

func collect_business_income() -> Dictionary:
	return _collect_businesses()

func coterie_cap() -> int:
	_ensure_haven()
	var base := 3 + int(haven["rooms"].get("barracks", 0)) + (1 if int(attributes.get("presence", 1)) > 6 else 0)
	return max(base, legend_coterie_cap())

func bind_coterie_member(archetype: String, sim = null, childe: bool = false) -> Dictionary:
	if coterie.size() >= min(12, coterie_cap()):
		if sim != null:
			sim.emit_cue("coterie.blocked", { "reason": "cap", "cap": coterie_cap() })
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
	if not childe:
		stats["thralls"] = int(stats.get("thralls", 0)) + 1
	if sim != null:
		sim.emit_cue("coterie.bound", member.duplicate(true))
	progress_reveal("childer" if childe else "thralls", sim)
	return member

func assign_coterie(member_id: int, job_id: String, sim = null) -> bool:
	if not Catalog.COTERIE_JOBS.has(job_id):
		return false
	for i in range(coterie.size()):
		if int(coterie[i].get("id", 0)) == member_id:
			coterie[i]["assignment"] = job_id
			if sim != null:
				sim.emit_cue("coterie.assigned", { "member_id": member_id, "job_id": job_id })
			progress_reveal("coterieJobs", sim)
			return true
	return false

func summon_coterie(member_id: int, sim) -> SimEntity:
	if sim == null or sim.player == null:
		return null
	for member in coterie:
		if int(member.get("id", 0)) != member_id:
			continue
		if String(member.get("assignment", "none")) != "none":
			if sim != null:
				sim.emit_cue("coterie.summon_failed", { "member_id": member_id, "reason": "assigned" })
			return null
		for e in sim.entities:
			if e != null and not e.dead and int(e.tags.get("coterie_id", 0)) == member_id:
				sim.emit_cue("coterie.summon_failed", { "member_id": member_id, "reason": "already_active" })
				return null
		if _active_coterie_count(sim) >= coterie_cap():
			sim.emit_cue("coterie.summon_failed", { "member_id": member_id, "reason": "active_cap", "cap": coterie_cap() })
			return null
		var level_i := int(member.get("level", 1))
		var is_childe := bool(member.get("isChilde", false))
		var pos: Vector2 = sim.world.nearest_open_around(sim.player.pos, 28.0, 82.0, member_id + next_coterie_id)
		var ally: SimEntity = sim.spawn_npc("thrall", pos, {
			"state": "follow",
			"hostile_to_player": false,
			"hp": (70.0 + float(level_i) * 18.0) * (1.6 if is_childe else 1.0),
		})
		ally.faction = "player"
		ally.hostile_to_player = false
		ally.ai_state = "follow"
		ally.tags["coterie_id"] = member_id
		ally.tags["coterie_name"] = String(member.get("name", "Thrall"))
		ally.tags["childe"] = is_childe
		ally.attack_damage *= (1.40 if is_childe else 1.0) + float(level_i) * 0.08
		if is_childe:
			ally.tags["weapon"] = "rifle"
		sim.emit_cue("coterie.summoned", { "member_id": member_id, "entity_id": ally.id, "name": ally.tags["coterie_name"], "pos": ally.pos, "childe": is_childe })
		return ally
	return null

func coterie_ally_kill(ally: SimEntity, sim = null) -> bool:
	if ally == null or not ally.tags.has("coterie_id"):
		return false
	var member_id := int(ally.tags["coterie_id"])
	for i in range(coterie.size()):
		if int(coterie[i].get("id", 0)) != member_id:
			continue
		var gain := 8
		coterie[i]["xp"] = int(coterie[i].get("xp", 0)) + gain
		var need: int = max(40, int(coterie[i].get("level", 1)) * 40)
		if int(coterie[i]["xp"]) >= need:
			coterie[i]["xp"] = int(coterie[i]["xp"]) - need
			coterie[i]["level"] = int(coterie[i].get("level", 1)) + 1
			coterie[i]["loyalty"] = min(100, int(coterie[i].get("loyalty", 50)) + 5)
			if sim != null:
				sim.emit_cue("coterie.level_up", { "member_id": member_id, "level": coterie[i]["level"], "name": coterie[i].get("name", "") })
		elif sim != null:
			sim.emit_cue("coterie.xp", { "member_id": member_id, "xp": coterie[i]["xp"], "gain": gain })
		return true
	return false

func can_embrace(target: SimEntity, sim) -> bool:
	if target == null or sim == null or sim.player == null or sim.player.behaviour == null:
		return false
	var quality := target.victim_type in ["noble", "athlete", "hunter", "cop"] or target.type_id in ["hunter", "cop", "swat"]
	return legend >= 260 and quality and float(sim.player.behaviour.get("blood")) >= 60.0

func embrace(target_id: int, sim) -> Dictionary:
	var target: SimEntity = sim.get_entity(target_id) if sim != null else null
	if not can_embrace(target, sim):
		if sim != null:
			sim.emit_cue("coterie.embrace_failed", { "target_id": target_id, "legend": legend })
		return {}
	var blood := float(sim.player.behaviour.get("blood"))
	sim.player.behaviour.set("blood", blood - 60.0)
	var member := bind_coterie_member("childe", sim, true)
	if member.is_empty():
		sim.player.behaviour.set("blood", blood)
		return {}
	target.dead = true
	target.tags["embraced"] = true
	stats["childer"] = int(stats.get("childer", 0)) + 1
	sim.add_heat(1.0, "embrace")
	add_legend(15, sim, "embrace")
	progress_reveal("childer", sim)
	sim.emit_cue("coterie.embraced", { "member": member.duplicate(true), "target_id": target.id, "pos": target.pos })
	return member

func collect_coterie_jobs() -> Dictionary:
	var cash := 0
	var vitae := 0
	for member in coterie:
		var job: Dictionary = Catalog.COTERIE_JOBS.get(String(member.get("assignment", "none")), {})
		var mult := 1.0 + float(member.get("level", 1)) * 0.15 + float(member.get("loyalty", 50)) * 0.004
		cash += roundi(float(job.get("cash", 0)) * mult)
		vitae += roundi(float(job.get("vitae", 0)) * mult)
	return { "cash": cash, "vitae": vitae }

func collect_coterie_wages() -> Dictionary:
	var vitae := 0
	for member in coterie:
		vitae += 14 if bool(member.get("isChilde", false)) else 6
	return { "cash": 0, "vitae": vitae }

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
	if owned_domain_count() >= legend_domain_cap():
		if sim != null:
			sim.emit_cue("domain.blocked", { "domain_id": domain_id, "reason": "legend_cap", "cap": legend_domain_cap(), "legend": legend })
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
	if domains[domain_id].get("owner", null) == "player":
		return false
	if domains[domain_id].get("owner", null) != "player" and owned_domain_count() >= legend_domain_cap():
		if sim != null:
			sim.emit_cue("domain.blocked", { "domain_id": domain_id, "reason": "legend_cap", "cap": legend_domain_cap(), "legend": legend })
		return false
	domains[domain_id]["owner"] = "player"
	domains[domain_id]["contesting"] = false
	district_state[domain_id]["prosperity"] = 1.0
	district_state[domain_id]["terror"] = 0.0
	stats["domainsClaimed"] = int(stats.get("domainsClaimed", 0)) + 1
	add_legend(18, sim, "domain")
	progress_reveal("domains", sim)
	change_reputation("anarch", 8.0, sim)
	if sim != null:
		sim.emit_cue("domain.claimed", { "domain_id": domain_id, "owned": owned_domain_count(), "cap": legend_domain_cap() })
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
	if event_id == "feed.spare" or event_id == "feed.kill":
		stats["feeds"] = int(stats.get("feeds", 0)) + 1
		progress_reveal("feed", sim)
		gain_mastery("predation", 6.0, sim)
		if data.has("target_id") and sim != null:
			var feed_target: SimEntity = sim.get_entity(int(data["target_id"]))
			if feed_target != null:
				codex_mark("fedTypes", feed_target.victim_type if feed_target.victim_type != "" else feed_target.type_id, sim)
	elif event_id == "npc.death":
		stats["kills"] = int(stats.get("kills", 0)) + 1
		if bool(data.get("finisher", false)):
			progress_reveal("finisher", sim)
	elif event_id == "power.cast":
		stats["castsTotal"] = int(stats.get("castsTotal", 0)) + 1
		progress_reveal("powers", sim)
		codex_mark("powers", String(data.get("power_id", "")), sim)
		var power_id := String(data.get("power_id", ""))
		if power_id.begins_with("bs_") or power_id.begins_with("shd_") or power_id.begins_with("dem_"):
			gain_mastery("sorcery", 4.0, sim)
	if active_mission.is_empty() or String(active_mission.get("state", "")) != "active":
		return
	var type_id := String(active_mission["type"])
	if event_id == "feed.spare" or event_id == "feed.kill":
		if type_id == "feed":
			_mission_progress(1, sim)
	if event_id == "npc.death":
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
	add_legend(6 + int(active_mission.get("level", level)) / 4, sim, "mission")
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

func progress_reveal(progress_id: String, sim = null, silent: bool = false) -> bool:
	if progress_id == "" or not PROGRESS_ORDER.has(progress_id):
		return false
	if progress.has(progress_id) and bool(progress[progress_id].get("revealed", false)):
		return false
	progress[progress_id] = {
		"revealed": true,
		"seen": false,
		"order": PROGRESS_ORDER.find(progress_id),
		"tick": sim.tick if sim != null else 0,
	}
	if sim != null and not silent:
		sim.emit_cue("progress.revealed", { "id": progress_id, "order": progress[progress_id]["order"] })
	return true

func progress_is_revealed(progress_id: String) -> bool:
	return bool(progress.get(progress_id, {}).get("revealed", false))

func progress_mark_seen(progress_id: String) -> bool:
	if not progress.has(progress_id):
		return false
	progress[progress_id]["seen"] = true
	return true

func progress_check(sim = null) -> void:
	progress_reveal("move", sim, true)
	if level > 1 or attr_points > 0:
		progress_reveal("attributes", sim)
	if int(stats.get("feeds", 0)) > 0:
		progress_reveal("feed", sim)
	if int(stats.get("castsTotal", 0)) > 0:
		progress_reveal("powers", sim)
	if int(stats.get("hijacks", 0)) > 0:
		progress_reveal("vehicles", sim)
	if active_mission.size() > 0 or missions_done > 0:
		progress_reveal("missions", sim)
	if missions_done > 0 or level >= 10:
		progress_reveal("mastery", sim)
	if _has_any_haven_upgrade():
		progress_reveal("havenUpgrade", sim)
	if _has_any_reputation():
		progress_reveal("reputation", sim)
	if coterie.size() > 0:
		progress_reveal("thralls", sim)
	if legend > 0:
		progress_reveal("legend", sim)
	if owned_domain_count() > 0:
		progress_reveal("domains", sim)
	if _owned_business_count() > 0:
		progress_reveal("businesses", sim)
	if _has_any_coterie_job():
		progress_reveal("coterieJobs", sim)
	if not nemeses.is_empty():
		progress_reveal("nemesis", sim)
	if elder_vitae > 0 or level >= MAX_LEVEL:
		progress_reveal("elder", sim)

func check_achievements(sim = null) -> Array[String]:
	var unlocked: Array[String] = []
	for def in Catalog.ACHIEVEMENTS:
		var id := String(def.get("id", ""))
		if id == "" or achievements.has(id):
			continue
		if _achievement_met(def, sim) and unlock_achievement(id, sim):
			unlocked.append(id)
	return unlocked

func unlock_achievement(achievement_id: String, sim = null) -> bool:
	if achievement_id == "" or achievements.has(achievement_id):
		return false
	var def := _achievement_def(achievement_id)
	if def.is_empty():
		return false
	achievements[achievement_id] = 1
	skill_points += 1
	if sim != null:
		sim.emit_cue("achievement.unlocked", {
			"id": achievement_id,
			"name": def.get("name", achievement_id),
			"desc": def.get("desc", ""),
			"skill_points": skill_points,
		})
	return true

func _update_achievements(sim = null) -> void:
	achievement_check_ticks -= 1
	if achievement_check_ticks > 0:
		return
	achievement_check_ticks = 60
	check_achievements(sim)

func _achievement_def(achievement_id: String) -> Dictionary:
	for def in Catalog.ACHIEVEMENTS:
		if String(def.get("id", "")) == achievement_id:
			return (def as Dictionary).duplicate(true)
	return {}

func _achievement_met(def: Dictionary, sim = null) -> bool:
	if def.has("stat") and int(stats.get(String(def["stat"]), 0)) < int(def.get("min", 1)):
		return false
	if def.has("level") and level < int(def["level"]):
		return false
	if def.has("known_powers") and known_powers.size() < int(def["known_powers"]):
		return false
	if def.has("money") and money < int(def["money"]):
		return false
	if def.has("missions_done") and missions_done < int(def["missions_done"]):
		return false
	if def.has("min_humanity") and _player_humanity(sim) < float(def["min_humanity"]):
		return false
	if def.has("max_humanity") and _player_humanity(sim) > float(def["max_humanity"]):
		return false
	return true

func _player_humanity(sim = null) -> float:
	if sim != null and sim.player != null and sim.player.behaviour != null:
		return float(sim.player.behaviour.get("humanity"))
	return 10.0

func try_nemesis_escape(target: SimEntity, sim, opts: Dictionary = {}) -> bool:
	if target == null or sim == null:
		return false
	if bool(opts.get("no_nemesis", false)) or bool(target.tags.get("no_nemesis", false)):
		return false
	if target.tags.has("baron_of"):
		return false
	if target.tags.has("nemesis_name"):
		return false
	if not (target.faction == "inquis" or target.type_id in ["hunter", "elder"]):
		return false
	# B14: the slice's herald (sire's hunter / tutorial boss) is the player's FIRST named foe — it
	# ALWAYS flees its first defeat. Tagging the spawned entity tags["herald"]=true (done by the
	# slice spawn) is the whole "trigger" — the rule (force + telegraphed exit) lives here.
	var is_herald := bool(target.tags.get("herald", false))
	var force := is_herald or bool(opts.get("force_nemesis", false)) or bool(target.tags.get("force_nemesis", false))
	if not force and _draw_float(sim) >= 0.40:
		return false
	var dtype := String(opts.get("damage_type", opts.get("dmgType", "physical")))
	var rank := int(target.tags.get("nemesis_rank", 0)) + 1
	var rec := {
		"name": String(target.tags.get("name", _roll_name(sim))),
		"rank": rank,
		"scar": NEMESIS_SCARS[_draw_index(sim, NEMESIS_SCARS.size())],
		"resistType": dtype,
		"archetype": target.type_id,
		"escaped_tick": sim.tick,
	}
	nemeses.append(rec)
	while nemeses.size() > 3:
		nemeses.pop_front()
	target.hp = maxf(1.0, target.max_hp * 0.35)
	target.dead = false
	target.downed = false
	target.ai_state = "flee"
	target.perception_state = "retreating"
	target.hostile_to_player = false
	target.tags["nemesis_escaped"] = true
	target.tags["no_body"] = true
	# Telegraphed exit: flag the flee so presentation paints a legible "they're getting away" exit
	# (a marker / bark) and the herald can be lured toward the dawn sun-patch instead of just blinking out.
	target.tags["telegraph_exit"] = true
	target.tags["flee_from"] = sim.player.pos if sim.player != null else target.pos
	if is_herald:
		target.tags["herald_fled"] = true
	stats["nemesisEscapes"] = int(stats.get("nemesisEscapes", 0)) + 1
	add_legend(8 + rank * 2, sim, "nemesis_escape")
	progress_reveal("nemesis", sim)
	sim.emit_cue("nemesis.escaped", { "name": rec["name"], "rank": rank, "scar": rec["scar"], "resistType": dtype, "entity_id": target.id, "pos": target.pos, "herald": is_herald })
	return true

## B14 trigger — call from the damage path BEFORE lethality: when the herald is wounded past a
## threshold (default 35% HP) it flees scarred while still alive, rather than waiting for a killing
## blow. Returns true once it has fired (one-shot, guarded by the herald_fled tag so repeated hits
## don't re-trigger). Deterministic: try_nemesis_escape's only draws are name/scar rolls.
func wound_herald_to_flee(target: SimEntity, sim, opts: Dictionary = {}) -> bool:
	if target == null or sim == null or target.dead:
		return false
	if not bool(target.tags.get("herald", false)):
		return false
	if bool(target.tags.get("herald_fled", false)) or target.tags.has("nemesis_name"):
		return false
	var threshold := float(opts.get("flee_at_pct", 0.35))
	if target.max_hp <= 0.0 or target.hp > target.max_hp * threshold:
		return false
	var flee_opts := opts.duplicate(true)
	flee_opts["force_nemesis"] = true
	return try_nemesis_escape(target, sim, flee_opts)

func maybe_inject_nemesis(sim) -> SimEntity:
	if sim == null or nemeses.is_empty():
		return null
	var rec: Dictionary = nemeses[0]
	var rank: int = max(1, int(rec.get("rank", 1)))
	var resist_type := String(rec.get("resistType", "physical"))
	var resist_amount := minf(0.75, 0.22 + float(rank) * 0.08)
	var pos: Vector2 = sim.world.nearest_open_around(sim.player.pos, 240.0, 760.0, sim.draw_index(997) + rank * 31)
	var nemesis: SimEntity = sim.spawn_npc("hunter", pos, {
		"state": "chase",
		"hostile_to_player": true,
		"hp": 220.0 + float(rank) * 60.0 + float(level) * 8.0,
		"resist": { resist_type: resist_amount },
	})
	nemesis.tags["nemesis_name"] = String(rec.get("name", "The Hunter"))
	nemesis.tags["nemesis_rank"] = rank
	nemesis.tags["nemesis_scar"] = String(rec.get("scar", "scarred"))
	nemesis.tags["warded_mind"] = true
	nemesis.tags["native_warded_mind"] = true
	nemesis.armor = minf(0.65, nemesis.armor + 0.06 * float(rank))
	nemesis.attack_damage *= 1.0 + float(rank) * 0.12
	if nemesis.behaviour != null:
		nemesis.behaviour.set("speed", float(nemesis.behaviour.get("speed")) * (1.0 + float(rank) * 0.04))
	rec["rank"] = rank + 1
	rec["returned_tick"] = sim.tick
	nemeses[0] = rec
	sim.emit_cue("nemesis.return", { "name": nemesis.tags["nemesis_name"], "rank": rank, "entity_id": nemesis.id, "pos": nemesis.pos, "resistType": resist_type })
	return nemesis

func on_nemesis_dead(target: SimEntity, sim = null) -> void:
	if target == null:
		return
	var name := String(target.tags.get("nemesis_name", ""))
	for i in range(nemeses.size() - 1, -1, -1):
		if String(nemeses[i].get("name", "")) == name:
			nemeses.remove_at(i)
	stats["nemesisKills"] = int(stats.get("nemesisKills", 0)) + 1
	add_legend(20 + int(target.tags.get("nemesis_rank", 1)) * 4, sim, "nemesis_kill")
	if sim != null:
		sim.emit_cue("nemesis.dead", { "name": name, "entity_id": target.id, "pos": target.pos })

func claim_bounty(target: SimEntity, sim = null) -> bool:
	if target == null or not target.tags.has("bounty"):
		return false
	var amount: int = max(0, int(target.tags.get("bounty", 0)))
	if amount <= 0:
		return false
	target.tags.erase("bounty")
	money += amount
	stats["bounties"] = int(stats.get("bounties", 0)) + 1
	add_legend(5 + int(amount / 100), sim, "bounty")
	if sim != null:
		sim.emit_cue("bounty.claimed", { "entity_id": target.id, "amount": amount, "money": money, "pos": target.pos })
	return true

func mastery_rank_for(xp_amount: float) -> int:
	return min(MASTERY_CAP, floori(sqrt(maxf(0.0, xp_amount) / 28.0)))

func gain_mastery(track_id: String, amount: float, sim = null) -> bool:
	if not MASTERY_TRACKS.has(track_id) or amount <= 0.0:
		return false
	_ensure_mastery()
	var rec: Dictionary = mastery[track_id]
	rec["xp"] = float(rec.get("xp", 0.0)) + amount
	var next_rank := mastery_rank_for(float(rec["xp"]))
	var ranked := next_rank > int(rec.get("rank", 0))
	if ranked:
		rec["rank"] = next_rank
	mastery[track_id] = rec
	if ranked:
		recompute()
		if sim != null:
			apply_to_runtime(sim)
			sim.emit_cue("mastery.rank", { "track_id": track_id, "rank": next_rank, "name": MASTERY_TRACKS[track_id].get("name", track_id) })
		progress_reveal("mastery", sim)
	return ranked

func award_trophy_for(target: SimEntity, sim = null) -> bool:
	var key := _trophy_key_for(target)
	if key == "" or trophies.has(key):
		return false
	var def: Dictionary = TROPHY_DEFS[key]
	trophies[key] = { "id": key, "name": def["name"], "desc": def["desc"] }
	add_legend(4, sim, "trophy")
	recompute()
	if sim != null:
		apply_to_runtime(sim)
		sim.emit_cue("trophy.awarded", { "id": key, "name": def["name"], "desc": def["desc"], "target_id": target.id if target != null else 0 })
	return true

func codex_mark(category: String, key: String, sim = null) -> bool:
	if key == "" or not CODEX_TOTALS.has(category):
		return false
	_ensure_codex()
	if bool(codex[category].get(key, false)):
		return false
	codex[category][key] = true
	var completed := _codex_check_complete(category, sim)
	if sim != null:
		sim.emit_cue("codex.marked", { "category": category, "key": key, "count": codex[category].size(), "complete": completed })
	progress_reveal("codex", sim)
	return true

func alchemy_available() -> Array[String]:
	_ensure_haven()
	var workshop := int(haven.get("rooms", {}).get("workshop", 0))
	var out: Array[String] = []
	var ids := ALCHEMY_RECIPES.keys()
	ids.sort()
	for id in ids:
		if workshop >= int(ALCHEMY_RECIPES[id].get("minWorkshop", 1)):
			out.append(String(id))
	return out

func alchemy_input_count(recipe_id: String) -> int:
	if not ALCHEMY_RECIPES.has(recipe_id):
		return 0
	var recipe: Dictionary = ALCHEMY_RECIPES[recipe_id]
	if recipe_id == "extract":
		return inventory.size()
	var count := 0
	for item in inventory:
		if String(item.get("rarity", "common")) == String(recipe.get("inRarity", "")):
			count += 1
	return count

func alchemy_brew(recipe_id: String, sim = null) -> bool:
	_ensure_haven()
	if not ALCHEMY_RECIPES.has(recipe_id) or not alchemy_available().has(recipe_id):
		return false
	var recipe: Dictionary = ALCHEMY_RECIPES[recipe_id]
	if recipe_id == "extract":
		if inventory.is_empty():
			return false
		var cheapest_idx := 0
		var cheapest_value := sell_value(inventory[0])
		for i in range(1, inventory.size()):
			var value := sell_value(inventory[i])
			if value < cheapest_value:
				cheapest_value = value
				cheapest_idx = i
		var item: Dictionary = inventory[cheapest_idx]
		var vitae := int(EXTRACT_VITAE.get(String(item.get("rarity", "common")), 4))
		inventory.remove_at(cheapest_idx)
		deposit_vitae(float(vitae))
		if sim != null:
			sim.emit_cue("alchemy.extracted", { "item": item.get("name", ""), "vitae": vitae })
		return true
	var need := int(recipe.get("need", 3))
	if alchemy_input_count(recipe_id) < need:
		return false
	var removed := 0
	for i in range(inventory.size() - 1, -1, -1):
		if removed >= need:
			break
		if String(inventory[i].get("rarity", "common")) == String(recipe.get("inRarity", "")):
			inventory.remove_at(i)
			removed += 1
	var out_item := generate_item(level, String(recipe.get("outRarity", "uncommon")), "", sim)
	add_item(out_item, sim)
	if sim != null:
		sim.emit_cue("alchemy.brewed", { "recipe_id": recipe_id, "item": out_item.get("name", ""), "rarity": out_item.get("rarity", "") })
	progress_reveal("alchemy", sim)
	return true

func can_enter_torpor() -> bool:
	return legend >= 650

func enter_torpor(sim = null) -> bool:
	if not can_enter_torpor():
		return false
	_ensure_bloodline()
	var ledger: Array = bloodline.get("ledger", [])
	ledger.append({
		"title": legend_title().get("name", "Elder"),
		"clan": clan_id,
		"legend": legend,
		"domains": owned_domain_count(),
		"day": day,
	})
	while ledger.size() > 12:
		ledger.pop_front()
	bloodline["generation"] = int(bloodline.get("generation", 1)) + 1
	bloodline["bonus"] = minf(0.6, float(bloodline.get("bonus", 0.0)) + 0.05)
	bloodline["ledger"] = ledger
	progress_reveal("prestige", sim)
	recompute()
	if sim != null:
		apply_to_runtime(sim)
		sim.emit_cue("legacy.torpor", { "generation": bloodline["generation"], "bonus": bloodline["bonus"], "ledger": ledger.duplicate(true) })
	return true

func trigger_event(event_id: String, sim) -> bool:
	if sim == null or not EVENT_DEFS.has(event_id):
		return false
	match event_id:
		"gangwar":
			return _event_gangwar(sim)
		"crackdown":
			return _event_crackdown(sim)
		"bloodhunt":
			return _event_bloodhunt(sim)
		"vip":
			return _event_vip(sim)
		"faint":
			return _event_faint(sim)
		"bounty":
			return _event_bounty(sim)
		"domainraid":
			return _event_domainraid(sim)
	return false

func domain_upkeep() -> Dictionary:
	_ensure_domains()
	var cash := 0
	for d in Catalog.DISTRICTS:
		var id := String(d["id"])
		if domains[id].get("owner", null) == "player":
			cash += roundi(18.0 * (1.0 + float(d.get("danger", 0.0))))
	return { "cash": cash, "vitae": 0 }

func raise_terror_by_id(domain_id: String, amount: float, sim = null, reason: String = "") -> bool:
	_ensure_domains()
	if not district_state.has(domain_id):
		return false
	var before := float(district_state[domain_id].get("terror", 0.0))
	district_state[domain_id]["terror"] = clamp(before + amount, 0.0, 1.0)
	if sim != null and not is_equal_approx(before, float(district_state[domain_id]["terror"])):
		sim.emit_cue("domain.terror", { "domain_id": domain_id, "terror": district_state[domain_id]["terror"], "reason": reason })
	return true

func raise_prosperity_by_id(domain_id: String, amount: float, sim = null, reason: String = "") -> bool:
	_ensure_domains()
	if not district_state.has(domain_id):
		return false
	var before := float(district_state[domain_id].get("prosperity", 0.0))
	district_state[domain_id]["prosperity"] = clamp(before + amount, 0.0, 1.0)
	if sim != null and not is_equal_approx(before, float(district_state[domain_id]["prosperity"])):
		sim.emit_cue("domain.prosperity", { "domain_id": domain_id, "prosperity": district_state[domain_id]["prosperity"], "reason": reason })
	return true

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
		"achievement_check_ticks": achievement_check_ticks,
		"stats": stats.duplicate(true),
		"legend": legend,
		"progress": progress.duplicate(true),
		"nemeses": nemeses.duplicate(true),
		"event_timer": event_timer,
		"active_events": active_events.duplicate(true),
		"pending_raids": pending_raids.duplicate(true),
		"next_event_id": next_event_id,
		"mastery": mastery.duplicate(true),
		"trophies": trophies.duplicate(true),
		"codex": codex.duplicate(true),
		"bloodline": bloodline.duplicate(true),
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
	achievement_check_ticks = max(0, int(data.get("achievement_check_ticks", 0)))
	stats = data.get("stats", {}).duplicate(true) if data.get("stats", {}) is Dictionary else {}
	legend = max(0, int(data.get("legend", 0)))
	progress = _clean_progress(data.get("progress", {}))
	nemeses = _clean_nemeses(data.get("nemeses", []))
	event_timer = maxf(0.0, float(data.get("event_timer", 75.0)))
	active_events = _clean_events(data.get("active_events", []))
	pending_raids = _clean_raids(data.get("pending_raids", []))
	next_event_id = max(1, int(data.get("next_event_id", 1)))
	mastery = _clean_mastery(data.get("mastery", {}))
	trophies = _clean_trophies(data.get("trophies", {}))
	codex = _clean_codex(data.get("codex", {}))
	bloodline = _clean_bloodline(data.get("bloodline", {}))
	_ensure_haven()
	_ensure_reputation()
	_ensure_domains()
	_ensure_mastery()
	_ensure_codex()
	_ensure_bloodline()
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
		_hash_variant(chain_titles), _hash_variant(achievements), _hash_variant(stats),
		achievement_check_ticks, legend, _hash_variant(progress), _hash_variant(nemeses), snapped(event_timer, 0.001),
		next_event_id, _hash_variant(active_events), _hash_variant(pending_raids),
		_hash_variant(mastery), _hash_variant(trophies), _hash_variant(codex), _hash_variant(bloodline)
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

func aggregate_mastery_mods() -> Dictionary:
	_ensure_mastery()
	var out := blank_mods()
	for id in mastery:
		var rank := int(mastery[id].get("rank", 0))
		if rank <= 0:
			continue
		var track: Dictionary = MASTERY_TRACKS.get(String(id), {})
		add_mods(out, _multiply_mods(track.get("per", {}), float(rank)))
	return out

func aggregate_trophy_mods() -> Dictionary:
	var out := blank_mods()
	for id in trophies:
		var def: Dictionary = TROPHY_DEFS.get(String(id), {})
		add_mods(out, def.get("mod", {}))
	return out

func aggregate_codex_mods() -> Dictionary:
	_ensure_codex()
	var out := blank_mods()
	var complete: Dictionary = codex.get("complete", {})
	for id in complete:
		if bool(complete[id]):
			add_mods(out, CODEX_MODS.get(String(id), {}))
	return out

func aggregate_bloodline_mods() -> Dictionary:
	_ensure_bloodline()
	var bonus := float(bloodline.get("bonus", 0.0))
	if bonus <= 0.0:
		return blank_mods()
	return { "add": {}, "pct": { "meleeDmg": bonus, "spellPower": bonus, "maxHP": bonus, "maxBlood": bonus, "feedYield": bonus } }

func resolve_dawn(sim) -> void:
	var coterie_pay := collect_coterie_jobs()
	var domain_pay := collect_domain_tithe()
	var business_pay := _collect_businesses()
	var coterie_cost := collect_coterie_wages()
	var domain_cost := domain_upkeep()
	var gross_cash := int(coterie_pay["cash"]) + int(domain_pay["cash"]) + int(business_pay["cash"])
	var gross_vitae := int(coterie_pay["vitae"]) + int(domain_pay["vitae"]) + int(business_pay["vitae"])
	var upkeep_cash := int(coterie_cost["cash"]) + int(domain_cost["cash"])
	var upkeep_vitae := int(coterie_cost["vitae"]) + int(domain_cost["vitae"])
	var cash := gross_cash - upkeep_cash
	var vitae := gross_vitae - upkeep_vitae
	money = max(0, money + cash)
	if vitae >= 0:
		deposit_vitae(float(vitae))
	else:
		_ensure_haven()
		haven["cellarVitae"] = maxf(0.0, float(haven.get("cellarVitae", 0.0)) + float(vitae))
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
	sim.emit_cue("dawn.arrive", { "day": day, "cash": cash, "vitae": vitae, "gross_cash": gross_cash, "gross_vitae": gross_vitae, "upkeep_cash": upkeep_cash, "upkeep_vitae": upkeep_vitae, "clock": clock })
	# AmbientFX listens for `dawn.arrived` (past tense) — alias it so the dawn ambient fade fires.
	sim.emit_cue("dawn.arrived", { "day": day, "clock": clock })

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

func _update_event_director(delta: float, sim) -> void:
	_resolve_pending_raids(sim)
	_prune_active_events(sim)
	event_timer -= delta
	if event_timer > 0.0:
		return
	event_timer = 90.0 + _draw_float(sim) * 70.0
	if _is_notorious(sim) and not nemeses.is_empty() and _draw_float(sim) < 0.40:
		if maybe_inject_nemesis(sim) != null:
			return
	var event_id := _pick_event_id(sim)
	if event_id != "":
		trigger_event(event_id, sim)

func _pick_event_id(sim) -> String:
	var pool: Array[String] = []
	var stars: int = sim.heat_stars() if sim != null else 0
	var has_domain := owned_domain_count() > 0
	var ids: Array = EVENT_DEFS.keys()
	ids.sort()
	for id in ids:
		var def: Dictionary = EVENT_DEFS[id]
		if stars < int(def.get("minStars", 0)) and not (String(id) == "bloodhunt" and _is_notorious(sim)):
			continue
		if bool(def.get("needsDomain", false)) and not has_domain:
			continue
		for _i in range(int(def.get("weight", 1))):
			pool.append(String(id))
	if pool.is_empty():
		return ""
	return pool[_draw_index(sim, pool.size())]

func _is_notorious(sim) -> bool:
	if sim == null:
		return false
	return sim.heat_stars() >= 3 or _player_humanity(sim) <= 3.0

func _event_gangwar(sim) -> bool:
	var pos := _pick_event_pos(sim, 500.0, 900.0)
	if pos == Vector2.INF:
		return false
	var event_id := _register_event("gangwar", pos, 60.0, sim)
	var red: Array[int] = []
	var blue: Array[int] = []
	for i in range(3):
		var a := _spawn_event_npc(sim, "gunner", pos + _event_offset(sim, 70.0), event_id, { "state": "guard", "hostile_to_player": false })
		a.tags["event_side"] = "red"
		red.append(a.id)
		var b_type := "gunner" if _draw_float(sim) < 0.5 else "thug"
		var b := _spawn_event_npc(sim, b_type, pos + Vector2(100.0, 0.0) + _event_offset(sim, 70.0), event_id, { "state": "guard", "hostile_to_player": false })
		b.tags["event_side"] = "blue"
		blue.append(b.id)
	sim.emit_cue("event.gangwar", { "event_id": event_id, "pos": pos, "red": red, "blue": blue, "caption": "A gang war erupts nearby." })
	return true

func _event_crackdown(sim) -> bool:
	var pos := _pick_event_pos(sim, 400.0, 700.0)
	if pos == Vector2.INF:
		return false
	var event_id := _register_event("crackdown", pos, 75.0, sim)
	var units: Array[int] = []
	for i in range(4):
		var unit := _spawn_event_npc(sim, "swat", pos + _event_offset(sim, 120.0), event_id, { "state": "search", "hostile_to_player": false, "responder": true })
		unit.responder = true
		unit.search_ticks = 420
		units.append(unit.id)
	sim.emit_cue("event.crackdown", { "event_id": event_id, "pos": pos, "units": units, "caption": "Sirens sweep the district." })
	return true

func _event_bloodhunt(sim) -> bool:
	var pos := _pick_event_pos(sim, 600.0, 1000.0)
	if pos == Vector2.INF:
		return false
	var event_id := _register_event("bloodhunt", pos, 90.0, sim)
	var hunters: Array[int] = []
	for i in range(3):
		var hunter := _spawn_event_npc(sim, "hunter", pos + _event_offset(sim, 60.0), event_id, { "state": "chase", "hostile_to_player": true })
		hunter.hostile_to_player = true
		hunters.append(hunter.id)
	sim.add_heat(0.6, "bloodhunt")
	sim.emit_cue("event.bloodhunt", { "event_id": event_id, "pos": pos, "hunters": hunters, "caption": "Second Inquisition hunters have your scent." })
	return true

func _event_vip(sim) -> bool:
	var pos := _pick_event_pos(sim, 300.0, 600.0)
	if pos == Vector2.INF:
		return false
	var event_id := _register_event("vip", pos, 45.0, sim)
	var vip := _spawn_event_npc(sim, "ped", pos, event_id, { "state": "wander", "hostile_to_player": false })
	vip.victim_type = "noble"
	vip.blood_yield = 34.0
	vip.blood_left = 52.0
	vip.tags["vip"] = true
	sim.emit_cue("event.vip", { "event_id": event_id, "entity_id": vip.id, "pos": pos, "caption": "An aristocrat lingers nearby." })
	return true

func _event_faint(sim) -> bool:
	var pos := _pick_event_pos(sim, 200.0, 500.0)
	if pos == Vector2.INF:
		return false
	var event_id := _register_event("faint", pos, 45.0, sim)
	var mortals: Array[int] = []
	for i in range(3):
		var mortal := _spawn_event_npc(sim, "ped", pos + _event_offset(sim, 60.0), event_id, { "state": "wander", "hostile_to_player": false })
		mortal.victim_type = "junkie"
		mortal.blood_yield = 18.0
		mortal.blood_left = 28.0
		mortal.apply_status("mesmerized", 120)
		mortals.append(mortal.id)
	sim.emit_cue("event.faint", { "event_id": event_id, "pos": pos, "mortals": mortals, "caption": "Dazed revelers stumble nearby." })
	return true

func _event_bounty(sim) -> bool:
	var pos := _pick_event_pos(sim, 300.0, 700.0)
	if pos == Vector2.INF:
		return false
	var event_id := _register_event("bounty", pos, 75.0, sim)
	var amount := 150 + level * 25
	var target := _spawn_event_npc(sim, "gunner", pos, event_id, { "state": "wander", "hostile_to_player": false, "hp": 90.0 + float(level) * 6.0 })
	target.tags["bounty"] = amount
	target.tags["vip"] = true
	target.tags["mission_target"] = true
	sim.emit_cue("event.bounty", { "event_id": event_id, "entity_id": target.id, "amount": amount, "pos": pos, "caption": "A marked killer roams nearby." })
	return true

func _event_domainraid(sim) -> bool:
	_ensure_domains()
	var owned: Array[String] = []
	for id in domains:
		if domains[id].get("owner", null) == "player":
			owned.append(String(id))
	owned.sort()
	if owned.is_empty():
		return false
	var domain_id := owned[_draw_index(sim, owned.size())]
	var pos := _pick_event_pos(sim, 400.0, 800.0)
	if pos == Vector2.INF:
		return false
	var event_id := _register_event("domainraid", pos, 120.0, sim)
	var raiders: Array[int] = []
	var count := 4 + _draw_index(sim, 3)
	for i in range(count):
		var type_id := "gunner" if _draw_float(sim) < 0.5 else "thug"
		var raider := _spawn_event_npc(sim, type_id, pos + _event_offset(sim, 100.0), event_id, { "state": "guard", "hostile_to_player": false })
		raider.tags["domain_raider"] = true
		raider.tags["raid_id"] = event_id
		raider.tags["raid_district"] = domain_id
		raiders.append(raider.id)
	pending_raids.append({
		"event_id": event_id,
		"domain_id": domain_id,
		"deadline_tick": sim.tick + 90 * 60,
		"pos": pos,
	})
	while pending_raids.size() > PENDING_RAID_CAP:
		var dropped = pending_raids.pop_front()
		if dropped is Dictionary:
			var dropped_id := int(dropped.get("event_id", 0))
			_remove_active_event_record(dropped_id)
			_remove_event_entities(sim, dropped_id)
	sim.emit_cue("domain.raid_started", { "event_id": event_id, "domain_id": domain_id, "pos": pos, "raiders": raiders, "deadline_tick": sim.tick + 90 * 60 })
	return true

func _resolve_pending_raids(sim) -> void:
	if pending_raids.is_empty():
		return
	for i in range(pending_raids.size() - 1, -1, -1):
		var raid: Dictionary = pending_raids[i]
		if sim.tick < int(raid.get("deadline_tick", 0)):
			continue
		var event_id := int(raid.get("event_id", 0))
		var alive := 0
		for e in sim.entities:
			if e != null and not e.dead and int(e.tags.get("raid_id", 0)) == event_id:
				alive += 1
		var domain_id := String(raid.get("domain_id", ""))
		if alive > 0:
			raise_terror_by_id(domain_id, 0.25, sim, "raid")
			raise_prosperity_by_id(domain_id, -0.15, sim, "raid")
			sim.emit_cue("domain.raid_failed", { "event_id": event_id, "domain_id": domain_id, "alive": alive, "pos": raid.get("pos", Vector2.ZERO) })
		else:
			raise_prosperity_by_id(domain_id, 0.10, sim, "raid_defended")
			add_legend(8, sim, "raid_defended")
			sim.emit_cue("domain.raid_defended", { "event_id": event_id, "domain_id": domain_id, "pos": raid.get("pos", Vector2.ZERO) })
		_remove_active_event_record(event_id)
		_remove_event_entities(sim, event_id)
		pending_raids.remove_at(i)

func _prune_active_events(sim) -> void:
	for i in range(active_events.size() - 1, -1, -1):
		var rec: Dictionary = active_events[i]
		if sim.tick >= int(rec.get("expires_tick", 0)):
			_remove_pending_raid_record(int(rec.get("id", 0)))
			_remove_event_entities(sim, int(rec.get("id", 0)))
			active_events.remove_at(i)

func _register_event(event_type: String, pos: Vector2, ttl_seconds: float, sim) -> int:
	var event_id := next_event_id
	next_event_id += 1
	active_events.append({ "id": event_id, "type": event_type, "pos": pos, "started_tick": sim.tick, "expires_tick": sim.tick + roundi(ttl_seconds * 60.0) })
	while active_events.size() > ACTIVE_EVENT_CAP:
		var dropped = active_events.pop_front()
		if dropped is Dictionary:
			var dropped_id := int(dropped.get("id", 0))
			_remove_pending_raid_record(dropped_id)
			_remove_event_entities(sim, dropped_id)
	sim.emit_cue("event.started", { "event_id": event_id, "type": event_type, "name": EVENT_DEFS.get(event_type, {}).get("name", event_type), "pos": pos })
	return event_id

func _spawn_event_npc(sim, type_id: String, pos: Vector2, event_id: int, opts: Dictionary) -> SimEntity:
	var npc: SimEntity = sim.spawn_npc(type_id, pos, opts)
	npc.tags["event_id"] = event_id
	npc.tags["event_type"] = active_events.back().get("type", "")
	return npc

func _remove_active_event_record(event_id: int) -> void:
	if event_id <= 0:
		return
	for i in range(active_events.size() - 1, -1, -1):
		if int(active_events[i].get("id", 0)) == event_id:
			active_events.remove_at(i)

func _remove_pending_raid_record(event_id: int) -> void:
	if event_id <= 0:
		return
	for i in range(pending_raids.size() - 1, -1, -1):
		if int(pending_raids[i].get("event_id", 0)) == event_id:
			pending_raids.remove_at(i)

func _remove_event_entities(sim, event_id: int) -> void:
	if sim == null or event_id <= 0:
		return
	for i in range(sim.entities.size() - 1, -1, -1):
		var e = sim.entities[i]
		if e == null:
			sim.entities.remove_at(i)
			continue
		if e == sim.player:
			continue
		var tagged_event := int(e.tags.get("event_id", 0)) == event_id
		var tagged_raid := int(e.tags.get("raid_id", 0)) == event_id
		if not tagged_event and not tagged_raid:
			continue
		if e.tags.has("mission_id") or e.tags.has("coterie_id"):
			continue
		sim.entities.remove_at(i)

func _pick_event_pos(sim, min_d: float, max_d: float) -> Vector2:
	if sim == null or sim.player == null or sim.world == null:
		return Vector2.INF
	for i in range(30):
		var angle := _draw_float(sim) * TAU
		var dist := min_d + _draw_float(sim) * (max_d - min_d)
		var p: Vector2 = sim.player.pos + Vector2.RIGHT.rotated(angle) * dist
		if not sim.world.is_blocked_world(p, 8.0):
			return p
	return sim.world.nearest_open_around(sim.player.pos, min_d, max_d, _draw_index(sim, 997))

func _event_offset(sim, spread: float) -> Vector2:
	return Vector2((_draw_float(sim) - 0.5) * spread, (_draw_float(sim) - 0.5) * spread)

func _collect_businesses() -> Dictionary:
	var cash := 0
	var vitae := 0
	var domain_mult := 1.0 + float(owned_domain_count()) * 0.12
	for id in businesses:
		if not bool(businesses[id].get("owned", false)):
			continue
		var def: Dictionary = Catalog.BUSINESSES.get(String(id), {})
		var tier := int(businesses[id].get("tier", 0))
		var mult := (1.0 + float(tier)) * domain_mult
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

func _has_any_haven_upgrade() -> bool:
	_ensure_haven()
	for id in haven["rooms"]:
		if int(haven["rooms"][id]) > 0:
			return true
	return false

func _has_any_reputation() -> bool:
	_ensure_reputation()
	for id in reputation:
		if absf(float(reputation[id])) > 0.001:
			return true
	return false

func _owned_business_count() -> int:
	var count := 0
	for id in businesses:
		if bool(businesses[id].get("owned", false)):
			count += 1
	return count

func _has_any_coterie_job() -> bool:
	for member in coterie:
		if String(member.get("assignment", "none")) != "none":
			return true
	return false

func _ensure_mastery() -> void:
	for id in MASTERY_TRACKS:
		if not mastery.has(id) or not (mastery[id] is Dictionary):
			mastery[id] = { "xp": 0.0, "rank": 0 }
		else:
			mastery[id]["xp"] = maxf(0.0, float(mastery[id].get("xp", 0.0)))
			mastery[id]["rank"] = clamp(int(mastery[id].get("rank", mastery_rank_for(float(mastery[id]["xp"])))), 0, MASTERY_CAP)

func _ensure_codex() -> void:
	for id in CODEX_TOTALS:
		if not codex.has(id) or not (codex[id] is Dictionary):
			codex[id] = {}
	if not codex.has("complete") or not (codex["complete"] is Dictionary):
		codex["complete"] = {}

func _ensure_bloodline() -> void:
	if bloodline.is_empty():
		bloodline = { "generation": 1, "bonus": 0.0, "ledger": [] }
	bloodline["generation"] = max(1, int(bloodline.get("generation", 1)))
	bloodline["bonus"] = clamp(float(bloodline.get("bonus", 0.0)), 0.0, 0.6)
	if not (bloodline.get("ledger", []) is Array):
		bloodline["ledger"] = []

func _codex_check_complete(category: String, sim = null) -> bool:
	_ensure_codex()
	var have: int = known_powers.size() if category == "powers" else codex[category].size()
	if have < int(CODEX_TOTALS.get(category, 999999)):
		return false
	if bool(codex["complete"].get(category, false)):
		return false
	codex["complete"][category] = true
	recompute()
	if sim != null:
		apply_to_runtime(sim)
		sim.emit_cue("codex.complete", { "category": category, "mods": CODEX_MODS.get(category, {}) })
	return true

func _trophy_key_for(target: SimEntity) -> String:
	if target == null:
		return ""
	if target.tags.has("baron_of"):
		return "baron"
	if target.tags.has("nemesis_name"):
		return "nemesis"
	if target.type_id == "elder":
		return "elder"
	if target.faction == "inquis":
		return "inquis" if bool(target.tags.get("elite", false)) or target.type_id in ["swat", "elder"] else "hunter"
	return ""

func _active_coterie_count(sim) -> int:
	if sim == null:
		return 0
	var count := 0
	for e in sim.entities:
		if e != null and not e.dead and e.tags.has("coterie_id"):
			count += 1
	return count

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
		for id in ["cel_dash", "pot_slam", "for_mend", "obf_cloak", "obf_vanish", "aus_mark", "dom_mesmer", "pre_dread", "bs_bolt"]:
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

func _clean_progress(source) -> Dictionary:
	var out := {}
	if source is Dictionary:
		for id in source:
			var key := String(id)
			if not PROGRESS_ORDER.has(key):
				continue
			var rec := {}
			if source[id] is Dictionary:
				rec = (source[id] as Dictionary).duplicate(true)
			rec["revealed"] = bool(rec.get("revealed", true))
			rec["seen"] = bool(rec.get("seen", false))
			rec["order"] = PROGRESS_ORDER.find(key)
			rec["tick"] = max(0, int(rec.get("tick", 0)))
			out[key] = rec
	return out

func _clean_nemeses(source) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if source is Array:
		for item in source:
			if not (item is Dictionary) or out.size() >= 3:
				continue
			var rec: Dictionary = item
			out.append({
				"name": String(rec.get("name", "The Hunter")),
				"rank": max(1, int(rec.get("rank", 1))),
				"scar": String(rec.get("scar", "scarred")),
				"resistType": String(rec.get("resistType", "physical")),
				"archetype": String(rec.get("archetype", "hunter")),
				"escaped_tick": max(0, int(rec.get("escaped_tick", 0))),
				"returned_tick": max(0, int(rec.get("returned_tick", 0))),
			})
	return out

func _clean_mastery(source) -> Dictionary:
	var out := {}
	for id in MASTERY_TRACKS:
		out[id] = { "xp": 0.0, "rank": 0 }
	if source is Dictionary:
		for id in MASTERY_TRACKS:
			var rec: Variant = (source as Dictionary).get(id, {})
			if rec is Dictionary:
				var xp_amount := maxf(0.0, float(rec.get("xp", 0.0)))
				out[id] = { "xp": xp_amount, "rank": clamp(int(rec.get("rank", mastery_rank_for(xp_amount))), 0, MASTERY_CAP) }
	return out

func _clean_trophies(source) -> Dictionary:
	var out := {}
	if source is Dictionary:
		for id in source:
			var key := String(id)
			if TROPHY_DEFS.has(key):
				var def: Dictionary = TROPHY_DEFS[key]
				out[key] = { "id": key, "name": def["name"], "desc": def["desc"] }
	elif source is Array:
		for item in source:
			if item is Dictionary:
				var key := String((item as Dictionary).get("id", ""))
				if TROPHY_DEFS.has(key):
					var def: Dictionary = TROPHY_DEFS[key]
					out[key] = { "id": key, "name": def["name"], "desc": def["desc"] }
	return out

func _clean_codex(source) -> Dictionary:
	var out := {}
	for id in CODEX_TOTALS:
		out[id] = {}
	out["complete"] = {}
	if source is Dictionary:
		for id in CODEX_TOTALS:
			var key := String(id)
			var rec = (source as Dictionary).get(key, {})
			if rec is Dictionary:
				for entry in rec:
					if bool(rec[entry]):
						out[key][String(entry)] = true
		var complete = (source as Dictionary).get("complete", {})
		if complete is Dictionary:
			for id in complete:
				var key := String(id)
				if CODEX_TOTALS.has(key) and bool(complete[id]):
					out["complete"][key] = true
	return out

func _clean_bloodline(source) -> Dictionary:
	var out := { "generation": 1, "bonus": 0.0, "ledger": [] }
	if source is Dictionary:
		out["generation"] = max(1, int((source as Dictionary).get("generation", 1)))
		out["bonus"] = clamp(float((source as Dictionary).get("bonus", 0.0)), 0.0, 0.6)
		var ledger = (source as Dictionary).get("ledger", [])
		if ledger is Array:
			for item in ledger:
				if item is Dictionary and out["ledger"].size() < 12:
					out["ledger"].append({
						"title": String((item as Dictionary).get("title", "")),
						"clan": _clean_clan(String((item as Dictionary).get("clan", clan_id))),
						"legend": max(0, int((item as Dictionary).get("legend", 0))),
						"domains": max(0, int((item as Dictionary).get("domains", 0))),
						"day": max(1, int((item as Dictionary).get("day", 1))),
					})
	return out

func _clean_events(source) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if source is Array:
		for item in source:
			if not (item is Dictionary) or out.size() >= ACTIVE_EVENT_CAP:
				continue
			var rec: Dictionary = item
			out.append({
				"id": max(1, int(rec.get("id", 1))),
				"type": String(rec.get("type", "")),
				"pos": rec.get("pos", Vector2.ZERO) if rec.get("pos", null) is Vector2 else Vector2.ZERO,
				"started_tick": max(0, int(rec.get("started_tick", 0))),
				"expires_tick": max(0, int(rec.get("expires_tick", 0))),
			})
	return out

func _clean_raids(source) -> Array[Dictionary]:
	_ensure_domains()
	var out: Array[Dictionary] = []
	if source is Array:
		for item in source:
			if not (item is Dictionary) or out.size() >= PENDING_RAID_CAP:
				continue
			var rec: Dictionary = item
			var domain_id := String(rec.get("domain_id", ""))
			if not domains.has(domain_id):
				continue
			out.append({
				"event_id": max(1, int(rec.get("event_id", 1))),
				"domain_id": domain_id,
				"deadline_tick": max(0, int(rec.get("deadline_tick", 0))),
				"pos": rec.get("pos", Vector2.ZERO) if rec.get("pos", null) is Vector2 else Vector2.ZERO,
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
