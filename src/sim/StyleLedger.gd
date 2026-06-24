## StyleLedger.gd — the consequence loop's memory: a Sim-owned, deterministic profile of HOW the
## player fights (force / stealth / social / blood), so the city can dispatch hunters that COUNTER
## the player's build instead of a style-blind coin flip. Pure data + integer-stable float tallies;
## folded into Sim.state_hash and the save round-trip, so replays stay bit-exact. No RNG of its own.
extends RefCounted
class_name StyleLedger

var tallies: Dictionary = { "force": 0.0, "stealth": 0.0, "social": 0.0, "blood": 0.0 }


func record(channel: String, weight: float) -> void:
	if tallies.has(channel):
		tallies[channel] = float(tallies[channel]) + weight


## The play style the player leans on most (or "" before they've shown their hand).
func dominant() -> String:
	var best := ""
	var best_v := 0.0001
	for k in tallies:
		var v := float(tallies[k])
		if v > best_v:
			best_v = v
			best = k
	return best


## A responder type that COUNTERS the dominant style, gated by heat. `roll` is a deterministic draw
## from Sim.rng (passed in) so the within-tier choice stays replay-stable.
func counter_type(stars: int, roll: float) -> String:
	if stars <= 2:
		return "cop"
	var dom := dominant()
	if dom == "stealth":
		return "hunter"          # a Tracker for the unseen, at any serious heat
	if stars >= 6:
		return "elder" if dom == "force" or roll < 0.5 else "hunter"
	if stars >= 5:
		return "swat" if dom == "force" or roll < 0.5 else "hunter"
	# stars 3-4: a bruiser for the brute, else a patrol escalation
	return "swat" if dom == "force" or roll < 0.5 else "cop"


func state_hash() -> int:
	return hash([
		snapped(float(tallies["force"]), 0.001), snapped(float(tallies["stealth"]), 0.001),
		snapped(float(tallies["social"]), 0.001), snapped(float(tallies["blood"]), 0.001),
	])


func to_dict() -> Dictionary:
	return tallies.duplicate(true)


func from_dict(d: Dictionary) -> void:
	for k in tallies:
		tallies[k] = float(d.get(k, tallies[k]))
