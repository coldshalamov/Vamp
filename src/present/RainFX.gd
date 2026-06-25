## RainFX.gd — persistent GPU rain + ground splash for the rain-slicked noir night.
##
## REPLACES the old draw_line rain in AtmosphereDirector (the integrator disables that). A single
## continuous GPUParticles2D of fast, thin, diagonal cool-grey streaks (<=220) covers the camera
## viewport and is repositioned to the camera's screen-center every frame so it always fills the
## view, no matter where the predator prowls. A second cheap continuous emitter scatters tiny
## short-lived ground splash flecks under it. Subtle by design — atmosphere, not a curtain.
##
## Presentation-only: subscribes to CueBus read-only and READS Sim only for null-guarding; never
## touches Sim.rng or mutates state. GL Compatibility notes — continuous systems use emitting=true
## (emit_particle() is unsupported here), local_coords=false so streaks keep falling in world space
## as the emitter re-centres, and both particle textures are per-pixel soft-alpha ImageTextures
## (GradientTexture2D leaves opaque square corners). Counts are small and fixed (freeze-safe).
extends Node2D
class_name RainFX

const RAIN_COUNT := 220       # hard ceiling — thin streaks, sized large rather than many tiny dots
const SPLASH_COUNT := 48      # cheap ground flecks; idle-cheap, never a second curtain
const WIND_ANGLE := 0.22      # radians of lean off vertical (slight diagonal)
const COVER_MARGIN := 220.0   # extra world px around the view so streaks enter/exit off-screen

# How far above the camera centre rain is born, in screen-fractions of the visible height.
const SPAWN_ABOVE := 0.62

var _rain: GPUParticles2D = null
var _splash: GPUParticles2D = null
var _rain_mat: ParticleProcessMaterial = null
var _intensity: float = 1.0           # 0..1 — scales amount + visibility
var _base_rain_alpha: float = 0.0
var _base_splash_alpha: float = 0.0


func _ready() -> void:
	z_index = 55   # above the world, below the HUD

	var streak := _streak_texture(8, 40)
	var dot := _dot_texture(12)

	_rain_mat = _rain_material()
	_rain = _make_emitter(streak, RAIN_COUNT, 1.05, _rain_mat)
	_rain.preprocess = 1.0   # fill the screen immediately instead of fading in from empty
	add_child(_rain)

	_splash = _make_emitter(dot, SPLASH_COUNT, 0.34, _splash_material())
	add_child(_splash)

	_base_rain_alpha = _rain.modulate.a
	_base_splash_alpha = _splash.modulate.a

	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _process(_delta: float) -> void:
	# Follow the camera so the rain box always covers what the player sees. Null-guarded so a
	# headless/boot frame with no active Camera2D simply skips (the emitters stay where they are).
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_2d()
	if cam == null:
		return
	var center: Vector2 = cam.get_screen_center_position()

	# Visible world extent (account for zoom), padded so streaks spawn/expire off-screen.
	var view_size: Vector2 = vp.get_visible_rect().size
	var zoom: Vector2 = cam.zoom
	var half := Vector2(
		view_size.x * 0.5 / maxf(zoom.x, 0.001),
		view_size.y * 0.5 / maxf(zoom.y, 0.001)
	)
	var world_w: float = half.x * 2.0 + COVER_MARGIN
	var world_h: float = half.y * 2.0 + COVER_MARGIN

	# Rain is born from a wide thin band above the view and falls through it.
	if _rain_mat != null:
		_rain_mat.emission_box_extents = Vector3(world_w * 0.5, 4.0, 0.0)
	_rain.position = center - Vector2(0.0, world_h * SPAWN_ABOVE)

	# Splashes land across the visible ground — a flat band centred on the view.
	_splash.position = center
	var sm := _splash.process_material as ParticleProcessMaterial
	if sm != null:
		sm.emission_box_extents = Vector3(world_w * 0.5, world_h * 0.5, 0.0)


func _on_cue(event_id: String, payload: Dictionary) -> void:
	if event_id == "vfx.rain.intensity":
		set_intensity(float(payload.get("value", 1.0)))


## Public knob: scale rain amount + visibility in [0,1]. 0 stops it cleanly; 1 is full storm.
func set_intensity(v: float) -> void:
	_intensity = clampf(v, 0.0, 1.0)
	if _rain != null:
		_rain.amount_ratio = _intensity
		_rain.emitting = _intensity > 0.001
		_rain.modulate.a = _base_rain_alpha * _intensity
	if _splash != null:
		# Splashes thin out faster than streaks so light drizzle barely speckles the ground.
		_splash.amount_ratio = _intensity * _intensity
		_splash.emitting = _intensity > 0.05
		_splash.modulate.a = _base_splash_alpha * _intensity


func _make_emitter(tex: Texture2D, count: int, life: float, mat: ParticleProcessMaterial) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.texture = tex
	p.amount = count
	p.lifetime = life
	p.one_shot = false
	p.emitting = true
	p.local_coords = false      # particles keep falling in world space as the emitter re-centres
	p.process_material = mat
	return p


# --- particle process materials ---

func _rain_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(640.0, 4.0, 0.0)   # re-sized to the view each frame
	# Fall down with a slight rightward wind lean.
	m.direction = Vector3(sin(WIND_ANGLE), cos(WIND_ANGLE), 0.0)
	m.spread = 2.0
	m.initial_velocity_min = 1300.0
	m.initial_velocity_max = 1650.0
	m.gravity = Vector3(0.0, 220.0, 0.0)
	# Streaks are pre-shaped by the texture; keep scale tight so they stay thin and fast.
	m.scale_min = 0.7
	m.scale_max = 1.15
	m.color = Color(0.66, 0.73, 0.86, 1.0)
	m.color_ramp = _fade_ramp(Color(0.7, 0.77, 0.9, 0.0), Color(0.62, 0.7, 0.84, 0.85), Color(0.6, 0.68, 0.82, 0.0))
	return m


func _splash_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(640.0, 360.0, 0.0)   # re-sized to the view each frame
	# Tiny radial flecks that pop up off the wet ground and settle.
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 70.0
	m.initial_velocity_min = 22.0
	m.initial_velocity_max = 70.0
	m.gravity = Vector3(0.0, 320.0, 0.0)
	m.damping_min = 30.0
	m.damping_max = 90.0
	m.scale_min = 0.12
	m.scale_max = 0.34
	m.color = Color(0.7, 0.77, 0.9, 1.0)
	m.color_ramp = _fade_ramp(Color(0.78, 0.84, 0.95, 0.7), Color(0.7, 0.77, 0.9, 0.4), Color(0.62, 0.7, 0.84, 0.0))
	return m


# --- texture helpers (per-pixel soft alpha; GradientTexture2D leaves opaque square corners) ---

## A soft vertical streak: bright thin core down the centre, feathered to transparent at the edges
## and tapered at the ends — reads as a fast rain line, not a rectangle.
func _streak_texture(w: int, h: int) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := float(w - 1) * 0.5
	var rx := float(w) * 0.5
	var hf := float(h)
	for y in range(h):
		var v := float(y) / maxf(hf - 1.0, 1.0)
		# Taper both ends so the streak fades in and out along its length.
		var ends := sin(v * PI)
		for x in range(w):
			var dx := absf(float(x) - cx) / rx
			var across := clampf(1.0 - dx, 0.0, 1.0)
			across = across * across   # sharp bright core, feathered sides
			var a := across * ends
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


## A soft round dot with a genuinely transparent edge (per-pixel alpha falloff) — for splash flecks.
func _dot_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	var r := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - c, float(y) - c).length() / r
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _fade_ramp(c0: Color, c1: Color, c2: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, c0)
	g.add_point(0.5, c1)
	g.set_color(1, c2)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
