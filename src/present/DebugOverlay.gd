## DebugOverlay.gd — F3 sim-truth debug overlay (MASTER_PLAN Wave 7 #29).
##
## A toggleable CanvasLayer that reads the Sim READ-ONLY and draws the authoritative
## state the renderer is mirroring: tick, heat (+ stars), player vitals (hunger / blood /
## humanity / exposure), entity count, the global last-seen-pos, and each live NPC's
## ai_state / perception_state. It also draws LOS lines from the player to hostiles and
## last-known-position markers — all straight from published sim fields, never by calling
## sim logic. Zero gameplay impact, pure read.
##
## It is a CanvasLayer (not a Node2D child of GameRenderer) so the HUD text stays in
## screen space and does not pan/zoom with the gameplay camera. World-anchored gizmos use
## the live canvas transform so they line up with the camera's position AND zoom.
##
## Toggled with F3. Starts hidden and does nothing until shown.
extends CanvasLayer
class_name DebugOverlay

const FONT_PATH := "res://art/fonts/ShareTechMono.ttf"
const FONT_SIZE := 13
const LINE_HEIGHT := 16
const PANEL_MARGIN := Vector2(10, 10)
const PANEL_PAD := 8.0

const COL_TEXT := Color("#bfe8c0")
const COL_DIM := Color("#7fae86")
const COL_WARN := Color("#f0c040")
const COL_HOT := Color("#ff5050")
const COL_PANEL := Color(0.02, 0.03, 0.02, 0.72)
const COL_LOS := Color(1.0, 0.25, 0.25, 0.55)
const COL_LKP := Color(1.0, 0.7, 0.2, 0.9)
const COL_SEEN := Color(0.5, 0.8, 1.0, 0.9)
const COL_NPC_LABEL := Color("#cfe0ff")

var _draw_layer: Control = null
var _font: Font = null


func _ready() -> void:
	# Draw above the gameplay view and VisualFX; keep responsive even while paused.
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_font = _load_font()

	_draw_layer = Control.new()
	_draw_layer.name = "DebugDraw"
	_draw_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.draw.connect(_on_draw)
	add_child(_draw_layer)


func _input(event: InputEvent) -> void:
	# No InputMap action exists for this; read the raw key. Don't consume it — there is
	# no conflict with GameRenderer's _input (that only handles Rebind-captured actions).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible
		if visible and _draw_layer != null:
			_draw_layer.queue_redraw()


func _process(_delta: float) -> void:
	# Pure idle redraw while shown; completely inert when hidden.
	if not visible or _draw_layer == null:
		return
	_draw_layer.queue_redraw()


func _on_draw() -> void:
	if not visible or _draw_layer == null:
		return
	if Sim == null:
		return
	_draw_world_gizmos()
	_draw_npc_labels()
	_draw_stats_panel()


# --- world-anchored gizmos (use the live canvas transform: position + zoom + offset) ---

func _draw_world_gizmos() -> void:
	var xform := get_viewport().get_canvas_transform()
	var player: SimEntity = Sim.player

	# Global heat-search marker (Sim.last_seen_pos).
	var seen_screen: Vector2 = xform * Sim.last_seen_pos
	_draw_layer.draw_circle(seen_screen, 6.0, COL_SEEN)
	_draw_layer.draw_arc(seen_screen, 11.0, 0.0, TAU, 18, COL_SEEN, 1.5)

	if player == null:
		return
	var player_screen: Vector2 = xform * player.pos

	for e in Sim.entities:
		if e == null or e == player or e.dead or e.kind != "npc":
			continue
		if not e.hostile_to_player:
			continue
		var npc_screen: Vector2 = xform * e.pos
		# LOS line player -> hostile NPC.
		_draw_layer.draw_line(player_screen, npc_screen, COL_LOS, 1.5)
		# Last-known-position marker (where the AI last placed the player).
		var lkp_screen: Vector2 = xform * e.last_seen_pos
		_draw_layer.draw_line(lkp_screen + Vector2(-5, -5), lkp_screen + Vector2(5, 5), COL_LKP, 1.5)
		_draw_layer.draw_line(lkp_screen + Vector2(-5, 5), lkp_screen + Vector2(5, -5), COL_LKP, 1.5)


func _draw_npc_labels() -> void:
	if _font == null:
		return
	var xform := get_viewport().get_canvas_transform()
	for e in Sim.entities:
		if e == null or e.dead or e.kind != "npc":
			continue
		var screen: Vector2 = xform * e.pos
		var label := "%s/%s" % [e.ai_state, e.perception_state]
		var col := COL_HOT if e.hostile_to_player else COL_NPC_LABEL
		_draw_layer.draw_string(_font, screen + Vector2(-18, -22), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 1, col)


# --- screen-space stats panel (pure, no camera math) ---

func _draw_stats_panel() -> void:
	if _font == null:
		return
	var lines := _build_stat_lines()
	var width := 0.0
	for line in lines:
		width = maxf(width, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var panel_size := Vector2(width + PANEL_PAD * 2.0, lines.size() * LINE_HEIGHT + PANEL_PAD * 2.0)
	_draw_layer.draw_rect(Rect2(PANEL_MARGIN, panel_size), COL_PANEL)

	var y := PANEL_MARGIN.y + PANEL_PAD + FONT_SIZE
	for line in lines:
		var col := COL_TEXT
		if line.begins_with("HEAT") and Sim.heat_stars() >= 3:
			col = COL_HOT
		elif line.begins_with("HEAT") and Sim.heat_stars() >= 1:
			col = COL_WARN
		elif line.begins_with("--"):
			col = COL_DIM
		_draw_layer.draw_string(_font, Vector2(PANEL_MARGIN.x + PANEL_PAD, y), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, col)
		y += LINE_HEIGHT


func _build_stat_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("-- SIM DEBUG (F3) --")
	lines.append("tick   %d" % int(Sim.tick))
	lines.append("HEAT   %.2f  (%d stars)" % [Sim.heat, Sim.heat_stars()])
	lines.append("entities %d" % Sim.entities.size())
	lines.append("lastseen %.0f,%.0f" % [Sim.last_seen_pos.x, Sim.last_seen_pos.y])

	var player: SimEntity = Sim.player
	if player != null:
		lines.append("-- PLAYER --")
		lines.append("pos    %.0f,%.0f" % [player.pos.x, player.pos.y])
		lines.append("hp     %.0f / %.0f" % [player.hp, player.max_hp])
		lines.append("expose %.2f" % player.exposure)
		var b = player.behaviour
		if b != null:
			lines.append("blood  %.1f / %.1f" % [_f(b, "blood"), _f(b, "max_blood", 100.0)])
			lines.append("hunger %.2f" % _f(b, "hunger"))
			lines.append("human  %.2f" % _f(b, "humanity"))
			if bool(b.get("frenzied")):
				lines.append("** FRENZIED **")
	# Hidden-game city model: how the world reads the player's style (glowup PlayerStyleProfile).
	var ds := get_node_or_null("/root/DirectorService")
	if ds != null and ds.has_method("dominant_style"):
		var dom: Dictionary = ds.dominant_style()
		lines.append("-- CITY MODEL --")
		lines.append("style  %s %.0f%%" % [String(dom.get("axis", "—")).to_upper(), float(dom.get("share", 0.0)) * 100.0])
		lines.append("hybrid %.2f" % float(dom.get("entropy", 0.0)))
		if ds.has_method("rumor_belief"):
			var belief: Dictionary = ds.rumor_belief()
			lines.append("rumors %d  aware %.2f fear %.2f" % [ds.rumor_claims(), float(belief.get("awareness", 0.0)), float(belief.get("fear", 0.0))])
		if ds.has_method("current_opportunity"):
			var op: Dictionary = ds.current_opportunity()
			if not op.is_empty():
				lines.append("next op: %s" % String(op.get("display_name", op.get("id", "—"))))
	return lines


# --- helpers ---

func _f(obj, key: String, fallback: float = 0.0) -> float:
	# Safe read of a behaviour field (statically typed RefCounted → use get()).
	if obj == null:
		return fallback
	var v = obj.get(key)
	return float(v) if v != null else fallback


func _load_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		var f := load(FONT_PATH) as Font
		if f != null:
			return f
	# Fall back to the default theme font so draw_string never gets a null Font.
	var theme_font := ThemeDB.fallback_font
	return theme_font
