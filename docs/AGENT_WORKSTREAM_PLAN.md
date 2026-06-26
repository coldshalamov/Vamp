# AGENT_WORKSTREAM_PLAN.md — staged parallel production plan

> How the work gets done: a team-of-agents model mapped to concrete, DoD-gated tasks. Each task names
> files, the gap it closes (from `GODOT_WIRING_AUDIT.md` / `FIRST_HUNT_SLICE_PLAN.md`), and its
> evidence requirement. **The director (A) owns contracts, review, integration, and taste; agents own
> bulk implementation against contracts.** No agent gets a feature-name task without a checkable DoD.

## Sequencing principle

Three waves, gated. **Wave 1 unblocks everything; Wave 2 is the felt slice; Wave 3 is the polish gate.**
Within a wave, the listed streams run in parallel. Do not start Wave 2 art-dependent integration until
the Wave 1 pipeline (B/H-pipeline) lands; do not start Wave 3 until Wave 2's mechanic gaps close.

Local Windows safety overrides every evidence row below: use only the bounded
`scripts/RunGutSafe.ps1` smoke wrapper locally. Full recursive GUT, repeated clean boots, and
windowed capture belong in CI or on an explicitly approved machine.

---

## WAVE 1 — Make it clean & unblock the pipeline (small, safe, mostly verified)

| Stream | Task | Files | DoD / evidence |
|---|---|---|---|
| **B Tech** | Fix `art/icon.png`; CueBus **merge-define** (not replace) + regression test; remove orphan `break_responder_locks`. | `project.godot`, `src/present/CueBus.gd`, `src/sim/Sim.gd`, new `test/unit/test_cuebus_merge.gd` | 5 clean boots, 0 errors; test asserts a def retains camera+vfx keys; 38→39+ green. |
| **B Tech** | Persist full `SimMeta.serialize()` from Boot; save→load→scene-resync smoke. | `scenes/Boot.gd`, `src/core/SaveSystem.gd`, new test | Load a saved night; entities + HUD reflect restored Sim. |
| **J Audio** | Define Master/Music/SFX/Voice/Ambient bus layout; bridge `CueBus._play_audio`→AudioServer; wire `SettingsMenu` sliders to all buses. | `src/present/CueBus.gd`, `src/ui/SettingsMenu.gd`, `default_bus_layout.tres` | A test cue produces an AudioServer play call on the right bus; sliders move bus volume. |
| **H Art (pipeline)** | Stand up the sprite pipeline: chroma-key the existing magenta-bg concept JPGs into transparent PNGs for **menus/portraits/loading**; define atlas + `SpriteFrames` import convention; write the style guide. | `assets/images/*`, new `art/portraits/`, `docs/UI_STYLE_GUIDE.md` (extend) | Title/menu uses real key-art; a documented pipeline a content agent can follow. |
| **M QA** | Promote `test/CaptureSlice.tscn` into the evidence workflow; add a render-smoke + no-error gate; document the CI/approved-machine capture command. | `test/CaptureSlice.gd`, CI/docs | Every PR can attach a fresh screenshot bundle + GUT result without requiring raw local Windows Godot runs. |

**Wave 1 gate:** boots clean (0 errors), audio bus graph live, sprite pipeline documented, full save/load.

---

## WAVE 2 — The felt slice (close the slice-critical mechanic gaps + first art)

| Stream | Task | Files | DoD / evidence |
|---|---|---|---|
| **D Feel** | Restore camera shake (post-clobber-fix); tune hitstop; particle pool (blood/spark/dash-trail); <100ms feedback audit per action. | `src/present/VisualFX.gd`, `CameraDirector.gd`, new `Particles` | Every connect = hitstop + shake + particle, once (no cue storm). |
| **E Feeding** | Gulp timing window (input→vitae/slowmo coupling); resonance type on victims + Auspex aura read + feed buff; humanity→world hook (exposure + NPC flinch + screen state + one banner/step). | `src/entities/SimPlayer.gd`, `SimNPC.gd`, `src/sim/Sim.gd`, `SimMeta.gd`, HUD | Scripted good-gulp vs bad-gulp differ in vitae/heat; feed-on-choleric measurably buffs; humanity drop changes a pedestrian + screen within 1s (test). |
| **F Stealth/AI** | Seed-driven search branches (pursue/flank/give-up-ambush/call-allies) + spreading uncertainty cone; the 100-seed property test; search legibility marker. | `src/entities/SimNPC.gd`, new `test/unit/test_perception_property.gd` | ≥3 materially different search behaviors over 100 seeds; 0 runs "instantly know live pos." |
| **L Systems** | Wire the **3 slice clan keystones** at runtime (Brujah Blood Rage toggle, Nosferatu One-With-Shadow, Tremere Vitae Alchemy HP-bleed); one counter-demanding encounter per clan path. | `src/entities/SimPlayer.gd`, `src/sim/SimMeta.gd`, `Sim.gd` | The forced fight is *visibly* solved differently by each of the 3 clans (test + capture). |
| **C/G Gameplay** | Author `load_vertical_slice` into a real block (alley LOS-break, lit feed spot, haven, fight choke); trigger the herald nemesis (force_nemesis) + telegraphed exit; continuous dawn pressure (over-time sun + countdown + sky lerp). | `src/sim/SimWorld.gd`, `Sim.gd`, `SimMeta.gd` (`resolve_dawn`), HUD | The 8 beats play end-to-end; a night can end in torpor; herald flees scarred. |
| **H Art (first actors)** | Authored top-down sprites: player + 4 slice actors (civilian, thug, shield cop, herald-hunter), idle/walk/attack/feed/death. | `assets/sprites/`, `EntityRenderer.gd` (sprite path) | Zero hero primitives in the slice; distinct silhouettes per actor. |

**Wave 2 gate:** the slice's *mechanics* are fun and legible with first-pass art — feeding is a
skill+choice, the hunter searches honestly, clans diverge, dawn bites, the nemesis hook lands.

---

## WAVE 3 — The polish pass (the Steam-screenshot gate)

| Stream | Task | DoD / evidence |
|---|---|---|
| **H Render/Light** | Dirty-urban lighting: player follow-light (chiaroscuro), clock-driven intensity + sky gradient, streetlamp/headlight/police/neon/muzzle/feed lights (≥3 dynamic per scene), wet-asphalt reflections, bloom on highlights only (per memory `visual-night-legibility`). | Grimy street reads "moody" not "broken"; capsule-quality screenshot. |
| **I UI/UX** | Predator-Minimal HUD using real `art/ui` pieces (vitae/blood/hunger/heat/humanity + hotbar from `meta.slot_power`); interact prompts; Occult-Dossier menu skin; text scale + high-contrast. | Purpose obvious in 2s; controller + KB/M; no dev labels. |
| **J Audio** | Adaptive ambient→combat→chase→dawn stem cross-fade driven by CueBus tension; feeding heartbeat; offscreen hunter footsteps (positional); heat stingers; full cue table + captions. | Hearing an offscreen hunter is reliably reactable; every beat has audio on the right bus. |
| **K Narrative** | Opening hook line; sire/herald/nemesis framing; 3–5 NPC barks; one banner per humanity step; dawn recap as a *moment*. | A blind playtester names the hook after 30s. |
| **D Feel** | Post-FX: heat-pulse tiers, feed letterbox/frame, frenzy pulse, dawn color-grade; reduced-motion variants for all. | One coordinated cue per event; reduced-motion completable. |
| **M QA** | The slice skill-gap benchmark (expert beats masher ≥30% time / ≥50% hits, same seed); 5 clean runs; accessibility pass; evidence bundle. | All `FIRST_HUNT_SLICE_PLAN §4` boxes checked. |

**Wave 3 gate = the merge gate:** The First Hunt is shippable as a demo. *Only then* does Phase 2 open.

---

## Roles → streams (the team-of-agents map)

- **A Director (me):** contracts (schemas/DoDs), review, integration, taste, the cut-list as a contract.
- **B Technical Director:** determinism gate, save/load, CueBus, CI, the boot-clean + grep gates.
- **C Gameplay / G World:** the authored night, dawn pressure, level block, beat triggers.
- **D Feel Engineer:** hitstop/shake/particles/post-FX/<100ms feedback.
- **E Feeding Designer:** gulp, resonance, humanity-as-lived-state.
- **F Stealth/AI Engineer:** perception, search diversity, property tests, keystone-AI interplay.
- **H Render/Art Director:** style guide, sprite pipeline, lighting.
- **I UI/UX Lead:** HUD, menus, accessibility, controller.
- **J Audio Director:** bus graph, cue table, adaptive stems, captions.
- **K Narrative:** hooks, barks, banners, recap.
- **L Systems/Progression:** clan keystone runtime, what's surfaced vs quarantined.
- **M QA/Automation:** GUT, property tests, render-smoke, evidence bundles, the skill-gap benchmark.
- **N Steam/Product:** demo scope, trailer beat, store assets (Milestone 7).

## Before acting on a matrix row: re-verify it against source

The archaeology readers were fast and broad but made ≥2 verifiable errors (they claimed hitstop and
lifesteal were unapplied — both are applied in `Sim.damage_entity`; they called `resolve_dawn` "dead
code" — it's called at `SimMeta.gd:217`). **Any workstream that picks up a `LEGACY_PORT_MATRIX.md` row
as a work item must first re-confirm that specific claim against the current code.** Treat the matrix
as a high-quality lead list, not ground truth. The same CI/approved-machine capture + bounded local
GUT discipline that found the New Game hang applies to every claim before you build on it.

## Handoff contract (every agent PR)

Files changed · reason (which gap/DoD it closes) · tests run + result · evidence (screenshot/clip/GUT)
· remaining risk · what it unblocks. Leave the repo cleaner than found; delete or quarantine stale code;
never leave a half-wired system silent — wire it, isolate it, or mark it.
