## CaptureGraphicsPass.gd — deterministic, windowed visual acceptance harness.
##
## This scene boots the real GameView and captures the presentation pass under actual
## Godot rendering. It is not gameplay code and never mutates shipping behavior. Run:
##   godot --path . res://test/CaptureGraphicsPass.tscn
extends Node2D

const GameViewScene := preload("res://scenes/GameView.tscn")
const OUT_DIR := "res://docs/evidence/graphics_pass"
const CAPTURE_SIZE := Vector2i(1280, 720)

var _game_view: Node2D = null
var _showcase: Array[SimEntity] = []
var _fps_samples: Array[float] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_showcase_sim()
	_game_view = GameViewScene.instantiate()
	add_child(_game_view)
	await get_tree().process_frame
	await get_tree().process_frame
	_run_capture_sequence.call_deferred()


func _build_showcase_sim() -> void:
	Sim.new_game(424242, "brujah")
	# Remove the slice's starter cast. This harness builds a controlled lineup while using
	# the same SimEntity/SimNPC construction path as the shipping game.
	for i in range(Sim.entities.size() - 1, -1, -1):
		if Sim.entities[i] != Sim.player:
			Sim.entities.remove_at(i)
	Sim.player.pos = Vector2(380.0, 576.0)
	Sim.player.home_pos = Sim.player.pos
	Sim.player.facing = -PI * 0.5

	_showcase = [Sim.player]
	_spawn_guard("ped", Vector2(-210.0, 28.0), 0.12)
	_spawn_guard("thug", Vector2(-150.0, 25.0), -0.18)
	_spawn_guard("gunner", Vector2(-92.0, 22.0), 0.08)
	_spawn_guard("cop", Vector2(78.0, 22.0), -0.06)
	_spawn_guard("swat", Vector2(136.0, 24.0), 0.15)
	_spawn_guard("hunter", Vector2(196.0, 28.0), -0.12)


func _spawn_guard(type_id: String, offset: Vector2, facing_bias: float = 0.0) -> SimEntity:
	var actor := Sim.spawn_npc(
		type_id,
		Sim.player.pos + offset,
		{"state": "guard", "hostile_to_player": false, "responder": false}
	)
	actor.ai_state = "guard"
	actor.perception_state = "calm"
	actor.hostile_to_player = false
	actor.responder = false
	actor.vel = Vector2.ZERO
	actor.facing = -PI * 0.5 + facing_bias
	_showcase.append(actor)
	return actor


func _run_capture_sequence() -> void:
	await _settle(40)
	await _shot("graphics_01_lineup")

	# Continuous locomotion: no sprite frames. The rig is posed every render frame from
	# fixed-tick displacement and the engine interpolates the world transform.
	for i in range(58):
		_drive(InputAction.Kind.MOVE, Vector2(0.72, -0.28).normalized())
		await get_tree().process_frame
	await _shot("graphics_02_locomotion")

	# Capture the authoritative ActionDef swing during its active pose.
	_drive(InputAction.Kind.AIM, Sim.player.pos + Vector2(130.0, -18.0))
	_drive(InputAction.Kind.ATTACK)
	await _settle(7)
	await _shot("graphics_03_attack")

	_spawn_ballistic_gallery()
	await _settle(10)
	await _shot("graphics_04_ballistics")

	_emit_impact_gallery()
	await _settle(5)
	await _shot("graphics_05_impacts")

	_build_stress_case()
	await _measure_render_fps(150)
	await _shot("graphics_06_stress")
	_write_metrics()

	print(
		"[GRAPHICS_CAPTURE] done entities=",
		Sim.entities.size(),
		" average_fps=",
		_snapped_average_fps(),
		" output=",
		OUT_DIR
	)
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if _snapped_average_fps() >= 30.0 else 3)


func _spawn_ballistic_gallery() -> void:
	var base := Sim.player.pos + Vector2(-110.0, -62.0)
	(
		Sim
		. spawn_projectile(
			base,
			Vector2(155.0, -8.0),
			{
				"owner_id": Sim.player.id,
				"kind": "blood_bolt",
				"faction": "player",
				"radius": 4.5,
				"damage": 0.0,
				"damage_type": "blood",
				"life_ticks": 150,
			}
		)
	)
	(
		Sim
		. spawn_projectile(
			base + Vector2(72.0, -8.0),
			Vector2(118.0, 4.0),
			{
				"owner_id": Sim.player.id,
				"kind": "poison_vial",
				"faction": "player",
				"radius": 6.0,
				"damage": 0.0,
				"damage_type": "poison",
				"status": "poison",
				"aoe_radius": 54.0,
				"life_ticks": 150,
			}
		)
	)
	(
		Sim
		. spawn_projectile(
			base + Vector2(144.0, 2.0),
			Vector2(105.0, 15.0),
			{
				"owner_id": Sim.player.id,
				"kind": "fire_bomb",
				"faction": "player",
				"radius": 7.0,
				"damage": 0.0,
				"damage_type": "fire",
				"status": "burn",
				"aoe_radius": 66.0,
				"life_ticks": 150,
			}
		)
	)


func _emit_impact_gallery() -> void:
	var center := Sim.player.pos + Vector2(85.0, -5.0)
	(
		Sim
		. emit_cue(
			"physics.impact",
			{
				"pos": center + Vector2(-82.0, 22.0),
				"kind": "glass_vial",
				"damage_type": "poison",
				"explosive": true,
				"radius": 50.0,
			}
		)
	)
	(
		Sim
		. emit_cue(
			"surface.spawn",
			{
				"pos": center + Vector2(-82.0, 22.0),
				"surface": "poison",
				"radius": 52.0,
				"duration": 5.0,
			}
		)
	)
	(
		Sim
		. emit_cue(
			"physics.impact",
			{
				"pos": center + Vector2(40.0, 12.0),
				"kind": "fire_bomb",
				"damage_type": "fire",
				"explosive": true,
				"radius": 64.0,
			}
		)
	)
	(
		Sim
		. emit_cue(
			"surface.spawn",
			{
				"pos": center + Vector2(40.0, 12.0),
				"surface": "fire",
				"radius": 61.0,
				"duration": 4.0,
			}
		)
	)
	(
		Sim
		. emit_cue(
			"damage.dealt",
			{
				"attacker_id": Sim.player.id,
				"target_id": _showcase[1].id,
				"amount": 26.0,
				"pos": _showcase[1].pos,
				"crit": true,
				"damage_type": "blood",
			}
		)
	)


func _build_stress_case() -> void:
	var center := Sim.player.pos
	var types := ["ped", "thug", "gunner", "cop", "swat", "hunter"]
	for i in range(30):
		var pos := Sim.world.nearest_open_around(center, 105.0, 245.0, i + 20)
		var actor := Sim.spawn_npc(
			types[i % types.size()], pos, {"state": "guard", "hostile_to_player": false}
		)
		actor.ai_state = "guard"
		actor.hostile_to_player = false
		actor.facing = (center - pos).angle()
	for i in range(28):
		var angle := TAU * float(i) / 28.0
		var kind := ["blood_bolt", "poison_vial", "fire_bomb", "shadow_shard"][i % 4]
		var dtype := ["blood", "poison", "fire", "shadow"][i % 4]
		(
			Sim
			. spawn_projectile(
				center + Vector2.RIGHT.rotated(angle) * (32.0 + float(i % 3) * 11.0),
				Vector2.RIGHT.rotated(angle) * (90.0 + float(i % 5) * 13.0),
				{
					"owner_id": Sim.player.id,
					"kind": kind,
					"faction": "player",
					"radius": 4.0 + float(i % 3),
					"damage": 0.0,
					"damage_type": dtype,
					"life_ticks": 180,
				}
			)
		)
	for i in range(6):
		var a := TAU * float(i) / 6.0
		(
			Sim
			. emit_cue(
				"physics.impact",
				{
					"pos": center + Vector2.RIGHT.rotated(a) * 92.0,
					"kind": "debris",
					"damage_type": "physical",
					"explosive": false,
					"radius": 28.0,
				}
			)
		)


func _drive(kind: int, vector: Vector2 = Vector2.ZERO, action_id: String = "") -> void:
	var action := InputAction.new(kind)
	action.vector = vector
	action.action_id = action_id
	Sim.apply_input(action)


func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _measure_render_fps(frames: int) -> void:
	_fps_samples.clear()
	for i in range(frames):
		await get_tree().process_frame
		if i > 20:
			_fps_samples.append(float(Engine.get_frames_per_second()))


func _snapped_average_fps() -> float:
	if _fps_samples.is_empty():
		return 0.0
	var total := 0.0
	for sample in _fps_samples:
		total += sample
	return snappedf(total / float(_fps_samples.size()), 0.1)


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != CAPTURE_SIZE:
		push_warning(
			"Graphics capture viewport is %s, expected %s" % [image.get_size(), CAPTURE_SIZE]
		)
	var path := "%s/%s.png" % [OUT_DIR, label]
	var error := image.save_png(path)
	print("[GRAPHICS_CAPTURE] saved ", path, " error=", error, " size=", image.get_size())


func _write_metrics() -> void:
	var minimum_fps := 0.0
	if not _fps_samples.is_empty():
		minimum_fps = _fps_samples.min()
	var metrics := {
		"engine": Engine.get_version_info().get("string", "unknown"),
		"renderer": RenderingServer.get_current_rendering_method(),
		"viewport": [get_viewport_rect().size.x, get_viewport_rect().size.y],
		"entity_count": Sim.entities.size(),
		"average_fps": _snapped_average_fps(),
		"minimum_sampled_fps": snappedf(minimum_fps, 0.1),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"physics_interpolation_fraction": Engine.get_physics_interpolation_fraction(),
	}
	var file := FileAccess.open("%s/graphics_metrics.json" % OUT_DIR, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics, "  "))
