## SimEntity.gd — base class for everything in the sim that ticks.
##
## Pure data + logic. NO Nodes, NO rendering. The scene tree mirrors these as sprites.
## Subclasses (SimPlayer, SimNPC, SimProjectile, ...) add behaviour; this holds the
## shared spatial/state/animation-track substrate.
##
## Determinism: all randomness must come from `sim.rng`. Never call global rand*().
##
extends RefCounted
class_name SimEntity

var id: int
var kind: String                  # "player" | "npc" | "projectile" | "prop" ...
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var facing: float = 0.0           # radians
var radius: float = 12.0          # for collision queries
var dead: bool = false

# --- action/animation state (the frame-data layer) ---
var current_action: ActionState = null   # what we're doing right now (startup/active/recovery)
var action_frame: int = 0                # ticks elapsed in current_action
var cooldowns: Dictionary = {}           # action_id -> ticks remaining
var stun: int = 0                        # ticks of hard CC (can't act)
var hitstop: int = 0                     # ticks frozen on connection (handled in step)

# --- health/damage (subclasses specialise) ---
var hp: float = 100.0
var max_hp: float = 100.0

func _init(entity_id: int, entity_kind: String) -> void:
	id = entity_id
	kind = entity_kind

## Advance this entity by one fixed tick. Override in subclasses; call super first.
func step(delta: float, sim) -> void:
	if dead:
		return
	# hitstop freezes the entity in place (but the sim clock keeps ticking globally).
	if hitstop > 0:
		hitstop -= 1
		return
	if stun > 0:
		stun -= 1
	# advance the active action's frame counter
	if current_action != null:
		action_frame += 1
	# tick down cooldowns
	var expired: Array = []
	for key in cooldowns:
		cooldowns[key] -= 1
		if cooldowns[key] <= 0:
			expired.append(key)
	for key in expired:
		cooldowns.erase(key)
	# integrate velocity (fixed step)
	pos += vel * delta
	# friction — tunable per entity
	vel *= 0.86

## Begin an action defined by `def`. Returns false if we can't (cooldown/stun/recovery-lock).
func begin_action(def: ActionDef, sim) -> bool:
	if stun > 0 or hitstop > 0:
		return false
	if cooldowns.has(def.id) and cooldowns[def.id] > 0:
		return false
	current_action = ActionState.new(def)
	action_frame = 0
	cooldowns[def.id] = def.cooldown_ticks
	return true

## Which frame-phase of the current action are we in? null if none.
func action_phase() -> String:
	if current_action == null:
		return ""
	var def := current_action.def
	if action_frame < def.startup:
		return "startup"
	if action_frame < def.startup + def.active:
		return "active"
	if action_frame < def.startup + def.active + def.recovery:
		return "recovery"
	return "done"

## Can we cancel the current action's recovery into `next_def`? (the combo system)
func can_cancel_into(next_def: ActionDef) -> bool:
	if current_action == null:
		return true
	if action_phase() != "recovery":
		return false
	return current_action.def.cancel_into.has(next_def.id)

## Deterministic hash of this entity's state — feeds Sim.state_hash() for replay tests.
func state_hash() -> int:
	return hash([id, kind, pos, vel, facing, hp, action_phase(), stun, hitstop])
