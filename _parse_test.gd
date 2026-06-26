extends RefCounted

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * 32.0, (float(cell.y) + 0.5) * 32.0)

var named_points: Dictionary = {}
var pois: Dictionary = {}
var encounter_points: Array = []

func build() -> void:
	var plaza := _cell_center(Vector2i(31, 19))
	var shop := _cell_center(Vector2i(46, 10))
	named_points = {
		"plaza": plaza,
	}
	pois = {
		"shop": shop,
	}
	encounter_points = [
		{ "template": "x", "pos": plaza },
	]

func _init() -> void:
	build()
