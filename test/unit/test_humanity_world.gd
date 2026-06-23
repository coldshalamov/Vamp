## test_humanity_world.gd — Humanity is lived state, not a number (Wave 1 #3).
##
## An innocent kill must (a) drop Humanity, (b) make nearby mortals recoil and flee within the
## same tick (emitting npc.flinch), and (c) low Humanity must raise the player's exposure. All
## deterministic — the reaction iterates entities by distance, no RNG.
extends GutTest

const DT := 1.0 / 60.0


func test_innocent_kill_makes_the_world_react() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var p: SimEntity = sim.player
	var pb: SimPlayer = p.behaviour
	var civs: Array = []
	for e in sim.entities:
		if e != p and e.kind == "npc" and e.faction == "civ":
			civs.append(e)
	assert_true(civs.size() >= 2, "the slice has at least two civilians")
	var victim: SimEntity = civs[0]
	var bystander: SimEntity = civs[1]
	bystander.pos = victim.pos + Vector2(80, 0)   # within the 200px reaction radius
	p.pos = victim.pos - Vector2(20, 0)
	var hum0: float = pb.humanity

	var feed := InputAction.new(InputAction.Kind.FEED)
	feed.held = true
	sim.apply_input(feed)
	var killed := false
	for i in range(600):
		var was_feeding := pb.feeding_target_id != 0
		sim.tick_sim(DT)
		if was_feeding and pb.feeding_target_id == 0:
			killed = true
			break

	assert_true(killed, "the held feed ran to a lethal finish")
	assert_true(victim.dead, "the innocent victim was killed")
	assert_true(pb.humanity < hum0, "Humanity dropped on the innocent kill (%.2f < %.2f)" % [pb.humanity, hum0])
	assert_eq(bystander.ai_state, "flee", "a nearby mortal flees the monster")
	var flinches := 0
	for rec in sim.cue_events:
		if String(rec.get("id", "")) == "npc.flinch":
			flinches += 1
	assert_true(flinches > 0, "npc.flinch fired — the world recoiled")


func test_low_humanity_raises_exposure() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var pb: SimPlayer = sim.player.behaviour
	pb.humanity = 7.0
	var e_high: float = pb._compute_exposure(sim)
	pb.humanity = 1.0
	var e_low: float = pb._compute_exposure(sim)
	assert_true(e_low > e_high, "low Humanity reads as more exposed (%.2f > %.2f)" % [e_low, e_high])
