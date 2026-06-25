## Shared helpers for tests that instantiate VCSim directly instead of using the Sim autoload.
extends RefCounted
class_name SimTestHelpers


static func new_sim(seed_value: int = 42, clan_id: String = "brujah") -> VCSim:
	var sim := VCSim.new()
	sim.new_game(seed_value, clan_id)
	return sim


static func free_sim(sim: VCSim) -> void:
	if sim != null and is_instance_valid(sim):
		sim.free()
