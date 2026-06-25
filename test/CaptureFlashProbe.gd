## CaptureFlashProbe.gd — verify the white-hot hit-flash (A1.2). The flash decays fast (~5.8/s), so
## it only reads at the PEAK frame; a normal capture easily misses it. This drops an NPC beside the
## predator, fires hit.connect at it, and shoots the very next drawn frame. Presentation read-only.
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

	var npc: SimEntity = null
	for e in Sim.entities:
		if e != null and e != Sim.player and e.kind == "npc" and not e.dead:
			npc = e
			break
	if npc != null:
		npc.pos = Sim.player.pos + Vector2(64, 0)
		for e in Sim.entities:
			if e != null and e != Sim.player and e != npc and e.kind != "vehicle":
				e.pos = e.pos + Vector2(0, -9000)

	var cam := _find_camera(get_tree().root)
	var director := _find_by_name(get_tree().root, "CameraDirector")
	if director != null and director.has_method("set_process"):
		director.set_process(false)
	if cam != null:
		cam.zoom = Vector2(2.0, 2.0)
		cam.global_position = (Sim.player.pos + npc.pos) * 0.5 if npc != null else Sim.player.pos
	await _settle(10)
	await _shot("flash_before")

	# Fire the melee connect at the NPC and grab the very next drawn frame (peak flash).
	if npc != null:
		CueBus.emit_cue("hit.connect", {
			"entity_id": Sim.player.id, "target_id": npc.id, "pos": npc.pos,
			"dir": Vector2.RIGHT, "crit": true, "melee": true,
		})
	await _shot("flash_peak")
	await _settle(8)
	await _shot("flash_after")

	print("[CAPTURE-FLASH] done npc=", npc != null)
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
	print("[CAPTURE-FLASH] saved ", label)
