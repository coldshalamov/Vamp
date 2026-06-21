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
# NOTE: no class_name — this script IS the `Sim` autoload singleton.
# Adding class_name here collides with the autoload name in GDScript.

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
	# TODO(spawn): construct player from clan data, spawn the slice district.
	player = SimEntity.new(rng.randi(), "player")
	player.pos = Vector2(400, 300)
	entities.append(player)

## Advance the world by exactly one fixed step. The ONLY place sim state mutates per-frame.
## delta must be the physics step (1.0/60.0). Do NOT pass wall-clock delta here.
func tick_sim(delta: float) -> void:
	assert(is_equal_approx(delta, 1.0 / 60.0), "Sim.tick_sim must receive the fixed step")
	tick += 1
	for e in entities:
		if is_instance_valid(e):
			e.step(delta, self)

## Apply a player input action. Recorded for replay if recording is on.
func apply_input(action: InputAction) -> void:
	if _recording:
		_recorded_inputs.append({ "tick": tick, "action": action.serialize() })
	if player != null and is_instance_valid(player):
		player.apply_action(action, self)

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
