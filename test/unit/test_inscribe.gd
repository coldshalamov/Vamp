## test_inscribe.gd — Blood Grammar INSCRIBE atom: paint a blood-sigil that rewrites a local rule.
## "FEAR IS DAMAGE" sears frightened enemies inside the sigil. Deterministic.
extends GutTest

const DT := 1.0 / 60.0


func _hostile(sim) -> SimEntity:
	for e in sim.entities:
		if e != sim.player and e.kind == "npc" and e.hostile_to_player and not e.dead:
			return e
	return null


func test_fear_sigil_sears_feared_enemies() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var thug := _hostile(sim)
	assert_not_null(thug, "a hostile to frighten")
	thug.apply_status("fear", 300, {})
	var hp0: float = thug.hp
	sim.inscribe_sigil(thug.pos, "fear_is_damage", 400.0, 360)
	for i in range(40):
		sim.tick_sim(DT)
	assert_true(thug.hp < hp0, "a feared enemy in the sigil is seared (%.1f -> %.1f)" % [hp0, thug.hp])


func test_player_inscribe_spends_vitae_and_paints_a_sigil() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var pb: SimPlayer = sim.player.behaviour
	pb.blood = 60.0
	var b0: float = pb.blood
	pb.inscribe(sim)
	assert_eq(sim.sigils.size(), 1, "a sigil was painted")
	assert_true(pb.blood < b0, "inscribing spent vitae as ink (%.1f -> %.1f)" % [b0, pb.blood])


func test_sigil_is_deterministic() -> void:
	assert_eq(_run(), _run(), "same sigil + ticks -> identical sear")


func _run() -> float:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var thug := _hostile(sim)
	thug.apply_status("fear", 300, {})
	sim.inscribe_sigil(thug.pos, "fear_is_damage", 400.0, 360)
	for i in range(40):
		sim.tick_sim(DT)
	return thug.hp
