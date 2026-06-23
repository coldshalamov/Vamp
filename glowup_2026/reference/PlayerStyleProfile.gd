## PlayerStyleProfile.gd — deterministic inference of how the player actually solves risk.
##
## This is an authoritative reference asset: no scene tree, wall clock, input polling, or internal RNG.
## Record completed semantic resolutions, never raw button presses. The caller owns event ordering.
extends RefCounted
class_name NightglassPlayerStyleProfile

const AXES: Array[String] = ["force", "stealth", "influence", "mobility", "systems"]
const VERSION := 1
const MAX_REPEAT_KEYS := 64

var values: Dictionary = {}
var repeat_memory: Dictionary = {}
var repeat_order: Array[String] = []
var meaningful_events: int = 0

## Applied once per meaningful event. High enough to remember a night, low enough to change over a run.
var event_decay: float = 0.985
## Repeating an identical resolution key contributes less; this prevents attack/button farming.
var repeat_penalty: float = 0.72
var meaningful_floor: float = 0.06


func _init() -> void:
	_reset_values()


func _reset_values() -> void:
	values.clear()
	for axis in AXES:
		values[axis] = 0.0
	repeat_memory.clear()
	repeat_order.clear()
	meaningful_events = 0


## `weights` may split one resolution across axes, e.g. an environmental ambush can be
## {"systems": 0.6, "stealth": 0.4}. `novelty_key` should describe the resolved pattern,
## not the input: "feed.spare.phlegmatic", "combat.flank.shield", "heat.escape.vehicle".
func record(weights: Dictionary, intensity: float = 1.0, novelty_key: String = "") -> bool:
	for axis in AXES:
		values[axis] = float(values.get(axis, 0.0)) * event_decay

	var positive_total := 0.0
	for axis in AXES:
		positive_total += maxf(0.0, float(weights.get(axis, 0.0)))
	var magnitude := clampf(intensity, 0.0, 1.0)
	if positive_total <= 0.000001 or magnitude < meaningful_floor:
		_decay_repeat_memory(novelty_key)
		return false

	var novelty_multiplier := 1.0
	if novelty_key != "":
		var repeats := int(repeat_memory.get(novelty_key, 0))
		novelty_multiplier = pow(repeat_penalty, mini(repeats, 6))
		_remember_repeat(novelty_key, repeats + 1)

	for axis in AXES:
		var raw := maxf(0.0, float(weights.get(axis, 0.0)))
		if raw > 0.0:
			values[axis] = float(values.get(axis, 0.0)) + magnitude * novelty_multiplier * raw / positive_total

	meaningful_events += 1
	_decay_repeat_memory(novelty_key)
	return true


## Convenience mapping for the first integration pass. Content-specific events should pass
## explicit weights instead of extending this forever.
func record_method(method: String, intensity: float, novelty_key: String = "") -> bool:
	if not AXES.has(method):
		return false
	return record({ method: 1.0 }, intensity, novelty_key)


func normalized() -> Dictionary:
	var out: Dictionary = {}
	var total := 0.0
	for axis in AXES:
		total += maxf(0.0, float(values.get(axis, 0.0)))
	if total <= 0.000001:
		for axis in AXES:
			out[axis] = 1.0 / float(AXES.size())
		return out
	for axis in AXES:
		out[axis] = maxf(0.0, float(values.get(axis, 0.0))) / total
	return out


## 0 = highly specialized, 1 = evenly hybridized across all axes.
func entropy() -> float:
	var distribution := normalized()
	var h := 0.0
	for axis in AXES:
		var p := float(distribution.get(axis, 0.0))
		if p > 0.000001:
			h -= p * log(p)
	return clampf(h / log(float(AXES.size())), 0.0, 1.0)


func dominant() -> Dictionary:
	var distribution := normalized()
	var best_axis := AXES[0]
	var best_share := -1.0
	for axis in AXES:
		var share := float(distribution.get(axis, 0.0))
		if share > best_share:
			best_share = share
			best_axis = axis
	return { "axis": best_axis, "share": best_share, "entropy": entropy() }


func support_fit(methods: Array) -> float:
	var distribution := normalized()
	var fit := 0.0
	for method in methods:
		fit += float(distribution.get(String(method), 0.0))
	return clampf(fit, 0.0, 1.0)


## Gentle counterpoint rises only for a specialist whose dominant method is absent.
## The director must cap this below style support and enforce counter streak limits.
func counterpoint(methods: Array) -> float:
	var dom := dominant()
	if methods.has(String(dom["axis"])):
		return 0.0
	return clampf(float(dom["share"]) - 0.35, 0.0, 0.45)


func serialize() -> Dictionary:
	return {
		"version": VERSION,
		"values": values.duplicate(true),
		"repeat_memory": repeat_memory.duplicate(true),
		"repeat_order": repeat_order.duplicate(),
		"meaningful_events": meaningful_events,
		"event_decay": event_decay,
		"repeat_penalty": repeat_penalty,
		"meaningful_floor": meaningful_floor,
	}


func restore(data: Dictionary) -> void:
	_reset_values()
	if data.is_empty():
		return
	var raw_values: Dictionary = data.get("values", {})
	for axis in AXES:
		values[axis] = maxf(0.0, float(raw_values.get(axis, 0.0)))
	var raw_repeat: Dictionary = data.get("repeat_memory", {})
	for key in raw_repeat:
		var clean_key := String(key)
		if clean_key != "" and repeat_memory.size() < MAX_REPEAT_KEYS:
			repeat_memory[clean_key] = maxi(0, int(raw_repeat[key]))
	var raw_order: Array = data.get("repeat_order", [])
	for item in raw_order:
		var clean_item := String(item)
		if repeat_memory.has(clean_item) and not repeat_order.has(clean_item):
			repeat_order.append(clean_item)
	meaningful_events = maxi(0, int(data.get("meaningful_events", 0)))
	event_decay = clampf(float(data.get("event_decay", event_decay)), 0.90, 1.0)
	repeat_penalty = clampf(float(data.get("repeat_penalty", repeat_penalty)), 0.25, 1.0)
	meaningful_floor = clampf(float(data.get("meaningful_floor", meaningful_floor)), 0.0, 1.0)


func state_hash() -> int:
	var h := hash([VERSION, meaningful_events, snapped(event_decay, 0.0001), snapped(repeat_penalty, 0.0001)])
	for axis in AXES:
		h = hash([h, axis, snapped(float(values.get(axis, 0.0)), 0.0001)])
	var keys := repeat_memory.keys()
	keys.sort()
	for key in keys:
		h = hash([h, String(key), int(repeat_memory[key])])
	for key in repeat_order:
		h = hash([h, key])
	return h


func _remember_repeat(key: String, count: int) -> void:
	if not repeat_memory.has(key):
		repeat_order.append(key)
	repeat_memory[key] = count
	while repeat_order.size() > MAX_REPEAT_KEYS:
		var oldest := repeat_order.pop_front()
		repeat_memory.erase(oldest)


func _decay_repeat_memory(except_key: String) -> void:
	var erase_keys: Array[String] = []
	for key in repeat_memory:
		if String(key) == except_key:
			continue
		var next_count := maxi(0, int(repeat_memory[key]) - 1)
		repeat_memory[key] = next_count
		if next_count == 0:
			erase_keys.append(String(key))
	for key in erase_keys:
		repeat_memory.erase(key)
		repeat_order.erase(key)