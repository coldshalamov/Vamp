## process_sprites.gd — chroma-key + autocrop + downscale tool (NOT a gameplay file).
##
## Converts the magenta-background sprites grok generates in assets/sprites/gen/ into clean
## transparent game-ready PNGs in assets/sprites/. Keys out #FF00FF, despills the fringe,
## crops to content, and caps the long edge at 256px.
## LOCAL WINDOWS SAFETY: do not run raw Godot scripts on this machine without explicit user approval.
extends SceneTree

const GEN_DIR := "res://assets/sprites/gen/"
const OUT_DIR := "res://assets/sprites/"
const MAX_EDGE := 256


func _init() -> void:
	var d := DirAccess.open(GEN_DIR)
	if d == null:
		print("[SPRITES] no gen dir")
		quit()
		return
	var count := 0
	for f in d.get_files():
		if not f.to_lower().ends_with(".png"):
			continue
		var img := Image.new()
		if img.load(GEN_DIR + f) != OK:
			print("[SPRITES] failed to load ", f)
			continue
		img.convert(Image.FORMAT_RGBA8)
		_key_magenta(img)
		img = _autocrop(img)
		if img == null:
			print("[SPRITES] ", f, " fully keyed away (skipped)")
			continue
		_downscale(img)
		var out_name := f.replace("_topdown", "")
		var out_path := ProjectSettings.globalize_path(OUT_DIR + out_name)
		var err := img.save_png(out_path)
		print("[SPRITES] %s -> %s (%dx%d) err=%d" % [f, out_name, img.get_width(), img.get_height(), err])
		count += 1
	print("[SPRITES] processed ", count, " sprites")
	quit()


## Remove magenta background with a soft edge + despill, in place.
func _key_magenta(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			# Distance to pure magenta (1,0,1). Dark coats are far; bg/fringe is near.
			var dist := Vector3(c.r - 1.0, c.g - 0.0, c.b - 1.0).length()
			if dist < 0.30:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif dist < 0.62:
				# Fringe: ramp alpha and despill (pull magenta tint toward green channel).
				var a := (dist - 0.30) / 0.32
				var g := c.g
				var r := minf(c.r, g + 0.25)
				var b := minf(c.b, g + 0.25)
				img.set_pixel(x, y, Color(r, g, b, a))


## Crop to the bounding box of non-transparent pixels (+ small pad). Returns null if empty.
func _autocrop(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.12:
				minx = mini(minx, x)
				miny = mini(miny, y)
				maxx = maxi(maxx, x)
				maxy = maxi(maxy, y)
	if maxx < 0:
		return null
	var pad := 6
	minx = maxi(0, minx - pad)
	miny = maxi(0, miny - pad)
	maxx = mini(w - 1, maxx + pad)
	maxy = mini(h - 1, maxy + pad)
	return img.get_region(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))


func _downscale(img: Image) -> void:
	var maxd := maxi(img.get_width(), img.get_height())
	if maxd <= MAX_EDGE:
		return
	var s := float(MAX_EDGE) / float(maxd)
	img.resize(int(img.get_width() * s), int(img.get_height() * s), Image.INTERPOLATE_LANCZOS)
