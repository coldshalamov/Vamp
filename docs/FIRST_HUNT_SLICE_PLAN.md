# FIRST_HUNT_SLICE_PLAN.md — the governing deliverable

> The merge gate for Phase 1. A 12–18 minute playable night that proves the whole game. This plan is
> built on **code truth**: the backend spine already exists and is tested, so this is a *convergence +
> authoring* plan, not a build-from-scratch plan. Read with `CUT_OR_DELAY_LIST.md` (what we refuse to
> touch until this is fun) and `AGENT_WORKSTREAM_PLAN.md` (who builds what, in parallel).
> Local Windows safety: use only `scripts/RunGutSafe.ps1` for bounded local smoke. Full recursive GUT,
> repeated clean boots, and windowed evidence capture belong in CI or on an explicitly approved machine.

## 0. The highest-value path (the strategic call)

The repo's situation is **backend-heavy, presentation-light**. The trap to avoid is *adding more
systems* — there are already ~25 tested ones. The leverage is to **make one night real**. So:

1. **Freeze backend breadth.** No new domains/coterie/businesses/alchemy/loot depth. They stay in code,
   quarantined from the slice UX.
2. **Spend the entire budget on felt quality of one night:** art, lighting, audio, juice, and the
   *authored* structure that turns the test-input loop into a curated experience.
3. **Close exactly the slice-critical mechanic gaps** (gulp, resonance, humanity-world,
   3-clan keystones, dawn pressure) — and nothing else.

This is the spec's own anti-bloat doctrine ("converge before expanding"), and it's the right call
because the expensive, un-fun-to-build half (a correct deterministic sim) is already done.

## 1. Directions chosen (one each — no soup)

| Axis | Choice | Why this one (evidence-based) |
|---|---|---|
| **Gameplay** | **Hades-tight action core (A)** + vampire verbs, with GTA heat (C) and a *seed* of immersive-sim (E) | The skill-gap + frame-data + cancel combo already exist and are tested — the action foundation is the repo's strength. Lead with it. City-sim and systemic surfaces are Phase 2. |
| **Art** | **Dirty Top-Down Urban Horror** (user-chosen 2026-06-23) | Grimy concrete streets, sodium-orange streetlamps, headlight/police-light cones, neon signage, wet-asphalt sheen, blood trails — GTA-readable, grounded-urban rather than premium-comic. Lighting is *even more* central here (reflective rain-slick streets, light cones), so the Light2D work is the unlock. The existing comic-noir concept JPGs become **menu/portrait** art; gameplay sprites lean grittier and more grounded. Top-down framing + chroma-key + atlas pipeline unchanged. |
| **UI** | **Predator-Minimal in gameplay, Occult-Dossier in menus** | `art/ui/` already ships HP/vitae bars, hunger teeth, heat stars, slot bg — purpose-built for a minimal predator HUD. |
| **Audio** | Build the **bus architecture** (Master/Music/SFX/Voice/Ambient) + CueBus→AudioServer bridge; start with the **feeding heartbeat**, hit/feed/power one-shots, one adaptive ambient stem, offscreen hunter footsteps; captions for all | Audio is at zero; the architecture is the unlock. CueBus is the perfect driver (it already carries `pos`/`magnitude`). |
| **Tech** | **Keep deterministic Sim authority; CharacterBody2D-style actors are already mirrored.** Fix present-layer wiring only. | The Sim is proven and tested. Do not rewrite it. |
| **Physics** | Actors as Sim entities mirrored to Node2D views; Area2D-style overlap already done in sim; RigidBody2D reserved for Phase-2 props/cars | Matches the existing view/sim split. |

## 2. "The First Hunt" — the authored night (beat sheet)

A clan-initiation night. **The sire's herald wants you dead before dawn.** Each beat maps to existing
backend + the specific gap to close.

| # | Beat | Player experience | Backend (exists) | Gap to close for the beat |
|---|---|---|---|---|
| 1 | **Wake** | Rise in a haven; a single diegetic line; "move" taught by a lit path, not text | `new_game`, haven surface, named points | Onboarding-through-action; one banner line; player follow-light so the path reads |
| 2 | **First feed** | Stalk a mortal; **read their resonance** (aura tint); grab; **hit the gulp window**; **choose kill or spare** | feed grab/drain/kill-spare, hunger, body, witness | **Resonance type + aura read**; **gulp timing window** (skill→vitae/slowmo); feed VFX/audio (heartbeat) |
| 3 | **Consequence** | A witness sees it → heat rises; a body is found | witnessed_act, heat, investigation | Witness/heat **readability** (icon, sting, cue not clobbered) |
| 4 | **The hunter searches** | A hunter (the herald) hunts your **last-known position**, not you; break LOS down an alley and watch them lose the trail | last-known-pos responder spawn, perception, 6s window | Search **legibility** (search cone/marker); ≥3 search behaviors (property-test target) |
| 5 | **Forced fight** | An enemy that **demands your clan keystone** to beat cleanly | combat grammar, enemy presets, status | **Wire the 3 slice keystones** at runtime; one counter-demanding encounter |
| 6 | **Humanity turns the world** | A lethal choice drops Humanity → **pedestrians flinch, the screen cools, the city reacts within 1s** | humanity stat, cues | **Humanity→world hook** (exposure + NPC reaction + screen state + one banner) |
| 7 | **Dawn pressure** | The sky shifts; a countdown; a desperate run to a haven as sun exposure bites | dawn roll, haven shelter, sun damage | **Continuous dawn pressure** (over-time exposure + countdown UX + sky lerp), not one-shot |
| 8 | **The hook** | You wound the herald; they **flee scarred** — "they'll be back, and they'll remember the fire" | nemesis flee→return→scar (tested!) | **Trigger it in the slice** (force_nemesis on the herald) + a telegraphed exit line |

A blind playtester should, after 30s, be able to say: *"I'm a vampire predator; I feed to survive, I
broke the Masquerade and got hunted, and the guy I let live is coming back for me."*

## 3. The slice content roster (deliberately small)

- **3 clans, each a different solution to beat 5:** **Brujah** (Blood Rage frenzy toggle — brute the
  fight), **Nosferatu** (One With Shadow — stealth-chain past it), **Tremere** (Vitae Alchemy — blood
  magic burst). These three already have boon/bane in `GameCatalog`; we wire their *keystones*.
- **~6 powers in the slice hotbar** (from the 36 ported): dash, a bolt, a slam, cloak/vanish, mend,
  mark — plus the clan keystone. (Catalog already exceeds this.)
- **~4 enemy roles** for the slice: a witness/civilian, a thug, the **shield cop** (forces flank/dash —
  front-armor already in `damage_entity`), and the **herald-hunter** (searches; becomes the nemesis).
- **1 handcrafted block** — upgrade `load_vertical_slice` from "spawn 5 things" into an *authored*
  street with an alley (LOS break), a lit feeding spot, a haven to flee to, and a forced-fight choke.
  Multi-route is a stretch goal; one clean critical path first.
- **1 night clock** with real dawn pressure.

## 4. Definition of Done (the merge gate — checkable)

From `REVAMP_SPEC.md §6`, scoped to what the slice must actually prove:

- [ ] **Boots clean:** 5 consecutive runs, **zero console errors** (fix icon + clobber first).
- [ ] **Renders like a game:** authored sprites for player + the 4 enemy roles (zero hero primitives);
      ≥3 dynamic lights per scene incl. a player follow-light; the night reads as *moody*, not *broken*.
- [ ] **Sounds like a game:** every CueBus beat has audio on the right bus; feeding heartbeat audible;
      offscreen hunter footstep reliably reactable; captions present.
- [ ] **Feels like a game:** hitstop on every connect **and** camera shake (clobber fixed); dash i-frames;
      <100ms feedback on every action.
- [ ] **Feeding is a skill+choice:** gulp window measurably changes vitae/heat; resonance choice
      measurably changes outcome; kill vs spare measurably changes the board.
- [ ] **Humanity changes the world within 1s** of a drop (NPC + screen), not a menu number.
- [ ] **Hunter searches, doesn't cheat:** breaks LOS → loses you in ≥95% of seeded runs; property test green.
- [ ] **Clan matters:** the 3 clans require *visibly different* approaches to beat 5.
- [ ] **Dawn matters:** a night can end in torpor because you pushed one feed too far.
- [ ] **Nemesis hook lands:** the herald flees scarred; a blind playtester names the hook.
- [ ] **Skill gap holds at slice scale:** scripted expert beats masher by ≥30% time / ≥50% fewer hits
      on the same seed (extend `test_skill_gap` to the slice).
- [ ] **Save/load works:** full Sim persists from the menu and reloads into a correct scene.

## 5. Build order (milestones → this slice)

- **M1 (runs clean):** icon fix, CueBus merge-define, full-save from Boot, and a CI/approved-machine
  clean-run evidence bundle (the `CaptureSlice` harness is the seed). Locally on Windows, use only the
  bounded smoke wrapper. *Mostly done; small fixes.*
- **M2 (player feel):** player follow-light, camera shake restored, hitstop tuning, dash/attack/feed
  feedback <100ms, the slice skill-gap benchmark. First authored player sprite.
- **M3 (feeding/humanity):** gulp window, resonance read + buff, humanity→world hook (NPC flinch +
  screen state + banner), feeding heartbeat audio.
- **M4 (heat/hunter):** search legibility + cone, the property test (≥3 behaviors), the forced fight,
  the 3 clan keystones at runtime, the herald→nemesis trigger.
- **M5 (art/light/UI/audio pass):** authored sprites for all 5 actors, dirty-urban lighting (street/head/police/neon light cones + wet-asphalt reflections), predator
  HUD with real `art/ui` pieces, the audio bus graph + cue table, continuous dawn pressure + sky lerp.
- **M6 (the slice):** author the block + the night's beats end-to-end; 5 clean runs; blind playtest.

Each milestone ships an **evidence bundle** (screenshots via `CaptureSlice`, GUT green, a short
clip-or-frames capture, changed-files + risks) per the handoff rules. On local Windows, capture/GUT
must stay bounded through the safe wrapper; full evidence is CI/approved-machine work.

## 6. What this slice is NOT (guardrails)

No districts beyond the one block. No vehicles-as-feature (they render; they're not a slice verb). No
domains/coterie/businesses/alchemy/loot UI. No full skill-tree screen. No systemic fire/water/electric.
No radio. No dialogue trees. All of that is real in code and waits in Phase 2 — see `CUT_OR_DELAY_LIST.md`.
**Do not begin Phase 2 until a blind playtester finishes The First Hunt and wants to play it again.**
