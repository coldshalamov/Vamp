## CaptureShadowProbe.gd — definitive proof that LightOccluder2D shadows render. Boots the game,
## drops the predator flush against a building edge, freezes the camera zoomed in, and shoots. If
## occlusion works the round follow-light pool is visibly CLIPPED at the wall (and a shadow wedge
## falls past the corner) instead of bleeding through the building. Presentation read-only.
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

	var world = Sim.world
	var ts: int = world.tile_size
	# Find a building corner: solid cell whose up-left quadrant is open street.
	var corner := Vector2i(-1, -1)
	for y in range(6, int(world.size.y) - 6):
		for x in range(6, int(world.size.x) - 6):
			if world.is_solid(Vector2i(x, y)) \
				and not world.is_solid(Vector2i(x - 1, y)) \
				and not world.is_solid(Vector2i(x, y - 1)) \
				and not world.is_solid(Vector2i(x - 1, y - 1)) \
				and not world.is_solid(Vector2i(x - 2, y - 1)):
				corner = Vector2i(x, y)
				break
		if corner.x >= 0:
			break

	var focus := Sim.player.pos
	if corner.x >= 0:
		var wall_world := Vector2(float(corner.x * ts), float(corner.y * ts))
		# Predator stands just up-left of the corner; the corner should bite a wedge out of the pool.
		Sim.player.pos = wall_world + Vector2(-ts * 0.9, -ts * 0.9)
		focus = wall_world
		# Park everyone else far away so the frame is just the predator + the architecture.
		for e in Sim.entities:
			if e != null and e != Sim.player and e.kind != "vehicle":
				e.pos = e.pos + Vector2(0, -9000)
	await _settle(20)

	var cam := _find_camera(get_tree().root)
	var director := _find_by_name(get_tree().root, "CameraDirector")
	if director != null and director.has_method("set_process"):
		director.set_process(false)
	if cam != null:
		cam.zoom = Vector2(1.7, 1.7)
		cam.global_position = focus
	await _settle(8)
	await _shot("shadow_probe")

	print("[CAPTURE-SHADOW] done (corner=", corner, ")")
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
	print("[CAPTURE-SHADOW] saved ", path, " (", err, ")")
