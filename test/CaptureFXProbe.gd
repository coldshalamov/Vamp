## CaptureFXProbe.gd — verify the event-driven presentation FX that don't fire during a normal
## capture: ScreenFX damage vignette + crit chromatic aberration, and per-discipline SpellParticles.
## Fires cues directly through CueBus (presentation-only) and shoots peak frames.
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

	var p: Vector2 = Sim.player.pos
	for e in Sim.entities:
		if e != null and e != Sim.player and e.kind != "vehicle":
			e.pos = e.pos + Vector2(0, -9000)

	var cam := _find_camera(get_tree().root)
	var director := _find_by_name(get_tree().root, "CameraDirector")
	if director != null and director.has_method("set_process"):
		director.set_process(false)
	if cam != null:
		cam.zoom = Vector2(1.4, 1.4)
		cam.global_position = p

	# 1) Spell particles — fire one cast per discipline color/archetype around the predator.
	var casts := [
		{ "archetype": "NOVA", "color": "#33aaff", "off": Vector2(0, 0) },          # Celerity blue
		{ "archetype": "GROUND_AOE", "color": "#ff7722", "off": Vector2(120, -20) }, # Potence orange
		{ "archetype": "CONE", "color": "#cc33ff", "off": Vector2(-120, 10) },       # Dominate purple
		{ "archetype": "PROJECTILE", "color": "#cc1133", "off": Vector2(40, 110) },  # Blood crimson
		{ "archetype": "SELF_BUFF", "color": "#33dd66", "off": Vector2(-90, -90) },  # Protean green
	]
	for c in casts:
		var origin: Vector2 = p + c["off"]
		CueBus.emit_cue("power.cast", {
			"origin": origin, "target_pos": origin + Vector2(90, 0),
			"color": c["color"], "archetype": c["archetype"],
			"range": 180.0, "radius": 90.0, "arc": 0.7, "aim_dir": 0.0,
		})
	await _settle(5)
	await _shot("fx_spell_particles")

	# 2) ScreenFX damage vignette.
	CueBus.emit_cue("damage.player", { "attacker_id": 0, "amount": 38.0, "pos": p, "damage_type": "physical" })
	await get_tree().process_frame
	await _shot("fx_damage_vignette")

	# 3) ScreenFX crit chromatic aberration (+ a fresh damage pulse for contrast).
	CueBus.emit_cue("hit.connect", { "entity_id": 0, "target_id": 0, "pos": p, "dir": Vector2.RIGHT, "crit": true, "melee": true })
	CueBus.emit_cue("damage.player", { "attacker_id": 0, "amount": 60.0, "pos": p, "damage_type": "physical" })
	await get_tree().process_frame
	await _shot("fx_aberration")

	print("[CAPTURE-FX] done")
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
	print("[CAPTURE-FX] saved ", label)
