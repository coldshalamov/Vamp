## Sim.gd — the deterministic authoritative game state.
##
## This is the single source of truth for all gameplay. It is a pure-data/pure-logic
## singleton: it must NOT touch Nodes, the scene tree, rendering, Input, OS time, or any
## source of nondeterminism. The scene tree is a VIEW that reads Sim state each frame
## and draws it. Render code never mutates Sim state.
##
## Determinism contract (HANDOFF §6 guardrail #6, REVAMP_SPEC §2.1):
##   - All randomness routes through `rng` (a seeded RandomNumberGenerator).
##   - ZERO calls to randf()/randi()/randf_range()/Time.get_ticks_usec()/etc. in src/sim/
##     and src/entities/. A pre-commit grep enforces this.
##   - Sim.tick(delta) is the only mutator of sim state. delta is the FIXED physics step
##     (1/60s) — never wall-clock.
##   - A recorded input sequence replays byte-stably across runs with the same seed.
##
extends Node
# Registered as both: (1) the `Sim` autoload singleton at runtime (in-game), and
# (2) the `VCSim` type so headless tests can instantiate it via VCSim.new() — Godot 4.7
# removed GDScript.new(), but typed classes still support .new(). The two coexist: the
# type name is VCSim, the singleton instance is Sim. GUT's CLI entry doesn't always load
# project autoloads, so tests must use the type, not the global.
class_name VCSim

# --- the seeded RNG — every random roll in the game goes through this ---
var rng := RandomNumberGenerator.new()

# --- world state (grown incrementally; fields added as systems land) ---
var tick: int = 0                      # physics ticks since boot (the canonical clock)
var seed_value: int = 0
var time_scale: float = 1.0            # for slowmo; sim still advances in fixed steps
var player: SimEntity = null           # the player entity (created on new_game)
var entities: Array[SimEntity] = []    # all updatable entities
var world: SimWorld = null             # the level/district

# --- recording/replay (for deterministic tests) ---
var _recorded_inputs: Array = []
var _replay_queue: Array = []
var _recording: bool = false

## Initialise a fresh game. Deterministic given the same seed.
## Fully resets all sim state so repeated calls (e.g. in the determinism test) are clean.
func new_game(seed_value: int, clan_id: String) -> void:
	self.seed_value = seed_value
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	tick = 0
	time_scale = 1.0
	entities.clear()
	_recorded_inputs.clear()
	_replay_queue.clear()
	_recording = false
	# Player entity always carries a SimPlayer behaviour (the verbs). TODO(spawn): later,
	# construct from clan data + spawn the slice district; for now the slice is a void.
	player = SimEntity.new(rng.randi(), "player")
	player.pos = Vector2(400, 300)
	player.behaviour = SimPlayer.new(player)
	entities.append(player)

## Advance the world by exactly one fixed step. The ONLY place sim state mutates per-frame.
## delta must be the physics step (1.0/60.0). Do NOT pass wall-clock delta here.
func tick_sim(delta: float) -> void:
	assert(is_equal_approx(delta, 1.0 / 60.0), "Sim.tick_sim must receive the fixed step")
	tick += 1
	for e in entities:
		if is_instance_valid(e):
			e.step(delta, self)
	# resolve combat: any entity in the active window of an action hits overlapping targets
	tick_combat()

## Check active action windows against nearby targets and resolve hits.
func tick_combat() -> void:
	for attacker in entities:
		if not is_instance_valid(attacker) or attacker.dead or attacker.current_action == null:
			continue
		if attacker.action_phase() != "active":
			continue
		var def: ActionDef = attacker.current_action.def
		if def.damage <= 0.0:
			continue   # non-damaging action (e.g. dash) — no hit resolution
		# already-connected this active window? skip (prevents multi-hit per swing)
		if attacker.current_action.has_connected:
			continue
		attacker.current_action.has_connected = true
		# query targets within the action's range in the facing direction
		var hit_arc := 1.2   # ~69 degrees either side of facing
		for target in entities:
			if target == attacker or target.dead:
				continue
			var to_target := target.pos - attacker.pos
			var dist := to_target.length()
			if dist > def.range + target.radius:
				continue
			if dist > 1.0:
				var ang_to := to_target.angle()
				# smallest signed angular difference, wrapped to [-PI, PI]
				var da: float = fmod(ang_to - attacker.facing, TAU)
				if da > PI:
					da -= TAU
				elif da < -PI:
					da += TAU
				da = abs(da)
				if da > hit_arc:
					continue   # outside the attack arc
			# hit! resolve damage inline (combat logic lives in the sim, not a separate
			# class — premature abstraction created a circular ref between Sim and Combat).
			var dmg := _resolve_hit(attacker, def, target)
			if dmg > 0.0 and attacker.has_method("on_damage_dealt"):
				attacker.on_damage_dealt(dmg)
			if target.has_method("on_damage_taken"):
				target.on_damage_taken(dmg)

## Resolve one action hitting one target. Returns damage dealt. Seeded crit, deterministic.
func _resolve_hit(attacker: SimEntity, def: ActionDef, target: SimEntity) -> float:
	if target.dead:
		return 0.0
	var crit: bool = rng.randf() < 0.15
	var dmg: float = def.damage
	if crit:
		dmg *= 1.75
	dmg = max(1.0, dmg)
	target.hp -= dmg
	# hitstop freezes both on connection — the "weight" of the hit
	target.hitstop = max(target.hitstop, def.hitstop_ticks)
	attacker.hitstop = max(attacker.hitstop, def.hitstop_ticks)
	# knockback applies impulse along facing
	if def.knockback > 0.0:
		var dir := Vector2.RIGHT.rotated(attacker.facing)
		target.vel += dir * def.knockback
	# lifesteal
	if def.lifesteal > 0.0 and attacker.has_method("heal_blood"):
		attacker.heal_blood(dmg * def.lifesteal)
	if target.hp <= 0.0:
		target.hp = 0.0
		target.dead = true
	return dmg

## Apply a player input action. Recorded for replay if recording is on.
## Routes through the player entity's behaviour delegate (SimPlayer) — SimEntity itself
## has no apply_action, just as it has no step logic; behaviour owns the verbs.
func apply_input(action: InputAction) -> void:
	if _recording:
		_recorded_inputs.append({ "tick": tick, "action": action.serialize() })
	if player != null and is_instance_valid(player) and player.behaviour != null:
		if player.behaviour.has_method("apply_action"):
			player.behaviour.apply_action(action, self)

## Hash the full sim state — used by the determinism test (20 runs, same seed = same hash).
func state_hash() -> int:
	var h := hash(seed_value)
	h = hash([h, tick])
	for e in entities:
		if is_instance_valid(e):
			h = hash([h, e.state_hash()])
	return h

## Begin recording inputs for a deterministic replay capture.
func start_recording() -> void:
	_recording = true
	_recorded_inputs.clear()

## Replay a previously captured input sequence. Returns true when the queue is exhausted.
func replay_step() -> bool:
	while not _replay_queue.is_empty() and _replay_queue[0]["tick"] <= tick:
		var entry = _replay_queue.pop_front()
		var action = InputAction.deserialize(entry["action"])
		player.apply_action(action, self)
	return _replay_queue.is_empty()

func load_replay(inputs: Array) -> void:
	_replay_queue = inputs.duplicate()
