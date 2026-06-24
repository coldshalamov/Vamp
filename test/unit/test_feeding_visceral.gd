## Visceral feeding — proves a lethal drink leaves a corpse-white victim and sprays REAL blood into
## the SPILL grid (the answer to "a blob gulps a blob, then a red oval"). Deterministic: pallor + the
## Brink flag are tags/hashed state; blood is the integer SPILL layer.
extends GutTest

const DT := 1.0 / 60.0


func test_lethal_feed_sprays_real_blood_and_drains_to_corpse_white() -> void:
	var sim := VCSim.new()
	sim.new_game(1919, "brujah")
	var civ: SimEntity = null
	for e in sim.entities:
		if e != null and e.faction == "civ" and not e.dead:
			civ = e
			break
	assert_not_null(civ, "expected a civilian to feed on")
	if civ == null:
		sim.queue_free()
		return
	sim.player.pos = civ.pos + Vector2(8.0, 0.0)
	var feed := InputAction.new(InputAction.Kind.FEED)
	feed.held = true
	sim.apply_input(feed)
	# Tick until the lethal finish lands, then check immediately (spilled blood decays over time).
	for _t in range(300):
		sim.tick_sim(DT)
		if civ.dead:
			break
	assert_true(civ.dead, "holding the feed past the Brink must kill")
	assert_eq(int(civ.tags.get("pallor", 0)), 5, "a fully drained victim is corpse-white")
	assert_gt(sim.world.blood_at(civ.pos), 20, "the kill sprays REAL blood into the SPILL grid (no red oval)")
	sim.queue_free()
