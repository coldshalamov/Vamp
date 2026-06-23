## test_xp_leveling.gd — kills/feeds now grant XP (they didn't before, so the player never levelled).
extends GutTest


func _hostile(sim) -> SimEntity:
	for e in sim.entities:
		if e != sim.player and e.kind == "npc" and e.hostile_to_player and not e.dead:
			return e
	return null


func test_killing_grants_xp() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var xp0: int = sim.meta.xp_total
	var thug := _hostile(sim)
	assert_not_null(thug, "found a hostile to kill")
	sim.damage_entity(sim.player, thug, 9999.0, { "cue": "damage.dealt" })
	assert_true(thug.dead, "the hostile died")
	assert_true(sim.meta.xp_total > xp0, "killing granted XP (%d -> %d)" % [xp0, sim.meta.xp_total])


func test_gain_xp_levels_up() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var lvl0: int = sim.meta.level
	sim.meta.gain_xp(100000, sim)
	assert_true(sim.meta.level > lvl0, "enough XP raises the level (%d -> %d)" % [lvl0, sim.meta.level])


func test_xp_gain_is_deterministic() -> void:
	var a := VCSim.new(); a.new_game(42, "brujah")
	var b := VCSim.new(); b.new_game(42, "brujah")
	a.damage_entity(a.player, _hostile(a), 9999.0, { "cue": "damage.dealt" })
	b.damage_entity(b.player, _hostile(b), 9999.0, { "cue": "damage.dealt" })
	assert_eq(a.meta.xp_total, b.meta.xp_total, "same kill -> same XP")
	assert_eq(a.meta.level, b.meta.level, "same kill -> same level")
