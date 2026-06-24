## SpellFX seam — proves the archetype-driven spell renderer handles every archetype, stays bounded
## (freeze-safe ring buffer), ages/culls cleanly, and ignores unrelated cues. (Pixel distinctness is
## verified separately in a windowed CapturePlay session — headless cannot screenshot.)
extends GutTest

const SpellFXScript := preload("res://src/present/SpellFX.gd")
const ARCHES := ["PROJECTILE", "NOVA", "GROUND_AOE", "CONE", "ENTITY_TARGET", "DEBUFF", "DASH", "TETHER", "SELF_BUFF"]


func test_handles_all_archetypes_and_stays_bounded() -> void:
	var fx = SpellFXScript.new()
	for i in range(60):
		fx._on_cue("power.cast", {
			"archetype": ARCHES[i % ARCHES.size()],
			"origin": Vector2(100, 100),
			"target_pos": Vector2(220, 150),
			"color": "#e0203f",
			"range": 300.0, "radius": 80.0, "arc": 1.2, "aim_dir": 0.3,
		})
	assert_true(fx._fx.size() <= 32, "SpellFX must ring-buffer (cap 32), got %d" % fx._fx.size())
	# advance ~2s of frames: every effect should age out without error
	for _s in range(120):
		fx._process(1.0 / 60.0)
	assert_eq(fx._fx.size(), 0, "all effects should expire")
	fx.free()


func test_ignores_unrelated_cues() -> void:
	var fx = SpellFXScript.new()
	fx._on_cue("damage.dealt", { "pos": Vector2.ZERO })
	fx._on_cue("feed.start", {})
	assert_eq(fx._fx.size(), 0, "SpellFX should only react to power.cast")
	fx.free()
