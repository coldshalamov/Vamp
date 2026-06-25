## ProgressionHUD.gd — XP bar, level-up moment, loot pickup, and the dawn indicator.
##
## A self-contained full-rect overlay added under UIManager (a CanvasLayer that persists across
## screens). It reads Sim.meta read-only for the XP fraction and subscribes to CueBus.cue_emitted
## for the punctuating beats. It draws its own thin bottom-edge XP bar, a gold level-up burst with a
## hint arrow toward the skill menu, and a subtle rising sun as dawn nears. All transient toasts/
## banners route through UIManager (NotificationPanel) so styling stays consistent.
##
## OWNERSHIP (single-source-per-cue): this node owns the "player.xp" popup (it listens to player.xp
## ONLY, never player.xp_gain — that would double-count) and the level-up BANNER + "+Skill Point"
## message. VisualFX keeps only its screen flash for level-up. HEAT STARS are owned by the HUD agent;
## this node does NOT render heat. The dawn TOAST text is owned by the HUD agent (HUD._on_cue handles
## "dawn.warning"); this node adds only the SUBTLE drawn sun so the two never double up.
##
## No-ops entirely when Sim == null or Sim.player == null so it never paints over the title screen.
extends Control
class_name ProgressionHUD

## Pixel height of the persistent XP bar pinned to the very bottom edge.
const BAR_HEIGHT := 6.0
## How fast the displayed fill chases the real fraction (per second, as a lerp weight).
const FILL_LERP := 6.0
## Seconds the bar glows after an XP gain or level-up.
const GLOW_DWELL := 0.9
## Seconds the level-up gold burst + skill-menu hint arrow linger.
const LEVELUP_DWELL := 2.6
## Seconds the rising-sun dawn indicator lingers once dawn.warning fires.
const DAWN_DWELL := 14.0

# Smoothed display state for the XP bar.
var _display_frac: float = 0.0
var _target_frac: float = 0.0
var _last_real_frac: float = 0.0
var _glow_t: float = 0.0
# True while a level rollover is mid-flourish (bar sweeping up to full before it resets to the new
# low fraction). A persistent flag is needed because the "real fraction dropped" condition is true
# for only a single frame — inferring rollover from the fraction alone collapses after one frame.
var _rolling_over: bool = false

# Level-up burst + skill-menu hint.
var _levelup_t: float = 0.0
var _levelup_level: int = 0

# Dawn indicator.
var _dawn_t: float = 0.0
var _dawn_clock: float = 0.0

# Floating "+N XP" popup pool (screen-space labels above the bar). Updated each frame.
var _xp_pops: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)
	# Initialise the bar to the current real fraction so it doesn't sweep up from 0 on first frame.
	_target_frac = _real_xp_fraction()
	_display_frac = _target_frac
	_last_real_frac = _target_frac


func _process(delta: float) -> void:
	# HARD no-op when there is no live game: never paint over the main menu / title screen.
	if Sim == null or Sim.player == null:
		if _display_frac != 0.0 or not _xp_pops.is_empty() or _levelup_t > 0.0 or _dawn_t > 0.0:
			_reset_transient()
			queue_redraw()
		return

	var real := _real_xp_fraction()
	# Level rollover: when the real fraction DROPS (xp spent into a new level), latch a flourish —
	# sweep the bar UP to full first, then snap to the new low value, so the eye reads "filled up,
	# levelled, reset" rather than the bar jerking backward. The latch (not a per-frame fraction
	# compare) is what keeps the sweep alive across the many frames it takes to reach full.
	if real < _last_real_frac - 0.02:
		_rolling_over = true
	_last_real_frac = real

	if _rolling_over:
		_target_frac = 1.0
		if _display_frac >= 0.985:
			# Reached full — drop to the real low fraction and end the flourish.
			_display_frac = 0.0
			_rolling_over = false
			_target_frac = real
	else:
		_target_frac = real

	# Smoothly chase the target.
	_display_frac = lerpf(_display_frac, _target_frac, clampf(delta * FILL_LERP, 0.0, 1.0))

	if _glow_t > 0.0:
		_glow_t = maxf(0.0, _glow_t - delta)
	if _levelup_t > 0.0:
		_levelup_t = maxf(0.0, _levelup_t - delta)
	if _dawn_t > 0.0:
		_dawn_t = maxf(0.0, _dawn_t - delta)

	_update_xp_pops(delta)
	queue_redraw()


func _reset_transient() -> void:
	_display_frac = 0.0
	_target_frac = 0.0
	_last_real_frac = 0.0
	_rolling_over = false
	_glow_t = 0.0
	_levelup_t = 0.0
	_dawn_t = 0.0
	_xp_pops.clear()


## Current XP progress in [0,1], computed from Sim.meta. Guards every field so a half-built meta
## (or a level at the cap where xp_to_next could be small) never divides by zero or errors.
func _real_xp_fraction() -> float:
	if Sim == null or Sim.meta == null:
		return 0.0
	var meta = Sim.meta
	var lv: int = int(meta.level)
	var to_next: float = 1.0
	if meta.has_method("xp_to_next"):
		to_next = float(meta.xp_to_next(lv))
	if to_next <= 0.0:
		# At the level cap xp folds into elder_vitae; show the bar full rather than dividing by zero.
		return 1.0
	return clampf(float(meta.xp) / to_next, 0.0, 1.0)


func _update_xp_pops(delta: float) -> void:
	for i in range(_xp_pops.size() - 1, -1, -1):
		var pop: Dictionary = _xp_pops[i]
		pop.t += delta
		if pop.t >= pop.dur:
			_xp_pops.remove_at(i)


# ---------------------------------------------------------------- cue handling

func _on_cue(event_id: String, payload: Dictionary) -> void:
	# HARD RULE #4: guard in the cue handler too, not just _process. The banner/toast handlers
	# (level_up / equipped / auto_sold) have side effects via UIManager that bypass the _process
	# gate — without this, a cue draining after death (player nulled) or on the title screen would
	# pop a banner over the menu. Fire nothing until a live game exists.
	if Sim == null or Sim.player == null:
		return
	match event_id:
		"player.xp":
			_on_player_xp(payload)
		"player.level_up":
			_on_level_up(payload)
		"inventory.equipped":
			_on_equipped(payload)
		"inventory.auto_sold":
			_on_auto_sold(payload)
		"dawn.warning":
			_on_dawn_warning(payload)


## 5b — "+N XP" popup near the bar + a brief bar glow/surge. Listens to player.xp ONLY.
func _on_player_xp(payload: Dictionary) -> void:
	var amt: int = int(payload.get("amount", 0))
	if amt <= 0:
		return
	_glow_t = GLOW_DWELL
	var reduced := _reduced_motion()
	# Stack popups slightly so a flurry of kills doesn't overprint into one smudge.
	var rise: float = 0.0 if reduced else 26.0
	_xp_pops.append({
		"text": "+%d XP" % amt,
		"t": 0.0,
		"dur": 1.1,
		"rise": rise,
		"x_jit": float((_xp_pops.size() % 3) - 1) * 34.0,
	})
	if _xp_pops.size() > 6:
		_xp_pops.pop_front()


## 5a — celebratory level-up. Banner + "+Skill Point" message via UIManager, plus a gold burst and a
## hint arrow toward where the skill menu opens (we own these; VisualFX keeps only the screen flash).
func _on_level_up(payload: Dictionary) -> void:
	var lvl: int = int(payload.get("level", 0))
	_levelup_level = lvl
	_levelup_t = LEVELUP_DWELL
	_glow_t = maxf(_glow_t, GLOW_DWELL)
	if UIManager != null:
		var gold := _accent("gold", Color(0.95, 0.78, 0.28))
		UIManager.show_banner("LEVEL %d" % lvl, tr("BANNER_LEVELUP_BODY") if _has_tr("BANNER_LEVELUP_BODY") else "+1 Skill Point — open the skill menu", gold)


## 5c — loot pickup surrogate. There is no player.loot event; inventory.equipped is the closest beat.
## Rarity-neutral styling (we have no rarity data in this payload — see GAP note).
func _on_equipped(payload: Dictionary) -> void:
	if UIManager == null:
		return
	var nm := String(payload.get("name", ""))
	if nm.strip_edges() == "":
		nm = "item"
	_glow_t = maxf(_glow_t, GLOW_DWELL * 0.7)
	UIManager.show_notification("Equipped: %s" % nm, _accent("gold", Color(0.92, 0.80, 0.42)))


## 5c — auto-sell overflow toast. money is the NEW running total per the contract.
func _on_auto_sold(payload: Dictionary) -> void:
	if UIManager == null:
		return
	var item := String(payload.get("item", "item"))
	var money: float = float(payload.get("money", 0.0))
	UIManager.show_notification("Sold %s  +$%d" % [item, int(round(money))], _accent("dim", Color(0.70, 0.68, 0.62)))


## 5e — dawn indicator. SUBTLE only: we arm the drawn rising sun. The HUD agent owns the toast text
## for dawn.warning, so we deliberately do NOT push a notification here (single-source-per-cue).
func _on_dawn_warning(payload: Dictionary) -> void:
	_dawn_t = DAWN_DWELL
	_dawn_clock = float(payload.get("clock", 0.0))


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	# Mirror the _process gate: nothing renders without a live game.
	if Sim == null or Sim.player == null:
		return
	var vp := size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	_draw_xp_bar(vp)
	_draw_xp_pops(vp)
	if _dawn_t > 0.0:
		_draw_dawn(vp)
	if _levelup_t > 0.0:
		_draw_levelup(vp)


func _draw_xp_bar(vp: Vector2) -> void:
	var y := vp.y - BAR_HEIGHT
	# Track.
	draw_rect(Rect2(0.0, y, vp.x, BAR_HEIGHT), Color(0.05, 0.04, 0.06, 0.78))
	# Fill — warm gold, brightened briefly by the glow envelope after a gain.
	var glow := 0.0 if _reduced_motion() else (_glow_t / GLOW_DWELL)
	var fill_col := Color(0.86, 0.66, 0.22, 0.95).lerp(Color(1.0, 0.92, 0.55, 1.0), clampf(glow, 0.0, 1.0))
	var w := clampf(_display_frac, 0.0, 1.0) * vp.x
	if w > 0.0:
		draw_rect(Rect2(0.0, y, w, BAR_HEIGHT), fill_col)
		# A 1px hot leading edge sells the "filling" motion.
		draw_rect(Rect2(maxf(0.0, w - 2.0), y, 2.0, BAR_HEIGHT), Color(1.0, 0.95, 0.7, 0.9 * (0.4 + 0.6 * glow)))
	# Thin top hairline so the bar reads as a deliberate element, not screen tearing.
	draw_rect(Rect2(0.0, y - 1.0, vp.x, 1.0), Color(0.0, 0.0, 0.0, 0.5))


func _draw_xp_pops(vp: Vector2) -> void:
	if _xp_pops.is_empty():
		return
	var font := get_theme_default_font()
	if font == null:
		return
	var fsize := _font_size(15)
	var base_x := vp.x * 0.5
	var base_y := vp.y - BAR_HEIGHT - 10.0
	for pop in _xp_pops:
		var prog: float = clampf(float(pop.t) / float(pop.dur), 0.0, 1.0)
		var alpha := 1.0 - prog * prog
		var px := base_x + float(pop.get("x_jit", 0.0))
		var py := base_y - prog * float(pop.get("rise", 0.0))
		var txt := String(pop.text)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		_draw_text_outlined(font, Vector2(px - tw * 0.5, py), txt, fsize, Color(1.0, 0.9, 0.5, alpha))


## A small warm sun rising at the right edge as dawn nears — atmospheric, not a screaming timer.
func _draw_dawn(vp: Vector2) -> void:
	var life: float = clampf(_dawn_t / DAWN_DWELL, 0.0, 1.0)   # 1 at trigger -> 0 at expiry
	var age: float = 1.0 - life                                # 0 at trigger -> 1 at expiry
	# Envelope: fade IN over the first ~15% of the dwell, hold, fade OUT over the last ~30%.
	# Reduced motion keeps it static at full presence (no fade animation).
	var presence: float = 1.0
	if not _reduced_motion():
		var fade_in := clampf(age / 0.15, 0.0, 1.0)
		var fade_out := clampf(life / 0.30, 0.0, 1.0)
		presence = minf(fade_in, fade_out)
	if presence <= 0.0:
		return
	var cx := vp.x - 64.0
	# Rises from just below a horizon line as the dwell elapses (full -> a touch higher).
	var horizon := vp.y * 0.30
	var rise := 0.0 if _reduced_motion() else age * 14.0
	var cy := horizon - rise
	var r := 16.0
	# Warm halo, then the disc.
	draw_circle(Vector2(cx, cy), r * 2.1, Color(0.95, 0.55, 0.22, 0.10 * presence))
	draw_circle(Vector2(cx, cy), r * 1.45, Color(0.98, 0.62, 0.26, 0.14 * presence))
	draw_circle(Vector2(cx, cy), r, Color(1.0, 0.74, 0.34, 0.55 * presence))
	draw_circle(Vector2(cx, cy), r * 0.7, Color(1.0, 0.86, 0.55, 0.7 * presence))
	# A faint warm readout of the hour, understated.
	var font := get_theme_default_font()
	if font != null:
		var txt := "DAWN %02d:%02d" % [int(_dawn_clock), int((_dawn_clock - floorf(_dawn_clock)) * 60.0)]
		var fsize := _font_size(11)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		_draw_text_outlined(font, Vector2(cx - tw * 0.5, cy + r * 2.6), txt, fsize, Color(0.98, 0.78, 0.5, 0.7 * presence))


## Gold burst + a hint arrow pointing toward the skill menu (bottom-center hotbar / "open skills").
func _draw_levelup(vp: Vector2) -> void:
	var prog := 1.0 - (_levelup_t / LEVELUP_DWELL)     # 0 -> 1
	var center := Vector2(vp.x * 0.5, vp.y * 0.42)
	if not _reduced_motion():
		# Expanding ring burst — bright early, fades as it grows.
		var burst := clampf(prog * 2.2, 0.0, 1.0)
		var ring_r := 30.0 + burst * 120.0
		var ring_a := (1.0 - burst) * 0.6
		if ring_a > 0.01:
			draw_arc(center, ring_r, 0.0, TAU, 48, Color(1.0, 0.86, 0.4, ring_a), 3.0, true)
		# A handful of radiating gold spokes.
		var spokes := 10
		for i in range(spokes):
			var ang := TAU * float(i) / float(spokes)
			var inner := 24.0 + burst * 40.0
			var outer := inner + 26.0 * (1.0 - burst)
			var a := (1.0 - burst) * 0.7
			if a > 0.01:
				draw_line(center + Vector2(cos(ang), sin(ang)) * inner, center + Vector2(cos(ang), sin(ang)) * outer, Color(1.0, 0.9, 0.5, a), 2.0)
	# Hint arrow: a small chevron near the bottom edge pointing down toward where skills open.
	# Lingers (gentle pulse) for the whole dwell so the player connects "+1 point" to an action.
	var arrow_a := clampf(_levelup_t / LEVELUP_DWELL, 0.0, 1.0)
	var pulse := 1.0 if _reduced_motion() else (0.6 + 0.4 * sin(prog * TAU * 3.0))
	var ax := vp.x * 0.5
	var ay := vp.y - 96.0       # just above the hotbar (hotbar sits at offset_top -78)
	var col := Color(1.0, 0.88, 0.42, 0.85 * arrow_a * pulse)
	var pts := PackedVector2Array([
		Vector2(ax - 9.0, ay - 8.0),
		Vector2(ax, ay + 4.0),
		Vector2(ax + 9.0, ay - 8.0),
	])
	draw_polyline(pts, col, 3.0, true)


func _draw_text_outlined(font: Font, pos: Vector2, text: String, fsize: int, col: Color) -> void:
	# Cheap legibility: a 1px black halo via four offset draws, then the colored glyphs.
	var halo := Color(0.0, 0.0, 0.0, col.a * 0.85)
	for off in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		font.draw_string(get_canvas_item(), pos + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, halo)
	font.draw_string(get_canvas_item(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


# ---------------------------------------------------------------- helpers

func _reduced_motion() -> bool:
	if UIManager != null:
		return UIManager.is_reduced_motion()
	if CueBus != null:
		return CueBus.reduced_motion
	return false


func _accent(key: String, fallback: Color) -> Color:
	if UIManager != null:
		return UIManager.theme_get_color(key, "UITheme", fallback)
	return fallback


func _font_size(fallback: int) -> int:
	if UIManager != null:
		return UIManager.theme_font_size("font_size", "Label", fallback)
	return fallback


func _has_tr(key: String) -> bool:
	# tr() returns the key verbatim when no translation is registered; detect that so we can fall
	# back to a hard-coded English string instead of showing a raw key.
	return tr(key) != key
