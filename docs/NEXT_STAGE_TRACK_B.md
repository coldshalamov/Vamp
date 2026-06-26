# Next Stage: Track B — Gameplay Engine

> **Why this is the critical path:** The visual engine is shipped. The UI shells are built and
> waiting. But they're all consuming CueBus events that DON'T EXIST YET because the sim hasn't
> been upgraded. FeedingHUD listens for `feed.progress` — never fires. ProgressionHUD listens
> for `player.xp_gain` — never fires. WorldIndicatorLayer listens for `enemy.telegraph` — never
> fires. Track B is the thing that makes every other piece come alive.

## What Already Exists In The Sim (Don't Rebuild)

Read these carefully — they're the foundation you're extending, not replacing:

**SimEntity.gd** (src/sim/SimEntity.gd):
- `statuses: Dictionary` — keyed by status name, value is remaining ticks
- `status_data: Dictionary` — keyed by status name, value is dict of params (dps, factor, etc.)
- `apply_status(status_id, ticks, data)` — applies stun/mesmerize/fear/root, sets stun counter
- `has_status(status_id)` — checks if status is active
- `speed_factor()` — checks slow/shock/root/stun for movement speed
- Already handles: stun (can't act), root (can't move), fear (flee), mesmerize (freeze),
  slow (reduced speed), shock (reduced speed + 15% more damage taken)

**Sim.gd damage_entity()** (src/sim/Sim.gd ~line 191):
- Already applies statuses from opts["status"] + opts["status_ticks"]
- Already has two hardcoded combo checks:
  * `mark` status → +25% damage (configurable via status_data.mark.amount)
  * `mesmerized` status → +50% damage, emits `combo.shatter`
- Already has: crit system, armor, front_armor (directional), resistance by damage type,
  knockback, hitstop, blood spill on hit, lifesteal, i-frame dodge check
- Already emits: `damage.dealt`, `hit.connect` (melee only), `dodge.iframe`, `player.died`

**SimPlayer.gd** (src/entities/SimPlayer.gd):
- 30+ powers across disciplines (cel_dash, pot_slam, bs_bolt, shd_tendril, etc.)
- `flow_stacks` — builds from perfect gulp timing, +8% melee per stack
- `blood` / `max_blood` — the mana resource (72/100)
- Gulp timing minigame (GULP_PERIOD=42, GULP_WINDOW=15, perfect=2x vitae)
- Has `behaviour` dict with `buffs`, `iframes_remaining`, `flow_stacks`
- Resonance buffs already apply from feeding (res_choleric, res_phlegmatic, etc.)

**ActionDef.gd** (src/sim/ActionDef.gd):
- `applies_status` — status to apply on hit
- `cancel_into` — which actions can cancel into this one
- Has fields for timing: startup_frames, active_frames, recovery_frames
- `hitstop_ticks`, `knockback`

**SimNPC.gd** (src/entities/SimNPC.gd):
- Has `ai_state` (idle/patrol/alert/chase/attack/flee/search)
- Has LKP (last known position) search with 3 behaviors
- Gun NPCs fire visible projectiles
- Uses A* pathfinding via SimWorld.find_path()

**CueBus** (src/present/CueBus.gd):
- Signal-based event bus, emit_cue() on Sim.gd
- Existing events include: damage.dealt, hit.connect, dodge.iframe, player.died,
  feed.start, feed.gulp, feed.gulp.perfect, feed.gulp.miss, feed.end,
  combo.shatter, humanity.changed, masquerade.breach, dawn.warning, dawn.arrived

## The Agent Prompt

```
You are upgrading the gameplay engine of Vampire City, a Godot 4.7 / GDScript top-down vampire
ARPG. The visual engine is done (shaders, particles, lighting, rain). The UI is built and
WAITING for CueBus events you will create. Your job is to make the combat, feeding, and
progression systems actually produce fun gameplay.

READ THESE FILES FIRST (in this order — understand what exists before changing anything):
1. docs/GAME_OVERHAUL_PLAN.md — the full plan. Read Part 1 (design principles), Part 3 (the
   vertical slice — what the first 10 minutes should feel like), Part 4 (CueBus event contract),
   Part 5 Track B (your task list).
2. src/sim/Sim.gd — the main simulation. Read damage_entity() carefully (~line 191). It already
   has status checks (mark, mesmerized), crits, armor, directional front_armor, resistances,
   knockback, i-frames, and lifesteal. EXTEND this, don't rewrite it.
3. src/sim/SimEntity.gd — base entity. Read apply_status(), has_status(), speed_factor().
   The status framework EXISTS but only handles stun/mesmerize/fear/root/slow/shock. You need
   to add bleeding (DoT ticks), burning (DoT ticks), frozen (shatter combo), weakened (+dmg
   taken), empowered (+dmg dealt), and marked (already partially works).
4. src/entities/SimPlayer.gd — the player. Read the full power list, gulp timing, flow stacks,
   blood economy. You're modifying power execution and adding progression.
5. src/entities/SimNPC.gd — NPC AI. You're adding archetype behaviors.
6. src/sim/ActionDef.gd — action definitions. You may add fields for cast_type, combo_trigger.
7. src/sim/SimWorld.gd — world grid. Has encounter_points[] (3 templates defined but not
   consumed), districts, blood/fire layers.
8. src/present/CueBus.gd — the event bus. Register your new events here.
9. src/ui/FeedingHUD.gd — ALREADY BUILT, waiting for: feed.progress, feed.choice, feed.spare,
   feed.kill events. Read what it expects.
10. src/ui/ProgressionHUD.gd — ALREADY BUILT, waiting for: player.xp_gain, player.level_up,
    player.loot events. Read what it expects.
11. src/present/WorldIndicatorLayer.gd — ALREADY BUILT, waiting for: enemy.telegraph,
    enemy.alert events. Read what it expects.
12. src/ui/TutorialDirector.gd — ALREADY BUILT, waiting for tutorial trigger events.

CRITICAL RULES:
1. DETERMINISM IS SACRED. Use ONLY the LCG RNG (entity.rng / sim rng via draw_float/draw_int).
   NEVER use randf(), randi(), Time.*, or any Godot random/time function.
   After your changes, state_hash must be identical across 20 runs with the same seed.
2. EXTEND, DON'T REWRITE. damage_entity() already works. apply_status() already works.
   Add new status types, add combo checks, add new code paths — but don't gut what's there.
3. EMIT CUEBUS EVENTS that the existing UI shells expect. The UI code is ALREADY WRITTEN
   and listening. Your job is to make the sim emit the events they need.
4. You may NOT touch files in src/present/ except CueBus.gd (to register new event channels).
   The visual engine is done — hands off.

YOUR DELIVERABLES (in priority order — do phase 1 first, verify, then phase 2, etc.):

PHASE 1 — Status effects + combo triggers (the foundation everything else needs):

1. EXTEND STATUS TICK PROCESSING in the sim's main tick loop:
   SimEntity already stores statuses with tick counts. Add processing for:
   - bleeding: ticks DPS damage per second (status_data.bleeding.dps), stacks
   - burning: ticks DPS damage per second, does NOT stack (refreshes duration)
   - frozen: slowed 50% (already via speed_factor), SHATTERS on next hit for bonus damage
   - weakened: takes 30% more damage (add check in damage_entity)
   - empowered: deals 30% more damage (add check in damage_entity)
   Emit "status.applied" on apply_status(): { target_id, status, duration, source_id }
   Emit "status.expired" when a status ticks to 0: { target_id, status }
   WorldIndicatorLayer is ALREADY listening for these events to show icons.

2. GENERALIZE THE COMBO SYSTEM in damage_entity():
   Currently there are two hardcoded checks (mark, mesmerized). Replace with a data-driven
   combo check that runs after damage calculation:
   
   Define combos (in Sim.gd or a new data file):
   - hemorrhage: target has "bleeding" + attacker uses blood ability → +50% damage, consume bleed
   - execute: target has "stun" + attacker uses melee → +100% damage, consume stun
   - shatter: target has "frozen" + any hit → +80% damage + AoE burst, consume frozen
   - pyre: target has "burning" + fire ability → AoE explosion around target, consume burn
   - soul_rend: target has "marked" + shadow ability → +50% damage + heal 30%, consume mark
   
   On combo trigger, emit: combo.trigger { entity_id, target_id, combo_name, bonus_damage, pos }
   Keep the existing mark and mesmerized checks working (just fold them into the new system).

3. MAKE EXISTING POWERS APPLY STATUSES:
   Map discipline powers to statuses they should apply:
   - bs_bolt (Blood Bolt): apply "bleeding" 5s
   - bs_storm: apply "burning" 3s in AoE
   - shd_tendril: apply "marked" 8s
   - pot_slam: apply "stun" 1.5s
   - pot_quake: apply "stun" 1s in AoE + "weakened" 5s
   - cel_dash: already has i-frames, no status needed
   - dom_mesmer: already applies mesmerized
   - pre_dread: already applies fear
   - for_stone: apply "empowered" 5s to self
   - pro_claws: apply "bleeding" 3s on each hit
   
   Update ActionDef or the power execution code to apply these statuses via the existing
   damage_entity opts["status"] mechanism.

PHASE 2 — Enemy archetypes + telegraphs:

4. ADD ARCHETYPE FIELD TO SimNPC and wire distinct behaviors:
   
   npc.archetype = "rusher" | "tank" | "shooter" | "healer" | "summoner" | "ambusher"
   
   In the NPC AI tick, branch on archetype:
   - rusher: high move speed (×1.4), charges at player, melee chain, low HP (×0.6)
   - tank: slow (×0.7), high HP (×2.0), has front_armor tag (blocks 40% frontal damage —
     this already works in damage_entity!), heavy hits (×1.5 damage)
   - shooter: maintains preferred_range (200px), backs up if player closes, ranged attacks
   - healer: stays behind allies (find nearest ally, position behind them relative to player),
     every 180 ticks pulses HoT on nearby allies within 128px
   - summoner: every 300 ticks spawns a weak minion (rusher with 30% HP), max 3 active
   - ambusher: starts with "obfuscate" tag (invisible until close), first attack from stealth
     does 2× damage, revealed on attack or if player has auspex active
   
   Set archetype when spawning NPCs. Use encounter_points[] in SimWorld (already has 3
   templates defined — "street_thugs", "gang_squad", "hunter_cell"). Wire Sim to read these
   and spawn the right archetypes.

5. ADD ENEMY TELEGRAPHS:
   All NPC heavy attacks get a wind-up phase (15-25 ticks):
   - Before attacking, set npc.telegraphing = true, npc.telegraph_ticks = wind_up_duration
   - During telegraph: NPC can't change target or move, telegraph_ticks counts down
   - When telegraph_ticks hits 0: execute the attack
   - Emit "enemy.telegraph" { entity_id, pos, direction, attack_type, wind_up_ms }
     WorldIndicatorLayer is ALREADY listening for this.
   
   Light attacks (rushers, basic melee): no telegraph, fast, weak.
   Heavy attacks (tanks, bosses): 20-tick telegraph, strong. The player reads the wind-up
   and decides: dodge, interrupt with CC, or tank it.

PHASE 3 — Feeding redesign:

6. FEEDING AS POWER LOOP:
   Currently in SimPlayer — find the feeding code and modify:
   - Remove humanity loss from feeding. Only killing costs humanity.
   - Add continuous feed.progress emission (every 10 ticks during feed):
     { entity_id, target_id, progress_pct, blood_gained }
     FeedingHUD is ALREADY listening for this.
   - At 70% drain, emit feed.choice { entity_id, target_id, can_spare: true, blood_pct }
     FeedingHUD is ALREADY listening for this.
   - On release before 100%: emit feed.spare { entity_id, target_id, blood_gained, humanity_kept }
   - On full drain (100%): emit feed.kill { entity_id, target_id, blood_gained, humanity_lost }
     Apply humanity loss ONLY here, not on feed.start or feed.end.
   
   The gulp timing minigame can stay — it's the "perfect timing" bonus on TOP of the base drain.

7. BLOOD RESONANCE BUFFS:
   NPCs already have a `resonance` field on SimEntity. When feeding completes, apply a
   timed buff based on victim's resonance:
   - sanguine: +30% melee damage for 7200 ticks (~2 min)
   - choleric: +30% spell damage for 7200 ticks (res_choleric already partially works!)
   - melancholic: +stealth effectiveness for 7200 ticks
   - phlegmatic: +HP regen for 7200 ticks (res_phlegmatic already partially works!)
   
   Emit the resonance type in feed events so the UI can display it.

PHASE 4 — Progression + onboarding:

8. XP AND LEVELING:
   Add to SimPlayer: xp (float), level (int), skill_points (int)
   XP sources: kill (scale by enemy max_hp), feeding (flat 25), combo trigger (10)
   Level thresholds: [100, 250, 500, 800, 1200, 1700, 2300, 3000, 4000, 5000]
   On level up: +1 skill_point, +10 max_blood, +5 max_hp
   Emit: player.xp_gain { amount, source, pos }
   Emit: player.level_up { level, skill_points, pos }
   ProgressionHUD is ALREADY listening for both of these.

9. ONBOARDING FIX:
   Find where the timed contract fires on game start (likely in Sim.gd or a scene script).
   Replace with:
   - On first spawn: no timer, no contract. Just the player in the city.
   - Emit a tutorial event for TutorialDirector: { step: "first_spawn" }
   - After first feed: emit { step: "first_feed_complete" }
   - After first kill: emit { step: "first_kill" }
   - After first combo: emit { step: "first_combo" }
   TutorialDirector is ALREADY listening and will show the right prompts.

10. HEAT ESCALATION:
    Add to Sim or SimPlayer: heat_stars (int 0-5)
    Heat rises from: public feeding (+1), combat in view of civilians (+1), overt power use (+1)
    Heat decays: -1 every 600 ticks when player isn't causing trouble
    Tiers affect NPC spawn aggression:
    - 0: peaceful, NPCs ignore you
    - 1-2: alert, nearby NPCs investigate
    - 3-4: hostile, police/hunter patrols spawn and seek
    - 5: full hunt, heavy response
    Emit: heat.changed { old_stars, new_stars }

TESTING:
- LOCAL WINDOWS SAFETY: do not run raw Godot or recursive GUT on this machine. Use
  `powershell -ExecutionPolicy Bypass -File .\scripts\RunGutSafe.ps1` for local checks.
  Full recursive GUT belongs in CI or requires an explicit `VAMP_ALLOW_FULL_GUT=1` override.
- Existing tests must pass in CI. Your changes must not break determinism.
- Write NEW GUT tests for each phase:
  Phase 1: status ticks (bleeding does damage over time), combo triggers (bleed+bolt=hemorrhage)
  Phase 2: archetype behaviors (rusher charges, healer heals), telegraph timing
  Phase 3: feeding progress events, spare vs kill humanity, resonance buff application
  Phase 4: XP gain and level up, tutorial step emission
- DETERMINISM: run the sim for 600 ticks twice with identical seeds. state_hash must match.
- Do not launch the game locally unless the user explicitly asks. If playtesting is approved, use
  `PlayGame.bat` for the normal full-presentation game and stop immediately on memory growth.
  `PlayGame.bat --safe` is only an emergency reduced-visual fallback. Fight enemies — do combos work? Do enemies behave differently? Feed — does blood fill
  visibly? Does the death screen explain what killed you? If not, you're not done.

DO NOT:
- Rewrite damage_entity() from scratch (extend it)
- Rewrite apply_status() from scratch (extend it)
- Touch files in src/present/ except CueBus.gd
- Touch files in src/ui/ (the UI is built, it just needs your events)
- Add visual effects, shaders, or particles
- Break determinism
- Write planning documents instead of code
```
