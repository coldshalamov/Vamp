## Piloted locomotion — proves the player no longer moves at an instant constant speed (the "float"):
## it accelerates from rest and glides to a stop with momentum. Deterministic (move_vel is hashed).
extends GutTest

const DT := 1.0 / 60.0


func test_accelerates_from_rest_not_instant() -> void:
	var sim := VCSim.new()
	sim.new_game(3, "brujah")
	var pb := sim.player.behaviour
	_press(sim, Vector2.RIGHT)
	sim.tick_sim(DT)
	var v1: Vector2 = pb.get("move_vel")
	var top := float(pb.get("move_speed"))
	assert_gt(v1.length(), 0.0, "should begin moving")
	assert_lt(v1.length(), top, "should not hit full speed in one tick (acceleration ramp)")
	for _t in range(20):
		sim.tick_sim(DT)
	var v2: Vector2 = pb.get("move_vel")
	assert_gt(v2.length(), v1.length(), "should keep accelerating toward full speed")
	sim.queue_free()


func test_glides_to_a_stop() -> void:
	var sim := VCSim.new()
	sim.new_game(3, "brujah")
	var pb := sim.player.behaviour
	_press(sim, Vector2.RIGHT)
	for _t in range(20):
		sim.tick_sim(DT)
	var moving: Vector2 = pb.get("move_vel")
	assert_gt(moving.length(), 50.0, "should be up to speed")
	_press(sim, Vector2.ZERO)   # release
	sim.tick_sim(DT)
	var after: Vector2 = pb.get("move_vel")
	assert_gt(after.length(), 0.0, "should glide on release, not halt instantly (momentum)")
	assert_lt(after.length(), moving.length(), "should be decelerating")
	sim.queue_free()


func _press(sim: VCSim, dir: Vector2) -> void:
	var a := InputAction.new(InputAction.Kind.MOVE)
	a.vector = dir
	sim.apply_input(a)
