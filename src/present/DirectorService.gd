## DirectorService.gd — wires the merged glowup hidden-game systems into the live game (shadow mode).
##
## Presentation-side OBSERVER: it listens to CueBus and feeds the deterministic kit reference systems
## (PlayerStyleProfile now; RumorGraph + OpportunityDirector next) so the city builds a model of HOW
## the player solves problems — without touching the Sim, so replay determinism is unaffected. This is
## the REVAMP_SYNTHESIS "consequence layer" the Blood Grammar feeds.
extends Node

const StyleProfileScript := preload("res://glowup_2026/reference/PlayerStyleProfile.gd")
const RumorGraphScript := preload("res://glowup_2026/reference/RumorGraph.gd")

var style = null   # NightglassPlayerStyleProfile
var rumor = null   # NightglassRumorGraph — the city's decaying memory of what it witnessed

# CueBus event -> (method, intensity). novelty_key dampens farming via the profile's repeat penalty.
const FEED_INTENSITY := 1.0


func _ready() -> void:
	style = StyleProfileScript.new()
	rumor = RumorGraphScript.new()
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _on_cue(event_id: String, payload: Dictionary) -> void:
	if style == null:
		return
	match event_id:
		"level.loaded":
			style = StyleProfileScript.new()   # fresh model each new night
			rumor = RumorGraphScript.new()
		"feed.kill":
			style.record_method("force", 1.0, "feed.kill")
			_witnessed("feed", payload.get("pos", Vector2.ZERO), "feed.kill")
		"masquerade.broken":
			_witnessed("violence", payload.get("pos", Vector2.ZERO), "masquerade")
		"humanity.lost":
			_witnessed("kill", payload.get("pos", Vector2.ZERO), "humanity.lost")
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


## A witnessable act: nearby civilians who can see it form decaying claims about the predator.
## Cloaked acts read as "unknown" identity; exposure drives visibility. Shadow mode — display only.
func _witnessed(method: String, pos: Vector2, cue: String) -> void:
	if Sim == null or rumor == null:
		return
	var tick: int = int(Sim.tick)
	var exposure: float = 0.6
	var cloaked: bool = false
	if Sim.player != null:
		exposure = clampf(Sim.player.exposure / 1.3, 0.0, 1.0)
		cloaked = bool(Sim.player.tags.get("cloaked", false))
	var ev := {
		"event_id": "%s_%d" % [cue, tick],
		"actor_id": "player",
		"district_id": "old_town",
		"visibility": exposure,
		"method": method,
		"identity_key": "unknown" if cloaked else "the_predator",
		"identity_ambiguity": 0.65 if cloaked else 0.15,
		"tags": [],
	}
	var seen: int = 0
	for e in Sim.entities:
		if e == null or e.dead or e.kind != "npc" or e.faction != "civ":
			continue
		if e.pos.distance_to(pos) > 280.0:
			continue
		rumor.observe_event(ev, { "id": "npc_%d" % e.id, "attention": 0.55, "stress": 0.25, "fear": 0.2 }, tick)
		seen += 1
		if seen >= 8:
			break
	rumor.decay(0.01, tick)


func rumor_belief() -> Dictionary:
	if rumor == null:
		return { "trust": 0.0, "fear": 0.0, "awareness": 0.0 }
	return rumor.faction_summary(rumor.claims_by_holder.keys())


func rumor_claims() -> int:
	var n := 0
	if rumor != null:
		for k in rumor.claims_by_holder:
			n += (rumor.claims_by_holder[k] as Array).size()
	return n


## Read-only accessors for HUD / debug.
func style_distribution() -> Dictionary:
	return style.normalized() if style != null else {}


func dominant_style() -> Dictionary:
	return style.dominant() if style != null else { "axis": "—", "share": 0.0, "entropy": 0.0 }
