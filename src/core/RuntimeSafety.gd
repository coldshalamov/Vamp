extends RefCounted
class_name RuntimeSafety

const SAFE_MAX_FPS := 30
const NORMAL_MAX_FPS := 60


static func safe_mode_enabled() -> bool:
	if _truthy(OS.get_environment("VAMP_FULL_VISUALS")):
		return false
	var explicit_safe := OS.get_environment("VAMP_SAFE_MODE").strip_edges()
	if explicit_safe != "":
		return _truthy(explicit_safe)
	return false


static func launch_max_fps() -> int:
	var raw := OS.get_environment("VAMP_MAX_FPS").strip_edges()
	if raw != "":
		var fps := raw.to_int()
		if fps > 0:
			return int(clamp(fps, 15, 120))
	return SAFE_MAX_FPS if safe_mode_enabled() else NORMAL_MAX_FPS


static func apply_startup_limits() -> void:
	var fps := launch_max_fps()
	if fps > 0:
		Engine.max_fps = fps
	if safe_mode_enabled():
		print("[RuntimeSafety] Reduced visual profile active: FPS capped and optional presentation systems disabled.")
	else:
		print("[RuntimeSafety] Normal game profile active: full presentation enabled, FPS capped at ", fps, ".")


static func _truthy(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	return normalized in ["1", "true", "yes", "on", "full"]
