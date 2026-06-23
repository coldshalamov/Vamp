## test_ui_flow.gd — integration smoke test for the UI flow (acceptance criteria #1-3, #10).
##
## Drives UIManager through the real flow without the rendering layer: open MainMenu, start
## a new game, confirm HUD registration + that pause toggles the Sim time scale. UI never
## mutates gameplay Sim state directly; this test asserts that contract holds.
extends GutTest


func test_main_menu_opens_via_ui_manager() -> void:
	assert_not_null(UIManager, "UIManager autoload present")
	var screen := UIManager.open_menu("main_menu")
	assert_not_null(screen, "MainMenu opened")
	assert_true(UIManager.is_menu_open(), "a menu is on the stack")
	screen.close()
	await get_tree().process_frame
	assert_false(UIManager.is_menu_open(), "menu stack empty after close")


func test_pause_toggles_sim_time_scale() -> void:
	# Mimic entering gameplay then opening the pause menu.
	Sim.new_game(7, "brujah")
	UIManager.set_gameplay_paused(true)
	assert_true(UIManager.is_gameplay_paused(), "paused flag set")
	assert_true(is_equal_approx(Sim.time_scale, 0.0), "Sim.time_scale zeroed on pause")
	UIManager.set_gameplay_paused(false)
	assert_true(is_equal_approx(Sim.time_scale, 1.0), "Sim.time_scale restored on resume")


func test_ui_code_does_not_mutate_gameplay_state() -> void:
	# Gameplay-mutating methods must not be reachable from UI scripts. We assert by setting a
	# known state, exercising the HUD cue path, and confirming player hp/blood are unchanged.
	Sim.new_game(11, "brujah")
	var before_hp: float = Sim.player.hp
	var before_blood: float = Sim.player.behaviour.blood
	# Route a damage cue through UIManager (HUD consumes it for floating text only).
	UIManager.spawn_floating_text(Vector2.ZERO, "17", Color.RED)
	UIManager.show_notification("test")
	UIManager.show_banner("t", "b")
	assert_eq(Sim.player.hp, before_hp, "HP unchanged after UI cue routing")
	assert_eq(Sim.player.behaviour.blood, before_blood, "blood unchanged after UI cue routing")


func test_close_all_menus_is_synchronous_and_does_not_hang() -> void:
	# Regression for the New Game hang: with animations ON (reduced_motion off), close() defers the
	# stack pop to a tween callback. Boot._enter_gameplay used to `while is_menu_open(): close_menu()`
	# which spins forever waiting for a pop that can't happen inside one frame. close_all_menus()
	# must empty the stack THIS frame, with NO await.
	UIManager.theme_resource.reduced_motion = false
	# Two animated screens on the stack (main_menu is proven-clean; keeps this regression focused
	# on the teardown contract, not on any one menu's internals).
	UIManager.open_menu("main_menu")
	UIManager.open_menu("main_menu")
	assert_true(UIManager.is_menu_open(), "menus pushed onto the stack")
	UIManager.close_all_menus()
	assert_false(UIManager.is_menu_open(), "stack emptied synchronously (the old loop would hang here)")


func test_closed_screens_do_not_accumulate_in_the_tree() -> void:
	# Regression: pop_screen used to remove from the stack array only, leaving closed screens
	# parented under ScreensLayer (visible=false). Opening/closing menus then leaked nodes forever.
	# pop_screen now queue_free()s the popped screen.
	UIManager.theme_resource.reduced_motion = true  # synchronous open/close for a deterministic count
	var layer: Node = UIManager.get_node("ScreensLayer")
	var baseline := layer.get_child_count()
	for i in range(6):
		UIManager.open_menu("main_menu")
		UIManager.close_all_menus()
		await get_tree().process_frame
	await get_tree().process_frame
	assert_lte(layer.get_child_count(), baseline + 1, "closed screens are freed, not accumulated")


func test_settings_menu_builds_all_tabs_without_errors() -> void:
	# Regression: _section() returns the inner VBox (already parented to its ScrollContainer), so
	# _build() must add the ScrollContainer root to the TabContainer, not the VBox. Adding the VBox
	# threw "already has a parent" x4 and silently dropped the Video/Audio/Gameplay/Accessibility
	# tabs (only Controls survived). GUT fails this test on the pushed engine error if it regresses.
	var screen := UIManager.open_menu("settings")
	assert_not_null(screen, "settings menu opened")
	var tab_bar: TabContainer = screen.get("_tab_bar")
	assert_not_null(tab_bar, "tab bar exists")
	# 4 _section tabs + the remap/Controls panel = 5.
	assert_eq(tab_bar.get_child_count(), 5, "all 5 settings tabs present (4 sections + controls)")
	UIManager.close_all_menus()


func test_settings_persist_round_trip() -> void:
	# Accessibility flags written via UIManager should survive a save/load cycle.
	UIManager.set_reduced_motion(true)
	UIManager.set_text_scale(1.25)
	# UIManager persisted to user://settings.cfg (or Accessibility autoload). Reload by
	# reading the ConfigFile directly — the test for persistence is "the value is on disk".
	var cfg := ConfigFile.new()
	var found_reduced := false
	if cfg.load("user://settings.cfg") == OK:
		# Either the UI section (our store) or the accessibility section (vision agent's).
		for sec in ["ui", "accessibility"]:
			if cfg.has_section_key(sec, "reduced_motion") and bool(cfg.get_value(sec, "reduced_motion")):
				found_reduced = true
	assert_true(found_reduced, "reduced_motion persisted to settings.cfg")
	# Restore defaults so this test doesn't pollute others.
	UIManager.set_reduced_motion(false)
	UIManager.set_text_scale(1.0)
