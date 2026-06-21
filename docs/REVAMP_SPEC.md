# Vampire City — Revamp Spec

> **Living document.** This is grown through three explicit iteration passes, each with a dated review
> at the bottom. Read top-to-bottom for the current state; read the review log at the end to see how it
> got here and why each addition earned its place.
>
> **Status:** Iteration 3 (final pre-implementation). Date: 2026-06-21.

---

## 0. Constitution (unchanging across iterations)

- **Engine:** Godot 4.3+ (GDScript), 2D top-down. Full port — the legacy `js/` code is archived, not
  migrated; we inherit its *design* (clans, powers, resonance, nemesis loop), not its code.
  Rationale: on "best results, however much work," Godot wins decisively. Its 2D renderer (Light2D +
  real shadows, GPUParticles2D, shaders, CanvasLayer compositing) is qualitatively a tier above
  hand-rolled WebGL — and for a vampire game whose whole atmosphere is darkness cut by pools of light,
  that *is* the look. It also ships the audio bus system, animation/art pipeline, input remapping,
  save slots, controller support, and native Steam export for free — i.e., five of the six missing
  backbones from `HANDOFF_QUALITY_BAR.md`. The earlier TS+PixiJS recommendation was rejected because
  it optimized for orchestration convenience (agents are JS-native) over game quality — which was
  precisely the laziness failure mode the project exists to avoid. Agents author Godot scenes
  (`.tscn`) and resources (`.tres`) directly as text; the GUI editor is not required for automation.
  A deterministic sim core (`Sim` autoload, plain classes, seeded RNG) runs headless via
  `godot --headless`.
- **Pillars:** Predator (skill-ceiling verbs), Rise (visible aspirational climb), Cost (every gain
  costs something diegetic), Continuous (the city simulates without you). Any feature serving none is cut.
- **The disease-denying metric:** a skilled player must measurably beat a masher on the same seed
  (faster clears, fewer hits taken, higher feed efficiency) *because the verbs reward mastery*. If the
  skill gap doesn't exist, the game failed even if it's polished.
- **Discipline:** every task ships against a checkable Definition of Done, not a feature name. The
  vertical slice ("The First Hunt") is the merge gate for Phase 1. Bulk-content agents fill schemas;
  they never invent contracts.

---

## 1. Reference-game innovation map

What actually impressed gamers about each reference, and what we inherit. The bolded items are
load-bearing for Vampire City.

### Diablo (1, 2, and the ARPG grammar D2 codified)
- **Loot as the progression engine.** Diablo II's genius was that *the loot IS the build*. A
  Necromancer with Homunculus and a Necro without are different characters. We inherit: relics with
  build-defining tradeoffs (Tier-2 idea #16 from the design audit), affix literacy as a long-horizon
  pursuit, and the color-rarity dopamine ladder. We **reject** Diablo's stat-stick inflation — our
  relics rewrite verbs, not numbers.
- **The skill tree as identity fork.** D2's synergy system (points in one skill buffing related ones)
  made builds feel *committed*. We inherit: clan keystones as mutually-exclusive rule changes (the
  committed fork). We reject skill-point bloat — 12-15 powers with combos beats 35 flat ones.
- **The cow level / secret density.** Diablo's reputation for secrets made exploration feel rewarded.
  We inherit: systemic discovery (predator combos, hidden resonance interactions, the "wait, I can do
  THAT?" moment per session).
- **Runewords.** The apex of "items that combine into something greater." We inherit this as the
  relic-set / weapon-evolution system (Vampire Survivors-style).
- **What we lack that Diablo had:** a loot-driven endgame loop worth playing for hundreds of hours.
  This is Phase 3, but the *foundation* (affix system, relic contracts) is Phase 1.

### Fallout 1 & 2 (the CRPG grammar)
- **SPECIAL + tagged skills = identity at chargen.** You defined your character *before* play, and the
  game respected it everywhere. We inherit: clan + background tags that surface bespoke dialogue and
  solutions only your character can use. A Nosferatu reads a different game than a Ventrue.
- **Multiple solutions to every quest.** Fallout let you talk, sneak, fight, or science your way
  through almost anything. We inherit: the Dishonored-style systemic verb set (Dominate, Obfuscate,
  Presence, blood-conducting surfaces) so every problem has 3+ solutions. **This is the biggest
  untapped design space in Vampire City.**
- **Karma/Reputation with real teeth.** Fallout's karma changed endings, companion availability, and
  random encounters. We inherit: Humanity-as-lived-state (Tier-1 #2) — not a counter, a world response.
- **Companions with personality and a cost.** Fallout companions could mutiny or die. We inherit: the
  Embrace system (Tier-2 #18) — named, leveling coterie with vitae upkeep and the emotional weight of
  siring.
- **What we lack that Fallout had:** real authored reactivity to *who you are*, not just what you do.
  This is expensive (dialogue/quest branching) and is Phase 2-3, but the *tag system* is Phase 1.

### GTA (1, 2, and the top-down grammar that's our direct ancestor)
- **The wanted system as emergent drama.** GTA's stars created player-authored chase stories. We
  inherit: last-known-position heat (Tier-1 #6) with the 6-second provoke window — the "duck down an
  alley, lose them" loop. **Already the best idea in the legacy masquerade.js; keep and deepen it.**
- **The city that doesn't wait.** Gangs fight each other; the world has its own politics. We inherit:
  gang-vs-gang territory AI (Tier-3 #20), but *only if surfaced* — background sim the player can't see
  is wasted dev.
- **Radio as atmosphere multiplier.** Near-free, huge mood. We inherit: 4 procedural stations (Phase 2).
- **Cars as verbs, not just transport.** Top-down GTA made driving a skill. We inherit: vehicles as a
  real traversal/combat verb (the legacy already has this), tuned for feel.
- **Aspirational locked locations.** The map showing "? Prince's Tower — Ventrue" from night one
  (Tier-1 #7). Cheapest high-ROI idea in the plan.
- **What we lack that GTA had:** a *living* city rhythm. Currently the city is a static backdrop. The
  day/night cycle, faction ticks, and terror/prosperity reactivity must make the city *pulse*.

### Vampire: The Masquerade — Bloodlines (the thematic north star)
- **Other vampires are the real threat.** Vampire City has zero rival vampires — a gaping hole. We
  inherit: rival mirror fights (Tier-1 #8) as the defining late-game enemy.
- **Clan as total identity.** A Nosferatu run is a different game. We inherit: rule-changing
  keystones (Tier-1 #1) + clan bane/boon mirrors (Tier-2 #15).
- **The Masquerade as a mechanical system.** Breaking it summons hunters; it's not flavor. We inherit:
  the full heat/witness system as a *core verb*, not a sidebar.
- **Social paths can resolve major beats.** The talker build is legitimate. We inherit (Phase 2):
  dice-roll dialogue checks and social-boss duels for key story moments.
- **What we lack that Bloodlines had:** authored narrative reactivity. This is the hardest gap and the
  most expensive to close; we scope it as authored *moments* (5 standalone missions) rather than a full
  dialogue tree system.

### The synthesis (one sentence, sharpened across iterations)
Vampire City is **Diablo's loot-and-build depth, Fallout's character-as-identity and multi-solution
quests, GTA's living city and emergent wanted-system chases, and VtM:Bloodlines's clan-as-identity and
Masquerade-as-mechanic — expressed as a 2D top-down vampire action-RPG with authored art, real
lighting, and a skill-ceiling combat grammar.** Every system below serves one clause of that sentence.

---

## 2. Core systems (the Phase 1 must-haves, each with a DoD)

These are the systems the vertical slice requires. Each ships with a checkable Definition of Done.

### 2.1 The deterministic sim core (`Sim`)
Plain GDScript classes (not Nodes) holding all gameplay state, owned by a `Sim` autoload singleton.
A single seeded RNG (`RandomNumberGenerator` with explicit seed) injected everywhere; **zero**
`randf()`/`randi()`/`Time.get_ticks` in authoritative code (lint/grep-enforced). `Sim.tick(delta)`
advances the world; `Sim.apply_input(action)` mutates it. The scene tree is a *view* that reads sim
state and renders — it never mutates it.
- **DoD:** `godot --headless --script res://test/run_replay.gd --seed 42 --ticks 3600` produces a
  hash; 20 runs identical. A recorded input sequence replays tick-stably. Zero RNG leakage flagged by
  a pre-commit grep.

### 2.2 The combat grammar (`ActionDef`)
The disease fix. Every player and AI action is frame data:
```
startup / active / recovery / cancelInto[] / cost / cooldown /
hitbox (authored Shape) / hurtbox / knockback / hitstop / sound / vfx cue
```
- The melee combo is a real cancel sequence: `light (startup 3, active 3, recovery 8, cancels into
  light/heavy/dash) → light → heavy (startup 6, active 4, recovery 18)`. A masher eats the 18f
  recovery; a skilled player cancels. **This is the skill ceiling.**
- Each power gets a distinct input grammar: Bolt = aim+release (lead target); Slam = hold-to-charge
  radius, commit stationary; Dash = directional double-tap i-frames (the Hades dash); Mesmerize =
  cone-aim + brief channel; Heal = hold-to-channel, immobile (vulnerable).
- Predator combos are real cancel sequences: Mark during Bolt recovery → Detonate at reduced cost.
- **DoD:** scripted `dash→mark→detonate` = exact tick trace. A scripted-expert benchmark beats a
  random-masher benchmark by ≥30% clear speed and ≥50% fewer hits on the same seed.

### 2.3 Perception-based stealth + hunter AI
State machine: `UNAWARE → SUSPICIOUS → INVESTIGATING → SEARCHING → REACQUIRING → COMBAT/(lose)`.
Hunters hold a *last-known-position with uncertainty* (spreading search cone), investigate sighting
sites, lose you after disengaging, can be deceived by Obfuscate (reduces sighting range, erases trail).
Feeding in a witness's LOS creates a sighting; sightings escalate heat. Running in light increases
sighting range; crouching in shadow reduces it.
- **DoD:** across 100 seeded runs, a hunter that saw you feed exhibits ≥3 materially different search
  behaviors (direct pursuit / flank / give-up-and-ambush / call allies). A property test verifies no
  run produces "hunter instantly knows your live position."

### 2.4 Feeding as the core verb (resonance + kill-is-a-choice + load-bearing Gulp)
- **Resonance** (Tier-1 #3): victims carry a humour (choleric/sanguine/melancholic/phlegmatic +
  dyscrasia from hunters), visible via an Auspex aura read or subtle tint *before* you commit. Who
  you feed on is a build decision.
- **Kill is a choice** (Tier-1 #4): a normal feed leaves the victim unconscious (a body that
  witnesses can find → heat); only a held feed or execution kills. Spare = silent +Humanity; kill =
  cost Humanity but a cleaner board.
- **Load-bearing Gulp**: the heartbeat mini-game now matters. Hit the window → bonus vitae + brief
  slowmo; miss → the feed *slows* (longer exposure = more heat risk) and yields less. No longer
  decorative.
- **DoD:** a feeding encounter where the resonance choice, the Gulp skill, and the kill/spare
  decision each measurably change the outcome (vitae gained, heat generated, humanity moved, body left).

### 2.5 Humanity as lived state (Tier-1 #2)
- Tiers 7-10: mortals don't panic near you; dawn survivable 2s longer.
- Tiers 5-6: baseline.
- Tiers 3-4: pedestrians flinch and scream at proximity; police aggro range +20%; player sprite has
  deeper shadow.
- Tiers 1-2: feeding on innocents never fully satisfies; random frenzy risk during heat events.
- Tier 0: Wassail — permanent frenzy, input noise, bleeding screen. The playable bad ending.
- Every step down fires *one* authored banner line (never repeated, never stacked). The mechanical
  gates are felt in traversal/combat, not edge-case menus.
- **DoD:** a Humanity drop visibly changes pedestrian behavior and screen state on the same screen as
  the drop, within 1 second. Not a menu number.

### 2.6 The heat/Masquerade system (Tier-1 #6, deepened)
- Last-known-position responder spawning (not psychic tracking). 6-second provoke window: heat freezes
  while seen, barely cools while searched, bleeds fast once disengaged.
- Star tiers: 1★ = 1 responder; 2★ = 3; 3★ = SWAT; 4★ = Inquisition (stakes, UV). Stars clear =
  responders physically disperse and wander off.
- Only the player's witnessed crimes raise the player's heat; NPC crossfire is ambient.
- **DoD:** a property test: after breaking LOS and not provoking for 8s, responders have left the
  player's awareness radius in ≥95% of seeded runs.

### 2.7 The presentation orchestration (`CueBus`)
A semantic event bus: `feed.start`, `humanity.lost`, `masquerade.broken`, `hunter.alarmed`,
`kill.elite`, `combo.landed`. Each maps to ONE coordinated cue (camera + audio + VFX + HUD) with
priority, concurrency limits, and accessibility transforms (reduced-motion flattens shake/flash).
Stops effects being independent noise.
- **DoD:** triggering `kill.elite` produces exactly one camera move + one audio sting + one VFX
  burst + one HUD flash, coordinated, regardless of how many systems fired. No cue storm.

### 2.8 Authored art + real lighting
- **Art source:** AI-generated sprites via grok/agy/codex image-gen (user-confirmed available), then
  post-processed (transparent backgrounds, atlas-packed, palette-normalized) into Godot `SpriteFrames`.
  Curated into a cohesive look; never accepted as-is — every asset gets a consistency pass against the
  style guide (limited gothic palette: deep blues/purples, blood reds, candle golds, cold moonlight
  whites; ~48-64px characters; distinct silhouettes per faction/clan).
- **Authored frames** for idle/walk/attack/feed/death per character class. Procedural generation
  permitted ONLY for things that should vary (loot affix glows, graffiti, blood splatter, particle
  textures). **No procedural primitives for hero assets** — the legacy's `spriter.js` Canvas shapes are
  the #1 "looks like a flash game" cause and are not carried forward.
- **Lighting as atmosphere (Godot Light2D + shadows):** streetlamps, headlights, muzzle flashes, the
  feeding vignette, moonlight through alleys — all real light sources casting real shadows. Pools of
  light cut by darkness. This single system is the look upgrade. Godot's 2D lighting is qualitatively
  beyond hand-rolled WebGL and is a primary reason for the engine choice.
- **DoD:** zero Canvas-primitive hero sprites in the slice. Every scene has ≥3 dynamic light sources.
  A dark scene reads as "moody" not "broken monitor." Every hero sprite is atlas-packed with authored
  animation frames.

---

## 3. Content systems (Phase 1 foundation, Phase 2 expansion)

### 3.1 Clans (7, each a real identity fork)
Each clan: a **rule-changing keystone** (mutually exclusive), a **boon**, and a **mirrored bane**:
| Clan | Keystone (rule change) | Boon | Bane |
|---|---|---|---|
| Brujah | Blood Rage: frenzy is an opt-in toggle (+40% dmg, CC-immune, no disciplines) | +15% melee | -15% frenzy resist |
| Nosferatu | One With Shadow: stealth kills don't break cloak for 2s, chain indefinitely | Stealth specialist | -12% prices/social |
| Tremere | Vitae Alchemy: half of each power's blood cost comes from HP | +18% spell power | -10% HP |
| Ventrue | Iron Will: dominated thralls permanent (up to Influence÷5) | Social/income | Can only feed on "refined" blood |
| Toreador | Perfect Predator: sparing a target resets ALL cooldowns | +crit/dodge | Penalties when "unmoved" (no feed recently) |
| Gangrel | The Wild Hunt: moving without stopping builds Hunt Stacks (+dmg/speed) | +survivability | Frenzy risk in civilized areas |
| Malkavian | The Voices Know: 20% chance on cast for a free random second power | +insight/auspex | Input/sanity noise |
- **DoD (Phase 1):** at least 3 clans fully playable in the slice, each requiring a *visibly different*
  approach to the same encounter (not just different numbers).

### 3.2 Powers (~12-15 in Phase 1, each a distinct input grammar)
Port the best from `gamedata.js`, re-expressed as `ActionDef`. Each gets a unique input shape. Plus
the genuinely missing verbs:
- **Predator Sense / Dead-Eye** (NEW): a meter that slows time so you paint targets/body parts, then
  unleash a choreographed flurry. The player-activated time-slow the user asked for.
- **Ranged weapon system** (NEW): firearms/crossbows with reload, recoil, ammo types (hollowpoint,
  incendiary, UV rounds for vampires). The VtM setting has these; the game doesn't.
- **Heal line**: Mend Flesh (channel, self), and an AoE ally heal for coterie play.
- **DoD:** every power has ≥1 enemy that demands it and ≥1 enemy that counters it. No two powers
  share an input grammar.

### 3.3 Enemies (~8 in Phase 1, each with a forced counter)
| Enemy | Counter verb |
|---|---|
| Shield riot cop | Flank or dash behind (front-armor) |
| Warded inquisitor | Out-damage or maneuver into environmental hazard (immune to fear/CC) |
| Blood-mage rival | Interrupt during channel |
| Frenzied ghoul | Kite or root-lock (ignores stagger) |
| Sniper spotter | Silence first (calls allies; priority target) |
| Swarmer | AoE / crowd control |
| Bruiser | Dodge-then-punish recovery windows |
| Rival vampire (mirror) | Fight against your own optimal combo (Wards your damage type) |
- **DoD:** no two enemies share an optimal counter. The 8 create 8 distinct micro-puzzles.

### 3.4 The economy (collapsed currencies — kill the bloat)
**Three currencies only:** Vitae (blood, the resource), Coin (money), and Legend (one meta-progression
currency). Delete the legacy's influence/elder-vitae/reagents/terror-as-currency sprawl. Terror and
prosperity remain as *district state*, not spendable currency.
- One compounding income chain (Phase 2): businesses-as-fronts → district claims → lair → dominion.
  Cut the parallel automations. Upkeep (bribes, vitae wages) is the part that keeps money meaningful.

### 3.5 The nemesis loop (Tier-1 #5)
Hunters you nearly kill may flee → become named persistent foes → return with resist to your scarred
damage type → escalate rank. First nemesis guaranteed early (the herald always flees). Returns
telegraphed (a watcher NPC spawns and vanishes first). Cap at 2-3 active.
- **DoD:** a nemesis that returns visibly scarred by the damage type you used, with a telegraph, and
  measurably harder to kill with that same type.

---

## 4. The vertical slice: "The First Hunt" (the merge gate)

A 12-18 minute clan-initiation night. The sire's rival wants you dead before dawn. The night forces:
feed (resonance + Gulp + kill/spare) → fight (an enemy demanding a specific counter) → use your clan
keystone (mechanically necessary) → trigger a Humanity loss that changes the world → be hunted by
something that searches → end on a nemesis-tease hook.
- **Success metric:** skilled player beats masher by the §2.2 margins on the same seed.
- **DoD:** the full Phase 1 DoD checklist (§6) passes.

---

## 5. Phase plan (gated, anti-bloat)

- **Phase 1 — Foundations + Slice.** §2.1-2.8, §3.1-3.5 (3 clans, ~12 powers, ~8 enemies), §4.
  Nothing else. This is "the game is fun."
- **Phase 2 — Deepen + the living city.** Remaining 4 clans, full power roster, flywheel economy
  (one chain), the Lair as place (4-5 rooms), gang territory AI (surfaced), rival vampires radiant,
  the 5 authored missions, radio, difficulty modes.
- **Phase 3 — Endgame + loot endgame.** Lord of the Night state, The Final Siege, New Bloodline,
  the loot/affix endgame (Diablo-style greater-rift ladder), codex/bestiary, Steam polish.

---

## 6. Phase 1 Definition of Done (the merge gate — paste to every agent)

- [ ] Deterministic: 20 headless runs, same seed = identical hash. Zero RNG leakage (lint-enforced).
- [ ] Skill gap: scripted-expert beats masher by ≥30% clear speed, ≥50% fewer hits, same seed.
- [ ] AI diversity: hunter search behaviors pass the property test (≥3 materially different).
- [ ] Every player action has frame data and a <100ms feedback cue.
- [ ] Hitstop on every connection, not just crits/kills.
- [ ] Authored art for every hero asset in the slice; zero procedural primitives.
- [ ] Real lighting in every scene (≥3 dynamic sources).
- [ ] 5 consecutive clean runs: zero console errors, zero crashes.
- [ ] A blind playtester names the hook after 30s.
- [ ] Humanity loss visibly changes the world within 1s, not a banner.
- [ ] CI green: lint + typecheck + unit + headless-replay + Playwright smoke, on every push.

---

## 7. Orchestration model (how I drive the agents without burning my limit)

This is the meta-plan for execution. **I (ZCode) own: planning, spec, contracts (schemas, DoDs),
review, integration, and taste.** Agents own: bulk implementation against contracts, backend systems,
content fills.

- **codex** (`codex exec`, non-interactive): backend/systems code. The deterministic sim core, the
  combat grammar engine, schema validators, the headless test runner. This is its strength. *Note:
  config currently broken (`service_tier` parse error) — fix before first dispatch.*
- **grok** (`grok --print` or worktree sessions): the most capable harness. Use for the hard
  integrations and `--best-of-n` on ambiguous design implementations. Subagents for parallel
  fan-out (e.g., "port these 7 clans in parallel").
- **agy** (`agy --print`): secondary non-interactive runner. Use for content fills into validated
  schemas (power data, enemy data, lore entries, clan feed-sound params).
- **ZCode (me):** I write the contracts (ActionDef schema, Sim interface, CueBus spec), review every
  agent PR against the DoD, integrate, and make all taste calls. I do NOT burn my context on bulk
  code generation that codex can do offline.

**Anti-loop guardrail:** no agent gets a feature-name task. Every dispatch includes the relevant DoD
checkboxes and the slice metric it must move. Bulk-content agents get a schema + validator first
(guardrail #10); they never invent contracts.

---

## 8. First concrete steps (immediately after spec approval)

1. Fix `codex` config (`service_tier` error) so it's usable.
2. Archive legacy: `js/ scripts/ server.js index.html score.js scored.json` → `legacy/` with a
   porting README. Git history untouched.
3. Scaffold the TS+Pixi+Vite project (`package.json`, `tsconfig`, `vite.config`, `src/sim/`,
   `src/render/`, `src/data/`, `src/test/`, CI workflow). **Dispatch to codex** (backend scaffold
   is its strength).
4. Port content data `gamedata.js` → TS Resources/JSON (mechanical, high-value). **Dispatch to agy.**
5. I write the `Sim` interface + `ActionDef` schema contracts. **codex implements Sim; I review.**
6. Build the melee combo + dash as the first playable verbs with the skill-gap benchmark. **This is
   the first "is it fun" milestone.** I drive this directly — it's the taste-critical work.

---

## REVIEW LOG

### Review 1 (post-first-draft)
*Grew from a feature list into a contract-driven spec. Added: the disease-denying metric as the
central gate; the explicit reference-game map with what each taught; the collapsed-currencies
decision (killed the sprawl); the DoD per system. Identified the biggest untapped space: systemic
multi-solution verbs (Fallout/Dishonored). Flagged: image-gen tooling unresolved.*

### Review 2 (post-second-draft)
*Sharpened the combat grammar into the literal disease fix (frame data + cancels = skill ceiling).
Added the genuinely missing verbs (Predator Sense, ranged weapons, heal line) per user feedback.
Added the 7-clan table with bane/boon mirrors. Added the enemy-counter table (8 enemies, 8 counters).
Cut: achievement sprawl, idle job board, parallel automations, 35-power bloat. Tightened the slice
DoD to be checkable, not vibes. Open question remains: authored-art source.*

### Review 3 (post-third-draft — the "no laziness" pass)
*Hostile re-read found six real gaps where "best" had silently become "easy." Each is now a system:*
*1. **Audio** was one line — for a game whose references (Hotline Miami's sound design, GTA radio,
   VtM's ambient dread) are defined by audio, that's inexcusable. Added §9 (Audio Architecture).*
*2. **The dawn** was mentioned in the slice but had no system. A vampire game with no dawn pressure
   is missing its core tension — the legacy's toothless spreadsheet-dawn is the disease. Added §10
   (The Day/Night/Dawn system).*
*3. **Traversal & level design** was entirely absent. Top-down GTA lives on verticality and
   multi-route levels; a flat ground plane is why the legacy feels like a flash game. Added §11.*
*4. **Environmental interaction** was promised (Dishonored/Fallout multi-solution) but had no
   systemic substrate — no surfaces, no rules. Added §12 (the systemic world).*
*5. **Accessibility** was one buried line. For a "professional" spec that's a failure. Added §13.*
*6. **No performance budget.** "Best results" needs numbers, not vibes. Added §14.*
*7. Tightened: the systemic-surface rules make the 8 enemy counters *emergent* (a warded inquisitor
   shoved into fire dies regardless of who shoved), not scripted — this is the Fallout/Dishonored
   payoff and it's the difference between a good game and a great one.*

---

## 9. Audio architecture (the atmosphere half of "professional")

A vampire game is half audio. The legacy has procedural WebAudio; we rebuild it as a real system.

- **Adaptive music stems + transition matrix** (Hades / Doom 2016 model). Exploration stem → combat
  stem → chase stem → dawn stem, cross-faded by a tension value the `CueBus` drives. No hard cuts.
  Transitions land on bar boundaries. A 6-note descending "hunting call" leitmotif weaves through all
  stems, swells on mission-complete/level-up, stings on kill.
- **3D positional + HRTF audio.** For a top-down *predator* game, *hearing* a victim's heartbeat or a
  hunter's bootstep off-screen is enormous. WebAudio PannerNode + HRTF. A civilian you can't see but
  can hear (heartbeat thickening as hunger rises) is core fantasy.
- **Occlusion/reverb zones.** Inside (haven, club, crypt) = reverb tail; outside (street) = dry.
  ConvolverNode with authored impulse responses per zone type.
- **Procedural + sampled hybrid.** Continuous systems (the feeding heartbeat, clan-distinct feed
  sounds — savage tearing for Brujah, dry crunch for Nosferatu, chemical hiss for Tremere) are
  procedural. One-shots (gunshots, impacts, stings) are sampled for punch. Procedural where it should
  vary; sampled where it should hit.
- **Mix snapshots + priority buses + ducking.** Master / Music / SFX / Voice / Ambient buses. A
  `feed.start` cue ducks music −6dB and foregrounds the heartbeat. A `masquerade.broken` cue ducks
  everything for the alarm sting. Priority preemption: a kill sting ducks a footstep, never vice versa.
- **Radio (Phase 2):** 4 procedurally-synthesized stations (dark synth / industrial / jazz / static),
  distinct synthesis parameters per station, heard only in vehicles. Press R to cycle.
- **DoD:** every `CueBus` event has a dedicated audio cue with correct bus routing and ducking. A
  feed in a reverberant alley sounds materially different from a feed on an open street. Hearing a
  hunter approach from off-screen is reliable enough to react to.

## 10. The day/night/dawn system (the core vampire tension)

The legacy's dawn was a spreadsheet recap. We make it the central dramatic pressure of every night.

- **The night is the playground; the dawn is the deadline.** A real-time clock (e.g., dusk 21:00 →
  dawn 05:00 ≈ 12-16 real minutes, tunable per difficulty). The sky lerps through a full gradient.
  Lighting intensifies from deep night → pre-dawn blue → killing gold.
- **Sun damage is lethal and escalating.** Once the sun rises, exposure deals escalating damage that
  ignores armor; shaded areas (under awnings, in alleys, indoors) are safe. The last 60 seconds of a
  night are a desperate scramble to reach a haven — *this is the arc the legacy was missing.*
- **Dawn preparation is a verb.** You must physically reach a haven (or a claimed safehouse, or
  Obfuscate into a sewer) before sunrise. Failing = torpor (death → respawn at last haven with a
  Humanity/permanent cost per difficulty). This makes *where you end the night* a real decision.
- **Haven-as-safety is earned.** Your lair is the one guaranteed dawn-safe zone. Losing it (raided,
  burned — see the Phase 3 Final Siege) is catastrophic. This is the mechanical weight behind "the
  lair as a place."
- **The dawn recap matters.** The recap screen now shows: night duration, hunts, feeds, kills,
  spares, heat survived, Humanity delta, and an authored epitaph line. It's a *moment*, not a menu.
- **DoD:** ≥90% of blind playtesters report feeling dawn pressure by night 2. A night that ends in
  torpor because you pushed one feed too far is a feature, not a bug.

## 11. Traversal & level design (why top-down GTA feels alive)

A flat ground plane is why the legacy feels like a flash game. Verticality and routes fix it.

- **Verticality:** rooftops (reachable by Gangrel wall-crawl, Celerity blink-up, or fire-escape
  props), alleys (the stealth channel), sewers (the Obfuscate highway + dawn escape route), and
  interiors (clubs, havens, crypts — loadable zones or seamless). *Predator positioning* happens in 3D.
- **Multi-route level design (Fallout/Dishonored):** every objective has ≥3 paths. A guarded
  building: front door (fight/social), roof (climb → drop), sewer (stealth), or Dominate the guard.
  The world respects your build. Authoring-intensive but the immersive-sim payoff is the whole point.
- **The city is legible and navigable:** landmarks visible from anywhere (the cathedral spire, the
  Prince's tower, the neon of the club district) for orientation. Fog-of-war reveal + discovered
  havens as fast-travel nodes (the "mist-travel between lairs" fantasy).
- **Handcrafted, not procedural.** The slice is one hand-built block. Phase 2 adds districts, each
  with a distinct architectural identity (gothic old quarter, neon downtown, industrial docks,
  cemetery district). No procedural city generation — that's how you get generic.
- **DoD:** the slice's objective is solvable by ≥3 materially different routes, each leveraging a
  different verb set. A Nosferatu (sewer + stealth) and a Ventrue (front door + Dominate) reach it
  different ways and have different experiences.

## 12. The systemic world (the Dishonored/Fallout payoff)

This is the single most important *non-combat* system. It's what makes the 8 enemy counters
*emergent* rather than scripted, and it's the "wait, I can do THAT?" engine.

- **Authored surface types with consistent rules:**
  - **Blood pools** (from kills/feeds): conduct a "Blood Lash" — chain lightning through anyone
    standing in blood. Fire spreads across blood. Vampires (including rivals) can drink from pools.
  - **Fire** (molotovs, candles, pyres): spreads along flammable surfaces (oil, paper, blood),
    ignites enemies, blocks paths. Vampires take aggravated damage. A warded inquisitor shoved into
    a fire dies — *regardless of who shoved him.* Emergent counter.
  - **Water** (puddles, rain): conducts shock (a Shock power + water = AoE stun). Breaks line of
    fire. Blood in water spreads downstream.
  - **Sunlight patches** (dawn, broken skylights, UV lamps): lethal patches you can *lure enemies
    into*. A rival vampire chased into a sunbeam dusts. The ultimate environmental kill.
  - **Electricity** (broken panels, junction boxes): shocks anyone in nearby water; can be
    shorted by blood. Power doors/locks.
- **The AI obeys the same rules.** Hunters avoid fire and sun; ghouls don't; rivals fear sun but not
  fire as much. This is what makes creativity beat raw stats — the *world* is a weapon.
- **Status interaction (Diablo-adjacent):** burn boils poison (AoE poison-cloud detonation); shock
  spreads in water; bleed pools conduct. Two-status combos produce emergent effects. Capped at ~6
  strong interactions to keep it legible.
- **DoD:** a property test — across 100 seeded runs, players (scripted policies) solve the warded-
  inquisitor encounter by ≥3 different means (out-damage / shove-into-fire / lure-into-sun), all
  *systemic* (no scripted "if inquisitor near fire, die" trigger). The rules produce the outcome.

## 13. Accessibility (architecture, not a checklist)

- **Full input remapping** with presets (lefty, one-hand, gamepad). Stored per-save.
- **Gamepad support** (XInput/DInput) as a first-class input, not an afterthought.
- **Colorblind-safe palettes:** status effects distinguished by *shape + icon + color*, never color
  alone. A colorblind mode retints the palette.
- **Text scaling** (UI 75%-150%) without layout breakage. High-contrast text mode.
- **Reduced-motion mode:** flattens screen shake, hitstop (becomes brief flash), and eliminates
  flashing/strobing VFX. Respected by every `CueBus` cue.
- **Captions** for every meaningful audio cue (footstep direction, heartbeat, stings) — Dead
  Space-style, since positional audio is core and deaf players must not lose the information.
- **Hold-vs-toggle** options for every continuous action (feed, sprint, cloak).
- **Difficulty as accessibility:** the easy mode ("The Masquerade") is a real first-class mode, not
  "the baby mode." Dawn windows wider, Humanity loss halved, no permanent death cost.
- **DoD:** the slice is completable with reduced-motion + captions + gamepad + remapped inputs, with
  no information lost versus the default. An accessibility audit passes.

## 14. Performance budget (numbers, not vibes)

- **Target:** 60 FPS on a 2020 mid-range laptop (integrated GPU) at 1080p; 144 FPS on a gaming desktop.
- **Frame budget:** 16.6ms @ 60 FPS. Sim ≤ 4ms, render ≤ 8ms, GC ≤ 1ms, headroom ≥ 3ms.
- **Entity budget:** 200 active NPCs + 500 props + 50 active VFX without dropping a frame. Spatial
  partitioning (uniform grid) for queries; brute-force O(n²) is forbidden past 100 entities.
- **Allocation discipline:** zero per-frame allocations in hot loops (no `new` in `Sim.tick`). Object
  pools for projectiles, VFX, damage numbers. GC pauses profiled and eliminated.
- **Asset budget:** initial load < 3s (lazy-load districts). Texture atlas ≤ 4096²; batched draws.
  Total client payload < 50MB for the slice.
- **DoD:** a CI performance gate runs the slice headless + a frame-time benchmark; merges that miss
  the frame budget by >10% are blocked. Profiling artifacts attached to every Phase 1 PR.

---

*End of spec, iteration 3. Ready for implementation on approval of the three open decisions
(§0 engine confirmed TS+Pixi; art source TBD §2.8; legacy archival approved §8.2).*
