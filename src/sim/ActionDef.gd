## ActionDef.gd — the frame-data schema for every player and AI action.
##
## THIS FILE IS THE DISEASE FIX.
##
## The legacy game had no frame data: the claw combo auto-incremented, soft-aimed for the
## player, and a masher produced identical DPS to a skilled player. That's why no verb had
## a skill ceiling, which is why every system built on top could only add numbers, not
## playstyle — the feature-factory disease.
##
## Every action now carries explicit frame data:
##   startup  — frames before the hitbox is live (telegraph + commitment)
##   active   — frames the hitbox is live (the connection window)
##   recovery — frames before you can act again (the punish window if whiffed)
##   cancel_into — actions that can interrupt recovery (the COMBO system)
##
## A masher eats recovery. A skilled player cancels recovery into the next input.
## That gap — measurably, repeatably, on a fixed seed — is the skill ceiling.
## (See REVAMP_SPEC §2.2 and §6 skill-gap DoD.)
##
## Each action also carries an authored hitbox SHAPE (not a radius check) and a distinct
## input grammar, so no two powers ask the same thing of the player's hands.
##
extends Resource
class_name ActionDef

@export var id: String = ""                       # unique key, e.g. "melee_light", "bolt", "dash"
@export var display_name: String = ""
@export var description: String = ""

# --- frame data (in physics ticks @ 60Hz) ---
@export var startup: int = 3
@export var active: int = 3
@export var recovery: int = 8
@export var cancel_into: PackedStringArray = []   # action ids that can interrupt recovery

# --- resource economy ---
@export var blood_cost: float = 0.0               # vitae
@export var stamina_cost: float = 0.0
@export var cooldown_ticks: int = 0               # ticks before this action can begin again

# --- input grammar (how the player triggers it) ---
@export_enum("press", "hold", "charge", "double_tap", "toggle", "aim_release") \
		var input_grammar: String = "press"

# --- geometry: authored shapes, not radius checks ---
@export var hitbox: Shape2D = null                 # set in editor or by code; for melee, a fan/arc
@export var hitbox_offset: Vector2 = Vector2.ZERO  # local offset from the actor's facing
@export var range: float = 0.0                     # for ranged/aimed actions

# --- impact (applied on a connection during the active window) ---
@export var damage: float = 0.0
@export var damage_type: String = "physical"       # physical | blood | shadow | fire | sun
@export var knockback: float = 0.0
@export var hitstop_ticks: int = 2                 # freeze BOTH attacker and victim on hit
@export var lifesteal: float = 0.0

# --- status applied on hit (empty = none) ---
@export var applies_status: Dictionary = {}        # {"bleed": {"dps": 8, "dur_ticks": 180}, ...}

# --- presentation cues (routed through CueBus) ---
@export var cue_on_startup: String = ""            # CueBus event id, e.g. "attack.slash.windup"
@export var cue_on_active: String = ""             # e.g. "attack.slash.connect"
@export var cue_on_hit: String = ""                # e.g. "attack.slash.hit"
@export var sound: String = ""                     # Audio bus sample id

# --- melee-combo chain helpers (used by SimPlayer) ---
@export var combo_next: String = ""                # natural follow-up if input timing is right
@export var combo_window_start: int = 0            # earliest tick in recovery where next can cancel
@export var combo_window_end: int = 0              # latest tick


## Total length of the action in ticks.
func total_ticks() -> int:
	return startup + active + recovery

## Is `tick_in_action` within the active (hitbox-live) window?
func is_active_at(action_tick: int) -> bool:
	return action_tick >= startup and action_tick < startup + active

## Is `tick_in_action` within the cancel window for chaining into a follow-up?
func in_combo_window(action_tick: int) -> bool:
	if combo_next == "":
		return false
	var earliest := startup + active + combo_window_start
	var latest := startup + active + combo_window_end
	return action_tick >= earliest and action_tick <= latest
