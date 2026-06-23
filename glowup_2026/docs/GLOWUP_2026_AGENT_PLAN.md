# Vampire City 2026 — Agent Implementation Plan

This plan translates the glow-up specification into conflict-aware work packages for the current Godot architecture. It extends, rather than replaces, `FIRST_HUNT_SLICE_PLAN.md`, `MASTER_PLAN.md`, and `AGENT_WORKSTREAM_PLAN.md`.

## Prime directive

No agent receives a feature-name task. Every task defines inputs, outputs, touched authority, deterministic invariants, tests, evidence, performance budget, and rollback switch.

Every PR handoff contains:

```text
Player-facing problem
Existing behavior preserved
Files changed
Authority boundaries touched
Semantic events added/consumed
Save implications
Tests and results
Windowed evidence
Performance before/after
Accessibility behavior
Remaining risk
Feature flag / rollback path
```

## Integration seam

Create one Sim-owned `HiddenGameState` inside `SimMeta` with:

```text
style_profile
rumor_graph
local_exposure
opportunity_history
pressure_causes
version
```

`Sim.emit_cue` remains the source of semantic facts. Add a direct deterministic observer call before presentation deferral:

```gdscript
if meta != null:
    meta.observe_hidden_game_event(event_id, payload, self)
```

The observer may mutate only Sim/SimMeta-owned data. It may not read the scene tree, wall-clock time, devices, audio, camera, or render state. Presentation continues through CueBus.

The reference scripts in this kit are algorithmic assets. Integrating agents should relocate or rename them only after tests prove equivalent behavior.

---

# WAVE 0 — Baseline and shadow mode

## NG-0001: Event vocabulary and trace

**Owner:** Technical director  
**Files:** `src/sim/Sim.gd`, `src/sim/SimMeta.gd`, new `src/sim/HiddenGameState.gd`, debug overlay, tests

Inputs:

- existing `emit_cue(event_id, payload)`,
- Sim tick,
- player identity/clan,
- district at event position.

Outputs:

- bounded semantic event record,
- deterministic event sequence ID,
- development trace ring buffer,
- no gameplay change.

Invariants:

- no `Time.*`, `randf`, `randi`, or scene lookup in authoritative code;
- duplicate sequence IDs are ignored;
- payload is copied and sanitized;
- trace capacity is fixed;
- state hash includes persistent hidden-game state, not the debug ring buffer.

DoD:

- replay of the same input tape produces identical hidden-game hash and trace IDs;
- 10,000 events do not grow memory unbounded;
- F3 debug page lists event, cause, method, identity, district, and magnitude;
- all existing tests stay green.

Rollback: `hidden_game_enabled = false` in SimMeta.

## NG-0002: Style inference in shadow mode

**Owner:** Systems engineer  
**Files:** reference `PlayerStyleProfile.gd` integrated under `src/sim/`, `SimMeta.gd`, debug overlay, test

Record only completed semantic resolutions:

- feed spare/kill/perfect gulp,
- combat connect/finisher/escape,
- power resolution,
- body conceal/disposal,
- heat escape,
- vehicle hijack/pursuit,
- mission/domain/coterie outcomes.

DoD:

- repeated button presses without outcomes contribute zero;
- scripted stealth and force traces diverge visibly;
- hybrid trace has higher normalized entropy;
- state survives save/load;
- no opportunity or enemy behavior changes yet.

## NG-0003: Rumor graph in shadow mode

**Owner:** AI/simulation engineer  
**Files:** reference `RumorGraph.gd`, `SimNPC.gd` witness adapter, `SimMeta.gd`, debug overlay, tests

Near-field witness generation uses existing LOS/exposure and explicit snapshot fields. The graph stores claims with confidence and identity ambiguity.

DoD:

- unseen act creates no eyewitness claim;
- cloaked/disguised act can create an event claim without true identity linkage;
- duplicate claims merge rather than multiply;
- confidence decays deterministically;
- faction summaries differ when witnesses belong to different factions;
- still no gameplay change.

**Wave 0 gate:** a complete First Hunt can be replayed and inspected as style, pressure, and uncertain city memory without changing existing outcomes.

---

# WAVE 1 — Finish the First Hunt’s remaining gameplay proof

## NG-1001: Resonance assignment and aura

**Owner:** Feeding designer + render engineer  
**Files:** `SimNPC.gd`, `SimPlayer.gd`, `EntityRenderer.gd`, `GameCatalog.gd`, HUD, included aura shader, tests

Data contract on feedable NPC:

```text
resonance_id
resonance_strength
resonance_revealed
resonance_source_seed
```

Assignment is deterministic from NPC type, district state, and Sim RNG at spawn. Auspex or close observation reveals it; the aura is never authoritative.

Buff contract:

- sanguine: recovery/flow,
- choleric: poise/force/frenzy control,
- melancholic: spell/cooldown/anomaly,
- phlegmatic: stealth/stability/exposure.

DoD:

- the player can identify resonance before grabbing under at least one accessible rule;
- each resonance measurably changes one slice-scale outcome;
- colorblind mode adds shape/frequency differences;
- same seed assigns the same victims;
- save/load preserves assignments and active buff.

## NG-1002: Runtime clan keystones for Brujah, Nosferatu, Tremere

**Owner:** Gameplay systems  
**Files:** `SimPlayer.gd`, `Sim.gd`, `SimMeta.gd`, HUD, tests

Brujah:

- explicit Blood Rage toggle;
- costs Vitae/Need over time;
- adds force/poise immunity;
- blocks or distorts selected disciplines;
- increases exposure/anomaly.

Nosferatu:

- unseen takedown/feed can preserve or extend cloak;
- witnessed or loud action breaks it;
- the rule is shown in HUD and cue stream.

Tremere:

- configured fraction of power cost may be paid from HP;
- health payment cannot kill below the safety floor unless an advanced node explicitly permits it;
- blood damage/refunds use one audited path.

DoD:

- the forced encounter has one clean distinct solution per clan;
- test captures prove different state trajectories on the same seed;
- keystones serialize;
- no generic stat-only fallback is counted as completion.

## NG-1003: Continuous dawn pressure

**Owner:** World/gameplay + UI + lighting  
**Files:** `SimMeta.gd`, `Sim.gd`, `LightingDirector.gd`, HUD, VisualFX, audio

Add a dawn phase value independent of presentation:

```text
night_progress 0..1
dawn_warning_band
dawn_exposure 0..1
sun_damage_accumulator
```

DoD:

- final 90 seconds visibly and audibly escalate;
- sunlight damages continuously outside haven/shadow once active;
- damage uses fixed-step accumulation and derived sun resistance;
- player can enter/exit shelter without double damage or stale state;
- a seeded run can end in torpor;
- reduced-flash path remains readable.

## NG-1004: Herald encounter and nemesis handoff

**Owner:** Encounter + narrative  
**Files:** authored world setup, SimMeta nemesis path, barks/captions, tests

DoD:

- the herald demonstrates search rather than psychic pursuit;
- encounter demands the clan rule at least once;
- herald flees when the escape predicate is met;
- damage type and method seed the scar/adaptation;
- blind tester can state that this opponent will remember them.

**Wave 1 gate:** First Hunt is mechanically complete and replayable across three clans.

---

# WAVE 2 — Contact quality and honest AI

## NG-2001: Input buffer and whiff/on-hit grammar

**Owner:** Feel engineer  
**Files:** `SimPlayer.gd`, `ActionState.gd`, ActionDef resources, tests

Add one bounded queued intent with expiry and priority. Distinguish on-hit and on-whiff recovery. Add dash-cancel windows through ActionDef data rather than hardcoded branches.

DoD:

- valid presses inside 3–6 frames are not dropped;
- mash cannot create infinite queue;
- expert-versus-masher gap remains or improves;
- replay stays deterministic.

## NG-2002: Unified impact packet

**Owner:** Combat + presentation  
**Files:** `Sim.gd`, CueBus payloads, CameraDirector, VisualFX, AudioDirector, EntityRenderer

One packet contains damage, poise, impulse, direction, crit, material/type, status, and presentation magnitude.

DoD:

- hitstop, camera, particles, audio, text, and rumble agree on severity;
- no double damage-number path;
- multi-hit effects respect concurrency caps;
- reduced-motion lowers shake without removing hit confirmation.

## NG-2003: Search diversity and uncertainty

**Owner:** AI engineer  
**Files:** `SimNPC.gd`, renderer/debug, property test

Seed-pick a search plan when LOS is lost:

- sweep LKP,
- contain exits,
- flank quadrant,
- check objective/body,
- delayed ambush,
- call allies/specialist when knowledge allows.

DoD:

- at least three materially distinct traces over 100 seeds;
- ≥95% of valid LOS breaks lose live player tracking;
- no branch reads current player position after loss unless a new observation occurs;
- plan and uncertainty are visible in debug;
- public cues remain diegetic.

**Wave 2 gate:** combat and pursuit are skillful, readable, and causally fair.

---

# WAVE 3 — Presentation convergence

## NG-3001: Pooled VFX pack

**Owner:** VFX engineer  
**Files:** new pool, VisualFX, EntityRenderer, shaders

Ship pooled:

- blood impact/splatter,
- dash trail,
- guard spark,
- feed stream/frame,
- sun ash/dissolve,
- resonance aura,
- search marker,
- and nemesis scar accent.

DoD:

- zero runtime allocation after pool warmup in the stress capture;
- effects have anticipation/contact/peak/decay/residue timing;
- no effect hides the next attack;
- low-effects preset preserves information.

## NG-3002: Dirty urban lighting/material pass

**Owner:** Technical art  
**Files:** WorldRenderer, LightingDirector, wet-asphalt shader, props, project render settings

DoD:

- wet roads respond to nearby light without becoming chrome;
- player, prey, exits, and attacks remain readable in the darkest slice route;
- at least three dynamic light functions are present: navigation, encounter, mood;
- slow camera pan shows no unacceptable temporal shimmer;
- GL Compatibility and Steam Deck profile stay within budget.

## NG-3003: Coordinated post grade

**Owner:** Technical art + accessibility  
**Files:** one grade director, included grade shader, VisualFX cleanup

Replace competing full-screen flashes with semantic parameters:

```text
heat
humanity_loss
frenzy
feed
sun_exposure
dawn_phase
reduced_flash
```

DoD:

- effects blend rather than overwrite;
- HUD remains unaffected or intentionally compensated;
- reduced-flash mode passes the same gameplay-readability checklist;
- no global contrast crush.

## NG-3004: Adaptive audio and information captions

**Owner:** Audio  
**Files:** AudioDirector, CueBus definitions, caption table, authored stems/SFX

DoD:

- exploration/combat/chase/dawn transition with hysteresis;
- offscreen hunter steps are reactable;
- AI stimulus severity agrees with the audible event;
- every information-bearing sound has a caption or sound-radar representation;
- dialogue/critical cues win mix priority.

**Wave 3 gate:** the slice passes Steam screenshot and in-motion capture review.

---

# WAVE 4 — Turn backend breadth into the campaign

This wave does not begin until blind players finish First Hunt and ask for another night.

## NG-4001: Opportunity director in shadow mode

**Owner:** Simulation + mission systems  
**Files:** integrated reference director, SimMeta, debug overlay, content loader, tests

DoD:

- all candidate scores and rejection reasons are inspectable;
- selection is deterministic from sorted candidates and caller RNG;
- adaptation budget cannot issue repeated hard counters;
- high pressure opens relevant relief jobs;
- no unavailable actor/location/resource can be selected.

## NG-4002: Convert three missions to objective graphs

Convert:

1. feeding/infiltration,
2. social/faction relationship,
3. pursuit/combat crisis.

Each gets multiple entries, three resolution methods, two phase transitions, three fail-forward outcomes, witness/evidence consequences, and district/faction outputs.

DoD: blind testers produce distinct coherent stories from the same template on different seeds.

## NG-4003: Lair hub and dawn recap

**Owner:** UI/meta/narrative  
**Files:** new Lair/Haven screen, real backend bindings, recap presenter

DoD:

- rooms expose services and rule changes, not passive clutter;
- recap names style, pressure, mercy, heat, debt, nemesis, and district change;
- every displayed value comes from SimMeta truth;
- existing `haven_bg` and portrait assets gain authored homes.

## NG-4004: District/faction agenda

**Owner:** World simulation + content  
**Files:** SimMeta agenda tick, district renderer states, event content

DoD:

- each faction acts for needs and resources;
- important changes have physical/audio/dialogue clues;
- domains create income, cover, jobs, upkeep, and raids;
- distant simulation uses aggregate state, not full actors.

**Wave 4 gate:** one full dusk→hunt→dawn→lair→next-night loop works.

---

# WAVE 5 — Replayability, legacy, and ship discipline

## NG-5001: Seed partitioning

Separate deterministic streams:

```text
world_init
faction_agenda
opportunity_selection
opportunity_slots
rumor_distortion
npc_decision:<id>
loot_reward
cosmetic_only
```

Cosmetic draws may never perturb authoritative streams.

## NG-5002: New Bloodline legacy

Carry one bounded boon, one relationship complication, one mythic rumor, and one altered district trait into a new character.

DoD: legacy changes context without trivializing early play or creating stat runaway.

## NG-5003: Save migration and soak

DoD:

- versioned hidden-game schema;
- active opportunity, claims above threshold, style, pressure causes, and stream state round-trip;
- corrupt/old data fails gracefully;
- eight-hour soak shows bounded event/claim/particle growth;
- deterministic reproduction includes seed, content version, tuning hash, and checkpoint.

## NG-5004: Product gate

Ship only when:

- five clean boots/runs,
- full controller and Steam Deck pass,
- minimum-spec worst-case scene meets target,
- all critical sounds captioned,
- no blocker/critical save defects,
- first-hour seams are polished,
- and two materially different clan/style playthroughs are captured.

---

# Required debug pages

The existing F3 overlay should gain pages for:

1. frame/alloc/particle/cue budgets,
2. movement, input buffer, action frame, cancel and hit windows,
3. perception, LKP, uncertainty, search plan and path,
4. style vector, entropy, dominant axis and recent contributions,
5. witness lines, claims, confidence, propagation and identity ambiguity,
6. pressure channels with source event and decay,
7. opportunity candidates, scores, cooldowns and rejections,
8. objective graph and fail-forward exits,
9. faction trust/fear/respect/awareness and active agenda,
10. save version, stream seeds and state hash.

Hidden state without a debug page is not production-ready.

# Agent stop conditions

Write an ADR before proceeding if:

- a feature requires a second authoritative event bus, save system, input abstraction, or RNG owner;
- more than three foundational autoloads must be modified;
- same-seed replay diverges;
- an ordinary content author must edit code to create an opportunity;
- a system polls the entire entity list every frame instead of consuming events/spatial queries;
- save size or claim count grows without a bound;
- a shader has no low-cost/reduced-effects path;
- or an adaptive enemy counter cannot be explained by in-world knowledge.

The game is allowed to be ambitious. The architecture is not allowed to become superstitious.