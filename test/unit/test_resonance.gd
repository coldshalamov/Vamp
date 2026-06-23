## test_resonance.gd — Blood Grammar Resonance: prey have a humour; feeding grants a matching buff;
## the buffs measurably change combat (choleric melee). Deterministic (resonance from id-hash, not RNG).
extends GutTest

const DT := 1.0 / 60.0


func test_npcs_have_a_resonance() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var checked := 0
	for e in sim.entities:
		if e.kind == "npc":
			assert_true(e.resonance in ["sanguine", "choleric", "melancholic", "phlegmatic"], "npc has a resonance humour")
			checked += 1
	assert_true(checked > 0, "there are npcs to check")


func test_feeding_grants_the_victims_resonance_buff() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var p: SimEntity = sim.player
	var pb: SimPlayer = p.behaviour
	var victim: SimEntity = null
	for e in sim.entities:
		if e != p and e.kind == "npc" and e.faction == "civ":
			victim = e
			break
	assert_not_null(victim, "a civilian to feed on")
	var hum: String = victim.resonance
	p.pos = victim.pos - Vector2(20, 0)
	pb.blood = 30.0
	var feed := InputAction.new(InputAction.Kind.FEED)
	feed.held = true
	sim.apply_input(feed)
	for i in range(400):
		var was := pb.feeding_target_id != 0
		sim.tick_sim(DT)
		if was and pb.feeding_target_id == 0:
			break
	assert_true(pb.buffs.has("res_" + hum), "feeding a %s victim granted res_%s" % [hum, hum])


func test_choleric_resonance_raises_melee_damage() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var pb: SimPlayer = sim.player.behaviour
	var t1: SimEntity = sim.spawn_npc("ped", Vector2(400, 400), {})
	var hp0: float = t1.hp
	sim.damage_entity(sim.player, t1, 20.0, { "damage_type": "physical" })
	var base: float = hp0 - t1.hp

	pb.buffs["res_choleric"] = { "ticks": 1800, "melee": 0.25 }
	var t2: SimEntity = sim.spawn_npc("ped", Vector2(420, 400), {})
	var hp2: float = t2.hp
	sim.damage_entity(sim.player, t2, 20.0, { "damage_type": "physical" })
	var boosted: float = hp2 - t2.hp
	assert_true(boosted > base, "choleric melee deals more (%.1f > %.1f)" % [boosted, base])
