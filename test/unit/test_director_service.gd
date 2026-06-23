## test_director_service.gd — the glowup PlayerStyleProfile is now wired to CueBus (shadow mode):
## how you actually play (kills/powers/dashes) shapes the city's model of your style.
extends GutTest

const DS := preload("res://src/present/DirectorService.gd")
const SP := preload("res://glowup_2026/reference/PlayerStyleProfile.gd")
const RG := preload("res://glowup_2026/reference/RumorGraph.gd")
const OD := preload("res://glowup_2026/reference/OpportunityDirector.gd")


func _service():
	var d = DS.new()
	d.style = SP.new()   # bypass _ready/autoload; test the cue->style mapping directly
	d.rumor = RG.new()
	d.opp = OD.new()
	d.opp.configure(d._load_templates())
	return d


func test_director_stages_a_style_aware_opportunity() -> void:
	var d = _service()
	assert_true(d.opp.templates.size() > 0, "opportunity templates loaded from the merged JSON")
	# Bias the style toward stealth, then ask the city what it would stage.
	for i in range(5):
		d.style.record_method("stealth", 0.8, "s%d" % i)
	var op: Dictionary = d.current_opportunity()
	assert_true(not op.is_empty(), "the director staged an opportunity")
	assert_true(op.has("display_name") or op.has("id"), "it is a real authored template")


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


func test_witnesses_build_the_citys_belief() -> void:
	var d = _service()
	var ev := {
		"event_id": "e1", "actor_id": "player", "district_id": "old_town",
		"visibility": 0.9, "method": "feed", "identity_key": "the_predator",
		"identity_ambiguity": 0.1, "tags": [],
	}
	for i in range(4):
		d.rumor.observe_event(ev, { "id": "npc_%d" % i, "attention": 0.7, "stress": 0.1, "fear": 0.1 }, 100)
	assert_true(d.rumor_claims() > 0, "witnesses formed claims about the predator")
	assert_true(float(d.rumor_belief().get("awareness", 0.0)) > 0.0, "the city is now aware")


func test_observer_is_deterministic() -> void:
	var a = _service()
	var b = _service()
	for i in range(4):
		a._on_cue("move.dash", {})
		b._on_cue("move.dash", {})
		a._on_cue("feed.spare", {})
		b._on_cue("feed.spare", {})
	assert_eq(a.style_distribution(), b.style_distribution(), "same events -> same model")
