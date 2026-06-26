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
const ParticleFXScript := preload("res://src/present/ParticleFX.gd")
const SpellParticlesScript := preload("res://src/present/SpellParticles.gd")
const RainFXScript := preload("res://src/present/RainFX.gd")
const AmbientFXScript := preload("res://src/present/AmbientFX.gd")
const BloomFXScript := preload("res://src/present/BloomFX.gd")
const ScreenFXScript := preload("res://src/present/ScreenFX.gd")
const ParallaxBackdropScript := preload("res://src/present/ParallaxBackdrop.gd")
const CityDetailLayerScript := preload("res://src/present/CityDetailLayer.gd")
const AtmosphereScript := preload("res://src/present/AtmosphereDirector.gd")
const NocturneGradeScript := preload("res://src/present/NocturneGrade.gd")
const PostProcessScript := preload("res://src/present/PostProcess.gd")
const DebugOverlayScript := preload("res://src/present/DebugOverlay.gd")
const DeathScreenScript := preload("res://src/ui/DeathScreen.gd")

var _world_renderer: Node2D = null
var _blood_renderer: Node2D = null
var _prop_renderer: Node2D = null
var _entity_renderer: Node2D = null
var _world_fx: Node2D = null
var _spell_fx: Node2D = null
var _particle_fx: Node2D = null
var _spell_particles: Node2D = null
var _rain_fx: Node2D = null
var _ambient_fx: Node2D = null
var _bloom_fx: Node2D = null
var _screen_fx: CanvasLayer = null
var _parallax: CanvasLayer = null
var _city_detail: Node2D = null
var _atmosphere: Control = null
var _lighting: Node2D = null
var _camera: Camera2D = null
var _visual_fx: CanvasLayer = null
var _nocturne: CanvasLayer = null
var _post_process: CanvasLayer = null
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

	# Distant parallax city silhouettes BEHIND the play field (it forces its own layer = -1).
	_parallax = ParallaxBackdropScript.new()
	_parallax.name = "ParallaxBackdrop"
	add_child(_parallax)

	# Build the view hierarchy.
	_world_renderer = WorldRendererScript.new()
	_world_renderer.name = "WorldRenderer"
	_world_renderer.setup(Sim.world)
	add_child(_world_renderer)

	# City ground detail (lane lines, crosswalks, manholes — z 6, below actors) + foreground props
	# (awnings/signs that overlap the player near buildings — z 30). Additive over WorldRenderer.
	_city_detail = CityDetailLayerScript.new()
	_city_detail.name = "CityDetailLayer"
	add_child(_city_detail)
	_city_detail.setup(Sim.world)

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

	# Manual additive bloom/glow over each authored light (no HDR-2D on GL Compat) — neon bleeds.
	_bloom_fx = BloomFXScript.new()
	_bloom_fx.name = "BloomFX"
	add_child(_bloom_fx)
	_bloom_fx.setup(Sim.world)

	# Lean ambient atmosphere — drifting dust motes / faint steam (z 14, above ground, below actors).
	_ambient_fx = AmbientFXScript.new()
	_ambient_fx.name = "AmbientFX"
	add_child(_ambient_fx)

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

	# GPUParticles2D combat spectacle (blood spray, death dissolve, dash/footstep dust) — read-only cues.
	_particle_fx = ParticleFXScript.new()
	_particle_fx.name = "ParticleFX"
	add_child(_particle_fx)

	# Per-discipline GPU spell particles layered over SpellFX's line-art (z 53).
	_spell_particles = SpellParticlesScript.new()
	_spell_particles.name = "SpellParticles"
	add_child(_spell_particles)

	# GPU rain + ground splash, camera-following world-space (z 55). Replaces the old draw_line rain.
	_rain_fx = RainFXScript.new()
	_rain_fx.name = "RainFX"
	add_child(_rain_fx)

	# Screen-space fog, above the world and below the mood grade + HUD.
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

	# Event-driven screen feedback (damage red-vignette + crit chromatic aberration) on layer 3,
	# composited above the NocturneGrade (layer 2) and below the HUD (layer 100).
	_screen_fx = ScreenFXScript.new()
	_screen_fx.name = "ScreenFX"
	add_child(_screen_fx)

	# Final filmic master pass on layer 4 (ACES tonemap + teal/amber grade + grain + vignette),
	# above the world/mood/damage grades and below all UI. See PostProcess.gd / post_process.gdshader.
	_post_process = PostProcessScript.new()
	_post_process.name = "PostProcess"
	add_child(_post_process)

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
