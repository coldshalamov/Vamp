## PostProcess.gd — the final filmic master pass for the gameplay view.
##
## A high CanvasLayer holding one full-rect ColorRect that runs art/shaders/post_process.gdshader:
## ACES filmic tonemap, lift/gamma/gain + teal-shadow / amber-highlight split-tone grade, subtle
## TIME-based film grain, an optional FXAA edge pass, and a near-zero framing vignette. It is the LAST
## screen-space grade before the UI — it composites the lit world + NocturneGrade + ScreenFX into one
## cinematic frame, but sits UNDER every UI layer so it never tonemaps or grains text.
##
## Layer map (verified against the tree, see GameRenderer.gd / NocturneGrade.gd / ScreenFX.gd):
##   AtmosphereLayer = 1
##   NocturneGrade   = 2
##   ScreenFX        = 3
##   PostProcess     = 4   <-- THIS: above the world grades, below all UI
##   DeathScreen     = 60
##   HUD (UIManager) = 100
##   DebugOverlay    = 128
##
## The shader carries TIME-driven grain, so there is NO _process cost: _ready binds the material once
## and the GPU animates it. Like every optional full-screen FX in GameRenderer, this is gated behind
## the safe-visual profile by the caller (it is a third always-on screen read; on the GL Compat iGPU
## that is real cost). FXAA defaults OFF (aa_strength = 0.0) so the idle path is a single screen tap.
##
## ------------------------------------------------------------------------------------------------
## INTEGRATION — GameRenderer.gd
## ------------------------------------------------------------------------------------------------
## 1. Add the preload constant near the other PATH consts (around line 34, with NOCTURNE_GRADE_PATH):
##
##        const POST_PROCESS_PATH := "res://src/present/PostProcess.gd"
##
## 2. Add a field near `_nocturne` (around line 55):
##
##        var _post_process: CanvasLayer = null
##
## 3. Instantiate it ONCE inside the existing `if not safe_visuals:` flow, AFTER the ScreenFX block
##    (~line 203) so it composites on top of NocturneGrade(2) and ScreenFX(3) but below the HUD. Use
##    the same `_new_optional_node` pattern the file already uses:
##
##        if not safe_visuals:
##            # Final filmic master pass (ACES tonemap + grade + grain + vignette) on layer 4, above the
##            # world/mood/damage grades and below all UI. Self-assigns its layer in _ready.
##            _post_process = _new_optional_node(POST_PROCESS_PATH)
##            if _post_process != null:
##                _post_process.name = "PostProcess"
##                add_child(_post_process)
##
##    (Equivalently, `PostProcess.attach(self)` does the load + add in one call — see below — but the
##    `_new_optional_node` form matches every other optional FX in this file.)
##
## Do NOT raise its layer to 100: that is the HUD. Layer 4 keeps it the topmost *world* pass while
## leaving the interface, death overlay (60), and debug overlay (128) ungraded.
extends CanvasLayer
class_name PostProcess

const SHADER_PATH := "res://art/shaders/post_process.gdshader"

# Above ScreenFX(3) / NocturneGrade(2), below DeathScreen(60), HUD(100), DebugOverlay(128).
const POST_PROCESS_LAYER := 4

var _mat: ShaderMaterial = null
var _rect: ColorRect = null


func _ready() -> void:
	layer = POST_PROCESS_LAYER
	if not ResourceLoader.exists(SHADER_PATH):
		push_warning("PostProcess: shader missing at %s — skipping filmic pass." % SHADER_PATH)
		return
	var sh := load(SHADER_PATH) as Shader
	if sh == null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.color = Color(1, 1, 1, 1)
	add_child(_rect)


## One-call instantiate + attach helper. Loads the script, names the node, parents it to `parent`,
## and returns the instance (or null if the script is unavailable). The caller is responsible for the
## safe-visual gate — only call this when full visuals are enabled. Example, from GameRenderer._ready:
##
##     if not safe_visuals:
##         _post_process = PostProcess.attach(self)
##
static func attach(parent: Node) -> CanvasLayer:
	if parent == null:
		return null
	var script := load("res://src/present/PostProcess.gd")
	if script == null:
		push_error("PostProcess.attach: could not load PostProcess.gd")
		return null
	var node: CanvasLayer = script.new()
	node.name = "PostProcess"
	parent.add_child(node)
	return node


## Optional runtime knob hook (e.g. an options menu). No-op until the rect/material exist.
func set_param(name: StringName, value: Variant) -> void:
	if _mat != null:
		_mat.set_shader_parameter(name, value)
