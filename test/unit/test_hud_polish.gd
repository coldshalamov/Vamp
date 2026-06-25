## test_hud_polish.gd — GUT smoke tests for the HUD "feel" polish (Track C 1c/1d/5d).
##
## Proves the new presentation pieces run error-free against real Sim state:
##   - Cooldown RING: feeding b.power_cooldowns drives the per-slot radial wipe; clearing it fires
##     the cooldown->ready transition. (The ring reads b.power_cooldowns, NOT the cue payload.)
##   - Blood VIAL: set_fill lerps a displayed ratio; low-blood + feed surge animate without crash.
##   - Heat card HIDES at zero stars and shows when stars > 0.
##   - feed.kill/spare/end cues surge the vial; damage cues no longer crash (numbers moved to VisualFX).
##
## Mirrors test_hud_binding.gd: instantiate the HUD scene, swap a fresh VCSim into the live autoload.
extends GutTest

const HUDScene := preload("res://scenes/ui/HUD.tscn")
const SimTest := preload("res://test/unit/sim_test_helpers.gd")
const CooldownRingScript := preload("res://src/ui/CooldownRing.gd")
const VialGaugeScript := preload("res://src/ui/VialGauge.gd")

var _sim: VCSim
var _hud: Control
var _saved_autoload: Dictionary = {}


func before_each() -> void:
	_sim = SimTest.new_sim(99, "brujah")
	if Sim != null:
		_saved_autoload = {
			"player": Sim.player, "entities": Sim.entities, "heat": Sim.heat,
			"tick": Sim.tick, "meta": Sim.meta,
		}
		Sim.player = _sim.player
		Sim.entities = _sim.entities
		Sim.heat = _sim.heat
		Sim.tick = _sim.tick
		Sim.meta = _sim.meta
	_sim.cue_events.clear()
	_hud = HUDScene.instantiate()
	add_child_autoqfree(_hud)


func after_each() -> void:
	if Sim != null and not _saved_autoload.is_empty():
		Sim.player = _saved_autoload["player"]
		Sim.entities = _saved_autoload["entities"]
		Sim.heat = float(_saved_autoload["heat"])
		Sim.tick = int(_saved_autoload["tick"])
		Sim.meta = _saved_autoload["meta"]
	if UIManager != null and UIManager._hud == _hud:
		UIManager._hud = null
	SimTest.free_sim(_sim)
	_sim = null
	_hud = null
	_saved_autoload.clear()


func _first_slotted_power() -> String:
	if Sim == null or Sim.meta == null or Sim.meta.get("slots") == null:
		return ""
	for s in Sim.meta.slots:
		if s != null and String(s) != "":
			return String(s)
	return ""


func test_cooldown_ring_drives_and_clears_without_error() -> void:
	var pid := _first_slotted_power()
	assert_ne(pid, "", "the brujah loadout slots at least one power")
	var b: SimPlayer = _sim.player.behaviour
	# Put the power on cooldown -> ring should take the wipe path.
	b.power_cooldowns[pid] = 90
	_hud._refresh_hotbar()
	# The slot whose power matches pid should now host a CooldownRing with a non-zero fraction.
	var ring: Control = _find_ring_for_power(pid)
	assert_not_null(ring, "found the cooldown ring for the slotted power")
	if ring != null:
		assert_gt(ring._frac, 0.0, "ring shows a live cooldown fraction")
	# Now come off cooldown -> the ring detects the ready edge (fires its flash) without crashing.
	b.power_cooldowns[pid] = 0
	_hud._refresh_hotbar()
	if ring != null:
		assert_eq(ring._frac, 0.0, "ring cleared to ready when cooldown elapsed")
	# Erase entirely (loadout-style change) -> ring must reset cleanly.
	b.power_cooldowns.erase(pid)
	_hud._refresh_hotbar()
	assert_true(true, "hotbar refresh ran clean across cooldown -> ready -> cleared")


func _find_ring_for_power(pid: String) -> Control:
	var slots: Array = Sim.meta.slots
	for i in _hud._hotbar_slots.size():
		if i < slots.size() and slots[i] != null and String(slots[i]) == pid:
			return _hud._hotbar_slots[i]["ring"]
	return null


func test_power_cooldown_cue_refreshes_hotbar_without_error() -> void:
	# The cue only triggers a refresh; the ring reads live state. Just assert no crash.
	_hud._on_cue("power.cooldown", { "power_id": _first_slotted_power(), "remaining": 60 })
	assert_true(true, "power.cooldown cue handled without error")


func test_vial_low_blood_and_surge_animate_without_error() -> void:
	var b: SimPlayer = _sim.player.behaviour
	# Drive the vial into the low-blood band, then process a few frames (throb path).
	b.blood = b.max_blood * 0.1
	_hud._refresh_vitals()
	for i in 4:
		_hud._vitae_vial._process(1.0 / 60.0)
	# Refill + surge via the feed cues.
	b.blood = b.max_blood
	_hud._on_cue("feed.kill", { "target_id": 0, "pos": Vector2.ZERO, "blood": 30.0, "blood_gained": 30.0 })
	_hud._on_cue("feed.spare", { "target_id": 0, "pos": Vector2.ZERO, "blood": 10.0 })
	_hud._on_cue("feed.end", { "entity_id": 0, "blood_total": 60.0 })
	for i in 4:
		_hud._vitae_vial._process(1.0 / 60.0)
	assert_true(_hud._vitae_label.text.find("/") != -1, "vitae label intact after surge")


func test_vial_does_not_throb_with_no_player() -> void:
	# Regression for the menu-throb hazard: ratio pinned to 0.0 (null player) must NOT pulse.
	var vial: Control = VialGaugeScript.new()
	add_child_autoqfree(vial)
	vial.set_fill(0.0, Color.RED)
	for i in 10:
		vial._process(1.0 / 60.0)
	assert_eq(vial._pulse_phase, 0.0, "no low-blood throb when ratio is exactly 0 (menu/death state)")


func test_heat_card_hidden_at_zero_shown_when_hot() -> void:
	# Zero heat -> card hidden.
	Sim.heat = 0.0
	_hud._cached_heat = -1
	_hud._refresh_heat()
	assert_false(_hud._heat_card.visible, "heat card hidden when stars == 0")
	# Hot -> card visible.
	Sim.heat = 3.0
	_hud._cached_heat = -1
	_hud._refresh_heat()
	assert_true(_hud._heat_card.visible, "heat card shown when stars > 0")


func test_heat_changed_cue_runs_clean() -> void:
	_hud._on_cue("heat.changed", { "old_stars": 0, "new_stars": 2, "stars": 2, "heat": 2.0, "reason": "test" })
	assert_true(true, "heat.changed cue handled without error")


func test_damage_cue_no_longer_crashes_after_number_removal() -> void:
	# HUD no longer spawns damage numbers (VisualFX owns them); the cue is now an unmatched no-op.
	_hud._on_cue("damage.dealt", { "amount": 21.0, "pos": Vector2(50, 50), "crit": false })
	assert_true(true, "damage.dealt is a clean no-op in the HUD now")
