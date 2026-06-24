## CaptureWide.gd — a zoomed-OUT establishing shot of the whole slice block, so the director can
## judge the WORLD (population, atmosphere, sense of place) rather than a player-centered close-up.
## Boots the real game, lets the night breathe, freezes the follow-camera, pulls way back, and shoots.
extends Node

const BootScene := preload("res://scenes/Boot.tscn")
const OUT_DIR := "res://docs/evidence"

var _boot: Node = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_boot = BootScene.instantiate()
	add_child(_boot)
	await get_tree().process_frame
	await get_tree().process_frame
	_run.call_deferred()


func _run() -> void:
	await _settle(95)
	if UIManager != null and UIManager.cb_new_game.is_valid():
		UIManager.cb_new_game.call()
	await _settle(40)

	# Let the crowd disperse and live a little so the block reads as populated, not spawn-stacked.
	for i in range(160):
		await get_tree().process_frame

	var cam := _find_camera(get_tree().root)
	var director := _find_by_name(get_tree().root, "CameraDirector")
	if director != null and director.has_method("set_process"):
		director.set_process(false)   # stop the follow-cam from clobbering our establishing framing

	# Pull back to frame the whole hunting ground.
	for shot in [
		{ "name": "wide_01_block", "pos": Vector2(900, 640), "zoom": 0.42 },
		{ "name": "wide_02_lower", "pos": Vector2(900, 1040), "zoom": 0.42 },
	]:
		if cam != null:
			cam.zoom = Vector2(shot["zoom"], shot["zoom"])
			cam.global_position = shot["pos"]
		await _settle(6)
		await _shot(shot["name"])

	print("[CAPTURE-WIDE] done")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _find_camera(n: Node) -> Camera2D:
	if n is Camera2D:
		return n
	for c in n.get_children():
		var r := _find_camera(c)
		if r != null:
			return r
	return null


func _find_by_name(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for c in n.get_children():
		var r := _find_by_name(c, nm)
		if r != null:
			return r
	return null


func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, label]
	var err := img.save_png(path)
	print("[CAPTURE-WIDE] saved ", path, " (", err, ")")
