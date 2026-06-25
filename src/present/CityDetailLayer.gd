## CityDetailLayer.gd — additive ground detail + foreground depth over the textured city.
##
## WorldRenderer already paints wet asphalt / sidewalk / building faces (z 0). This layer sits ON TOP
## of that art and adds the things that make a street read as a real, used place: worn lane markings,
## curb edge lines, zebra crosswalks, manhole covers, cracks and faint puddles on the road; and — ABOVE
## the actors — sparse awnings, hanging signs and fire-escape railings clinging to building edges so the
## predator passes BEHIND them when prowling the walls, giving the flat top-down world some depth.
##
## Two CanvasItem bands (a single Node2D has ONE z_index, so the two depth layers must be separate
## children): a DETAIL band at z 6 (under the actors at z 20) and a FOREGROUND band at z 30 (over them).
## The root draws nothing; setup() builds both bands, precomputes their static placement, and add_childs
## them. Both bands are plain Node2D/_draw() CanvasItems, so the LightingDirector's Light2D rig lights
## them like everything else in the night.
##
## Presentation-only: reads the SimWorld view dynamically (world.size / world.tile_size / world.is_solid /
## world.is_road_world) and NEVER mutates it or touches Sim.rng. All placement variation comes from a
## stable integer hash of the cell coords (the SpellFX/ParticleFX pattern), so it is identical every run
## and adds nothing to the per-frame cost — it is a STATIC layer, built once, no _process.
##
## NOTE on structure: the two bands are inner classes. GDScript inner classes cannot reference the
## enclosing `class_name` while the file is still compiling, so each band is fully self-contained —
## its own palette consts and its own copy of the (tiny) deterministic hash helpers.
extends Node2D
class_name CityDetailLayer

var _detail: _DetailBand = null
var _fg: _ForegroundBand = null


## Called by the integrator with Sim.world after add_child. Builds both depth bands from the grid.
## `world` is intentionally untyped — SimWorld may be mid-edit by a parallel agent and we only ever
## call instance members on it, never the SimWorld type itself.
func setup(world) -> void:
	if world == null:
		return
	_detail = _DetailBand.new()
	_detail.name = "CityDetailBand"
	_detail.z_index = 6        # below actors (z 20); above the world art (z 0)
	add_child(_detail)
	_detail.build(world)

	_fg = _ForegroundBand.new()
	_fg.name = "CityForegroundBand"
	_fg.z_index = 30           # above actors (z 20) so building-edge props overlap the player
	add_child(_fg)
	_fg.build(world)


# =====================================================================================
#  DETAIL BAND — road markings + ground decals, drawn UNDER the actors (z 6).
# =====================================================================================
class _DetailBand extends Node2D:
	# Worn, dark palette — weathering UNDER the asphalt texture, never fresh paint.
	const LANE_YELLOW := Color(0.62, 0.52, 0.16, 0.34)   # faded center dashes
	const EDGE_WHITE := Color(0.70, 0.70, 0.74, 0.22)    # curb edge lines
	const CROSSWALK := Color(0.74, 0.74, 0.78, 0.26)     # zebra stripes
	const MANHOLE := Color(0.06, 0.06, 0.08, 0.85)
	const MANHOLE_RIM := Color(0.16, 0.16, 0.19, 0.7)
	const CRACK := Color(0.03, 0.03, 0.04, 0.5)
	const PUDDLE := Color(0.16, 0.22, 0.30, 0.22)

	# Precomputed draw lists (built once in build(), replayed each frame by _draw()).
	var _h_dashes: Array[Dictionary] = []   # horizontal center dashes {a,b}
	var _v_dashes: Array[Dictionary] = []   # vertical center dashes {a,b}
	var _edges: Array[Dictionary] = []      # curb edge lines {a,b}
	var _zebras: Array[Dictionary] = []     # crosswalk stripes {a,b,w}
	var _manholes: PackedVector2Array = PackedVector2Array()
	var _cracks: Array[PackedVector2Array] = []
	var _puddles: Array[Dictionary] = []    # {c, rx, ry}

	# --- deterministic placement helpers (SpellFX/ParticleFX pattern — NEVER randf/Sim.rng) ---
	static func _cell_seed(cx: int, cy: int) -> int:
		return (cx * 73856093) ^ (cy * 19349663)

	static func _hash01(seed_val: int, salt: int) -> float:
		var x: int = absi(seed_val * 1103515245 + salt * 12345 + 1013904223)
		return float(x % 100003) / 100003.0

	func build(world) -> void:
		var ts: int = world.tile_size
		var sz: Vector2i = world.size
		var half: float = float(ts) * 0.5

		for y in range(sz.y):
			for x in range(sz.x):
				var cell := Vector2i(x, y)
				if world.is_solid(cell):
					continue
				var center := Vector2(x * ts + half, y * ts + half)
				if not world.is_road_world(center):
					continue

				# Run direction is a property of the band's EXTENT, not a cell's neighbours: a 4-wide
				# arterial has road on all four sides at its interior, so neighbour-counting fails.
				# Walk the contiguous road span along each axis and classify by which run is longer.
				var sh: Vector2i = _span(world, ts, x, y, 1, 0)   # (behind, ahead) horizontally
				var sv: Vector2i = _span(world, ts, x, y, 0, 1)   # (above, below) vertically
				var ext_h: int = sh.x + sh.y + 1                  # E-W run length through this cell
				var ext_v: int = sv.x + sv.y + 1                  # N-S run length through this cell
				var is_intersection: bool = mini(ext_h, ext_v) >= 5
				var is_ew: bool = ext_h > ext_v

				var rn: bool = _road(world, ts, x, y - 1)
				var rs: bool = _road(world, ts, x, y + 1)
				var rw: bool = _road(world, ts, x - 1, y)
				var re: bool = _road(world, ts, x + 1, y)

				var seed_val := _cell_seed(x, y)

				# --- CENTER LANE LINES: one dashed spine down the MIDDLE row/col of the band; plus
				# solid edge lines along the band's non-road long sides. Skip busy intersections.
				if not is_intersection:
					if is_ew:
						# band's middle row: top = y - above, center = top + floor(height/2)
						var mid_row: int = (y - sv.x) + (sv.x + sv.y) / 2
						if y == mid_row and ext_v >= 2:
							var ya: float = float(y * ts + ts)   # seam at the bottom of the mid row
							_h_dashes.append({"a": Vector2(x * ts + 2.0, ya), "b": Vector2(x * ts + ts - 2.0, ya)})
						if not rn:
							_edges.append({"a": Vector2(x * ts + 1.0, y * ts + 2.0), "b": Vector2(x * ts + ts - 1.0, y * ts + 2.0)})
						if not rs:
							_edges.append({"a": Vector2(x * ts + 1.0, y * ts + ts - 2.0), "b": Vector2(x * ts + ts - 1.0, y * ts + ts - 2.0)})
					else:
						var mid_col: int = (x - sh.x) + (sh.x + sh.y) / 2
						if x == mid_col and ext_h >= 2:
							var xa: float = float(x * ts + ts)
							_v_dashes.append({"a": Vector2(xa, y * ts + 2.0), "b": Vector2(xa, y * ts + ts - 2.0)})
						if not rw:
							_edges.append({"a": Vector2(x * ts + 2.0, y * ts + 1.0), "b": Vector2(x * ts + 2.0, y * ts + ts - 1.0)})
						if not re:
							_edges.append({"a": Vector2(x * ts + ts - 2.0, y * ts + 1.0), "b": Vector2(x * ts + ts - 2.0, y * ts + ts - 1.0)})

				# --- CROSSWALK only at a run's MOUTH (along the run axis), where it meets an
				# intersection or a walkable sidewalk curb. Bars run PERPENDICULAR to the run.
				_maybe_crosswalk(world, ts, x, y, is_ew, is_intersection)

				# --- SCATTERED DECALS (sparse, deterministic). On intersections only manholes.
				if is_intersection:
					if _hash01(seed_val, 17) < 0.05:
						_manholes.append(center)
				else:
					var roll := _hash01(seed_val, 3)
					if roll < 0.022:
						_manholes.append(center + Vector2((_hash01(seed_val, 5) - 0.5) * ts * 0.4,
							(_hash01(seed_val, 6) - 0.5) * ts * 0.4))
					elif roll < 0.16:
						_cracks.append(_make_crack(center, seed_val, ts))
					elif roll < 0.27:
						var rx: float = float(ts) * (0.18 + 0.20 * _hash01(seed_val, 8))
						var ry: float = rx * (0.55 + 0.35 * _hash01(seed_val, 9))
						_puddles.append({"c": center + Vector2((_hash01(seed_val, 10) - 0.5) * ts * 0.4,
							(_hash01(seed_val, 11) - 0.5) * ts * 0.4), "rx": rx, "ry": ry})

		queue_redraw()

	func _road(world, ts: int, cx: int, cy: int) -> bool:
		if cx < 0 or cy < 0 or cx >= world.size.x or cy >= world.size.y:
			return false
		return world.is_road_world(Vector2(cx * ts + ts * 0.5, cy * ts + ts * 0.5))

	# Contiguous road extent through (x,y) along (dx,dy): returns (cells_behind, cells_ahead).
	# ext = behind + ahead + 1. Used for run direction, band midpoint, and the intersection test.
	func _span(world, ts: int, x: int, y: int, dx: int, dy: int) -> Vector2i:
		var lo := 0
		while _road(world, ts, x - dx * (lo + 1), y - dy * (lo + 1)):
			lo += 1
		var hi := 0
		while _road(world, ts, x + dx * (hi + 1), y + dy * (hi + 1)):
			hi += 1
		return Vector2i(lo, hi)

	# True if the neighbour cell is an intersection, OR a walkable sidewalk curb (non-road, non-solid).
	# Road ends that butt into a wall are neither, so no crosswalk is painted there.
	func _is_crossing_edge(world, ts: int, cx: int, cy: int) -> bool:
		if cx < 0 or cy < 0 or cx >= world.size.x or cy >= world.size.y:
			return false
		var cell := Vector2i(cx, cy)
		if world.is_solid(cell):
			return false
		if not _road(world, ts, cx, cy):
			return true   # walkable curb
		# road neighbour: a crossing only if it is itself an intersection cell
		var sh: Vector2i = _span(world, ts, cx, cy, 1, 0)
		var sv: Vector2i = _span(world, ts, cx, cy, 0, 1)
		return mini(sh.x + sh.y + 1, sv.x + sv.y + 1) >= 5

	# Crosswalk only at a run's MOUTH: gate on the RUN-axis neighbours. Bars run PERPENDICULAR to the
	# run, so stacked across the band's mouth cells they read as one full crossing.
	func _maybe_crosswalk(world, ts: int, x: int, y: int, is_ew: bool, is_intersection: bool) -> void:
		if is_intersection:
			return
		var f := float(ts)
		if is_ew:
			# E-W road: a crossing sits at its E or W mouth -> vertical bars repeated along x
			if _is_crossing_edge(world, ts, x - 1, y) or _is_crossing_edge(world, ts, x + 1, y):
				for i in range(4):
					var xx: float = x * ts + f * (0.18 + 0.21 * i)
					_zebras.append({"a": Vector2(xx, y * ts + 3.0), "b": Vector2(xx, y * ts + f - 3.0), "w": 3.0})
		else:
			# N-S road: crossing at its N or S mouth -> horizontal bars repeated along y
			if _is_crossing_edge(world, ts, x, y - 1) or _is_crossing_edge(world, ts, x, y + 1):
				for i in range(4):
					var yy: float = y * ts + f * (0.18 + 0.21 * i)
					_zebras.append({"a": Vector2(x * ts + 3.0, yy), "b": Vector2(x * ts + f - 3.0, yy), "w": 3.0})

	func _make_crack(center: Vector2, seed_val: int, ts: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var ang: float = _hash01(seed_val, 21) * TAU
		var p := center + Vector2((_hash01(seed_val, 22) - 0.5) * ts * 0.4,
			(_hash01(seed_val, 23) - 0.5) * ts * 0.4)
		pts.append(p)
		for s in range(3):
			ang += (_hash01(seed_val, 30 + s) - 0.5) * 1.4
			var step: float = float(ts) * (0.12 + 0.10 * _hash01(seed_val, 40 + s))
			p += Vector2.RIGHT.rotated(ang) * step
			pts.append(p)
		return pts

	func _draw() -> void:
		# Faint puddles first (they sit "under" the markings), then decals, then paint.
		for pud in _puddles:
			_draw_ellipse(pud["c"], pud["rx"], pud["ry"], PUDDLE)
		for cr in _cracks:
			if cr.size() >= 2:
				draw_polyline(cr, CRACK, 1.0)
		for m in _manholes:
			draw_circle(m, 6.0, MANHOLE)
			draw_arc(m, 6.0, 0.0, TAU, 14, MANHOLE_RIM, 1.0)
			draw_line(m + Vector2(-4, 0), m + Vector2(4, 0), MANHOLE_RIM, 1.0)
		for e in _edges:
			draw_line(e["a"], e["b"], EDGE_WHITE, 1.5)
		for d in _h_dashes:
			draw_dashed_line(d["a"], d["b"], LANE_YELLOW, 2.0, 6.0)
		for d in _v_dashes:
			draw_dashed_line(d["a"], d["b"], LANE_YELLOW, 2.0, 6.0)
		for z in _zebras:
			draw_line(z["a"], z["b"], CROSSWALK, z["w"])

	func _draw_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		var n := 14
		for i in range(n):
			var a: float = TAU * float(i) / float(n)
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, col)


# =====================================================================================
#  FOREGROUND BAND — awnings / signs / fire-escape rails on building edges, OVER actors (z 30).
# =====================================================================================
class _ForegroundBand extends Node2D:
	const AWNING_A := Color(0.42, 0.12, 0.14, 0.95)      # deep red canvas
	const AWNING_B := Color(0.16, 0.26, 0.34, 0.95)      # teal canvas
	const AWNING_TRIM := Color(0.86, 0.82, 0.70, 0.9)
	const SIGN_BODY := Color(0.09, 0.09, 0.12, 0.95)
	const SIGN_GLOW := Color(0.85, 0.30, 0.42, 0.8)
	const RAIL := Color(0.05, 0.05, 0.07, 0.95)
	const RAIL_HI := Color(0.22, 0.22, 0.26, 0.8)

	# {kind:int, pos:Vector2, w:float, h:float, col:Color}  kind 0=awning 1=sign 2=rail
	var _props: Array[Dictionary] = []

	static func _cell_seed(cx: int, cy: int) -> int:
		return (cx * 73856093) ^ (cy * 19349663)

	static func _hash01(seed_val: int, salt: int) -> float:
		var x: int = absi(seed_val * 1103515245 + salt * 12345 + 1013904223)
		return float(x % 100003) / 100003.0

	func build(world) -> void:
		var ts: int = world.tile_size
		var sz: Vector2i = world.size
		var half: float = float(ts) * 0.5

		for y in range(sz.y):
			for x in range(sz.x):
				var cell := Vector2i(x, y)
				if world.is_solid(cell):
					continue
				# Only walkable cells that ABUT a building to the north — the prop hangs off that wall
				# face and drapes down over the street, so a player walking the wall passes behind it.
				if not _solid(world, x, y - 1):
					continue
				var seed_val := _cell_seed(x, y)
				# Sparse: roughly 1 in 6 eligible cells gets a prop; the hash picks which kind.
				if _hash01(seed_val, 71) > 0.17:
					continue
				var top := Vector2(x * ts + half, y * ts + 1.0)   # hangs from the wall base seam
				var kind_roll := _hash01(seed_val, 73)
				if kind_roll < 0.42:
					var col: Color = AWNING_A if _hash01(seed_val, 74) < 0.5 else AWNING_B
					_props.append({"kind": 0, "pos": top, "w": float(ts) * 0.92, "h": float(ts) * 0.5, "col": col, "seed": seed_val})
				elif kind_roll < 0.72:
					_props.append({"kind": 1, "pos": top + Vector2(0, 4.0), "w": float(ts) * 0.34, "h": float(ts) * 0.6, "col": SIGN_GLOW, "seed": seed_val})
				else:
					_props.append({"kind": 2, "pos": top, "w": float(ts) * 0.9, "h": float(ts) * 0.78, "col": RAIL, "seed": seed_val})

		queue_redraw()

	func _solid(world, cx: int, cy: int) -> bool:
		if cx < 0 or cy < 0 or cx >= world.size.x or cy >= world.size.y:
			return true
		return world.is_solid(Vector2i(cx, cy))

	func _draw() -> void:
		for p in _props:
			match int(p["kind"]):
				0: _draw_awning(p)
				1: _draw_sign(p)
				_: _draw_rail(p)

	# Striped canvas awning drooping from the wall over the sidewalk, with a soft cast shadow below.
	func _draw_awning(p: Dictionary) -> void:
		var c: Vector2 = p["pos"]
		var w: float = p["w"]
		var h: float = p["h"]
		var col: Color = p["col"]
		var tl := c + Vector2(-w * 0.5, 0.0)
		var tr := c + Vector2(w * 0.5, 0.0)
		var bl := c + Vector2(-w * 0.42, h)
		var br := c + Vector2(w * 0.42, h)
		# soft shadow it throws onto the ground just past its lip
		draw_colored_polygon(PackedVector2Array([bl + Vector2(2, 2), br + Vector2(2, 2),
			br + Vector2(2, 6), bl + Vector2(2, 6)]), Color(0, 0, 0, 0.28))
		draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), col)
		# vertical scallop stripes
		for i in range(1, 5):
			var f: float = float(i) / 5.0
			draw_line(tl.lerp(tr, f), bl.lerp(br, f), Color(1, 1, 1, 0.12), 1.0)
		# scalloped front trim
		draw_line(bl, br, AWNING_TRIM, 1.5)

	# Hanging blade sign on a short bracket — dark body with a neon edge so it pops in the night.
	func _draw_sign(p: Dictionary) -> void:
		var c: Vector2 = p["pos"]
		var w: float = p["w"]
		var h: float = p["h"]
		var col: Color = p["col"]
		var arm := c + Vector2(0, 2.0)
		var bracket := arm + Vector2(w * 0.7, 0.0)
		draw_line(arm, bracket, RAIL_HI, 1.5)              # support arm off the wall
		var rect := Rect2(bracket + Vector2(-w * 0.5, 2.0), Vector2(w, h))
		draw_rect(rect, SIGN_BODY)
		draw_rect(rect, col, false, 1.5)                   # neon outline
		draw_line(rect.get_center() + Vector2(0, -h * 0.22), rect.get_center() + Vector2(0, h * 0.22), col, 1.5)

	# Fire-escape railing: two horizontal rails + balusters the player passes behind.
	func _draw_rail(p: Dictionary) -> void:
		var c: Vector2 = p["pos"]
		var w: float = p["w"]
		var h: float = p["h"]
		var col: Color = p["col"]
		var left := c.x - w * 0.5
		var right := c.x + w * 0.5
		var top_y := c.y
		var bot_y := c.y + h
		draw_line(Vector2(left, top_y), Vector2(right, top_y), col, 2.0)
		draw_line(Vector2(left, top_y + h * 0.45), Vector2(right, top_y + h * 0.45), col, 1.5)
		for i in range(6):
			var px: float = lerp(left, right, float(i) / 5.0)
			draw_line(Vector2(px, top_y - 2.0), Vector2(px, bot_y), col, 1.0)
		draw_line(Vector2(left, top_y - 1.0), Vector2(right, top_y - 1.0), RAIL_HI, 1.0)
