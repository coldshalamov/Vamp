## The Cast Contract keystone — proves the power.cast cue is no longer blind.
##
## Before: every power emitted {power_id, name, pos} so presentation drew one red ring for ~24 of 36
## powers. Now the cue carries archetype + aimed target_pos + color, so SpellFX can render a distinct
## effect per kind, at the cursor. This is presentation-only (cue_events is not in state_hash), so the
## 20-run determinism suite stays green — guarded separately by test_determinism.
extends GutTest

const VALID := ["TETHER", "PROJECTILE", "NOVA", "SELF_BUFF", "DEBUFF", "DASH", "CONE", "GROUND_AOE", "ENTITY_TARGET"]


func test_every_power_classifies_to_a_valid_archetype() -> void:
	var seen := {}
	for pid in GameCatalog.POWERS:
		var def: Dictionary = GameCatalog.POWERS[pid]
		var a := SpellArchetype.archetype_of(def)
		assert_true(VALID.has(a), "%s -> unexpected archetype %s" % [pid, a])
		seen[a] = true
	# The whole point is variety: the 36 powers must span a real spread, not collapse to one bucket.
	assert_true(seen.size() >= 6, "expected >=6 distinct archetypes, got %s" % str(seen.keys()))


func test_spot_check_archetypes() -> void:
	var p := GameCatalog.POWERS
	assert_eq(SpellArchetype.archetype_of(p["bs_bolt"]), "PROJECTILE")
	assert_eq(SpellArchetype.archetype_of(p["pot_slam"]), "GROUND_AOE")
	assert_eq(SpellArchetype.archetype_of(p["dom_mesmer"]), "CONE")
	assert_eq(SpellArchetype.archetype_of(p["aus_mark"]), "DEBUFF")
	assert_eq(SpellArchetype.archetype_of(p["shd_arms"]), "TETHER")
	assert_eq(SpellArchetype.archetype_of(p["cel_haste"]), "SELF_BUFF")
	assert_eq(SpellArchetype.archetype_of(p["cel_dash"]), "DASH")
	assert_eq(SpellArchetype.archetype_of(p["pre_dread"]), "NOVA")
	assert_eq(SpellArchetype.archetype_of(p["dom_command"]), "ENTITY_TARGET")


func test_cast_cue_carries_the_contract() -> void:
	var sim := VCSim.new()
	sim.new_game(7, "brujah")
	sim.player.behaviour.set("blood", 100.0)
	# Aim well to the right of the caster, then cast a ranged projectile.
	var aim := InputAction.new(InputAction.Kind.AIM)
	aim.vector = sim.player.pos + Vector2(150.0, 0.0)
	aim.held = true
	sim.apply_input(aim)
	var cast := InputAction.new(InputAction.Kind.POWER)
	cast.action_id = "bs_bolt"
	sim.apply_input(cast)

	var payload := _last_cast(sim)
	assert_false(payload.is_empty(), "no power.cast cue was emitted")
	assert_eq(payload.get("archetype"), "PROJECTILE", "bolt should classify as PROJECTILE")
	assert_true(payload.has("target_pos"), "cue must carry target_pos")
	assert_true(payload.has("color"), "cue must carry a discipline color")
	assert_eq(String(payload.get("color")), "#e0203f", "sorcery color expected")
	# A ranged cast must aim at the cursor, NOT collapse to the caster (the old behavior).
	var tp: Vector2 = payload["target_pos"]
	assert_gt(tp.distance_to(sim.player.pos), 60.0, "ranged target_pos collapsed onto the caster")
	sim.queue_free()


func test_self_buff_targets_the_caster() -> void:
	var sim := VCSim.new()
	sim.new_game(7, "brujah")
	sim.player.behaviour.set("blood", 100.0)
	var aim := InputAction.new(InputAction.Kind.AIM)
	aim.vector = sim.player.pos + Vector2(150.0, 0.0)
	aim.held = true
	sim.apply_input(aim)
	var cast := InputAction.new(InputAction.Kind.POWER)
	cast.action_id = "for_mend"   # a self heal: no range, so it must resolve to the caster
	sim.apply_input(cast)

	var payload := _last_cast(sim)
	assert_false(payload.is_empty(), "no power.cast cue was emitted")
	assert_eq(payload.get("archetype"), "SELF_BUFF")
	var tp: Vector2 = payload["target_pos"]
	assert_lt(tp.distance_to(sim.player.pos), 1.0, "a self power must paint on the caster, not the cursor")
	sim.queue_free()


func _last_cast(sim: VCSim) -> Dictionary:
	for i in range(sim.cue_events.size() - 1, -1, -1):
		if String(sim.cue_events[i]["id"]) == "power.cast":
			return sim.cue_events[i]["payload"]
	return {}
