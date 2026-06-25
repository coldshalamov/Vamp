## GameRenderer.gd — the gameplay view layer.
##
## Owns the world renderer, entity renderer, lighting, camera, and visual FX.
## Bridges Godot input (via Rebind) to Sim.apply_input(). Runs Sim.tick_sim() on
## the fixed physics step. Owned by the vision-capable frontend agent.
extends Node2D
class_name GameRenderer

const FIXED_DT := 1.0 / 60.0

const WorldRendererScript := preload("res://src/present/WorldRenderer.gd")
const BloodRendererScript := preload("res://src/present/BloodRenderer.gd")
const PropRendererScript := preload("res://src/present/PropRenderer.gd")
const EntityRendererScript := preload("res://src/present/EntityRenderer.gd")
const LightingDirectorScript := preload("res://src/present/LightingDirector.gd")
const CameraDirectorScript := preload("res://src/present/CameraDirector.gd")
const VisualFXScript := preload("res://src/present/VisualFX.gd")
const WorldFXScript := preload("res://src/present/WorldFX.gd")
const SpellFXScript := preload("res://src/present/SpellFX.gd")
const AtmosphereScript := preload("res://src/present/AtmosphereDirector.gd")
const NocturneGradeScript := preload("res://src/present/NocturneGrade.gd")
const DebugOverlayScript := preload("res://src/present/DebugOverlay.gd")
const DeathScreenScript := preload("res://src/ui/DeathScreen.gd")

var _world_renderer: Node2D = null
var _blood_renderer: Node2D = null
var _prop_renderer: Node2D = null
var _entity_renderer: Node2D = null
var _world_fx: Node2D = null
var _spell_fx: Node2D = null
var _atmosphere: Control = null
var _lighting: Node2D = null
var _camera: Camera2D = null
var _visual_fx: CanvasLayer = null
var _nocturne: CanvasLayer = null
var _debug_overlay: CanvasLayer = null
var _death_screen: CanvasLayer = null
var _game_active: bool = true
var _dead_shown: bool = false

func _ready() -> void:
	# Ensure a sim game is running. If Sim was already initialised (e.g. by Boot),
	# reuse it; otherwise start a fresh slice.
	if Sim == null:
		push_error("GameRenderer: Sim autoload is missing")
		return
	if Sim.player == null:
		Sim.new_game(42, "brujah", true)   # populated: a living block for the playable night

	# Build the view hierarchy.
	_world_renderer = WorldRendererScript.new()
	_world_renderer.name = "WorldRenderer"
	_world_renderer.setup(Sim.world)
	add_child(_world_renderer)

	# Dynamic blood pools (the SPILL layer), under props/actors.
	_blood_renderer = BloodRendererScript.new()
	_blood_renderer.name = "BloodRenderer"
	_blood_renderer.setup(Sim.world)
	add_child(_blood_renderer)

	# Upright billboard props (lamps/trees/neon) above the floor, below entities.
	_prop_renderer = PropRendererScript.new()
	_prop_renderer.name = "PropRenderer"
	_prop_renderer.setup(Sim.world)
	add_child(_prop_renderer)

	_lighting = LightingDirectorScript.new()
	_lighting.name = "LightingDirector"
	_lighting.setup(Sim.world)
	add_child(_lighting)

	_entity_renderer = EntityRendererScript.new()
	_entity_renderer.name = "EntityRenderer"
	_entity_renderer.setup(Sim.entities)
	add_child(_entity_renderer)
	# Place every rig at its authoritative starting transform before the first rendered frame.
	_entity_renderer.physics_sync(0.0)

	# World-space combat/spell FX (swings, impacts, shockwaves) — above actors, under UI.
	_world_fx = WorldFXScript.new()
	_world_fx.name = "WorldFX"
	add_child(_world_fx)

	# Archetype-driven spell visuals (the end of "every spell is a circle"). Its own seam, above
	# WorldFX's swings/impacts — WorldFX stays owned by the ballistics pass.
	_spell_fx = SpellFXScript.new()
	_spell_fx.name = "SpellFX"
	add_child(_spell_fx)

	# Screen-space rain + fog, above the world and below the mood grade + HUD.
	var atmos_layer := CanvasLayer.new()
	atmos_layer.name = "AtmosphereLayer"
	atmos_layer.layer = 1
	add_child(atmos_layer)
	_atmosphere = AtmosphereScript.new()
	_atmosphere.name = "AtmosphereDirector"
	atmos_layer.add_child(_atmosphere)

	_camera = CameraDirectorScript.new()
	_camera.name = "CameraDirector"
	add_child(_camera)

	# Unified screen-space mood grade (merged glowup shader), above the world, below the HUD.
	_nocturne = NocturneGradeScript.new()
	_nocturne.name = "NocturneGrade"
	add_child(_nocturne)

	_visual_fx = VisualFXScript.new()
	_visual_fx.name = "VisualFX"
	add_child(_visual_fx)

	# F3 sim-truth debug overlay. Starts hidden; pure read of Sim state.
	_debug_overlay = DebugOverlayScript.new()
	_debug_overlay.name = "DebugOverlay"
	add_child(_debug_overlay)

	# Death/torpor overlay — without it, player death froze the world with no recovery.
	_death_screen = DeathScreenScript.new()
	_death_screen.name = "DeathScreen"
	add_child(_death_screen)

func _physics_process(_delta: float) -> void:
	if Sim == null:
		return
	# Catch player death the moment it happens and stop the world cleanly.
	if not _dead_shown and Sim.player != null and Sim.player.dead:
		_dead_shown = true
		_game_active = false
		if _death_screen != null:
			_death_screen.show_death()
		if _entity_renderer != null:
			_entity_renderer.physics_sync(FIXED_DT)
		return
	if not _game_active:
		return
	Sim.tick_sim(FIXED_DT)
	# Synchronise visual transforms only after the authoritative tick. With project-level physics
	# interpolation enabled, Godot now fills rendered frames between these deterministic 60 Hz states.
	if _entity_renderer != null:
		_entity_renderer.physics_sync(FIXED_DT)

func _input(event: InputEvent) -> void:
	# While dead, any key/click rises the player from torpor.
	if _dead_shown:
		var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed)
		if pressed:
			_respawn()
			get_viewport().set_input_as_handled()
		return
	if not _game_active or Rebind == null:
		return
	var action := Rebind.capture(event)
	if action != null:
		Sim.apply_input(action)
		get_viewport().set_input_as_handled()

func _respawn() -> void:
	if Sim != null:
		Sim.revive_player()
	_dead_shown = false
	_game_active = true
	if _entity_renderer != null:
		_entity_renderer.physics_sync(0.0)
	if _death_screen != null:
		_death_screen.hide_death()

func set_game_active(active: bool) -> void:
	_game_active = active
