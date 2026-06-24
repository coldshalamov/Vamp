## Regression guard for the ~30s hard freeze.
##
## Root cause (fixed): Sim.cue_events and CueBus.history were appended on every emit and never
## trimmed, so a normal play session grew an unbounded array of deep-copied dictionaries until the
## GC thrashed and the window locked up. Nothing reads these logs historically, so they are now
## bounded ring-style. These tests fail loudly if either bound is ever removed.
extends GutTest

const DT := 1.0 / 60.0

## Drive a real Sim for thousands of ticks while pumping a high cue volume, and prove the
## authoritative cue log never grows without bound (and the sim keeps ticking — no hang).
func test_cue_log_stays_bounded_over_long_run() -> void:
	var sim := VCSim.new()
	sim.new_game(4242, "brujah")
	# Far more emissions than the cap, interleaved with real ticks.
	for i in range(6000):
		sim.emit_cue("stress.ping", { "i": i })
		sim.tick_sim(DT)
	assert_true(sim.cue_events.size() <= VCSim.CUE_LOG_CAP,
		"cue_events must stay bounded; got %d (cap %d)" % [sim.cue_events.size(), VCSim.CUE_LOG_CAP])
	assert_gt(sim.tick, 5000, "sim should have advanced thousands of ticks without hanging")
	sim.queue_free()

## CueBus.history must also be bounded under heavy emission.
func test_cuebus_history_is_bounded() -> void:
	var bus = preload("res://src/present/CueBus.gd").new()
	for i in range(5000):
		bus.emit_cue("stress.ping", { "i": i })
	assert_true(bus.history.size() <= bus.HISTORY_CAP,
		"CueBus.history must stay bounded; got %d (cap %d)" % [bus.history.size(), bus.HISTORY_CAP])
	bus.free()
