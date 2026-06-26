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
const FEEDING_HUD_SCRIPT := preload("res://src/ui/FeedingHUD.gd")
const PROGRESSION_HUD_SCRIPT := preload("res://src/ui/ProgressionHUD.gd")
const THREAT_ARROWS_SCRIPT := preload("res://src/ui/OffscreenThreatArrows.gd")
const TUTORIAL_SCRIPT := preload("res://src/ui/TutorialDirector.gd")
const RuntimeSafetyScript := preload("res://src/core/RuntimeSafety.gd")

var _game_view: Node2D = null
var _hud: Control = null
var _notifs: Control = null
var _captions: Control = null
var _floating: Control = null
var _feeding_hud: Control = null
var _progression_hud: Control = null
var _threat_arrows: Control = null
var _tutorial: Control = null
var _in_gameplay: bool = false


func _ready() -> void:
	RuntimeSafetyScript.apply_startup_limits()
	# Ship hygiene: drop Godot's automatic "(DEBUG)" suffix so the window reads "Vampire City".
	get_window().title = "Vampire City"
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
	# The four gameplay-feel overlays that were built as files but never mounted — same disease
	# as WorldIndicatorLayer. They're full-rect Controls that listen to CueBus and read Sim, so
	# mounting them under the UIManager canvas is all that was missing. Order matters: feed meter
	# and XP bar sit above gameplay, arrows above the HUD, tutorial prompts on top of everything.
	_feeding_hud = _mount_overlay(FEEDING_HUD_SCRIPT)
	_progression_hud = _mount_overlay(PROGRESSION_HUD_SCRIPT)
	_threat_arrows = _mount_overlay(THREAT_ARROWS_SCRIPT)
	# TutorialDirector is a logic-only Node (drives toasts via UIManager), not a Control — mount
	# it bare, without the full-rect anchor preset that only Control supports.
	_tutorial = Node.new()
	_tutorial.set_script(TUTORIAL_SCRIPT)
	UIManager.add_child(_tutorial)

	# HUD starts hidden; we show it when gameplay begins.
	_hud = HUD_SCENE.instantiate()
	UIManager.add_child(_hud)
	UIManager.show_hud(false)

	# Title screen first (acceptance criterion #1: boots to MainMenu).
	UIManager.open_menu("main_menu")


# ---------------------------------------------------------------- flow

## Instantiate a full-rect Control overlay from a script (mirrors the FloatingText pattern).
## Used for the gameplay-feel overlays (feeding meter, XP bar, threat arrows, tutorial) that exist
## as scripts but have no .tscn — they were built but never mounted, which is why they never showed.
func _mount_overlay(script: GDScript) -> Control:
	var node := Control.new()
	node.set_script(script)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	UIManager.add_child(node)
	return node


func _on_new_game() -> void:
	Sim.new_game(42, "brujah", true)   # populated: a living block for the playable night
	Sim.set_difficulty(UIManager.selected_difficulty)
	_enter_gameplay()


func _on_continue_game() -> void:
	# Load the full persisted run and restore it into the Sim. restore_run() re-seeds via
	# new_game(), then layers the saved run scalars + meta back on top, so the authoritative
	# state matches the save. If there is no save (or it is corrupt/empty), restore_run()
	# returns false WITHOUT building a world — fall back to a fresh game so gameplay still
	# boots clean against a valid Sim (player/world non-null).
	var data := SaveSystem.load()
	if not Sim.restore_run(data):
		var seed_value := int(data.get("seed", 42))
		var clan := String(data.get("clan", "brujah"))
		Sim.new_game(seed_value, clan)
	# Entering gameplay (re)builds GameRenderer, which re-syncs the scene tree to whatever
	# entities the Sim now holds — restored or freshly spawned.
	_enter_gameplay()


func _on_save_game() -> void:
	# Persist the FULL run: run scalars (seed, rng, tick, heat, investigations, ...) plus the
	# whole meta backend (level/xp/money/skill tree/inventory/coterie/domains/...). seed/clan
	# are mirrored at the top level too so a corrupt/partial save can still seed a fallback
	# new_game() in _on_continue_game without parsing the nested meta block.
	var data := Sim.serialize_run()
	data["seed"] = Sim.seed_value
	data["clan"] = String(Sim.meta.clan_id) if Sim.meta != null else "brujah"
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
