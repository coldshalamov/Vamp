## DeathScreen.gd — the torpor/death overlay. Without this, player death silently froze the world.
##
## Shown by GameRenderer when the player dies; "rise again" reviving the player at their haven.
extends CanvasLayer
class_name DeathScreen

const DISPLAY_FONT := "res://art/fonts/Cinzel.ttf"
const MONO_FONT := "res://art/fonts/ShareTechMono.ttf"

var _title: Label
var _why: Label
var _hint: Label
var _stats: Label
var _prompt: Label
var _blink: float = 0.0

# Cached cause-of-death, set from the last player.death cue (and player.torpor for dawn deaths).
# Persisted between the killing blow and show_death() so the recap can say WHY you fell.
var _cause: String = ""
var _killer_id: int = 0
var _explanation: String = ""
var _dawn_death: bool = false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


## Cache the cause of death the moment it happens — show_death() may run a frame later (and the
## dawn path reports a generic damage_type, so player.torpor is the authoritative sunrise signal).
func _on_cue(event_id: String, payload: Dictionary) -> void:
	match event_id:
		"player.death":
			_cause = String(payload.get("cause", ""))
			_killer_id = int(payload.get("killer_id", 0))
			_explanation = String(payload.get("explanation", ""))
			_dawn_death = false   # a fresh death; torpor (if any) re-sets this true right after
		"player.torpor":
			_dawn_death = true
			_cause = "dawn"
			_killer_id = 0
			_explanation = "Caught by the dawn"


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.0, 0.02, 0.78)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	cc.add_child(vb)

	var kicker := Label.new()
	kicker.text = "NIGHTSHIFT DIVISION // CASE CLOSED"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(kicker, MONO_FONT, 15, Color("#8a8f99"))
	vb.add_child(kicker)

	_title = Label.new()
	_title.text = "THE NIGHT CLAIMS YOU"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(_title, DISPLAY_FONT, 56, Color("#c01028"))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	vb.add_child(_title)

	# WHY you died — one clear line built from the cached cause/killer, with a do-better hint below.
	_why = Label.new()
	_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(_why, DISPLAY_FONT, 24, Color("#d6b46a"))
	vb.add_child(_why)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(_hint, MONO_FONT, 15, Color("#9a9488"))
	vb.add_child(_hint)

	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(_stats, MONO_FONT, 16, Color("#b9b3a6"))
	vb.add_child(_stats)

	_prompt = Label.new()
	_prompt.text = "press any key to rise from torpor"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(_prompt, MONO_FONT, 18, Color("#d8d2c4"))
	vb.add_child(_prompt)


func _font(l: Label, path: String, size: int, col: Color) -> void:
	if ResourceLoader.exists(path):
		var f := load(path) as FontFile
		if f != null:
			l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)


func _process(delta: float) -> void:
	if not visible or _prompt == null:
		return
	_blink += delta
	_prompt.modulate.a = 0.5 + 0.5 * sin(_blink * 3.4)


func show_death() -> void:
	visible = true
	_blink = 0.0
	if _why != null:
		_why.text = _build_why()
		_why.visible = _why.text != ""
	if _hint != null:
		_hint.text = _build_hint()
		_hint.visible = _hint.text != ""
	if _stats != null:
		_stats.text = _build_stats()


## The one-line WHY: resolve the killer's type and map the cause to noir copy. Falls back to a
## generic line (and an empty hint) when no player.death/torpor cue was received this run.
func _build_why() -> String:
	var killer := _killer_name()
	var lc := _cause.to_lower()
	if _dawn_death or lc.find("dawn") != -1 or lc.find("sun") != -1:
		return "Caught by the dawn — the sun found you in the open."
	if lc.find("fire") != -1 or lc.find("burn") != -1:
		return "Burned alive."
	if killer != "":
		return "Slain by %s." % killer
	if _cause == "":
		return "The night outlasted you."
	return "Slain by the night."


## A short, actionable "do this next time" line, keyed to how you fell. Empty when cause is unknown.
func _build_hint() -> String:
	var lc := _cause.to_lower()
	if _dawn_death or lc.find("dawn") != -1 or lc.find("sun") != -1:
		return "Reach your haven before sunrise."
	if lc.find("fire") != -1 or lc.find("burn") != -1:
		return "Mind the flames — spilled blood catches and spreads."
	if _killer_id != 0:
		return "Feed before you fight — and don't get cornered."
	if _cause == "":
		return ""
	return "Feed before you fight."


## Resolve the killer entity to a capitalized type name, or "" if there is no live killer to name.
func _killer_name() -> String:
	if _killer_id == 0 or Sim == null:
		return ""
	var e: SimEntity = Sim.get_entity(_killer_id)
	if e == null:
		return ""
	var t := e.type_id
	if t == "":
		return ""
	return t.substr(0, 1).to_upper() + t.substr(1)


## Run recap: level, feeds, kills, Humanity, and an epitaph keyed to how the soul fared.
func _build_stats() -> String:
	if Sim == null or Sim.player == null:
		return ""
	var b: Object = Sim.player.behaviour
	if b == null:
		return ""
	var level := int(Sim.meta.get("level")) if Sim.meta != null else 1
	var kills := int(b.get("kills"))
	var feeds := int(b.get("fed_count"))
	var inn := int(b.get("innocent_kills"))
	var humanity := float(b.get("humanity"))
	var epitaph := "The Beast outlived the man."
	if humanity <= 1.0:
		epitaph = "There was only the Beast."
	elif inn == 0:
		epitaph = "A predator, never a butcher."
	return "Level %d    ·    %d fed    ·    %d slain (%d innocent)    ·    Humanity %.0f\n%s" % [level, feeds, kills, inn, humanity, epitaph]


func hide_death() -> void:
	visible = false
	# Clear the cached cause so a later, unrelated show_death() can't inherit a stale epitaph.
	_cause = ""
	_killer_id = 0
	_explanation = ""
	_dawn_death = false
