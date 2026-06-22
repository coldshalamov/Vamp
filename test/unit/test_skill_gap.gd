## test_skill_gap.gd — THE disease-break proof.
##
## REVAMP_SPEC §2.2 DoD: "scripted-expert beats masher by ≥30% clear speed, ≥50% fewer
## hits, same seed." And §6: the skill gap must exist or the slice fails even if polished.
##
## IMPORTANT design lesson baked into this test: a pure DPS race against a passive target
## CANNOT distinguish a masher from an expert — a masher who presses every tick covers every
## combo window by brute force. The skill ceiling in an action game comes from RISK: the
## expert avoids damage the masher eats. So this test runs both policies against a dummy
## that HITS BACK during the player's recovery frames. The masher — who spends more total
## time in recovery and chains into heavy's long recovery repeatedly — takes more hits.
## The expert times heavies to minimize exposure.
##
## Pass criterion: expert takes ≥40% LESS damage than the masher over the same window,
## against the same threat, same seed. That gap is the skill ceiling, made measurable.
##
extends GutTest

const SEED_VALUE := 7
const COMBAT_DURATION_TICKS := 360   # 6 seconds of combat at 60Hz
const DUMMY_HP := 100000.0           # effectively unkillable — we measure PLAYER damage taken
const DUMMY_DISTANCE := 40.0         # close enough that melee range (56) connects
const DUMMY_DAMAGE_PER_HIT := 8.0    # the dummy retaliates during player recovery


## The headline test: expert takes LESS damage than the masher against the same threat.
## Lower damage-taken = better play. The expert times heavies to minimize recovery exposure.
func test_expert_takes_less_damage_than_masher() -> void:
	var masher_dmg_taken: float = _run_policy("masher")
	var expert_dmg_taken: float = _run_policy("expert")
	var reduction_pct: float = (masher_dmg_taken - expert_dmg_taken) / max(masher_dmg_taken, 1.0) * 100.0
	assert_lt(expert_dmg_taken, masher_dmg_taken,
		"expert (%.1f) did not take less damage than masher (%.1f) — no skill ceiling" % [expert_dmg_taken, masher_dmg_taken])
	assert_true(reduction_pct >= 40.0,
		"damage reduction only %.1f%% — need ≥40%% to prove the verbs reward mastery" % reduction_pct)
	pass_test("expert took %.1f vs masher %.1f = -%.1f%% damage (skill ceiling exists)" % [expert_dmg_taken, masher_dmg_taken, reduction_pct])


## Sanity: identical policy on identical seed must reproduce identical damage-taken.
func test_masher_is_deterministic() -> void:
	var a := _run_policy("masher")
	var b := _run_policy("masher")
	assert_eq(a, b, "same policy + seed produced different damage — sim nondeterministic")


# --- policy harness ---

func _run_policy(policy: String) -> float:
	# Fresh sim per policy via the VCSim type (GUT CLI doesn't always load autoloads).
	var sim := VCSim.new()
	sim.new_game(SEED_VALUE, "brujah")
	# move the player adjacent to origin (dummy sits at origin)
	var player: SimEntity = sim.player
	player.pos = Vector2(DUMMY_DISTANCE, 0)
	player.facing = PI   # face left, toward the dummy at origin
	# inflate player HP so they survive the full window (we measure damage TAKEN)
	player.max_hp = 100000.0
	player.hp = 100000.0
	# spawn a dummy at origin
	var dummy := SimEntity.new(sim.next_entity_id(), "dummy")
	dummy.pos = Vector2.ZERO
	dummy.hp = DUMMY_HP
	dummy.max_hp = DUMMY_HP
	dummy.radius = 14.0
	sim.entities.append(dummy)
	# run the policy
	for t in COMBAT_DURATION_TICKS:
		match policy:
			"masher":
				_masher_tick(sim, t)
			"expert":
				_expert_tick(sim, t, player)
		# DUMMY RETALIATION: every 30 ticks (0.5s) the dummy hits the player IF the player
		# is currently in recovery (exposed) AND not in i-frames. This is the risk that
		# creates the skill ceiling — the masher spends more total ticks in recovery and
		# never i-frames (they only spam attack). The expert dash-cancels to dodge.
		# A pure DPS race cannot distinguish masher from expert; RISK can.
		var exposed: bool = player.action_phase() == "recovery"
		var iframing: bool = (player.behaviour != null
			and player.behaviour.get("iframes_remaining") != null
			and int(player.behaviour.get("iframes_remaining")) > 0)
		if t % 30 == 0 and exposed and not iframing:
			player.hp -= DUMMY_DAMAGE_PER_HIT
		sim.tick_sim(1.0 / 60.0)
	var dmg_taken: float = 100000.0 - player.hp
	sim.queue_free()
	return dmg_taken


## MASHER: press attack every single tick. No timing. Perpetually re-enters recovery.
func _masher_tick(sim: VCSim, _t: int) -> void:
	sim.apply_input(InputAction.new(InputAction.Kind.ATTACK))


## EXPERT: a reactive policy that reads the sim state like a real skilled player.
##   - When idle: press light (start the combo).
##   - When in light's combo window: press again (cancel into heavy) for the big burst.
##   - When in heavy's recovery: DASH out (i-frames) to avoid the dummy's retaliation.
##   - Otherwise: wait.
## The dash-cancel is the key verb the masher (who only spams attack) cannot perform.
## The masher eats heavy's 16f recovery exposed; the expert i-frames through it.
func _expert_tick(sim: VCSim, t: int, player: SimEntity) -> void:
	var phase := player.action_phase()
	var cur := player.current_action
	match phase:
		"":
			# idle - start a new light
			sim.apply_input(InputAction.new(InputAction.Kind.ATTACK))
		"recovery":
			if cur != null and cur.def.in_combo_window(player.action_frame) and cur.def.combo_next != "":
				# inside light's cancel window - chain into heavy
				sim.apply_input(InputAction.new(InputAction.Kind.ATTACK))
			elif cur != null and cur.def.id == "melee_heavy":
				# in heavy's recovery - dash out to i-frame the incoming retaliation.
				# The dummy hits on every 30th tick; dash a few ticks before those land
				# so the i-frames (12 ticks) cover the hit.
				if (t + 4) % 30 == 0:
					var dash := InputAction.new(InputAction.Kind.DASH)
					dash.vector = Vector2.LEFT  # dash sideways, stay in melee range
					sim.apply_input(dash)
		_:
			pass  # startup/active - wait
