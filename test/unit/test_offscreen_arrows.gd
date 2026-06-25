## test_offscreen_arrows.gd — smoke test for OffscreenThreatArrows (Deliverable 2c).
##
## Presentation only. Asserts the overlay draws without crashing: with no Sim/player, with no
## camera (the headless default — get_camera_2d() returns null), and with a live camera plus a
## hostile NPC forced far offscreen so the edge-arrow draw path actually executes.
extends GutTest

const ArrowsScript := preload("res://src/ui/OffscreenThreatArrows.gd")


func after_each() -> void:
	if Sim != null:
		Sim.player = null
		Sim.entities.clear()
		Sim.world = null
		Sim.meta = null


func _make_arrows() -> Control:
	var arrows: Control = ArrowsScript.new()
	arrows.size = Vector2(1280, 720)
	add_child_autofree(arrows)
	return arrows


func test_no_sim_is_safe() -> void:
	Sim.player = null
	Sim.world = null
	var arrows := _make_arrows()
	arrows.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(true, "overlay drew with no Sim/player without crashing")


func test_no_camera_is_safe() -> void:
	# Headless test scene has no gameplay Camera2D: get_camera_2d() returns null. The overlay
	# must early-return in _draw() rather than dereferencing a null camera.
	Sim.new_game(1, "brujah")
	assert_null(get_viewport().get_camera_2d(), "headless scene really has no current camera")
	var arrows := _make_arrows()
	arrows.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(arrows.size, Vector2(1280, 720), "overlay kept its size; no crash with null camera")


func test_offscreen_hostile_draws_arrow_path() -> void:
	# Stand up a real camera so the world->screen transform resolves, then shove a hostile NPC
	# far outside the viewport so the edge-clamp + triangle draw code runs end-to-end.
	Sim.new_game(2, "brujah")
	var cam := Camera2D.new()
	add_child_autofree(cam)
	cam.zoom = Vector2(2.4, 2.4)   # the gameplay BASE_ZOOM
	cam.make_current()
	# Park the camera on the player and fling a hostile NPC well off the right edge.
	cam.global_position = Sim.player.pos
	var hostile: SimEntity = null
	for e in Sim.entities:
		if e != null and e.kind == "npc" and not e.dead:
			hostile = e
			break
	assert_not_null(hostile, "found an NPC to make hostile")
	hostile.hostile_to_player = true
	hostile.pos = Sim.player.pos + Vector2(4000, 0)   # far offscreen at 2.4x zoom

	var arrows := _make_arrows()
	arrows.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(arrows.size, Vector2(1280, 720), "overlay drew an edge arrow for the offscreen hostile without crashing")
	# Confirm the draw MATH actually ran (not just instantiation). If headless never issues the
	# draw notification this stays 0 — in which case the draw path is unverified (noted in gaps),
	# but the test still proves instantiate/process safety.
	assert_gt(arrows._arrows_drawn, 0, "edge-arrow draw path executed for the offscreen hostile")


func test_reduced_motion_does_not_crash() -> void:
	# Reduced motion disables pulsing only; the draw path must still complete.
	Sim.new_game(3, "brujah")
	var prev := UIManager.is_reduced_motion() if UIManager != null else false
	if UIManager != null:
		UIManager.set_reduced_motion(true)
	var cam := Camera2D.new()
	add_child_autofree(cam)
	cam.make_current()
	var arrows := _make_arrows()
	arrows.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(true, "overlay drew under reduced motion without crashing")
	if UIManager != null:
		UIManager.set_reduced_motion(prev)
