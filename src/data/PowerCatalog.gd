## PowerCatalog.gd -- deterministic Discipline content for the backend slice.
##
## This is pure data. The frontend can read these ids/names/descriptions for HUD and
## localization, while SimPlayer owns the actual state mutation when a power is cast.
extends RefCounted
class_name PowerCatalog

const POWERS := {
	"cel_dash": {
		"name": "Quicken",
		"discipline": "celerity",
		"cost": 8.0,
		"cooldown": 48,
		"range": 150.0,
		"cue": "power.celerity.quicken",
		"description": "Blink forward with brief invulnerability."
	},
	"cel_haste": {
		"name": "Fleetness",
		"discipline": "celerity",
		"cost": 4.0,
		"cooldown": 30,
		"duration": 240,
		"cue": "power.celerity.fleetness",
		"description": "Move and strike faster for a short burst."
	},
	"pot_slam": {
		"name": "Earthshock",
		"discipline": "potence",
		"cost": 12.0,
		"cooldown": 120,
		"radius": 112.0,
		"damage": 26.0,
		"stun": 36,
		"cue": "power.potence.slam",
		"description": "Stun and damage nearby enemies."
	},
	"pot_charge": {
		"name": "Shoulder Through",
		"discipline": "potence",
		"cost": 10.0,
		"cooldown": 96,
		"range": 135.0,
		"radius": 34.0,
		"damage": 30.0,
		"stun": 18,
		"cue": "power.potence.charge",
		"description": "Crash forward through the first target in your path."
	},
	"for_mend": {
		"name": "Mend the Dead Flesh",
		"discipline": "fortitude",
		"cost": 14.0,
		"cooldown": 150,
		"heal": 34.0,
		"cue": "power.fortitude.mend",
		"description": "Spend vitae to recover health."
	},
	"for_stone": {
		"name": "Stone Skin",
		"discipline": "fortitude",
		"cost": 10.0,
		"cooldown": 180,
		"duration": 300,
		"armor": 0.35,
		"cue": "power.fortitude.stone_skin",
		"description": "Reduce incoming damage for a short time."
	},
	"obf_cloak": {
		"name": "Cloak of Shadows",
		"discipline": "obfuscate",
		"cost": 8.0,
		"cooldown": 45,
		"duration": 300,
		"cue": "power.obfuscate.cloak",
		"description": "Become difficult to perceive until you attack."
	},
	"obf_vanish": {
		"name": "Vanish",
		"discipline": "obfuscate",
		"cost": 16.0,
		"cooldown": 240,
		"duration": 180,
		"heat_reduction": 0.8,
		"cue": "power.obfuscate.vanish",
		"description": "Break pursuit and reduce Heat."
	},
	"aus_mark": {
		"name": "Predator's Mark",
		"discipline": "auspex",
		"cost": 8.0,
		"cooldown": 90,
		"range": 360.0,
		"duration": 360,
		"damage_bonus": 0.35,
		"cue": "power.auspex.mark",
		"description": "Reveal and weaken one target."
	},
	"dom_mesmerize": {
		"name": "Mesmerize",
		"discipline": "dominate",
		"cost": 10.0,
		"cooldown": 120,
		"range": 150.0,
		"arc": 1.35,
		"stun": 180,
		"cue": "power.dominate.mesmerize",
		"description": "Freeze targets in front of you."
	},
	"dom_forget": {
		"name": "Forgetful Mind",
		"discipline": "dominate",
		"cost": 18.0,
		"cooldown": 300,
		"heat_reduction": 1.2,
		"cue": "power.dominate.forget",
		"description": "Erase witnesses and lower Heat."
	},
	"pre_dread": {
		"name": "Dread Gaze",
		"discipline": "presence",
		"cost": 12.0,
		"cooldown": 150,
		"radius": 165.0,
		"fear": 210,
		"cue": "power.presence.dread",
		"description": "Send nearby mortals and enemies fleeing."
	},
	"bs_bolt": {
		"name": "Blood Bolt",
		"discipline": "blood_sorcery",
		"cost": 9.0,
		"cooldown": 42,
		"range": 340.0,
		"damage": 24.0,
		"bleed": 180,
		"cue": "power.blood_sorcery.bolt",
		"description": "Strike the nearest aimed target with blood magic."
	}
}

static func ids() -> Array:
	return POWERS.keys()

static func get_def(power_id: String) -> Dictionary:
	if not POWERS.has(power_id):
		return {}
	return (POWERS[power_id] as Dictionary).duplicate(true)
