## ParallaxBackdrop.gd — distant nocturnal city beyond the play field.
##
## In this top-down game the lit building blocks float in a dark void; this fills that void with a
## sense of a larger sleeping city. Three ParallaxLayers, each driven by a PROCEDURALLY generated
## silhouette ImageTexture (no art assets exist): a FAR band of dark blue-grey towers (motion_scale
## ~0.2), a MID band of nearer rooftops + water towers (~0.45), and a SKY band with a soft moon and
## faint cloud smears. Each band tiles horizontally via ParallaxLayer.motion_mirroring so it covers
## camera panning in any direction.
##
## ParallaxBackground extends CanvasLayer and auto-follows the active Camera2D (the CameraDirector).
## It is forced to layer = -1 so it renders BEHIND the world regardless of child order. Everything is
## kept DARK and dim so it reads as far-off background and never competes with the lit foreground.
##
## Presentation-only: subscribes to CueBus read-only (dawn.warning, to faintly warm the sky toward
## dawn) and never touches Sim or Sim.rng. All work is one-time texture bakes in _ready() — there is
## no per-frame _draw/_process cost beyond ParallaxBackground's built-in scroll follow.
extends ParallaxBackground
class_name ParallaxBackdrop

# Texture strip dimensions. Wider than a single screen so the seam is far apart; mirrored to tile.
const STRIP_W := 1024
const FAR_H := 320
const MID_H := 256
const SKY_H := 360

# How dim each band sits. The far band is the dimmest; nothing here is allowed to read as foreground.
const FAR_MOTION := 0.2
const MID_MOTION := 0.45
const SKY_MOTION := 0.1   # sky barely parallaxes — it's effectively at infinity

# Baseline cool night sky color the moon/clouds sit against.
const SKY_TOP := Color(0.045, 0.055, 0.085, 1.0)
const SKY_BOTTOM := Color(0.085, 0.075, 0.105, 1.0)

# Dawn warm tint, blended over the sky sprite's modulate as dawn approaches (cue-driven, read-only).
const DAWN_TINT := Color(0.55, 0.40, 0.42)

var _sky_sprite: Sprite2D = null
var _dawn: float = 0.0   # 0 = deep night, 1 = dawn near; lerped toward the cue's target each frame


func _ready() -> void:
	# Force behind the world (WorldRenderer lives in the default layer 0). Negative layer guarantees
	# it draws first even if the integrator's child order ever changes.
	layer = -1

	_build_sky_layer()
	_build_far_layer()
	_build_mid_layer()

	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


# --- layer construction -------------------------------------------------------

func _build_sky_layer() -> void:
	var tex := _make_sky_texture()
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	# Anchor the sky band near the top of the view; it sits furthest back.
	sprite.position = Vector2(0, -SKY_H * 0.5)
	sprite.modulate = Color(1, 1, 1, 1)
	_sky_sprite = sprite

	var layer_node := ParallaxLayer.new()
	layer_node.motion_scale = Vector2(SKY_MOTION, SKY_MOTION * 0.5)
	layer_node.motion_mirroring = Vector2(STRIP_W, 0)   # tile horizontally only
	layer_node.add_child(sprite)
	add_child(layer_node)


func _build_far_layer() -> void:
	var tex := _make_skyline_texture(
		FAR_H, 14,
		Color(0.10, 0.12, 0.17, 1.0),   # dark blue-grey towers
		Color(0.14, 0.16, 0.22, 1.0),   # faint top edge
		Color(0.55, 0.60, 0.40, 1.0),   # rare dim lit window
		0.012,                          # window density (very sparse)
		0.40, 0.95                      # min/max building height fraction
	)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.position = Vector2(0, -FAR_H * 0.35)
	sprite.modulate = Color(1, 1, 1, 0.85)

	var layer_node := ParallaxLayer.new()
	layer_node.motion_scale = Vector2(FAR_MOTION, FAR_MOTION)
	layer_node.motion_mirroring = Vector2(STRIP_W, 0)
	layer_node.add_child(sprite)
	add_child(layer_node)


func _build_mid_layer() -> void:
	var tex := _make_skyline_texture(
		MID_H, 9,
		Color(0.07, 0.08, 0.11, 1.0),   # nearer = darker silhouettes
		Color(0.11, 0.12, 0.16, 1.0),
		Color(0.62, 0.55, 0.32, 1.0),   # warmer lit windows
		0.020,
		0.30, 0.80
	)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.position = Vector2(0, -MID_H * 0.15)
	sprite.modulate = Color(1, 1, 1, 0.92)

	var layer_node := ParallaxLayer.new()
	layer_node.motion_scale = Vector2(MID_MOTION, MID_MOTION)
	layer_node.motion_mirroring = Vector2(STRIP_W, 0)
	layer_node.add_child(sprite)
	add_child(layer_node)


# --- cue handling (read-only) -------------------------------------------------

func _on_cue(event_id: String, payload: Dictionary) -> void:
	if event_id != "dawn.warning":
		return
	# minutes_remaining shrinks toward dawn; warm the sky more the closer it gets. Guard the key.
	var mins: float = float(payload.get("minutes_remaining", 30.0))
	_dawn = clampf(1.0 - mins / 30.0, 0.0, 1.0)
	_apply_dawn()


func _apply_dawn() -> void:
	if _sky_sprite == null:
		return
	# Tint the sky sprite toward a muted warm dawn; stays dim (capped) so it never blooms.
	var tint := Color(1, 1, 1).lerp(DAWN_TINT, _dawn * 0.6)
	_sky_sprite.modulate = tint


# --- procedural texture bakes (one-time, in _ready) ---------------------------

## A vertical sky gradient with a soft moon disc and a couple of faint horizontal cloud smears.
func _make_sky_texture() -> ImageTexture:
	var img := Image.create(STRIP_W, SKY_H, false, Image.FORMAT_RGBA8)
	for y in range(SKY_H):
		var vt: float = float(y) / float(SKY_H - 1)
		var base := SKY_TOP.lerp(SKY_BOTTOM, vt)
		for x in range(STRIP_W):
			img.set_pixel(x, y, base)

	# Faint drifting cloud bands — low-alpha lighter smears, drawn with a cheap sine-thickness loop.
	var cloud := Color(0.16, 0.17, 0.22, 1.0)
	var bands := [
		{"cy": int(SKY_H * 0.30), "amp": 10.0, "freq": 0.018, "a": 0.10},
		{"cy": int(SKY_H * 0.55), "amp": 7.0, "freq": 0.026, "a": 0.07},
	]
	for b in bands:
		var cy: int = b["cy"]
		var amp: float = b["amp"]
		var freq: float = b["freq"]
		var ca: float = b["a"]
		for x in range(STRIP_W):
			var off: int = int(sin(float(x) * freq) * amp)
			var half := 6 + int(3.0 * sin(float(x) * 0.01))
			for dy in range(-half, half + 1):
				var yy: int = cy + off + dy
				if yy < 0 or yy >= SKY_H:
					continue
				var edge: float = 1.0 - absf(float(dy)) / float(half + 1)
				_blend_px(img, x, yy, cloud, ca * edge)

	# Soft moon disc, parked left-of-center so panning reveals it. Per-pixel alpha falloff (no square).
	var moon_c := Vector2(STRIP_W * 0.28, SKY_H * 0.32)
	var moon_r := 34.0
	var moon_col := Color(0.82, 0.84, 0.78, 1.0)
	var halo_r := moon_r * 2.6
	var x0: int = int(moon_c.x - halo_r)
	var x1: int = int(moon_c.x + halo_r)
	var y0: int = int(moon_c.y - halo_r)
	var y1: int = int(moon_c.y + halo_r)
	for y in range(maxi(0, y0), mini(SKY_H, y1)):
		for x in range(maxi(0, x0), mini(STRIP_W, x1)):
			var d: float = Vector2(float(x), float(y)).distance_to(moon_c)
			if d <= moon_r:
				# solid-ish disc with a feathered rim
				var core: float = clampf(1.0 - (d / moon_r) * 0.4, 0.0, 1.0)
				_blend_px(img, x, y, moon_col, core * 0.85)
			elif d <= halo_r:
				# soft halo glow
				var h: float = 1.0 - (d - moon_r) / (halo_r - moon_r)
				_blend_px(img, x, y, moon_col, h * h * 0.10)
	return ImageTexture.create_from_image(img)


## A tiling skyline silhouette strip: flat-topped buildings of varied width/height, a lighter top
## edge, and sparse lit windows. Deterministic (presentation hash, never Sim.rng) so the strip is
## stable across runs. The first and last building columns are kept short/flat so the mirror seam
## is invisible when tiled.
func _make_skyline_texture(h: int, count: int, body: Color, top_edge: Color, window: Color,
		window_density: float, min_frac: float, max_frac: float) -> ImageTexture:
	var img := Image.create(STRIP_W, h, false, Image.FORMAT_RGBA8)
	# Transparent above the rooftops; the sky layer shows through.
	img.fill(Color(0, 0, 0, 0))

	var seed_base := 0x9E3779B9 ^ (h * 2654435761) ^ (count * 40503)
	var x := 0
	var bw: int = STRIP_W / count
	var idx := 0
	while x < STRIP_W:
		var w: int = bw + int(_h01(seed_base, idx * 3) * float(bw) * 0.5) - int(bw * 0.25)
		w = clampi(w, int(bw * 0.5), int(bw * 1.4))
		if x + w > STRIP_W:
			w = STRIP_W - x
		var frac: float = lerpf(min_frac, max_frac, _h01(seed_base, idx * 3 + 1))
		var bh: int = int(float(h) * frac)
		var top_y: int = h - bh
		# Fill the building body.
		for yy in range(top_y, h):
			for xx in range(x, mini(STRIP_W, x + w)):
				img.set_pixel(xx, yy, body)
		# Lighter top edge / parapet (2-3 px).
		var edge_h := 3
		for yy in range(top_y, mini(h, top_y + edge_h)):
			for xx in range(x, mini(STRIP_W, x + w)):
				img.set_pixel(xx, yy, top_edge)
		# Sparse lit windows scattered down the face.
		var inset := 3
		for yy in range(top_y + edge_h + 2, h - 2):
			for xx in range(x + inset, mini(STRIP_W, x + w - inset)):
				if _h01(seed_base, (yy * 131 + xx) * 7 + idx) < window_density:
					img.set_pixel(xx, yy, window)
		x += w
		idx += 1
	return ImageTexture.create_from_image(img)


# --- pixel helpers ------------------------------------------------------------

## Alpha-over blend a color onto an existing pixel (the bake uses straight-alpha source colors).
func _blend_px(img: Image, x: int, y: int, col: Color, a: float) -> void:
	if a <= 0.0:
		return
	var dst := img.get_pixel(x, y)
	var out_a: float = a + dst.a * (1.0 - a)
	if out_a <= 0.0001:
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var r: float = (col.r * a + dst.r * dst.a * (1.0 - a)) / out_a
	var g: float = (col.g * a + dst.g * dst.a * (1.0 - a)) / out_a
	var b: float = (col.b * a + dst.b * dst.a * (1.0 - a)) / out_a
	img.set_pixel(x, y, Color(r, g, b, out_a))


## Deterministic presentation-only pseudo-noise in [0,1) — NEVER Sim.rng (keeps replays clean).
func _h01(seed_val: int, i: int) -> float:
	var v: int = absi(seed_val * 1103515245 + i * 12345 + 1013904223)
	return float(v % 100003) / 100003.0
