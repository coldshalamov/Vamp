## EntityRenderer.gd — draws all SimEntities as placeholder sprites.
##
## Uses simple shapes so the game is readable before final art arrives.
## Player and NPCs get distinct silhouettes; facing is shown with a wedge.
extends Node2D
class_name EntityRenderer

const PLAYER_COLOR := Color("#c01028")
const PLAYER_CLOAK := Color("#1a0a14")
const CIV_COLOR := Color("#8a8a9a")
const GANG_COLOR := Color("#5a3a2a")
const POLICE_COLOR := Color("#2a3a5a")
const INQUIS_COLOR := Color("#3a3a3a")
const THRALL_COLOR := Color("#4a2a5a")
const DEAD_COLOR := Color("#0a0a10")

var _entities: Array[SimEntity] = []

func setup(entities: Array[SimEntity]) -> void:
	_entities = entities

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for e in _entities:
		if e == null or e.dead:
			continue
		_draw_entity(e)

func _draw_entity(e: SimEntity) -> void:
	var r: float = e.radius
	var pos: Vector2 = e.pos
	var color := _entity_color(e)

	# Shadow
	draw_circle(pos + Vector2(0, r * 0.4), r * 1.1, Color(0, 0, 0, 0.35))

	# Body
	draw_circle(pos, r, color)

	# Facing wedge
	var nose := pos + Vector2.RIGHT.rotated(e.facing) * r * 1.2
	var left := pos + Vector2.RIGHT.rotated(e.facing + 0.9) * r * 0.6
	var right := pos + Vector2.RIGHT.rotated(e.facing - 0.9) * r * 0.6
	draw_colored_polygon([nose, left, right], _facing_color(e))

	# Status overlays
	if e.has_status("mesmerized"):
		draw_arc(pos, r + 4, 0, TAU, 16, Color("#b98cff"), 2.0)
	if e.has_status("fear"):
		draw_arc(pos, r + 4, 0, TAU, 16, Color("#ff9ecf"), 2.0)
	if e.has_status("stun"):
		draw_arc(pos, r + 4, 0, TAU, 16, Color("#f0c040"), 2.0)
	if e.tags.get("marked", 0) > 0:
		draw_arc(pos, r + 6, 0, TAU, 16, Color("#aef0ff"), 2.0)

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

func _facing_color(e: SimEntity) -> Color:
	var base := _entity_color(e)
	return base.lightened(0.25)
