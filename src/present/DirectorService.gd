## DirectorService.gd — wires the merged glowup hidden-game systems into the live game (shadow mode).
##
## Presentation-side OBSERVER: it listens to CueBus and feeds the deterministic kit reference systems
## (PlayerStyleProfile now; RumorGraph + OpportunityDirector next) so the city builds a model of HOW
## the player solves problems — without touching the Sim, so replay determinism is unaffected. This is
## the REVAMP_SYNTHESIS "consequence layer" the Blood Grammar feeds.
extends Node

const StyleProfileScript := preload("res://glowup_2026/reference/PlayerStyleProfile.gd")
const RumorGraphScript := preload("res://glowup_2026/reference/RumorGraph.gd")
const OppDirectorScript := preload("res://glowup_2026/reference/OpportunityDirector.gd")
const TEMPLATES_PATH := "res://glowup_2026/content/opportunity_templates.json"

var style = null   # NightglassPlayerStyleProfile
var rumor = null   # NightglassRumorGraph — the city's decaying memory of what it witnessed
var opp = null     # NightglassOpportunityDirector — stages style-aware opportunities
var _opp_cache: Dictionary = {}
var _opp_tick: int = -100000

# CueBus event -> (method, intensity). novelty_key dampens farming via the profile's repeat penalty.
const FEED_INTENSITY := 1.0


func _ready() -> void:
	style = StyleProfileScript.new()
	rumor = RumorGraphScript.new()
	opp = OppDirectorScript.new()
	opp.configure(_load_templates())
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _load_templates() -> Array:
	if not FileAccess.file_exists(TEMPLATES_PATH):
		return []
	var f := FileAccess.open(TEMPLATES_PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Array else []


## The opportunity the city would stage next, given the player's style + pressure (cached; shadow mode).
func current_opportunity() -> Dictionary:
	if opp == null or opp.templates.is_empty():
		return {}
	var now: int = int(Sim.tick) if Sim != null else 0
	if not _opp_cache.is_empty() and now - _opp_tick < 180:
		return _opp_cache
	var ctx := _build_context(now)
	var st: Dictionary = style.normalized() if style != null else {}
	var r1: float = float(absi(hash([now / 180, "sel"])) % 1000) / 1000.0
	var r2: float = float(absi(hash([now / 180, "dif"])) % 1000) / 1000.0
	var chosen: Dictionary = opp.choose(ctx, st, r1, r2)
	var selected: Dictionary = chosen.get("selected", {})
	var tid := String(selected.get("template_id", ""))
	var result: Dictionary = {}
	for t in opp.templates:
		if String(t.get("id", "")) == tid:
			result = t
			break
	if result.is_empty():
		result = opp.templates[0]
	_opp_cache = result
	_opp_tick = now
	return result


func _build_context(now: int) -> Dictionary:
	# Provide a district carrying the union of all required tags so any template can find a home.
	var all_tags: Dictionary = {}
	for t in opp.templates:
		for tag in t.get("required_tags", []):
			all_tags[String(tag)] = true
	var exposure: float = 0.3
	var heat: float = 0.0
	if Sim != null:
		heat = clampf(Sim.heat / 6.0, 0.0, 1.0)
		if Sim.player != null:
			exposure = clampf(Sim.player.exposure / 1.3, 0.0, 1.0)
	return {
		"tick": now,
		"districts": { "old_town": { "tags": all_tags.keys(), "control": 0.5 } },
		"factions": { "anarch": { "id": "anarch", "resources": 0.6, "agenda_pressure": 0.6, "fit": 0.5 } },
		"controls": { "anarch": 0.5 },
		"relationships": { "anarch": 0.2 },
		"resources": { "condition": 1.0, "leverage": 0.3 },
		"pressure": { "exposure": exposure, "heat": heat, "debt": 0.1 },
		"player_district": "old_town",
		"resolved_opportunities": 0,
	}


func _on_cue(event_id: String, payload: Dictionary) -> void:
	if style == null:
		return
	match event_id:
		"level.loaded":
			style = StyleProfileScript.new()   # fresh model each new night
			rumor = RumorGraphScript.new()
			_opp_cache = {}
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
