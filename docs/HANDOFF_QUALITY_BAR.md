# Vampire City — Quality Bar & Rigor Handoff

> **Read this BEFORE reading `.claude/plans/improvement-plan.md`.** That plan is a good *feature* list;
> this document is the *quality discipline* that turns a feature list into a professional game. Without
> this, the feature list reproduces the same failure mode that nearly killed a sibling project.

**Audience:** the engineering agent(s) — resident and any structural "genius" contractors — working on
Vampire City. You are assumed competent at writing code. This document is about *what to build, in what
order, to what standard, and what traps to refuse to fall into.*

---

## 0. The meta-lesson (read this first — it is the whole point)

A sibling game project (a JS/Three.js space sim) was built almost entirely by AI agents across many
iterations. It ended up with 13 ships, 10 mission types, 8 factions, a real economy, a save system,
adaptive audio, pooled VFX — **all of it functional, none of it good.** The creator's verdict: *"boring,
confusing, ugly."* This is not a quality problem with any single feature. It is a **process disease**
with a name.

### The disease: the feature factory / local-minimum trap

Every agent turn asks *"what's a useful next thing I can do?"* and does it. Individually each step is
reasonable. Stitched together, you get a game that is **wide but shallow** — every system exists at
~60%, nothing is finished, nothing is great. AI agents optimize for *"does it function?"* (a local
minimum), never *"would a real studio ship this?"* (the global one). The word **"professional"** does
not break the loop, because agents have no checkable definition of professional — only a vibe, and
vibes default to *functional*.

**The four symptoms this produces, all of which you can already see in Vampire City:**

1. **Movement/feel has no authority.** (Here: combat is stat-tick resolution, not weighty/physical.
   Compare Hotline Miami / Hades — every hit *lands*.)
2. **Art has no ingress path.** (Here: everything is Canvas 2D primitives + procedural sprites. There
   is no way for authored pixel art or vector art to enter the game.)
3. **Content is presented, not embodied.** (Here: the Masquerade / Humanity / clan fiction is data
   fields and banners, not mechanics that *enact* the fiction.)
4. **"Done" has no evidence bundle.** (Here: the QA scripts smoke-test that it runs, not that any
   moment is *good*. Nothing is gated on a quality bar.)

The cure is **not a better prompt.** The cure is three structures:

1. **A Definition of Done** — a literal, per-asset-type checklist an agent can fail.
2. **An iteration loop** — a way for agents to *see and measure* their own output (headless run +
   captured frame + telemetry) instead of waiting for the human to say "still bad."
3. **Vertical-slice discipline** — a hard rule that nothing new gets touched until one complete slice
   is at 100%.

These three structures are the real backbone. Everything below is built to serve them.

---

## 1. The professional top-down action-RPG menu

This is the ceiling — the techniques the reference games (VtM: Bloodlines, GTA 1/2, Hotline Miami,
Hades) actually employ. A professional production *chooses from this menu in service of a coherent
game*; it does not accumulate every technique. **For Vampire City, the bolded items are the
load-bearing ones.**

### Architecture
- **Fixed-timestep sim with interpolation** — Vampire City HAS this (`loop.js`). Good. Do not break it.
- **Deterministic, headless-runable sim core** — MISSING. Combat/economy/AI should run in Node with
  no DOM/Canvas, seeded, byte-stable. This is what lets you write *real* tests instead of Playwright
  smoke checks. **Load-bearing.**
- **Data/content separation + schema validation** — PARTIAL. `gamedata.js` is data, but it's a free-form
  JS object with no validator. A typo in a power cost silently ships. **Load-bearing.**
- **Sim/render decoupling** — PARTIAL. Systems mutate `window.VAMP` globals freely; rendering reads
  live state. Save already strips non-plain data, which is the tell that the boundary is leaky.
- Scene graph / spatial partitioning beyond brute-force entity scan — likely MISSING for a top-down
  game with many entities. Quadtree or grid for query/cull.

### Rendering & art
- **Authored art ingress** — MISSING. Everything is `spriter.js` Canvas primitives. There is no sprite-
  sheet/atlas loader, no authored-frame animation pipeline. **The #1 "looks cheap" cause after feel.**
- **Sprite atlas + batched draw** — for any authored pixel art; one texture, thousands of draws.
- **Dynamic lighting that reads** — `lightworker.js` exists; verify it produces *spatial* light
  (vampire game = darkness + pools of light = atmosphere). Hotline Miami's identity is its lighting.
- Post-FX stack (bloom/vignette/grade/grain/scanline) — `postfx.js` exists; verify it's a *directed*
  stack with a per-scene grade, not a pile of filters.
- Hit-flash / chromatic aberration / impact frames — `powervfx.js` exists; verify they're *choreographed
  to semantic events*, not generic.
- Screen shake / hitstop / time-scale — verify they form a *priority system*, not independent effects.

### Game feel / juice (the single biggest "is it fun" lever — cheapest to fix)
- **Input buffering + coyote/grace windows** — does a dash/feed/ability press slightly early still
  register? It must.
- **Anticipation / active / recovery frames** on every action (Hotline Miami melee, Hades attack).
- **Hitstop on every connection** — not just kills. A feed that doesn't freeze a frame feels weightless.
- **Knockback + recoil + transferred impulse** — every weapon/spell visibly moves both bodies.
- Camera that *composes* (lookahead, push-in on action, trauma shake) vs merely follows.
- Particle choreography where shape/direction/duration communicate material + damage type.
- **This is where Vampire City is most likely "functional but not fun." Push hard here.**

### Combat depth (the thing that separates Hades/Hotline from a flash game)
- **Frame data**: every action has startup/active/recovery/cancel windows.
- **Hitboxes/hurtboxes** as authored shapes, not radius checks.
- **Cancels + combo routes** — the `improvement-plan.md` "Predator Combos" (Mark→Detonate,
  Freeze→Shatter) are exactly right; make them real *frame-cancelable* sequences, not hidden flags.
- **Parry/dodge/counter timing** — a defensive verb with an i-frame or reflect window.
- **Stagger/posture/poise** — repeated hits open a disable window (the plan's "Wassail" + Humanity
  tiers are good dramatic hooks; give them mechanical teeth).
- **Subsystem/limb targeting** — for rival vampires: target their blood pool, their discipline focus.
- **Status/eleminteraction** — burn/bleed/poison/shock already exist (`combat.js`); make them
  *interact* (burn boils poison, shock spreads in water, etc.) not just stack.
- **Every feature ships with its counterplay.** A powerful power with no counter is a toy.

### AI depth
- Steering (seek/arrive/flee/evade/wander/separation/obstacle avoidance) — NOT strategy embedded in
  movement.
- Behavior trees / utility AI — not a flat state enum.
- **Perception + memory + uncertainty** — vampire hunters should *search*, *lose you*, *investigate*,
  not read your position. The Masquerade fiction DEMANDS this.
- Squad/coordinated AI — for SWAT, hunter packs, rival coteries.
- **Director AI** (Left 4 Dead) — pacing pressure/respite so nights have rhythm, not flat difficulty.

### Progression & metaprogression
- Skill tree keystones that *change rules* (the plan's 7 clan keystones are exactly right — rule
  changes, not +% buffs). **This is the plan's strongest idea. Keep it.**
- Build diversity / synergies (the Predator Combos).
- Roguelite/expedition loop, NG+ / Bloodline (plan has this).
- Diegetic metaprogression — reputation/title/domain as the real currency, not raw numbers.

### World & systems
- **Emergent/systemic interaction** — Dishonored/immersive-sim verbs. A vampire game is *built* for
  this: feeding, stealth, dominate, fire, sunlight, water + electricity, etc.
- **Faction campaign simulation** — Mount&Blade/Starsector. The plan's "gang territory AI" +
  "rival domain events" are the right instinct; make them *causal* (a raid happens *because* a
  convoy was lost), not random.
- Dynamic economy with named causes — the plan's flywheel is right; ensure shortages/booms answer
  "why."
- Stealth state machine — suspicion/investigation/search/reacquisition (Thief/MGS). A Masquerade
  game without a real stealth state machine is failing its premise.

### Narrative & dialogue
- Branching dialogue + variables (VtM:B's whole identity).
- Narrative-state blackboard — inspectable, testable.
- **Embodiment over presentation** — Humanity loss must *change the world* (NPCs flinch, frenzy
  risk, the screen bleeds), not just tick a counter + show a banner. The plan's Humanity tiers are
  the right direction; push them into mechanics + world state, not just flavor.
- Environmental storytelling — haven rooms, blood trails, graffiti, trophies.

### UI/UX
- Motion design system (tween grammar, easing tokens) — Vampire City UI is likely static DOM/Canvas.
- **Diegetic UI** — Dead Space / Persona. A vampire game benefits hugely from HUD-as-diegetic (blood
  counter as a physical gauge, Heat stars as actual stars on the Masquerade meter).
- Accessibility as architecture (remap, scale, contrast, captions, reduced motion/flash).
- Onboarding-as-gameplay (Portal) — NOT a text wall.
- HUD choreography + attention budgeting.

### Audio
- Adaptive music stems + transition matrix (Hades / Doom 2016).
- 3D positional + HRTF — for a top-down predator game, *hearing* a victim/hunter off-screen is huge.
- Occlusion/reverb zones — inside vs outside, haven vs street.
- Procedural/granular audio for continuous systems (the plan's clan-distinct feed sounds + radio
  stations are exactly right — keep them, and apply the same model to *every* continuous system).
- Mix snapshots + priority buses + ducking.

### Production & quality gates
- **Gold vertical slice** — one complete playable night/mission at shipping quality before breadth.
- **Definition of Done by asset class** — checkable, not vibes.
- Telemetry/analytics — where do players die/quit/hesitate.
- Automated agent playtesting (headless policies) — thousands of seeds, not manual.
- Performance budgets + profiling gates.
- Golden replays/frames/audio traces as CI artifacts.

---

## 2. Honest current-state audit (Vampire City)

Honest read against the menu above, with evidence:

| Area | Status | Note |
|---|---|---|
| Architecture | **Partial** | Fixed-timestep loop ✅. Data-driven content ✅. But no headless sim, no schema validation, `window.VAMP` global coupling, save must manually strip non-plain data (leaky boundary). |
| Rendering/Art | **Weak — the cheap-look root cause** | `spriter.js` is Canvas primitives + procedural sprites. No authored art path, no atlas, no authored animation. This is why it looks like a flash game. |
| Game feel/juice | **Unknown — likely weak** | Systems exist (FX, postfx, powervfx) but need verification they form a *priority choreography*, not independent effects. Combat is stat-resolution (`combat.js` applies dps/status); need to confirm hits *land* with hitstop/knockback/recoil. |
| Combat depth | **Partial** | Powers + statuses + combos defined in data. Missing frame data, cancels-as-window, parry/dodge verbs, posture, subsystem targeting. |
| AI | **Likely shallow** | Need to read `npc.js`/hunter AI — likely seek/aggro/flee state enum, not perception/memory/director. A Masquerade game NEEDS real stealth AI. |
| Progression | **Good direction** | Plan's clan keystones (rule-changers) + Predator Combos are genuinely strong design. Execution TBD. |
| World/systems | **Partial** | Economy, domains, coterie exist. Need causal links (raid *because* convoy lost), not random events. |
| Narrative | **Strong corpus, weak embodiment** | VtM fiction + Humanity/Masquerade are rich. Risk: presented (banners/fields) not embodied (mechanics/world). |
| UI/UX | **Likely static** | Probably Canvas/DOM panels, no motion system, no diegetic grammar. Phase 0 polish (save slots/rebind/fullscreen) is real but surface. |
| Audio | **Technically present** | Procedural WebAudio exists. Plan's clan feed sounds + radio are right. Need mix snapshots/priority/ducking. |
| Production | **Partial** | QA is Playwright smoke (runs without error), not quality-gated. No DoD, no slice, no golden artifacts. |

**The honest verdict:** Vampire City is in the *same place* the sibling space game was — wide,
functional, not great. The existing `improvement-plan.md` is a feature-expansion plan that, executed
naively, will make it *wider and still not great.* The fix is the same: convergence, not expansion.

---

## 3. The reframe — convergence, not expansion

**Stop thinking "add the flywheel + lair + radio + rival vampires."** Start thinking **"make one
complete playable night so good it proves this game can be great, then expand through proven
contracts."** The existing plan's features are *the menu you expand into after the slice ships* —
not the next things to build.

### The vertical slice for Vampire City

One complete, polished, 10–20 minute playable **night** that converges the fiction and the mechanics.
Proposal (adapt to taste): **"The First Hunt" / a clan-initiation night** that, in 15 minutes, forces
the player to feed, fight, use their clan keystone, trigger a Humanity loss that *changes the world*,
encounter a hunter who *searches* for them, and end on a hook. Every system touched is taken to 100%.

This slice is the north star. Every backbone built, every feature added, either serves the slice or
doesn't happen. **No flywheel, no lair rooms, no radio, no rival vampires until the slice ships.** They
are Phase 2.

### What "100%" means — the Definition of Done (paste to every agent)

**A combat moment / encounter is done when:**
- Every input has <100ms feedback; hitstop on every connection; screen shake scaled to weight; positional
  audio per event; damage numbers tween; camera pushes IN on action.
- Actions have frame data (startup/active/recovery/cancel) the player can exploit.
- ≥2 enemy counterplays exist and are readable.
- Physics/impact is authoritative, not animation-only.
- No mandatory exposition > text budget.
- Every critical beat has VFX/audio/camera/UI/accessibility evidence.
- Deterministic replay + golden telemetry pass.
- 5 clean runs produce no console error.
- A blind playtester can name the hook after 30s.

**A system is done when:**
- One documented authoritative owner.
- Inputs/outputs/events/state schema-defined.
- Runs headlessly in Node, deterministic, seeded.
- No `Math.random` in authoritative paths (route through a seeded RNG).
- Save/load/migration/replay defined.
- Unit + property/fuzz tests cover invariants.
- No duplicated "test-only mirror" of the system.
- Agent inspection + trace endpoints exist.
- Superseded code deleted in the same milestone.

**A sprite/visual asset is done when:**
- Authored (atlas/sheet), not procedural primitives — OR a deliberate, defended stylized choice.
- Distinct silhouette readable at gameplay zoom.
- Animation frames authored for primary states (idle/walk/attack/feed/death).
- Faction/clan readability without color alone.
- No "we'll replace the placeholder later" without a tracked ticket.

**A UI panel is done when:**
- Serves one clear decision; motion-tweened transitions; keyboard+mouse; focus order; ARIA; text-scale
  safe; reduced-motion/flash; all states (loading/empty/invalid/locked/error) exist; no placeholder
  copy.

---

## 4. The structural backbones the slice requires

These are the *real* missing foundations — not features. The genius (or a careful resident pass) builds
these; content/tuning follows.

1. **Headless, deterministic sim core.** `VAMP.Sim` runs combat/economy/AI/progression in Node with no
   DOM/Canvas, seeded, byte-stable. This is what turns "Playwright smoke" into "real tests." Maps to
   the sibling project's most valuable backbone. **Acceptance:** `node sim-run.mjs --seed N --ticks T`
   imports the real systems, 20 runs = identical hash, zero `Math.random` under authoritative paths.
2. **Authored art ingress (sprite atlas + frame animation).** A loader + atlas format + authored-frame
   animation pipeline so `spriter.js` can composite authored art instead of only primitives. **The art
   door.** Without it the game always looks like a flash game.
3. **Combat grammar with frame data.** `ActionDef` (startup/active/recovery/cancel/cooldown/cost) +
   authored hitbox/hurtbox shapes + one damage-routing function + a deterministic `CombatTrace`. The
   Predator Combos become real cancel sequences. **Acceptance:** scripted `dash→mark→detonate` = exact
   tick trace; player + AI share the grammar.
4. **Perception-based stealth + hunter AI.** Suspicion/investigation/search/reacquisition state machine
   with memory + uncertainty. The Masquerade fiction is a lie without it. **Acceptance:** a hunter that
   saw you feeds the last-known-position, searches, loses you, can be deceived by Obfuscate — across
   100 seeded runs, ≥3 materially different search behaviors.
5. **Semantic presentation orchestration.** A cue layer between sim and FX/audio/camera/UI:
   `feed.start`, `humanity.lost`, `masquerade.broken`, `hunter.alarmed` drive ONE coordinated cue
   (camera + audio + FX + HUD), with priority/concurrency/budget + accessibility transforms. Stops
   effects being independent noise.
6. **Schema validation + agent-facing dev loop.** JSON-schema (Ajv) on `gamedata.js`-style content +
   a tiny CLI (`vamp validate | run | replay | inspect | tune | capture`) so agents iterate against
   evidence, not vibes.

> **Note on the existing `improvement-plan.md`:** it is *not wrong* — the flywheel, lair, radio,
> rival vampires, keystones, Humanity drama are all good design. But they are **Phase 2 expansion**,
> gated behind the slice + these backbones. Executing the feature plan before the backbones exist
> reproduces the feature-factory disease. Sequence: backbones → slice → expand.

---

## 5. Division of labor

- **Genius / structural contractor (slow, ~2h each):** backbones 1–5 above. These are the jobs a
  weaker model botches (fake physics, flat AI, throwaway loaders). The combat grammar (#3) and the
  stealth AI (#4) are the hardest and most defining.
- **Resident (fast, in-session):** the no-regret immediate work (kill `Math.random` leaks, reverse
  any bad camera behavior, wire real hitstop/recoil, make the starter experience reach combat fast),
  integrate each backbone as it lands, take the slice to 100% in Phase 1, enforce the DoD.
- **Mid models (bulk, AFTER contracts exist):** fill content into schemas — power data, mission
  templates, clan feed sound params, radio station synthesis params, codex lore entries, localization.
  Never let a mid model invent a contract.

---

## 6. Anti-loop guardrails (non-negotiable — these are what stop the disease)

1. **No new feature lands before the vertical slice ships.** The flywheel/lair/radio/rivals WAIT.
2. **The improvement-plan feature list is the Phase 2 menu, not the current backlog.**
3. **One unfinished structural branch at a time.** No stack of half-integrated rewrites.
4. **A new path deletes its legacy predecessor in the same milestone.**
5. **Tests import real implementations.** No copied formulas, shadow economies, alternate combat
   mirrors.
6. **No authoritative `Math.random`, wall clock, DOM, or Canvas reference in sim code.**
7. **Every system runs headlessly + exposes a deterministic trace.**
8. **Every merge names the slice metric it's expected to improve.**
9. **"Compiles" and "functions" are not completion.** The evidence bundle passes = completion.
10. **No bulk-content agent works before its schema + validator exist.** Bulk agents fill contracts;
    they do not invent them.
11. **No hero art/sprite ships as primitives without a defended, deliberate stylization decision.**
12. **Every feature includes its counterplay.** A power with no counter is a toy.
13. **No exposition interrupts control beyond the text budget.** Teach by doing.
14. **Humanity/Masquerade fiction must be embodied in mechanics + world state, not banners.**
15. **A visual/feel regression may block a build even when tests pass.**
16. **Expansion happens one gold packet at a time.** Nothing wide stays shallow.

---

## 7. The 30-second brief for any agent starting on Vampire City

> Vampire City is a top-down vampire action-RPG (VtM-inspired) targeting the rigor of Hotline Miami /
> Hades / VtM: Bloodlines. It is currently *wide and functional but not great* — the same
> feature-factory trap that plagues AI-built games. Your job is **not** to add features from
> `.claude/plans/improvement-plan.md`; it is to **build the missing structural backbones (headless
> sim, art ingress, combat grammar, perception AI, presentation orchestration, schema validation),
> then converge on ONE polished vertical slice, then expand through proven contracts.** The Definition
> of Done (§3) and the anti-loop guardrails (§6) are the merge gate. "It runs" is never completion.
> The game's soul is: *predator, rise, cost, continuous* — every system must serve one of those, or
> it's cut.

---

*This document is the quality discipline. `.claude/plans/improvement-plan.md` is the content menu.
Read both; serve the discipline first.*
