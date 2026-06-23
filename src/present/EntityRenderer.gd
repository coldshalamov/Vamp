## EntityRenderer.gd — draws SimEntities as authored top-down sprites (with graceful fallback).
##
## Loads keyed sprites from assets/sprites/ (player/civilian/thug/cop/hunter) and draws them with a
## soft drop shadow + a facing nub. Vehicles get a real top-down car body. If a sprite is missing it
## falls back to the old colored disc so nothing ever vanishes. Lit by the LightingDirector rig.
extends Node2D
class_name EntityRenderer

const PLAYER_COLOR := Color("#c01028")
const CIV_COLOR := Color("#8a8a9a")
const GANG_COLOR := Color("#5a3a2a")
const POLICE_COLOR := Color("#2a3a5a")
const INQUIS_COLOR := Color("#3a3a3a")
const THRALL_COLOR := Color("#4a2a5a")

# entity sprite key -> resource path (keyed transparent PNGs produced by process_sprites.gd)
const SPRITE_PATHS := {
	"player": "res://assets/sprites/player.png",
	"civ": "res://assets/sprites/civilian.png",
	"gang": "res://assets/sprites/thug.png",
	"police": "res://assets/sprites/cop.png",
	"inquis": "res://assets/sprites/hunter.png",
}

var _entities: Array[SimEntity] = []
var _tex_cache: Dictionary = {}


func setup(entities: Array[SimEntity]) -> void:
	_entities = entities


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for e in _entities:
		if e == null or e.dead:
			continue
		if e.kind == "vehicle":
			_draw_vehicle(e)
		elif e.kind == "projectile":
			_draw_projectile(e)
		else:
			_draw_actor(e)


func _draw_projectile(e: SimEntity) -> void:
	var tex := _tex_projectile()
	if tex == null:
		draw_circle(e.pos, maxf(e.radius, 4.0), Color("#c8102a"))
		return
	var s := maxf(e.radius * 2.2, 12.0) / float(tex.get_height())
	var size := tex.get_size() * s
	draw_set_transform(e.pos, e.facing, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-size * 0.5, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_actor(e: SimEntity) -> void:
	var r: float = e.radius
	var pos: Vector2 = e.pos
	# Soft contact shadow at the feet.
	draw_circle(pos + Vector2(0, r * 0.55), r * 1.15, Color(0, 0, 0, 0.40))

	var tex := _sprite_for(e)
	if tex != null:
		# Draw upright (these sprites aren't directional) scaled to the actor's footprint.
		var target_h := r * 5.2
		var scale := target_h / float(tex.get_height())
		var size := tex.get_size() * scale
		draw_texture_rect(tex, Rect2(pos - size * 0.5 - Vector2(0, r * 0.6), size), false)
		# Small bright facing nub on the ground so aim/facing stays readable.
		var nub := pos + Vector2.RIGHT.rotated(e.facing) * (r * 1.2)
		draw_circle(nub, 2.5, Color(1, 0.9, 0.7, 0.9))
	else:
		_draw_disc(e)

	_draw_status(e)


func _draw_disc(e: SimEntity) -> void:
	var r: float = e.radius
	var pos: Vector2 = e.pos
	var color := _entity_color(e)
	draw_circle(pos, r, color)
	var nose := pos + Vector2.RIGHT.rotated(e.facing) * r * 1.2
	var left := pos + Vector2.RIGHT.rotated(e.facing + 0.9) * r * 0.6
	var right := pos + Vector2.RIGHT.rotated(e.facing - 0.9) * r * 0.6
	draw_colored_polygon([nose, left, right], color.lightened(0.25))


func _draw_vehicle(e: SimEntity) -> void:
	var r: float = e.radius
	var pos: Vector2 = e.pos
	var length := maxf(r * 2.6, 44.0)
	var width := maxf(r * 1.4, 22.0)
	var body := Color("#1a2438") if _entity_is_police(e) else Color("#15151c")
	draw_set_transform(pos, e.facing, Vector2.ONE)
	# contact shadow
	draw_rect(Rect2(Vector2(-length * 0.5 + 2, -width * 0.5 + 3), Vector2(length, width)), Color(0, 0, 0, 0.4))
	# body
	draw_rect(Rect2(Vector2(-length * 0.5, -width * 0.5), Vector2(length, width)), body)
	# roof / cabin
	draw_rect(Rect2(Vector2(-length * 0.12, -width * 0.38), Vector2(length * 0.42, width * 0.76)), body.lightened(0.10))
	# windshield hint
	draw_rect(Rect2(Vector2(length * 0.22, -width * 0.30), Vector2(length * 0.10, width * 0.60)), Color("#3a4a66"))
	# headlight beams forward
	var beam := Color(1.0, 0.95, 0.7, 0.5) if not _entity_is_police(e) else Color(0.6, 0.7, 1.0, 0.5)
	draw_colored_polygon([
		Vector2(length * 0.5, -width * 0.4),
		Vector2(length * 0.5, width * 0.4),
		Vector2(length * 1.1, width * 0.9),
		Vector2(length * 1.1, -width * 0.9),
	], Color(beam.r, beam.g, beam.b, 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


func _entity_color(e: SimEntity) -> Color:
	if e.kind == "player":
		return PLAYER_COLOR
	match e.faction:
		"civ":
			return CIV_COLOR
		"gang":
			return GANG_COLOR
		"police":
			return POLICE_COLOR
		"inquis":
			return INQUIS_COLOR
		"player":
			return THRALL_COLOR
	return Color.GRAY
