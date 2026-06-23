## NocturneGrade.gd — drives the merged glowup nocturne_grade screen shader from live Sim state.
##
## One unified semantic colour grade for the whole frame (instead of competing flash overlays):
## low Humanity cools + desaturates, Heat red-pulses the edges, frenzy adds contrast, feeding frames
## the centre, dawn warms highlights. Sits above the world, below the HUD (layer 100).
extends CanvasLayer
class_name NocturneGrade

const SHADER_PATH := "res://glowup_2026/shaders/nocturne_grade.gdshader"

var _mat: ShaderMaterial = null
var _frenzy: float = 0.0
var _feeding: float = 0.0
var _heat: float = 0.0
var _humanity: float = 0.0


func _ready() -> void:
	layer = 2
	if not ResourceLoader.exists(SHADER_PATH):
		return
	var sh := load(SHADER_PATH) as Shader
	if sh == null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _mat
	rect.color = Color(1, 1, 1, 1)
	add_child(rect)


func _process(delta: float) -> void:
	if _mat == null or Sim == null:
		return
	var k: float = clampf(delta * 6.0, 0.0, 1.0)
	var heat_t: float = clampf(Sim.heat / 6.0, 0.0, 1.0)
	_heat = lerpf(_heat, heat_t, k)

	var hum_t: float = 0.0
	var frenzy_t: float = 0.0
	var feed_t: float = 0.0
	if Sim.player != null and Sim.player.behaviour != null:
		var pb = Sim.player.behaviour
		hum_t = clampf(1.0 - float(pb.get("humanity")) / 10.0, 0.0, 1.0)
		frenzy_t = 1.0 if bool(pb.get("frenzied")) else 0.0
		feed_t = 1.0 if int(pb.get("feeding_target_id")) != 0 else 0.0
	_humanity = lerpf(_humanity, hum_t, k)
	_frenzy = lerpf(_frenzy, frenzy_t, k)
	_feeding = lerpf(_feeding, feed_t, k)

	_mat.set_shader_parameter("heat", _heat)
	_mat.set_shader_parameter("humanity_loss", _humanity * 0.7)
	_mat.set_shader_parameter("frenzy", _frenzy)
	_mat.set_shader_parameter("feeding", _feeding)
	_mat.set_shader_parameter("dawn_phase", _dawn_phase())
	_mat.set_shader_parameter("sun_exposure", 0.0)
	if CueBus != null:
		_mat.set_shader_parameter("reduced_flash", CueBus.reduced_flash)
		_mat.set_shader_parameter("reduced_motion", CueBus.reduced_motion)


func _dawn_phase() -> float:
	# Night runs 21:00 -> ~06:00; warm the frame as the clock closes on dawn (last ~2h).
	if Sim.meta == null:
		return 0.0
	var clock: float = float(Sim.meta.get("clock")) if Sim.meta.get("clock") != null else 21.0
	if clock >= 4.0 and clock < 6.5:
		return clampf((clock - 4.0) / 2.5, 0.0, 1.0)
	return 0.0
