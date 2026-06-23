## test_glowup_hidden_game.gd — deterministic contract tests for the 2026 reference systems.
extends GutTest

const StyleProfile := preload("res://glowup_2026/reference/PlayerStyleProfile.gd")
const RumorGraph := preload("res://glowup_2026/reference/RumorGraph.gd")
const OpportunityDirector := preload("res://glowup_2026/reference/OpportunityDirector.gd")


func test_style_profile_infers_practiced_resolution_not_button_count() -> void:
	var profile = StyleProfile.new()
	for i in range(24):
		profile.record({ "stealth": 0.8, "systems": 0.2 }, 0.82, "stealth.route.%d" % (i % 6))
	# Low-intensity spam is below the meaningful floor and contributes nothing.
	for i in range(100):
		profile.record({ "force": 1.0 }, 0.01, "attack.button")
	var dominant: Dictionary = profile.dominant()
	assert_eq(String(dominant["axis"]), "stealth")
	assert_gt(float(dominant["share"]), 0.70)
	assert_lt(profile.entropy(), 0.55)


func test_style_profile_round_trips_with_identical_hash() -> void:
	var source = StyleProfile.new()
	source.record({ "force": 0.55, "mobility": 0.45 }, 0.9, "vehicle.impact.escape")
	source.record({ "influence": 1.0 }, 0.7, "witness.recruited")
	var restored = StyleProfile.new()
	restored.restore(source.serialize())
	assert_eq(restored.state_hash(), source.state_hash())
	assert_eq(restored.normalized(), source.normalized())


func test_ambiguous_witness_creates_event_claim_without_true_identity_link() -> void:
	var graph = RumorGraph.new()
	var event := {
		"event_id": "evt_masked",
		"actor_id": "player",
		"district_id": "red_row",
		"visibility": 0.92,
		"method": "systems",
		"identity_key": "night_courier",
		"identity_ambiguity": 1.0,
		"tags": ["power", "nonlethal"],
	}
	var witness := { "id": "witness_1", "attention": 0.9, "stress": 0.1, "fear": 0.1 }
	var claims: Array[Dictionary] = graph.observe_event(event, witness, 120)
	assert_gt(claims.size(), 0)
	for claim in claims:
		assert_ne(String(claim.get("predicate", "")), "identity_link")
		assert_eq(String(claim.get("identity_key", "")), "unknown")


func test_duplicate_observations_merge_instead_of_multiplying_claims() -> void:
	var graph = RumorGraph.new()
	var event := {
		"event_id": "evt_visible",
		"actor_id": "player",
		"district_id": "old_town",
		"visibility": 1.0,
		"method": "force",
		"identity_key": "red_coat",
		"identity_ambiguity": 0.0,
		"tags": ["lethal"],
	}
	var witness := { "id": "witness_2", "attention": 1.0 }
	graph.observe_event(event, witness, 10)
	var before := (graph.claims_by_holder["witness_2"] as Array).size()
	graph.observe_event(event, witness, 11)
	var after := (graph.claims_by_holder["witness_2"] as Array).size()
	assert_eq(after, before)
	assert_eq(after, 2, "one method claim + one identity-link claim")


func test_rumor_graph_round_trip_is_hash_identical() -> void:
	var graph = RumorGraph.new()
	graph.observe_event({
		"event_id": "evt_mercy", "actor_id": "player", "district_id": "docks",
		"visibility": 0.8, "method": "influence", "identity_key": "red_coat",
		"tags": ["mercy", "protective"]
	}, { "id": "source", "attention": 0.8 }, 42)
	var source_claims: Array = graph.claims_by_holder["source"]
	var claim_id := String((source_claims[0] as Dictionary)["claim_id"])
	var propagated := graph.propagate_claim("source", "target", claim_id, 0.5, -0.2, 43)
	assert_false(propagated.is_empty())
	var restored = RumorGraph.new()
	restored.restore(graph.serialize())
	assert_eq(restored.state_hash(), graph.state_hash())


func test_opportunity_choice_is_deterministic_for_sorted_context_and_rolls() -> void:
	var templates := [
		{
			"id": "support_stealth", "required_tags": ["route"], "forbidden_tags": [],
			"resolution_methods": ["stealth", "systems"], "pressure_relief": { "exposure": 0.4 },
			"base_difficulty": 0.45, "authored_priority": 0.7, "counter_strength": 0.0,
			"cooldown_ticks": 20
		},
		{
			"id": "force_counter", "required_tags": ["route"], "forbidden_tags": [],
			"resolution_methods": ["force"], "pressure_relief": { "heat": 0.2 },
			"base_difficulty": 0.55, "authored_priority": 0.5, "counter_strength": 0.6,
			"cooldown_ticks": 20
		}
	]
	var context := _director_context()
	var style := { "force": 0.05, "stealth": 0.72, "influence": 0.05, "mobility": 0.05, "systems": 0.13 }
	var first = OpportunityDirector.new()
	first.configure(templates)
	var second = OpportunityDirector.new()
	second.configure(templates)
	var pick_a: Dictionary = first.choose(context, style, 0.37, 0.61, 7)
	var pick_b: Dictionary = second.choose(context, style, 0.37, 0.61, 7)
	assert_eq(pick_a, pick_b)
	assert_false((pick_a["selected"] as Dictionary).is_empty())
	assert_true((pick_a["selected"] as Dictionary).has("score_breakdown"))


func test_opportunity_director_blocks_consecutive_hard_counters() -> void:
	var director = OpportunityDirector.new()
	director.configure([{
		"id": "hard_counter", "required_tags": ["route"], "forbidden_tags": [],
		"resolution_methods": ["force"], "pressure_relief": {}, "base_difficulty": 0.5,
		"authored_priority": 0.5, "counter_strength": 0.85, "cooldown_ticks": 1
	}])
	director.mark_used("previous_hard_counter", 99, 0.9)
	var evaluated: Dictionary = director.score_candidates(_director_context(), {
		"force": 0.0, "stealth": 0.9, "influence": 0.05, "mobility": 0.03, "systems": 0.02
	})
	assert_true((evaluated["candidates"] as Array).is_empty())
	var reasons: Array = evaluated["rejected"]
	assert_true(reasons.any(func(item) -> bool:
		return String((item as Dictionary).get("reason", "")) == "hard_counter_streak"
	))


func _director_context() -> Dictionary:
	return {
		"tick": 100,
		"player_district": "old_town",
		"resolved_opportunities": 2,
		"districts": {
			"old_town": {
				"tags": ["route", "records"],
				"adjacent": ["docks"],
				"faction_control": { "camarilla": 0.6, "anarch": 0.2 }
			},
			"docks": {
				"tags": ["route", "vehicle_routes"],
				"adjacent": ["old_town"],
				"faction_control": { "anarch": 0.5, "camarilla": 0.1 }
			}
		},
		"factions": {
			"camarilla": { "resources": 0.8, "agenda_pressure": 0.6 },
			"anarch": { "resources": 0.5, "agenda_pressure": 0.8 }
		},
		"relationships": { "camarilla": 0.1, "anarch": 0.4 },
		"resources": { "condition": 0.85, "leverage": 0.45 },
		"pressure": {
			"exposure": 0.7, "heat": 0.4, "need": 0.2, "injury": 0.1,
			"debt": 0.3, "anomaly": 0.2, "volatility": 0.5
		}
	}
