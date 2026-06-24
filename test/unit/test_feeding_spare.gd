## test_feeding_spare.gd — the Verdict (B3): RELEASING mid-feed must spare the victim. The spare path
## leaves a LIVING, downed, fed-on mortal (not a corpse) and announces "feed.spare" with a {pos}.
## The kill path (hold past the Brink) is covered by test_feeding_visceral.gd; this is its mirror image —
## proof that mercy is a real, reachable gameplay outcome, not just a code branch with zero coverage.
extends GutTest

const DT := 1.0 / 60.0


func _nearest_civ(sim: VCSim, player: SimEntity) -> SimEntity:
	for e in sim.entities:
		if e != null and e != player and e.kind == "npc" and e.faction == "civ" and not e.dead:
			return e
	return null


func test_releasing_midfeed_spares_a_living_downed_victim() -> void:
	var sim := VCSim.new()
	sim.new_game(1919, "brujah")
	var player: SimEntity = sim.player
	var pb: SimPlayer = player.behaviour
	var civ: SimEntity = _nearest_civ(sim, player)
	assert_not_null(civ, "expected a civilian to feed on")
	if civ == null:
		sim.queue_free()
		return
	player.pos = civ.pos + Vector2(8.0, 0.0)

	# Bite and hold — the drain runs while FEED is held.
	var feed := InputAction.new(InputAction.Kind.FEED)
	feed.held = true
	sim.apply_input(feed)

	# Tick while holding until enough vitae is drained to make the release a SPARE (>= 8.0,
	# the _try_spare_feed threshold), but well short of the lethal Brink (1.2 * blood_yield).
	var released := false
	for _t in range(300):
		sim.tick_sim(DT)
		if pb.feeding_target_id != 0 and pb.feed_drained >= 8.0:
			var release := InputAction.new(InputAction.Kind.FEED)
			release.held = false
			sim.apply_input(release)
			released = true
			break
		if civ.dead:
			break
	assert_true(released, "drained enough to reach the spare threshold without killing")

	# Let the spare finish settle.
	for _t in range(5):
		sim.tick_sim(DT)

	assert_false(civ.dead, "releasing mid-feed must NOT kill — the victim lives")
	assert_true(civ.downed, "a spared victim is left downed, not standing")
	assert_eq(int(pb.feeding_target_id), 0, "the feed ended on release")
	assert_true(bool(civ.tags.get("fed_on", false)), "the spared victim is marked fed_on (a witness/evidence)")

	# The Verdict cue fired with a position, and no kill cue was emitted for this victim.
	var spared := false
	var killed := false
	for rec in sim.cue_events:
		var id := String(rec.get("id", ""))
		if id == "feed.spare":
			spared = true
			assert_true(rec.get("payload", {}).has("pos"), "feed.spare carries a {pos} for the present layer")
		elif id == "feed.kill":
			killed = true
	assert_true(spared, "the spare verdict emitted feed.spare")
	assert_false(killed, "no feed.kill fired on a spare")

	sim.queue_free()
