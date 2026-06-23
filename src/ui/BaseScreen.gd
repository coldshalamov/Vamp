## BaseScreen.gd — common base for every full-screen UI panel.
##
## Owns: open/close tweening (reduced-motion aware), focus restoration (so keyboard /
## gamepad users resume where they were), and ui_cancel handling (close / go back).
##
## Subclasses override: `_on_opened()`, `_on_about_to_close()`, `default_focus_control()`.
## Screens must never mutate Sim state; they emit intent through UIManager callbacks.
extends Control
class_name BaseScreen

signal opened(screen: BaseScreen)
signal closed(screen: BaseScreen)

var _tween: Tween = null
var _saved_focus: Control = null
var _is_open: bool = false

@export var title: String = ""
@export var close_on_cancel: bool = true        # ui_cancel closes this screen
@export var block_gameplay_input: bool = true   # when open, gameplay verbs are suppressed

@onready var _root: Control = get_node(".")


func _ready() -> void:
	# Screens start hidden; UIManager makes them visible on open().
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


## UIManager calls this to slide the screen in. Reduced-motion => instant.
func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_saved_focus = null
	var focus := default_focus_control()
	if focus != null:
		focus.grab_focus()
	_cancel_tween()
	if _reduced_motion():
		modulate.a = 1.0
		_on_opened()
		opened.emit(self)
		return
	modulate.a = 0.0
	scale = Vector2(0.98, 0.98)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, _anim_open())
	_tween.tween_property(self, "scale", Vector2.ONE, _anim_open()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(func() -> void:
		_on_opened()
		opened.emit(self))


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_on_about_to_close()
	_cancel_tween()
	if _reduced_motion():
		visible = false
		modulate.a = 1.0
		closed.emit(self)
		UIManager.pop_screen(self)
		return
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, _anim_close())
	_tween.tween_property(self, "scale", Vector2(0.98, 0.98), _anim_close()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
		closed.emit(self)
		UIManager.pop_screen(self))


## Synchronous close — no animation, pops THIS FRAME. Used when entering gameplay so the host
## never busy-waits on a close tween. The animated close() defers the stack pop to a tween
## callback; a caller that loops `while is_menu_open(): close_menu()` would spin forever waiting
## for a pop that can't happen inside one frame (this hung the New Game button — see
## UIManager.close_all_menus / Boot._enter_gameplay).
func force_close() -> void:
	_is_open = false
	_cancel_tween()
	_on_about_to_close()
	visible = false
	modulate.a = 1.0
	closed.emit(self)
	if UIManager != null:
		UIManager.pop_screen(self)


## Remember the current focus so a nested screen can restore it when it closes.
func save_focus() -> void:
	_saved_focus = get_viewport().gui_get_focus_owner() if is_inside_tree() else null


func restore_focus() -> void:
	var target: Control = _saved_focus if _saved_focus != null else default_focus_control()
	if target != null and is_instance_valid(target):
		target.grab_focus()


# --- subclass hooks ---

func default_focus_control() -> Control:
	# Default: first focusable child. Subclasses override for explicit order.
	return _first_focusable(self)

func _on_opened() -> void:
	pass

func _on_about_to_close() -> void:
	pass


# --- input ---

func _gui_input(event: InputEvent) -> void:
	if close_on_cancel and event.is_action_pressed("ui_cancel"):
		accept_event()
		close()
	elif event.is_action_pressed("pause") and is_pause_toggle_screen():
		accept_event()
		close()


## Override to true for the PauseMenu so the pause key closes it again.
func is_pause_toggle_screen() -> bool:
	return false


# --- helpers ---

func _reduced_motion() -> bool:
	return UIManager.is_reduced_motion()

func _anim_open() -> float:
	return UIManager.theme_resource.anim_open if UIManager != null else 0.18

func _anim_close() -> float:
	return UIManager.theme_resource.anim_close if UIManager != null else 0.12

func _cancel_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null

static func _first_focusable(node: Node) -> Control:
	if node is Control:
		var c: Control = node
		if c.focus_mode != Control.FOCUS_NONE and c.visible:
			return c
	for child in node.get_children():
		var found := _first_focusable(child)
		if found != null:
			return found
	return null
