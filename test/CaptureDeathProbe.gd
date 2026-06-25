## CaptureDeathProbe.gd — verify the GPUParticles2D death-dissolve burst. HEAD sim doesn't emit
## enemy.death (a WIP cue), so this fires the cue directly through CueBus (presentation-only) at a
## few points near the predator and shoots, proving the death pool renders the scatter burst.
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
	await _settle(30)

	# Park other actors away; frame just the predator + the bursts.
	var p := Sim.player.pos
	for e in Sim.entities:
		if e != null and e != Sim.player and e.kind != "vehicle":
			e.pos = e.pos + Vector2(0, -9000)

	var cam := _find_camera(get_tree().root)
	var director := _find_by_name(get_tree().root, "CameraDirector")
	if director != null and director.has_method("set_process"):
		director.set_process(false)
	if cam != null:
		cam.zoom = Vector2(1.5, 1.5)
		cam.global_position = p

	# Fire death-dissolve bursts around the predator.
	for off in [Vector2(70, -10), Vector2(-60, 20), Vector2(20, 60)]:
		CueBus.emit_cue("enemy.death", { "entity_id": 0, "pos": p + off })
	await _settle(6)
	await _shot("death_probe_early")
	await _settle(14)
	await _shot("death_probe_late")

	print("[CAPTURE-DEATH] done")
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
	img.save_png("%s/%s.png" % [OUT_DIR, label])
	print("[CAPTURE-DEATH] saved ", label)
