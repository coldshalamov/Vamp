## TutorialDirector.gd — gentle one-time onboarding prompts.
##
## Lives under UIManager (a plain Node child of the UIManager CanvasLayer). Surfaces a short,
## calm sequence of tutorial hints, each shown EXACTLY ONCE and never repeated. There is no
## timer and no urgency: prompts are routed through UIManager.show_notification / show_banner
## and the player can ignore them freely.
##
## Each hint is gated by a permanent `has_seen_*` boolean. Two of them are condition-polled in
## _process (first spawn, near first NPC); the rest fire from CueBus cues. Flags are IN-SESSION
## only (not persisted). This single instance lives under UIManager for the whole app session, so
## the hints show once per LAUNCH: they re-arm after relaunching the app, but a second New Game in
## the same session keeps the already-flipped flags and stays quiet (intended for a single-night
## slice). Persisting to user:// could be layered on later without touching the cue wiring.
##
## Like every overlay under UIManager, this NO-OPs whenever Sim == null or Sim.player == null so
## it never fires over the main menu / title screen.
extends Node
class_name TutorialDirector

## How close (world units) the player must get to a living feedable NPC to surface the feed hint.
const FEED_HINT_RANGE: float = 90.0
const FEED_HINT_RANGE_SQ: float = FEED_HINT_RANGE * FEED_HINT_RANGE

# One permanent gate per hint. Each flips true the first time its condition holds and never resets.
var has_seen_spawn: bool = false        # #1 gameplay begins
var has_seen_feed_hint: bool = false    # #2 near first feedable NPC
var has_seen_first_feed: bool = false   # #3 after first feed
var has_seen_first_ability: bool = false # #4 after first ability cast
var has_seen_first_combo: bool = false  # #5 after first combo
var has_seen_first_kill: bool = false   # #6 after first kill


func _ready() -> void:
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)


func _process(_delta: float) -> void:
	# No-op over the title screen / between runs.
	if Sim == null or Sim.player == null:
		return
	# #1 — first spawn: the player entity now exists for the first time.
	if not has_seen_spawn:
		has_seen_spawn = true
		_notify("You're hungry. Find someone to feed on.", _color_calm())
		return  # one prompt per frame keeps the onboarding unhurried
	# #2 — near first feedable NPC. Gated behind #1 so it never precedes the opener.
	if not has_seen_feed_hint and _near_feedable_npc():
		has_seen_feed_hint = true
		_notify("Hold [F] to feed", _color_calm())


# ---------------------------------------------------------------- cue handlers

func _on_cue(event_id: String, _payload: Dictionary) -> void:
	# Cue-driven hints still no-op without an active run (cues only fire in-game, but guard anyway
	# so a stray emit on the title screen can't surface a prompt).
	if Sim == null or Sim.player == null:
		return
	match event_id:
		"feed.end", "feed.spare", "feed.kill":
			# #3 — after first feed (any feed outcome counts).
			if not has_seen_first_feed:
				has_seen_first_feed = true
				_notify("Blood is your power. Use abilities with [1-5].", _color_calm())
		"power.cast":
			# #4 — after first ability cast.
			if not has_seen_first_ability:
				has_seen_first_ability = true
				_notify("Combine abilities for bonus damage. Try bleeding, then bolting.", _color_calm())
		"combo.trigger":
			# #5 — after first combo.
			if not has_seen_first_combo:
				has_seen_first_combo = true
				_notify("Nice! Experiment with different combinations.", _color_calm())
		"kill", "npc.death", "enemy.death":
			# #6 — after first kill. Multiple death aliases can fire for one kill; the flag makes
			# this idempotent regardless of which arrives first.
			if not has_seen_first_kill:
				has_seen_first_kill = true
				_notify("+XP for the kill. Slay and feed to level up.", _color_calm())


# ---------------------------------------------------------------- helpers

## True when a living, feedable NPC is within FEED_HINT_RANGE of the player. Non-hostile NPCs are
## preferred (a calmer first feed), but any living npc qualifies so the hint always lands.
func _near_feedable_npc() -> bool:
	var player := Sim.player
	if player == null:
		return false
	var ppos: Vector2 = player.pos
	var fallback_in_range: bool = false
	for e in Sim.entities:
		if e == null or e == player:
			continue
		if e.kind != "npc" or e.dead:
			continue
		if ppos.distance_squared_to(e.pos) > FEED_HINT_RANGE_SQ:
			continue
		if not e.hostile_to_player:
			return true            # ideal: a calm, non-hostile target nearby
		fallback_in_range = true   # a hostile npc is still feedable; remember it
	return fallback_in_range


func _notify(text: String, color: Color) -> void:
	if UIManager != null:
		UIManager.show_notification(text, color)


## A soft, low-urgency tint for tutorial toasts (theme-driven when available).
func _color_calm() -> Color:
	if UIManager != null:
		return UIManager.theme_get_color("text_muted", "UITheme", Color(0.82, 0.84, 0.92, 1.0))
	return Color(0.82, 0.84, 0.92, 1.0)
