## OpportunityDirector.gd — deterministic authored-opportunity selection.
##
## The director arranges existing game systems around pressure, faction agenda, geography,
## novelty, relationships, resources, and the player's practiced style. It owns no RNG: the
## caller passes sorted-world context and explicit rolls from Sim.draw_float().
extends RefCounted
class_name NightglassOpportunityDirector

const VERSION := 1
const METHODS: Array[String] = ["force", "stealth", "influence", "mobility", "systems"]

const DEFAULT_WEIGHTS := {
	"pressure_relevance": 0.22,
	"faction_agenda": 0.18,
	"novelty": 0.16,
	"style_support": 0.12,
	"counterpoint": 0.08,
	"geography": 0.08,
	"relationship": 0.08,
	"resource_fit": 0.05,
	"authored_priority": 0.03,
}

var templates: Array[Dictionary] = []
var recent_template_ticks: Dictionary = {}
var recent_counter_strengths: Array[float] = []
var temperature: float = 0.18
var weights: Dictionary = DEFAULT_WEIGHTS.duplicate(true)


func configure(new_templates: Array) -> void:
	templates.clear()
	for item in new_templates:
		if not (item is Dictionary):
			continue
		var rec: Dictionary = (item as Dictionary).duplicate(true)
		var id := String(rec.get("id", ""))
		if id == "":
			continue
		rec["id"] = id
		templates.append(rec)
	templates.sort_custom(func(a, b) -> bool:
		return String((a as Dictionary).get("id", "")) < String((b as Dictionary).get("id", ""))
	)


## Context contract:
## tick, player_district, districts, factions, relationships, resources, pressure.
## District: tags, adjacent, faction_control. Faction: resources, agenda_pressure.
## Style is a normalized axis dictionary from PlayerStyleProfile.normalized().
func score_candidates(context: Dictionary, style: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	var tick := int(context.get("tick", 0))
	var districts: Dictionary = context.get("districts", {})
	var district_ids := districts.keys()
	district_ids.sort()

	for template in templates:
		var template_id := String(template.get("id", ""))
		var counter_strength := clampf(float(template.get("counter_strength", 0.0)), 0.0, 1.0)
		if counter_strength >= 0.75 and _last_counter_strength() >= 0.75:
			rejected.append({ "template_id": template_id, "reason": "hard_counter_streak" })
			continue

		var cooldown_ticks := maxi(1, int(template.get("cooldown_ticks", 20)))
		var last_tick := int(recent_template_ticks.get(template_id, -1000000000))
		var elapsed := tick - last_tick
		if elapsed < cooldown_ticks:
			rejected.append({ "template_id": template_id, "reason": "cooldown", "remaining": cooldown_ticks - elapsed })
			continue

		for district_key in district_ids:
			var district_id := String(district_key)
			var district: Dictionary = districts[district_key]
			var district_tags: Array = district.get("tags", [])
			if not _contains_all_tags(district_tags, template.get("required_tags", [])):
				rejected.append({ "template_id": template_id, "district_id": district_id, "reason": "missing_required_tags" })
				continue
			if _intersects_tags(district_tags, template.get("forbidden_tags", [])):
				rejected.append({ "template_id": template_id, "district_id": district_id, "reason": "forbidden_tag" })
				continue

			var faction_pick := _best_faction(context, district)
			var faction_id := String(faction_pick.get("id", ""))
			if faction_id == "":
				rejected.append({ "template_id": template_id, "district_id": district_id, "reason": "no_faction" })
				continue

			var novelty := clampf(float(elapsed) / float(cooldown_ticks), 0.0, 1.0)
			novelty = 0.35 + 0.65 * novelty
			var methods: Array = template.get("resolution_methods", [])
			var breakdown := {
				"pressure_relevance": _pressure_relevance(context.get("pressure", {}), template.get("pressure_relief", {})),
				"faction_agenda": clampf(0.70 * float(faction_pick.get("agenda", 0.0)) + 0.30 * float(faction_pick.get("fit", 0.0)), 0.0, 1.0),
				"novelty": novelty,
				"style_support": _style_support(style, methods),
				"counterpoint": minf(counter_strength, _counterpoint(style, methods)),
				"geography": _geography(context, district_id),
				"relationship": clampf((float((context.get("relationships", {}) as Dictionary).get(faction_id, 0.0)) + 1.0) * 0.5, 0.0, 1.0),
				"resource_fit": _resource_fit(context.get("resources", {}), methods),
				"authored_priority": clampf(float(template.get("authored_priority", 0.5)), 0.0, 1.0),
			}
			var score := 0.0
			for key in DEFAULT_WEIGHTS:
				score += float(weights.get(key, DEFAULT_WEIGHTS[key])) * float(breakdown.get(key, 0.0))

			var base_difficulty := clampf(float(template.get("base_difficulty", 0.5)), 0.0, 1.0)
			var desired_difficulty := _desired_difficulty(context)
			score *= 0.70 + 0.30 * (1.0 - absf(base_difficulty - desired_difficulty))
			candidates.append({
				"template_id": template_id,
				"district_id": district_id,
				"faction_id": faction_id,
				"score": maxf(0.0, score),
				"score_breakdown": breakdown,
				"base_difficulty": base_difficulty,
				"counter_strength": counter_strength,
			})

	candidates.sort_custom(func(a, b) -> bool:
		var aa: Dictionary = a
		var bb: Dictionary = b
		return _candidate_key(aa) < _candidate_key(bb)
	)
	return { "candidates": candidates, "rejected": rejected }


## Two caller-owned rolls preserve deterministic stream partitioning.
func choose(context: Dictionary, style: Dictionary, selection_roll: float, difficulty_roll: float, instance_salt: int = 0) -> Dictionary:
	var evaluated := score_candidates(context, style)
	var candidates: Array = evaluated.get("candidates", [])
	if candidates.is_empty():
		return { "selected": {}, "rejected": evaluated.get("rejected", []) }

	var max_score := 0.0
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		max_score = maxf(max_score, float(candidate.get("score", 0.0)))
	var candidate_weights: Array[float] = []
	var total_weight := 0.0
	var clean_temperature := maxf(0.02, temperature)
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		var w := exp((float(candidate.get("score", 0.0)) - max_score) / clean_temperature)
		candidate_weights.append(w)
		total_weight += w

	var point := clampf(selection_roll, 0.0, 0.999999) * total_weight
	var cumulative := 0.0
	var selected: Dictionary = candidates.back()
	for i in range(candidates.size()):
		cumulative += candidate_weights[i]
		if point <= cumulative:
			selected = candidates[i]
			break

	var pressure_load := _pressure_load(context.get("pressure", {}))
	var difficulty_jitter := (clampf(difficulty_roll, 0.0, 1.0) * 2.0 - 1.0) * 0.06
	var difficulty := clampf(float(selected.get("base_difficulty", 0.5)) + difficulty_jitter + 0.08 * pressure_load, 0.0, 1.0)
	var tick := int(context.get("tick", 0))
	var instance_hash: int = absi(hash([String(selected.get("template_id", "")), tick, instance_salt,
		String(selected.get("district_id", "")), String(selected.get("faction_id", ""))]))
	var instance := selected.duplicate(true)
	instance["instance_id"] = "ng_opp_%016x" % instance_hash
	instance["selected_tick"] = tick
	instance["difficulty"] = difficulty
	return { "selected": instance, "rejected": evaluated.get("rejected", []) }


func mark_used(template_id: String, tick: int, counter_strength: float = 0.0) -> void:
	if template_id != "":
		recent_template_ticks[template_id] = tick
	recent_counter_strengths.append(clampf(counter_strength, 0.0, 1.0))
	while recent_counter_strengths.size() > 3:
		recent_counter_strengths.pop_front()


func serialize() -> Dictionary:
	return {
		"version": VERSION,
		"recent_template_ticks": recent_template_ticks.duplicate(true),
		"recent_counter_strengths": recent_counter_strengths.duplicate(),
		"temperature": temperature,
		"weights": weights.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	recent_template_ticks.clear()
	recent_counter_strengths.clear()
	weights = DEFAULT_WEIGHTS.duplicate(true)
	temperature = 0.18
	if data.is_empty():
		return
	var raw_recent: Dictionary = data.get("recent_template_ticks", {})
	for key in raw_recent:
		recent_template_ticks[String(key)] = int(raw_recent[key])
	var raw_counters: Array = data.get("recent_counter_strengths", [])
	for item in raw_counters:
		recent_counter_strengths.append(clampf(float(item), 0.0, 1.0))
	while recent_counter_strengths.size() > 3:
		recent_counter_strengths.pop_front()
	temperature = clampf(float(data.get("temperature", temperature)), 0.02, 1.0)
	var raw_weights: Dictionary = data.get("weights", {})
	for key in DEFAULT_WEIGHTS:
		weights[key] = maxf(0.0, float(raw_weights.get(key, DEFAULT_WEIGHTS[key])))


func state_hash() -> int:
	var h := hash([VERSION, snapped(temperature, 0.0001)])
	var recent_keys := recent_template_ticks.keys()
	recent_keys.sort()
	for key in recent_keys:
		h = hash([h, String(key), int(recent_template_ticks[key])])
	for value in recent_counter_strengths:
		h = hash([h, snapped(value, 0.0001)])
	for key in DEFAULT_WEIGHTS:
		h = hash([h, key, snapped(float(weights.get(key, 0.0)), 0.0001)])
	return h


func _best_faction(context: Dictionary, district: Dictionary) -> Dictionary:
	var factions: Dictionary = context.get("factions", {})
	var controls: Dictionary = district.get("faction_control", {})
	var faction_ids := factions.keys()
	faction_ids.sort()
	var best := { "id": "", "fit": -1.0, "agenda": 0.0 }
	for faction_key in faction_ids:
		var faction_id := String(faction_key)
		var faction: Dictionary = factions[faction_key]
		var control := clampf(float(controls.get(faction_id, 0.0)), 0.0, 1.0)
		var resources := clampf(float(faction.get("resources", 0.5)), 0.0, 1.0)
		var agenda := clampf(float(faction.get("agenda_pressure", 0.5)), 0.0, 1.0)
		var fit := 0.45 * control + 0.35 * resources + 0.20 * agenda
		if fit > float(best["fit"]):
			best = { "id": faction_id, "fit": fit, "agenda": agenda }
	return best


func _pressure_relevance(pressure_variant, relief_variant) -> float:
	if not (pressure_variant is Dictionary) or not (relief_variant is Dictionary):
		return 0.25
	var pressure: Dictionary = pressure_variant
	var relief: Dictionary = relief_variant
	var weighted := 0.0
	var total := 0.0
	for channel in relief:
		var w := maxf(0.0, float(relief[channel]))
		weighted += clampf(float(pressure.get(channel, 0.0)), 0.0, 1.0) * w
		total += w
	return clampf(weighted / total, 0.0, 1.0) if total > 0.000001 else 0.25


func _style_support(style: Dictionary, methods: Array) -> float:
	var fit := 0.0
	for method_variant in methods:
		fit += maxf(0.0, float(style.get(String(method_variant), 0.0)))
	return clampf(fit, 0.0, 1.0)


func _counterpoint(style: Dictionary, methods: Array) -> float:
	var dominant_axis := METHODS[0]
	var dominant_share := -1.0
	for axis in METHODS:
		var share := float(style.get(axis, 0.0))
		if share > dominant_share:
			dominant_share = share
			dominant_axis = axis
	if methods.has(dominant_axis):
		return 0.0
	return clampf(dominant_share - 0.35, 0.0, 0.45)


func _geography(context: Dictionary, district_id: String) -> float:
	var player_district := String(context.get("player_district", ""))
	if district_id == player_district:
		return 1.0
	var districts: Dictionary = context.get("districts", {})
	if districts.has(player_district):
		var current: Dictionary = districts[player_district]
		var adjacent: Array = current.get("adjacent", [])
		if adjacent.has(district_id):
			return 0.72
	return 0.35


func _resource_fit(resources_variant, methods: Array) -> float:
	if not (resources_variant is Dictionary):
		return 0.5
	var resources: Dictionary = resources_variant
	var condition := clampf(float(resources.get("condition", 1.0)), 0.0, 1.0)
	var leverage := clampf(float(resources.get("leverage", 0.0)), 0.0, 1.0)
	var recovery_routes := 0.0
	if methods.has("influence"):
		recovery_routes += 0.40 * leverage
	if methods.has("stealth"):
		recovery_routes += 0.30
	return clampf(0.35 + 0.40 * condition + recovery_routes, 0.0, 1.0)


func _desired_difficulty(context: Dictionary) -> float:
	var resolved := maxf(0.0, float(context.get("resolved_opportunities", 0)))
	return clampf(0.42 + 0.18 * resolved / 20.0 - 0.12 * _pressure_load(context.get("pressure", {})), 0.0, 1.0)


func _pressure_load(pressure_variant) -> float:
	if not (pressure_variant is Dictionary):
		return 0.0
	var pressure: Dictionary = pressure_variant
	var channels: Array[String] = ["exposure", "heat", "need", "injury", "debt", "anomaly", "volatility"]
	var total := 0.0
	for channel in channels:
		total += clampf(float(pressure.get(channel, 0.0)), 0.0, 1.0)
	return total / float(channels.size())


func _contains_all_tags(haystack_variant, required_variant) -> bool:
	if not (required_variant is Array):
		return true
	if not (haystack_variant is Array):
		return (required_variant as Array).is_empty()
	var haystack: Array = haystack_variant
	for tag in required_variant:
		if not haystack.has(String(tag)):
			return false
	return true


func _intersects_tags(first_variant, second_variant) -> bool:
	if not (first_variant is Array) or not (second_variant is Array):
		return false
	var first: Array = first_variant
	for tag in second_variant:
		if first.has(String(tag)):
			return true
	return false


func _candidate_key(candidate: Dictionary) -> String:
	return "%s|%s|%s" % [String(candidate.get("template_id", "")), String(candidate.get("district_id", "")), String(candidate.get("faction_id", ""))]


func _last_counter_strength() -> float:
	return recent_counter_strengths.back() if not recent_counter_strengths.is_empty() else 0.0