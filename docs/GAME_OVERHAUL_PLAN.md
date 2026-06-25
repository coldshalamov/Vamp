# GAME OVERHAUL PLAN — From Prototype to Playable

> **Why the last plan failed:** MASTER_PLAN.md was 150 ideas fanned to parallel agents. Each agent
> shipped its feature in isolation. The result: 109 green tests, zero fun. This plan is organized
> differently: **one playable vertical slice built end-to-end first**, then breadth. Every feature
> names the fun-principle it serves and the reference game it steals from. Nothing ships until it's
> been PLAYED by a human in a windowed build — green tests are necessary but not sufficient.

---

## Part 1 — Design Philosophy (Why Games Are Fun)

These principles were extracted from analyzing Diablo, WoW, VtM:Bloodlines, Hades, GTA, Dark
Souls, Path of Exile, Age of Conan, and Star Wars: Force Unleashed. Every feature in this plan
traces back to one or more of these.

### P1: Fun = Decisions Per Second
The WoW combat loop is a nonstop decision chain: debuff → DoT → charged spell while safe →
instant to start cooldown → AoE knockback when they close → charge again during stun → heal
during window. Every SECOND the player chooses. A game with 1 decision per 30 seconds ("walk
toward thing, press F") is not a game — it's a screensaver with input.

### P2: Depth From Combinatorial Primitives
Chess has 6 piece types and infinite strategy. Diablo has ~5 spell shapes × ~6 effect types and
thousands of builds. You don't need 100 spells — you need 12 that COMBINE in 100 ways. The
player discovering "wait, if I root them THEN cast the charged spell..." IS the fun. The
primitives: **shapes** (single target, cone, AoE, line, self) × **types** (damage, DoT, heal,
buff, debuff, CC) × **cast mechanics** (instant+cooldown, channeled, charged+interruptible) ×
**combo triggers** (bonus if target has status X).

### P3: Resources Create Tension
Unlimited mana = spam best spell = no decisions. Scarce mana means EVERY cast is a choice: "Do I
blow my blood on this fight or save it? Heal now or tough it out? Big AoE or save for escape?"
Blood must be scarce enough that running dry is real, making FEEDING the reload mechanic — fight
until empty, find prey, refuel, fight harder things.

### P4: Enemies Must Be Puzzles, Not Furniture
Identical enemies = no decisions. A pack with a healer in back, tank in front, and shooter on
the flank = "kill the healer first, CC the tank, kite the shooter." Different compositions =
different solutions = you're THINKING. (Diablo elite packs, WoW dungeon pulls, Hades room
compositions.)

### P5: Readable State Enables All Strategy
You cannot strategize if you can't tell what's happening. Required: damage numbers on hits,
status effect icons on enemies (burning/stunned/bleeding), clear cooldown timers, enemy telegraph
before attacks (wind-up glow/animation), health bars that chunk on hit, death explanation. This
game currently communicates NOTHING — the player dies without knowing why.

### P6: Layered Time Horizons Of Fun
The game must be engaging at every timescale:
- **Millisecond**: smooth animations, reactive controls, readable body language (Age of Conan)
- **Second**: which spell do I cast given mana/cooldowns/enemy state? (WoW/Diablo)
- **Minute**: how do I approach this encounter? Stealth? Rush? Lure? (VtM, Deus Ex)
- **Hour**: which skills do I level? What gear? What professions? (WoW, PoE)
- **Session**: which zone? Which boss? What build this run? (Diablo, Hades)

### P7: Sandbox Freedom Creates Ownership
GTA: ignore missions, steal cars, fight cops, explore. WoW: ignore quests, farm professions,
PvP. The player must feel they're writing their own story, not following a script. Timed
contracts on frame 1 = the opposite. The world should be a playground with optional objectives,
not a railroad.

### P8: Feeding Is The Power Loop
Feeding should be: low on blood → find prey → drain them → POWERED UP → fight with full mana.
Humanity loss comes from KILLING, not from feeding. The choice: drain partially (safe, less
blood) vs. drain fully (risk killing them, more blood, humanity cost). Feeding is the REWARD
loop, not a punishment. (VtM:Bloodlines — feeding feels dangerous and powerful, not bureaucratic.)

### P9: The Vampire Power Fantasy
You are a supernatural predator. Every system should reinforce this: you're faster, stronger,
deadlier than any human. The FUN is using that power strategically while managing the risk of
exposure. Dominate to lure prey, Presence to terrify, Obfuscate to vanish, Potence to crush.
Each discipline is a different flavor of "I am the apex predator" — not "a circle appeared."

---

## Part 2 — Full Vision (Ambitious, Prunable)

Everything that would make this game great. Ordered by principle, not priority. The user said
"err on the side of ambition, we can take things out."

### Combat System [P1, P2, P3]

**Spell primitive matrix** — the core combinatorial engine:

| Primitive | Options | Example |
|-----------|---------|---------|
| Shape | single target, cone, AoE circle, line/beam, self-buff, ground-placed | Cone: Presence Dread hits everything in a frontal wedge |
| Effect type | direct damage, DoT (damage over time), HoT (heal over time), buff self, debuff enemy, CC (stun/root/slow/knockback/fear/confuse/mesmerize), mark | DoT: Blood Sorcery Bleed ticks damage for 10s |
| Cast mechanic | instant (has cooldown), channeled (hold button, drains mana/sec), charged (hold to power up, release to fire, damage interrupts charge) | Charged: Potence Quake — hold to charge, release to slam. Getting hit during charge loses charge. Creates tactical windows. |
| Combo trigger | "If target has [status], this ability does [bonus]" | "If target is bleeding, Blood Bolt detonates all bleed stacks for burst AoE damage." "If target is stunned, next melee attack is a guaranteed crit Execute." |
| Resource cost | blood (primary mana), health (desperate/Tremere), cooldown (time) | Every cast costs blood. Running dry = must feed to reload. |

**Melee as the out-of-mana fallback** [P3, Diablo]:
Click attacks are free but weak. Spells are strong but cost blood. Gameplay oscillates: "I have
blood → cast strategically" ↔ "I'm dry → click and dodge until I can feed." This creates the
Diablo rhythm where basic attacks matter early/when resource-starved.

**Positional combat** [P1, Age of Conan, Dark Souls]:
- Backstab: +50% damage from behind (visible indicator when in position)
- Flanking: attacks from the side bypass shield/block
- Stealth opener: first attack from stealth does 2× damage, some abilities are stealth-only
- Height advantage: attacks from above (rooftop → street) do bonus damage + knockdown
- Environmental weapons: throw dumpsters with Potence, rip lamp posts, impale on fences
  (Star Wars Force Unleashed — the world is your weapon)

**Combo discovery examples** — these are what make the player THINK:
- Root (shadow tendril) → Charged spell (Potence Quake) = free charge time, huge damage
- Bleed (Blood Bolt) → Bleed Burst (Blood Storm) = detonates all bleed for AoE
- Mark (Auspex) → Execute (melee finisher) = 4× damage on marked+low-HP target
- Mesmerize (Dominate) → Feed = drain mesmerized target without struggle, double blood
- Fear (Presence Dread) → Backstab = feared enemies turn and run, exposing their backs

### Enemy Design [P4, P5]

**Archetypes** (each demands different tactics):

| Type | Behavior | Player Response | Reference |
|------|----------|-----------------|-----------|
| Rusher | Sprints at you, melee spam, low HP | AoE/kite/knockback | Diablo fallen |
| Tank | Slow, armored, shield blocks frontal | Flank or DoT or CC-and-bypass | WoW warrior mob |
| Shooter | Ranged, kites backward, low HP | Close gap with dash, interrupt | Diablo succubus |
| Healer | Stays behind tanks, heals allies | Kill first (priority target) | WoW priest mob |
| Summoner | Spawns minions, weak alone | Burst down before overwhelmed | Diablo necro mob |
| Ambusher | Stealths, attacks from behind | Auspex reveals, AoE flush | Skyrim assassin |

**Telegraphed attacks** [P5, Dark Souls]:
Every enemy heavy attack has a visible wind-up: 0.3-0.5s where the enemy glows/pulls back/
charges. The player reads this and decides: dodge, interrupt, block, or tank it. This creates
millisecond-level reactivity. Light attacks are faster but weaker — no telegraph needed.

**Group compositions as puzzles** [P4]:
Encounters are DESIGNED, not random: "Tank + Healer + 2 Rushers" = kill healer, CC tank, AoE
rushers. "Sniper + 3 Ambushers" = Auspex reveals ambushers, dash to sniper. Each composition
is a different puzzle with multiple valid solutions.

**Resistances/weaknesses** [P2, Diablo/WoW]:
Fire-resistant enemies (use shadow), CC-immune bosses (use DoT + kiting), shadow-immune
hunters (use physical + fire). Forces skill tree diversification — can't dump all points
into one element.

### Feeding & Blood Economy [P3, P8]

**Feeding as the core power loop:**
1. Fight until blood (mana) runs low
2. Disengage, find a victim (isolated human)
3. Approach: stealth ambush, Dominate lure, or Presence charm
4. Drain: visible blood meter filling, victim animation (struggle → weaken → limp)
5. CHOICE POINT: stop early (partial blood, victim lives, safe) or drain fully (max blood,
   might kill them, humanity risk)
6. Killing = humanity loss. Feeding ≠ humanity loss. The CHOICE to kill is the moral weight.
7. Return to combat POWERED UP: full blood, cast freely, feel the vampire power fantasy

**Blood resonance as build fuel** [P2, VtM]:
Different victims have different blood flavors visible as colored auras:
- Sanguine (red): +combat damage for 2 min
- Choleric (orange): +ability power for 2 min
- Melancholic (blue): +stealth/perception for 2 min
- Phlegmatic (green): +healing/regen for 2 min

You HUNT specific prey types for your build: a Brujah brawler hunts Sanguine for damage, a
Nosferatu stalker hunts Melancholic for stealth. Feeding becomes strategic, not just "hold F
on nearest human."

**Non-combat feeding approaches** [P7, VtM]:
- Dominate: mind-control a human, walk them to an alley, drain privately
- Presence: charm a group, feed on one while others are entranced
- Obfuscate: go invisible, feed without anyone seeing
- Brute force: grab someone on the street (fast but witnesses → heat)
Each approach is a different GAMEPLAY LOOP with different risk/reward.

### Progression [P6]

**Skill tree with mechanical changes, not stat buffs** [PoE, Diablo]:
Each power has 3 upgrade paths that change HOW it works:

Example — Blood Bolt:
- Path A "Hemorrhage": Blood Bolt now applies 10s bleed DoT (enables bleed-burst combos)
- Path B "Scatter Shot": Blood Bolt splits into 3 weaker bolts (AoE clear)
- Path C "Siphon": Blood Bolt returns 30% damage as blood (sustain)

Each path creates a different playstyle. The player thinks: "Which path synergizes with my
other abilities?" That thinking IS the hour-level fun.

**Gear with build-defining effects** [Diablo, PoE]:
Not "+2 armor." Instead:
- Cloak of the Night Stalker: stealth attacks apply 5s bleed
- Ring of Conflagration: killing a burning enemy refunds 20 blood
- Amulet of the Beast: Frenzy mode also grants +30% lifesteal
Each item suggests a BUILD: "If I have the conflagration ring, I should invest in fire spells
and kill burning enemies to sustain my blood." The gear creates the build conversation.

**Professions/trades** [P6, WoW]:
Pick 2 of:
- **Blood Alchemy**: craft potions from harvested blood (healing potions, damage potions, fire
  bombs, buff elixirs). Strategy: self-sufficiency, save money, powerful consumables.
- **Shadow Forge**: craft gear from harvested darkness + enemy drops. Strategy: best-in-slot
  gear without relying on RNG drops.
- **Thrall Mastery**: dominated NPCs are stronger, last longer, can be assigned to gather
  resources or guard territory. Strategy: action-economy advantage, passive income.
- **Occult Inscription**: craft blood sigils that act as traps/wards. Strategy: area denial,
  defensive play, preparation-based gameplay.

### Sandbox & Open World [P7]

**Multiple districts with identity** [GTA, VtM]:
- Old Town: narrow alleys, easy stealth, weak civilians, low heat
- Docks: open spaces, gang territory, medium enemies, moderate heat
- Red Row: nightlife district, dense crowds, good feeding, witnesses everywhere
- Financial: wide streets, police presence, strong enemies, high heat response
- Underground: sewers, vampire politics, elders, no sunlight risk
Each district has different enemy types, feeding opportunities, and challenges.

**NPC routines** [Skyrim, VtM]:
Humans walk between locations, enter buildings, gather in groups, react to events. A lone
human walking home at night is a feeding opportunity. A crowd on a busy street is dangerous.
NPCs go inside at dawn (fewer targets). This creates emergent gameplay — the world moves
whether you interact or not.

**Heat as emergent sandbox fun** [GTA]:
Cause chaos → police respond → fight or flee → hunters arrive → helicopter → escalation.
Heat is FUN when you choose it, not when it's forced. Stars on the HUD, visible response
force, the player decides whether to run or double down.

**Environmental interaction** [Star Wars, Deus Ex]:
- Throw enemies off buildings with Potence (instant kill, no blood gained — tradeoff)
- Rip lamp posts as melee weapons
- Throw dumpsters to block alleys or crush enemies
- Break through walls/doors with strength
- Use fire hydrants to create water hazards (vampires are weak to running water)
- Dark alleys give stealth bonus, rooftops give range advantage
- Cars can be hijacked for travel and combat

**The Beast / Frenzy as emergent risk** [VtM]:
High hunger → screen subtly pulses red, controls get twitchier, attack damage increases.
Starve completely → you LOSE CONTROL, auto-attack nearest human, potential masquerade
breach and humanity loss. Creates real tension: "One more fight or feed NOW?"

**Vampire senses** [Batman Arkham, Witcher]:
Hold a button → world shifts to "blood vision." Heartbeats pulse through walls (find hidden
victims), blood trails glow (track wounded prey), traps/dangers highlight. Both a COOL visual
and a gameplay tool for hunting and exploration.

### Atmosphere & Visual Identity [P5, P6]

**Rain as constant atmosphere** — falling particles, puddle reflections, splashes on impact.
Instant noir mood. (Blade Runner, VtM:Bloodlines Santa Monica)

**Neon and contrast** — dark streets punctuated by colored neon. Red for danger zones, blue for
haven, amber for neutral. The lighting TELLS you about the world.

**Dynamic shadows** — buildings cast real shadows via LightOccluder2D. Shadows = stealth
advantage. Light pools = danger zones. The player reads the lighting for tactical info.

**Blood as persistent world-state** — kills leave blood pools that persist. Your own spells
spill blood. Blood on the ground IS the world telling the story of the fight. (Already in
the sim via SimWorld.blood/fire grids — just needs visual expression.)

**Dawn gradient** — as the night progresses, the sky slowly shifts. The eastern horizon warms.
This is the clock the player READS without a HUD timer. Urgency comes from atmosphere, not
from a countdown screaming at you.

---

## Part 3 — The Vertical Slice (Execution Priority)

**Before any breadth, build the first 5-10 minutes end-to-end and PLAY them.**

The vertical slice is the unit of done. Everything else is theory until this feels good.

### Minute 0-1: Calm Start (currently broken)
- Remove timed contract on game start
- Player wakes in an alley. Rain falling. Distant city sounds.
- Brief text: "You're hungry. Find someone to feed on."
- No timer. No demands. Player discovers movement naturally.
- Waypoint on minimap: general direction of "populated area"

### Minute 1-3: First Feed (currently terrible)
- See a human walking alone (NPC with visible route, not frozen in place)
- Approach. Prompt: "Hold F to feed" appears when close enough.
- FEEDING EXPERIENCE: Camera tightens slightly. Blood meter fills visibly over 3-4 seconds.
  Victim animation: surprise → struggle → weaken → go limp. Player character leans in.
  Sound: heartbeat rising, wet drain, then slowing heartbeat as victim weakens.
- CHOICE POINT at ~70% drained: "Release [F] to spare / Hold to drain fully"
  - Spare: victim stumbles away dazed. +70 blood. No humanity loss. Safe.
  - Drain fully: victim collapses. +100 blood. "Humanity decreased." World slightly desaturates.
    But you have MORE POWER.
- After feeding: "+70 Blood" popup. Blood bar visibly full. Powers are now available.
  The player FEELS the reward.

### Minute 3-5: First Power Use (currently "a circle appeared")
- Prompt: "Press 1 to use Quicken (Celerity Dash)"
- Player dashes — BLUR across the street with speed lines and afterimage trail
- "That was cool. What else?" Natural curiosity about other powers.
- Try Earthshock (Potence) — slam the ground, visible shockwave, nearby objects scatter
- Each ability LOOKS and FEELS completely different

### Minute 5-8: First Combat (currently "click on thing near you")
- Two thugs spot you (exclamation mark above heads, "Hey!" bark)
- They approach — one rushes (melee), one hangs back (ranged)
  DIFFERENT BEHAVIOR = you have to think about approach
- Thugs telegraph heavy attacks (glow + wind-up animation, 0.3s)
- Player dodges, attacks. Damage numbers pop up. Enemy staggers. Blood sprays.
- Kill first thug: ragdoll, blood pool, small XP popup, maybe an item drops
- Kill second thug: same feedback
- Player feels: "That was a fight. I made decisions. I won because I played well."

### Minute 8-10: First Combo Discovery (currently nonexistent)
- Encounter a tougher group: tank + 2 rushers
- Player discovers: "If I stun the tank with Earthshock, then attack, it does bonus damage"
- Visual feedback: "STUNNED!" on enemy → "COMBO: ×2 DAMAGE" on the bonus hit
- Player's brain: "Oh wait — if I bleed them with Blood Bolt first, THEN stun, THEN hit..."
- THIS is when the game becomes a strategy game, not a clicker

### Minute 10+: The Night Opens Up
- Waypoint: "Reach your haven before dawn" — clear goal, no timer (yet)
- The city is open. Multiple paths. Different districts. Optional encounters.
- Player explores at their own pace, feeding to refuel, fighting to gain XP
- Dawn pressure builds through ATMOSPHERE (sky brightening), not a screaming HUD timer
- The player is now PLAYING THE GAME by choice, not following a script

---

## Part 4 — CueBus Event Contract

The two parallel tracks (Visual + Gameplay) meet at the CueBus seam. This contract MUST be
agreed before agents diverge, or they'll ship mismatched event names (this already happened:
`feed.gulp.perfect` vs `feed.gulp_perfect` is in the code right now).

### Combat Events
```
attack.start       { entity_id, pos, action_id, startup_frames, active_frames }
attack.telegraph    { entity_id, pos, direction, wind_up_ms }    # NEW: enemy tells
hit.connect         { entity_id, target_id, pos, dir, damage, crit, damage_type, status_applied }
damage.dealt        { entity_id, target_id, amount, pos, crit, damage_type, overkill }
damage.player       { attacker_id, amount, pos, damage_type }
combo.trigger       { entity_id, target_id, combo_name, bonus_damage, pos }  # NEW
kill                { killer_id, target_id, pos, xp_gained, drops[] }         # NEW
```

### Feeding Events
```
feed.start          { entity_id, target_id, pos }
feed.progress       { entity_id, target_id, progress_pct, blood_gained }      # NEW: continuous
feed.gulp           { entity_id, pos, window_size, phase }
feed.gulp.perfect   { entity_id, pos, bonus_vitae }
feed.gulp.miss      { entity_id, pos, forfeit }
feed.choice         { entity_id, target_id, can_spare: bool, blood_pct }      # NEW
feed.spare          { entity_id, target_id, pos, blood_gained, humanity_kept }
feed.kill           { entity_id, target_id, pos, blood_gained, humanity_lost }
feed.end            { entity_id, blood_total }
```

### Status & Combo Events
```
status.applied      { target_id, status, duration, source_id }               # NEW
status.expired      { target_id, status }                                     # NEW
status.detonated    { target_id, status, bonus_damage, pos }                  # NEW: combo burst
```

### Enemy State Events
```
enemy.alert         { entity_id, pos, alert_level: "noticed|alarmed|hostile" } # NEW
enemy.telegraph     { entity_id, pos, attack_type, direction, wind_up_ms }     # NEW
enemy.flee          { entity_id, pos, reason }
enemy.search        { entity_id, pos, phase }
enemy.death         { entity_id, pos, death_type, killer_id }                 # NEW: death anim
```

### Player State Events
```
player.level_up     { level, skill_points, pos }                              # NEW
player.xp_gain      { amount, source, pos }                                   # NEW
player.loot         { item_id, rarity, pos }                                  # NEW
player.death        { cause, killer_id, pos, explanation }                    # NEW: death screen
humanity.changed    { old_val, new_val, reason }
blood.changed       { old_val, new_val, reason }                              # NEW
```

### World Events
```
masquerade.breach   { pos, witnesses, heat_added, stars }
heat.changed        { old_stars, new_stars }
dawn.warning        { minutes_remaining, sky_color }
dawn.arrived        { }
```

---

## Part 5 — The Three Tracks

### Track A: Visual Engine (PARALLEL with Track B)
**Files:** `src/present/`, `assets/`, `shaders/`, `tools/visual/`
**Principle:** Make the player SEE what's happening [P5, P6 millisecond level]

#### A1: Guaranteed Visual Wins (no technical risk, massive impact)
1. **Character rim-light / outline shader** — 1-2px bright edge on all characters so they pop
   from the dark ground. Like Hades. Apply as CanvasItem shader on every rig.
   _Reference: Hades, Dead Cells — characters are ALWAYS readable against any background._

2. **Hit flash shader** — character material goes white for 2-3 frames on taking damage.
   Universal "I got hit" signal. Apply via shader uniform toggle.
   _Reference: every game ever. This is table stakes._

3. **GPUParticles2D system** — replace ALL draw_circle/draw_arc effects:
   - Blood spray: directional burst on hit (red particles, gravity, splatter on ground)
   - Rain: constant falling particles across the viewport + splash particles on ground
   - Death dissolve: character breaks into particles that scatter (not "entity vanishes")
   - Spell effects: fire embers, shadow wisps, blood droplets, electric sparks per discipline
   - Dust/debris on impacts, footstep puffs, dash trail particles
   - Ambient: floating motes, steam from grates, smoke from fires
   _Reference: Vampire Survivors — simple art + good particles = looks great._

4. **LightOccluder2D on buildings** — walls cast real 2D shadows. Shadows = stealth zones.
   Light pools = danger. The lighting becomes TACTICAL information.
   _Reference: Monaco, Mark of the Ninja — light/shadow as gameplay._

5. **Screen-space effects** — BackBufferCopy + ShaderMaterial:
   - Vignette (constant subtle dark edges, stronger when hurt)
   - Bloom on light sources (neon signs GLOW, streetlamps bleed)
   - Damage vignette (screen edges pulse red when hit)
   - Chromatic aberration on big impacts (brief, punchy)
   _Reference: Resident Evil, any AAA game — "free" atmosphere._

6. **Parallax city backdrop** — ParallaxBackground with distant building silhouettes,
   water towers, moon, clouds. Creates sense of a city beyond the play area.
   _Reference: Dead Cells, Hollow Knight — parallax = instant depth._

#### A2: World Depth
7. **TileMapLayer world rendering** — replace the draw_rect-per-tile loop with proper
   Godot TileMapLayer. Multiple layers: ground, road markings, detail (puddles/cracks/
   debris), walls (building facades with windows that glow warm), foreground (signs,
   awnings, railings that overlap the player). Autotiling for proper edges.

8. **Building facades** — buildings are not black voids. They have:
   - Window grid with warm interior glow (some lit, some dark)
   - Fire escapes, signage, awnings
   - Graffiti, posters, air conditioning units
   - Rooftop edges visible from the top-down angle
   Drawn as authored tiles or procedural from a set of building components.

9. **Ground detail** — road markings (lane lines, crosswalks), puddles that reflect
   lights, manhole covers, storm drains, trash, broken glass. The street looks USED.

#### A3: Character Animation (spike required before committing)
10. **Skeleton2D spike** — take ONE character (the hero), separate the body parts from
    the SVG pipeline, rig with Skeleton2D + Bone2D, create walk/idle/attack animations
    with AnimationPlayer. If it works: commit to rigging all characters. If it doesn't:
    fall back to higher-resolution atlas with more animation frames (12+ per cycle).

11. **If rig works:** Full skeletal characters with:
    - Idle: breathing, weight shift, weapon sway
    - Walk: 12+ frame cycle with contact, passing, reach
    - Run: distinct from walk, leaning forward
    - Attack: wind-up → swing arc → follow-through (weapon trail via Line2D)
    - Feed: lean in toward victim, victim struggles then slumps
    - Hit react: directional stagger (IK-driven)
    - Death: ragdoll collapse (RigidBody2D limbs, visual-only physics)
    - Status effects: burning particles attach to body, ice crystals on frozen, etc.

12. **If rig doesn't work:** Higher-resolution atlases (192×256 per frame instead of
    96×128) with 8+ frames per walk cycle, distinct attack phases, feeding poses. The
    SVG pipeline can generate at any resolution — it's just a render scale change.

#### A4: Spell Visuals Per Discipline
Every discipline should be INSTANTLY recognizable by its visual language:
- **Celerity** (speed): electric blue streaks, afterimage trail, speed lines
- **Potence** (strength): orange shockwave, ground crack, debris scatter
- **Fortitude** (defense): green/grey stone texture overlay, impact absorption flash
- **Obfuscate** (stealth): shadow dissolve, smoke wisps, desaturation
- **Auspex** (perception): golden eye flash, reveal pulse, mark glow
- **Dominate** (control): purple chains/tendrils connecting caster to victim
- **Presence** (awe/fear): yellow radial wave, victim recoil animation
- **Blood Sorcery**: crimson liquid tendrils, blood rain, red mist
- **Protean** (beast form): green claw marks, bestial particles, feral aura
- **Oblivion/Shadow**: black tendrils, void particles, gravity distortion

### Track B: Gameplay Engine (PARALLEL with Track A)
**Files:** `src/sim/`, `src/entities/`, `data/`, `src/data/`
**Principle:** Give the player DECISIONS to make [P1, P2, P3, P4]

**Hard rule:** Sim stays deterministic. All physics/ragdoll/particles are presentation-only.
No Godot physics in sim. No randf/randi/Time.* in sim. 20-run hash must hold.

#### B1: Combat Combo System [P1, P2]
1. **Status effect framework** — entities can have named statuses with durations and stacking:
   `bleeding`, `burning`, `stunned`, `rooted`, `feared`, `mesmerized`, `marked`, `frozen`,
   `weakened`, `empowered`. Each status has a visible effect (communicated via cue to Track A).

2. **Combo trigger system** — abilities check target status before applying damage:
   ```
   if target.has_status("bleeding"):
       damage *= 1.5  # bleed amplifies next hit
       emit_cue("combo.trigger", { combo_name: "Hemorrhage", bonus_damage: ... })
   if target.has_status("stunned"):
       damage *= 2.0  # execute bonus on stunned targets
       emit_cue("combo.trigger", { combo_name: "Execute", ... })
   ```
   The combo trigger emits a CUE so Track A can show "COMBO: HEMORRHAGE ×1.5" visually.

3. **Cast mechanic variety:**
   - Instant+cooldown: press → fires immediately → starts cooldown timer. Get these off early
     to start the CD. (WoW instant spells)
   - Charged: hold → builds power → release to fire. Getting hit during charge reduces charge
     by 30%. Creates "charge while safe" windows. (WoW Pyroblast)
   - Channeled: hold → continuous effect → release to stop. Costs blood/sec. You're vulnerable
     while channeling. (WoW Arcane Missiles)

4. **Melee rework:**
   - Light attack (click): fast, free, low damage. The fallback when blood-dry.
   - Heavy attack (hold click): slower, free, more damage, breaks block. Risk: vulnerable during
     wind-up.
   - Combo string: light → light → heavy = natural rhythm with increasing damage on the chain.
   - Flow stacks (already exist): perfect timing builds flow → damage multiplier. Reward skill.

#### B2: Enemy Overhaul [P4]
5. **Distinct archetype behaviors:**
   - Rusher: sprint toward player, melee chain, low HP. Counter: AoE, knockback.
   - Tank: slow approach, shield blocks frontal attacks, high HP. Counter: flank, DoT, CC-bypass.
   - Shooter: maintains distance, kites backward while shooting. Counter: dash to close gap.
   - Healer: stays behind allies, pulses HoT on nearby allies. Counter: priority target, dash past
     frontline.
   - Summoner: spawns minions every N seconds, fragile. Counter: burst before overwhelmed.
   - Ambusher: invisible until close, backstab opener. Counter: Auspex reveals, AoE flush.

6. **Enemy telegraphs:**
   - All heavy/special attacks have a 0.3-0.5s wind-up visible to the player
   - Emits `enemy.telegraph` cue with direction and type for Track A visualization
   - Player can dodge during wind-up, interrupt with CC, or block with shield/parry
   - Light attacks have no telegraph (faster, weaker, less punishing)

7. **Group composition encounters:**
   - Define encounter templates: `{tank: 1, rusher: 2, healer: 1}`
   - Place encounters at designed locations in the world
   - Each composition has a "solution space" — multiple valid approaches
   - Difficulty scales by adding tougher compositions, not just more HP

8. **Resistances:**
   - Each enemy type has 1-2 resistances and 1 weakness
   - Thugs: resist physical, weak to fire
   - Hunters: resist shadow, weak to physical
   - Elders: resist CC, weak to blood sorcery
   - Forces skill diversification in the player's build

#### B3: Feeding Redesign [P3, P8]
9. **Feeding as power loop:**
   - Remove humanity loss from feeding. Only killing costs humanity.
   - Feeding fills blood (mana) at a visible rate. The meter filling IS the reward.
   - Drain amount is player choice: release F to stop at any point.
   - Drain past 70%: victim starts to weaken visibly. Past 90%: risk of killing.
   - Killing: +100% blood but -0.5 humanity. The CHOICE is the gameplay.

10. **Resonance as build fuel:**
    - NPCs have visible aura (color) indicating blood type
    - Draining gives a 2-min buff matching the resonance type
    - Sanguine: +30% melee damage. Choleric: +30% spell damage.
      Melancholic: +stealth radius. Phlegmatic: +regen.
    - Strategic hunting: seek out the resonance that matches your build

11. **Non-combat feeding approaches:**
    - Dominate: mind-control → walk to secluded spot → drain (safe, slow, mana cost)
    - Presence charm: freeze nearby NPCs → feed on one (risky, nearby witnesses)
    - Stealth ambush: Obfuscate → approach → grab from behind (skill-based, no mana cost)
    - Street grab: just grab someone (fast, loud, witnesses, heat)
    Each is a different risk/reward/skill tradeoff. CHOICES.

#### B4: Progression [P6]
12. **Branching skill upgrades:**
    Each power has 3 upgrade paths at ranks 3/5/7:
    - Path changes HOW the power works, not just numbers
    - Example: Celerity Dash → A: leaves damaging trail / B: dashes through enemies
      (phasing) / C: resets cooldown on kill
    - Forces meaningful choices that create distinct builds

13. **Gear drops:**
    - Enemies drop gear on kill (not every kill — rarity matters)
    - Gear has 1-2 effects that suggest build synergies
    - Rarity tiers: common (1 stat), uncommon (1 effect), rare (2 effects), legendary
      (build-defining unique effect)
    - Gear is visible on the character (weapon swap, cloak change)

14. **XP + leveling:**
    - XP from kills (scaled by enemy difficulty), feeding, discovery, quests
    - Level up = 1 skill point + stat increase (visible: "+10 max blood, +5 max HP")
    - Skill point goes into discipline tree
    - Level milestones unlock new power tiers (level 3: tier 2 powers, level 5: tier 3)

#### B5: Sandbox Sim [P7]
15. **Onboarding fix:**
    - Remove timed contract from game start
    - Start with a calm "you're hungry, find someone" prompt
    - First objective is gentle: "Feed on a mortal" (no timer, waypoint to nearest NPC)
    - Combat tutorial triggered by first hostile encounter, not forced

16. **Heat as opt-in escalation:**
    - Heat only rises from player actions (fighting, feeding in public, using powers)
    - World starts CALM (standing project principle — GTA feel)
    - Player CHOOSES to cause chaos or stay quiet
    - Heat tiers: 0 = peaceful, 1 = alert, 2 = patrol, 3 = hunt, 4 = SWAT, 5 = hunter squad

17. **Night structure:**
    - Dawn pressure through atmosphere (sky gradient) not HUD timers
    - Three acts: Early Night (calm, explore, feed) → Mid Night (encounters, quests) →
      Late Night (urgency, dawn approaching, reach haven)
    - Haven = safe zone where you can craft, sell, upgrade between nights

18. **NPC routines:**
    - Civilians walk between locations, enter buildings, gather in groups
    - Patterns create feeding opportunities (lone walker = easy target,
      couple = harder, crowd = dangerous)
    - NPCs react to world state (bodies found → panic, blood on street → avoid area)

### Track C: Experience Integration (DEPENDS ON A+B)
**Files:** `src/ui/`, `scenes/`, `src/present/` (HUD overlays)
**Principle:** Connect the systems so the player can SEE and UNDERSTAND them [P5]

Track C is the INTEGRATION layer. It consumes the CueBus events from Track B and the visual
systems from Track A, and wires them into a coherent player experience. It partially overlaps
with both tracks and starts after the event contract is stable.

#### C1: Combat Feedback (wires B1→A1)
1. **Floating damage numbers** — every `damage.dealt` cue spawns a number that punches up
   and fades. Normal = white, crit = yellow + bigger, combo = special color + "COMBO: ×2"
2. **Status effect indicators** — on `status.applied`, show icon above enemy head (flame for
   burning, drops for bleeding, stars for stunned, snowflake for frozen)
3. **Cooldown display** — hotbar slots show spinning cooldown ring, flash when ready
4. **Blood/mana bar feel** — bar drains visibly on cast, pulses when low (<20%), glows on feed
5. **Kill feedback chain** — death cue triggers: ragdoll + blood spray + XP popup + item drop
   glow + brief satisfaction pause (Diablo kill feel)

#### C2: Enemy Readability (wires B2→A1)
6. **Alert state indicators** — `?` when suspicious, `!` when alarmed, `!!` when hostile.
   Color-coded: yellow → orange → red. (Metal Gear Solid)
7. **Telegraph visualization** — on `enemy.telegraph` cue: enemy glows, ground indicator for
   AoE, directional arrow for charge attack. Player reads this and reacts.
8. **Enemy health bars** — visible when damaged, chunk animation on hit, distinct for
   elite/boss enemies (larger bar, name label)
9. **Offscreen threat indicators** — arrows at screen edge pointing to hostile enemies
   outside the viewport. Color indicates threat level.

#### C3: Feeding Experience (wires B3→A3)
10. **Blood drain meter** — when feeding, a circular or bar meter fills visibly. Pulsing
    heartbeat effect synced to drain rate.
11. **Victim animation states** — communicate drain progress: struggling (0-30%), weakening
    (30-70%), limp (70-100%). Player reads the victim to know when to stop.
12. **Choice moment UI** — at 70%, subtle prompt: "Release to spare / Hold to drain"
    Spare = green flash + "+70 Blood." Kill = red flash + "+100 Blood" + "Humanity -0.5"
13. **Resonance reveal** — pre-feed, show the victim's aura color and what buff it gives.
    Player decides: "Is this the blood type I want?"

#### C4: Navigation & Goals (wires B5→HUD)
14. **Minimap waypoints** — arrow on minimap pointing to current objective
15. **Objective display** — clear, simple current goal on screen (not "CONTRACT: drain the
    marked mortal (26s left)" but "Find someone to feed on")
16. **District indicators** — entering a new area shows district name + danger level
17. **Death explanation** — on death, show WHAT killed you and WHY: "Killed by Hunter — you
    were spotted feeding" or "Burned by sunlight — reach your haven before dawn"

#### C5: Progression Feel (wires B4→HUD)
18. **Level-up moment** — flash, fanfare, "LEVEL 2" banner, "+1 Skill Point" with immediate
    prompt to spend it
19. **Skill tree UI** — visual tree showing branches, current path, locked/unlocked nodes
20. **Gear comparison** — on pickup, show current vs. new with green/red stat changes
21. **Loot rarity visuals** — common: no effect, uncommon: faint glow, rare: bright glow +
    beam, legendary: golden beam + unique sound

---

## Part 6 — Definition of Done

A feature is DONE when ALL of these are true:

1. **Boot clean** — no errors in console
2. **GUT green** — existing tests still pass (determinism preserved: 20-run hash holds)
3. **New tests** — the feature has at least one GUT test exercising the sim-side logic
4. **PLAYED** — a human launched the windowed build and used the feature
5. **Screenshot/video proof** — captured evidence that it looks and feels right
6. **"Would I play 5 more minutes?"** — subjective but honest. If the answer is no, it's not done.

Green tests are NECESSARY but NOT SUFFICIENT. The asparagus people passed 109 tests. The game
was still a pile of shit. Play it. Look at it. Be honest.

---

## Part 7 — What's NOT In This Plan (Explicitly)

- Camera shake magnitude changes (meaningless without combat that works)
- Loot drop fanfare (meaningless without loot that matters)
- Save/load system polish (meaningless without a game worth saving)
- CI pipeline improvements (meaningless without a game to test)
- Determinism gate hardening (already works, don't touch)

These are post-fun optimizations. They become relevant after the vertical slice feels good.

---

## Appendix: Reference Games and What To Steal

| Game | What to steal | Applied where |
|------|--------------|---------------|
| Diablo III | Click → kill → reward loop, ability combos, loot tiers | Combat, progression |
| WoW | Spell decision chains, mana tension, professions, enemy variety | Combat system, crafting |
| VtM: Bloodlines | Feeding intimacy, discipline fantasy, Masquerade tension, atmosphere | Feeding, powers, world |
| Hades | Boon combos, death-as-progress, animation quality, per-weapon feel | Combos, death, visuals |
| GTA | Sandbox freedom, heat escalation, open world, emergent fun | Sandbox, heat, freedom |
| Dark Souls | Telegraphed attacks, stamina management, weight of every action | Enemy design, combat |
| Path of Exile | Gem+support combos, build depth, meaningful choices | Skill tree, builds |
| Age of Conan | Directional combat, combo inputs, reading enemy body language | Melee system |
| Mark of the Ninja | Stealth readability, light/shadow as gameplay, clarity of state | Stealth, lighting |
| Dead Cells | Skeletal animation, weapon variety, procedural variety | Animation, variety |
| Vampire Survivors | Simple art + particles = spectacle, many enemies on screen | VFX, enemy count |
| Batman Arkham | Detective vision / sense mode, environmental takedowns | Vampire senses, env kills |
| Star Wars: TFU | Force throw, environmental weapons, physics spectacle | Potence, env interaction |
