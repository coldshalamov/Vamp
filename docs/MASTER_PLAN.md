# MASTER_PLAN.md — synthesized from the 30-agent studio brainstorm

> Source: 10 teams × 3 personas = 30 specialists, 1,829 ideas brainstormed, top-5-per-agent = 150
> ideas synthesized here. Heavy convergence (the same load-bearing ideas surfaced across many teams)
> drove the dedup below — each feature merges the best concrete details from every agent that proposed
> it. Number in `[×N]` = how many independent agents converged on it (a confidence signal).
> Everything ships on `master`. Verification gate per feature: GUT green + windowed capture + clean boot.

## Already done (do NOT re-implement — several agents proposed these; they're live)
CueBus merge-define fix (camera shake restored) `[×6]` • player follow-light • wired environment
textures • generated top-down sprites • Cinzel/Oswald/ShareTechMono fonts • NIGHT SHIFT main menu •
NIGHT SHIFT HUD (textured bars/fangs/stars/slot art + sliced discipline icons) • full i18n • billboard
props • blood projectile • New Game hang fix • Settings tabs fix • screen-leak fix.

---

## WAVE 1 — Slice-critical mechanics (the gameplay gaps; highest convergence; core-file, serialized)

1. **Gulp timing window** `[×15]` — feeding becomes a skill. On `feed.gulp`, open a timing window
   (shrinks with hunger/magnitude); input quality → vitae multiplier (perfect +25-30%, miss −20-50%)
   + brief slowmo on perfect; mastery.predation widens the window. *Files:* `SimPlayer.gd` (_tick_feeding),
   `InputAction`, `VisualFX.gd` (shrinking ring), `HUD.gd`. *DoD:* scripted good-gulp vs bad-gulp differ
   measurably in vitae+heat; expert>masher at feeding.
2. **Resonance auras + feed buffs** `[×11]` — victims carry a humour (sanguine/choleric/melancholic/
   phlegmatic); Auspex (or proximity) reveals a colored aura; feeding applies a 30-60s clan-synergistic
   buff + vitae multiplier. *Files:* `SimNPC.gd` (humour field), `SimPlayer.gd` (_finish_feed buff),
   `EntityRenderer.gd`/`LightingDirector.gd` (aura), `GameCatalog.gd`. *DoD:* victim choice measurably
   changes outcome; aura readable pre-grab.
3. **Humanity → world cascade** `[×12]` — add a humanity term to `_compute_exposure`; on a lethal drop:
   pedestrian flinch/flee, screen desaturate/cool (CameraDirector/VisualFX), one banner, NPC barks,
   (stretch) merchant price +. *Files:* `SimPlayer.gd`, `SimNPC.gd`, `VisualFX.gd`, `CameraDirector.gd`,
   `HUD.gd`. *DoD:* a drop visibly changes the world within 1s.
4. **Clan keystone runtime wiring (3 slice clans)** `[×10]` — Brujah Blood Rage (toggle frenzy, costs
   vitae, +dmg/−defense), Nosferatu One-With-Shadow (stealth-kill chains/extends cloak), Tremere Vitae
   Alchemy (damage refunds blood / cost from HP). HUD keystone badge. *Files:* `SimPlayer.gd`,
   `SimMeta.gd`, `HUD.gd`, new `test_slice_keystones.gd`. *DoD:* the 3 clans solve the forced fight
   visibly differently.
5. **Continuous dawn pressure** `[×12]` — replace the one-shot with over-time sun exposure in the last
   minutes; countdown HUD; sky color lerp; dawn vignette; humanity scales final damage. *Files:*
   `SimMeta.gd` (resolve_dawn → tick), `Sim.gd`, `LightingDirector.gd`, `HUD.gd`, `VisualFX.gd`. *DoD:*
   a night can end in torpor from one feed too many.

## WAVE 2 — Combat feel & juice (mostly core-file; serialized w/ Wave 1)

6. **Combat grammar depth** `[×6]` — input buffering (3-6f), on-hit advantage (+2f attacker), whiff-punish
   (+recovery on miss), dash-cancel windows on all powers. *Files:* `SimPlayer.gd`, `ActionState.gd`,
   `Sim.gd`, `test_skill_gap.gd`.
7. **Flank bonus** `[×2]` — +50% dmg / +crit hitting within 60° behind target. *Files:* `Sim.gd` damage_entity.
8. **Readability telegraphs** `[×5]` — startup-frame outline pulse, dash i-frame flicker, enemy windup
   snap, hitstop scaling by damage, damage-number punch. *Files:* `EntityRenderer.gd`, `VisualFX.gd`, `Sim.gd`.
9. **VFX juice pack** `[×8]` — feed vignette (heartbeat throb), sun-dust death dissolve, blood splatter
   decals, hit sparks, NPC flinch anim, dash trail. *Files:* `VisualFX.gd`, new particle/`art/shaders/`,
   `WorldRenderer.gd`, `EntityRenderer.gd`.

## WAVE 3 — AI / Stealth / Living City (SimNPC-centric; parallel-friendly vs Waves 1-2 core)

10. **Vision cones + perception markers** `[×4]` — facing-gated sight for hostiles; `!`/`?` state markers.
    *Files:* `SimNPC.gd`, `EntityRenderer.gd`, `CueBus.gd`.
11. **AI search diversity + property test** `[×8]` — spiral/sweep/quadrant strategies (seed-picked,
    deterministic); property test (≥3 behaviors, ≥95% lose-LOS / 100 seeds). *Files:* `SimNPC.gd`, new
    `test_ai_search_diversity.gd`.
12. **Auditory perception** `[×3]` — gunfire/power/sprint emit noise cues → NPCs investigate; sneaking is
    silent (stealth/speed tradeoff). *Files:* `SimNPC.gd`, `SimPlayer.gd`, `Sim.gd`, `CueBus.gd`.
13. **Heat readability** `[×6]` — ambient hue by heat, last-known-pos shrinking ring, heat-star pulse,
    witness icon+sting, witness heat scales by rank. *Files:* `LightingDirector.gd`, `HUD.gd`,
    `WorldRenderer.gd`/overlay, `Sim.gd`, `VisualFX.gd`.
14. **Nemesis scarring + barks** `[×3]` — scar by damage type, return leitmotif/bark. *Files:* `SimMeta.gd`,
    `EntityRenderer.gd`, `CueBus.gd`, `CaptionOverlay.gd`.

## WAVE 4 — Audio from zero (independent subsystem; parallel-safe)

15. **AudioServer bus graph + CueBus._play_audio bridge** `[×5]` — Master/Music/SFX/Voice/Ambient/UI +
    ducking. *Files:* new `AudioDirector.gd`, `CueBus.gd`, `default_bus_layout.tres`, `SettingsMenu.gd`.
16. **Feeding heartbeat** `[×5]` — procedural, hunger-scaled BPM/intensity. *Files:* `AudioDirector.gd`,
    `CueBus.gd`, `SimPlayer.gd`.
17. **Core SFX + stings** `[×4]` — hit/feed/power/UI one-shots, masquerade siren, humanity.lost lowpass
    swell. *Files:* `AudioDirector.gd`, `CueBus.gd`, `audio/`.
18. **Adaptive music stems + clan leitmotifs** `[×3]` — exploration/combat/chase/dawn, tension-driven.
    *Files:* `AudioDirector.gd`, `audio/stems/`. *(heavier; may be partial)*
19. **Positional footsteps + sound radar + captions** `[×4]` — offscreen hunter steps, deaf-accessible
    bearing arc, caption overlay. *Files:* `AudioDirector.gd`, new `SoundRadar.gd`, `CaptionOverlay.gd`.

## WAVE 5 — World / Level / Art polish (parallel-safe; level + render)

20. **Forced-fight geometry + multi-route + patrol waypoints** `[×3]` — author `load_vertical_slice` into
    3-path encounter + alley LOS-break + herald patrol. *Files:* `SimWorld.gd`, `SimNPC.gd`.
21. **Persistence decals** `[×4]` — corpse persistence, blood splatter, witness flight trails, clan graffiti.
    *Files:* `WorldRenderer.gd`, `EntityRenderer.gd`, `PropRenderer.gd`, `SimWorld.gd`.
22. **Lighting depth** `[×6]` — dawn sky gradient, heat ambient glow, haven sanctuary glow, player-light
    scales w/ humanity+hunger, wall occluder shadows, neon bloom / post-FX. *Files:* `LightingDirector.gd`,
    `WorldRenderer.gd`, `art/shaders/`.
23. **Onboarding light path on wake** `[×1]` — diegetic trail to first objective. *Files:* `LightingDirector.gd`, `Boot.gd`.

## WAVE 6 — UI/UX & Accessibility (HUD-centric; coordinate with Wave 1 HUD)

24. **HUD deepening** `[×6]` — keystone badge, hunger danger-zone, lethal/spare badge, resonance target
    micro-banner, search-cone overlay. *Files:* `HUD.gd`, `EntityRenderer.gd`.
25. **Controller/Deck/a11y** `[×5]` — controller glyphs, Steam-Deck profiles, high-contrast HUD boost,
    sound radar. *Files:* `InputMap.gd`, `InputRemapPanel.gd`, `UITheme.gd`, `HUD.gd`, `art/ui/glyphs/`.
26. **Three-act night phase UI** `[×2]` — Early/Mid/Late banners + spawn/heat pacing. *Files:* `SimMeta.gd`,
    `HUD.gd`, `CueBus.gd`.

## WAVE 7 — Engineering / Tools (independent; parallel-safe)

27. **Full save/load + scene resync + test** `[×3]` — Boot persists full `SimMeta.serialize`, restores +
    re-syncs scene. *Files:* `SaveSystem.gd`, `Boot.gd`, `SimMeta.gd`, new `test_save_load_resync.gd`.
28. **CI: headless GUT (GitHub Actions, JUnit) + determinism gate** `[×3]`. *Files:* `.github/workflows/`.
29. **F-key sim-truth debug overlay** `[×1]` — tick/heat/hunger/exposure/LKP/LOS/paths/AI states.
    *Files:* new `DebugOverlay.gd`, `GameView.tscn`.
30. **Perf** `[×5]` — object pools, spatial hash, texture pre-cache, draw batching. *Files:* `Sim.gd`,
    `SimEntity.gd`, renderers. *(do after gameplay stabilizes)*
31. **Parametric CaptureSlice multi-clan evidence** `[×1]`. *Files:* `CaptureSlice.gd`.

## WAVE 8 — Progression / Meta / Replayability / Narrative content

32. **Keystones as economy converters + predator combos** `[×3]`. *Files:* `SimMeta.gd`, `SimPlayer.gd`.
33. **Loot depth** `[×5]` — resonance affinity on items, affix tiers, synergies, legendary on-hit procs,
    curses. *Files:* `SimMeta.gd` (generate_item/recompute), `GameCatalog.gd`, `Sim.gd`.
34. **Meta sinks & replay** `[×5]` — hunger-as-currency, haven coin sinks, legend boon market, bloodline
    prestige/NG+, difficulty modifiers. *Files:* `SimMeta.gd`, `Boot.gd`, new screens.
35. **Narrative content** `[×5]` — sire monologue, herald through-line (beats 1/4/5/8), dossier codex
    chapter, dawn recap moment, clan/nemesis barks. *Files:* `SimMeta.gd`, `CueBus.gd`, `CaptionOverlay.gd`,
    `GameCatalog.gd`.

---

## Execution model
- **Waves 1-2 (slice-critical, core-file contention on SimPlayer/Sim/SimMeta/HUD/VisualFX):** implemented
  carefully and serialized (director-led or one-agent-per-cluster) — these are taste-critical and conflict-heavy.
- **Waves 3-8 (more independent subsystems):** fanned out to parallel implementation agents, merged to
  master, each iterated 1-3× based on review quality.
- Every feature: GUT green + windowed capture + clean boot before commit. Determinism gate held when
  touching authoritative sim. Final director pass reconciles incongruities across all merged work.
