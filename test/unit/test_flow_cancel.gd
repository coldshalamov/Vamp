## test_flow_cancel.gd — gulp-as-master-cancel: a tight "perfect" combo cancel builds FLOW, which
## raises melee damage (the combat skill ceiling). Deterministic.
extends GutTest

const DT := 1.0 / 60.0


func test_flow_raises_melee_damage() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var pb: SimPlayer = sim.player.behaviour
	var t1: SimEntity = sim.spawn_npc("ped", Vector2(400, 400), {})
	var hp0: float = t1.hp
	sim.damage_entity(sim.player, t1, 20.0, { "damage_type": "physical" })
	var base: float = hp0 - t1.hp

	pb.flow_stacks = 4
	var t2: SimEntity = sim.spawn_npc("ped", Vector2(420, 400), {})
	var hp2: float = t2.hp
	sim.damage_entity(sim.player, t2, 20.0, { "damage_type": "physical" })
	var flowed: float = hp2 - t2.hp
	assert_true(flowed > base, "flow raises melee damage (%.1f > %.1f)" % [flowed, base])


func test_perfect_cancel_builds_flow() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var p: SimEntity = sim.player
	var pb: SimPlayer = p.behaviour
	sim.apply_input(InputAction.new(InputAction.Kind.ATTACK))   # begin the light swing
	var chained := false
	for i in range(40):
		sim.tick_sim(DT)
		if p.action_phase() == "recovery" and p.current_action != null and p.current_action.def.in_combo_window(p.action_frame):
			sim.apply_input(InputAction.new(InputAction.Kind.ATTACK))   # cancel at the first in-window frame = perfect
			chained = true
			break
	assert_true(chained, "reached the combo window")
	assert_true(pb.flow_stacks > 0, "a perfect cancel built flow (stacks=%d)" % pb.flow_stacks)
