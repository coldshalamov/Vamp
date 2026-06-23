# THE OVERALL REVAMP — Vampire City, unified
### Where the Blood Grammar (the verb) and the Nightglass kit (the consequence) become one immersive sim.

> This reconciles every design document in the repo into a single game:
> - **`VAMPIRE_CITY_BIBLE.md`** — the macro flywheel & the Rise (what the game *is*).
> - **`GAMEPLAY_GRAMMAR.md`** — "The Blood Grammar", the moment-to-moment verb/physics/build layer.
> - **`docs/VampSpec.txt`** — the "Nightglass 2026 Glow-up Kit": a city-pressure immersive-sim layer
>   (witnesses, rumor, faction belief, an opportunity director, player-style inference, fail-forward).
> - **`MASTER_PLAN.md`** — the 35-feature build backlog; **`CUT_OR_DELAY_LIST.md`** — the anti-bloat guardrail.
>
> The headline finding: **these were never two visions.** They are the same thesis seen from two ends, and
> they already share an architecture this repo has built. This document is the unifier and the roadmap.

---

## 1. THE ONE THESIS BOTH SPECS INDEPENDENTLY STATE

Read these side by side — they were written by different processes and say the *same thing*:

- **Nightglass** (`VampSpec.txt`): *"The player should never merely spend power. Every use of power should
  solve one problem, create a signature, alter somebody's model of the player, and bend the next
  situation."* → *"The fantasy is not omnipotence. It is authorship under pressure."*
- **Blood Grammar** (`GAMEPLAY_GRAMMAR.md`): *"Spending blood and creating battlefield terrain are the same
  physical act."* → power is never a number behind glass; it is a *visible, physical residue.*

Nightglass says **power leaves residue.** The Blood Grammar makes that residue **literal, physical, and
commandable: blood.** That is the keystone of the whole revamp:

> **Your spilled blood is simultaneously the verb (Open Vein), the evidence (Nightglass witnesses/rumor),
> and the signature of your style (Nightglass style-inference). One substance carries all three layers.**

A vampire is the only fantasy where this is literally true — which is why this game, specifically, can fuse
a kinetic action core with a systemic-consequence city in a way no other immersive sim can.

---

## 2. THE THREE-LAYER STACK (how the specs compose)

Nightglass already defines the game as a four-layer instrument (Contact → Tactic → Consequence → Arc). Our
two design docs slot into it exactly, with blood threading top to bottom:

| Nightglass layer | The player asks | Owned by | Blood's role |
|---|---|---|---|
| **Contact** ("does this feel good *now*?") | input, camera, impact, readability | **Blood Grammar** §6 (the four cores) | the Open Vein wound you bleed as you act |
| **Tactic** ("what's my best move?") | spatial options, resources, leverage | **Blood Grammar** §1–3 (5 atoms, composition) | spilled fluid is terrain, ammo, cover, trap |
| **Consequence** ("what will this cost/unlock?") | witnesses, evidence, heat, debt, belief | **Nightglass** §1–4 (event spine, pressure, rumor, factions) | the trail IS the evidence; cleaning it is a verb |
| **Arc** ("who am I becoming?") | style, relationships, district state, legacy | **Bible** (the Rise) + **Nightglass** §5–6, §13 (director, style, City Pressure) | your blood-habits are the style the city learns |

**The loop that ties the layers (and the two specs) together:**
```
SPILL a verb (Blood Grammar)
   → that blood is EVIDENCE a witness sees / a camera records (Nightglass)
      → the rumor names your METHOD and raises Exposure for your identity (Nightglass)
         → your repeated methods form a STYLE VECTOR (Nightglass inference)
            → the OPPORTUNITY DIRECTOR composes the next night around that style (Nightglass)
               → which you answer with more SPILL — but now you also COMMAND the trail away,
                  or INSCRIBE a false one, to manage the consequence (Blood Grammar × Nightglass fused)
```
The micro feeds the macro feeds the micro. That circle is the overall game.

---

## 3. VOCABULARY RECONCILIATION (one canon)

Nightglass is deliberately engine-neutral and original-termed; our game is vampire-native. **The vampire
vocabulary is canonical; we adopt Nightglass's structural rigor under our names.**

| Nightglass term | Vampire City canon | Status in repo |
|---|---|---|
| **Condition** (body can execute?) | Vitae/HP + Injury wounds | Vitae unified ✓; injury arcs = new |
| **Need** (what power demands?) | **Hunger / Frenzy** (the Beast) | coded ✓ |
| **Mask** (`identity_key` — who does the city think did it?) | **The Masquerade** | heat/witness partial ✓ |
| **Leverage** (who can be moved?) | **Influence + Coterie + Boons owed** | coded, unsurfaced |
| Style channels: **FORCE / STEALTH / INFLUENCE / MOBILITY / SYSTEMS** | the **9 disciplines + clans** (see §4) | powers coded ✓ |
| Pressure: **Exposure** | Masquerade exposure / `_compute_exposure` | coded ✓ (+Humanity term, just built) |
| Pressure: **Heat** | district Heat (0–6), responders | coded ✓ |
| Pressure: **Injury / Debt / Anomaly / Volatility** | wounds / Boons / the Beast & Inquisition attention / district terror-prosperity | partial |
| **Event spine** (`gameplay_event_published`) | **`CueBus` / `Sim.emit_cue`** | **already built ✓** |
| **NightglassDebugHUD** | **F3 `DebugOverlay`** | **already built ✓** |
| Reference **pressure model** (Python) | observers ported into `SimMeta`/`Sim` | to port |
| "sim may not read wall-clock; all RNG seeded; events idempotent; LOD sim" | the deterministic `Sim` constitution | **already our law ✓** |

**The punchline of this table:** the Nightglass kit's own Godot adapter says *"prefer an existing
autoload/service if the repository has one."* We have one — `CueBus`. We are already past the kit's Gate-3
architecture and its determinism contract. The kit is not asking us to rebuild; it's handing us the
*consequence algorithms* to run on rails we already laid.

---

## 4. THE FUSION THAT MAKES 1 + 1 = 3

The specific places where combining the two specs produces something neither had alone:

1. **Blood = residue (the central fusion).** The Open Vein's spilled trail *is* Nightglass's evidence
   object. **Hemography** (Auspex reads who bled, when, which way they fled) *is* the witness/rumor record —
   rendered in physical fluid instead of an abstract claim. So "cover your tracks" stops being a menu toggle
   and becomes COMMAND the trail into a drain, or INSCRIBE a false trail toward a rival's haven to frame
   him. *Stealth, evidence, and physics are one system.*
2. **Style-as-practiced is the destination the composable primitives were built for.** Nightglass's "the
   system describes your style *after* play, it doesn't prescribe a class" is the exact promise of the Blood
   Grammar's "you discover a build by noticing what spill reacts with what surface." They are the same idea
   at two scales — the five atoms generate the habits; the style-inference vector *names* them (Predator,
   Ghost, Saboteur…) and the director answers them.
3. **Vitae Inscription is how the player edits the consequence layer.** Nightglass lets factions/pressure
   reshape the world; the Blood Grammar lets *you* locally rewrite a rule in blood (`SUN IS BLOOD`, `THE FED
   ARE FRIENDS`). Inscription is the player's verb *against* the city-pressure machine — authorship under
   pressure, made literal.
4. **The opportunity director composes nights around YOUR Blood Grammar.** Director scoring already weights
   "player-style support" + "gentle counterpoint." Feed it the style vector built from your blood-verbs and
   the city literally stages scenarios that let you express — or pressure — your signature. The Bible's
   radiant `EVENT_DEFS` become the director's instantiation layer.
5. **Fail-forward IS the Cost pillar.** Nightglass's "avoid binary failure; prefer debts, wounds, exposure,
   lost leverage, changed ownership" is the Bible's Cost pillar and the dawn/torpor/Boon systems, stated as
   an engineering rule. They are the same design value; adopt Nightglass's phrasing as the doctrine.

---

## 5. RECONCILING THE SCOPE TENSION (the honest part)

Nightglass is *ambitious* — 3 districts, 5–7 factions, social-encounter play, an opportunity director, a
20–35h campaign. Our `CUT_OR_DELAY_LIST` and convergence doctrine say **prove the First Hunt slice is fun
before any breadth.** Are these in conflict? **No — Nightglass agrees, in its own words:**

- *"Density beats acreage… a three-block district with twenty meaningful actors beats ten square km."* = the Bible's "richest block" slice.
- *"Fix movement, camera, interaction, hit reaction **before** adding content."* = feel-first (Gates 1–2).
- *"Integrate the city-pressure model in **shadow mode** first: observe events without changing gameplay."* = de-risk before commit.
- *"Convert three existing missions into systemic opportunities **before** authoring new missions."*
- *"Only **then** expand factions, districts, abilities, vehicles, and narrative arcs."*

Both specs are anti-feature-factory. The synthesis is therefore not "build everything" — it's a **strict
sequence**: the Blood Grammar slice → consequence in shadow mode → one district live → expand. The two
specs' build philosophies are identical; only the vocabulary differed.

---

## 6. THE UNIFIED ROADMAP (Nightglass's 10 gates × our build orders × the waves)

One sequence, merging Nightglass gates, the Blood Grammar build order, and the Bible's flywheel:

| Phase | = Nightglass gates | What ships | Already done in repo |
|---|---|---|---|
| **0 · Truth & rails** | G0, half of G3 | audit, deterministic Sim, **CueBus event spine**, **F3 overlay**, full save/load, CI+determinism gate | **✓ all of it** |
| **1 · The Verb (First Hunt slice)** | G1–G2 | **fluid spine** (int-depth surfaces) → **gulp-as-master-cancel** → **surface reaction matrix**; the felt night (lighting/audio/sprites) | gulp window ✓; lighting/audio/UI ✓; fluid spine = next |
| **2 · Shadow-mode consequence** | G3–G4 | port the pressure observer (Exposure/Heat/Need/Injury/Debt/Anomaly/Volatility) onto CueBus; **witness→claim→rumor** with **blood-trail = evidence (Hemography)**; identity/district heat; cleanup verbs | heat/nemesis/last-seen partial ✓; humanity→world ✓ |
| **3 · The Arc (one district live)** | G5–G7 | 5 factions' belief+agenda; **opportunity director keyed to the style vector**; convert 3 missions to objective graphs; the Rise (Legend→titles→caps); **Vitae Inscription** | factions/districts/EVENT_DEFS/skill-tree coded, unsurfaced |
| **4 · Make it expensive & endless** | G8–G10 | presentation pass; replay seeds; **City Pressure post-campaign**; legacy/NG+; ship discipline | NIGHT SHIFT UI + graphics foundation ✓ |

**Sequencing rule (from both specs):** do not open a phase until the prior phase's slice is *fun on a blind
playtest*, and gate every Sim-touching change on the 20-run determinism hash + GUT + capture.

---

## 7. GOVERNANCE — adopt Nightglass's execution contract as our dev law

The kit's `AGENTS.md` is a superb, compatible discipline. We adopt it wholesale because it sharpens what we
already do:

- **The four PR questions** (which player problem does this solve? which invariant improves? what new
  failure mode? how is it rolled back?) — attach to every feature commit.
- **Shadow mode before authority** — new consequence systems *observe* via CueBus before they change
  outcomes. This is how we add the pressure model without risking the slice.
- **Feature flags / data switches** so anything can be disabled until the slice is approved.
- **Stop-and-write-an-ADR conditions** (touching >3 singletons; determinism diverges before 10k events;
  a "fun" change hurts combat-distance readability). 
- **The anti-feature list** (no map-icon confetti, no bullet-sponge elites, no universal psychic police, no
  single global morality bar, no readability-killing post-FX) — pin beside our `CUT_OR_DELAY_LIST`.
- **Keep our determinism constitution** — it already satisfies the kit's hardest rules (seeded RNG, no
  wall-clock in sim, idempotent events, LOD sim). The fluid spine must hold the line: **integer depth,
  bounded active-set, fixed iteration order, next-tick-deferred triggers** (see `GAMEPLAY_GRAMMAR.md` §8).

---

## 8. WHAT THE OVERALL GAME IS, IN ONE PARAGRAPH

**Vampire City** is a top-down gothic-noir vampire immersive-sim action-RPG where **blood is a commandable
physical fluid that is at once your life, your ammo, your money, your food, and your forensic signature.**
Moment to moment you author a predatory style from five composable blood-verbs (spill, command, react,
drink, inscribe) over a kinetic frame-data core with an "easy to learn, lifetime to master" skill curve. The
blood you spill becomes terrain you weaponize *and* evidence the city reads: a living web of factions,
witnesses, and rumors learns your method, raises pressure on your Masquerade, and a style-aware opportunity
director composes each night around who you are becoming. Failure rarely ends the night — it mutates it into
debt, exposure, a wound, a scarred nemesis, or a dawn you barely survive. Across those nights you Rise from
fledgling to Lord of the Night, claiming territory, siring a coterie, and writing the laws of the city in
red — until your reign itself becomes the thing the next predator must topple.

That game is not hypothetical. Its backend is ~85% built and tested, its event spine and debug rails and
determinism are already in place, and its two design halves — the verb and the consequence — turn out to be
one idea. The revamp is **wiring the blood through all three layers, in the strict order above.**
