## WorldRenderer.gd — draws the SimWorld grid using the authored environment textures.
##
## The old version drew flat color rects and ignored the 22 textures sitting in assets/images/.
## This wires the real art: wet asphalt for roads, sidewalk for floor, a building face for walls,
## with per-tile region sampling for variation and translucent surface overlays. Lit by the
## LightingDirector's Light2D rig (this is a CanvasItem, so it receives 2D lighting).
extends Node2D
class_name WorldRenderer

const WALL_COLOR := Color("#13131b")
const WALL_TOP_COLOR := Color("#22222d")
const FLOOR_FALLBACK := Color("#262932")   # dark sidewalk
const ROAD_FALLBACK := Color("#191b22")    # dark wet asphalt

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


const WET_SHADER := "res://glowup_2026/shaders/wet_asphalt.gdshader"


func setup(world: SimWorld) -> void:
	_world = world
	_floor_tex = _try_load("res://assets/images/sidewalk.jpg")
	_road_tex = _try_load("res://assets/images/asphalt_wet.jpg")
	_wall_tex = _try_load("res://assets/images/windows_sheet.jpg")
	_apply_wet_material()
	queue_redraw()


## Apply the merged glowup wet-asphalt shader as a subtle wet-street sheen over the tiles.
func _apply_wet_material() -> void:
	if not ResourceLoader.exists(WET_SHADER):
		return
	var mat := ShaderMaterial.new()
	mat.shader = load(WET_SHADER)
	var noise := _try_load("res://assets/images/wet_noise.png")
	var ripple := _try_load("res://assets/images/wet_ripple.png")
	if noise != null:
		mat.set_shader_parameter("noise_texture", noise)
	if ripple != null:
		mat.set_shader_parameter("ripple_texture", ripple)
	mat.set_shader_parameter("wetness", 0.5)
	mat.set_shader_parameter("reflection_strength", 0.16)
	mat.set_shader_parameter("warm_mix", 0.32)
	mat.set_shader_parameter("darkening", 0.08)
	mat.set_shader_parameter("ripple_strength", 0.1)
	mat.set_shader_parameter("macro_scale", 1.4)
	material = mat


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
	# Dark base first, then the photo CONTINUOUSLY at low opacity = subtle grounded texture
	# instead of a loud, discontinuous per-tile photo quilt (the old *3 jump made it look noisy).
	draw_rect(rect, fallback)
	if tex == null:
		return
	var ts: int = _world.tile_size
	var tw: int = max(ts, tex.get_width())
	var th: int = max(ts, tex.get_height())
	var sx: int = (x * ts) % (tw - ts) if tw > ts else 0
	var sy: int = (y * ts) % (th - ts) if th > ts else 0
	draw_texture_rect_region(tex, rect, Rect2(sx, sy, ts, ts), Color(1, 1, 1, 0.42))


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
