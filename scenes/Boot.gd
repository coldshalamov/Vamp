## Boot.gd — game host / flow controller.
##
## Owns the high-level game flow: title -> gameplay -> pause -> quit. The scene tree here is
## a thin orchestrator. The Sim autoload is the authoritative state; GameRenderer is the
## gameplay VIEW (world/entities/camera/input bridge); UIManager is the UI layer.
##
## This is the ONLY place that connects UI intent to Sim mutation:
##   - UIManager exposes callbacks (cb_new_game, cb_save_game, ...) that screens call.
##   - Boot wires those callbacks to Sim.new_game() / SaveSystem / scene swaps.
##   - UI code never touches Sim directly.
extends Node2D

const GAME_VIEW_SCENE := preload("res://scenes/GameView.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const NOTIF_SCENE := preload("res://scenes/ui/NotificationPanel.tscn")
const CAPTION_SCENE := preload("res://scenes/ui/CaptionOverlay.tscn")
const FLOATING_SCRIPT := preload("res://src/ui/FloatingText.gd")

var _game_view: Node2D = null
var _hud: Control = null
var _notifs: Control = null
var _captions: Control = null
var _floating: Control = null
var _in_gameplay: bool = false


func _ready() -> void:
	# Wire UI intent -> host actions.
	UIManager.cb_new_game = _on_new_game
	UIManager.cb_continue_game = _on_continue_game
	UIManager.cb_save_game = _on_save_game
	UIManager.cb_quit_to_menu = _on_quit_to_menu
	UIManager.cb_quit_to_desktop = _on_quit_to_desktop

	# Build the persistent overlays once. They live in the UIManager canvas layer so they
	# render above gameplay but below menu screens.
	_notifs = NOTIF_SCENE.instantiate()
	UIManager.add_child(_notifs)
	_captions = CAPTION_SCENE.instantiate()
	UIManager.add_child(_captions)
	_floating = Control.new()
	_floating.set_script(FLOATING_SCRIPT)
	_floating.set_anchors_preset(Control.PRESET_FULL_RECT)
	UIManager.add_child(_floating)

	# HUD starts hidden; we show it when gameplay begins.
	_hud = HUD_SCENE.instantiate()
	UIManager.add_child(_hud)
	UIManager.show_hud(false)

	# Title screen first (acceptance criterion #1: boots to MainMenu).
	UIManager.open_menu("main_menu")


# ---------------------------------------------------------------- flow

func _on_new_game() -> void:
	Sim.new_game(42, "brujah")
	_enter_gameplay()


func _on_continue_game() -> void:
	var data := SaveSystem.load()
	var seed_value := int(data.get("seed", 42))
	var clan := String(data.get("clan", "brujah"))
	Sim.new_game(seed_value, clan)
	_enter_gameplay()


func _on_save_game() -> void:
	var data := {
		"seed": Sim.seed_value,
		"clan": String(Sim.player.tags.get("clan", "brujah")) if Sim.player != null else "brujah",
		"tick": Sim.tick,
	}
	SaveSystem.save(data)


func _on_quit_to_menu() -> void:
	_exit_gameplay()
	UIManager.open_menu("main_menu")


func _on_quit_to_desktop() -> void:
	get_tree().quit()


func _enter_gameplay() -> void:
	if _in_gameplay:
		return
	_in_gameplay = true
	# Close the title screen stack (New Game / Continue started from there). Must be synchronous:
	# close() is animated by default and pops on a later tween frame, so a `while is_menu_open():
	# close_menu()` loop would spin forever in this frame and hang. close_all_menus() pops now.
	UIManager.close_all_menus()
	# Spawn the gameplay view. GameRenderer builds world/entities/camera and ticks Sim.
	_game_view = GAME_VIEW_SCENE.instantiate()
	add_child(_game_view)
	# Connect the floating-text layer's world->screen lookup to the gameplay camera.
	if _floating.has_method("set") and _game_view.has_node("CameraDirector"):
		var cam: Camera2D = _game_view.get_node("CameraDirector")
		_floating.world_to_screen = func(world_pos: Vector2) -> Vector2:
			return cam.get_screen_transform() * world_pos if cam != null else world_pos
	UIManager.show_hud(true)


func _exit_gameplay() -> void:
	if not _in_gameplay:
		return
	_in_gameplay = false
	UIManager.show_hud(false)
	if _game_view != null:
		_game_view.queue_free()
		_game_view = null
	if UIManager.is_gameplay_paused():
		UIManager.set_gameplay_paused(false)
