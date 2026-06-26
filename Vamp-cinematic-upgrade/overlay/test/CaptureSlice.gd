## CaptureSlice.gd — windowed visual evidence harness for the cinematic presentation pass.
##
## Boots the real GameView, drives authoritative inputs, captures idle/run/attack/power,
## then spawns a real deterministic ballistic fire flask and captures arc + impact frames.
## Run windowed:
##   Godot_v4.7-stable_win64.exe --path . res://test/CaptureSlice.tscn
extends Node2D

const GameViewScene := preload("res://scenes/GameView.tscn")
const OUT_DIR := "res://docs/evidence"

var _gv: Node2D = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_gv = GameViewScene.instantiate()
	add_child(_gv)
	await get_tree().process_frame
	await get_tree().process_frame
	_run.call_deferred()


func _drive(kind: int, vec: Vector2 = Vector2.ZERO, action_id: String = "") -> void:
	if Sim == null:
		return
	var action := InputAction.new(kind)
	action.vector = vec
	action.action_id = action_id
	Sim.apply_input(action)


func _run() -> void:
	await _settle(24)
	await _shot("01_cinematic_idle")

	for _i in range(76):
		_drive(InputAction.Kind.MOVE, Vector2.RIGHT)
		await get_tree().process_frame
	await _shot("02_cinematic_run")

	_drive(InputAction.Kind.AIM, Sim.player.pos + Vector2(120, 0) if Sim.player else Vector2(120, 0))
	_drive(InputAction.Kind.ATTACK)
	await _settle(5)
	await _shot("03_cinematic_attack_startup")
	await _settle(5)
	await _shot("04_cinematic_attack_active")

	_drive(InputAction.Kind.POWER, Vector2.ZERO, "slot_1")
	await _settle(9)
	await _shot("05_cinematic_power")

	# Exercise the new physics channel without adding a debug-only gameplay mutation.
	# Production powers/alchemy can call this same Sim.spawn_projectile API.
	if Sim != null and Sim.player != null:
		var direction := Vector2.RIGHT.rotated(Sim.player.facing)
		Sim.spawn_projectile(Sim.player.pos + direction * 18.0, direction * 235.0, {
			"owner_id": Sim.player.id,
			"faction": "player",
			"kind": "volatile_flask",
			"radius": 6.0,
			"damage": 8.0,
			"aoe_damage": 18.0,
			"aoe_radius": 92.0,
			"damage_type": "fire",
			"status": "burn",
			"status_ticks": 150,
			"ballistic": true,
			"launch_height": 5.0,
			"vertical_velocity": 220.0,
			"gravity": 560.0,
			"bounces": 1,
			"bounce_factor": 0.30,
			"surface_effect": "fire",
			"life_ticks": 160,
		})
	await _settle(15)
	await _shot("06_ballistic_arc")
	await _settle(49)
	await _shot("07_ballistic_impact")

	for _i in range(80):
		_drive(InputAction.Kind.MOVE, Vector2(-0.55, 0.84).normalized())
		await get_tree().process_frame
	await _shot("08_camera_follow")

	if Sim != null and Sim.player != null:
		print("[CAPTURE] tick=", Sim.tick, " player_pos=", Sim.player.pos,
			" hp=", Sim.player.hp, " entities=", Sim.entities.size(),
			" heat=", Sim.heat, " cues=", Sim.cue_events.size(),
			" fps=", Engine.get_frames_per_second())
	print("[CAPTURE] done — screenshots in ", OUT_DIR)
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _settle(frames: int) -> void:
	for _i in range(frames):
		await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, label]
	var err := img.save_png(path)
	print("[CAPTURE] saved ", path, " (", err, ") size=", img.get_size())
