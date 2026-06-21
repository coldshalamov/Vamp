## SimWorld.gd — the level/district state inside the sim.
##
## Pure data: the tile/collision grid, spawn points, surface-type map (for the systemic
## world rules — blood/fire/water/sun, REVAMP_SPEC §12), and named POIs. No rendering.
## The render layer reads this and draws tiles + lighting; it never mutates this.
##
## Stub for now — fleshed out when the level-design system lands (Phase 1 §11).
##
extends RefCounted
class_name SimWorld

var size: Vector2i = Vector2i(128, 128)        # tiles
var tile_size: int = 32                         # pixels per tile
var walls: PackedByteArray = PackedByteArray()  # 1 = solid, 0 = open (size.x * size.y)
var surfaces: PackedByteArray = PackedByteArray() # 0=none, 1=blood, 2=fire, 3=water, 4=sun, 5=electric
var spawn_points: Array[Vector2] = []

func _init() -> void:
	walls.resize(size.x * size.y)
	surfaces.resize(size.x * size.y)

func is_solid(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return true
	return walls[cell.y * size.x + cell.x] != 0

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x) / tile_size, int(world_pos.y) / tile_size)
