## AtmosphereDirector.gd — screen-space weather: drifting fog + falling rain, for the rain-slicked
## night the static map was missing. Presentation only (no Sim, no Sim.rng); a local clock drives it.
## Mounted by GameRenderer inside a CanvasLayer below the mood grade + HUD. Kept deliberately subtle
## so it reads as atmosphere, not an obscuring curtain (tune RAIN_ALPHA / FOG_ALPHA from playtest).
extends Control
class_name AtmosphereDirector

const RAIN := 110
const RAIN_ALPHA := 0.18
const FOG_ALPHA := 0.022

var _t: float = 0.0


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	# low drifting fog banks
	for i in range(3):
		var fx := fmod(_t * (8.0 + float(i) * 5.0) + float(i) * 420.0, w + 420.0) - 210.0
		var fy := h * (0.22 + 0.24 * float(i))
		draw_circle(Vector2(fx, fy), 180.0 + float(i) * 44.0, Color(0.30, 0.33, 0.42, FOG_ALPHA))
	# Rain is now GPUParticles2D-based RainFX (world-space, camera-following); the old draw_line
	# streaks are disabled so the two don't stack into a curtain — only the fog banks remain here.
