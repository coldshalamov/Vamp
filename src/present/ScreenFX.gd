## ScreenFX.gd — event-driven screen-space damage feedback (red vignette + crit chromatic aberration).
##
## Two effects, IDLE/cheap the vast majority of the time, composited ABOVE NocturneGrade (layer 3
## over its layer 2) so the damage grade reads on top of the mood grade:
##
##   (1) DAMAGE VIGNETTE — on "damage.player", pulse a RED edge vignette that fades over ~0.5s, its
##       intensity scaled by payload.amount. Pure uniform-driven radial math in the shader: it rides
##       on the single screen tap the shader already does, no extra SCREEN_TEXTURE read.
##   (2) CRIT CHROMATIC ABERRATION — on "hit.connect" when payload.crit, a brief RGB-split at the
##       edges for ~0.15s, decaying. This is the only path that adds screen taps; when its timer is
##       ~0 the shader collapses to a single pass-through sample (uniform branch, cheap on GL Compat).
##   Plus a constant, subtle framing vignette (a shader uniform default — no per-frame cost).
##
## Presentation-only: subscribes to CueBus read-only, never touches Sim / Sim.rng / game state. These
## are screen-edge effects, so no world positioning is needed (Sim is not read at all). Decay timers
## live in _process; cues only refresh the peak via max() so a fresh hit can't truncate a live fade.
extends CanvasLayer
class_name ScreenFX

const SHADER_PATH := "res://art/shaders/screen_fx.gdshader"

# Decay windows (seconds) — matches the spec: ~0.5s red fade, ~0.15s crit split.
const DAMAGE_FADE := 0.5
const ABERRATION_FADE := 0.15
# Damage amount that maps to a full-strength vignette. We can't read the sim's damage range, so this
# normalises defensively; the clamp guarantees an enormous hit can't white the screen out.
const DAMAGE_REF := 18.0
const DAMAGE_PEAK := 0.9   # hard ceiling on vignette intensity even at/over DAMAGE_REF

var _mat: ShaderMaterial = null
var _rect: ColorRect = null
var _damage: float = 0.0
var _aberration: float = 0.0


func _ready() -> void:
	layer = 3   # above NocturneGrade (layer 2), below the HUD
	if not ResourceLoader.exists(SHADER_PATH):
		return
	var sh := load(SHADER_PATH) as Shader
	if sh == null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	# No always-on framing vignette: the full-screen screen-sampling pass is the cost, so the rect is
	# HIDDEN whenever no effect is live (the common case, incl. the FPS stress showcase) — zero idle
	# cost on the iGPU. NocturneGrade (layer 2) carries the constant mood/edge grade.
	_mat.set_shader_parameter("framing_vignette", 0.0)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.color = Color(1, 1, 1, 1)
	_rect.visible = false
	add_child(_rect)
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _on_cue(event_id: String, payload: Dictionary) -> void:
	match event_id:
		"damage.player":
			var amount: float = float(payload.get("amount", 0.0))
			var intensity: float = clampf(amount / DAMAGE_REF, 0.0, 1.0) * DAMAGE_PEAK
			# Accessibility: reduced_flash tames full-screen flashes (this is exactly that).
			if CueBus != null and CueBus.reduced_flash:
				intensity *= 0.25
			_damage = maxf(_damage, intensity)
		"hit.connect":
			if not bool(payload.get("crit", false)):
				return
			var split: float = 1.0
			# Accessibility: reduced_motion softens the screen warp.
			if CueBus != null and CueBus.reduced_motion:
				split *= 0.25
			_aberration = maxf(_aberration, split)
		_:
			pass


func _process(delta: float) -> void:
	if _mat == null or _rect == null:
		return
	# Linear decay of both timers toward zero over their windows.
	if _damage > 0.0:
		_damage = maxf(0.0, _damage - delta / DAMAGE_FADE)
	if _aberration > 0.0:
		_aberration = maxf(0.0, _aberration - delta / ABERRATION_FADE)
	var active := _damage > 0.0 or _aberration > 0.0
	# Hide the rect when idle so the full-screen screen-sampling pass doesn't run every frame.
	if _rect.visible != active:
		_rect.visible = active
	if active:
		_mat.set_shader_parameter("damage", _damage)
		_mat.set_shader_parameter("aberration", _aberration)
