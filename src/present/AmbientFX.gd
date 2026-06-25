## AmbientFX.gd — the air, made faintly alive. A VERY subtle, VERY cheap persistent atmosphere
## layer: slow-drifting dust motes that hang in the streetlight, plus an optional faint rising
## steam/haze wisp (the breath of grates and gutters). It exists to kill the "dead vacuum" feel of
## an empty street — never to be noticed directly. Readability and perf come first; if you can SEE
## it as an effect, it's turned up too far.
##
## Presentation-only: subscribes to CueBus read-only and READS Sim.player.pos for positioning only —
## it NEVER touches Sim.rng, never mutates state, never imports anything under src/sim or src/entities.
##
## GL Compatibility / Intel iGPU discipline:
##  - TWO continuous GPUParticles2D (motes <=60, steam <=24) — no per-frame draw(), no pools to fire.
##  - local_coords = false: spawned motes keep drifting in WORLD space (they feel like physical air,
##    not a HUD overlay glued to the camera). Each frame we re-anchor the emitter node + visibility_rect
##    to the player/camera centre so the field is always populated on screen and never culled.
##  - A handful of LARGE soft sprites (per-pixel soft-alpha ImageTexture — GradientTexture2D leaves
##    opaque square corners) at very low alpha, rather than a swarm of tiny dots.
##  - dawn.warning / dawn.arrived gently fade the motes out as the sky greys toward day; no shaders.
extends Node2D
class_name AmbientFX

const MOTE_COUNT := 56          # <= 60: large faint sprites, not a swarm
const STEAM_COUNT := 20         # <= 24: a slow, sparse haze
const MOTE_LIFETIME := 9.0      # long life -> very slow, sleepy drift
const STEAM_LIFETIME := 6.0
const MOTE_TEX_SIZE := 48       # large, soft
const STEAM_TEX_SIZE := 64
# Half-extents of the field we seed around the player. Sized past the visible rect (camera zoom ~2.4)
# so motes already exist before they enter frame and there's no spawn "pop" at the edges.
const FIELD_HALF := Vector2(520.0, 360.0)

# Cosmetic intensity, eased toward a target so dawn fades read smoothly. 1.0 = full faint presence.
var _intensity: float = 1.0
var _intensity_target: float = 1.0

var _motes: GPUParticles2D = null
var _steam: GPUParticles2D = null
var _mote_base_alpha: float = 0.0
var _steam_base_alpha: float = 0.0


func _ready() -> void:
	# World-space, above the ground/road (z ~ 0-5) but below the actors (z ~ 20) so motes hang in the
	# air in front of the street yet never occlude a character's silhouette or readability.
	z_index = 14

	var mote_tex := _soft_dot(MOTE_TEX_SIZE)
	var steam_tex := _soft_dot(STEAM_TEX_SIZE)

	_motes = _make_emitter(mote_tex, MOTE_COUNT, MOTE_LIFETIME, _mote_material())
	add_child(_motes)
	_steam = _make_emitter(steam_tex, STEAM_COUNT, STEAM_LIFETIME, _steam_material())
	add_child(_steam)

	# Seed the field at the current player position so the very first frame isn't empty.
	var anchor := _anchor_pos()
	_motes.position = anchor
	_steam.position = anchor
	# visibility_rect is node-local and constant in size, so set it once here (not per-frame).
	_set_visibility_rect(_motes, FIELD_HALF)
	_set_visibility_rect(_steam, FIELD_HALF)

	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)
	# Establish the faint base alpha BEFORE the first rendered frame. _apply_intensity only runs in
	# _process when intensity is easing, and at boot intensity == target, so without this the emitters
	# would render at full modulate.a (10-20x too opaque) until the first dawn cue. Hard "barely-there".
	_apply_intensity()


func _process(delta: float) -> void:
	# Ease cosmetic intensity toward its target (dawn fade) — purely visual, decoupled from any sim value.
	if not is_equal_approx(_intensity, _intensity_target):
		_intensity = move_toward(_intensity, _intensity_target, delta * 0.4)
		_apply_intensity()

	if _motes == null:
		return

	# Re-anchor the emitters to the camera/player centre. With local_coords=false the already-spawned
	# motes keep drifting in world space (physical air), while new ones spawn around wherever the player
	# now is — so the field stays on screen as the camera follows. Null-guard the camera/sim for headless.
	var anchor := _anchor_pos()
	_motes.position = anchor
	_steam.position = anchor


## Read-only world anchor: prefer the live camera centre (matches what the player sees), fall back to
## the player position, then origin. Never writes anything.
func _anchor_pos() -> Vector2:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam != null:
		return cam.get_screen_center_position()
	if Sim != null and Sim.player != null:
		return Sim.player.pos
	return Vector2.ZERO


func _on_cue(event_id: String, _payload: Dictionary) -> void:
	# As the night greys toward dawn, the motes/steam fade — the air goes flat and lifeless before day.
	match event_id:
		"dawn.warning":
			_intensity_target = 0.45
		"dawn.arrived":
			_intensity_target = 0.0
		_:
			pass


func _apply_intensity() -> void:
	if _motes != null:
		_motes.modulate.a = _mote_base_alpha * _intensity
	if _steam != null:
		_steam.modulate.a = _steam_base_alpha * _intensity


# --- emitter construction ---

func _make_emitter(tex: Texture2D, count: int, life: float, mat: ParticleProcessMaterial) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.texture = tex
	p.amount = count
	p.lifetime = life
	p.one_shot = false
	p.emitting = true
	p.local_coords = false          # spawned motes persist in world space as the emitter moves
	p.preprocess = life             # start with a full, settled field (no fade-in from empty on boot)
	p.fixed_fps = 20                # iGPU budget: 20 Hz sim is plenty for near-static drifting air
	p.interpolate = true            # smooth the low fixed_fps so motion doesn't look steppy
	p.process_material = mat
	return p


# --- particle process materials (one instance each) ---

## Dust motes: near-zero gravity, slow random velocity, gentle turbulence, low alpha. They barely move.
func _mote_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	# Spawn across a wide box around the player so the air is filled, not puffing from a point.
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(FIELD_HALF.x, FIELD_HALF.y, 1.0)
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 180.0                       # any direction
	m.gravity = Vector3(0.0, -2.0, 0.0)    # the faintest upward lilt
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 11.0          # slow, sleepy drift
	m.damping_min = 0.5
	m.damping_max = 2.0
	# Gentle turbulence so motes wander instead of tracking dead-straight lines.
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 6.0
	m.turbulence_noise_scale = 1.2
	m.turbulence_influence_min = 0.05
	m.turbulence_influence_max = 0.15
	m.scale_min = 0.18
	m.scale_max = 0.5
	# Faint cool dust catching the streetlight.
	m.color = Color(0.74, 0.78, 0.86, 1.0)
	# Fade in from nothing, hold faint, fade out — so motes wink softly rather than hard-clip.
	_mote_base_alpha = 0.10
	m.color_ramp = _life_ramp(
		Color(0.74, 0.78, 0.86, 0.0),
		Color(0.78, 0.82, 0.90, 1.0),
		Color(0.70, 0.74, 0.84, 0.0))
	return m


## Steam/haze wisp: a slow, sparse rise — the breath off grates. Wide, soft, very low alpha.
func _steam_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(FIELD_HALF.x, FIELD_HALF.y * 0.6, 1.0)
	m.direction = Vector3(0.0, -1.0, 0.0)  # rises
	m.spread = 18.0
	m.gravity = Vector3(0.0, -16.0, 0.0)   # a slow updraft
	m.initial_velocity_min = 6.0
	m.initial_velocity_max = 18.0
	m.damping_min = 1.0
	m.damping_max = 4.0
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 10.0
	m.turbulence_noise_scale = 0.8
	m.turbulence_influence_min = 0.08
	m.turbulence_influence_max = 0.2
	# Wisps swell as they rise (warmer near the ground, cooling as they thin out).
	m.scale_min = 0.6
	m.scale_max = 1.4
	m.color = Color(0.60, 0.62, 0.66, 1.0)
	_steam_base_alpha = 0.05
	m.color_ramp = _life_ramp(
		Color(0.60, 0.62, 0.66, 0.0),
		Color(0.64, 0.66, 0.70, 1.0),
		Color(0.58, 0.60, 0.64, 0.0))
	return m


# --- texture / helpers ---

## A large soft round sprite with a genuinely transparent feathered edge (per-pixel alpha falloff).
## GradientTexture2D FILL_RADIAL leaves opaque square corners, reading as hard squares — this builds a
## real circle whose alpha eases to zero at the rim so the motes melt into the dark.
func _soft_dot(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	var r := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - c, float(y) - c).length() / r
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * a   # cube the falloff -> a soft glowing core that fades long before the edge
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


## A three-stop life ramp (fade in -> hold -> fade out) so particles never pop on or off.
func _life_ramp(start_col: Color, mid_col: Color, end_col: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, start_col)
	g.add_point(0.5, mid_col)
	g.set_color(1, end_col)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## Centre the GPU visibility rect on the emitter's current world position so the field is never culled
## as the camera follows the player. (local_coords=false particles live in world space.)
func _set_visibility_rect(p: GPUParticles2D, half: Vector2) -> void:
	if p == null:
		return
	# visibility_rect is in the node's LOCAL space; the node sits at the anchor, so the rect is centred.
	var pad := Vector2(64.0, 64.0)
	p.visibility_rect = Rect2(-(half + pad), (half + pad) * 2.0)
