## Shared material and silhouette palettes for NocturneEntityRig.
extends RefCounted


static func make(entity: SimEntity) -> Dictionary:
	var weapon := String(entity.tags.get("weapon", ""))
	var variant := absi(entity.id * 17 + 11) % 4
	if entity.kind == "player":
		var player := _base(
			Color("#252631"),
			Color("#c9bbb2"),
			Color("#a91e31"),
			0.96,
			1.06,
			true,
			"claws",
			"bandolier"
		)
		player["rim"] = Color(0.56, 0.66, 0.78, 0.62)
		player["eye"] = Color("#d7cbc2")
		return player
	match entity.faction:
		"civ":
			var coats := [Color("#494941"), Color("#39434b"), Color("#503d35"), Color("#3e4146")]
			var skins := [Color("#c3a58d"), Color("#a77e63"), Color("#d0b19a"), Color("#8e6652")]
			return _base(
				coats[variant],
				skins[variant],
				Color("#786f61"),
				0.90 + variant * 0.035,
				0.96 + (variant % 2) * 0.05,
				variant == 2,
				"",
				"satchel" if variant == 1 else ""
			)
		"gang":
			return _base(
				Color("#302922"),
				Color("#ad8465"),
				Color("#7e2930"),
				1.10 if entity.type_id == "thug" else 1.02,
				1.0,
				variant == 3,
				weapon if weapon != "" else "knife",
				"bandolier"
			)
		"police":
			var police := _base(
				Color("#1d2b3d"),
				Color("#b99a83"),
				Color("#758ca8"),
				1.19 if entity.type_id == "swat" else 1.08,
				1.02,
				entity.type_id == "swat",
				weapon if weapon != "" else "baton",
				"badge"
			)
			police["rim"] = Color(0.53, 0.63, 0.77, 0.55)
			return police
		"inquis":
			var inquis := _base(
				Color("#29282a"),
				Color("#c2b6a2"),
				Color("#8d7a55"),
				1.26 if entity.type_id == "elder" else 1.10,
				1.08,
				true,
				weapon if weapon != "" else "stake",
				"cross"
			)
			inquis["rim"] = Color(0.72, 0.70, 0.64, 0.50)
			return inquis
		"player":
			return _base(
				Color("#31263b"),
				Color("#b99fbb"),
				Color("#7b4a96"),
				0.98,
				1.03,
				true,
				weapon if weapon != "" else "knife",
				"cross"
			)
	return _base(Color("#404046"), Color("#aa9586"), Color("#6e6872"), 1.0, 1.0, false, weapon, "")


static func resonance_color(value: String) -> Color:
	match value:
		"sanguine":
			return Color("#98404f")
		"choleric":
			return Color("#9b6537")
		"melancholic":
			return Color("#566784")
		"phlegmatic":
			return Color("#527b69")
	return Color("#6d6d73")


static func projectile_color(damage_type: String, kind: String) -> Color:
	if kind.contains("blood") or damage_type in ["blood", "bleed"]:
		return Color("#b20f2b")
	if damage_type == "poison" or kind.contains("poison"):
		return Color("#658b45")
	if damage_type in ["burn", "fire"] or kind.contains("fire"):
		return Color("#c66b2e")
	if damage_type == "shock" or kind.contains("shock"):
		return Color("#7aa6c7")
	if kind.contains("shadow"):
		return Color("#6d4a86")
	return Color("#b8b0a0")


static func _base(
	coat: Color,
	skin: Color,
	accent: Color,
	build: float,
	stature: float,
	hooded: bool,
	weapon: String,
	gear: String
) -> Dictionary:
	return {
		"coat": coat,
		"coat_shadow": coat.darkened(0.48),
		"pants": coat.darkened(0.34),
		"boot": Color("#090a0e"),
		"skin": skin,
		"hair": Color("#211c1b"),
		"hood": coat.darkened(0.34),
		"rim": Color(0.62, 0.66, 0.72, 0.48),
		"accent": accent,
		"metal": Color("#a7adb4"),
		"leather": Color("#3b2f29"),
		"eye": Color("#392f2b"),
		"build": build,
		"stature": stature,
		"hooded": hooded,
		"weapon": weapon,
		"gear": gear,
	}
