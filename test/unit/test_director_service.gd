## test_director_service.gd — the glowup PlayerStyleProfile is now wired to CueBus (shadow mode):
## how you actually play (kills/powers/dashes) shapes the city's model of your style.
extends GutTest

const DS := preload("res://src/present/DirectorService.gd")
const SP := preload("res://glowup_2026/reference/PlayerStyleProfile.gd")


func _service():
	var d = DS.new()
	d.style = SP.new()   # bypass _ready/autoload; test the cue->style mapping directly
	return d


func test_kills_make_force_the_dominant_style() -> void:
	var d = _service()
	for i in range(6):
		d._on_cue("feed.kill", {})
	assert_eq(String(d.dominant_style()["axis"]), "force", "lethal play reads as FORCE")


func test_stealth_powers_make_stealth_dominant() -> void:
	var d = _service()
	for i in range(6):
		d._on_cue("power.cast", { "power_id": "obf_cloak" })
	assert_eq(String(d.dominant_style()["axis"]), "stealth", "cloaking reads as STEALTH")


func test_observer_is_deterministic() -> void:
	var a = _service()
	var b = _service()
	for i in range(4):
		a._on_cue("move.dash", {})
		b._on_cue("move.dash", {})
		a._on_cue("feed.spare", {})
		b._on_cue("feed.spare", {})
	assert_eq(a.style_distribution(), b.style_distribution(), "same events -> same model")
