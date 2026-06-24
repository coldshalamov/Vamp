## CharacterVisualProfile.gd — deterministic visual identity for every actor archetype.
##
## This file deliberately contains no gameplay state and no random calls.  A profile is a
## compact art-direction record consumed by EntityRenderer's continuous procedural rig.
## Variation is derived from the stable entity id, so replay captures and screenshots are
## repeatable while crowds still avoid the cloned-pawn look.
extends RefCounted
class_name CharacterVisualProfile


static func for_entity(e: SimEntity) -> Dictionary:
	var profile := _base_profile()
	var type_id := String(e.type_id)
	var faction := String(e.faction)

	if e.kind == "player" or type_id == "player":
		profile.merge({
			"coat": Color("#20242d"), "coat_dark": Color("#0d1016"),
			"cloth": Color("#151921"), "pants": Color("#0b0e13"),
			"skin": Color("#c8bbb0"), "metal": Color("#78808c"),
			"accent": Color("#a90f24"), "rim": Color("#91a6ca"),
			"build": 0.96, "stature": 1.08, "shoulders": 1.08,
			"coat_length": 1.26, "hooded": true, "masked": true,
			"armored": false, "eyes": true, "claws": true,
			"weapon": "claws", "silhouette": "predator",
		}, true)
		return _apply_variation(profile, e.id)

	match type_id:
		"thug":
			profile.merge({
				"coat": Color("#332b24"), "coat_dark": Color("#15110e"),
				"cloth": Color("#251e19"), "pants": Color("#11100e"),
				"skin": Color("#a67c5b"), "metal": Color("#726b61"),
				"accent": Color("#7e1d23"), "build": 1.15,
				"shoulders": 1.13, "weapon": "bat", "silhouette": "bruiser",
			}, true)
		"gunner":
			profile.merge({
				"coat": Color("#29251f"), "coat_dark": Color("#11100d"),
				"cloth": Color("#1d1a17"), "pants": Color("#0e0e0d"),
				"skin": Color("#a98268"), "metal": Color("#77736d"),
				"accent": Color("#7b2026"), "build": 1.02,
				"weapon": "pistol", "silhouette": "street_gunner",
			}, true)
		"cop":
			profile.merge({
				"coat": Color("#18253a"), "coat_dark": Color("#09111e"),
				"cloth": Color("#111c2c"), "pants": Color("#0b1018"),
				"skin": Color("#b79882"), "metal": Color("#8993a2"),
				"accent": Color("#607ca9"), "rim": Color("#a7bada"),
				"build": 1.05, "armored": true, "weapon": "pistol",
				"silhouette": "officer",
			}, true)
		"swat":
			profile.merge({
				"coat": Color("#151b25"), "coat_dark": Color("#070a0f"),
				"cloth": Color("#10151d"), "pants": Color("#080b10"),
				"skin": Color("#aa9280"), "metal": Color("#6f7884"),
				"accent": Color("#5d789d"), "rim": Color("#8fa6c5"),
				"build": 1.18, "stature": 1.04, "shoulders": 1.22,
				"armored": true, "helmeted": true, "masked": true,
				"weapon": "rifle", "silhouette": "heavy_tactical",
			}, true)
		"hunter":
			profile.merge({
				"coat": Color("#24242a"), "coat_dark": Color("#0b0b0f"),
				"cloth": Color("#18181d"), "pants": Color("#0c0c10"),
				"skin": Color("#c4b8a5"), "metal": Color("#aca58f"),
				"accent": Color("#8d6d3a"), "rim": Color("#b9b7aa"),
				"build": 1.08, "stature": 1.08, "shoulders": 1.10,
				"coat_length": 1.14, "hooded": true, "masked": true,
				"armored": true, "weapon": "rifle", "silhouette": "hunter",
			}, true)
		"elder":
			profile.merge({
				"coat": Color("#17171d"), "coat_dark": Color("#050507"),
				"cloth": Color("#101016"), "pants": Color("#07070a"),
				"skin": Color("#d4cdc0"), "metal": Color("#b6ad94"),
				"accent": Color("#a48045"), "rim": Color("#d2c8ad"),
				"build": 1.22, "stature": 1.16, "shoulders": 1.20,
				"coat_length": 1.35, "hooded": true, "masked": true,
				"armored": true, "weapon": "rifle", "silhouette": "elder_hunter",
			}, true)
		"thrall":
			profile.merge({
				"coat": Color("#282331"), "coat_dark": Color("#0e0b13"),
				"cloth": Color("#1c1722"), "pants": Color("#0d0b11"),
				"skin": Color("#b29bab"), "metal": Color("#77717f"),
				"accent": Color("#6f3d79"), "rim": Color("#a79bb5"),
				"build": 0.98, "weapon": "pistol", "hooded": true,
				"silhouette": "thrall",
			}, true)
		"rat":
			profile.merge({
				"animal": true, "coat": Color("#35302e"),
				"coat_dark": Color("#151211"), "skin": Color("#8e6e68"),
				"accent": Color("#4d3638"), "build": 0.66,
				"stature": 0.45, "silhouette": "rat", "weapon": "",
			}, true)
		_:
			if faction == "civ":
				var civ_variant := e.id % 4
				var civs := [
					{ "coat": Color("#4a4640"), "coat_dark": Color("#23201d"), "cloth": Color("#393530"), "pants": Color("#242321"), "skin": Color("#b99478"), "accent": Color("#655e56") },
					{ "coat": Color("#38434f"), "coat_dark": Color("#182029"), "cloth": Color("#2b3540"), "pants": Color("#1d252c"), "skin": Color("#c3a38d"), "accent": Color("#5f6d7b") },
					{ "coat": Color("#514038"), "coat_dark": Color("#251c18"), "cloth": Color("#3e302a"), "pants": Color("#251d19"), "skin": Color("#a97d62"), "accent": Color("#6d5549") },
					{ "coat": Color("#41403b"), "coat_dark": Color("#1c1c1a"), "cloth": Color("#31302d"), "pants": Color("#1e1f1d"), "skin": Color("#d0b09a"), "accent": Color("#66635d") },
				]
				profile.merge(civs[civ_variant], true)
				profile["build"] = 0.90 + float((e.id * 17) % 19) * 0.012
				profile["stature"] = 0.94 + float((e.id * 11) % 17) * 0.010
				profile["hooded"] = (e.id % 5) == 0
				profile["silhouette"] = "civilian"
			elif faction == "gang":
				profile["weapon"] = "bat"
			elif faction == "police":
				profile["weapon"] = "pistol"
				profile["armored"] = true
			elif faction == "inquis":
				profile["weapon"] = "rifle"
				profile["hooded"] = true
				profile["armored"] = true

	return _apply_variation(profile, e.id)


static func _base_profile() -> Dictionary:
	return {
		"coat": Color("#3d4046"),
		"coat_dark": Color("#181a1e"),
		"cloth": Color("#2b2e33"),
		"pants": Color("#17191d"),
		"skin": Color("#b99d87"),
		"metal": Color("#777b82"),
		"accent": Color("#6b6260"),
		"rim": Color("#8e9db4"),
		"build": 1.0,
		"stature": 1.0,
		"shoulders": 1.0,
		"coat_length": 0.86,
		"head_scale": 1.0,
		"hooded": false,
		"helmeted": false,
		"masked": false,
		"armored": false,
		"eyes": false,
		"claws": false,
		"animal": false,
		"weapon": "",
		"silhouette": "human",
	}


static func _apply_variation(profile: Dictionary, entity_id: int) -> Dictionary:
	var out := profile.duplicate(true)
	# Small deterministic offsets break repetition without corrupting faction readability.
	var shade := (float((entity_id * 37) % 13) - 6.0) * 0.008
	var coat: Color = out["coat"]
	var cloth: Color = out["cloth"]
	out["coat"] = coat.lightened(shade) if shade >= 0.0 else coat.darkened(-shade)
	out["cloth"] = cloth.lightened(shade * 0.7) if shade >= 0.0 else cloth.darkened(-shade * 0.7)
	out["head_scale"] = float(out.get("head_scale", 1.0)) * (0.95 + float((entity_id * 23) % 9) * 0.012)
	out["stance_bias"] = (float((entity_id * 31) % 11) - 5.0) * 0.012
	return out
