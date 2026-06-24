## CameraDirector.gd — gameplay camera: smooth follow, trauma shake, push-ins.
##
## Reads Sim.player position each frame. Listens to CueBus for trauma events.
## Respects Accessibility.reduced_motion.
extends Camera2D
class_name CameraDirector

const TRAUMA_DECAY := 0.9
const MAX_OFFSET := 12.0
const MAX_ROTATION := 2.5
const FOLLOW_SPEED := 0.17
const BASE_ZOOM := 2.4   # pull the camera in so the character reads as a character, not a speck

# B4 — directional kick on melee connect. Added into offset after the noise shake each frame,
# then decays to zero. Separate from trauma so the direction reads clearly.
const KICK_DECAY := 6.0
const KICK_MAG := 7.0         # pixels on a normal hit
const KICK_MAG_CRIT := 14.0   # pixels on a crit

@export var trauma: float = 0.0
@export var push_scale: float = 1.0

var _target_pos: Vector2 = Vector2.ZERO
var _noise: FastNoiseLite = null
var _kick: Vector2 = Vector2.ZERO   # B4 directional kick, decays per frame

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = 42
	_noise.frequency = 0.5
	_noise.fractal_octaves = 1
	position_smoothing_enabled = false
	process_callback = CAMERA2D_PROCESS_IDLE
	_register_cues()

func _register_cues() -> void:
	if CueBus == null:
		return
	# B4 — dedicated handler reads dir/crit from the melee connect payload so the camera
	# actually kicks in the attack direction. Registered separately from pounce.hit below
	# so the pounce handler is not broken when hit.connect's payload shape differs.
	CueBus.define("hit.connect", CueBus.Priority.COMBAT, {
		"camera": _on_hit_connect_cue,
		"duration_ms": 200,
	})
	CueBus.define("pounce.hit", CueBus.Priority.COMBAT, {
		"camera": _on_hit_cue,
		"duration_ms": 250,
	})
	CueBus.define("finisher.start", CueBus.Priority.CRITICAL, {
		"camera": _on_finisher_cue,
		"duration_ms": 600,
	})
	CueBus.define("masquerade.broken", CueBus.Priority.CRITICAL, {
		"camera": _on_alert_cue,
		"duration_ms": 400,
	})
	CueBus.define("heat.rise", CueBus.Priority.COMBAT, {
		"camera": _on_alert_cue,
		"duration_ms": 300,
	})
	CueBus.define("frenzy.start", CueBus.Priority.CRITICAL, {
		"camera": _on_frenzy_cue,
		"duration_ms": 800,
	})

func _process(delta: float) -> void:
	if Sim == null or Sim.player == null:
		return
	var target: Vector2 = Sim.player.pos
	_target_pos = _target_pos.lerp(target, FOLLOW_SPEED)
	position = _target_pos

	# Trauma shake
	if CueBus != null and CueBus.reduced_motion:
		trauma = 0.0
		_kick = Vector2.ZERO
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * delta)
	# B4 — directional kick decay: moves toward zero at KICK_DECAY units/sec
	_kick = _kick.move_toward(Vector2.ZERO, KICK_DECAY * delta * maxf(1.0, _kick.length()))
	if trauma > 0.0:
		var shake: float = trauma * trauma
		offset = _shake_offset(shake) + _kick
		rotation = _shake_rotation(shake)
	else:
		offset = _kick
		rotation = 0.0

	# Push-in recovery
	push_scale = lerpf(push_scale, 1.0, 5.0 * delta)
	zoom = Vector2.ONE * (BASE_ZOOM * push_scale)

func _shake_offset(amount: float) -> Vector2:
	var t: float = Time.get_ticks_msec() / 1000.0
	return Vector2(
		_noise.get_noise_2d(t * 80.0, 0.0) * MAX_OFFSET * amount,
		_noise.get_noise_2d(0.0, t * 80.0) * MAX_OFFSET * amount
	)

func _shake_rotation(amount: float) -> float:
	var t: float = Time.get_ticks_msec() / 1000.0
	return _noise.get_noise_2d(t * 60.0, t * 60.0) * MAX_ROTATION * amount

func add_trauma(amount: float) -> void:
	if CueBus != null and CueBus.reduced_motion:
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)

func push_in(amount: float) -> void:
	if CueBus != null and CueBus.reduced_motion:
		return
	push_scale = maxf(push_scale, 1.0 + amount)

## B4 — melee connect: directional camera kick along attack direction + crit-scaled trauma.
## Registered only to "hit.connect" so pounce.hit keeps the generic handler below.
func _on_hit_connect_cue(payload: Dictionary) -> void:
	if CueBus != null and CueBus.reduced_motion:
		return
	var is_crit: bool = bool(payload.get("crit", false))
	var dir: Vector2 = payload.get("dir", Vector2.ZERO)
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	# Kick the camera in the attack direction — a short sharp jerk then noise-shake.
	var mag: float = KICK_MAG_CRIT if is_crit else KICK_MAG
	_kick += dir * mag
	add_trauma(0.55 if is_crit else 0.35)
	push_in((0.55 if is_crit else 0.35) * 0.08)

func _on_hit_cue(payload: Dictionary) -> void:
	var magnitude: float = payload.get("magnitude", 0.35)
	add_trauma(magnitude)
	push_in(magnitude * 0.08)

func _on_finisher_cue(_payload: Dictionary) -> void:
	add_trauma(0.8)
	push_in(0.06)

func _on_alert_cue(_payload: Dictionary) -> void:
	add_trauma(0.45)

func _on_frenzy_cue(_payload: Dictionary) -> void:
	add_trauma(0.7)
	push_in(0.04)
