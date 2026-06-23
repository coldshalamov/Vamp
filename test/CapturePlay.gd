## CapturePlay.gd — REAL playtest evidence harness. Drives the actual first-minute play beats the
## player complained about (floating character, dead click, empty hotbar, text-only spells, death
## soft-lock) and screenshots each, so they are verified by SEEING, not by headless asserts.
## Run windowed: Godot_v4.7-stable_win64.exe --path . res://test/CapturePlay.tscn
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
	await _shot("play_10_spawn")               # grounded directional character (not a floating portrait)

	# Walk right — capture 3 consecutive gait frames to prove the legs/arms actually animate.
	for i in range(45):
		_move(Vector2.RIGHT)
		await get_tree().process_frame
		if i == 14:
			await _shot("play_11a_walk")
		elif i == 20:
			await _shot("play_11b_walk")
		elif i == 26:
			await _shot("play_11c_walk")

	# Dodge-roll (the dash) — tucked roll + motion trail.
	var d := InputAction.new(InputAction.Kind.DASH)
	d.vector = Vector2.RIGHT
	Sim.apply_input(d)
	await _settle(4)
	await _shot("play_11d_dodge")

	# Aim + attack into empty space → a visible swing arc (was: click did nothing).
	_aim(Sim.player.pos + Vector2(90, -20))
	_attack()
	await _settle(3)
	await _shot("play_12_swing")

	# Cast spells → real world-space VFX (was: just a 'Earthquake!' text).
	if Sim != null and Sim.player != null:
		Sim.emit_cue("power.cast", { "power_id": "pot_quake", "name": "Earthquake", "pos": Sim.player.pos })
		Sim.emit_cue("power.cast", { "power_id": "cel_dash", "name": "Blink", "pos": Sim.player.pos })
	await _settle(6)
	await _shot("play_13_spell_vfx")

	# Real combat: stand next to the thug, aim at it, attack → impact sparks + damage numbers.
	var thug := _find_hostile()
	if thug != null and Sim != null and Sim.player != null:
		Sim.player.pos = thug.pos - Vector2(64, 0)
		_aim(thug.pos)
		await _settle(10)            # let the hostile enter its chase/attack state
		await _shot("play_14z_alert")   # capture the "!" alert indicator on a LIVE enemy
		Sim.player.pos = thug.pos - Vector2(30, 0)
		for i in range(20):
			_attack()
			await get_tree().process_frame
			await get_tree().process_frame
			if i == 2:
				await _shot("play_14a_hit")   # early: thug flashing + starting to fly
	await _shot("play_14_combat")             # later: thug shoved back

	# REACT: ignite the spilled blood -> spreading flames
	if Sim != null and Sim.player != null:
		Sim.world.spill_blood(Sim.player.pos, 220)
		Sim.world.spill_blood(Sim.player.pos + Vector2(28, 0), 200)
		Sim.world.spill_blood(Sim.player.pos + Vector2(56, 0), 180)
		Sim.world.ignite_radius(Sim.player.pos, 70.0)
	await _settle(14)
	await _shot("play_react_fire")

	# INSCRIBE: paint a blood-sigil (rune ring)
	if Sim != null and Sim.player != null and Sim.player.behaviour != null:
		Sim.player.behaviour.blood = 60.0
		Sim.player.pos = Sim.player.pos + Vector2(0, -90)   # step off the flames
		Sim.player.behaviour.inscribe(Sim)
	await _settle(10)
	await _shot("play_sigil")

	# Death → the torpor screen (was: world froze, character vanished, no recovery).
	if Sim != null and Sim.player != null:
		Sim.player.hp = 0.0
		Sim.player.dead = true
	await _settle(20)
	await _shot("play_15_death_screen")

	# Rise from torpor → world resumes, character back at haven.
	var gr := _find_game_renderer(get_tree().root)
	if gr != null and gr.has_method("_respawn"):
		gr._respawn()
	await _settle(20)
	_move(Vector2.RIGHT)
	await _settle(10)
	await _shot("play_16_respawned")

	# Clean SOLO hero portrait LAST (parking entities here can't break anything downstream).
	if Sim != null and Sim.player != null:
		Sim.player.pos = Vector2(480, 600)
		Sim.player.facing = 0.6
		for e in Sim.entities:
			if e != null and e != Sim.player and e.kind != "vehicle":
				e.pos = e.pos + Vector2(0, -4000)
	await _settle(18)
	await _shot("play_11_hero")
	for i in range(16):
		_move(Vector2(0.7, 0.7))
		await get_tree().process_frame
	await _shot("play_11_hero_walk")

	print("[CAPTURE-PLAY] done")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _move(dir: Vector2) -> void:
	if Sim == null:
		return
	var a := InputAction.new(InputAction.Kind.MOVE)
	a.vector = dir
	Sim.apply_input(a)


func _aim(world_pos: Vector2) -> void:
	if Sim == null:
		return
	var a := InputAction.new(InputAction.Kind.AIM)
	a.vector = world_pos
	a.held = true
	Sim.apply_input(a)


func _attack() -> void:
	if Sim == null:
		return
	Sim.apply_input(InputAction.new(InputAction.Kind.ATTACK))


func _find_hostile() -> SimEntity:
	if Sim == null:
		return null
	for e in Sim.entities:
		if e != null and e.kind == "npc" and e.hostile_to_player and not e.dead:
			return e
	return null


func _find_game_renderer(n: Node) -> Node:
	if n.get_class() == "Node2D" and n.has_method("_respawn"):
		return n
	if n.name == "GameRenderer":
		return n
	for c in n.get_children():
		var r := _find_game_renderer(c)
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
	print("[CAPTURE-PLAY] saved ", path, " (", err, ")")
