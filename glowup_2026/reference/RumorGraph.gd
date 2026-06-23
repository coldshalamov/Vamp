## RumorGraph.gd — deterministic claims, uncertainty, propagation, and faction belief summaries.
##
## A witness does not create omniscient truth. It creates a claim with source and confidence.
## The caller supplies perception facts and any deterministic distortion roll; this class owns no RNG.
extends RefCounted
class_name NightglassRumorGraph

const VERSION := 1
const MAX_CLAIMS_PER_HOLDER := 64
const MIN_CONFIDENCE := 0.08

var claims_by_holder: Dictionary = {}   # holder_id -> Array[Dictionary]
var next_claim_seq: int = 1


## Build zero, one, or two claims from an observed semantic event.
##
## Required event fields: event_id, actor_id, district_id, visibility, method, identity_key.
## Witness fields: id; optional attention, stress, fear, look_away, threshold_bias,
## threat_bias, loyalty_to_actor.
func observe_event(event: Dictionary, witness: Dictionary, tick: int) -> Array[Dictionary]:
	var created: Array[Dictionary] = []
	var witness_id := String(witness.get("id", ""))
	if witness_id == "":
		return created

	var visibility := clampf(float(event.get("visibility", 0.0)), 0.0, 1.0)
	var attention := clampf(float(witness.get("attention", 0.5)), 0.0, 1.0)
	var stress := clampf(float(witness.get("stress", 0.0)), 0.0, 1.0)
	var fear := clampf(float(witness.get("fear", 0.0)), 0.0, 1.0)
	var look_away := clampf(float(witness.get("look_away", 0.0)), 0.0, 1.0)
	var sensation := visibility * (0.35 + 0.65 * attention)
	sensation *= (1.0 - 0.35 * stress) * (1.0 - 0.25 * fear) * (1.0 - 0.70 * look_away)
	var threshold := clampf(0.25 + float(witness.get("threshold_bias", 0.0)), 0.05, 0.95)
	if sensation < threshold:
		return created

	var confidence := clampf(0.25 + 0.65 * sensation + float(witness.get("confidence_bias", 0.0)), MIN_CONFIDENCE, 1.0)
	var identity_ambiguity := clampf(float(event.get("identity_ambiguity", 0.0)), 0.0, 1.0)
	var identity_confidence := confidence * (1.0 - 0.70 * identity_ambiguity)
	var event_identity := String(event.get("identity_key", "unknown"))
	var believed_identity := event_identity if event_identity != "" and event_identity != "unknown" and identity_confidence >= 0.28 else "unknown"
	var valence := _event_valence(event, witness)

	var method_claim := _new_claim({
		"subject_id": String(event.get("actor_id", "unknown_actor")),
		"predicate": "used_method",
		"value": String(event.get("method", "unknown")),
		"confidence": confidence,
		"valence": valence,
		"source_id": witness_id,
		"source_chain": [witness_id],
		"origin_event_id": String(event.get("event_id", "")),
		"district_id": String(event.get("district_id", "")),
		"identity_key": believed_identity,
		"created_tick": tick,
		"last_updated_tick": tick,
		"tags": _copy_tags(event.get("tags", []), ["eyewitness"]),
	})
	add_claim(witness_id, method_claim)
	created.append(method_claim)

	if believed_identity != "unknown":
		var identity_claim := _new_claim({
			"subject_id": String(event.get("actor_id", "unknown_actor")),
			"predicate": "identity_link",
			"value": believed_identity,
			"confidence": clampf(identity_confidence, MIN_CONFIDENCE, 1.0),
			"valence": valence,
			"source_id": witness_id,
			"source_chain": [witness_id],
			"origin_event_id": String(event.get("event_id", "")),
			"district_id": String(event.get("district_id", "")),
			"identity_key": believed_identity,
			"created_tick": tick,
			"last_updated_tick": tick,
			"tags": ["eyewitness", "identity"],
		})
		add_claim(witness_id, identity_claim)
		created.append(identity_claim)

	return created


## Insert or merge a claim. Compatible independent claims increase confidence without summing past 1.
func add_claim(holder_id: String, incoming: Dictionary) -> String:
	if holder_id == "" or incoming.is_empty():
		return ""
	var holder_claims: Array = claims_by_holder.get(holder_id, [])
	var incoming_key := _claim_key(incoming)
	for existing_variant in holder_claims:
		var existing: Dictionary = existing_variant
		if _claim_key(existing) != incoming_key:
			continue
		var existing_conf := clampf(float(existing.get("confidence", 0.0)), 0.0, 1.0)
		var incoming_conf := clampf(float(incoming.get("confidence", 0.0)), 0.0, 1.0)
		var valence_distance := absf(float(existing.get("valence", 0.0)) - float(incoming.get("valence", 0.0)))
		var agreement := clampf(1.0 - valence_distance * 0.25, 0.5, 1.0)
		existing["confidence"] = clampf(1.0 - (1.0 - existing_conf) * (1.0 - incoming_conf * agreement), 0.0, 1.0)
		existing["valence"] = clampf((float(existing.get("valence", 0.0)) + float(incoming.get("valence", 0.0))) * 0.5, -1.0, 1.0)
		existing["last_updated_tick"] = maxi(int(existing.get("last_updated_tick", 0)), int(incoming.get("last_updated_tick", 0)))
		existing["source_chain"] = _merged_chain(existing.get("source_chain", []), incoming.get("source_chain", []))
		existing["tags"] = _copy_tags(existing.get("tags", []), incoming.get("tags", []))
		claims_by_holder[holder_id] = holder_claims
		return String(existing.get("claim_id", ""))

	holder_claims.append(incoming.duplicate(true))
	claims_by_holder[holder_id] = holder_claims
	_trim_holder(holder_id)
	return String(incoming.get("claim_id", ""))


## Propagate one known claim across an explicit social edge. `distortion_roll` is caller-owned,
## deterministic, and expected in [-1, 1]. Returns the propagated claim or an empty dictionary.
func propagate_claim(source_id: String, target_id: String, claim_id: String, trust: float, distortion_roll: float, tick: int) -> Dictionary:
	var source_claim := find_claim(source_id, claim_id)
	if source_claim.is_empty() or target_id == "":
		return {}
	var clean_trust := clampf((trust + 1.0) * 0.5, 0.0, 1.0)
	var distortion := clampf(distortion_roll, -1.0, 1.0) * 0.08 * (1.0 - clean_trust)
	var propagated_conf := clampf(float(source_claim.get("confidence", 0.0)) * 0.82 * (0.45 + 0.55 * clean_trust) + distortion, 0.0, 1.0)
	if propagated_conf < MIN_CONFIDENCE:
		return {}

	var propagated := _new_claim({
		"subject_id": String(source_claim.get("subject_id", "")),
		"predicate": String(source_claim.get("predicate", "")),
		"value": String(source_claim.get("value", "")),
		"confidence": propagated_conf,
		"valence": clampf(float(source_claim.get("valence", 0.0)) + distortion * 0.5, -1.0, 1.0),
		"source_id": source_id,
		"source_chain": _merged_chain(source_claim.get("source_chain", []), [source_id]),
		"origin_event_id": String(source_claim.get("origin_event_id", "")),
		"district_id": String(source_claim.get("district_id", "")),
		"identity_key": String(source_claim.get("identity_key", "unknown")),
		"created_tick": tick,
		"last_updated_tick": tick,
		"tags": _copy_tags(source_claim.get("tags", []), ["hearsay"]),
	})
	add_claim(target_id, propagated)
	return propagated


func find_claim(holder_id: String, claim_id: String) -> Dictionary:
	var holder_claims: Array = claims_by_holder.get(holder_id, [])
	for claim_variant in holder_claims:
		var claim: Dictionary = claim_variant
		if String(claim.get("claim_id", "")) == claim_id:
			return claim
	return {}


## Caller chooses cadence. `amount` is confidence removed per invocation, not wall-clock time.
func decay(amount: float, tick: int) -> void:
	var clean_amount := maxf(0.0, amount)
	var empty_holders: Array[String] = []
	for holder_key in claims_by_holder:
		var holder_id := String(holder_key)
		var holder_claims: Array = claims_by_holder[holder_id]
		for i in range(holder_claims.size() - 1, -1, -1):
			var claim: Dictionary = holder_claims[i]
			claim["confidence"] = clampf(float(claim.get("confidence", 0.0)) - clean_amount, 0.0, 1.0)
			claim["last_updated_tick"] = tick
			if float(claim["confidence"]) < MIN_CONFIDENCE:
				holder_claims.remove_at(i)
		claims_by_holder[holder_id] = holder_claims
		if holder_claims.is_empty():
			empty_holders.append(holder_id)
	for holder_id in empty_holders:
		claims_by_holder.erase(holder_id)


## Aggregate only claims held by the explicitly supplied faction members.
func faction_summary(holder_ids: Array) -> Dictionary:
	var trust_sum := 0.0
	var fear_sum := 0.0
	var awareness_sum := 0.0
	var weight_sum := 0.0
	for holder_variant in holder_ids:
		var holder_id := String(holder_variant)
		var holder_claims: Array = claims_by_holder.get(holder_id, [])
		for claim_variant in holder_claims:
			var claim: Dictionary = claim_variant
			var source_weight := 1.0 if _has_tag(claim.get("tags", []), "eyewitness") else 0.65
			var weight := clampf(float(claim.get("confidence", 0.0)), 0.0, 1.0) * source_weight
			var valence := clampf(float(claim.get("valence", 0.0)), -1.0, 1.0)
			awareness_sum += weight
			if valence < 0.0:
				fear_sum += weight * -valence
			else:
				trust_sum += weight * valence
			weight_sum += weight
	if weight_sum <= 0.000001:
		return { "trust": 0.0, "fear": 0.0, "awareness": 0.0 }
	return {
		"trust": clampf(trust_sum / weight_sum, 0.0, 1.0),
		"fear": clampf(fear_sum / weight_sum, 0.0, 1.0),
		"awareness": clampf(awareness_sum / maxf(1.0, float(holder_ids.size())), 0.0, 1.0),
	}


func serialize() -> Dictionary:
	return {
		"version": VERSION,
		"next_claim_seq": next_claim_seq,
		"claims_by_holder": claims_by_holder.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	claims_by_holder.clear()
	next_claim_seq = 1
	if data.is_empty():
		return
	next_claim_seq = maxi(1, int(data.get("next_claim_seq", 1)))
	var raw_holders: Dictionary = data.get("claims_by_holder", {})
	for holder_key in raw_holders:
		var holder_id := String(holder_key)
		if holder_id == "" or not (raw_holders[holder_key] is Array):
			continue
		var cleaned: Array[Dictionary] = []
		for claim_variant in raw_holders[holder_key]:
			if claim_variant is Dictionary:
				var claim: Dictionary = (claim_variant as Dictionary).duplicate(true)
				claim["confidence"] = clampf(float(claim.get("confidence", 0.0)), 0.0, 1.0)
				if float(claim["confidence"]) >= MIN_CONFIDENCE:
					cleaned.append(claim)
		if not cleaned.is_empty():
			claims_by_holder[holder_id] = cleaned
			_trim_holder(holder_id)


func state_hash() -> int:
	var h := hash([VERSION, next_claim_seq])
	var holders := claims_by_holder.keys()
	holders.sort()
	for holder_key in holders:
		var holder_id := String(holder_key)
		h = hash([h, holder_id])
		var holder_claims: Array = claims_by_holder[holder_id]
		var sorted_claims := holder_claims.duplicate(true)
		sorted_claims.sort_custom(func(a, b) -> bool:
			return String((a as Dictionary).get("claim_id", "")) < String((b as Dictionary).get("claim_id", ""))
		)
		for claim_variant in sorted_claims:
			var claim: Dictionary = claim_variant
			h = hash([h,
				String(claim.get("claim_id", "")), String(claim.get("subject_id", "")),
				String(claim.get("predicate", "")), String(claim.get("value", "")),
				snapped(float(claim.get("confidence", 0.0)), 0.0001),
				snapped(float(claim.get("valence", 0.0)), 0.0001),
				String(claim.get("source_id", "")), String(claim.get("origin_event_id", "")),
				String(claim.get("district_id", "")), String(claim.get("identity_key", "")),
				int(claim.get("created_tick", 0)), int(claim.get("last_updated_tick", 0))])
	return h


func _new_claim(fields: Dictionary) -> Dictionary:
	var claim := fields.duplicate(true)
	claim["claim_id"] = "ng_claim_%08d" % next_claim_seq
	next_claim_seq += 1
	return claim


func _event_valence(event: Dictionary, witness: Dictionary) -> float:
	var base := 0.0
	var tags = event.get("tags", [])
	if _has_tag(tags, "protective") or _has_tag(tags, "rescue"):
		base += 0.35
	if _has_tag(tags, "lethal"):
		base -= 0.35
	if _has_tag(tags, "collateral"):
		base -= 0.40
	if _has_tag(tags, "mercy"):
		base += 0.18
	base += 0.35 * clampf(float(witness.get("loyalty_to_actor", 0.0)), -1.0, 1.0)
	base -= 0.20 * clampf(float(witness.get("threat_bias", 0.5)), 0.0, 1.0)
	return clampf(base, -1.0, 1.0)


func _claim_key(claim: Dictionary) -> Array:
	return [
		String(claim.get("subject_id", "")),
		String(claim.get("predicate", "")),
		String(claim.get("value", "")),
		String(claim.get("district_id", "")),
		String(claim.get("identity_key", "unknown")),
	]


func _trim_holder(holder_id: String) -> void:
	var holder_claims: Array = claims_by_holder.get(holder_id, [])
	while holder_claims.size() > MAX_CLAIMS_PER_HOLDER:
		var weakest_index := 0
		for i in range(1, holder_claims.size()):
			var candidate: Dictionary = holder_claims[i]
			var weakest: Dictionary = holder_claims[weakest_index]
			if float(candidate.get("confidence", 0.0)) < float(weakest.get("confidence", 0.0)):
				weakest_index = i
			elif is_equal_approx(float(candidate.get("confidence", 0.0)), float(weakest.get("confidence", 0.0))) and int(candidate.get("created_tick", 0)) < int(weakest.get("created_tick", 0)):
				weakest_index = i
		holder_claims.remove_at(weakest_index)
	claims_by_holder[holder_id] = holder_claims


func _copy_tags(first, second) -> Array[String]:
	var out: Array[String] = []
	if first is Array:
		for item in first:
			var tag := String(item)
			if tag != "" and not out.has(tag):
				out.append(tag)
	if second is Array:
		for item in second:
			var tag := String(item)
			if tag != "" and not out.has(tag):
				out.append(tag)
	out.sort()
	return out


func _merged_chain(first, second) -> Array[String]:
	var out := _copy_tags(first, second)
	while out.size() > 8:
		out.pop_front()
	return out


func _has_tag(tags, wanted: String) -> bool:
	if not (tags is Array):
		return false
	for item in tags:
		if String(item) == wanted:
			return true
	return false