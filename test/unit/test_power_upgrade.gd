## test_power_upgrade.gd — leveling visibly UPGRADES the kit: a stronger power replaces a slot, and
## the hotbar (which reads meta.slots) changes. "Fun levelup, changing gameplay with better powers."
extends GutTest


func test_leveling_upgrades_slots_and_learns_the_powers() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	assert_eq(String(sim.meta.slots[1]), "pot_slam", "slot 2 starts as Earthshock")
	assert_eq(String(sim.meta.slots[7]), "bs_bolt", "slot 8 starts as Blood Bolt")

	sim.meta.gain_xp(100000, sim)   # vault past level 8
	assert_true(sim.meta.level >= 8, "reached the upgrade levels")
	assert_eq(String(sim.meta.slots[1]), "pot_quake", "L3 upgraded slot 2 to Earthquake")
	assert_eq(String(sim.meta.slots[7]), "bs_storm", "L4 upgraded slot 8 to Blood Storm")
	assert_true(sim.meta.knows_power("pot_quake") and sim.meta.knows_power("bs_storm"), "learned the upgraded powers")


func test_upgrade_is_deterministic() -> void:
	var a := VCSim.new(); a.new_game(42, "brujah"); a.meta.gain_xp(100000, a)
	var b := VCSim.new(); b.new_game(42, "brujah"); b.meta.gain_xp(100000, b)
	assert_eq(a.meta.slots, b.meta.slots, "same XP -> same upgraded loadout")
