## SaveSystem.gd — minimal save-game persistence for the vertical slice.
##
## The frontend needs a Continue affordance that's disabled when no save exists, and a
## "Save Game" verb in the pause menu. The full save schema (coterie, economy, Heat
## history, replay tapes) is Phase 2; for the slice we persist the seed + clan + a tick
## snapshot so New/Continue round-trips cleanly and UI can react to save state.
##
## This is a separate autoload from Sim: UI calls save()/load() here, and Boot.gd (the
## game host) is what actually seeds Sim.new_game() with the loaded values. UI still
## never mutates Sim directly.
extends Node
# NOTE: no class_name — this script IS the `SaveSystem` autoload singleton.

# Godot variant text (var_to_str), NOT JSON: it round-trips every Godot type losslessly
# (ints stay ints, Vector2 positions survive). JSON coerces all numbers to float and drops
# Vector2, which silently breaks the full-run restore (legend/positions vanished mid-restore).
const SAVE_PATH := "user://save.sav"


static func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Persist the full run state. `data` is owned by the caller (Boot.gd via Sim.serialize_run()).
func save(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[SaveSystem] could not open save for write: %s" % SAVE_PATH)
		return
	f.store_string(var_to_str(data))
	f.close()


func load() -> Dictionary:
	if not save_exists():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = str_to_var(text)
	if not (parsed is Dictionary):
		return {}
	return parsed


func erase() -> void:
	if save_exists():
		DirAccess.remove_absolute(SAVE_PATH)
