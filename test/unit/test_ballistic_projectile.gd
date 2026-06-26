## Regression coverage for the deterministic ballistic projectile extension.
extends GutTest

const DT := 1.0 / 60.0


func test_ballistic_projectile_rises_bounces_and_explodes() -> void:
	var sim := VCSim.new()
	sim.new_game(481516, "brujah")
	var lane := sim.player.pos + Vector2(0.0, 64.0)
	var flask := sim.spawn_projectile(lane + Vector2(18.0, 0.0), Vector2(205.0, 0.0), {
		"owner_id": sim.player.id,
		"faction": "player",
		"kind": "volatile_flask",
		"radius": 6.0,
		"damage": 8.0,
		"aoe_damage": 14.0,
		"aoe_radius": 82.0,
		"damage_type": "fire",
		"status": "burn",
		"status_ticks": 90,
		"ballistic": true,
		"launch_height": 4.0,
		"vertical_velocity": 205.0,
		"gravity": 520.0,
		"bounces": 1,
		"bounce_factor": 0.32,
		"ground_friction": 0.72,
		"surface_effect": "fire",
		"life_ticks": 150,
	})
	_tick_for(sim, 8)
	assert_true(bool(flask.behaviour.get("ballistic")), "flask did not enter ballistic mode")
	assert_true(float(flask.behaviour.get("height")) > 8.0, "flask never rose above the ground plane")
	_tick_for(sim, 130)
	assert_true(_has_cue(sim, "projectile.bounce"), "ballistic projectile never emitted a bounce")
	assert_true(_has_cue(sim, "projectile.explode"), "ballistic projectile never exploded")
	sim.queue_free()


func test_ballistic_explosion_applies_aoe_and_is_deterministic() -> void:
	var a := _run_throw(90031)
	var b := _run_throw(90031)
	assert_eq(a["hash"], b["hash"], "identical ballistic throws diverged")
	assert_true(float(a["target_hp"]) < float(a["target_max_hp"]), "ballistic explosion did not damage its target")
	assert_true(bool(a["exploded"]), "throw did not emit projectile.explode")


func _run_throw(seed: int) -> Dictionary:
	var sim := VCSim.new()
	sim.new_game(seed, "brujah")
	var lane := sim.player.pos + Vector2(0.0, 64.0)
	var target: SimEntity = sim.spawn_npc("thug", lane + Vector2(174.0, 0.0), {
		"state": "guard",
		"hostile_to_player": false,
	})
	sim.spawn_projectile(lane + Vector2(18.0, 0.0), Vector2(218.0, 0.0), {
		"owner_id": sim.player.id,
		"faction": "player",
		"kind": "firebomb",
		"radius": 6.0,
		"damage": 6.0,
		"aoe_damage": 24.0,
		"aoe_radius": 96.0,
		"damage_type": "fire",
		"status": "burn",
		"status_ticks": 120,
		"ballistic": true,
		"vertical_velocity": 205.0,
		"gravity": 520.0,
		"bounces": 0,
		"surface_effect": "fire",
		"life_ticks": 120,
	})
	_tick_for(sim, 90)
	var result := {
		"hash": sim.state_hash(),
		"target_hp": target.hp,
		"target_max_hp": target.max_hp,
		"exploded": _has_cue(sim, "projectile.explode"),
	}
	sim.queue_free()
	return result


func _tick_for(sim: VCSim, ticks: int) -> void:
	for _i in range(ticks):
		sim.tick_sim(DT)


func _has_cue(sim: VCSim, cue_id: String) -> bool:
	for cue in sim.cue_events:
		if String(cue.get("id", cue.get("event_id", ""))) == cue_id:
			return true
	return false
