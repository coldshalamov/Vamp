## test_nav_death.gd — smoke test for the Navigation Track C wiring: DeathScreen cause-of-death
## explanation and MinimapRadar objective waypoint. Presentation only; asserts no crash + that the
## death explanation renders non-empty after a player.death cue.
extends GutTest

const DeathScreenScript := preload("res://src/ui/DeathScreen.gd")
const MinimapRadarScript := preload("res://src/ui/MinimapRadar.gd")


func after_each() -> void:
	if Sim != null:
		Sim.player = null
		Sim.entities.clear()
		Sim.world = null
		Sim.meta = null


func test_death_screen_explains_fire_death() -> void:
	Sim.new_game(1, "brujah")
	var ds: CanvasLayer = DeathScreenScript.new()
	add_child_autofree(ds)
	await get_tree().process_frame
	# Fire death, no nameable killer — should still produce a clear explanation line.
	CueBus.emit_cue("player.death", { "cause": "fire", "killer_id": 0, "pos": Vector2.ZERO, "explanation": "Killed by fire" })
	ds.show_death()
	assert_true(ds.visible, "death screen visible after show_death")
	var why: Label = ds.get("_why")
	assert_not_null(why, "_why label exists")
	assert_true(why.text.strip_edges() != "", "death explanation is non-empty")
	ds.hide_death()
	assert_false(ds.visible, "death screen hidden after hide_death")


func test_death_screen_names_killer_type() -> void:
	# The headline of 4d: a real killer id must resolve to a capitalized type in the why-line.
	Sim.new_game(7, "brujah")
	var killer_id: int = 0
	var killer_type: String = ""
	for e in Sim.entities:
		if e != null and e.kind == "npc" and e.type_id != "":
			killer_id = e.id
			killer_type = e.type_id
			break
	assert_true(killer_id != 0, "found an NPC to act as the killer")
	var ds: CanvasLayer = DeathScreenScript.new()
	add_child_autofree(ds)
	await get_tree().process_frame
	CueBus.emit_cue("player.death", { "cause": "physical", "killer_id": killer_id, "pos": Vector2.ZERO, "explanation": "Killed by physical" })
	ds.show_death()
	var why: Label = ds.get("_why")
	var cap: String = killer_type.substr(0, 1).to_upper() + killer_type.substr(1)
	assert_true(why.text.find(cap) != -1, "why-line names the capitalized killer type (%s in '%s')" % [cap, why.text])


func test_death_screen_dawn_torpor() -> void:
	Sim.new_game(2, "brujah")
	var ds: CanvasLayer = DeathScreenScript.new()
	add_child_autofree(ds)
	await get_tree().process_frame
	CueBus.emit_cue("player.torpor", { "day": 1, "pos": Vector2.ZERO })
	ds.show_death()
	var why: Label = ds.get("_why")
	assert_true(why.text.to_lower().find("dawn") != -1, "dawn death names the dawn")


func test_death_screen_no_cue_falls_back() -> void:
	Sim.new_game(3, "brujah")
	var ds: CanvasLayer = DeathScreenScript.new()
	add_child_autofree(ds)
	await get_tree().process_frame
	# No player.death received — must show a graceful generic line without crashing.
	ds.show_death()
	var why: Label = ds.get("_why")
	assert_true(why.text.strip_edges() != "", "fallback explanation is non-empty")


func test_minimap_radar_draws_without_crash() -> void:
	Sim.new_game(4, "brujah")
	var radar: Control = MinimapRadarScript.new()
	radar.size = Vector2(120, 120)
	add_child_autofree(radar)
	# Let the engine drive the real draw cycle (waypoint + blips) over a couple of frames.
	radar.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(radar.size, Vector2(120, 120), "radar kept its size; no crash drawing waypoint")


func test_minimap_radar_no_sim_is_safe() -> void:
	Sim.player = null
	Sim.world = null
	var radar: Control = MinimapRadarScript.new()
	radar.size = Vector2(120, 120)
	add_child_autofree(radar)
	radar.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(true, "radar drew with no Sim/player without crashing")
