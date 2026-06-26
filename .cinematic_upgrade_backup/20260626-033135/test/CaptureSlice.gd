## CaptureSlice.gd — windowed evidence harness (NOT a gameplay file).
##
## Boots the real GameView, drives the player through the Sim authority for a few
## seconds (move + attack), and saves PNG screenshots to docs/evidence/. This is the
## only way to get pixel proof that the present layer actually renders — headless has
## no rendering server. LOCAL WINDOWS SAFETY: do not run this raw/windowed without explicit user approval.
extends Node2D

const GameViewScene := preload("res://scenes/GameView.tscn")
const OUT_DIR := "res://docs/evidence"

var _gv: Node2D = null
var _frame: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# GameView self-initialises Sim.new_game(42, "brujah") and builds world/entity/camera.
	_gv = GameViewScene.instantiate()
	add_child(_gv)
	await get_tree().process_frame
	await get_tree().process_frame
	_run.call_deferred()


func _drive(kind: int, vec: Vector2 = Vector2.ZERO, action_id: String = "") -> void:
	if Sim == null:
		return
	var a := InputAction.new(kind)
	a.vector = vec
	a.action_id = action_id
	Sim.apply_input(a)


func _run() -> void:
	# Frame 0: the starting board.
	await _settle(20)
	await _shot("01_start")

	# Walk right toward the hostile thug for ~1.2s, feeding move intent each frame.
	for i in range(80):
		_drive(InputAction.Kind.MOVE, Vector2.RIGHT)
		await get_tree().process_frame
	await _shot("02_moved_right")

	# Throw a light attack and an aim, capture the action frame.
	_drive(InputAction.Kind.AIM, Sim.player.pos + Vector2(120, 0) if Sim.player else Vector2(120, 0))
	_drive(InputAction.Kind.ATTACK)
	await _settle(6)
	await _shot("03_attack")

	# Cast slot 1 (clan power) and capture.
	_drive(InputAction.Kind.POWER, Vector2.ZERO, "slot_1")
	await _settle(10)
	await _shot("04_power")

	# Move down-left to show camera follow over distance.
	for i in range(100):
		_drive(InputAction.Kind.MOVE, Vector2(-0.6, 0.8).normalized())
		await get_tree().process_frame
	await _shot("05_camera_follow")

	# Report sim truth to stdout for the evidence log.
	if Sim != null and Sim.player != null:
		print("[CAPTURE] tick=", Sim.tick, " player_pos=", Sim.player.pos,
			" hp=", Sim.player.hp, " entities=", Sim.entities.size(),
			" heat=", Sim.heat, " cues=", Sim.cue_events.size())
	print("[CAPTURE] done — screenshots in ", OUT_DIR)
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
	print("[CAPTURE] saved ", path, " (", err, ") size=", img.get_size())
