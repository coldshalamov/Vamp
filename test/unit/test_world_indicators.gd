## test_world_indicators.gd — smoke test for WorldIndicatorLayer (world-space enemy indicators).
##
## Drives a real sim slice, instantiates the layer, fires every cue it consumes with realistic
## payloads, and processes a frame. Asserts no crash and that the layer recorded the expected
## transient state. We assert on the layer's STATE dictionaries (not _draw) because under
## --headless there is no draw pass, matching the "process a frame" path the layer is built around.
extends GutTest

const WorldIndicatorLayerScript := preload("res://src/present/WorldIndicatorLayer.gd")


func after_each() -> void:
	if Sim != null:
		Sim.player = null
		Sim.entities.clear()
		Sim.world = null
		Sim.meta = null


func _make_layer() -> Node2D:
	var layer: Node2D = WorldIndicatorLayerScript.new()
	add_child_autofree(layer)
	return layer


func _first_npc_id() -> int:
	if Sim == null:
		return 0
	for e in Sim.entities:
		if e != null and e.kind == "npc":
			return e.id
	return 0


func _herald() -> SimEntity:
	if Sim == null:
		return null
	for e in Sim.entities:
		if e != null and e.kind == "npc" and e.tags.get("herald"):
			return e
	return null


func test_layer_noops_without_sim_player() -> void:
	# A bare layer with no game running must not crash on _process or any cue.
	var layer := _make_layer()
	assert_eq(layer.z_index, 30, "draws above EntityRenderer (z 20)")
	CueBus.emit_cue("enemy.alert", { "entity_id": 999, "pos": Vector2.ZERO, "alert_level": "hostile" })
	CueBus.emit_cue("status.applied", { "target_id": 999, "status": "burning", "duration": 60, "source_id": 0 })
	await get_tree().process_frame
	assert_true(layer._alert_state.is_empty(), "alert ignored when Sim.player is null")
	assert_true(layer._status_state.is_empty(), "status ignored when Sim.player is null")


func test_all_cues_record_state_and_do_not_crash() -> void:
	Sim.new_game(1, "brujah")
	var npc_id := _first_npc_id()
	assert_gt(npc_id, 0, "a real npc exists in the slice")
	var npc: SimEntity = Sim.get_entity(npc_id)
	var npc_pos: Vector2 = npc.pos if npc != null else Vector2.ZERO

	var layer := _make_layer()

	# 1e — damage reveals a health bar; combo + detonate also reveal.
	CueBus.emit_cue("damage.dealt", {
		"entity_id": Sim.player.id, "attacker_id": Sim.player.id, "target_id": npc_id,
		"amount": 18.0, "pos": npc_pos, "crit": true, "damage_type": "physical", "overkill": 0.0,
	})
	CueBus.emit_cue("combo.trigger", { "entity_id": Sim.player.id, "target_id": npc_id, "combo_name": "Rip", "bonus_damage": 6.0, "pos": npc_pos })
	CueBus.emit_cue("status.detonated", { "target_id": npc_id, "status": "bleeding", "bonus_damage": 9.0, "pos": npc_pos })

	# 1b — status icons: apply two, expire one.
	CueBus.emit_cue("status.applied", { "target_id": npc_id, "status": "burning", "duration": 60, "source_id": Sim.player.id })
	CueBus.emit_cue("status.applied", { "target_id": npc_id, "status": "stunned", "duration": 30, "source_id": Sim.player.id })
	CueBus.emit_cue("status.expired", { "target_id": npc_id, "status": "burning" })

	# 2a — alerts, both tiers.
	CueBus.emit_cue("enemy.alert", { "entity_id": npc_id, "pos": npc_pos, "alert_level": "noticed" })
	CueBus.emit_cue("enemy.alert", { "entity_id": npc_id, "pos": npc_pos, "alert_level": "hostile" })

	# 2b — telegraph variants: ranged -> line, aoe -> ground, melee -> glow.
	CueBus.emit_cue("enemy.telegraph", { "entity_id": npc_id, "pos": npc_pos, "attack_type": "ranged_gun", "direction": 0.7, "wind_up_ms": 600 })
	await get_tree().process_frame
	assert_eq(String(layer._telegraph_state[npc_id]["kind"]), "line", "ranged telegraph -> line")

	CueBus.emit_cue("enemy.telegraph", { "entity_id": npc_id, "pos": npc_pos, "attack_type": "aoe_slam", "direction": 0.0, "wind_up_ms": 800 })
	await get_tree().process_frame
	assert_eq(String(layer._telegraph_state[npc_id]["kind"]), "ground", "aoe telegraph -> ground")

	CueBus.emit_cue("enemy.telegraph", { "entity_id": npc_id, "pos": npc_pos, "attack_type": "heavy_charge", "direction": 0.0, "wind_up_ms": 500 })
	await get_tree().process_frame

	# State assertions after processing.
	assert_eq(String(layer._telegraph_state[npc_id]["kind"]), "melee", "heavy telegraph -> melee glow")
	assert_true(layer._hp_state.has(npc_id), "health bar revealed by damage")
	assert_true(layer._status_state.has(npc_id), "status row exists")
	assert_false(Dictionary(layer._status_state[npc_id]).has("burning"), "expired status removed")
	assert_true(Dictionary(layer._status_state[npc_id]).has("stunned"), "active status retained")
	assert_eq(String(layer._alert_state[npc_id]["level"]), "hostile", "latest alert tier recorded")

	# Chunk seeding (1e): display_frac must be seeded from the PRE-damage fraction (> real hp now),
	# so the white "lost chunk" is visible on the FIRST hit, not only the second.
	assert_gt(float(layer._hp_state[npc_id]["display_frac"]), Sim.get_entity(npc_id).hp / Sim.get_entity(npc_id).max_hp - 0.0001,
		"display_frac seeded above current hp so the first-hit chunk renders")

	# Elite-branch decision logic: the slice's herald is tagged elite and gets a name label.
	var herald: SimEntity = _herald()
	if herald != null:
		assert_true(layer._is_elite(herald), "herald (tags.herald) detected as elite")
		assert_eq(layer._elite_name(herald), "Herald", "elite name resolves from herald tag")
	pass_test("WorldIndicatorLayer processed all consumed cues without crashing")


func test_state_dropped_when_entity_gone() -> void:
	Sim.new_game(2, "brujah")
	var layer := _make_layer()
	# Fire cues against an id that does NOT exist — the layer must seed nothing durable / prune it.
	var ghost_id := 999999
	CueBus.emit_cue("status.applied", { "target_id": ghost_id, "status": "marked", "duration": 60, "source_id": 0 })
	CueBus.emit_cue("enemy.alert", { "entity_id": ghost_id, "pos": Vector2.ZERO, "alert_level": "noticed" })
	CueBus.emit_cue("enemy.telegraph", { "entity_id": ghost_id, "pos": Vector2.ZERO, "attack_type": "ranged", "direction": 0.0, "wind_up_ms": 400 })
	# Process a couple of frames so _prune_dead runs and clears state for the missing entity.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(layer._alert_state.has(ghost_id), "alert for missing entity pruned")
	assert_false(layer._telegraph_state.has(ghost_id), "telegraph for missing entity pruned")
	assert_false(layer._status_state.has(ghost_id), "status for missing entity pruned")
