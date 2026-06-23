## WorldRenderer.gd — draws the SimWorld grid as simple colored tiles.
##
## Purely visual: floor, walls, and surface overlays (shadow, haven, water, etc.).
## No collision or gameplay logic. Owned by the vision-capable frontend agent.
extends Node2D
class_name WorldRenderer

const FLOOR_COLOR := Color("#14141c")
const WALL_COLOR := Color("#0a0a10")
const WALL_TOP_COLOR := Color("#1c1c28")
const SHADOW_COLOR := Color("#080810")
const HAVEN_COLOR := Color("#1a2038")
const WATER_COLOR := Color("#0c1828")
const FIRE_COLOR := Color("#38180c")
const SUN_COLOR := Color("#382818")
const BLOOD_COLOR := Color("#1c080c")

var _world: SimWorld = null

func setup(world: SimWorld) -> void:
	_world = world
	queue_redraw()

func _draw() -> void:
	if _world == null:
		return
	var ts: int = _world.tile_size
	for y in range(_world.size.y):
		for x in range(_world.size.x):
			var cell := Vector2i(x, y)
			var pos := Vector2(x * ts, y * ts)
			var rect := Rect2(pos, Vector2(ts, ts))
			if _world.is_solid(cell):
				_draw_wall(rect)
			else:
				draw_rect(rect, FLOOR_COLOR)
				var surface: int = _world.surface_at(pos + Vector2(ts * 0.5, ts * 0.5))
				if surface != SimWorld.Surface.NONE:
					_draw_surface(rect, surface)

func _draw_wall(rect: Rect2) -> void:
	# Slight 3D effect: darker bottom, lighter top.
	draw_rect(rect, WALL_COLOR)
	var top := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.25))
	draw_rect(top, WALL_TOP_COLOR)
	# Subtle outline
	draw_rect(rect, Color(0.08, 0.08, 0.12, 0.5), false, 1.0)

func _draw_surface(rect: Rect2, surface: int) -> void:
	match surface:
		SimWorld.Surface.SHADOW:
			draw_rect(rect, SHADOW_COLOR)
		SimWorld.Surface.HAVEN:
			draw_rect(rect, HAVEN_COLOR)
			# Soft cross pattern
			var c := rect.get_center()
			draw_line(c - Vector2(4, 4), c + Vector2(4, 4), Color("#4a5a8a"), 1.0)
			draw_line(c - Vector2(4, -4), c + Vector2(4, -4), Color("#4a5a8a"), 1.0)
		SimWorld.Surface.WATER:
			draw_rect(rect, WATER_COLOR)
		SimWorld.Surface.FIRE:
			draw_rect(rect, FIRE_COLOR)
		SimWorld.Surface.SUN:
			draw_rect(rect, SUN_COLOR)
		SimWorld.Surface.BLOOD:
			draw_rect(rect, BLOOD_COLOR)
		SimWorld.Surface.ELECTRIC:
			draw_rect(rect, Color("#183038"))
