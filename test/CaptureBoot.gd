## CaptureBoot.gd — windowed evidence harness for the REAL boot→menu→HUD stack.
##
## Unlike CaptureSlice (which instantiates GameView directly and bypasses Boot), this loads the
## actual Boot.tscn so the HUD / NotificationPanel / CaptionOverlay / FloatingText (all added by
## Boot into the UIManager layer) are present. It captures the main menu, then drives the wired
## UIManager.cb_new_game callback to enter gameplay and captures the HUD over the live game.
## LOCAL WINDOWS SAFETY: do not run this raw/windowed without explicit user approval.
extends Node

const BootScene := preload("res://scenes/Boot.tscn")
const OUT_DIR := "res://docs/evidence"

var _boot: Node = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_boot = BootScene.instantiate()
	add_child(_boot)
	# Boot._ready wires UIManager callbacks and opens the main menu.
	await get_tree().process_frame
	await get_tree().process_frame
	_run.call_deferred()


func _run() -> void:
	await _settle(95)
	await _shot("10_main_menu")

	# Drive the wired New Game intent exactly as the menu button would.
	if UIManager != null and UIManager.cb_new_game.is_valid():
		UIManager.cb_new_game.call()
	else:
		push_error("CaptureBoot: cb_new_game not wired")
	await _settle(30)
	await _shot("11_hud_over_gameplay")

	# Move so the HUD vitals + camera follow are exercised over the real stack.
	for i in range(70):
		if Sim != null:
			var a := InputAction.new(InputAction.Kind.MOVE)
			a.vector = Vector2.RIGHT
			Sim.apply_input(a)
		await get_tree().process_frame
	await _shot("12_hud_after_move")

	if Sim != null and Sim.player != null:
		print("[CAPTURE-BOOT] tick=", Sim.tick, " hp=", Sim.player.hp,
			" hud_visible=", (UIManager.is_hud_visible() if UIManager.has_method("is_hud_visible") else "?"))
	print("[CAPTURE-BOOT] done")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, label]
	var err := img.save_png(path)
	print("[CAPTURE-BOOT] saved ", path, " (", err, ") size=", img.get_size())
