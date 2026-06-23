## WorldRenderer.gd — draws the SimWorld grid using the authored environment textures.
##
## The old version drew flat color rects and ignored the 22 textures sitting in assets/images/.
## This wires the real art: wet asphalt for roads, sidewalk for floor, a building face for walls,
## with per-tile region sampling for variation and translucent surface overlays. Lit by the
## LightingDirector's Light2D rig (this is a CanvasItem, so it receives 2D lighting).
extends Node2D
class_name WorldRenderer

const WALL_COLOR := Color("#15151d")
const WALL_TOP_COLOR := Color("#24242f")
const FLOOR_FALLBACK := Color("#3a3a44")
const ROAD_FALLBACK := Color("#202028")

# Translucent surface overlays (drawn on top of the textured floor).
const SHADOW_TINT := Color(0, 0, 0, 0.45)
const HAVEN_TINT := Color(0.30, 0.45, 0.85, 0.30)
const WATER_TINT := Color(0.10, 0.30, 0.55, 0.40)
const FIRE_TINT := Color(0.85, 0.35, 0.10, 0.40)
const SUN_TINT := Color(1.0, 0.85, 0.45, 0.35)
const BLOOD_TINT := Color(0.45, 0.04, 0.07, 0.45)
const ELECTRIC_TINT := Color(0.30, 0.65, 0.90, 0.35)

var _world: SimWorld = null
var _floor_tex: Texture2D = null
var _road_tex: Texture2D = null
var _wall_tex: Texture2D = null


func setup(world: SimWorld) -> void:
	_world = world
	_floor_tex = _try_load("res://assets/images/sidewalk.jpg")
	_road_tex = _try_load("res://assets/images/asphalt_wet.jpg")
	_wall_tex = _try_load("res://assets/images/windows_sheet.jpg")
	queue_redraw()


func _try_load(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


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
				_draw_wall(rect, x, y)
			else:
				var center := pos + Vector2(ts * 0.5, ts * 0.5)
				if _world.is_road_world(center):
					_draw_tex_tile(_road_tex, rect, x, y, ROAD_FALLBACK)
				else:
					_draw_tex_tile(_floor_tex, rect, x, y, FLOOR_FALLBACK)
				var surface: int = _world.surface_at(center)
				if surface != SimWorld.Surface.NONE:
					_draw_surface(rect, surface)


## Draw a tile by sampling a tile-sized region from the big source texture (per-tile offset gives
## variation and uses real pixels). Falls back to a flat color if the texture is missing.
func _draw_tex_tile(tex: Texture2D, rect: Rect2, x: int, y: int, fallback: Color) -> void:
	if tex == null:
		draw_rect(rect, fallback)
		return
	var ts: int = _world.tile_size
	var tw: int = max(ts, tex.get_width())
	var th: int = max(ts, tex.get_height())
	var sx: int = (x * ts * 3) % (tw - ts) if tw > ts else 0
	var sy: int = (y * ts * 3) % (th - ts) if th > ts else 0
	draw_texture_rect_region(tex, rect, Rect2(sx, sy, ts, ts))


func _draw_wall(rect: Rect2, x: int, y: int) -> void:
	# Building face: dark base, a lit-window band sampled from the windows sheet, lighter top edge.
	draw_rect(rect, WALL_COLOR)
	if _wall_tex != null:
		var ts: int = _world.tile_size
		var tw: int = max(ts, _wall_tex.get_width())
		var th: int = max(ts, _wall_tex.get_height())
		var sx: int = (x * ts * 2) % (tw - ts) if tw > ts else 0
		var sy: int = (y * ts * 2) % (th - ts) if th > ts else 0
		# Dim the window texture so buildings read as dark with a few lit panes, not billboards.
		draw_texture_rect_region(_wall_tex, rect, Rect2(sx, sy, ts, ts), Color(0.55, 0.55, 0.6, 1.0))
	var top := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.22))
	draw_rect(top, WALL_TOP_COLOR)
	draw_rect(rect, Color(0.04, 0.04, 0.07, 0.6), false, 1.0)


func _draw_surface(rect: Rect2, surface: int) -> void:
	match surface:
		SimWorld.Surface.SHADOW:
			draw_rect(rect, SHADOW_TINT)
		SimWorld.Surface.HAVEN:
			draw_rect(rect, HAVEN_TINT)
			var c := rect.get_center()
			draw_line(c - Vector2(4, 4), c + Vector2(4, 4), Color("#7a92d8"), 1.0)
			draw_line(c - Vector2(4, -4), c + Vector2(4, -4), Color("#7a92d8"), 1.0)
		SimWorld.Surface.WATER:
			draw_rect(rect, WATER_TINT)
		SimWorld.Surface.FIRE:
			draw_rect(rect, FIRE_TINT)
		SimWorld.Surface.SUN:
			draw_rect(rect, SUN_TINT)
		SimWorld.Surface.BLOOD:
			draw_rect(rect, BLOOD_TINT)
		SimWorld.Surface.ELECTRIC:
			draw_rect(rect, ELECTRIC_TINT)
