## GameCatalog.gd -- static gameplay data ported from legacy/js/data/gamedata.js.
##
## This file is pure deterministic data. Runtime systems may read and duplicate these
## dictionaries, but all mutation belongs to Sim/SimMeta/SimEntity delegates.
extends RefCounted
class_name GameCatalog

const ATTRIBUTES := [
	{ "id": "might", "name": "Might", "desc": "Melee damage and knockback" },
	{ "id": "finesse", "name": "Finesse", "desc": "Move speed, attack speed, and dodge" },
	{ "id": "vitality", "name": "Vitality", "desc": "Health and regeneration" },
	{ "id": "bloodcraft", "name": "Bloodcraft", "desc": "Vitae and discipline potency" },
	{ "id": "wits", "name": "Wits", "desc": "Cooldowns and critical hits" },
	{ "id": "presence", "name": "Presence", "desc": "Feeding, influence, prices, and XP" },
]

const DISCIPLINES := {
	"celerity": { "name": "Celerity", "color": "#7ad0ff" },
	"potence": { "name": "Potence", "color": "#e0b050" },
	"fortitude": { "name": "Fortitude", "color": "#9aa0a8" },
	"obfuscate": { "name": "Obfuscate", "color": "#8a8fb0" },
	"auspex": { "name": "Auspex", "color": "#aef0ff" },
	"dominate": { "name": "Dominate", "color": "#b98cff" },
	"presence": { "name": "Presence", "color": "#ff9ecf" },
	"protean": { "name": "Protean", "color": "#c1722a" },
	"sorcery": { "name": "Blood Sorcery", "color": "#e0203f" },
	"dark": { "name": "Dark Arts", "color": "#8a4bd0" },
	"predator": { "name": "Predator", "color": "#c0303a" },
}

const CLAN_BANES := {
	"brujah": { "pct": { "frenzyResist": -0.15 } },
	"gangrel": { "pct": { "discount": -0.08 } },
	"tremere": { "pct": { "maxHP": -0.10 } },
	"ventrue": { "pct": { "feedYield": -0.12 } },
	"toreador": { "pct": { "armor": -0.06 } },
	"nosferatu": { "pct": { "discount": -0.12 } },
	"malkavian": { "pct": { "maxBlood": -0.08 } },
}

const CLAN_BOONS := {
	"brujah": { "pct": { "meleeDmg": 0.15 } },
	"gangrel": { "pct": { "moveSpeed": 0.10, "hpRegen": 0.25 } },
	"tremere": { "pct": { "spellPower": 0.18 } },
	"ventrue": { "add": { "influence": 2 }, "pct": { "discount": 0.10 } },
	"toreador": { "pct": { "feedYield": 0.15, "critChance": 0.04 } },
	"nosferatu": { "pct": { "maxHP": 0.10 } },
	"malkavian": { "pct": { "cdr": 0.10 } },
}

const POWERS := {
	"cel_dash": { "name": "Quicken", "discipline": "celerity", "type": "active", "cost": 8.0, "cooldown": 210, "range": 205.0, "iframes": 21, "cue": "power.celerity.quicken", "description": "Blink forward with brief invulnerability." },
	"cel_haste": { "name": "Fleetness", "discipline": "celerity", "type": "toggle", "cost": 0.0, "upkeep": 2.4, "cooldown": 30, "duration": -1, "cue": "power.celerity.fleetness", "description": "Toggle faster movement, attacks, and dodge at a vitae upkeep." },
	"cel_flurry": { "name": "Blood Flurry", "discipline": "celerity", "type": "active", "cost": 12.0, "cooldown": 600, "duration": 210, "cue": "power.celerity.flurry", "description": "Greatly increase attack speed for a short burst." },
	"cel_bullet": { "name": "Quicksilver", "discipline": "celerity", "type": "active", "cost": 25.0, "cooldown": 1680, "duration": 240, "cue": "power.celerity.quicksilver", "description": "Slow the world while you keep moving." },
	"pot_slam": { "name": "Earthshock", "discipline": "potence", "type": "active", "cost": 14.0, "cooldown": 420, "radius": 115.0, "damage": 24.0, "knockback": 240.0, "stun": 72, "cue": "power.potence.slam", "description": "Ground slam with damage, knockback, and stun." },
	"pot_charge": { "name": "Brutal Charge", "discipline": "potence", "type": "active", "cost": 10.0, "cooldown": 360, "range": 210.0, "radius": 34.0, "damage": 26.0, "stun": 36, "cue": "power.potence.charge", "description": "Lunge through foes, stunning them." },
	"pot_quake": { "name": "Cataclysm", "discipline": "potence", "type": "active", "cost": 30.0, "cooldown": 1320, "radius": 185.0, "damage": 42.0, "knockback": 320.0, "stun": 96, "cue": "power.potence.cataclysm", "description": "Massive shockwave with heavy knockback." },
	"for_mend": { "name": "Mend Flesh", "discipline": "fortitude", "type": "active", "cost": 25.0, "cooldown": 300, "heal": 48.0, "cue": "power.fortitude.mend", "description": "Spend vitae to heal grievous wounds." },
	"for_stone": { "name": "Stone Skin", "discipline": "fortitude", "type": "active", "cost": 12.0, "cooldown": 840, "duration": 480, "armor": 0.40, "cue": "power.fortitude.stone_skin", "description": "Reduce incoming damage for a short time." },
	"for_unkill": { "name": "Unkillable", "discipline": "fortitude", "type": "active", "cost": 30.0, "cooldown": 2160, "duration": 156, "cue": "power.fortitude.unkillable", "description": "Become briefly invulnerable." },
	"obf_cloak": { "name": "Cloak of Shadows", "discipline": "obfuscate", "type": "toggle", "cost": 6.0, "upkeep": 1.4, "cooldown": 30, "duration": -1, "cue": "power.obfuscate.cloak", "description": "Toggle stealth until you attack or run out of vitae." },
	"obf_vanish": { "name": "Vanish", "discipline": "obfuscate", "type": "active", "cost": 18.0, "cooldown": 1320, "duration": 180, "radius": 240.0, "heat_reduction": 0.8, "cue": "power.obfuscate.vanish", "description": "Break pursuit and reduce Heat." },
	"obf_mask": { "name": "Mask of a Thousand Faces", "discipline": "obfuscate", "type": "active", "cost": 35.0, "cooldown": 3300, "heat_reduction": 2.0, "cue": "power.obfuscate.mask", "description": "Assume a new face and clear Heat." },
	"aus_senses": { "name": "Heightened Senses", "discipline": "auspex", "type": "toggle", "cost": 0.0, "upkeep": 0.6, "cooldown": 30, "duration": -1, "cue": "power.auspex.senses", "description": "Reveal threats and gain critical focus." },
	"aus_premon": { "name": "Premonition", "discipline": "auspex", "type": "active", "cost": 12.0, "cooldown": 720, "duration": 360, "dodge": 0.4, "cue": "power.auspex.premonition", "description": "Gain a strong dodge buff." },
	"aus_mark": { "name": "Aura of Frailty", "discipline": "auspex", "type": "active", "cost": 8.0, "cooldown": 360, "range": 380.0, "duration": 600, "damage_bonus": 0.35, "cue": "power.auspex.mark", "description": "Reveal and weaken one target." },
	"dom_mesmer": { "name": "Mesmerize", "discipline": "dominate", "type": "active", "cost": 10.0, "cooldown": 300, "range": 150.0, "radius": 130.0, "arc": 1.4, "stun": 300, "cue": "power.dominate.mesmerize", "description": "Freeze targets in front of you." },
	"dom_command": { "name": "Command: Flee", "discipline": "dominate", "type": "active", "cost": 12.0, "cooldown": 540, "range": 220.0, "fear": 300, "cue": "power.dominate.command", "description": "Force a target to flee." },
	"dom_forget": { "name": "Forgetful Mind", "discipline": "dominate", "type": "active", "cost": 20.0, "cooldown": 1560, "heat_reduction": 1.0, "cue": "power.dominate.forget", "description": "Erase witness panic and reduce Heat." },
	"dom_thrall": { "name": "Bind Thrall", "discipline": "dominate", "type": "active", "cost": 30.0, "cooldown": 2400, "range": 95.0, "cue": "power.dominate.thrall", "description": "Enslave a weakened soul to fight for you." },
	"pre_dread": { "name": "Dread Gaze", "discipline": "presence", "type": "active", "cost": 16.0, "cooldown": 720, "radius": 165.0, "fear": 300, "cue": "power.presence.dread", "description": "Terrify nearby mortals and enemies." },
	"pre_majesty": { "name": "Majesty", "discipline": "presence", "type": "active", "cost": 25.0, "cooldown": 1560, "duration": 360, "cue": "power.presence.majesty", "description": "Mortals hesitate to strike you." },
	"pre_entr": { "name": "Entrancement", "discipline": "presence", "type": "active", "cost": 18.0, "cooldown": 1080, "radius": 185.0, "stun": 480, "cue": "power.presence.entrancement", "description": "Charm civilians into willing prey." },
	"pro_claws": { "name": "Feral Claws", "discipline": "protean", "type": "toggle", "cost": 0.0, "upkeep": 1.2, "cooldown": 30, "duration": -1, "damage_bonus": 0.5, "lifesteal": 0.08, "cue": "power.protean.claws", "description": "Grow claws for melee damage and lifesteal." },
	"pro_mist": { "name": "Mist Form", "discipline": "protean", "type": "active", "cost": 25.0, "cooldown": 1080, "duration": 180, "cue": "power.protean.mist", "description": "Become mist and ignore harm briefly." },
	"pro_beast": { "name": "Beast Form", "discipline": "protean", "type": "active", "cost": 30.0, "cooldown": 1680, "duration": 600, "cue": "power.protean.beast", "description": "Transform for melee, speed, and health." },
	"bs_bolt": { "name": "Blood Bolt", "discipline": "sorcery", "type": "active", "cost": 8.0, "cooldown": 72, "range": 340.0, "speed": 540.0, "damage": 24.0, "bleed": 180, "cue": "power.blood_sorcery.bolt", "description": "Hurl a bolt of congealed blood." },
	"bs_cauldron": { "name": "Cauldron of Blood", "discipline": "sorcery", "type": "active", "cost": 14.0, "cooldown": 420, "range": 320.0, "damage": 18.0, "duration": 300, "splash": 70.0, "cue": "power.blood_sorcery.cauldron", "description": "Boil a victim's blood and spread bleed nearby." },
	"bs_ward": { "name": "Blood Ward", "discipline": "sorcery", "type": "active", "cost": 20.0, "cooldown": 960, "duration": 720, "shield": 60.0, "cue": "power.blood_sorcery.ward", "description": "A shield of vitae absorbs damage." },
	"bs_theft": { "name": "Theft of Vitae", "discipline": "sorcery", "type": "active", "cost": 5.0, "cooldown": 240, "range": 300.0, "damage": 18.0, "steal": 0.6, "cue": "power.blood_sorcery.theft", "description": "Rip blood from afar to refill your own." },
	"bs_storm": { "name": "Blood Storm", "discipline": "sorcery", "type": "active", "cost": 35.0, "cooldown": 1200, "bolts": 14, "damage": 16.0, "cue": "power.blood_sorcery.storm", "description": "Erupt in a radial storm of blood bolts." },
	"shd_tendril": { "name": "Shadow Tendrils", "discipline": "dark", "type": "active", "cost": 14.0, "cooldown": 540, "range": 280.0, "radius": 95.0, "duration": 180, "damage": 8.0, "cue": "power.dark.tendrils", "description": "Pin foes with roots of darkness." },
	"shd_arms": { "name": "Arms of the Abyss", "discipline": "dark", "type": "active", "cost": 12.0, "cooldown": 420, "range": 340.0, "damage": 14.0, "pull": 130.0, "cue": "power.dark.arms", "description": "Drag a distant foe to your fangs." },
	"dem_confuse": { "name": "Dementation", "discipline": "dark", "type": "active", "cost": 18.0, "cooldown": 900, "radius": 190.0, "duration": 360, "cue": "power.dark.dementation", "description": "Drive foes mad against each other." },
	"vic_horrid": { "name": "Horrid Form", "discipline": "dark", "type": "active", "cost": 30.0, "cooldown": 2160, "duration": 720, "cue": "power.dark.horrid", "description": "Become monstrous: tougher, armored, and brutal." },
}

const LEGACY_POWER_ALIASES := {
	"dom_mesmerize": "dom_mesmer",
	"blood_bolt": "bs_bolt",
}

const SKILL_TIER_REQ := [0, 1, 3, 6, 10, 15]

const SKILL_NODES := {
	"cel_p0": { "branch": "celerity", "type": "passive", "tier": 0, "maxRank": 3, "mods": { "pct": { "moveSpeed": 0.05 } } },
	"cel_n1": { "branch": "celerity", "type": "power", "tier": 1, "power": "cel_dash" },
	"cel_p1": { "branch": "celerity", "type": "passive", "tier": 1, "maxRank": 3, "mods": { "pct": { "attackSpeed": 0.06, "dodge": 0.02 } } },
	"cel_n2": { "branch": "celerity", "type": "power", "tier": 2, "power": "cel_haste" },
	"cel_p2": { "branch": "celerity", "type": "passive", "tier": 2, "maxRank": 3, "mods": { "pct": { "moveSpeed": 0.07, "cdr": 0.03 } } },
	"cel_n3": { "branch": "celerity", "type": "power", "tier": 3, "power": "cel_flurry" },
	"cel_n4": { "branch": "celerity", "type": "power", "tier": 4, "power": "cel_bullet" },
	"cel_key": { "branch": "celerity", "type": "keystone", "tier": 4, "conflicts": ["pot_key"] },
	"pot_p0": { "branch": "potence", "type": "passive", "tier": 0, "maxRank": 3, "mods": { "pct": { "meleeDmg": 0.07 } } },
	"pot_n1": { "branch": "potence", "type": "power", "tier": 1, "power": "pot_charge" },
	"pot_p1": { "branch": "potence", "type": "passive", "tier": 1, "maxRank": 3, "mods": { "pct": { "meleeDmg": 0.08, "critMult": 0.05 } } },
	"pot_n2": { "branch": "potence", "type": "power", "tier": 2, "power": "pot_slam" },
	"pot_p2": { "branch": "potence", "type": "passive", "tier": 2, "maxRank": 3, "mods": { "pct": { "meleeDmg": 0.09 }, "add": { "critChance": 3.0 } } },
	"pot_n3": { "branch": "potence", "type": "power", "tier": 3, "power": "pot_quake" },
	"pot_key": { "branch": "potence", "type": "keystone", "tier": 4, "conflicts": ["cel_key"] },
	"for_p0": { "branch": "fortitude", "type": "passive", "tier": 0, "maxRank": 4, "mods": { "pct": { "armor": 0.03, "maxHP": 0.04 } } },
	"for_n1": { "branch": "fortitude", "type": "power", "tier": 1, "power": "for_mend" },
	"for_p1": { "branch": "fortitude", "type": "passive", "tier": 1, "maxRank": 4, "mods": { "pct": { "maxHP": 0.06, "hpRegen": 0.15 } } },
	"for_n2": { "branch": "fortitude", "type": "power", "tier": 2, "power": "for_stone" },
	"for_p2": { "branch": "fortitude", "type": "passive", "tier": 2, "maxRank": 3, "mods": { "pct": { "frenzyResist": 0.10, "sunResist": 0.08 } } },
	"for_n3": { "branch": "fortitude", "type": "power", "tier": 3, "power": "for_unkill" },
	"for_key": { "branch": "fortitude", "type": "keystone", "tier": 4, "mods": { "pct": { "armor": 0.15, "maxHP": 0.15 } }, "conflicts": ["bs_key"] },
	"obf_p0": { "branch": "obfuscate", "type": "passive", "tier": 0, "maxRank": 3, "mods": { "add": { "detectRange": -20.0 } } },
	"obf_n1": { "branch": "obfuscate", "type": "power", "tier": 1, "power": "obf_cloak" },
	"obf_p1": { "branch": "obfuscate", "type": "passive", "tier": 1, "maxRank": 3, "mods": { "pct": { "critChance": 0.05 } } },
	"obf_n2": { "branch": "obfuscate", "type": "power", "tier": 2, "power": "obf_vanish" },
	"obf_p2": { "branch": "obfuscate", "type": "passive", "tier": 2, "maxRank": 3, "mods": { "pct": { "bloodEff": 0.05 } } },
	"obf_n3": { "branch": "obfuscate", "type": "power", "tier": 3, "power": "obf_mask" },
	"obf_key": { "branch": "obfuscate", "type": "keystone", "tier": 4, "conflicts": ["prd_key"] },
	"aus_p0": { "branch": "auspex", "type": "passive", "tier": 0, "maxRank": 3, "mods": { "add": { "critChance": 3.0 } } },
	"aus_n1": { "branch": "auspex", "type": "power", "tier": 1, "power": "aus_mark" },
	"aus_p1": { "branch": "auspex", "type": "passive", "tier": 1, "maxRank": 3, "mods": { "pct": { "dodge": 0.04 } } },
	"aus_n2": { "branch": "auspex", "type": "power", "tier": 2, "power": "aus_senses" },
	"aus_p2": { "branch": "auspex", "type": "passive", "tier": 2, "maxRank": 3, "mods": { "pct": { "critMult": 0.10 } } },
	"aus_n3": { "branch": "auspex", "type": "power", "tier": 3, "power": "aus_premon" },
	"aus_key": { "branch": "auspex", "type": "keystone", "tier": 4, "conflicts": ["dom_key"] },
	"dom_p0": { "branch": "dominate", "type": "passive", "tier": 0, "maxRank": 3, "mods": { "pct": { "cdr": 0.03 } } },
	"dom_n1": { "branch": "dominate", "type": "power", "tier": 1, "power": "dom_mesmer" },
	"dom_p1": { "branch": "dominate", "type": "passive", "tier": 1, "maxRank": 3, "mods": { "pct": { "bloodEff": 0.04 } } },
	"dom_n2": { "branch": "dominate", "type": "power", "tier": 2, "power": "dom_command" },
	"dom_n3": { "branch": "dominate", "type": "power", "tier": 3, "power": "dom_forget" },
	"dom_n4": { "branch": "dominate", "type": "power", "tier": 4, "power": "dom_thrall" },
	"dom_key": { "branch": "dominate", "type": "keystone", "tier": 4, "conflicts": ["aus_key"] },
	"pre_p0": { "branch": "presence", "type": "passive", "tier": 0, "maxRank": 3, "mods": { "pct": { "discount": 0.04, "feedYield": 0.04 } } },
	"pre_n1": { "branch": "presence", "type": "power", "tier": 1, "power": "pre_dread" },
	"pre_p1": { "branch": "presence", "type": "passive", "tier": 1, "maxRank": 3, "mods": { "pct": { "feedSpeed": 0.08, "xpMult": 0.03 } } },
	"pre_n2": { "branch": "presence", "type": "power", "tier": 2, "power": "pre_entr" },
	"pre_n3": { "branch": "presence", "type": "power", "tier": 3, "power": "pre_majesty" },
	"pre_key": { "branch": "presence", "type": "keystone", "tier": 4, "mods": { "pct": { "xpMult": 0.10, "discount": 0.10, "feedYield": 0.10 } }, "conflicts": ["pro_key"] },
	"pro_p0": { "branch": "protean", "type": "passive", "tier": 0, "maxRank": 3, "mods": { "pct": { "meleeDmg": 0.06, "lifesteal": 0.02 } } },
	"pro_n1": { "branch": "protean", "type": "power", "tier": 1, "power": "pro_claws" },
	"pro_p1": { "branch": "protean", "type": "passive", "tier": 1, "maxRank": 3, "mods": { "pct": { "armor": 0.05, "maxHP": 0.05 } } },
	"pro_n2": { "branch": "protean", "type": "power", "tier": 2, "power": "pro_mist" },
	"pro_n3": { "branch": "protean", "type": "power", "tier": 3, "power": "pro_beast" },
	"pro_key": { "branch": "protean", "type": "keystone", "tier": 4, "conflicts": ["pre_key"] },
	"bs_p0": { "branch": "sorcery", "type": "passive", "tier": 0, "maxRank": 4, "mods": { "pct": { "spellPower": 0.06 } } },
	"bs_n1": { "branch": "sorcery", "type": "power", "tier": 1, "power": "bs_bolt" },
	"bs_p1": { "branch": "sorcery", "type": "passive", "tier": 1, "maxRank": 4, "mods": { "pct": { "spellPower": 0.07, "bloodEff": 0.03 } } },
	"bs_n2": { "branch": "sorcery", "type": "power", "tier": 2, "power": "bs_theft" },
	"bs_n3": { "branch": "sorcery", "type": "power", "tier": 2, "power": "bs_cauldron" },
	"bs_n4": { "branch": "sorcery", "type": "power", "tier": 3, "power": "bs_ward" },
	"bs_n5": { "branch": "sorcery", "type": "power", "tier": 4, "power": "bs_storm" },
	"bs_key": { "branch": "sorcery", "type": "keystone", "tier": 4, "conflicts": ["for_key"] },
	"dk_p0": { "branch": "dark", "type": "passive", "tier": 0, "maxRank": 3, "mods": { "pct": { "spellPower": 0.05 } } },
	"dk_n1": { "branch": "dark", "type": "power", "tier": 1, "power": "shd_arms" },
	"dk_n2": { "branch": "dark", "type": "power", "tier": 2, "power": "shd_tendril" },
	"dk_p1": { "branch": "dark", "type": "passive", "tier": 2, "maxRank": 3, "mods": { "pct": { "spellPower": 0.06, "armor": 0.03 } } },
	"dk_n3": { "branch": "dark", "type": "power", "tier": 3, "power": "dem_confuse" },
	"dk_n4": { "branch": "dark", "type": "power", "tier": 4, "power": "vic_horrid" },
	"dk_key": { "branch": "dark", "type": "keystone", "tier": 4, "mods": { "pct": { "spellPower": 0.20, "maxHP": 0.12 } } },
	"prd_p0": { "branch": "predator", "type": "passive", "tier": 0, "maxRank": 4, "mods": { "pct": { "feedYield": 0.08, "feedSpeed": 0.08 } } },
	"prd_p1": { "branch": "predator", "type": "passive", "tier": 1, "maxRank": 4, "mods": { "pct": { "maxBlood": 0.10 } } },
	"prd_p2": { "branch": "predator", "type": "passive", "tier": 1, "maxRank": 3, "mods": { "pct": { "bloodEff": 0.04 } } },
	"prd_p3": { "branch": "predator", "type": "passive", "tier": 2, "maxRank": 3, "mods": { "pct": { "lifesteal": 0.04, "hpRegen": 0.20 } } },
	"prd_p4": { "branch": "predator", "type": "passive", "tier": 2, "maxRank": 3, "mods": { "pct": { "frenzyResist": 0.12 } } },
	"prd_p5": { "branch": "predator", "type": "passive", "tier": 3, "maxRank": 3, "mods": { "pct": { "xpMult": 0.06, "maxBlood": 0.08 } } },
	"prd_key": { "branch": "predator", "type": "keystone", "tier": 4, "mods": { "pct": { "lifesteal": 0.10, "meleeDmg": 0.12, "spellPower": 0.12 } }, "conflicts": ["obf_key"] },
}

const RARITY := {
	"common": { "name": "Common", "color": "#b8b8c0", "affixes": 1, "mult": 1.0 },
	"uncommon": { "name": "Uncommon", "color": "#5ad06a", "affixes": 2, "mult": 1.25 },
	"rare": { "name": "Rare", "color": "#5a9cff", "affixes": 3, "mult": 1.6 },
	"epic": { "name": "Epic", "color": "#c060ff", "affixes": 4, "mult": 2.1 },
	"legendary": { "name": "Legendary", "color": "#ff9a30", "affixes": 5, "mult": 2.8 },
	"relic": { "name": "Relic", "color": "#ff7a30", "affixes": 0, "mult": 4.5 },
}

const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary", "relic"]

const WEAPONS := [
	{ "kind": "pistol", "name": "Pistol", "damage": 12.0, "fire_rate": 0.28, "spread": 0.05, "speed": 600.0, "slot": "weapon" },
	{ "kind": "smg", "name": "SMG", "damage": 9.0, "fire_rate": 0.10, "spread": 0.10, "speed": 640.0, "slot": "weapon" },
	{ "kind": "shotgun", "name": "Shotgun", "damage": 8.0, "fire_rate": 0.70, "spread": 0.05, "speed": 560.0, "pellets": 6, "slot": "weapon" },
	{ "kind": "magnum", "name": "Magnum", "damage": 30.0, "fire_rate": 0.60, "spread": 0.02, "speed": 720.0, "pierce": 1, "slot": "weapon" },
	{ "kind": "rifle", "name": "Assault Rifle", "damage": 16.0, "fire_rate": 0.13, "spread": 0.06, "speed": 720.0, "slot": "weapon" },
	{ "kind": "stake", "name": "Stake Launcher", "damage": 40.0, "fire_rate": 0.90, "spread": 0.01, "speed": 540.0, "pierce": 2, "slot": "weapon" },
]

const ATTIRE := [
	{ "kind": "coat", "name": "Leather Coat", "slot": "attire", "base": { "pct": { "armor": 0.05 } } },
	{ "kind": "cloak", "name": "Midnight Cloak", "slot": "attire", "base": { "pct": { "dodge": 0.05 } } },
	{ "kind": "suit", "name": "Tailored Suit", "slot": "attire", "base": { "pct": { "discount": 0.06 } } },
	{ "kind": "mail", "name": "Hidden Mail", "slot": "attire", "base": { "add": { "maxHP": 25.0 } } },
	{ "kind": "shroud", "name": "Shroud of Night", "slot": "attire", "base": { "pct": { "spellPower": 0.08 } } },
]

const CHARMS := [
	{ "kind": "signet", "name": "Bloodstone Signet", "slot": "charm", "base": { "pct": { "maxBlood": 0.08 } } },
	{ "kind": "fang", "name": "Ancient Fang", "slot": "charm", "base": { "pct": { "feedYield": 0.10 } } },
	{ "kind": "locket", "name": "Cursed Locket", "slot": "charm", "base": { "pct": { "spellPower": 0.06 } } },
	{ "kind": "ring", "name": "Ring of Celerity", "slot": "charm", "base": { "pct": { "cdr": 0.05 } } },
	{ "kind": "idol", "name": "Obsidian Idol", "slot": "charm", "base": { "add": { "critChance": 5.0 } } },
]

const RELICS := [
	{ "id": "sanguine_heart", "name": "The Sanguine Heart", "slot": "charm", "mods": { "pct": { "lifesteal": 0.30, "maxHP": -0.15 } } },
	{ "id": "tyrant_crown", "name": "Crown of the Tyrant", "slot": "attire", "mods": { "pct": { "meleeDmg": 0.25, "spellPower": 0.25, "armor": -0.10 }, "add": { "influence": 3.0 } } },
	{ "id": "antediluvian_fang", "name": "Fang of the Antediluvian", "slot": "charm", "mods": { "pct": { "feedYield": 0.50, "feedSpeed": 0.30, "lifesteal": 0.05 } } },
	{ "id": "mirror_nights", "name": "Mirror of Endless Nights", "slot": "charm", "mods": { "pct": { "dodge": 0.25, "cdr": 0.20, "maxHP": -0.12 } } },
	{ "id": "cauldron_stone", "name": "The Cauldron Stone", "slot": "charm", "mods": { "pct": { "spellPower": 0.55, "maxBlood": 0.25 }, "add": { "critChance": -5.0 } } },
	{ "id": "tempest_striders", "name": "Striders of the Tempest", "slot": "attire", "mods": { "pct": { "moveSpeed": 0.35, "attackSpeed": 0.20 } } },
	{ "id": "obsidian_grin", "name": "The Obsidian Grin", "slot": "weapon", "weaponBase": "magnum", "mods": { "pct": { "critChance": 0.15, "critMult": 0.50 } } },
	{ "id": "shroud_methuselah", "name": "Shroud of the Methuselah", "slot": "attire", "mods": { "pct": { "armor": 0.20, "sunResist": 0.40, "frenzyResist": 0.20 } } },
]

const AFFIXES := [
	{ "id": "sharp", "name": "Sharp", "mods": { "pct": { "meleeDmg": 0.05 } }, "scale": { "pct": { "meleeDmg": 0.004 } } },
	{ "id": "arcane", "name": "Arcane", "mods": { "pct": { "spellPower": 0.05 } }, "scale": { "pct": { "spellPower": 0.004 } } },
	{ "id": "cruel", "name": "Cruel", "mods": { "add": { "critChance": 3.0 } }, "scale": { "add": { "critChance": 0.2 } } },
	{ "id": "savage", "name": "Savage", "mods": { "pct": { "critMult": 0.10 } }, "scale": { "pct": { "critMult": 0.006 } } },
	{ "id": "swift", "name": "Swift", "mods": { "pct": { "attackSpeed": 0.04 } }, "scale": { "pct": { "attackSpeed": 0.003 } } },
	{ "id": "fleet", "name": "Fleet", "mods": { "pct": { "moveSpeed": 0.03 } }, "scale": { "pct": { "moveSpeed": 0.002 } } },
	{ "id": "vital", "name": "Vital", "mods": { "add": { "maxHP": 15.0 } }, "scale": { "add": { "maxHP": 3.0 } } },
	{ "id": "sanguine", "name": "Sanguine", "mods": { "add": { "maxBlood": 10.0 } }, "scale": { "add": { "maxBlood": 2.0 } } },
	{ "id": "leeching", "name": "Leeching", "mods": { "pct": { "lifesteal": 0.02 } }, "scale": { "pct": { "lifesteal": 0.0015 } } },
	{ "id": "warded", "name": "Warded", "mods": { "pct": { "armor": 0.03 } }, "scale": { "pct": { "armor": 0.002 } } },
	{ "id": "evasive", "name": "Evasive", "mods": { "pct": { "dodge": 0.02 } }, "scale": { "pct": { "dodge": 0.0015 } } },
	{ "id": "attuned", "name": "Attuned", "mods": { "pct": { "cdr": 0.02 } }, "scale": { "pct": { "cdr": 0.0012 } } },
	{ "id": "opulent", "name": "Opulent", "mods": { "pct": { "xpMult": 0.03 } }, "scale": { "pct": { "xpMult": 0.002 } } },
	{ "id": "predatory", "name": "Predatory", "mods": { "pct": { "feedYield": 0.05 } }, "scale": { "pct": { "feedYield": 0.003 } } },
]

const HAVEN_ROOMS := {
	"coffin": { "name": "Elder Coffin", "max": 5, "cost_base": 200, "cost_step": 280, "mods_per_level": { "pct": { "hpRegen": 0.25, "bloodRegen": 0.12 } } },
	"cellar": { "name": "Blood Cellar", "max": 5, "cost_base": 250, "cost_step": 320, "mods_per_level": { "pct": { "maxBlood": 0.06 } } },
	"shrine": { "name": "Blood Shrine", "max": 5, "cost_base": 300, "cost_step": 380, "mods_per_level": { "pct": { "xpMult": 0.05 } } },
	"barracks": { "name": "Barracks", "max": 5, "cost_base": 350, "cost_step": 420, "mods_per_level": {} },
	"sanctum": { "name": "Hidden Sanctum", "max": 5, "cost_base": 300, "cost_step": 360, "mods_per_level": { "pct": { "frenzyResist": 0.04, "sunResist": 0.04 } } },
	"workshop": { "name": "Workshop", "max": 3, "cost_base": 500, "cost_step": 600, "mods_per_level": { "pct": { "spellPower": 0.05 } } },
}

const BUSINESSES := {
	"bloodbank": { "name": "Blood Bank Front", "cost": 1200, "cash": 28, "vitae": 16 },
	"club": { "name": "Red Light Club", "cost": 1700, "cash": 70, "vitae": 6 },
	"warehouse": { "name": "Dockside Warehouse", "cost": 2200, "cash": 95, "vitae": 0 },
	"antiquities": { "name": "Old Town Antiquities", "cost": 2900, "cash": 130, "vitae": 0 },
	"casino": { "name": "Underground Casino", "cost": 4500, "cash": 210, "vitae": 0 },
}

const ECONOMY_SERVICES := {
	"refillBlood": { "name": "Vitae Pack", "cost": 80 },
	"heal": { "name": "Mend Wounds", "cost": 60 },
	"respecTree": { "name": "Reflect on the Path", "cost": 250 },
	"clearHeat": { "name": "Lay Low", "cost": 200 },
	"bribe": { "name": "Bribe Officials", "cost": 120 },
}

const COTERIE_JOBS := {
	"none": { "name": "Idle", "cash": 0, "vitae": 0 },
	"herd": { "name": "Herd", "cash": 0, "vitae": 10 },
	"fence": { "name": "Fence", "cash": 30, "vitae": 0 },
	"spy": { "name": "Spy", "cash": 12, "vitae": 0 },
	"guard": { "name": "Guard", "cash": 8, "vitae": 4 },
}

const FACTIONS := {
	"camarilla": { "name": "Camarilla", "color": "#6c7bd6" },
	"anarch": { "name": "Anarchs", "color": "#e0457b" },
	"inquis": { "name": "Second Inquisition", "color": "#ff5a5a" },
	"gang": { "name": "Street Gangs", "color": "#d6953f" },
	"police": { "name": "Police", "color": "#5a8cff" },
}

const RIVALS := { "camarilla": "anarch", "anarch": "camarilla", "police": "gang", "gang": "police", "inquis": "camarilla" }

const MISSION_TYPES := {
	"feed": { "name": "The Hunger", "icon": "feed", "color": "#c0303a", "base_xp": 160, "base_money": 120 },
	"assassinate": { "name": "Blood Debt", "icon": "kill", "color": "#a02030", "base_xp": 260, "base_money": 320 },
	"collect": { "name": "Relic Run", "icon": "relic", "color": "#c0a030", "base_xp": 200, "base_money": 200 },
	"escort": { "name": "Safe Passage", "icon": "escort", "color": "#5a9cff", "base_xp": 240, "base_money": 260 },
	"cleanse": { "name": "Purge the Nest", "icon": "cleanse", "color": "#e07020", "base_xp": 300, "base_money": 360 },
	"heist": { "name": "Vitae Heist", "icon": "cash", "color": "#30c060", "base_xp": 280, "base_money": 500 },
	"survive": { "name": "Second Inquisition", "icon": "survive", "color": "#ff4040", "base_xp": 340, "base_money": 300 },
	"courier": { "name": "Night Errand", "icon": "courier", "color": "#9a6cff", "base_xp": 180, "base_money": 160 },
}

const MISSION_MODIFIERS := [
	{ "id": "none", "bonus": 0.0 },
	{ "id": "none", "bonus": 0.0 },
	{ "id": "nokill", "name": "Leave No Trace", "tag": "NO-KILL", "bonus": 0.40 },
	{ "id": "silent", "name": "Lights Out", "tag": "STEALTH", "bonus": 0.45 },
	{ "id": "fortified", "name": "Fortified", "tag": "HEAVY", "bonus": 0.35, "harder": true },
	{ "id": "bounty", "name": "High Profile", "tag": "BOUNTY", "bonus": 0.50, "hot": true },
]

const ACHIEVEMENTS := [
	{ "id": "first_blood", "name": "First Blood", "desc": "Feed for the first time.", "stat": "feeds", "min": 1 },
	{ "id": "glutton", "name": "Insatiable", "desc": "Feed 50 times.", "stat": "feeds", "min": 50 },
	{ "id": "level10", "name": "Fledgling Rises", "desc": "Reach level 10.", "level": 10 },
	{ "id": "level25", "name": "Ancilla", "desc": "Reach level 25.", "level": 25 },
	{ "id": "level50", "name": "Methuselah", "desc": "Reach level 50.", "level": 50 },
	{ "id": "arsenal", "name": "Diverse Arts", "desc": "Learn 10 powers.", "known_powers": 10 },
	{ "id": "kills100", "name": "Reaper", "desc": "Slay 100 foes.", "stat": "kills", "min": 100 },
	{ "id": "rich", "name": "Patron of the Night", "desc": "Hold $5000.", "money": 5000 },
	{ "id": "mission10", "name": "Made Kindred", "desc": "Complete 10 missions.", "missions_done": 10 },
	{ "id": "driver", "name": "Road Reaver", "desc": "Hijack 10 vehicles.", "stat": "hijacks", "min": 10 },
	{ "id": "untouchable", "name": "Untouchable", "desc": "Clear 5 Heat stars at once.", "stat": "clearedFiveHeat", "min": 1 },
	{ "id": "humane", "name": "Golconda Seeker", "desc": "Reach level 20 with Humanity 8+.", "level": 20, "min_humanity": 8.0 },
	{ "id": "monster", "name": "Embrace the Beast", "desc": "Drop to Humanity 2 or below.", "max_humanity": 2.0 },
	{ "id": "thralls", "name": "Sire", "desc": "Bind 5 thralls.", "stat": "thralls", "min": 5 },
]

const VEHICLE_TYPES := {
	"sedan": { "width": 46.0, "height": 24.0, "max_speed": 330.0, "accel": 240.0, "handling": 2.6, "hp": 120.0 },
	"sport": { "width": 44.0, "height": 22.0, "max_speed": 460.0, "accel": 340.0, "handling": 3.2, "hp": 100.0 },
	"van": { "width": 54.0, "height": 28.0, "max_speed": 270.0, "accel": 190.0, "handling": 2.0, "hp": 180.0 },
	"police": { "width": 48.0, "height": 24.0, "max_speed": 400.0, "accel": 300.0, "handling": 3.0, "hp": 160.0, "siren": true },
	"hearse": { "width": 56.0, "height": 26.0, "max_speed": 300.0, "accel": 210.0, "handling": 2.3, "hp": 200.0 },
}

const DISTRICTS := [
	{ "id": "old_town", "name": "Old Town", "danger": 0.20 },
	{ "id": "docks", "name": "Docks", "danger": 0.45 },
	{ "id": "red_row", "name": "Red Row", "danger": 0.30 },
	{ "id": "financial", "name": "Financial District", "danger": 0.55 },
]

const FIRST_NAMES := ["Lucretia", "Dorian", "Vasilica", "Mireille", "Caine", "Octavia", "Sava", "Isolde", "Marquel", "Drusilla", "Tariq", "Yvette", "Bishop", "Carmilla", "Strauss", "Nadia", "Velvet", "Gideon", "Pisha", "Jeanette"]
const LAST_NAMES := ["Ash", "Vane", "Mercurio", "Voerman", "LaCroix", "Nostromo", "Black", "Stryker", "Grout", "Andrei", "Ka", "Holloway", "Vermeer", "Cross", "Dane", "Rourke"]

static func canonical_power_id(power_id: String) -> String:
	return String(LEGACY_POWER_ALIASES.get(power_id, power_id))
