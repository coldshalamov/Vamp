## ParallaxBackdrop seam — proves the distant-city parallax backdrop builds its three layers, forces
## itself behind the world (layer = -1), bakes its silhouette/sky textures without error, and handles
## the dawn.warning cue read-only (warming the sky). Runs under GUT so the CueBus autoload is present.
## (Visual subtlety is judged separately in a windowed capture — headless cannot screenshot.)
extends GutTest

const BackdropScript := preload("res://src/present/ParallaxBackdrop.gd")


func test_builds_three_layers_behind_world() -> void:
	var bg = BackdropScript.new()
	add_child_autofree(bg)   # fires _ready(): builds layers + bakes textures
	assert_eq(int(bg.layer), -1, "backdrop must sit behind the world (layer -1)")
	var layers := 0
	for c in bg.get_children():
		if c is ParallaxLayer:
			layers += 1
			# every band must tile horizontally so camera panning never reveals an edge
			assert_gt(c.motion_mirroring.x, 0.0, "each ParallaxLayer must mirror horizontally")
			assert_gt(c.get_child_count(), 0, "each layer needs a drawing child")
	assert_eq(layers, 3, "expected FAR + MID + SKY layers")


func test_dawn_cue_warms_sky_and_ignores_others() -> void:
	var bg = BackdropScript.new()
	add_child_autofree(bg)
	# unrelated cues are no-ops
	bg._on_cue("hit.connect", {"pos": Vector2.ZERO})
	assert_eq(bg._dawn, 0.0, "non-dawn cues must not change dawn state")
	# dawn.warning drives the dawn factor toward 1.0 as minutes_remaining falls
	bg._on_cue("dawn.warning", {"minutes_remaining": 0.0})
	assert_almost_eq(bg._dawn, 1.0, 0.001, "dawn at 0 minutes remaining should be full")
	# missing-key payload must not crash (defaults to 30 min -> dawn 0)
	bg._on_cue("dawn.warning", {})
	assert_eq(bg._dawn, 0.0, "absent minutes_remaining defaults to deep night")
