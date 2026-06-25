## test_visualfx_numbers.gd — smoke test for the reworked floating damage numbers.
##
## Instantiates VisualFX, adds it to the tree (so _ready registers cues), and fires the cues
## it consumes for the punch-style number rework: damage.dealt (crit + non-crit) and the new
## combo.trigger. Asserts no crash and that a floating label node was actually created.
## Camera is null in headless (no gameplay camera) — VisualFX._world_to_screen guards that.
extends GutTest

const VisualFXScript := preload("res://src/present/VisualFX.gd")


func _make_fx() -> VisualFX:
	var fx: VisualFX = VisualFXScript.new()
	add_child_autofree(fx)
	# _ready ran on add_child; cue registration done. Pump a frame to settle.
	return fx


func _floating_count(fx: VisualFX) -> int:
	return fx._floating_texts.size()


func test_damage_dealt_normal_spawns_a_floating_number() -> void:
	var fx := _make_fx()
	assert_eq(_floating_count(fx), 0, "no floats before any cue")
	fx._on_damage_dealt({ "amount": 14.0, "pos": Vector2(120, 80), "crit": false })
	assert_eq(_floating_count(fx), 1, "a non-crit hit spawns one floating number")
	# The float's node is real and parented under the VisualFX layer.
	var ft: Dictionary = fx._floating_texts[0]
	assert_not_null(ft.get("label"), "float record carries a label node")
	assert_true(is_instance_valid(ft["label"]), "label node is alive")
	assert_eq((ft["label"] as Node).get_parent(), fx, "label parented under VisualFX")


func test_damage_dealt_crit_spawns_with_crit_tag() -> void:
	var fx := _make_fx()
	fx._on_damage_dealt({ "amount": 33.0, "pos": Vector2(200, 140), "crit": true })
	assert_eq(_floating_count(fx), 1, "a crit hit spawns one floating number")
	var node: Node = fx._floating_texts[0]["label"]
	# Crit style stacks a "CRIT!" tag label above the number → two child labels in the box.
	var label_count := 0
	for c in node.get_children():
		if c is Label:
			label_count += 1
	assert_eq(label_count, 2, "crit float carries a CRIT! tag plus the number")


func test_combo_trigger_spawns_combo_readout() -> void:
	var fx := _make_fx()
	fx._on_combo_trigger({
		"target_id": 7,
		"combo_name": "hemorrhage",
		"bonus_damage": 5.0,
		"pos": Vector2(64, 64),
	})
	assert_eq(_floating_count(fx), 1, "combo.trigger spawns one readout")
	var node: Node = fx._floating_texts[0]["label"]
	var found_text := ""
	for c in node.get_children():
		if c is Label:
			found_text = (c as Label).text
	assert_string_contains(found_text, "HEMORRHAGE", "combo readout names the combo")
	assert_string_contains(found_text, "+5", "combo readout shows the bonus damage")


func test_cues_route_through_cuebus_without_crash() -> void:
	var fx := _make_fx()
	assert_not_null(CueBus, "CueBus autoload present")
	# emit_cue calls the registered vfx handler synchronously.
	CueBus.emit_cue("damage.dealt", { "amount": 9.0, "pos": Vector2(10, 10), "crit": false })
	CueBus.emit_cue("damage.dealt", { "amount": 40.0, "pos": Vector2(10, 10), "crit": true })
	CueBus.emit_cue("combo.trigger", {
		"combo_name": "immolate", "bonus_damage": 8.0, "pos": Vector2(10, 10),
	})
	assert_gte(_floating_count(fx), 3, "all three cues spawned floats via CueBus routing")


func test_floats_punch_then_expire_over_lifetime() -> void:
	var fx := _make_fx()
	fx._on_damage_dealt({ "amount": 12.0, "pos": Vector2(0, 0), "crit": false })
	assert_eq(_floating_count(fx), 1, "float present right after spawn")
	# Drive past the lifetime; the float must clean itself up (no leak).
	fx._update_floating_texts(VisualFX.DAMAGE_DURATION + 0.05)
	assert_eq(_floating_count(fx), 0, "float removed after its lifetime elapses")


func test_reduced_motion_skips_punch_but_still_spawns() -> void:
	var fx := _make_fx()
	var prior := false
	if CueBus != null:
		prior = CueBus.reduced_motion
		CueBus.reduced_motion = true
	fx._on_damage_dealt({ "amount": 7.0, "pos": Vector2(0, 0), "crit": false })
	assert_eq(_floating_count(fx), 1, "number still appears under reduced motion")
	var ft: Dictionary = fx._floating_texts[0]
	assert_eq(float(ft["punch_time"]), 0.0, "reduced motion disables the punch window")
	assert_eq(float(ft["punch_scale"]), 1.0, "reduced motion starts at final scale")
	if CueBus != null:
		CueBus.reduced_motion = prior
