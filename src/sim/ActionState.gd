## ActionState.gd — the live runtime state of an action in progress.
##
## Pairs with ActionDef (the data) — this is the per-entity "what am I doing right now"
## holder. Kept separate so the same ActionDef resource can be shared by many entities
## without per-instance data leaking.
##
extends RefCounted
class_name ActionState

var def: ActionDef
var has_connected: bool = false        # so a single active window hits each target once
var hit_targets: Array[int] = []       # entity ids already struck this active window

func _init(d: ActionDef) -> void:
	def = d

func reset_for_new_window() -> void:
	has_connected = false
	hit_targets.clear()
