## CueBus.gd — the semantic presentation-orchestration layer.
##
## The problem it solves (HANDOFF §1 "Game feel/juice", REVAMP_SPEC §2.7):
## the legacy game's effects were independent noise — a kill might fire a camera shake,
## an audio sting, a VFX burst, AND a HUD flash, each from a different system, with no
## coordination. The result was cue storms on big events and dead silence on small ones.
##
## CueBus fixes this by sitting BETWEEN the sim and presentation. Sim code emits a single
## semantic event:
##
##     CueBus.emit_cue("kill.elite", { "pos": Vector2(...), "magnitude": 0.7 })
##
## and CueBus routes it to ONE coordinated cue: a camera move + an audio sting + a VFX
## burst + a HUD flash, with priority (a kill sting ducks a footstep, never vice versa),
## concurrency limits (don't stack 10 crit flashes), and accessibility transforms
## (reduced-motion flattens shake/flash; captions fire for deaf players).
##
## Presentation systems register as listeners; CueBus never reaches into them directly.
## This keeps the sim/render boundary clean and the cues choreographed.
##
extends Node
# NOTE: no class_name — this script IS the `CueBus` autoload singleton.

signal cue_emitted(event_id: String, payload: Dictionary)

# --- priority tiers (higher preempts lower) ---
enum Priority { AMBIENT = 0, GAMEPLAY = 10, COMBAT = 20, CRITICAL = 30 }

# --- cue definitions, registered at boot by the presentation layer ---
# { event_id: { "priority": int, "camera": Callable, "audio": String, "vfx": String,
#               "hud": String, "caption": String } }
var _cue_defs: Dictionary = {}

# --- runtime state ---
var _active_high_priority: int = -1   # the highest-priority cue currently suppressing others
var _concurrency: Dictionary = {}     # event_id -> active count, for rate-limiting
var history: Array[Dictionary] = []   # semantic stream the frontend/tests can inspect
var reduced_motion: bool = false      # accessibility: flatten shake/flash when true
var captions_enabled: bool = true     # accessibility: show sound captions

## Register how a semantic event should be presented. Called by presentation systems at boot.
##
## A single event is meant to carry MULTIPLE coordinated modalities (camera + audio + vfx + hud).
## Different presentation systems each own one modality and register independently — e.g.
## CameraDirector defines `hit.connect` with a `camera` callable, while VisualFX defines the same
## event with a `vfx` callable. So we MERGE modality keys instead of replacing the whole def;
## otherwise whichever system registers last silently clobbers the others (this dropped camera
## shake on hit.connect / frenzy.start / masquerade.broken — see GODOT_WIRING_AUDIT.md P0-1).
## Scalars (priority, duration_ms, max_concurrent) take the latest writer; in practice colliding
## registrations supply matching scalars, so this is lossless.
func define(event_id: String, priority: int, cue: Dictionary) -> void:
	cue["priority"] = priority
	if _cue_defs.has(event_id):
		var existing: Dictionary = _cue_defs[event_id]
		for k in cue:
			existing[k] = cue[k]
	else:
		_cue_defs[event_id] = cue

## Emit a semantic cue from sim code. `payload` carries event-specific data (pos, magnitude...).
func emit_cue(event_id: String, payload: Dictionary = {}) -> void:
	var rec := { "event_id": event_id, "payload": payload.duplicate(true) }
	history.append(rec)
	cue_emitted.emit(event_id, payload)
	if not _cue_defs.has(event_id):
		return
	var def: Dictionary = _cue_defs[event_id]
	# concurrency limit — don't stack the same cue endlessly
	var cap: int = int(def.get("max_concurrent", 3))
	if int(_concurrency.get(event_id, 0)) >= cap:
		return
	_concurrency[event_id] = int(_concurrency.get(event_id, 0)) + 1
	# fire each modality through its listener (if any). Listeners handle their own ducking.
	if def.has("camera") and not reduced_motion:
		def["camera"].call(payload)
	if def.has("audio"):
		_play_audio(def["audio"], payload, def["priority"])
	if def.has("vfx"):
		def["vfx"].call(payload)
	if def.has("hud"):
		def["hud"].call(payload)
	if captions_enabled and def.has("caption") and def["caption"] != "":
		_show_caption(def["caption"], payload)
	# release the concurrency slot after the cue's duration (default 400ms).
	# Guard against being called before CueBus is in the scene tree (headless tests).
	var dur_ms: int = int(def.get("duration_ms", 400))
	if is_inside_tree():
		get_tree().create_timer(dur_ms / 1000.0).timeout.connect(
			_release_slot.bind(event_id))
	else:
		# fallback: synchronous release (tests don't care about concurrency limits)
		_release_slot(event_id)

# --- internals ---
func _play_audio(sample_id: String, payload: Dictionary, priority: int) -> void:
	# TODO(audio): route through Audio buses with ducking per priority. Stub for now;
	# wired when the AudioServer bus layout lands.
	pass

func _show_caption(text: String, payload: Dictionary) -> void:
	# TODO(a11y): push to the caption overlay. Stub for now.
	pass

func _release_slot(event_id: String) -> void:
	_concurrency[event_id] = max(0, int(_concurrency.get(event_id, 0)) - 1)
