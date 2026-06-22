## PowerCatalog.gd -- compatibility facade for Discipline data.
##
## Full static gameplay data lives in GameCatalog. This class preserves the older
## backend-slice API used by SimPlayer and tests.
extends RefCounted
class_name PowerCatalog

const Catalog := preload("res://src/data/GameCatalog.gd")

static func ids() -> Array:
	var out := Catalog.POWERS.keys()
	for alias in Catalog.LEGACY_POWER_ALIASES:
		if not out.has(alias):
			out.append(alias)
	return out

static func get_def(power_id: String) -> Dictionary:
	var id := Catalog.canonical_power_id(power_id)
	if not Catalog.POWERS.has(id):
		return {}
	var rec := (Catalog.POWERS[id] as Dictionary).duplicate(true)
	rec["id"] = id
	return rec
