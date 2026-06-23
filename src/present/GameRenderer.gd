## GameRenderer.gd — the gameplay view layer.
##
## Owns the world renderer, entity renderer, lighting, camera, and visual FX.
## Bridges Godot input (via Rebind) to Sim.apply_input(). Runs Sim.tick_sim() on
## the fixed physics step. Owned by the vision-capable frontend agent.
extends Node2D
class_name GameRenderer

const FIXED_DT := 1.0 / 60.0

const WorldRendererScript := preload("res://src/present/WorldRenderer.gd")
const PropRendererScript := preload("res://src/present/PropRenderer.gd")
const EntityRendererScript := preload("res://src/present/EntityRenderer.gd")
const LightingDirectorScript := preload("res://src/present/LightingDirector.gd")
const CameraDirectorScript := preload("res://src/present/CameraDirector.gd")
const VisualFXScript := preload("res://src/present/VisualFX.gd")

var _world_renderer: Node2D = null
var _prop_renderer: Node2D = null
var _entity_renderer: Node2D = null
var _lighting: Node2D = null
var _camera: Camera2D = null
var _visual_fx: CanvasLayer = null
var _game_active: bool = true

func _ready() -> void:
	# Ensure a sim game is running. If Sim was already initialised (e.g. by Boot),
	# reuse it; otherwise start a fresh slice.
	if Sim == null:
		push_error("GameRenderer: Sim autoload is missing")
		return
	if Sim.player == null:
		Sim.new_game(42, "brujah")

	# Build the view hierarchy.
	_world_renderer = WorldRendererScript.new()
	_world_renderer.name = "WorldRenderer"
	_world_renderer.setup(Sim.world)
	add_child(_world_renderer)

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

	_camera = CameraDirectorScript.new()
	_camera.name = "CameraDirector"
	add_child(_camera)

	_visual_fx = VisualFXScript.new()
	_visual_fx.name = "VisualFX"
	add_child(_visual_fx)

func _physics_process(_delta: float) -> void:
	if not _game_active or Sim == null:
		return
	Sim.tick_sim(FIXED_DT)

func _input(event: InputEvent) -> void:
	if not _game_active or Rebind == null:
		return
	var action := Rebind.capture(event)
	if action != null:
		Sim.apply_input(action)
		get_viewport().set_input_as_handled()

func set_game_active(active: bool) -> void:
	_game_active = active
