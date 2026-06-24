## SaveSystem.gd — save-game persistence with multiple slots (ship hygiene Steam prerequisite).
##
## Three independent slots, each a Godot-variant text file (var_to_str, NOT JSON — it round-trips
## every Godot type losslessly; JSON coerces ints to float and drops Vector2, which silently broke
## the full-run restore). The active slot is `current_slot`; save()/load()/save_exists()/erase()
## operate on it, so the menu can switch slots without changing the call sites in Boot.gd.
##
## Separate autoload from Sim: UI calls these; Boot.gd seeds Sim.new_game() with the loaded values.
extends Node
# NOTE: no class_name — this script IS the `SaveSystem` autoload singleton.

static var current_slot: int = 0


static func _slot_path(slot: int) -> String:
	return "user://save_%d.sav" % clampi(slot, 0, 2)


static func save_exists() -> bool:
	return FileAccess.file_exists(_slot_path(current_slot))


static func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


## Persist the full run state into the active slot. `data` is owned by the caller.
func save(data: Dictionary) -> void:
	var f := FileAccess.open(_slot_path(current_slot), FileAccess.WRITE)
	if f == null:
		push_warning("[SaveSystem] could not open slot %d for write" % current_slot)
		return
	f.store_string(var_to_str(data))
	f.close()


func load() -> Dictionary:
	return _read(_slot_path(current_slot))


## A save's headline data (for slot-select UI): level/clan/etc. without restoring the run.
func slot_info(slot: int) -> Dictionary:
	return _read(_slot_path(slot))


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = str_to_var(text)
	return parsed if parsed is Dictionary else {}


func erase() -> void:
	var path := _slot_path(current_slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
