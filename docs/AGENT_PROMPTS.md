# Agent Launch Prompts — Game Overhaul

Read `docs/GAME_OVERHAUL_PLAN.md` first. It has the full design philosophy, feature specs,
CueBus event contract, and vertical slice definition. These prompts reference it.

**Launch order:** Tracks A and B run in parallel. Track C runs after both are done.

---

## TRACK A — Visual Engine

Copy everything between the `---` fences below into a new Claude Code session.

---

```
You are rebuilding the visual engine of Vampire City, a Godot 4.7 / GDScript top-down vampire
ARPG. The game currently renders EVERYTHING with manual _draw() calls — draw_circle, draw_rect,
draw_line, draw_colored_polygon. It uses approximately 0% of Godot's actual rendering features.
Your job is to make it look like a real game.

READ THESE FILES FIRST (in this order):
1. docs/GAME_OVERHAUL_PLAN.md — the full plan. Read Part 1 (principles), Part 4 (CueBus
   contract — you MUST emit/consume these exact event names), and Part 5 Track A (your task list).
2. src/present/EntityRenderer.gd — the entry point for character rendering. Manages rig pooling.
3. src/present/CharacterAtlas2D.gd — current character renderer (atlas-based sprite sheets).
   This is what you're improving or replacing.
4. src/present/SpellFX.gd — all spell visuals. Currently ALL draw_line/draw_arc. Replace with
   GPUParticles2D + shaders per discipline.
5. src/present/WorldFX.gd — transient combat effects (swing arcs, impact bursts, blood rings).
   Replace with GPUParticles2D.
6. src/present/VisualFX.gd — screen-level feedback (damage numbers, screen flash, hitstop).
   Improve damage numbers, add vignette/bloom.
7. src/present/CameraDirector.gd — camera shake/kick. KICK_MAG=7 is imperceptible. Fix it.
8. src/present/LightingDirector.gd — dynamic lighting. Only 3 world lights, no shadows.
   Add LightOccluder2D on buildings for real 2D shadows.
9. src/present/WorldRenderer.gd — world tile rendering. Replace draw_rect loop with TileMapLayer.
10. src/present/CueBus.gd — the event bus. You CONSUME events from the sim through this.
    NEVER import or modify anything in src/sim/ or src/entities/.

ARCHITECTURE RULE — HARD CONSTRAINT:
The game has a strict Sim → CueBus → Presentation seam. The sim (src/sim/, src/entities/) is
the authoritative game state. Presentation (src/present/) is view-only. You MUST NOT:
- Import, require, or reference any file in src/sim/ or src/entities/
- Mutate any sim state
- Use Godot physics (RigidBody2D, CharacterBody2D, Area2D collision) for gameplay logic
- Use randf(), randi(), or Time.* in any sim-touching code
You CAN freely use Godot's visual features: GPUParticles2D, Shaders, Skeleton2D, Light2D,
LightOccluder2D, TileMapLayer, AnimationPlayer, BackBufferCopy — these are all presentation.

YOUR DELIVERABLES (in priority order):

PHASE A1 — Guaranteed visual wins (no technical risk, do these first):

1. CHARACTER OUTLINE/RIM-LIGHT SHADER
   Write a CanvasItem shader that draws a 1-2px bright edge on characters so they pop from the
   dark ground. Like Hades/Dead Cells character readability. Apply to every character rig via
   EntityRenderer. The characters are currently dark blobs against dark ground — this alone is
   a massive readability win.

2. HIT FLASH SHADER
   On taking damage (hit.connect cue), the character material goes white for 2-3 frames.
   Universal "I got hit" signal. Implement as a shader uniform toggle on the character material.

3. GPUParticles2D SYSTEM — replace ALL draw_circle/draw_arc procedural effects:
   a. Blood spray: directional burst on hit (red particles, gravity, splatter on ground).
      Triggered by hit.connect cue. Direction from cue payload dir field.
   b. Rain: constant falling particles across viewport + splash on ground. Creates instant
      noir atmosphere. Should be a persistent viewport-level particle system.
   c. Death dissolve: on entity death, character breaks into particles that scatter outward
      instead of just vanishing. Triggered by kill/enemy.death cue.
   d. Spell effects per discipline — each discipline has a distinct visual language:
      - Celerity (speed): electric blue streaks, afterimage trail, speed lines
      - Potence (strength): orange shockwave, ground cracks, debris scatter
      - Fortitude (defense): green/grey stone texture overlay
      - Obfuscate (stealth): shadow dissolve, smoke wisps, desaturation
      - Auspex (perception): golden eye flash, reveal pulse
      - Dominate (control): purple chains/tendrils
      - Presence (awe/fear): yellow radial wave
      - Blood Sorcery: crimson liquid tendrils, blood rain, red mist
      - Protean (beast): green claw marks, bestial particles
      - Oblivion/Shadow: black tendrils, void particles
      Wire these to the existing SpellFX.gd archetype system (PROJECTILE, NOVA, GROUND_AOE,
      CONE, BEAM, DEBUFF, DASH, TETHER, SELF_BUFF) — map discipline+archetype to particle scene.
   e. Ambient particles: floating dust motes, steam from grates, smoke wisps. Background
      atmosphere that makes the world feel alive.
   f. Footstep dust puffs on walk, dash trail particles on celerity moves.

4. LightOccluder2D ON BUILDINGS
   Read SimWorld.gd to understand the wall layout (walls[] array, 64x40 grid, 32px tiles).
   Add LightOccluder2D polygons on wall tiles so buildings cast real 2D shadows. This makes
   light/shadow tactical: shadows = stealth zones, light pools = danger.
   Do this in WorldRenderer.gd or a companion node.

5. SCREEN-SPACE EFFECTS via BackBufferCopy + ShaderMaterial:
   a. Vignette: constant subtle dark edges, stronger when player is hurt (wire to damage.player)
   b. Bloom on light sources: neon signs and streetlamps should glow/bleed
   c. Damage vignette: screen edges pulse red on hit (wire to damage.player cue)
   d. Optional: brief chromatic aberration on big hits (crit from hit.connect payload)

6. PARALLAX CITY BACKDROP
   ParallaxBackground with 2-3 layers: distant building silhouettes, water towers, moon/clouds.
   Moves with camera at reduced rate. Creates sense of a city beyond the play area. Reference:
   Dead Cells, Hollow Knight parallax layers.

PHASE A2 — World depth:

7. TileMapLayer WORLD RENDERING
   Replace the draw_rect-per-tile loop in WorldRenderer.gd with Godot TileMapLayer. Multiple
   layers: ground (asphalt/concrete), road markings (lane lines, crosswalks), detail (puddles,
   cracks, debris, manhole covers), walls (building facades with lit windows), foreground
   (signs, awnings, railings that overlap the player for depth). Use autotiling for proper
   wall edges. The current world is just colored rectangles — this should look like a CITY.

PHASE A3 — Character animation (SPIKE FIRST):

8. SKELETON2D SPIKE
   Take ONE character (the hero). The SVG pipeline in tools/visual/ draws body parts separately.
   Try to: extract parts as separate sprites, rig with Skeleton2D + Bone2D in Godot, create
   walk/idle/attack/feed animations with AnimationPlayer.
   
   IF IT WORKS: commit to full skeletal characters with idle breathing, 12-frame walk, distinct
   run, attack with weapon trail, feed lean-in, directional hit stagger, ragdoll death.
   
   IF IT DOESN'T WORK (pivot extraction is too hard, rigging doesn't look good): fall back to
   higher-resolution atlases. The SVG pipeline can render at any size — go from 96x128 to
   192x256 per frame, add more animation frames (8+ walk frames, distinct attack phases).
   
   Report honestly which path you took and why. Do NOT claim the spike worked if it looks bad.

9. CAMERA FEEL
   In CameraDirector.gd: KICK_MAG=7 is imperceptible. Try 20-30 for normal hits, 40-50 for
   crits. BASE_ZOOM=2.4 might be too tight — experiment. Add a brief zoom punch on kills
   (0.1s zoom in 5%, then ease back). Make combat FEEL impactful through camera language.

CUEBUS EVENTS YOU CONSUME (from docs/GAME_OVERHAUL_PLAN.md Part 4):
- hit.connect: blood spray particles, hit flash, camera kick
- damage.dealt: floating damage numbers (make them PUNCH — larger, color-coded)
- damage.player: screen vignette pulse, damage indicator
- kill / enemy.death: death dissolve particles, blood pool, XP popup
- combo.trigger: special combo text effect ("COMBO: HEMORRHAGE x1.5")
- status.applied: status icon above enemy head (flame/bleed/stun/frost)
- feed.start / feed.progress / feed.end: camera tighten, blood drain visuals
- enemy.telegraph: ground indicator, glow effect on enemy during wind-up
- enemy.alert: ?/!/!! indicator above head
- attack.telegraph: anticipation visual for enemy heavy attacks
- dawn.warning: sky color shift, ambient light warming

NEW CUES YOU MAY NEED TO EMIT (presentation-only, for other presentation nodes):
- vfx.rain.intensity: control rain particle rate
- vfx.screen.flash: trigger screen overlay effects

VERIFICATION:
- Run the game: the Godot binary is at C:/Users/93rob/Documents/GitHub/Vamp/Godot_v4.4.1-stable_win64.exe
  Launch with: Godot_v4.4.1-stable_win64.exe --path . --windowed --resolution 1280x720
- Run GUT tests: Godot_v4.4.1-stable_win64.exe --path . -s addons/gut/gut_cmdln.gd -gexit
  All existing tests MUST still pass. You are not expected to break sim determinism since you
  only touch presentation files, but verify anyway.
- LOOK AT IT. Take a screenshot. Does it look like a real game? Compare mentally to Hades or
  Dead Cells. If it still looks like colored circles on a black background, you're not done.

DO NOT:
- Touch any file in src/sim/ or src/entities/
- Add features not in this list (no gameplay changes, no UI changes, no new game mechanics)
- Spend time on audio (that's separate)
- Write long planning documents — write CODE and verify it VISUALLY
```

---

## TRACK B — Gameplay Engine

Copy everything between the `---` fences below into a new Claude Code session.

---

```
You are rebuilding the gameplay engine of Vampire City, a Godot 4.7 / GDScript top-down vampire
ARPG. The game has 30+ vampire powers but zero strategic decisions — the player just walks up
to things and clicks. There are no combos, no enemy variety, no meaningful resource tension,
no readable feedback, and feeding (the core vampire mechanic) PUNISHES the player instead of
empowering them. Your job is to make the combat and progression systems actually fun.

READ THESE FILES FIRST (in this order):
1. docs/GAME_OVERHAUL_PLAN.md — the full plan. Read ALL of it but especially Part 1 (design
   principles — these are your north star), Part 3 (the vertical slice — this is what the first
   5-10 minutes should feel like), Part 4 (CueBus contract — you MUST emit these exact event
   names), and Part 5 Track B (your task list).
2. src/sim/Sim.gd — the main simulation loop. 60Hz tick, LCG RNG, state_hash. This is the
   authoritative game state. Everything you build goes here or in files it calls.
3. src/entities/SimPlayer.gd — the player entity. Has 30+ powers across disciplines. Read the
   full power list, the gulp timing system, locomotion, blood economy. You're MODIFYING this.
4. src/entities/SimNPC.gd — NPC behavior. Currently basic. You're adding enemy archetypes.
5. src/entities/SimEntity.gd — base entity with HP, blood, status, position. You'll add the
   status effect framework here.
6. src/sim/SimWorld.gd — 64x40 grid, districts, blood/fire layers. You may add encounter
   placement here.
7. src/sim/ImpulsePhysics.gd — the sim's physics. Deterministic. You may extend for knockback.
8. src/data/ — data definitions (ActionDef, etc). You'll add combo definitions here.
9. src/present/CueBus.gd — the event bus. You EMIT events through this. Read the existing
   event patterns so your new events match the style.

ARCHITECTURE RULE — HARD CONSTRAINTS:
1. DETERMINISM IS SACRED. The sim must stay bit-deterministic:
   - Use ONLY the LCG RNG (entity.rng, sim.rng) for any randomness
   - NEVER use randf(), randi(), rng.randf(), or any Godot random function
   - NEVER use Time.get_ticks_msec(), Time.get_unix_time_from_system(), or any time function
   - NEVER use Godot physics nodes (RigidBody2D, Area2D, CharacterBody2D) for game logic
   - After your changes, a 20-run hash test must produce identical state_hash every time
2. CueBus events: emit ALL combat/status/feeding events through CueBus so the visual layer
   (Track A, running in parallel) can display them. Use the EXACT event names from Part 4 of
   the plan. Do NOT invent your own names — the visual team is coding against the contract.
3. You may NOT touch files in src/present/ except CueBus.gd (to register new event channels).

YOUR DELIVERABLES (in priority order):

PHASE B1 — Combat combo system [Principles P1, P2]:

1. STATUS EFFECT FRAMEWORK
   Add to SimEntity (or a new StatusEffect system that SimEntity references):
   - Named statuses: bleeding, burning, stunned, rooted, feared, mesmerized, marked, frozen,
     weakened, empowered
   - Each status has: duration (ticks), intensity (float), source_id, stack_count
   - Statuses tick down each sim frame, removed when duration hits 0
   - On apply: emit CueBus "status.applied" { target_id, status, duration, source_id }
   - On expire: emit CueBus "status.expired" { target_id, status }
   - Key behaviors:
     * stunned: entity cannot act (skip action processing)
     * rooted: entity cannot move (zero velocity) but can still attack/cast
     * feared: entity runs away from source (override AI/input)
     * mesmerized: entity stands still, breaks on damage
     * bleeding: ticks X damage per second, stacks
     * burning: ticks X damage per second, does NOT stack (refreshes)
     * marked: no direct effect, but other abilities check for it (combo trigger)
     * frozen: slowed 50%, shatters for bonus damage on next hit (combo trigger)
     * weakened: takes 30% more damage
     * empowered: deals 30% more damage

2. COMBO TRIGGER SYSTEM
   When an ability hits a target, check for combo conditions and apply bonus effects:
   
   Define combos as data (in src/data/ or inline):
   ```
   combos = {
     "hemorrhage": { requires: "bleeding", trigger_abilities: ["blood_bolt", "bs_bolt"],
                     effect: "bonus_damage", multiplier: 1.5, consumes_status: true },
     "execute": { requires: "stunned", trigger_abilities: ["melee_heavy"],
                  effect: "bonus_damage", multiplier: 2.0, consumes_status: true },
     "shatter": { requires: "frozen", trigger_abilities: ["any_physical"],
                  effect: "bonus_aoe_damage", multiplier: 1.8, consumes_status: true },
     "soul_rend": { requires: "marked", trigger_abilities: ["shd_tendril", "shd_arms"],
                    effect: "bonus_damage_and_heal", multiplier: 1.5, heal_pct: 0.3 },
     "pyre": { requires: "burning", trigger_abilities: ["bs_bolt", "bs_storm"],
               effect: "aoe_explosion", radius: 96, consumes_status: true },
   }
   ```
   
   On combo trigger: emit CueBus "combo.trigger" { entity_id, target_id, combo_name,
   bonus_damage, pos } so Track A can show the combo text visually.
   
   The player discovers: "Oh, if I bleed them first THEN bolt, it does 1.5x!" This is the
   Diablo/Hades moment where combat becomes a strategy game.

3. CAST MECHANIC VARIETY
   Currently all powers are instant-fire. Add two new cast types:
   
   a. CHARGED: hold the ability key → power builds over 0.5-1.5s → release to fire.
      Damage scales with charge time. Getting hit during charge loses 30% charge (creates
      "charge while safe" tactical windows). Apply to: pot_slam, pot_quake, bs_storm.
      Reference: WoW Pyroblast, Elden Ring charged heavy attacks.
   
   b. CHANNELED: hold the ability key → continuous effect → drains blood per tick while held.
      Release to stop. Player is slowed while channeling. Apply to: bs_bolt (becomes a beam),
      shd_tendril (sustained drain). Reference: WoW Arcane Missiles, Diablo Disintegrate.
   
   Add cast_type to ActionDef: "instant" (default, current behavior), "charged", "channeled".
   The sim processes each type differently in the action execution loop.

4. MELEE REWORK
   Currently melee is... unclear. Make it:
   - Light attack (click): fast, FREE (no blood cost), low damage. The out-of-mana fallback.
   - Heavy attack (hold click + release): slower, FREE, more damage, but vulnerable during
     wind-up. Emits attack.telegraph so Track A can show the wind-up.
   - Combo string: light → light → heavy (within timing window) = natural rhythm with
     increasing damage. Flow stacks (already exist) reward timing.
   - Melee must be VIABLE when blood-dry. The gameplay loop is: "cast spells freely → run dry →
     melee + dodge while looking for feeding opportunity → feed → back to casting."

PHASE B2 — Enemy overhaul [Principle P4]:

5. ENEMY ARCHETYPES
   Modify SimNPC to support distinct behavior profiles:
   
   a. RUSHER: high move speed, charges at player, melee chain, low HP.
      Counter: AoE, knockback, kiting. Dangerous in groups.
   b. TANK: slow, high HP, frontal shield (blocks X% frontal damage), heavy hits.
      Counter: flank for backstab bonus, DoTs bypass shield, CC and bypass.
   c. SHOOTER: maintains preferred range (backs up if player closes), ranged attacks, low HP.
      Counter: dash to close gap, interrupt with CC.
   d. HEALER: stays behind allies, pulses HoT on nearby allies every N ticks.
      Counter: priority target — kill first or CC to stop healing.
   e. SUMMONER: spawns 1-2 weak minions every N ticks, fragile.
      Counter: burst the summoner before getting overwhelmed.
   f. AMBUSHER: starts in obfuscate (invisible), attacks from behind for bonus damage.
      Counter: Auspex reveals, AoE flushes them out.
   
   Each archetype should be a behavior profile on SimNPC, not a separate class. Data-driven:
   npc.archetype = "rusher" → selects behavior in the AI tick.

6. ENEMY TELEGRAPHS
   All enemy HEAVY attacks must have a startup window (15-30 ticks at 60Hz = 0.25-0.5s):
   - During wind-up: entity is in "telegraphing" state, emit "enemy.telegraph" cue with
     direction, attack type, and wind-up duration
   - Player can dodge, interrupt with CC, or block during this window
   - Light attacks are fast (3-5 tick startup) with no telegraph — less punishing
   - This creates the Dark Souls / Monster Hunter moment: read the tell → react

7. GROUP ENCOUNTER TEMPLATES
   Define encounter compositions as data:
   ```
   encounters = {
     "street_thugs": { rusher: 2, shooter: 1 },
     "gang_squad": { tank: 1, rusher: 2, healer: 1 },
     "hunter_cell": { shooter: 2, ambusher: 1 },
     "elder_guard": { tank: 2, healer: 1, summoner: 1 },
   }
   ```
   Place these at designed locations in SimWorld. Each composition is a puzzle with multiple
   valid solutions. The player thinks: "Tank + healer... I need to dash past the tank, CC the
   healer, then clean up."

8. RESISTANCES
   Add resistance/weakness to entity data:
   - physical_resist, fire_resist, shadow_resist, blood_resist (0.0 to 1.0, where 1.0 = immune)
   - weakness: takes 1.5x from that type
   - Thugs: resist physical 0.3, weak to fire
   - Hunters: resist shadow 0.5, weak to physical
   - Elders: CC duration halved, weak to blood sorcery
   Forces the player to diversify their build — can't just stack one element.

PHASE B3 — Feeding redesign [Principle P8]:

9. FEEDING AS POWER LOOP
   Currently feeding loses humanity, which feels like punishment. Fix:
   - Feeding does NOT cost humanity. Only KILLING costs humanity.
   - Feeding has a visible progress: blood fills at a rate over 3-4 seconds (emit
     "feed.progress" cue every few ticks with progress_pct and blood_gained)
   - Player can RELEASE at any time to stop early:
     * Stop at <70%: victim is dazed but alive. Safe. Partial blood.
     * Stop at 70-90%: victim collapses but alive. Full blood. Small risk.
     * Drain past 90%: victim dies. Max blood + bonus. Humanity loss.
   - Emit "feed.choice" when player crosses the 70% threshold so UI can show the prompt
   - Emit "feed.spare" or "feed.kill" on release based on whether victim survived
   - The CHOICE to kill or spare IS the morality system. Not feeding itself.

10. BLOOD RESONANCE
    NPCs have a resonance type (sanguine/choleric/melancholic/phlegmatic) assigned at spawn:
    - Draining gives a 2-minute buff matching resonance:
      * Sanguine (red): +30% melee damage
      * Choleric (orange): +30% spell damage
      * Melancholic (blue): +stealth effectiveness
      * Phlegmatic (green): +HP regen
    - Strategic hunting: "I'm a caster build, I need choleric blood — where are the orange ones?"
    - Emit resonance type in feed events so Track A can show the aura color

11. NON-COMBAT FEEDING APPROACHES
    Multiple ways to initiate feeding, each with different risk/reward:
    - Dominate (costs blood): mind-control target, walk them to a secluded spot, drain safely
    - Presence charm (costs blood): freeze nearby NPCs, feed on one while others are stunned
    - Stealth ambush (costs no blood): must be in Obfuscate, approach from behind
    - Street grab (costs nothing): just grab someone — fast but loud, witnesses, heat
    Add these as distinct actions the player can trigger near NPCs.

PHASE B4 — Progression basics [Principle P6]:

12. ONBOARDING FIX
    - Remove the timed contract that fires on game start. The current experience is: spawn →
      "GO FEED ON MARKED PERSON IN 26 SECONDS" → panic → die confused. Replace with:
    - On first spawn: set a gentle objective "Find someone to feed on" (no timer)
    - After first feed: "You feel stronger. Explore the district."
    - After first combat kill: brief explanation of combo system
    - Dawn pressure comes from ATMOSPHERE (sky brightening) not a HUD countdown
    - Emit appropriate cues for the UI layer to display these

13. XP AND LEVELING
    - XP from: kills (scaled by enemy difficulty), feeding (flat amount), discovery (new areas)
    - Level thresholds: simple scaling (100, 250, 500, 800, 1200...)
    - Level up grants: +1 skill point, +10 max blood, +5 max HP
    - Emit "player.level_up" and "player.xp_gain" cues

14. SKILL TREE BRANCHING
    At power ranks 3, 5, 7: offer a choice of 3 upgrade paths per power. Each path changes
    HOW the power works mechanically:
    
    Example — cel_dash:
    - Path A "Aftershock": dash leaves a damaging trail (DoT zone)
    - Path B "Phase": dash passes through enemies, phasing (invulnerable during)
    - Path C "Reset": killing during dash refunds cooldown
    
    Example — bs_bolt (Blood Bolt):
    - Path A "Hemorrhage": applies 10s bleed DoT (enables hemorrhage combo)
    - Path B "Scatter": splits into 3 weaker bolts (AoE clear)
    - Path C "Siphon": returns 30% damage as blood (sustain)
    
    Store upgrade choices on the player entity. Apply modifications in the power execution code.

15. HEAT AS OPT-IN ESCALATION
    - Heat only rises from player actions (public feeding, combat, overt power use)
    - 5 tiers: 0=peaceful, 1=alert, 2=patrol, 3=hunt, 4=SWAT, 5=hunters
    - Each tier increases police/hunter spawn rate and aggression
    - Heat decays over time when player is not causing trouble
    - Emit "heat.changed" cue for the HUD
    - World starts at heat 0. Always. The player CHOOSES to escalate. (GTA stars)

CUEBUS EVENTS YOU MUST EMIT (from docs/GAME_OVERHAUL_PLAN.md Part 4):
Use these EXACT names. The visual team (Track A) is coding against this contract.

Combat: attack.start, attack.telegraph, hit.connect, damage.dealt, damage.player,
        combo.trigger, kill
Feeding: feed.start, feed.progress, feed.gulp, feed.gulp.perfect, feed.gulp.miss,
         feed.choice, feed.spare, feed.kill, feed.end
Status: status.applied, status.expired, status.detonated
Enemy: enemy.alert, enemy.telegraph, enemy.flee, enemy.search, enemy.death
Player: player.level_up, player.xp_gain, player.loot, player.death
World: masquerade.breach, heat.changed, dawn.warning, dawn.arrived
State: humanity.changed, blood.changed

VERIFICATION:
- Run GUT tests: the Godot binary is at C:/Users/93rob/Documents/GitHub/Vamp/Godot_v4.4.1-stable_win64.exe
  Command: Godot_v4.4.1-stable_win64.exe --path . -s addons/gut/gut_cmdln.gd -gexit
  ALL existing tests must pass. Your changes must not break determinism.
- Write NEW GUT tests for: status effects (apply, tick, expire), combo triggers (bleed→bolt=
  hemorrhage), enemy archetypes (rusher charges, healer heals), feeding progress (stop early=
  spare, drain fully=kill), XP/leveling.
- DETERMINISM CHECK: run the sim for 600 ticks twice with the same seed. state_hash must match.
- After tests pass, launch the game windowed and PLAY it:
  Godot_v4.4.1-stable_win64.exe --path . --windowed --resolution 1280x720
  Can you make decisions? Do combos work? Does feeding feel like gaining power? Do enemies
  behave differently? If not, you're not done.

DO NOT:
- Touch any file in src/present/ (except CueBus.gd for registering new event channels)
- Add visual effects, shaders, particles, or UI elements (that's Track A and Track C)
- Break determinism. If you're not sure, run the hash test.
- Write planning documents instead of code
```

---

## TRACK C — Experience Integration

**Run this AFTER Tracks A and B are complete.** This track wires together the visual and
gameplay systems into a coherent player experience.

Copy everything between the `---` fences below into a new Claude Code session.

---

```
You are the integration layer for Vampire City, a Godot 4.7 / GDScript top-down vampire ARPG.
Two parallel tracks just ran: Track A rebuilt the visual engine (shaders, particles, lighting,
world rendering) and Track B rebuilt the gameplay engine (combos, enemy archetypes, feeding
redesign, progression). Your job is to WIRE THEM TOGETHER into a coherent player experience
through the HUD, UI, feedback systems, and onboarding flow.

READ THESE FILES FIRST (in this order):
1. docs/GAME_OVERHAUL_PLAN.md — the full plan. Read ALL of it but especially Part 3 (the
   vertical slice — this is the experience you're building), Part 4 (CueBus event contract),
   and Part 5 Track C (your task list).
2. src/present/CueBus.gd — the event bus. This is how you receive events from the sim.
   Track B added many new events. Read what's available.
3. src/present/VisualFX.gd — screen-level feedback. You're extending this.
4. src/present/EntityRenderer.gd — character rendering entry point. Track A modified this.
5. src/ui/UIManager.gd — the UI manager. You're modifying this extensively.
6. src/ui/CaptionOverlay.gd — text overlays. You'll use this for damage numbers, combo text.
7. src/ui/NotificationPanel.gd — notifications/banners. You'll rework this for onboarding.
8. src/present/CameraDirector.gd — camera. Track A modified kick values. You may fine-tune.

WHAT TRACK A SHIPPED (visual side — already in the code):
- Character outline/rim-light shaders (characters are readable)
- Hit flash shader (white flash on damage)
- GPUParticles2D: blood spray, rain, death dissolve, spell effects, ambient particles
- LightOccluder2D shadows on buildings
- Screen effects: vignette, bloom, damage vignette
- Parallax city backdrop
- TileMapLayer world rendering (the city looks like a city)
- Camera with real kick values (combat feels impactful)
- Possibly: Skeleton2D character animation OR higher-res atlases

WHAT TRACK B SHIPPED (gameplay side — already in the code):
- Status effects on entities (bleeding, burning, stunned, etc.)
- Combo trigger system (status-conditional bonus damage)
- Cast mechanic variety (instant, charged, channeled)
- Melee rework (light/heavy/combo, free but weak)
- 6 enemy archetypes (rusher, tank, shooter, healer, summoner, ambusher)
- Enemy telegraphs (wind-up before heavy attacks)
- Feeding redesign (power loop, spare/kill choice, resonance)
- XP/leveling with skill points
- Heat system (GTA-style escalation)
- Onboarding changes (no forced timed contract)

YOUR DELIVERABLES (in priority order):

1. COMBAT FEEDBACK — wire Track B's combat events to visible HUD elements:
   a. FLOATING DAMAGE NUMBERS: on "damage.dealt" cue, spawn a number that punches upward and
      fades. Styling: normal=white 24pt, crit=yellow 32pt + "CRIT!", combo=discipline-color +
      "COMBO: [name] x[mult]". Numbers should PUNCH — start large, shrink to final size, drift
      up. Reference: Diablo 3 damage numbers. Currently DAMAGE_FONT_SIZE=18 and RISE=48 —
      these are too small and too slow.
   b. STATUS EFFECT ICONS: on "status.applied" cue, show a small icon above the enemy's head
      (flame for burning, drops for bleeding, stars for stunned, snowflake for frozen, eye for
      marked, chains for mesmerized, skull for weakened, arrow-up for empowered). On
      "status.expired", remove the icon. Icons should be clear at game zoom level.
   c. COOLDOWN DISPLAY: the hotbar ability slots should show a spinning cooldown ring overlay
      when on cooldown, and flash/pulse when ready to use again.
   d. BLOOD/MANA BAR: make the blood bar FEEL alive — it should drain visibly on cast (animate
      the decrease), pulse when low (<20% blood), and glow/surge when feeding refills it.
   e. ENEMY HEALTH BARS: show a health bar above enemies when they take damage. Chunk animation
      on hit (white overlay that shrinks to show damage dealt). Elite/boss enemies get a larger
      bar with a name label.

2. ENEMY READABILITY — wire Track B's enemy events to visible indicators:
   a. ALERT INDICATORS: on "enemy.alert" cue, show ? (noticed, yellow), ! (alarmed, orange),
      or !! (hostile, red) above the enemy's head. Metal Gear Solid style.
   b. TELEGRAPH VISUALIZATION: on "enemy.telegraph" cue, show the appropriate warning:
      - Melee heavy: enemy briefly glows red/orange during wind-up
      - Ranged: line indicator showing aim direction
      - AoE: ground circle showing area of effect
      These must be CLEAR and READABLE — the player needs to react in 0.25-0.5 seconds.
   c. OFFSCREEN THREAT ARROWS: when hostile enemies are outside the viewport, show red arrows
      at the screen edge pointing toward them. Size/opacity based on proximity.

3. FEEDING EXPERIENCE — wire Track B's feeding events to a satisfying UX:
   a. BLOOD DRAIN METER: on "feed.start", show a circular or bar meter that fills as
      "feed.progress" events arrive. Pulsing heartbeat effect synced to drain progress.
   b. VICTIM STATE COMMUNICATION: the feed progress percentage should map to visible states —
      0-30%: "struggling" label, 30-70%: "weakening", 70-100%: "fading"
   c. CHOICE MOMENT: on "feed.choice" cue (player crosses 70% threshold), show a subtle
      prompt: "Release [F] to spare / Hold to drain fully"
   d. OUTCOME FEEDBACK: on "feed.spare" → green flash + "+[blood] Blood" popup.
      On "feed.kill" → red flash + "+[blood] Blood" + "Humanity -0.5" with screen desaturation.
   e. RESONANCE DISPLAY: before feeding, show the NPC's resonance aura color and what buff
      it grants. "Sanguine — +30% melee damage for 2 min"

4. NAVIGATION & GOALS:
   a. MINIMAP WAYPOINT: arrow on minimap pointing to current objective location
   b. OBJECTIVE DISPLAY: clear, simple text showing current goal. NOT "CONTRACT: drain the
      marked mortal (26s left)" — instead "Find someone to feed on" or "Reach your haven"
   c. DISTRICT LABELS: on entering a new district, brief banner: "OLD TOWN — Low Danger"
   d. DEATH EXPLANATION: on "player.death" cue, show a death screen that explains WHAT killed
      you and WHY: "Killed by Hunter — you were spotted feeding in the open" or "Burned by
      sunlight — reach your haven before dawn." The player must know what to do differently.

5. PROGRESSION FEEL:
   a. LEVEL-UP MOMENT: on "player.level_up" cue — flash, particle burst, "LEVEL [N]" banner,
      "+1 Skill Point" with an arrow pointing to the skill menu
   b. XP BAR: persistent XP bar at bottom of screen showing progress to next level. On
      "player.xp_gain", the bar fills with a satisfying animation and "+[amount] XP" popup.
   c. LOOT PICKUP: on "player.loot" cue — item name popup with rarity color (white/green/blue/
      purple/gold), brief glow at pickup location
   d. HEAT DISPLAY: on "heat.changed" cue — show heat level as star icons (like GTA wanted
      stars) in the HUD corner. Stars fill/drain with animation. At 0 stars, display is hidden.
   e. DAWN INDICATOR: on "dawn.warning" cue — the sky color shifts (Track A handles this), but
      also show a subtle HUD element: a sun icon rising at the screen edge, or the time display
      warming in color. No screaming timer — atmospheric urgency.

6. ONBOARDING FLOW:
   Wire the gentle onboarding that Track B set up:
   - First spawn: "You're hungry. Find someone to feed on." — no timer, no urgency
   - Near first NPC: "Hold [F] to feed" context prompt
   - After first feed: "Blood is your power. Use abilities with [1-5]."
   - After first ability use: "Combine abilities for bonus damage. Try bleeding then bolting."
   - After first combo: "Nice! Experiment with different combinations."
   - After first kill: brief "+[XP] XP" and explanation of leveling
   These should be one-time tutorial prompts that never repeat. Store "has_seen_tutorial_X"
   flags on the player or in a separate tutorial state.

VERIFICATION:
- Run GUT tests: Godot_v4.4.1-stable_win64.exe --path . -s addons/gut/gut_cmdln.gd -gexit
  All tests must pass.
- Launch the game and PLAY the first 10 minutes:
  Godot_v4.4.1-stable_win64.exe --path . --windowed --resolution 1280x720
  Walk through the vertical slice minute by minute:
  1. Do you start calm? No screaming timer?
  2. Can you find and feed on someone? Does the blood meter fill? Does the choice work?
  3. Do powers feel good? Visual feedback clear?
  4. Do enemies behave differently? Can you read telegraphs?
  5. Do combos work and show feedback?
  6. Do you know why you died (if you died)?
  7. Is the HUD helpful without being noisy?
  If ANY of these fail, fix it before reporting done.

DO NOT:
- Modify sim logic in src/sim/ or src/entities/ (Track B already did this)
- Modify shaders or particle systems in src/present/ that Track A built (use them, don't rebuild)
- Add new game mechanics (your job is to SURFACE existing mechanics, not create new ones)
- Write planning documents instead of code
```

---

## Quick Reference — Which Track Owns Which Files

| Directory / File | Track A | Track B | Track C |
|---|---|---|---|
| `src/sim/Sim.gd` | | **owns** | |
| `src/sim/SimWorld.gd` | | **owns** | |
| `src/sim/ImpulsePhysics.gd` | | **owns** | |
| `src/entities/SimPlayer.gd` | | **owns** | |
| `src/entities/SimNPC.gd` | | **owns** | |
| `src/entities/SimEntity.gd` | | **owns** | |
| `src/data/*` | | **owns** | |
| `src/present/EntityRenderer.gd` | **owns** | | |
| `src/present/CharacterAtlas2D.gd` | **owns** | | |
| `src/present/SpellFX.gd` | **owns** | | |
| `src/present/WorldFX.gd` | **owns** | | |
| `src/present/WorldRenderer.gd` | **owns** | | |
| `src/present/LightingDirector.gd` | **owns** | | |
| `src/present/CameraDirector.gd` | **owns** | | reads |
| `src/present/VisualFX.gd` | **owns** | | extends |
| `src/present/CueBus.gd` | reads | registers | reads |
| `src/ui/UIManager.gd` | | | **owns** |
| `src/ui/CaptionOverlay.gd` | | | **owns** |
| `src/ui/NotificationPanel.gd` | | | **owns** |
| `assets/`, `shaders/` | **owns** | | |
| `test/unit/*` | | **owns** | may add |
| `tools/visual/*` | **owns** | | |

**The only shared file is `CueBus.gd`** — Track B registers new event channels, Track A and C
consume them. The event contract in `docs/GAME_OVERHAUL_PLAN.md` Part 4 is the binding agreement.
If either track needs a new event not in the contract, add it to the plan file with a comment
so the other track can pick it up.
