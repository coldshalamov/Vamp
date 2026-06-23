## test_gulp_window.gd — proves the feeding gulp mini-game creates a skill gap, deterministically.
##
## A scripted "expert" taps ATTACK whenever the gulp window is open (reading sim state read-only);
## a "masher" never taps. The expert must land gulp windows and end the feed with MORE vitae. The
## window is tick-based and the tap arrives via the InputAction stream, so the run is replay-stable.
extends GutTest

const DT := 1.0 / 60.0


func _run(expert: bool) -> Dictionary:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var p: SimEntity = sim.player
	var pb: SimPlayer = p.behaviour
	var victim: SimEntity = null
	for e in sim.entities:
		if e != p and e.kind == "npc" and e.faction == "civ":
			victim = e
			break
	assert_not_null(victim, "found a civilian victim to feed on")
	p.pos = victim.pos - Vector2(20, 0)
	pb.blood = 30.0
	var feed := InputAction.new(InputAction.Kind.FEED)
	feed.held = true
	sim.apply_input(feed)

	var vitae_at_end := -1.0
	for i in range(400):
		if expert and pb.gulp_window_active:
			sim.apply_input(InputAction.new(InputAction.Kind.ATTACK))
		var was_feeding := pb.feeding_target_id != 0
		sim.tick_sim(DT)
		if was_feeding and pb.feeding_target_id == 0 and vitae_at_end < 0.0:
			vitae_at_end = pb.blood
			break
	var perfects := 0
	for rec in sim.cue_events:
		if String(rec.get("id", "")) == "feed.gulp.perfect":
			perfects += 1
	return { "vitae": vitae_at_end, "perfects": perfects }


func test_well_timed_gulps_yield_more_vitae() -> void:
	var expert := _run(true)
	var masher := _run(false)
	assert_true(float(expert["vitae"]) > 0.0, "expert feed completed")
	assert_gt(int(expert["perfects"]), 0, "expert landed gulp windows")
	assert_eq(int(masher["perfects"]), 0, "masher never tapped — no perfect gulps")
	assert_gt(float(expert["vitae"]), float(masher["vitae"]),
		"expert ends feed with more vitae (%.1f) than masher (%.1f)" % [expert["vitae"], masher["vitae"]])


func test_gulp_outcome_is_deterministic() -> void:
	var a := _run(true)
	var b := _run(true)
	assert_eq(float(a["vitae"]), float(b["vitae"]), "same seed + policy = identical vitae")
	assert_eq(int(a["perfects"]), int(b["perfects"]), "same perfect count across runs")
