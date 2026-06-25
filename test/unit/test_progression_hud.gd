## test_progression_hud.gd — smoke test for the ProgressionHUD overlay (deliverable 5 a,b,c,e).
##
## Verifies the overlay instantiates, registers against CueBus, survives a live new_game, and
## consumes EACH cue it listens to (player.xp / player.level_up / inventory.equipped /
## inventory.auto_sold / dawn.warning) without crashing — and that the XP-bar fraction is computed
## cleanly from Sim.meta. Mirrors the GutTest harness style in test/unit/test_ui_flow.gd.
extends GutTest

const ProgressionHUDScript := preload("res://src/ui/ProgressionHUD.gd")


func after_each() -> void:
	if Sim != null:
		Sim.player = null
		Sim.entities.clear()
		Sim.world = null
		Sim.meta = null
		Sim.cue_events.clear()
		Sim.cue_events_this_tick.clear()


# Returns the instance untyped: the `ProgressionHUD` global class_name may not be registered while
# unrelated WIP scripts fail to compile, so we avoid a hard type annotation and rely on the preload.
func _make_hud() -> Node:
	var hud = ProgressionHUDScript.new()
	add_child_autofree(hud)
	# The overlay sets PRESET_FULL_RECT in _ready, so it inherits the test viewport's size. Setting
	# .size directly here would warn ("non-equal opposite anchors override size after _ready").
	return hud


func test_instantiates_and_noops_without_a_game() -> void:
	# Before any new_game, the overlay must do nothing (so it never paints over the title screen).
	if Sim != null:
		Sim.player = null
		Sim.meta = null
	var hud := _make_hud()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(hud._display_frac, 0.0, "XP bar stays empty with no live game")
	assert_true(hud._xp_pops.is_empty(), "no XP popups without a game")


func test_consumes_all_cues_without_crashing() -> void:
	Sim.new_game(1, "brujah")
	var hud := _make_hud()
	await get_tree().process_frame

	# The XP fraction must compute cleanly from Sim.meta.
	var frac: float = hud._real_xp_fraction()
	assert_between(frac, 0.0, 1.0, "XP fraction is a clean [0,1] value")

	# Fire EACH consumed cue with a realistic payload via CueBus (cue_emitted is synchronous).
	assert_not_null(CueBus, "CueBus autoload present")
	CueBus.emit_cue("player.xp", { "amount": 25, "pos": Vector2.ZERO, "reason": "kill" })
	CueBus.emit_cue("player.level_up", { "level": 2, "ups": [] })
	CueBus.emit_cue("inventory.equipped", { "slot": "charm1", "item_id": 1, "name": "Test Ring" })
	CueBus.emit_cue("inventory.auto_sold", { "item": "Junk", "money": 12 })
	CueBus.emit_cue("dawn.warning", { "clock": 5.0, "day": 1, "caption": "Dawn is close." })

	# An XP gain should register a popup and arm the bar glow.
	assert_eq(hud._xp_pops.size(), 1, "player.xp produced one '+N XP' popup")
	assert_gt(hud._glow_t, 0.0, "player.xp armed the bar glow")
	# Level-up arms the burst + hint timer and records the level.
	assert_gt(hud._levelup_t, 0.0, "player.level_up armed the burst/hint")
	assert_eq(hud._levelup_level, 2, "level recorded from payload")
	# Dawn arms the rising-sun indicator.
	assert_gt(hud._dawn_t, 0.0, "dawn.warning armed the sun indicator")

	# Process several frames so _process + _draw run over the live state (no camera in headless;
	# this overlay is screen-space so it does not require one).
	for _i in range(8):
		await get_tree().process_frame

	assert_between(hud._display_frac, 0.0, 1.0, "displayed XP fraction stays in range after frames")
	# Popups age out within their dwell.
	assert_lte(hud._xp_pops.size(), 1, "XP popups age out and don't accumulate")


func test_level_rollover_sweeps_to_full_then_resets() -> void:
	# Prime the bar HIGH (just under the threshold) so leveling makes the real fraction DROP — the
	# rollover case. Confirm the flourish latches (sweeps toward full) and the bar stays in [0,1].
	Sim.new_game(2, "brujah")
	var hud := _make_hud()
	# Put XP just shy of the next level so _last_real_frac settles near ~0.95 first.
	var need: int = Sim.meta.xp_to_next(Sim.meta.level)
	Sim.meta.xp = int(float(need) * 0.95)
	await get_tree().process_frame   # bar reads the high fraction; _last_real_frac is now high
	# Now cross the boundary. gain_xp emits player.level_up; the real fraction drops to a low value.
	Sim.meta.gain_xp(need, Sim)
	assert_gte(Sim.meta.level, 2, "the sim actually levelled (sanity on the test setup)")
	await get_tree().process_frame
	assert_true(hud._rolling_over, "rollover flourish latched when the fraction dropped")
	# Drive frames; the display should climb toward full during the sweep, never leaving [0,1].
	var reached_high: float = float(hud._display_frac)
	for _i in range(30):
		await get_tree().process_frame
		reached_high = maxf(reached_high, float(hud._display_frac))
		assert_between(hud._display_frac, 0.0, 1.0, "fraction stays clean across the whole rollover")
	assert_gt(reached_high, 0.9, "the bar visibly swept up toward full before resetting")
	assert_false(hud._rolling_over, "flourish ended and the bar settled to the new low fraction")


func test_cue_after_player_cleared_does_not_pop_a_banner() -> void:
	# HARD RULE #4: a level_up cue draining after death (player nulled) must NOT arm a banner/burst
	# over the menu. The handler is gated in _on_cue, so nothing arms.
	Sim.new_game(5, "brujah")
	var hud := _make_hud()
	await get_tree().process_frame
	Sim.player = null
	CueBus.emit_cue("player.level_up", { "level": 9, "ups": [] })
	CueBus.emit_cue("inventory.equipped", { "slot": "charm1", "item_id": 2, "name": "Ghost Ring" })
	assert_eq(hud._levelup_t, 0.0, "level_up after player cleared did not arm the burst")
	assert_eq(hud._levelup_level, 0, "no level recorded from a guarded cue")


func test_noops_when_player_cleared_after_a_game() -> void:
	# If the game ends (player nulled) the overlay must reset its transient state and stop drawing.
	Sim.new_game(3, "brujah")
	var hud := _make_hud()
	CueBus.emit_cue("player.xp", { "amount": 40, "pos": Vector2.ZERO, "reason": "kill" })
	await get_tree().process_frame
	assert_eq(hud._xp_pops.size(), 1, "popup present during the game")
	Sim.player = null
	for _i in range(3):
		await get_tree().process_frame
	assert_true(hud._xp_pops.is_empty(), "transient state cleared once the game is gone")
	assert_eq(hud._display_frac, 0.0, "XP bar emptied once the game is gone")
