## SpellArchetype.gd — derives a presentation ARCHETYPE for a power from the data it already has.
##
## The Cast Contract keystone: ~24 of 36 powers rendered as one red ring because the cast cue was
## blind to what the spell did. This zero-authoring classifier keys every power to a visual archetype
## so SpellFX can render a DISTINCT anticipation -> impact -> aftermath per kind. Pure function of the
## def dict (no RNG, no state, no mutation) — deterministic and safe to call from anywhere.
extends RefCounted
class_name SpellArchetype


## One of: TETHER, PROJECTILE, NOVA, SELF_BUFF, DEBUFF, DASH, CONE, GROUND_AOE, ENTITY_TARGET.
## (WELL / BEAM / DOT_ZONE arrive with the new powers that introduce those verbs.)
static func archetype_of(def: Dictionary) -> String:
	if def.has("pull"):
		return "TETHER"          # drag a body to you (shd_arms) — a physics verb
	if def.has("speed"):
		return "PROJECTILE"      # a travelling bolt (bs_bolt)
	if def.has("bolts"):
		return "NOVA"            # a radial burst of bolts (bs_storm)
	if str(def.get("type", "active")) == "toggle":
		return "SELF_BUFF"       # toggled auras never paint a ground ring
	# Self-only effects — heals, armor, shields, stealth, heat-clears: body-hugging, no ground ring.
	if def.has("heal") or def.has("armor") or def.has("shield") or def.has("dodge") \
			or def.has("heat_reduction") or def.has("upkeep"):
		return "SELF_BUFF"
	if def.has("damage_bonus"):
		return "DEBUFF"          # curse / weaken one target (aus_mark)
	if def.has("iframes"):
		return "DASH"            # a blink / lunge (cel_dash)
	if def.has("arc"):
		return "CONE"            # a frontal cone (dom_mesmer)
	var has_range := def.has("range")
	var has_radius := def.has("radius")
	var has_damage := def.has("damage")
	if has_range and has_radius:
		return "GROUND_AOE"      # an area dropped at a distance (pot_charge, shd_tendril)
	if has_range:
		return "ENTITY_TARGET"   # a single locked target at range (dom_command, bs_theft, bs_cauldron)
	if has_radius and has_damage:
		return "GROUND_AOE"      # a slam centered on you (pot_slam, pot_quake)
	if has_radius:
		return "NOVA"            # a radial pulse of status (pre_dread, pre_entr, dem_confuse)
	return "SELF_BUFF"           # durational buffs with no footprint (pro_beast, pre_majesty, ...)


## Hex color string for a power, from its discipline palette.
static func color_of(def: Dictionary) -> String:
	var disc := str(def.get("discipline", ""))
	var d: Dictionary = GameCatalog.DISCIPLINES.get(disc, {})
	return str(d.get("color", "#c01028"))


## Coarse damage-type tag used for material/sound selection in presentation.
static func damage_type_of(def: Dictionary) -> String:
	match str(def.get("discipline", "")):
		"sorcery": return "blood"
		"dark": return "shadow"
		"potence": return "physical"
		"presence", "dominate", "auspex": return "psychic"
		_: return "physical"
