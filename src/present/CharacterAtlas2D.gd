## CharacterAtlas2D.gd — normal/specular-mapped atlas renderer for every living actor.
##
## Presentation only: authoritative state remains in SimEntity.  The renderer consumes the same
## setup/physics_sync/advance_visual/notify_event/set_detail_level contract as CharacterRig2D, but
## replaces hundreds of per-frame primitive calls with one atlas region draw per actor.  Eight
## authored directions avoid mirrored weapons and mirrored normal-map lobes.
extends Node2D
class_name CharacterAtlas2D

# Cell size + baseline are derived per-atlas from the bound texture (see
# _refresh_atlas) so the legacy 96x128 SVG atlases and the new 192x256 Blender
# atlases can coexist while the roster is migrated one archetype at a time.
var _frame_w := 96.0
var _frame_h := 128.0
var _baseline_y := 112.0
const HIT_REACT_DURATION := 0.24
const DASH_TRAIL_DURATION := 0.30
const TELEPORT_DISTANCE := 180.0
const MAX_AFTERIMAGES := 6
const TAU_INV := 1.0 / TAU
const RuntimeSafetyScript := preload("res://src/core/RuntimeSafety.gd")

## One shared rim-light material for every actor (cold-moon silhouette so dark bodies pop from the
## dark ground). Shared, not per-actor, so no per-actor material allocation. See character_rim.gdshader.
## The HERO gets an upgraded directional "wet edge" rim (hero_rim.gdshader) — also shared, so the player
## still costs one material, not one per frame.
const RIM_SHADER_PATH := "res://art/shaders/character_rim.gdshader"
const HERO_RIM_SHADER_PATH := "res://art/shaders/hero_rim.gdshader"
static var _rim_material: ShaderMaterial = null
static var _hero_rim_material: ShaderMaterial = null

static func _shared_rim_material() -> ShaderMaterial:
	if _rim_material == null:
		if not ResourceLoader.exists(RIM_SHADER_PATH):
			return null
		var rim_shader := load(RIM_SHADER_PATH) as Shader
		if rim_shader == null:
			return null
		_rim_material = ShaderMaterial.new()
		_rim_material.shader = rim_shader
	return _rim_material

## The hero's upgraded wet-edge rim. Falls back to the shared rim if the hero shader is missing.
static func _shared_hero_rim_material() -> ShaderMaterial:
	if _hero_rim_material == null:
		if not ResourceLoader.exists(HERO_RIM_SHADER_PATH):
			return _shared_rim_material()
		var hero_shader := load(HERO_RIM_SHADER_PATH) as Shader
		if hero_shader == null:
			return _shared_rim_material()
		_hero_rim_material = ShaderMaterial.new()
		_hero_rim_material.shader = hero_shader
	return _hero_rim_material

const ATLAS_MATERIAL_PATHS := {
	"hero": "res://assets/visual/materials/characters/hero.tres",
	"thug": "res://assets/visual/materials/characters/thug.tres",
	"gunner": "res://assets/visual/materials/characters/gunner.tres",
	"cop": "res://assets/visual/materials/characters/cop.tres",
	"swat": "res://assets/visual/materials/characters/swat.tres",
	"hunter": "res://assets/visual/materials/characters/hunter.tres",
	"elder": "res://assets/visual/materials/characters/elder.tres",
	"thrall": "res://assets/visual/materials/characters/thrall.tres",
	"civilian": "res://assets/visual/materials/characters/civilian.tres",
	"rat": "res://assets/visual/materials/characters/rat.tres",
}
static var _atlas_cache: Dictionary = {}

const CIVILIAN_TINTS := [
	Color(1.00, 1.00, 1.00, 1.0),
	Color(0.92, 0.98, 1.06, 1.0),
	Color(1.05, 0.95, 0.91, 1.0),
	Color(0.94, 1.04, 0.96, 1.0),
	Color(1.03, 1.00, 0.91, 1.0),
]

var entity: SimEntity = null
var detail_level: int = 2

var _atlas_key := "civilian"
var _atlas: Texture2D = null
var _profile_key := ""
var _facing := 0.0
var _speed_target := 0.0
var _speed_blend := 0.0
var _gait_phase := 0.0
var _time := 0.0
var _action_subframe := 0.0
var _last_action_frame := -1
var _hit_react := 0.0
var _dash_timer := 0.0
var _flash := 0.0
var _last_sim_pos := Vector2.ZERO
var _afterimages: Array[Dictionary] = []
var _trail_accum := 0.0
var _redraw_accum := 0.0
var _last_row := -1
var _last_col := -1


func setup(sim_entity: SimEntity) -> void:
	entity = sim_entity
	if entity == null:
		return
	position = entity.pos
	_facing = entity.facing
	_last_sim_pos = entity.pos
	# _refresh_atlas selects the rim material from _atlas_key (hero gets the upgraded wet-edge rim).
	_refresh_atlas(true)
	reset_physics_interpolation()
	queue_redraw()


## Called once after each authoritative simulation tick.
func physics_sync(delta: float) -> void:
	if entity == null:
		return
	var moved := _last_sim_pos.distance_to(entity.pos)
	var teleported := moved > TELEPORT_DISTANCE
	position = entity.pos
	if teleported:
		reset_physics_interpolation()
	_facing = entity.facing
	_speed_target = clampf(moved / maxf(delta, 0.0001) / 230.0, 0.0, 1.65) if delta > 0.0 else 0.0
	_last_sim_pos = entity.pos

	var frame := int(entity.action_frame)
	if frame != _last_action_frame:
		_last_action_frame = frame
		_action_subframe = 0.0

	if _dash_timer > 0.0 and moved > 2.0:
		_trail_accum += moved
		if _trail_accum >= 7.0:
			_trail_accum = 0.0
			_afterimages.push_back({
				"pos": entity.pos,
				"row": _select_row(),
				"col": _direction_column(_facing),
				"age": 0.0,
			})
			while _afterimages.size() > MAX_AFTERIMAGES:
				_afterimages.pop_front()

	_refresh_atlas(false)
	var row := _select_row()
	var col := _direction_column(_facing)
	if row != _last_row or col != _last_col:
		_last_row = row
		_last_col = col
		queue_redraw()


## Render-cadence state only.  Distant actors redraw more slowly while their interpolated Node2D
## transforms still move smoothly at the physics cadence.
func advance_visual(delta: float) -> void:
	if entity == null:
		return
	_time += delta
	var blend := 1.0 - exp(-12.0 * delta)
	_speed_blend = lerpf(_speed_blend, _speed_target, blend)
	if entity.hitstop <= 0:
		_gait_phase += delta * lerpf(2.0, 10.5, clampf(_speed_blend, 0.0, 1.0))
		_action_subframe = minf(_action_subframe + delta * 60.0, 0.999)
	_hit_react = maxf(0.0, _hit_react - delta)
	_dash_timer = maxf(0.0, _dash_timer - delta)
	_flash = maxf(0.0, _flash - delta * 5.8)
	for i in range(_afterimages.size() - 1, -1, -1):
		_afterimages[i]["age"] = float(_afterimages[i]["age"]) + delta
		if float(_afterimages[i]["age"]) >= DASH_TRAIL_DURATION:
			_afterimages.remove_at(i)

	var redraw_hz := 30.0 if detail_level >= 2 else (15.0 if detail_level == 1 else 8.0)
	_redraw_accum += delta
	if _redraw_accum >= 1.0 / redraw_hz:
		_redraw_accum = fmod(_redraw_accum, 1.0 / redraw_hz)
		queue_redraw()


func notify_event(event_id: String, payload: Dictionary) -> void:
	if entity == null:
		return
	match event_id:
		"move.dash":
			if int(payload.get("entity_id", 0)) == entity.id:
				_dash_timer = 0.34
				_trail_accum = 99.0
		"damage.dealt", "damage.player", "hit.connect", "projectile.hit":
			if int(payload.get("target_id", 0)) == entity.id:
				_hit_react = HIT_REACT_DURATION
				_flash = 1.0
				queue_redraw()
		"player.respawn":
			if entity.kind == "player":
				position = entity.pos
				_last_sim_pos = entity.pos
				reset_physics_interpolation()
				_afterimages.clear()
				queue_redraw()
		_:
			pass


func set_detail_level(level: int) -> void:
	detail_level = clampi(level, 0, 2)


func _draw() -> void:
	if entity == null:
		return
	_draw_resonance()
	_draw_contact_shadow()
	_draw_afterimages()
	if _atlas == null:
		_draw_missing_asset()
	else:
		var row := _select_row()
		var col := _direction_column(_facing)
		var tint := _entity_tint()
		if _flash > 0.0:
			# White-hot hit pop: brighten the body FAR past 1.0 so it survives the night ambient and
			# the brighter texels clip toward white — a clear "I connected" flash.
			tint = tint.lerp(Color(8.0, 8.0, 8.4, tint.a), clampf(_flash, 0.0, 1.0))
		_draw_frame(_atlas, row, col, tint, Vector2.ZERO, _sprite_scale())
	_draw_status()
	_draw_alert()


func _draw_frame(texture: Texture2D, row: int, col: int, tint: Color, offset: Vector2, scale_value: float) -> void:
	var source := Rect2(float(col) * _frame_w, float(row) * _frame_h, _frame_w, _frame_h)
	var destination := Rect2(
		Vector2(-_frame_w * 0.5 * scale_value, -_baseline_y * scale_value),
		Vector2(_frame_w * scale_value, _frame_h * scale_value))
	var placed := Rect2(destination.position + offset, destination.size)
	draw_texture_rect_region(texture, placed, source, tint, false, true)


## Contact shadow drawn in-engine (the Blender sprites are figure-only; no baked
## ground shadow, which would smear across the cell and pollute the normal pass).
func _draw_contact_shadow() -> void:
	if entity == null or entity.dead:
		return
	var rr := maxf(entity.radius, 8.0) * _sprite_scale() * (2.7 if _frame_h >= 200.0 else 1.2)
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, rr * 1.3, Color(0.0, 0.0, 0.0, 0.26))   # soft wide pool
	draw_circle(Vector2.ZERO, rr * 0.72, Color(0.0, 0.0, 0.0, 0.52))  # dark grounding core
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_afterimages() -> void:
	if _afterimages.is_empty() or _atlas == null or entity == null:
		return
	for snap in _afterimages:
		var age := float(snap["age"])
		var alpha := pow(1.0 - clampf(age / DASH_TRAIL_DURATION, 0.0, 1.0), 1.7) * 0.34
		if alpha <= 0.005:
			continue
		var offset: Vector2 = snap["pos"] - entity.pos
		var ghost := Color(1.0, 0.18, 0.30, alpha)
		_draw_frame(_atlas, int(snap["row"]), int(snap["col"]), ghost, offset, _sprite_scale())


func _select_row() -> int:
	if entity == null:
		return 0
	if entity.dead:
		return 15
	if entity.downed or String(entity.ai_state) in ["downed", "fed", "carried"]:
		return 14
	if _hit_react > 0.0 or entity.stun > 0 or entity.has_status("stun"):
		return 12
	if entity.current_action != null and entity.current_action.def != null:
		var def: ActionDef = entity.current_action.def
		var action_id := String(def.id)
		if action_id.contains("feed") or action_id.contains("bite"):
			return 13
		if action_id.contains("dash"):
			return 4 + (int(floor(fposmod(_gait_phase, TAU) * TAU_INV * 2.0)) % 2)
		var frame := float(entity.action_frame) + _action_subframe
		if frame < float(def.startup):
			return 8
		if frame < float(def.startup + def.active):
			var active_p := (frame - float(def.startup)) / maxf(float(def.active), 1.0)
			return 9 if active_p < 0.58 else 10
		return 11
	if _speed_blend > 0.10:
		var walk_frame := int(floor(fposmod(_gait_phase, TAU) * TAU_INV * 6.0)) % 6
		return 2 + walk_frame
	return int(floor(_time * 1.25 + float(entity.id) * 0.37)) % 2


func _direction_column(angle: float) -> int:
	var wrapped := wrapf(angle, 0.0, TAU)
	return int(round(wrapped / (PI * 0.25))) % 8


func _sprite_scale() -> float:
	if entity == null:
		return 0.68
	# Larger 192x256 cells have more headroom, so a lower multiplier keeps the
	# on-screen figure the same size as the legacy 96x128 art.
	var big := _frame_h >= 200.0
	if _atlas_key == "rat":
		return maxf(entity.radius / 8.0, 0.58) * (0.41 if big else 0.56)
	return maxf(entity.radius / 12.0, 0.72) * (0.62 if big else 0.68)


func _refresh_atlas(force: bool) -> void:
	if entity == null:
		return
	var key := "%s:%s:%s" % [entity.kind, entity.faction, entity.type_id]
	if not force and key == _profile_key:
		return
	_profile_key = key
	_atlas_key = _select_atlas_key()
	if RuntimeSafetyScript.safe_mode_enabled():
		material = null
		_atlas = null
		queue_redraw()
		return
	# Hero gets the upgraded directional wet-edge rim; every other actor shares the cheap cold rim.
	material = _shared_hero_rim_material() if _atlas_key == "hero" else _shared_rim_material()
	_atlas = _atlas_for(_atlas_key)
	if _atlas == null:
		push_error("Missing visual atlas material for '%s'" % _atlas_key)
	else:
		# 8 columns x 16 rows; baseline at 7/8 of cell height (Y=224 of 256, 112 of 128).
		var w := float(_atlas.get_width())
		var h := float(_atlas.get_height())
		if w > 0.0 and h > 0.0:
			_frame_w = w / 8.0
			_frame_h = h / 16.0
			_baseline_y = _frame_h * 0.875
	queue_redraw()


func _select_atlas_key() -> String:
	if entity.kind == "player":
		return "hero"
	var type_id := String(entity.type_id).to_lower()
	var faction := String(entity.faction).to_lower()
	if type_id in ["rat", "animal"]:
		return "rat"
	if faction == "thrall":
		return "thrall"
	if ATLAS_MATERIAL_PATHS.has(type_id):
		return type_id
	if type_id in ["ped", "civilian", "witness"]:
		return "civilian"
	if faction == "police":
		return "swat" if bool(entity.responder) and String(entity.tags.get("weapon", "")) == "rifle" else "cop"
	if faction in ["inquisition", "hunter"]:
		return "hunter"
	if bool(entity.tags.get("elder", false)):
		return "elder"
	var weapon := String(entity.tags.get("weapon", ""))
	if weapon == "rifle":
		return "hunter"
	if weapon == "pistol":
		return "gunner"
	if entity.hostile_to_player:
		return "thug"
	return "civilian"


func _entity_tint() -> Color:
	if entity == null:
		return Color.WHITE
	if _atlas_key == "civilian":
		return CIVILIAN_TINTS[abs(entity.id) % CIVILIAN_TINTS.size()]
	if bool(entity.tags.get("herald", false)):
		return Color(1.08, 0.82, 0.86, 1.0)
	return Color.WHITE


func _draw_missing_asset() -> void:
	var s := maxf(entity.radius, 8.0)
	var body := _safe_body_color() if RuntimeSafetyScript.safe_mode_enabled() else Color(0.96, 0.0, 0.82, 0.9)
	var points := PackedVector2Array([
		Vector2(0, -s * 2.2), Vector2(s, -s), Vector2(s * 0.72, 0),
		Vector2(-s * 0.72, 0), Vector2(-s, -s),
	])
	draw_colored_polygon(points, body)
	draw_circle(Vector2(0.0, -s * 2.55), s * 0.45, body.lightened(0.18))


func _draw_resonance() -> void:
	if entity.resonance == "" or not (entity.faction == "civ" or entity.downed):
		return
	var col := _resonance_color(entity.resonance)
	var pulse := 0.62 + 0.38 * sin(_time * 2.2 + float(entity.id))
	var rr := entity.radius * (1.55 + 0.12 * sin(_time * 2.2 + float(entity.id)))
	draw_arc(Vector2(0, 2.0), rr, 0, TAU, 28, Color(col.r, col.g, col.b, 0.38 * pulse), 1.8, true)
	draw_arc(Vector2(0, 2.0), rr * 0.72, 0, TAU, 24, Color(col.r, col.g, col.b, 0.16 * pulse), 1.1, true)


func _draw_status() -> void:
	if entity == null:
		return
	var r := entity.radius + 8.0
	if entity.has_status("mesmerized"):
		draw_arc(Vector2.ZERO, r, 0, TAU, 22, Color("b98cff"), 1.8, true)
	if entity.has_status("fear"):
		draw_arc(Vector2.ZERO, r, 0, TAU, 22, Color("ff9ecf"), 1.8, true)
	if entity.has_status("stun"):
		for i in range(3):
			var a := _time * 3.5 + float(i) * TAU / 3.0
			draw_line(Vector2.RIGHT.rotated(a) * (r - 2.0), Vector2.RIGHT.rotated(a) * (r + 4.0), Color("f0c040"), 1.8, true)
	if int(entity.tags.get("marked", 0)) > 0:
		draw_arc(Vector2.ZERO, r + 2.0, 0, TAU, 24, Color("aef0ff"), 1.8, true)


func _draw_alert() -> void:
	if entity == null or entity.dead or entity.kind != "npc" or not (entity.hostile_to_player or entity.responder):
		return
	var p := Vector2(0.0, -_baseline_y * _sprite_scale() - 4.0)
	var state := String(entity.ai_state)
	var perception := String(entity.perception_state)
	if state in ["chase", "attack"] or perception in ["alert", "combat"]:
		var combat_color := Color("ff3a44")
		draw_line(p, p + Vector2(0, 7), combat_color, 2.2, true)
		draw_circle(p + Vector2(0, 11), 1.5, combat_color)
	elif state == "search" or int(entity.search_ticks) > 0:
		var search_color := Color("f0c040")
		draw_arc(p + Vector2(0, 3), 3.8, -2.3, 1.2, 12, search_color, 1.9, true)
		draw_line(p + Vector2(0, 3), p + Vector2(0, 7), search_color, 1.9, true)
		draw_circle(p + Vector2(0, 10), 1.35, search_color)


func _resonance_color(humour: String) -> Color:
	match humour:
		"sanguine": return Color("d23a52")
		"choleric": return Color("e08838")
		"melancholic": return Color("6f8ce0")
		"phlegmatic": return Color("6fd6a0")
	return Color("a0a0a8")


static func _atlas_for(key: String) -> Texture2D:
	var resolved := key if ATLAS_MATERIAL_PATHS.has(key) else "civilian"
	if _atlas_cache.has(resolved):
		return _atlas_cache[resolved] as Texture2D
	var path := String(ATLAS_MATERIAL_PATHS[resolved])
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	_atlas_cache[resolved] = tex
	return tex


func _safe_body_color() -> Color:
	if entity == null:
		return Color("9ba8b5")
	if entity.kind == "player":
		return Color("d9dde7")
	if entity.faction == "police":
		return Color("7aa6d8")
	if entity.hostile_to_player:
		return Color("d87878")
	if entity.downed or entity.dead:
		return Color("777a80")
	return Color("a4b8aa")
