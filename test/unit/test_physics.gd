## ImpulsePhysics — proves the solver is REAL (damages both bodies by impact, not a constant) and
## bit-deterministic (the 20-run gate's invariant, exercised on an 8-body pile-up).
extends GutTest

const DT := 1.0 / 60.0


func test_impulse_damages_both_bodies() -> void:
	var sim := VCSim.new()
	sim.new_game(1, "brujah")
	var a := sim.spawn_npc("thug", Vector2(600.0, 600.0), {})
	var b := sim.spawn_npc("thug", Vector2(648.0, 600.0), {})
	a.ai_state = "idle"
	b.ai_state = "idle"
	var hpa0 := a.hp
	var hpb0 := b.hp
	a.knockback_vel = Vector2(420.0, 0.0)   # 'a' is hurled into 'b'
	for _t in range(24):
		sim.tick_sim(DT)
	# The rejected anti-pattern damaged only the target; a real collision hurts BOTH.
	assert_lt(a.hp, hpa0, "the hurled body must take impact damage too")
	assert_lt(b.hp, hpb0, "the struck body must take impact damage")
	sim.queue_free()


func test_impact_damage_scales_with_speed() -> void:
	var slow := _ram_damage(120.0)
	var fast := _ram_damage(520.0)
	assert_gt(fast, slow, "a faster impact must hurt more (no constant damage)")


func _ram_damage(speed: float) -> float:
	var sim := VCSim.new()
	sim.new_game(2, "brujah")
	var a := sim.spawn_npc("thug", Vector2(600.0, 600.0), {})
	var b := sim.spawn_npc("thug", Vector2(644.0, 600.0), {})
	a.ai_state = "idle"
	b.ai_state = "idle"
	var hpb0 := b.hp
	a.knockback_vel = Vector2(speed, 0.0)
	for _t in range(20):
		sim.tick_sim(DT)
	var lost := hpb0 - b.hp
	sim.queue_free()
	return lost


func test_physics_is_deterministic() -> void:
	assert_eq(_pileup_hash(), _pileup_hash(), "the impulse pass must be bit-deterministic")


func _pileup_hash() -> int:
	var sim := VCSim.new()
	sim.new_game(999, "brujah")
	var c: Vector2 = sim.player.pos
	for i in range(8):
		var ang := TAU * float(i) / 8.0
		var e := sim.spawn_npc("thug", c + Vector2.RIGHT.rotated(ang) * 80.0, {})
		e.knockback_vel = (c - e.pos).normalized() * 240.0
	for _t in range(90):
		sim.tick_sim(DT)
	var h := sim.state_hash()
	sim.queue_free()
	return h
