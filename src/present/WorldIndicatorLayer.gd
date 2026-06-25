## WorldIndicatorLayer.gd — world-space enemy-anchored indicators, drawn above the actors.
##
## A read-only Node2D view over Sim that draws four families of indicator anchored over an
## entity's head (in WORLD coordinates — it lives in the world, so no camera math for placement):
##   1. Enemy HEALTH BARS (with an animated white "chunk" on hit + elite name labels).
##   2. STATUS EFFECT ICONS (a stacked row of instantly-readable glyphs above the bar).
##   3. ALERT INDICATORS (Metal-Gear "?"/"!!" pops on enemy.alert).
##   4. TELEGRAPH visualizations (aim line / ground ring / wind-up glow on enemy.telegraph).
##
## Mirrors WorldFX's split: ALL timers/lerps/animation state advance in _process(delta), and
## _draw() is a pure read of that state. Transient per-entity state is kept in Dictionaries keyed
## by entity_id; state is dropped when Sim.get_entity(id) is null or the entity is dead. The whole
## layer no-ops when Sim == null or Sim.player == null (so it never paints over the title screen).
##
## Everything is sized in WORLD units against the gameplay camera zoom (CameraDirector.BASE_ZOOM
## = 2.4x), so a ~26 wu bar reads as ~62 screen px. Reduced motion (UIManager.is_reduced_motion())
## skips the scale-pop / pulse / chunk-lerp and snaps to the static indicator instead.
extends Node2D
class_name WorldIndicatorLayer

const CULL_MARGIN := 220.0

# Health-bar geometry (world units — multiply by ~2.4 for on-screen px).
const BAR_W := 26.0
const BAR_W_ELITE := 40.0
const BAR_H := 3.4
const HP_REVEAL_SEC := 3.0      # keep a bar up for this long after the last damage
const CHUNK_LERP_RATE := 4.0    # display-hp eases toward real hp at this rate (1/0.25s)

# Status-icon geometry.
const ICON_SIZE := 12.0
const ICON_GAP := 3.0

# Alert pop timing.
const ALERT_POP_SEC := 0.18
const ALERT_HOLD_SEC := 1.2
const ALERT_FADE_SEC := 0.45

# Per-entity transient state, all keyed by entity_id (int).
var _hp_state: Dictionary = {}        # id -> { display_frac, reveal_t }
var _status_state: Dictionary = {}    # id -> { status_name(String) -> true }
var _alert_state: Dictionary = {}     # id -> { level(String), t }
var _telegraph_state: Dictionary = {} # id -> { kind, dir, range, t, dur }


func _ready() -> void:
	z_index = 30   # above EntityRenderer (z_index 20); match EntityRenderer's self-set ordering.
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)
	queue_redraw()


func _on_cue(event_id: String, payload: Dictionary) -> void:
	if Sim == null or Sim.player == null:
		return
	match event_id:
		"damage.dealt":
			_reveal_hp(int(payload.get("target_id", 0)), float(payload.get("amount", 0.0)))
		"combo.trigger", "status.detonated":
			_reveal_hp(int(payload.get("target_id", 0)), float(payload.get("bonus_damage", 0.0)))
		"status.applied":
			_add_status(int(payload.get("target_id", 0)), String(payload.get("status", "")))
		"status.expired":
			_remove_status(int(payload.get("target_id", 0)), String(payload.get("status", "")))
		"enemy.alert":
			_set_alert(int(payload.get("entity_id", 0)), String(payload.get("alert_level", "noticed")))
		"enemy.telegraph":
			_set_telegraph(payload)
		_:
			pass


# --------------------------------------------------------------------------- cue state writers

## Reveal (or refresh) the health bar for `id`. `dmg` is this hit's damage so the chunk can be
## seeded from the PRE-hit fraction — e.hp is already post-damage by the time this cue fires, so
## without adding dmg back the first-hit chunk (disp > real) would never appear.
func _reveal_hp(id: int, dmg: float = 0.0) -> void:
	if id == 0:
		return
	var st: Dictionary = _hp_state.get(id, {})
	# Seed display_frac from the PRE-damage fraction so the white chunk drains from the old hp.
	if st.is_empty():
		var e: SimEntity = Sim.get_entity(id)
		var pre_frac := _hp_frac(e)
		if e != null and e.max_hp > 0.0 and dmg > 0.0:
			pre_frac = clampf((e.hp + dmg) / e.max_hp, 0.0, 1.0)
		st = { "display_frac": pre_frac, "reveal_t": 0.0 }
	st["reveal_t"] = HP_REVEAL_SEC
	_hp_state[id] = st


func _add_status(id: int, status: String) -> void:
	if id == 0 or status == "":
		return
	var row: Dictionary = _status_state.get(id, {})
	row[status] = true
	_status_state[id] = row


func _remove_status(id: int, status: String) -> void:
	if not _status_state.has(id):
		return
	var row: Dictionary = _status_state[id]
	row.erase(status)
	if row.is_empty():
		_status_state.erase(id)
	else:
		_status_state[id] = row


func _set_alert(id: int, level: String) -> void:
	if id == 0:
		return
	# Only "noticed" or "hostile" exist in the contract; coerce anything else to "noticed".
	if level != "hostile":
		level = "noticed"
	_alert_state[id] = { "level": level, "t": 0.0 }


func _set_telegraph(payload: Dictionary) -> void:
	var id := int(payload.get("entity_id", 0))
	if id == 0:
		return
	var attack_type := String(payload.get("attack_type", "")).to_lower()
	var kind := "melee"
	if attack_type.contains("ranged") or attack_type.contains("shoot") \
			or attack_type.contains("gun") or attack_type.contains("bolt"):
		kind = "line"
	elif attack_type.contains("aoe") or attack_type.contains("slam") \
			or attack_type.contains("quake") or attack_type.contains("ground"):
		kind = "ground"
	var dur := maxf(0.2, float(int(payload.get("wind_up_ms", 600))) / 1000.0)
	_telegraph_state[id] = {
		"kind": kind,
		"dir": float(payload.get("direction", 0.0)),
		"t": 0.0,
		"dur": dur,
	}


# --------------------------------------------------------------------------- per-frame advance

func _process(delta: float) -> void:
	if Sim == null or Sim.player == null:
		return
	var reduced := _reduced_motion()
	_advance_hp(delta, reduced)
	_advance_alerts(delta)
	_advance_telegraphs(delta)
	_prune_dead()
	# Only redraw when something is actually on screen — the iGPU baseline is ~26 FPS, so an
	# empty city (no wounded/alerted/telegraphing foes) should cost nothing here.
	if not (_hp_state.is_empty() and _status_state.is_empty() and _alert_state.is_empty() and _telegraph_state.is_empty()):
		queue_redraw()


func _advance_hp(delta: float, reduced: bool) -> void:
	for id in _hp_state.keys():
		var st: Dictionary = _hp_state[id]
		st["reveal_t"] = float(st["reveal_t"]) - delta
		var e: SimEntity = Sim.get_entity(id)
		var target_frac := _hp_frac(e)
		# Keep revealing while the entity is still damaged even after the timer lapses, so a
		# wounded foe always shows a bar (matches the "OR e.hp < e.max_hp" rule in the brief).
		if e != null and not e.dead and target_frac < 0.999:
			st["reveal_t"] = maxf(float(st["reveal_t"]), 0.0)
		if reduced:
			st["display_frac"] = target_frac
		else:
			st["display_frac"] = move_toward(float(st["display_frac"]), target_frac, delta * CHUNK_LERP_RATE)
		_hp_state[id] = st


func _advance_alerts(delta: float) -> void:
	for id in _alert_state.keys():
		var st: Dictionary = _alert_state[id]
		st["t"] = float(st["t"]) + delta
		_alert_state[id] = st


func _advance_telegraphs(delta: float) -> void:
	for id in _telegraph_state.keys():
		var st: Dictionary = _telegraph_state[id]
		st["t"] = float(st["t"]) + delta
		_telegraph_state[id] = st


## Drop all transient state for entities that have gone (null) or died, and expire finished timers.
func _prune_dead() -> void:
	for id in _hp_state.keys():
		var e: SimEntity = Sim.get_entity(id)
		var st: Dictionary = _hp_state[id]
		if e == null or e.dead or (float(st["reveal_t"]) <= 0.0 and _hp_frac(e) >= 0.999):
			_hp_state.erase(id)
	for id in _status_state.keys():
		var e: SimEntity = Sim.get_entity(id)
		if e == null or e.dead:
			_status_state.erase(id)
	for id in _alert_state.keys():
		var e: SimEntity = Sim.get_entity(id)
		var st: Dictionary = _alert_state[id]
		if e == null or e.dead or float(st["t"]) > (ALERT_POP_SEC + ALERT_HOLD_SEC + ALERT_FADE_SEC):
			_alert_state.erase(id)
	for id in _telegraph_state.keys():
		var e: SimEntity = Sim.get_entity(id)
		var st: Dictionary = _telegraph_state[id]
		if e == null or e.dead or float(st["t"]) >= float(st["dur"]):
			_telegraph_state.erase(id)


# --------------------------------------------------------------------------- drawing (pure read)

func _draw() -> void:
	if Sim == null or Sim.player == null:
		return
	var visible_rect := _visible_world_rect(CULL_MARGIN)
	var reduced := _reduced_motion()

	# Telegraphs draw on the ground/around the foe (beneath the head furniture).
	for id in _telegraph_state.keys():
		var e: SimEntity = Sim.get_entity(id)
		if e == null or e.dead or not visible_rect.has_point(e.pos):
			continue
		_draw_telegraph(e, _telegraph_state[id], reduced)

	# Health bars + status icons (anchored above the head).
	for id in _hp_state.keys():
		var e: SimEntity = Sim.get_entity(id)
		if e == null or e.dead or not visible_rect.has_point(e.pos):
			continue
		_draw_health_bar(e, _hp_state[id])
	for id in _status_state.keys():
		var e: SimEntity = Sim.get_entity(id)
		if e == null or e.dead or not visible_rect.has_point(e.pos):
			continue
		_draw_status_icons(e, _status_state[id])

	# Alerts pop on top.
	for id in _alert_state.keys():
		var e: SimEntity = Sim.get_entity(id)
		if e == null or e.dead or not visible_rect.has_point(e.pos):
			continue
		_draw_alert(e, _alert_state[id], reduced)


## 1e — health bar with an animated white "chunk" overlay (display_frac eases toward real hp).
func _draw_health_bar(e: SimEntity, st: Dictionary) -> void:
	var elite := _is_elite(e)
	var w := BAR_W_ELITE if elite else BAR_W
	var h := BAR_H
	var head := e.pos + Vector2(0, -e.radius - 14.0)
	var origin := head - Vector2(w * 0.5, 0.0)
	var real := _hp_frac(e)
	var disp := maxf(real, float(st["display_frac"]))   # chunk is the lost slice still draining

	# Backplate (with a thin dark outline so it reads over any ground colour).
	draw_rect(Rect2(origin - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(0, 0, 0, 0.72))
	draw_rect(Rect2(origin, Vector2(w, h)), Color(0.10, 0.04, 0.05, 0.85))
	# White "chunk" — the recently-lost portion, draining from disp down to real.
	if disp > real + 0.001:
		var chunk_x := origin.x + w * real
		draw_rect(Rect2(Vector2(chunk_x, origin.y), Vector2(w * (disp - real), h)), Color(0.95, 0.95, 0.95, 0.85))
	# Live fill — colour shifts green->amber->red as hp falls.
	var fill_col := Color(0.78, 0.16, 0.18) if real < 0.34 else (Color(0.86, 0.66, 0.20) if real < 0.66 else Color(0.40, 0.74, 0.34))
	if elite:
		fill_col = fill_col.lerp(Color(0.86, 0.20, 0.86), 0.18)   # elites tinted toward menace
	draw_rect(Rect2(origin, Vector2(w * real, h)), fill_col)

	# Elite/boss name label above the bar.
	if elite:
		var nm := _elite_name(e)
		var font := ThemeDB.fallback_font
		var fsize := 7   # world units; ~17px on screen at 2.4x
		var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize).x
		var lp := Vector2(head.x - tw * 0.5, origin.y - 3.0)
		draw_string(font, lp + Vector2(0.4, 0.4), nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, Color(0, 0, 0, 0.85))
		draw_string(font, lp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, Color(0.94, 0.82, 0.86))


## 1b — a horizontal row of status glyphs above the health bar; each glyph instantly readable.
func _draw_status_icons(e: SimEntity, row: Dictionary) -> void:
	var statuses: Array = row.keys()
	if statuses.is_empty():
		return
	var n := statuses.size()
	var total_w := n * ICON_SIZE + (n - 1) * ICON_GAP
	# Sit the row just above the health bar / elite label band.
	var top := e.pos + Vector2(0, -e.radius - 14.0 - (10.0 if _is_elite(e) else 6.0) - ICON_SIZE)
	var start_x := e.pos.x - total_w * 0.5
	for i in range(n):
		var cx := start_x + i * (ICON_SIZE + ICON_GAP) + ICON_SIZE * 0.5
		_draw_status_glyph(Vector2(cx, top.y + ICON_SIZE * 0.5), String(statuses[i]))


func _draw_status_glyph(c: Vector2, status: String) -> void:
	var r := ICON_SIZE * 0.5
	# A faint dark disc behind every glyph for legibility over bright ground.
	draw_circle(c, r + 0.6, Color(0, 0, 0, 0.55))
	match status:
		"burning":
			_glyph_flame(c, r, Color(1.0, 0.52, 0.14))
		"bleeding":
			_glyph_drop(c, r, Color(0.85, 0.10, 0.14))
		"stunned":
			_glyph_stars(c, r, Color(0.96, 0.86, 0.28))
		"frozen", "slow":
			_glyph_snowflake(c, r, Color(0.55, 0.86, 0.96) if status == "frozen" else Color(0.45, 0.62, 0.96))
		"marked":
			_glyph_eye(c, r, Color(0.95, 0.80, 0.28))
		"mesmerized", "confuse":
			_glyph_spiral(c, r, Color(0.70, 0.40, 0.92) if status == "mesmerized" else Color(0.96, 0.55, 0.78))
		"weakened":
			_glyph_skull(c, r, Color(0.72, 0.72, 0.74))
		"empowered":
			_glyph_arrow(c, r, Color(0.40, 0.84, 0.40))
		"rooted":
			_glyph_bracket(c, r, Color(0.62, 0.44, 0.24))
		"feared":
			_glyph_wave(c, r, Color(0.84, 0.84, 0.92))
		"shock":
			_glyph_spark(c, r, Color(0.96, 0.96, 0.98))
		_:
			# Unknown status: a neutral dot so it still reads as "something is on this foe."
			draw_circle(c, r * 0.5, Color(0.85, 0.85, 0.88))


## 2a — Metal-Gear alert: "?" (noticed, yellow) or "!!" (hostile, red), pops then holds then fades.
func _draw_alert(e: SimEntity, st: Dictionary, reduced: bool) -> void:
	var t := float(st["t"])
	var level := String(st["level"])
	var glyph := "!!" if level == "hostile" else "?"
	var col := Color(0.95, 0.20, 0.18) if level == "hostile" else Color(0.96, 0.86, 0.28)
	var a := 1.0
	if t > ALERT_POP_SEC + ALERT_HOLD_SEC:
		a = clampf(1.0 - (t - ALERT_POP_SEC - ALERT_HOLD_SEC) / ALERT_FADE_SEC, 0.0, 1.0)
	var scale := 1.0
	if not reduced and t < ALERT_POP_SEC:
		# Scale-in pop, overshooting slightly past 1.0.
		scale = clampf(t / ALERT_POP_SEC, 0.0, 1.0)
		scale = 0.4 + 1.05 * scale
	var font := ThemeDB.fallback_font
	var fsize := int(9.0 * scale)   # world units; ~22px on screen at 2.4x at rest
	if fsize < 4:
		fsize = 4
	var head := e.pos + Vector2(0, -e.radius - 26.0)
	var tw := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize).x
	var lp := Vector2(head.x - tw * 0.5, head.y)
	draw_string(font, lp + Vector2(0.5, 0.5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, Color(0, 0, 0, a * 0.85))
	draw_string(font, lp, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, Color(col.r, col.g, col.b, a))


## 2b — telegraph: aim line (ranged), ground ring (aoe), or wind-up glow (melee). Fades over its window.
func _draw_telegraph(e: SimEntity, st: Dictionary, reduced: bool) -> void:
	var p := clampf(float(st["t"]) / float(st["dur"]), 0.0, 1.0)
	var a := 1.0 - p
	var col := Color(0.95, 0.18, 0.16)
	match String(st["kind"]):
		"line":
			# A thin red aim line that grows out along 'direction' to a fixed reach.
			var reach := 240.0
			var dir := Vector2.RIGHT.rotated(float(st["dir"]))
			var tip := e.pos + dir * reach * (0.35 + 0.65 * p)
			draw_line(e.pos, tip, Color(col.r, col.g, col.b, a * 0.85), 1.6, true)
			draw_line(e.pos, tip, Color(1.0, 0.7, 0.6, a * 0.35), 4.0, true)
			draw_circle(tip, 3.2, Color(col.r, col.g, col.b, a * 0.9))
		"ground":
			# An expanding ground ring at the foe's feet (the AoE footprint filling in).
			var rmax := 60.0
			var rr := rmax * (0.25 + 0.75 * p)
			draw_circle(e.pos, rr, Color(col.r, col.g, col.b, a * 0.16))
			draw_arc(e.pos, rr, 0, TAU, 40, Color(col.r, col.g, col.b, a * 0.80), 2.2, true)
		_:
			# Melee heavy/charge: a pulsing glow ring hugging the foe during wind-up.
			var base := e.radius + 6.0
			var pulse := 0.0 if reduced else 3.0 * sin(p * TAU * 2.0)
			var rr := base + pulse
			draw_arc(e.pos, rr, 0, TAU, 32, Color(1.0, 0.45, 0.18, a * 0.85), 2.4, true)
			draw_arc(e.pos, rr * 0.7, 0, TAU, 28, Color(col.r, col.g, col.b, a * 0.40), 1.4, true)


# --------------------------------------------------------------------------- glyph primitives

func _glyph_flame(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(0, -r * 0.85),
		c + Vector2(r * 0.55, r * 0.1),
		c + Vector2(r * 0.30, r * 0.75),
		c + Vector2(-r * 0.30, r * 0.75),
		c + Vector2(-r * 0.55, r * 0.1),
	])
	draw_colored_polygon(pts, col)
	draw_circle(c + Vector2(0, r * 0.3), r * 0.28, Color(1.0, 0.86, 0.4))

func _glyph_drop(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(0, -r * 0.85),
		c + Vector2(r * 0.6, r * 0.35),
		c + Vector2(0, r * 0.8),
		c + Vector2(-r * 0.6, r * 0.35),
	])
	draw_colored_polygon(pts, col)

func _glyph_stars(c: Vector2, r: float, col: Color) -> void:
	for k in range(3):
		var ang := TAU * float(k) / 3.0 - PI * 0.5
		var p := c + Vector2.RIGHT.rotated(ang) * r * 0.45
		draw_line(p + Vector2(-r * 0.22, 0), p + Vector2(r * 0.22, 0), col, 1.4)
		draw_line(p + Vector2(0, -r * 0.22), p + Vector2(0, r * 0.22), col, 1.4)

func _glyph_snowflake(c: Vector2, r: float, col: Color) -> void:
	for k in range(3):
		var ang := PI * float(k) / 3.0
		var d := Vector2.RIGHT.rotated(ang) * r * 0.7
		draw_line(c - d, c + d, col, 1.3)

func _glyph_eye(c: Vector2, r: float, col: Color) -> void:
	draw_arc(c, r * 0.7, PI * 0.15, PI * 0.85, 12, col, 1.3)
	draw_arc(c, r * 0.7, PI + PI * 0.15, PI + PI * 0.85, 12, col, 1.3)
	draw_circle(c, r * 0.28, col)

func _glyph_spiral(c: Vector2, r: float, col: Color) -> void:
	var prev := c
	for k in range(12):
		var t := float(k) / 11.0
		var ang := t * TAU * 1.5
		var rad := r * 0.78 * t
		var p := c + Vector2.RIGHT.rotated(ang) * rad
		if k > 0:
			draw_line(prev, p, col, 1.2)
		prev = p

func _glyph_skull(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(0, -r * 0.1), r * 0.6, col)
	draw_circle(c + Vector2(-r * 0.22, -r * 0.12), r * 0.16, Color(0.06, 0.06, 0.08))
	draw_circle(c + Vector2(r * 0.22, -r * 0.12), r * 0.16, Color(0.06, 0.06, 0.08))
	draw_rect(Rect2(c + Vector2(-r * 0.28, r * 0.42), Vector2(r * 0.56, r * 0.3)), col)

func _glyph_arrow(c: Vector2, r: float, col: Color) -> void:
	draw_line(c + Vector2(0, r * 0.7), c + Vector2(0, -r * 0.7), col, 1.6)
	draw_line(c + Vector2(0, -r * 0.7), c + Vector2(-r * 0.45, -r * 0.15), col, 1.6)
	draw_line(c + Vector2(0, -r * 0.7), c + Vector2(r * 0.45, -r * 0.15), col, 1.6)

func _glyph_bracket(c: Vector2, r: float, col: Color) -> void:
	draw_line(c + Vector2(-r * 0.55, -r * 0.6), c + Vector2(-r * 0.55, r * 0.6), col, 1.5)
	draw_line(c + Vector2(-r * 0.55, r * 0.6), c + Vector2(-r * 0.2, r * 0.6), col, 1.5)
	draw_line(c + Vector2(r * 0.55, -r * 0.6), c + Vector2(r * 0.55, r * 0.6), col, 1.5)
	draw_line(c + Vector2(r * 0.55, r * 0.6), c + Vector2(r * 0.2, r * 0.6), col, 1.5)

func _glyph_wave(c: Vector2, r: float, col: Color) -> void:
	var prev := c + Vector2(-r * 0.7, 0)
	for k in range(1, 9):
		var t := float(k) / 8.0
		var x := -r * 0.7 + t * r * 1.4
		var y := sin(t * TAU) * r * 0.35
		var p := c + Vector2(x, y)
		draw_line(prev, p, col, 1.3)
		prev = p

func _glyph_spark(c: Vector2, r: float, col: Color) -> void:
	draw_line(c + Vector2(-r * 0.3, -r * 0.7), c + Vector2(r * 0.1, -r * 0.05), col, 1.5)
	draw_line(c + Vector2(r * 0.1, -r * 0.05), c + Vector2(-r * 0.15, r * 0.1), col, 1.5)
	draw_line(c + Vector2(-r * 0.15, r * 0.1), c + Vector2(r * 0.3, r * 0.7), col, 1.5)


# --------------------------------------------------------------------------- helpers

func _hp_frac(e: SimEntity) -> float:
	if e == null or e.max_hp <= 0.0:
		return 1.0
	return clampf(e.hp / e.max_hp, 0.0, 1.0)


func _is_elite(e: SimEntity) -> bool:
	if e == null:
		return false
	if e.tags.get("herald"):
		return true
	if e.max_hp >= 180.0:
		return true
	return e.type_id in ["elder", "hunter", "swat", "herald"]


func _elite_name(e: SimEntity) -> String:
	if e == null:
		return ""
	if e.tags.has("name"):
		return String(e.tags["name"])
	if e.tags.get("herald"):
		return "Herald"
	var t := String(e.type_id)
	if t.is_empty():
		return "Elite"
	return t.substr(0, 1).to_upper() + t.substr(1)


func _reduced_motion() -> bool:
	if UIManager != null and UIManager.has_method("is_reduced_motion"):
		return UIManager.is_reduced_motion()
	if CueBus != null:
		return CueBus.reduced_motion
	return false


## Visible world rect for culling (mirrors EntityRenderer._visible_world_rect). Returns a huge rect
## when there is no camera (headless) so nothing is culled — drawing is otherwise skipped at the call
## site anyway because _draw won't run headless.
func _visible_world_rect(margin: float) -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2(Vector2(-1000000.0, -1000000.0), Vector2(2000000.0, 2000000.0))
	var camera := viewport.get_camera_2d()
	if camera == null:
		return Rect2(Vector2(-1000000.0, -1000000.0), Vector2(2000000.0, 2000000.0))
	var view_size := viewport.get_visible_rect().size
	var zoom := camera.zoom
	var half := Vector2(
		view_size.x * 0.5 / maxf(zoom.x, 0.001),
		view_size.y * 0.5 / maxf(zoom.y, 0.001)
	) + Vector2(margin, margin)
	var center := camera.get_screen_center_position()
	return Rect2(center - half, half * 2.0)
