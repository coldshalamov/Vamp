## SimPlayer.gd — the player entity in the sim.
##
## Consumes InputActions and drives the ActionDef frame-data state machine. This is where
## the skill ceiling lives: a masher calls attack repeatedly and eats recovery; a skilled
## player times the cancel input during the combo window and chains light->heavy or
## cancels recovery into a dash. The gap between them is measurable on a fixed seed
## (see test_skill_gap.gd).
##
extends RefCounted
class_name SimPlayer

const ACTION_LIGHT := preload("res://data/powers/melee_light.tres")
const ACTION_HEAVY := preload("res://data/powers/melee_heavy.tres")
const ACTION_DASH := preload("res://data/powers/dash.tres")

# movement
var move_dir: Vector2 = Vector2.ZERO
var move_speed: float = 220.0   # px/sec

# combat economy
var blood: float = 100.0
var max_blood: float = 100.0
var hp: float = 100.0
var max_hp: float = 100.0

# combo memory — did the player press attack during the current combo window?
var _buffered_attack: bool = false
var _combo_count: int = 0   # 0 = light, 1 = heavy (next in chain)

# i-frame state (from dash)
var iframes_remaining: int = 0

# damage dealt this run — used by the skill-gap benchmark
var damage_dealt: float = 0.0
var damage_taken: float = 0.0

# owned SimEntity state (composition — SimPlayer IS-A SimEntity for the spatial/action layer)
var entity: SimEntity

func _init(e: SimEntity) -> void:
	entity = e

## Consume a player intent. Called by Sim.apply_input.
func apply_action(action: InputAction, _sim) -> void:
	match action.kind:
		InputAction.Kind.MOVE:
			move_dir = action.vector.normalized() if action.vector.length() > 0.01 else Vector2.ZERO
			# face the move direction
			if move_dir != Vector2.ZERO:
				entity.facing = move_dir.angle()
		InputAction.Kind.ATTACK:
			_try_attack()
		InputAction.Kind.DASH:
			_try_dash(action.vector)
		InputAction.Kind.RELEASE:
			# release of attack clears a held buffer (for future hold-to-heavy)
			pass

## Per-tick step. Called by the entity's step() via composition.
func step(delta: float, _sim) -> void:
	# i-frames tick down
	if iframes_remaining > 0:
		iframes_remaining -= 1
	# movement is locked during startup/active of an action; allowed during recovery/idle
	var phase := entity.action_phase()
	var can_move := (phase == "" or phase == "recovery")
	if can_move and move_dir != Vector2.ZERO:
		entity.pos += move_dir * move_speed * delta

## Attempt to begin an attack, respecting the cancel/combo rules.
##
## DESIGN: the combo cancel requires a FRESH press during the combo window. Presses
## during startup/active are DROPPED (not buffered) — this is what creates the skill
## ceiling. A masher who holds/spams attack has their pre-window presses consumed and
## must time a new press into the window to chain; an expert does exactly that. If we
## buffered presses, mashing would always have one in the window and there'd be no gap.
func _try_attack() -> void:
	var phase := entity.action_phase()
	match phase:
		"":
			# idle - start a fresh light
			if entity.begin_action(ACTION_LIGHT, null):
				_combo_count = 0
		"recovery":
			# ONLY a press landing inside the combo window chains. Outside it, the press
			# is dropped (no buffer) — the player must time it.
			if entity.current_action != null:
				var cur_def: ActionDef = entity.current_action.def
				if cur_def.in_combo_window(entity.action_frame) and cur_def.combo_next != "":
					var next_def := _get_action_def(cur_def.combo_next)
					if next_def != null:
						entity.begin_action(next_def, null)
						_combo_count = 1
			# else: press dropped — recovery must be eaten. This is the punish for spamming.
		_:
			# startup/active — press dropped. No buffering.
			pass

## Attempt a dash — cancels any recovery, sets i-frames.
func _try_dash(dir: Vector2) -> void:
	if not entity.can_cancel_into(ACTION_DASH) and entity.action_phase() != "":
		# can only dash from idle or as a cancel from recovery
		if entity.action_phase() != "recovery":
			return
	if entity.begin_action(ACTION_DASH, null):
		var dash_dir := dir if dir.length() > 0.01 else Vector2.RIGHT.rotated(entity.facing)
		# apply the blink displacement immediately on startup
		entity.pos += dash_dir.normalized() * ACTION_DASH.range
		entity.facing = dash_dir.angle()
		iframes_remaining = 12   # 0.2s of intangibility

func _get_action_def(id: String) -> ActionDef:
	match id:
		"melee_light": return ACTION_LIGHT
		"melee_heavy": return ACTION_HEAVY
		"dash": return ACTION_DASH
	return null
