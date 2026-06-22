## InputAction.gd — a serialisable player intent.
##
## Player input is captured as a stream of InputActions, NOT raw key states. This is what
## makes deterministic replay possible: we record the *intent* (move vector, pressed action,
## aim target), not the hardware. Replay re-feeds the same intents on the same ticks.
##
## Construct these in the render/input layer from Godot InputEvents; Sim.apply_input()
## consumes them. Never read Input directly inside src/sim/.
##
extends RefCounted
class_name InputAction

# Intent enum. Append new verbs so recorded replay integers stay stable.
enum Kind { MOVE, AIM, ATTACK, FEED, DASH, INTERACT, POWER, RELEASE, SPRINT, SNEAK, POUNCE, FINISH }

var kind: int = Kind.MOVE
var vector: Vector2 = Vector2.ZERO   # MOVE: unit move dir; AIM: world-space aim point
var action_id: String = ""           # POWER: which power id to cast; RELEASE: optional released verb
var held: bool = false               # FEED/SPRINT/SNEAK/AIM: current held state

func _init(k: int = Kind.MOVE) -> void:
	kind = k

## Serialise to a plain dict for the replay recording. Must be deterministic.
func serialize() -> Dictionary:
	return {
		"kind": kind,
		"vx": vector.x,
		"vy": vector.y,
		"action_id": action_id,
		"held": held,
	}

## Inverse of serialize(). Reconstructs the exact same intent for replay.
static func deserialize(d: Dictionary) -> InputAction:
	var a := InputAction.new(int(d["kind"]))
	a.vector = Vector2(float(d["vx"]), float(d["vy"]))
	a.action_id = String(d["action_id"])
	a.held = bool(d["held"])
	return a
