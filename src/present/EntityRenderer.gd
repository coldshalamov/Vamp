## EntityRenderer.gd — draws SimEntities as grounded, directional, animated top-down figures.
##
## Sprites (assets/sprites/*.png) are TRUE overhead art keyed to transparency. They are rotated to
## face the entity's aim/heading (the sprite art faces "north"), grounded with a soft contact shadow,
## and bob subtly when moving. Entities without a sprite yet fall back to a directional procedural
## figure (NOT a flat disc). Dead actors leave a body + blood pool instead of vanishing.
extends Node2D
class_name EntityRenderer

# Sprite art is drawn facing "up" (north); add +PI/2 so it points along the entity facing (0 = +X).
const SPRITE_NORTH_OFFSET := PI / 2.0

# entity sprite key -> overhead PNG (keyed transparent).
const SPRITE_PATHS := {
	"player": "res://assets/sprites/player.png",
	"civ": "res://assets/sprites/civilian.png",
	"gang": "res://assets/sprites/thug.png",
	"police": "res://assets/sprites/cop.png",
	"inquis": "res://assets/sprites/hunter.png",
}

var _entities: Array[SimEntity] = []
var _tex_cache: Dictionary = {}
var _last_pos: Dictionary = {}
var _moving: Dictionary = {}
var _t: float = 0.0


func setup(entities: Array[SimEntity]) -> void:
	_entities = entities


func _process(delta: float) -> void:
	_t += delta
	for e in _entities:
		if e == null:
			continue
		var lp: Vector2 = _last_pos.get(e.id, e.pos)
		_moving[e.id] = lp.distance_to(e.pos) > 0.45
		_last_pos[e.id] = e.pos
	queue_redraw()


func _draw() -> void:
	# Bodies first (under the living), then living actors.
	for e in _entities:
		if e == null:
			continue
		if e.dead:
			if e.kind == "player" or e.kind == "npc":
				_draw_corpse(e)
			continue
	for e in _entities:
		if e == null or e.dead:
			continue
		if e.kind == "vehicle":
			_draw_vehicle(e)
		elif e.kind == "projectile":
			_draw_projectile(e)
		else:
			_draw_actor(e)


# ----------------------------------------------------------------- actors

func _draw_actor(e: SimEntity) -> void:
	_draw_shadow(e, 1.0)
	var moving: bool = bool(_moving.get(e.id, false))
	var tex := _sprite_for(e)
	if tex != null:
		_draw_sprite_actor(e, tex, moving)
	else:
		_draw_proc_actor(e, moving)
	_draw_status(e)


func _draw_shadow(e: SimEntity, scale: float) -> void:
	var r: float = e.radius * scale
	draw_set_transform(e.pos + Vector2(0, r * 0.32), 0.0, Vector2(1.28, 0.60))
	draw_circle(Vector2.ZERO, r * 1.05, Color(0, 0, 0, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sprite_actor(e: SimEntity, tex: Texture2D, moving: bool) -> void:
	var r: float = e.radius
	var target_h: float = r * 4.4
	var sc: float = target_h / float(tex.get_height())
	var size: Vector2 = tex.get_size() * sc
	var bob: float = sin(_t * 9.0 + float(e.id)) * (r * 0.10) if moving else sin(_t * 2.0 + float(e.id)) * (r * 0.035)
	var rot: float = e.facing + SPRITE_NORTH_OFFSET
	draw_set_transform(e.pos + Vector2(0, -bob), rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-size * 0.5, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Directional top-down figure for entities that don't have a sprite yet (no flat discs).
func _draw_proc_actor(e: SimEntity, moving: bool) -> void:
	var r: float = e.radius
	var pal: Dictionary = _proc_palette(e)
	var phase: float = _t * (9.0 if moving else 2.2) + float(e.id) * 1.7
	var bob: float = sin(phase) * (r * 0.10 if moving else r * 0.035)
	var sw: float = sin(phase) * (r * 0.22 if moving else r * 0.05)   # limb swing
	draw_set_transform(e.pos + Vector2(0, -bob), e.facing, Vector2.ONE)   # local +X = forward
	# cloak/coat fan trailing behind for cloaked types
	if bool(pal.get("cloak", false)):
		draw_colored_polygon([
			Vector2(-r * 1.7, sin(phase) * r * 0.25), Vector2(r * 0.1, -r * 1.05),
			Vector2(r * 0.35, 0.0), Vector2(r * 0.1, r * 1.05),
		], pal["coat"] as Color)
	# arms/shoulders (swing fore/aft when moving)
	var arm: Color = (pal["coat"] as Color).darkened(0.12)
	draw_circle(Vector2(sw, -r * 0.66), r * 0.32, arm)
	draw_circle(Vector2(-sw, r * 0.66), r * 0.32, arm)
	# torso
	draw_circle(Vector2(-r * 0.04, 0.0), r * 0.92, pal["coat"] as Color)
	# head (hood/cap dark + face)
	draw_circle(Vector2(r * 0.30, 0.0), r * 0.46, pal["head_dark"] as Color)
	draw_circle(Vector2(r * 0.42, 0.0), r * 0.30, pal["head"] as Color)
	# accent (collar/insignia at chest, points forward)
	draw_colored_polygon([
		Vector2(r * 0.20, -r * 0.18), Vector2(r * 0.20, r * 0.18), Vector2(r * 0.58, 0.0),
	], pal["accent"] as Color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_corpse(e: SimEntity) -> void:
	var r: float = e.radius
	# blood pool
	draw_set_transform(e.pos, e.facing, Vector2(1.4, 0.72))
	draw_circle(Vector2.ZERO, r * 1.5, Color(0.16, 0.015, 0.035, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# prone body (squashed, dark)
	var pal: Dictionary = _proc_palette(e)
	draw_set_transform(e.pos, e.facing, Vector2(1.25, 0.66))
	draw_circle(Vector2.ZERO, r * 0.9, (pal["coat"] as Color).darkened(0.25))
	draw_circle(Vector2(r * 0.7, 0.0), r * 0.34, (pal["head"] as Color).darkened(0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _proc_palette(e: SimEntity) -> Dictionary:
	if e.kind == "player":
		return { "coat": Color("#15151d"), "head_dark": Color("#08080c"), "head": Color("#c9b8b0"), "accent": Color("#c01028"), "cloak": true }
	match String(e.faction):
		"civ":
			return { "coat": Color("#6f6456"), "head_dark": Color("#2a2018"), "head": Color("#c2a48c"), "accent": Color("#565663"), "cloak": false }
		"gang":
			return { "coat": Color("#3f2d20"), "head_dark": Color("#171109"), "head": Color("#b6906e"), "accent": Color("#7a2a2a"), "cloak": false }
		"police":
			return { "coat": Color("#1f2c49"), "head_dark": Color("#0d1322"), "head": Color("#bda890"), "accent": Color("#9fb4e0"), "cloak": false }
		"inquis":
			return { "coat": Color("#2b2b31"), "head_dark": Color("#131318"), "head": Color("#c8bca8"), "accent": Color("#d8d2c4"), "cloak": true }
		"player":
			return { "coat": Color("#3a2a4a"), "head_dark": Color("#181020"), "head": Color("#b89cc0"), "accent": Color("#8a5ac0"), "cloak": false }
	return { "coat": Color("#5a5a64"), "head_dark": Color("#1a1a20"), "head": Color("#b0a090"), "accent": Color("#777"), "cloak": false }


func _draw_status(e: SimEntity) -> void:
	var r: float = e.radius
	var pos: Vector2 = e.pos
	if e.has_status("mesmerized"):
		draw_arc(pos, r + 6, 0, TAU, 16, Color("#b98cff"), 2.0)
	if e.has_status("fear"):
		draw_arc(pos, r + 6, 0, TAU, 16, Color("#ff9ecf"), 2.0)
	if e.has_status("stun"):
		draw_arc(pos, r + 6, 0, TAU, 16, Color("#f0c040"), 2.0)
	if e.tags.get("marked", 0) > 0:
		draw_arc(pos, r + 8, 0, TAU, 16, Color("#aef0ff"), 2.0)


# ----------------------------------------------------------------- projectiles / vehicles

func _draw_projectile(e: SimEntity) -> void:
	var tex := _tex_projectile()
	if tex == null:
		# glowing blood mote with a short tail
		draw_circle(e.pos, maxf(e.radius, 4.0) + 2.0, Color(0.78, 0.06, 0.16, 0.35))
		draw_circle(e.pos, maxf(e.radius, 4.0), Color("#e8203a"))
		return
	var s := maxf(e.radius * 2.4, 14.0) / float(tex.get_height())
	var size := tex.get_size() * s
	draw_set_transform(e.pos, e.facing, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-size * 0.5, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_vehicle(e: SimEntity) -> void:
	var r: float = e.radius
	var pos: Vector2 = e.pos
	var length := maxf(r * 2.6, 44.0)
	var width := maxf(r * 1.4, 22.0)
	var body := Color("#1a2438") if _entity_is_police(e) else Color("#15151c")
	draw_set_transform(pos, e.facing, Vector2.ONE)
	draw_rect(Rect2(Vector2(-length * 0.5 + 2, -width * 0.5 + 3), Vector2(length, width)), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(Vector2(-length * 0.5, -width * 0.5), Vector2(length, width)), body)
	draw_rect(Rect2(Vector2(-length * 0.12, -width * 0.38), Vector2(length * 0.42, width * 0.76)), body.lightened(0.10))
	draw_rect(Rect2(Vector2(length * 0.22, -width * 0.30), Vector2(length * 0.10, width * 0.60)), Color("#3a4a66"))
	var beam := Color(1.0, 0.95, 0.7, 0.5) if not _entity_is_police(e) else Color(0.6, 0.7, 1.0, 0.5)
	draw_colored_polygon([
		Vector2(length * 0.5, -width * 0.4), Vector2(length * 0.5, width * 0.4),
		Vector2(length * 1.1, width * 0.9), Vector2(length * 1.1, -width * 0.9),
	], Color(beam.r, beam.g, beam.b, 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ----------------------------------------------------------------- texture helpers

func _sprite_for(e: SimEntity) -> Texture2D:
	var key := "player" if e.kind == "player" else String(e.faction)
	if not SPRITE_PATHS.has(key):
		return null
	if _tex_cache.has(key):
		return _tex_cache[key]
	var path: String = SPRITE_PATHS[key]
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_tex_cache[key] = tex
	return tex


func _tex_projectile() -> Texture2D:
	const P := "res://assets/sprites/projectile.png"
	if _tex_cache.has(P):
		return _tex_cache[P]
	var t: Texture2D = load(P) as Texture2D if ResourceLoader.exists(P) else null
	_tex_cache[P] = t
	return t


func _entity_is_police(e: SimEntity) -> bool:
	return e.type_id == "police" or e.faction == "police"
