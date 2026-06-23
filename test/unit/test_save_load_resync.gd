## test_save_load_resync.gd — full save/load round-trip for the run state (Wave 7 #27).
##
## Boot persists the WHOLE run via Sim.serialize_run() and restores it via Sim.restore_run().
## This test proves the round-trip is lossless for the persistent backend: build a sim, mutate
## key run state, serialize, restore into a FRESH sim, and assert the restored state matches.
##
## Why meta.state_hash() and NOT Sim.state_hash():
##   serialize_run() persists the run scalars + the meta backend, but NOT the live entity array.
##   restore_run() rebuilds entities from new_game() defaults, so Sim.state_hash() (which folds
##   in every entity) would only match an untouched, freshly-seeded sim — fragile. meta.state_hash()
##   is entity-independent and round-trips cleanly, so it is the right invariant to assert here.
##
## Uses VCSim.new() directly (not the `Sim` autoload) and an in-memory dict round-trip (not the
## SaveSystem autoload) because GUT's CLI entry point does not reliably initialise autoloads.
## Determinism-safe: no randf()/randi()/Time.* — all mutation is explicit scalar assignment.
##
extends GutTest

const SEED_VALUE := 42


## Mutate run state, serialize, restore into a fresh sim — backend hash + key fields must match.
func test_full_run_round_trips() -> void:
	var src := VCSim.new()
	src.new_game(SEED_VALUE, "brujah")

	# Mutate scalar run/meta state. These fields don't feed `derived`, so no recompute() needed.
	src.meta.money = 4242
	src.meta.xp = 137
	src.meta.xp_total = 137
	src.meta.missions_done = 3
	src.heat = 3.5
	src.tick = 900
	src.rng = 0x5151

	var expected_hash: int = src.meta.state_hash()
	var data: Dictionary = src.serialize_run()

	var dst := VCSim.new()
	var ok: bool = dst.restore_run(data)
	assert_true(ok, "restore_run() should accept a non-empty serialized run")

	# Run scalars round-trip via Sim.restore_run.
	assert_eq(dst.tick, 900, "tick should survive the round-trip")
	assert_eq(dst.rng, 0x5151, "rng state should survive the round-trip")
	assert_almost_eq(dst.heat, 3.5, 0.0001, "heat should survive the round-trip")

	# Meta backend scalars round-trip via meta.restore.
	assert_eq(dst.meta.money, 4242, "money should survive the round-trip")
	assert_eq(dst.meta.xp, 137, "xp should survive the round-trip")
	assert_eq(dst.meta.missions_done, 3, "missions_done should survive the round-trip")
	assert_eq(dst.meta.clan_id, "brujah", "clan should survive the round-trip")

	# The entity-independent backend hash is the keystone invariant.
	assert_eq(dst.meta.state_hash(), expected_hash,
		"restored meta backend hash diverged from the source — save/load is lossy")

	src.queue_free()
	dst.queue_free()


## Restoring an empty/corrupt save must fail gracefully (no world built) so Boot can fall back.
func test_empty_save_fails_without_building_world() -> void:
	var sim := VCSim.new()
	var ok: bool = sim.restore_run({})
	assert_false(ok, "restore_run({}) must return false so Boot falls back to new_game()")
	assert_null(sim.player, "an empty restore must not build a world/player")
	sim.queue_free()


## A serialized run survives the REAL SaveSystem text persistence path (var_to_str/str_to_var)
## losslessly. Unlike JSON, Godot variant text preserves exact types (ints stay ints, Vector2
## positions survive), so the full backend hash round-trips — no coercion, no mid-restore abort.
func test_savesystem_text_round_trips_backend() -> void:
	var src := VCSim.new()
	src.new_game(SEED_VALUE, "brujah")
	src.meta.money = 999
	src.meta.legend = 42
	src.tick = 1234
	var expected_hash: int = src.meta.state_hash()

	# var_to_str -> str_to_var, mirroring SaveSystem.save()/load().
	var text := var_to_str(src.serialize_run())
	var parsed: Variant = str_to_var(text)
	assert_true(parsed is Dictionary, "serialized run must decode to a Dictionary")

	var dst := VCSim.new()
	var ok: bool = dst.restore_run(parsed as Dictionary)
	assert_true(ok, "restore_run() should accept a text-decoded run")
	assert_eq(dst.meta.money, 999, "money should survive the SaveSystem round-trip")
	assert_eq(dst.meta.legend, 42, "legend should survive the SaveSystem round-trip")
	assert_eq(dst.tick, 1234, "tick should survive the SaveSystem round-trip")
	assert_eq(dst.meta.state_hash(), expected_hash,
		"backend hash must survive the SaveSystem text round-trip losslessly")

	src.queue_free()
	dst.queue_free()
