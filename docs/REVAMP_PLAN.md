# Vampire City — The Revamp Plan

> **Status:** Operating plan. Supersedes `.claude/plans/improvement-plan.md` (now demoted to the
> Phase 3 content menu) and replaces the "stay in JS" implication of `docs/HANDOFF_QUALITY_BAR.md`.
> The handoff doc's *discipline* (DoD, anti-loop guardrails, vertical-slice convergence) still governs;
> only the *engine choice* changes.

**Date:** 2026-06-21 · Iteration 0 of the revamp

---

## 0. The decision, and why

**Engine: Godot 4 (GDScript), 2D top-down.** This is a port, not a fresh start.

The single sentence that justified it: *the disease this project has is missing foundations, and
Godot ships with five of the six missing foundations for free.* On the old JS codebase we would have
had to hand-build a headless test runner, a 2D lighting system, an art/animation pipeline, an audio
bus system, input remapping, and save-slot management — months of plumbing that produces zero visible
game improvement, which is precisely the work the feature-factory disease starves. Godot gives all of
it natively, plus native Steam export, a profiler, and a debugger.

**What we keep (the valuable assets):**
- The design corpus: `improvement-plan.md`, `HANDOFF_QUALITY_BAR.md`, this plan.
- The content data: `gamedata.js` clans, powers, enemies, loot tables — trivially portable to Godot
  Resource files. This is genuinely valuable: ~36 powers across 10 disciplines already designed with
  costs, cooldowns, glyphs, descriptions. Re-authoring this from scratch would be weeks.
- Every regression class the QA probes (`scripts/qa-smoke.mjs`, `wave9/10/13`) taught us to watch for:
  save sanitization, placement-on-walkable-tiles, damage-type routing, malformed-save hardening. These
  become the first Godot test suite.
- The vertical-slice specification (§3 below).

**What we discard (the liabilities):**
- The entire `js/` tree. It embodies the disease: wide-but-shallow feature code, `window.VAMP` global
  coupling, `Math.random` in authoritative paths, no frame data. Porting it would carry the disease.
- The Canvas 2D renderer. WebGL via Pixi was the alternative; Godot supersedes both.
- `server.js`, `index.html`, the `<script>` dependency chain.

**Archived, not deleted:** `js/`, `scripts/`, `server.js`, `index.html`, `score.js`, `scored.json`
move to `legacy/` with a README. They remain reference material for porting data and behavior. The
git history is untouched.

---

## 1. What this game reminds me of — and what each one teaches us

The brief was "think about all the games it reminds you of." Here is the honest map, with the
specific lesson each one carries for Vampire City. The bolded games are the load-bearing references.

### The combat-feel references

- **`Hotline Miami`** (top-down, brutal, one-hit-kill both ways). Lesson: **the ceiling on top-down
  combat feel is set almost entirely by frame data and audio-visual commitment.** Every action has
  startup/active/recovery; every kill is loud, heavy, and instant; death is symmetric (you die in one
  hit, so do they). Vampire City should not copy the one-hit lethality (it's an RPG), but it must copy
  the *commitment* — no action should be interruptible into nothing, and a clean kill should feel like
  a statement. This is the combat grammar backbone, made concrete.
- **`Hades`** (isometric action-RPG, the modern gold standard for "fun mechanics"). Lessons: (1) every
  weapon plays genuinely differently because each has a distinct input grammar (sword = combo + spin,
  bow = charge + special, rail = auto-fire + bomb); (2) the dash is the best-feeling defensive verb
  in the genre and should be studied frame-for-frame; (3) the Boon system is the model for the
  "Predator Combos" — boons don't add numbers, they *rewrite how a weapon behaves*. Vampire City's
  clan keystones and power synergies should aim here.
- **`Diablo / Path of Exile`** (top-down loot-ARPG). Lesson: **build diversity comes from items and
  synergies rewriting the core loop, not from a wider spell list.** A Poe character with 12 active
  skills feels identical to one with 6; a character with one skill supported by 8 transformative
  items feels completely different. Resist the urge to add powers; add *interactions*.
- `Bastion` / `Transistor` (Supergiant's earlier work). Lesson: isometric narration + reactive world.
  The narrator *describes what you do*. Vampire City's Humanity system should feel this responsive —
  the world narrates your moral arc through behavior, not banners.

### The vampire / immersive-sim references

- **`Vampire: The Masquerade — Bloodlines`** (the namesake and north star for fiction). Lessons:
  (1) other vampires are the real threat, not mortals — Vampire City has zero rival vampires and this
  is a gaping hole; (2) clan choice must feel load-bearing from minute one (a Nosferatu run is a
  different *game*); (3) the Masquerade is a mechanical system (breaking it summons hunters), not
  flavor; (4) social/dialogue paths can resolve major beats without violence — the "talker build" is
  legitimate.
- **`Dishonored`** (immersive sim with vampire-adjacent powers). Lesson: **every problem has 3+
  systemic solutions and the world simulates them.** A guard can be killed, sneaked past, possessed,
  distracted, or turned against an ally. Vampire City's disciplines are *built* for this — Dominate,
  Obfuscate, Presence, blood pools that conduct — but currently none of them interact with the world
  systemically. This is the single biggest untapped design space.
- `Thief` / `Mark of the Ninja` (stealth state machines). Lesson: a stealth game lives or dies on its
  suspicion/investigation/search/reacquisition loop with *memory and uncertainty*. Vampire City's
  Masquerade fiction is a lie without this. `npc.js` already has the best AI in the current game
  (exposure-driven perception, last-known-position investigation, give-up timers); the Godot port
  formalizes and deepens it.

### The open-world / crime references

- **`GTA 1/2`** (the stated top-down GTA reference). Lesson: **the city exists without you.** Gangs
  fight each other over territory whether or not you're there; the wanted system escalates through
  coherent tiers; the radio is a signature atmospheric multiplier. Vampire City's flywheel economy
  and gang territory AI from the improvement plan aim here.
- `Sleeping Dogs` / `Yakuza` (open-world melee crime). Lesson: hand-to-hand combat depth can carry an
  entire open world. Vampire City's melee is currently the weakest verb; these games prove a
  top-down/3rd-person brawler loop is enough to anchor 40 hours.
- `Bully` (Rockstar's smaller-scale open world). Lesson: a *compressed* open world with a daily
  rhythm (classes, curfew, faction politics) can feel richer than a giant one. Vampire City's
  night/day cycle and "one city block at a time" territory expansion should study this.

### The progression / roguelite references

- **`Vampire Survivors`** (the naming collision is a sign). Lesson: weapon *evolution* via passive
  synergy is a phenomenally cheap, phenomenally fun progression engine. The improvement plan's
  "Weapon Evolution via Passive-Item Synergy" is exactly this and should be a first-class system.
- `Risk of Rain 2` / `Returnal`. Lesson: a difficulty-scales-with-time clock turns aimless farming
  into a survival pressure. Vampire City's dawn is the perfect diegetic clock — currently toothless.
- `Dead Cells` / `Hades` (meta-progression). Lesson: runs that fail should still move a permanent
  bar forward. Vampire City's "New Bloodline" prestige system aims here.

### The one-sentence synthesis

Vampire City should feel like **Hotline Miami's combat commitment, Hades's build diversity and dash,
Dishonored's systemic problem-solving, VtM: Bloodlines's clan-as-identity and Masquerade tension,
and GTA's living city — expressed through a 2D top-down vampire lens with authored art and real
lighting.** That is an ambitious but coherent target. Every system below serves one of those clauses.

---

## 2. The design pillars (every feature must serve one)

These replace the four words in the handoff doc with checkable design intent.

1. **Predator** — combat and traversal must reward positioning, timing, and choice of approach over
   raw stats. The verbs have a skill ceiling. *(Hotline Miami, Hades.)*
2. **Rise** — progression is a visible climb through named tiers (street → coterie → domain →
   dominion), with locked aspirational goals visible from night one. *(GTA, Mount & Blade.)*
3. **Cost** — every gain costs something diegetic: Humanity, blood, heat, a relationship, a district's
   loyalty. The fiction is embodied in the economy, not banners. *(VtM:B, Dishonored.)*
4. **Continuous** — the city simulates without you; nights have rhythm; failure generates content, not
   a reload. *(GTA, Dead Cells.)*

Anything that serves none of these is cut. This is the merge gate.

---

## 3. The vertical slice: "The First Hunt" (north star)

One polished, 12–18 minute playable night that proves the game can be great. It is the merge gate
for Phase 1: **nothing else ships until it passes the DoD at 100%.**

### The slice scenario

A clan-initiation night. You are a newly embraced fledgling; your sire's rival wants you dead before
dawn. In 15 minutes the night must force:

1. **Feed** — a real feeding encounter with a load-bearing Gulp mini-game and a kill/spare choice.
2. **Fight** — a combat encounter that requires a *specific* verb (an enemy with a shield you must
   flank, or a warded enemy immune to fear) so the build matters.
3. **Use your clan keystone** — the rule-changing power (Brujah's Blood Rage toggle, Tremere's
   blood-cost halving, etc.) must be mechanically necessary, not decorative.
4. **Trigger a Humanity loss that changes the world** — after a kill, NPCs flinch near you, the
   screen bleeds at the edges, frenzy risk ticks up. Not a banner.
5. **Be hunted by something that searches** — a hunter who saw you feed investigates your
   last-known position, loses you, can be deceived by Obfuscate. The Masquerade as a real system.
6. **End on a hook** — the sire's rival appears as a nemesis tease (a watcher who vanishes), setting
   up the return.

### The slice's success criterion (the disease-denying metric)

**A skilled player's run must be measurably different from a masher's.** Concretely, on the same
seed: a skilled player clears the combat encounter ~30% faster, takes ~50% fewer hits, and feeds
with higher efficiency (fewer missed Gulps, more spared targets retained as allies) — *because the
verbs now reward mastery, not because their numbers are bigger.* This is the testable claim that
proves we broke the local minimum. If the skill gap doesn't exist, the slice fails even if it "plays
fine."

### What the slice forces us to build (the Phase 1 scope)

The slice is small in *content* but demands every *foundation*. This is deliberate — it's how the
slice becomes the merge gate rather than a demo.

---

## 4. Phase 1 — Foundations + Vertical Slice (the "make it fun" phase)

This is the phase that produces the first playable, polished, fun build. It is the entire focus
until the slice passes the DoD. No flywheel, no lair, no radio, no rival vampires here.

### 1.1 The Godot project skeleton
- Godot 4.3+, GDScript, 2D top-down.
- Directory structure: `src/` (game code), `data/` (Resources — ported from `gamedata.js`),
  `art/`, `audio/`, `tests/`, `scenes/`.
- Fixed-timestep physics (`Engine.physics_ticks_per_second`, deterministic).
- A single autoload `Sim` singleton as the authoritative game state — *the headless core*. This is
  the handoff doc's backbone #1, and Godot makes it natural: the sim knows nothing about nodes or
  rendering; the scene tree is a view onto it.

### 1.2 The deterministic sim core (`Sim`)
- All gameplay state (player, NPCs, powers, economy, AI) lives in plain classes, not Nodes.
- A single seeded RNG (`RandomNumberGenerator` with explicit seed) — *zero* `randf()`/`randi()` in
  authoritative code. This is handoff guardrail #6.
- `Sim.tick(delta)` advances the world one step; `Sim.apply_input(action)` mutates it.
- Godot's `--headless` mode runs the sim with no rendering. This is the test runner.
- **Acceptance:** `godot --headless -- script run_slice.gd --seed 42` produces byte-identical
  output across 20 runs; a recorded input sequence replays deterministically.

### 1.3 The combat grammar (`ActionDef`) — THE fun work
This is the backbone that fixes the disease. Every player and AI action is defined by frame data:

```
ActionDef:
  startup: int      # frames before the hit is active
  active: int       # frames the hitbox is live
  recovery: int     # frames before you can act again
  cancel_into: []   # which actions can interrupt recovery (the combo system)
  cost: float       # blood/stamina
  cooldown: float
  hitbox: Shape2D   # authored shape, not a radius
  knockback: float
  hitstop: float    # freeze frames on connection
```

- The melee combo becomes a real *frame-cancelable* sequence: light → light → heavy, where the heavy
  must be input during the light's cancel window or you get the slow recovery. A masher gets the
  recovery; a skilled player gets the combo. **This is the skill ceiling.**
- Every power is re-expressed as an `ActionDef` with a distinct input grammar:
  - **Blood Bolt** = aim + release (lead the target).
  - **Earthshock** = hold to charge radius, release to commit (stationary recovery — a commitment).
  - **Dash** = directional double-tap with i-frames (the Hades dash).
  - **Mesmerize** = cone-aim + brief channel (a setup, not an instant).
  - **Heal (Mend Flesh)** = hold to channel, immobile (a real cost — you're vulnerable).
- The Predator Combos (Mark→Detonate, Mist→Ambush, etc.) become real *cancel sequences*: landing
  Mark during a Bolt's recovery cancels into Detonate at reduced cost. Discovery-driven depth.
- **Acceptance:** a scripted `dash → mark → detonate` produces an exact tick trace; the skill gap
  between a scripted expert and a masher is measurable in a headless benchmark.

### 1.4 Perception-based stealth + hunter AI
- State machine: `UNAWARE → SUSPICIOUS → INVESTIGATING → SEARCHING → REACQUIRING → (lose)/COMBAT`.
- Hunters remember a last-known-position with uncertainty (a spreading search cone, not a point).
- Feeding in line of sight of a witness creates a *sighting*; multiple sightings escalate heat.
- Obfuscate genuinely defeats perception (reduces sighting range, erases trail); running/sprinting
  in light increases it.
- **Acceptance:** across 100 seeded runs, a hunter that saw you feed exhibits ≥3 materially
  different search behaviors (direct pursuit, flank, give-up-and-ambush, call allies).

### 1.5 The presentation orchestration (cue layer)
- A `CueBus` that maps semantic events (`feed.start`, `humanity.lost`, `masquerade.broken`,
  `hunter.alarmed`, `kill.elite`) to a *single coordinated* presentation: camera move + audio sting
  + VFX burst + HUD flash, with priority, concurrency limits, and accessibility transforms
  (reduced-motion flattens shake/flash).
- Godot's AnimationPlayer + AudioServer buses make this natural. This is handoff backbone #5.

### 1.6 Authored art + real lighting
- **The art direction decision (defaulted):** curated 2D sprite art, top-down, ~32–48px characters,
  limited gothic palette (deep blues/purples, blood reds, candle golds). Either commissioned or a
  licensed cohesive pack — *no more procedural primitives for hero assets.* Procedural generation
  is permitted only for things that should vary (loot affixes, graffiti, blood splatter).
- **Lighting as atmosphere:** Godot 2D lights + shadows. The vampire game lives in pools of light
  cut by darkness. Streetlamps, headlights, muzzle flashes, the feeding vignette, moonlight through
  alleys — all real light sources casting real shadows. This single system does more for "looks
  professional" than any other.
- Sprite atlas + batched drawing (Godot handles this natively).
- Animation: authored frames for idle/walk/attack/feed/death per character class.

### 1.7 The playable night
- One district block (~1 screen of content), handcrafted.
- 4–6 enemy types with at least 2 that demand specific counters.
- The full feed → fight → keystone → humanity → hunt → hook arc from §3.
- Game feel pass: input buffering, coyote windows on the dash, hitstop on *every* connection,
  knockback + recoil on every weapon, camera that pushes in on action and trauma-shakes on damage.

### 1.8 The test suite (real tests, finally)
- Port the regression classes from the JS QA probes into Godot integration tests:
  save sanitization, placement-on-walkable-tiles, damage-type routing, malformed-save hardening.
- Add the tests the headless sim now makes possible: combat skill-gap benchmarks, AI search-behavior
  diversity property tests, deterministic replay golden traces.
- CI: GitHub Action runs `godot --headless` on every push. Tests must pass to merge.

### 1.9 Phase 1 Definition of Done (the merge gate)
The slice passes when **all** of these hold:
- [ ] Deterministic: 20 headless runs of the slice, same seed = identical hash.
- [ ] Skill gap: the scripted-expert benchmark beats the masher benchmark by the §3 margins.
- [ ] AI diversity: hunter search behaviors pass the property test (≥3 materially different).
- [ ] Every player action has frame data and a <100ms feedback cue.
- [ ] Hitstop on every connection, not just crits/kills.
- [ ] Authored art for every hero asset in the slice; no placeholder primitives.
- [ ] Real lighting in every scene.
- [ ] 5 consecutive clean runs: zero console errors, zero crashes.
- [ ] A blind playtester can name the hook after 30 seconds.
- [ ] The Humanity loss visibly changes the world (NPC behavior + screen state), not just a banner.
- [ ] CI green on the full test suite.

**Phase 1 is "the game is fun." Nothing past this point matters until it's true.**

---

## 5. Phase 2 — Deepen the verbs and the world (post-slice expansion)

Only after Phase 1's DoD passes. Each item ships as a gold packet gated on the DoD.

### 2.1 The full power roster, re-expressed in the combat grammar
- Port all ~36 powers from `gamedata.js` into `ActionDef` Resources. Each gets a distinct input
  grammar (no two powers share the same input shape).
- Add the genuinely missing verbs: a **player-activated time-slow** (Predator Sense / Dead-Eye —
  paint targets, unleash a flurry; the cel_bullet power is a seed for this), a **ranged weapon
  system** (firearms/crossbows with reload and recoil), and a **castable heal line** (already have
  Mend Flesh; extend to a HoT and an AoE ally heal).
- Every power ships with ≥1 enemy that demands it and ≥1 enemy that counters it.

### 2.2 Enemy variety with forced counters
- Expand from 9 presets to ~15, each with a distinct *counter* (not just stats):
  - **Shield riot cop** — must flank or dash behind (front-armor, already prototyped).
  - **Warded inquisitor** — immune to fear/CC; must be out-damaged or maneuvered into environmental
    hazards (fire, sunlight patches).
  - **Blood-mage rival** — uses your own powers against you; must be interrupted during channel.
  - **Frenzied ghoul** — ignores stagger; must be kited or root-locked.
  - **Sniper spotter** — calls in allies; must be silenced first (priority target).
- Elite affixes recombine these into tactical puzzles.

### 2.3 Rival vampires (the gaping hole)
- A new NPC class that uses a subset of the player's discipline powers, has a clan affiliation, can
  feed to heal, dodges, and can become a nemesis. VtM:B's identity came from other vampires being
  the real threat. Vampire City currently has zero.

### 2.4 The flywheel economy (from improvement-plan.md, now earned)
- Tier 0 street → Tier 1 automations → Tier 2 territory → Tier 3 lair rooms → Tier 4 dominion.
- Locked aspirational goals visible on the map from night one.
- Money must never feel meaningless past L20 (the success criterion).

### 2.5 The Lair as a place (not a menu)
- A real interior scene with rooms you purchase and walk into. Blood Cellar, Armory, War Room,
  Alchemist's Lab, Library, Trophy Hall, Throne Room. Each unlocks gameplay.

### 2.6 Gang territory AI + the living city
- Background `faction_tick`: gangs contest territory whether or not you're there. You can weaponize
  it (pay one gang to hit another). Creates the GTA "city exists without you" feel.

---

## 6. Phase 3 — Content depth, breadth, and the endgame

The improvement-plan.md feature menu lives here, gated on contracts. Bulk-content agents fill
schemas; they never invent them (handoff guardrail #10).

- All 5 authored standalone missions (The Masquerade Ball, The Burning Haven, Blood Test, The
  Betrayal, Prince's Last Night).
- Radio stations (procedural WebAudio → port to Godot AudioServer synthesis or authored stems).
- The full endgame loop: Lord of the Night state, The Final Siege, victory screen, New Bloodline.
- Difficulty modes (The Masquerade / The Danse Macabre / The Bloodhunt).
- Codex/bestiary, achievements, Steam prerequisites polish (already partially done: save slots,
  fullscreen, credits, death screen).

---

## 7. What this changes about how we work

- **No more feature-by-score selection.** `score.js`/`scored.json` are frozen artifacts; the
  backlog is this plan, sequenced.
- **Every task gets a DoD, not a feature name.** "Add parry" is forbidden; "add a parry with a
  6-frame window defined in ActionDef, ≥1 enemy that telegraphs a parryable attack, golden replay
  passes, scripted-expert beats masher by ≥X%" is allowed.
- **The merge gate names a slice metric it improves.** A change that doesn't move a Phase 1 metric
  (skill gap, AI diversity, frame-data coverage, lighting coverage) doesn't merge until the slice
  ships.
- **One unfinished structural branch at a time.** No stack of half-integrated rewrites — that's how
  the JS codebase got `p.reagents` ghosts and quests/events duplication.
- **The old code is reference, not a constraint.** When porting, ask "what does this need to be to
  serve the pillars?" not "how do I reproduce this in Godot?"

---

## 8. The first concrete steps (what happens immediately)

1. **Archive the legacy code:** move `js/`, `scripts/`, `server.js`, `index.html`, `score.js`,
   `scored.json` to `legacy/` with a porting-notes README. Git history untouched.
2. **Scaffold the Godot project** in the repo root: project.godot, directory structure, the `Sim`
   autoload, the seeded RNG, a headless test runner, and a CI workflow.
3. **Port the content data** (`gamedata.js` → Godot Resources): clans, powers (as ActionDef seeds),
   enemy presets, loot tables. This is mechanical and high-value.
4. **Build the combat grammar + melee combo** as the first playable verb, with the scripted-expert
   vs masher benchmark as the gate.
5. **Stand up the slice scene** with authored art and real lighting, then iterate to the Phase 1 DoD.

Steps 1–3 are days. Step 4 is the first real design milestone and where "fun" either appears or
doesn't. Step 5 is the convergence.

---

## Success criteria (the revamp's, not just Phase 1's)

1. **10-hour floor:** a completionist run takes 10+ hours of genuinely varied play.
2. **Build identity:** Nosferatu and Brujah playthroughs require different strategies from minute one.
3. **The skill gap:** a skilled player is measurably, repeatably better than a masher — the disease
   is broken.
4. **Authored moments:** a finishing player names 3+ things that happened to *their* character.
5. **Discovery:** at least one "wait, I can do THAT?" moment per session — systemic interaction, not
   a hidden stat.
6. **The soul cost:** players say "I was at 8 Humanity when I started" as a sentence about their
   character.
7. **Professional look:** authored art + real lighting; no one calls it a flash game.
8. **Engineering rigor:** deterministic sim, real test suite, CI green, golden replays as artifacts.
