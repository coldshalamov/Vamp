# RISK_REGISTER.md

> Severity = impact on shipping a compelling First Hunt slice. Likelihood = chance it bites if
> unaddressed. Both 1–5. **Score = S×L.** Ordered by score. Owners map to `AGENT_WORKSTREAM_PLAN.md`.

## Top risks

| # | Risk | S | L | Score | Mitigation | Owner |
|---|---|---|---|---|---|---|
| R1 | **No authored gameplay art.** Every actor is a colored circle; spec DoD "zero hero primitives" is 0% met. Art is the long-pole and the #1 "looks like a prototype" cause. | 5 | 5 | **25** | Direction chosen 2026-06-23: **Dirty Top-Down Urban Horror**. Pipeline: generate top-down framed sprites → chroma-key → atlas → `SpriteFrames`. Start with player + 4 slice actors only. NOTE: this diverges from the existing comic-noir concept JPGs (now menu/portrait art only), so the gameplay sprite set is net-new — watch consistency (R12). | H (Art) |
| R2 | **Silent game.** Audio is 100% stubbed; no bus graph, no files. References (Hotline/Hades/VtM) are *defined* by sound. | 5 | 5 | **25** | Build Master/Music/SFX/Voice/Ambient buses; bridge `CueBus._play_audio`→AudioServer; ship feeding heartbeat + hit/feed/power one-shots + 1 ambient stem + offscreen footsteps + captions. | J (Audio) |
| R3 | **The "slice" is a test-input script, not an authored night.** No beats, triggers, nemesis tease, or curated critical path. | 5 | 4 | **20** | Author `load_vertical_slice` into a real block with the 8 beats; trigger the herald nemesis; one banner per humanity step. | C/G (Gameplay) |
| R4 | **Game feel hollow:** CueBus clobber drops camera shake on hit/frenzy/masquerade; no particles; no post-FX; no player follow-light. | 4 | 5 | **20** | Fix clobber (merge-define); add particle pool (blood/spark/dash); player follow-light; heat-pulse/feed-frame/dawn-grade post-FX. | D/H (Feel/Render) |
| R5 | **Feeding has no skill or choice teeth.** Gulp is cue-only; resonance missing; humanity is a stat that doesn't change the world. The core verb is a pickup. | 5 | 4 | **20** | Implement gulp timing window; resonance type+aura+buff; humanity→exposure+NPC reaction+screen state+banner. | E (Feeding) |
| R6 | **Hunter AI feels scripted.** Search is linear-to-LKP; no property test for ≥3 behaviors; uncertainty cone missing. | 4 | 4 | **16** | Add seed-driven search branches (pursue/flank/give-up-ambush/call-allies); write the 100-seed property test; spreading search cone. | F (Stealth/AI) |
| R7 | **Clan keystones are inert at runtime.** Only `bs_key` cost-halving works; the slice requires keystone *necessity*. | 4 | 4 | **16** | Wire the 3 slice clans' keystones into action/feed/frenzy resolution; one encounter that demands each. | F/L (Systems) |
| R8 | **Present layer is untested.** 0/38 tests touch rendering; bugs hide where headless can't look (per memory `playtest-verify-real-dpr`). | 4 | 4 | **16** | Keep the windowed `CaptureSlice` harness in CI-as-evidence; add a render smoke + visual checks; real-hardware playtest is ground truth. | M (QA) |
| R9 | **Dawn pressure is a one-shot, not the night's arc.** No continuous exposure scramble or countdown UX. | 4 | 3 | **12** | Add over-time sun exposure after sunrise, a dawn countdown HUD, sky-gradient lerp, haven-shelter feedback. | C/G (Gameplay) |
| R10 | **Save/load only persists seed+clan from the menu;** no scene re-sync test. | 3 | 4 | **12** | Persist full `SimMeta.serialize()` from Boot; add save→load→scene-resync smoke test. | B (Tech) |
| R11 | **UI screens are intent-only** (allocate/equip/buy not wired). | 3 | 3 | **9** | Slice **hides** these (CUT list). Wire in Phase 2. | I (UI) |
| R12 | **Art-style drift / AI-art inconsistency** across a sprite set. | 4 | 2 | **8** | One style guide; every asset gets a consistency pass; limited palette; reject off-style. | H (Art) |
| R13 | **Scope creep back into backend breadth** (the feature-factory relapse). | 4 | 2 | **8** | The CUT list is a contract; no Phase-2 work until blind playtest passes. | A (Director) |
| R14 | **Determinism regression** when present-layer or new features touch sim paths. | 5 | 1 | **5** | Keep the grep gate (no `randf/randi/Time.*` in sim) + the 20-run hash test in CI on every push. | B (Tech) |
| R15 | **Performance unknown at scale** (no spatial hash; brute-force O(n²) combat loops). | 3 | 2 | **6** | Slice is tiny (64×40, ~6 entities) — fine now. Add uniform-grid spatial partition before Phase-2 city. | B (Tech) |

## Watch list (low now, real later)
- Systemic surfaces shipped as enum+tiles could *look* interactive but do nothing → player confusion.
  Either hide the surface tiles in the slice or wire the one or two that matter (sun patch for the
  nemesis dust-kill is the highest-ROI single interaction).
- `Engine.time_scale` hitstop (`VisualFX:157`) is global; if Phase-2 adds real-time multiplayer/replay
  of presentation it breaks. Fine for single-player.
- AI-art licensing/provenance for a commercial Steam release — confirm the generation path is
  commercially usable before committing the final art set.
