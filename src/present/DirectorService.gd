## DirectorService.gd — wires the merged glowup hidden-game systems into the live game (shadow mode).
##
## Presentation-side OBSERVER: it listens to CueBus and feeds the deterministic kit reference systems
## (PlayerStyleProfile now; RumorGraph + OpportunityDirector next) so the city builds a model of HOW
## the player solves problems — without touching the Sim, so replay determinism is unaffected. This is
## the REVAMP_SYNTHESIS "consequence layer" the Blood Grammar feeds.
extends Node

const StyleProfileScript := preload("res://glowup_2026/reference/PlayerStyleProfile.gd")

var style = null   # NightglassPlayerStyleProfile

# CueBus event -> (method, intensity). novelty_key dampens farming via the profile's repeat penalty.
const FEED_INTENSITY := 1.0


func _ready() -> void:
	style = StyleProfileScript.new()
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _on_cue(event_id: String, payload: Dictionary) -> void:
	if style == null:
		return
	match event_id:
		"level.loaded":
			style = StyleProfileScript.new()   # fresh model each new night
		"feed.kill":
			style.record_method("force", 1.0, "feed.kill")
		"feed.spare":
			style.record_method("influence", 0.9, "feed.spare")
		"feed.gulp.perfect":
			style.record_method("force", 0.4, "feed.gulp")
		"move.dash":
			style.record_method("mobility", 0.5, "dash")
		"damage.dealt":
			style.record_method("force", 0.35, "combat.hit")
		"power.cast":
			var pid := String(payload.get("power_id", ""))
			var axis := _discipline_axis(pid)
			if axis != "":
				style.record_method(axis, 0.7, "power." + pid)


func _discipline_axis(power_id: String) -> String:
	var p := power_id.split("_")[0]
	match p:
		"obf": return "stealth"          # Obfuscate — concealment
		"cel", "pro": return "mobility"  # Celerity / Protean — movement
		"bs", "aus": return "systems"    # Blood Sorcery / Auspex — tools & info
		"dom", "pre": return "influence" # Dominate / Presence — social control
		"pot", "for": return "force"     # Potence / Fortitude — direct force
	return ""


## Read-only accessors for HUD / debug.
func style_distribution() -> Dictionary:
	return style.normalized() if style != null else {}


func dominant_style() -> Dictionary:
	return style.dominant() if style != null else { "axis": "—", "share": 0.0, "entropy": 0.0 }
