## test_cuebus_merge.gd — regression guard for the CueBus modality-clobber bug.
##
## Before the fix, CueBus.define() replaced the whole def, so the last system to register an event
## won. CameraDirector and VisualFX both register hit.connect / frenzy.start / masquerade.broken;
## VisualFX loaded last (vfx-only) and silently dropped camera shake on those three beats.
## define() now MERGES modality keys. This test proves a colliding event keeps BOTH a camera and a
## vfx modality and that BOTH fire on emit. (The visual result can't be asserted headless; the
## def-shape + callable-fired contract is the headless-checkable proof.)
extends GutTest

const CueBusScript := preload("res://src/present/CueBus.gd")


func test_define_merges_colliding_modalities_instead_of_clobbering() -> void:
	var bus = CueBusScript.new()
	var cam_fired := [false]
	var vfx_fired := [false]
	var cam_cb := func(_p): cam_fired[0] = true
	var vfx_cb := func(_p): vfx_fired[0] = true

	# CameraDirector-style registration: camera modality only.
	bus.define("hit.connect", CueBusScript.Priority.COMBAT, {"camera": cam_cb, "duration_ms": 200})
	# VisualFX-style registration of the SAME event: vfx only. Must NOT clobber the camera key.
	bus.define("hit.connect", CueBusScript.Priority.COMBAT, {"vfx": vfx_cb, "duration_ms": 200})

	var def: Dictionary = bus._cue_defs["hit.connect"]
	assert_true(def.has("camera"), "camera modality must survive the second registration")
	assert_true(def.has("vfx"), "vfx modality must be added by the second registration")
	assert_eq(int(def["priority"]), int(CueBusScript.Priority.COMBAT), "priority preserved")

	bus.emit_cue("hit.connect", {})
	assert_true(cam_fired[0], "camera cue must fire after merge (was the clobbered shake)")
	assert_true(vfx_fired[0], "vfx cue must fire after merge")
	bus.free()


func test_define_still_sets_a_fresh_event() -> void:
	var bus = CueBusScript.new()
	var fired := [false]
	bus.define("solo.event", CueBusScript.Priority.GAMEPLAY, {"vfx": func(_p): fired[0] = true})
	assert_true(bus._cue_defs.has("solo.event"), "fresh event registers")
	bus.emit_cue("solo.event", {})
	assert_true(fired[0], "fresh single-modality event still fires")
	bus.free()
