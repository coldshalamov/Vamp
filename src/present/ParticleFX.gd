## ParticleFX.gd — GPUParticles2D combat spectacle. Directional blood spray on every hit, a particle
## dissolve burst when a body drops, and dust puffs on dashes — replacing flat draw_arc sparks with
## real particle systems (the BloodRenderer still owns the persistent ground pools; this is the
## transient airborne spray on top).
##
## Presentation-only: subscribes to CueBus read-only, never touches Sim or Sim.rng. GL Compatibility
## note — emit_particle() is unsupported on this renderer, so each effect is a POOLED one-shot
## GPUParticles2D re-fired with restart(); fixed pools bound the node and particle counts (freeze-safe).
extends Node2D
class_name ParticleFX

const BLOOD_POOL := 12
const DEATH_POOL := 6
const DUST_POOL := 8

var _blood: Array[GPUParticles2D] = []
var _death: Array[GPUParticles2D] = []
var _dust: Array[GPUParticles2D] = []
var _bi := 0
var _di := 0
var _ui := 0

# Footstep dust: polled from the player's motion (there is no per-step sim cue), so a stride kicks
# up a small puff. Read-only view of Sim.player.
var _last_player_pos := Vector2.ZERO
var _have_last := false
var _step_accum := 0.0


func _ready() -> void:
	z_index = 51   # above actors (z 20) and swing FX, below the mood grade + HUD
	var dot := _dot_texture(16)
	var blood_mat := _blood_material()
	var death_mat := _death_material()
	var dust_mat := _dust_material()
	for i in range(BLOOD_POOL):
		_blood.append(_make_emitter(dot, 18, 0.55, blood_mat))
	for i in range(DEATH_POOL):
		_death.append(_make_emitter(dot, 30, 0.95, death_mat))
	for i in range(DUST_POOL):
		_dust.append(_make_emitter(dot, 12, 0.5, dust_mat))
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _process(delta: float) -> void:
	# Footstep dust while the predator moves on foot — a stride's worth of travel kicks up a puff.
	if Sim == null or Sim.player == null or Sim.player.dead:
		_have_last = false
		return
	var p: Vector2 = Sim.player.pos
	if not _have_last:
		_last_player_pos = p
		_have_last = true
		return
	var moved := _last_player_pos.distance_to(p)
	_last_player_pos = p
	if moved / maxf(delta, 0.0001) > 55.0:
		_step_accum += moved
		if _step_accum >= 40.0:
			_step_accum = 0.0
			_fire(_dust, _ui, p + Vector2(0.0, 7.0), 0.0)
			_ui = (_ui + 1) % _dust.size()


func _on_cue(event_id: String, payload: Dictionary) -> void:
	match event_id:
		"hit.connect":
			var dir: Vector2 = payload.get("dir", Vector2.RIGHT)
			_fire(_blood, _bi, payload.get("pos", Vector2.ZERO), dir.angle() if dir.length_squared() > 0.001 else 0.0)
			_bi = (_bi + 1) % _blood.size()
		"damage.player":
			# The predator's own blood when struck — sprays upward off the body.
			_fire(_blood, _bi, payload.get("pos", Vector2.ZERO), -PI * 0.5)
			_bi = (_bi + 1) % _blood.size()
		"enemy.death", "feed.kill":
			_fire(_death, _di, payload.get("pos", Vector2.ZERO), 0.0)
			_di = (_di + 1) % _death.size()
		"move.dash":
			_fire(_dust, _ui, payload.get("pos", Vector2.ZERO), 0.0)
			_ui = (_ui + 1) % _dust.size()
		_:
			pass


func _fire(pool: Array, idx: int, pos: Vector2, rot: float) -> void:
	var p: GPUParticles2D = pool[idx]
	p.position = pos
	p.rotation = rot
	p.restart()


func _make_emitter(tex: Texture2D, count: int, life: float, mat: ParticleProcessMaterial) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.texture = tex
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0       # whole burst at once
	p.emitting = false
	p.local_coords = false      # particles keep simulating in world space after they leave the body
	p.process_material = mat
	add_child(p)
	return p


# --- particle process materials (one shared instance per effect family) ---

func _blood_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 4.0
	m.direction = Vector3(1.0, 0.0, 0.0)   # along the emitter's rotation (set per hit to the hit dir)
	m.spread = 40.0
	m.initial_velocity_min = 180.0
	m.initial_velocity_max = 430.0
	m.gravity = Vector3(0.0, 560.0, 0.0)
	m.damping_min = 20.0
	m.damping_max = 70.0
	m.scale_min = 0.12
	m.scale_max = 0.4
	m.color = Color(0.78, 0.05, 0.11, 1.0)
	m.color_ramp = _fade_ramp(Color(0.86, 0.10, 0.14, 1.0), Color(0.34, 0.0, 0.02, 0.0))
	return m


func _death_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 11.0
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 180.0                       # scatter outward in all directions
	m.initial_velocity_min = 55.0
	m.initial_velocity_max = 230.0
	m.gravity = Vector3(0.0, 260.0, 0.0)
	m.damping_min = 20.0
	m.damping_max = 70.0
	m.scale_min = 0.22
	m.scale_max = 0.8
	m.color = Color(0.52, 0.03, 0.08, 1.0)
	m.color_ramp = _fade_ramp(Color(0.62, 0.06, 0.10, 1.0), Color(0.10, 0.0, 0.02, 0.0))
	return m


func _dust_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 6.0
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 75.0
	m.initial_velocity_min = 18.0
	m.initial_velocity_max = 78.0
	m.gravity = Vector3(0.0, -28.0, 0.0)   # a little lift, like kicked-up grit
	m.damping_min = 40.0
	m.damping_max = 120.0
	m.scale_min = 0.3
	m.scale_max = 1.0
	m.color = Color(0.55, 0.55, 0.6, 1.0)
	m.color_ramp = _fade_ramp(Color(0.6, 0.6, 0.66, 0.5), Color(0.4, 0.4, 0.46, 0.0))
	return m


# --- texture / gradient helpers ---

## A soft round dot with a genuinely transparent edge (per-pixel alpha falloff). GradientTexture2D
## FILL_RADIAL left opaque corners, so particles read as hard red squares — this guarantees a circle.
func _dot_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	var r := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - c, float(y) - c).length() / r
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a   # ease the falloff so the core is solid and the rim is feathered
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _fade_ramp(from_col: Color, to_col: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, from_col)
	g.set_color(1, to_col)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
