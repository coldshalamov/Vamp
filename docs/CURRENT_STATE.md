# CURRENT_STATE.md — Vampire City, evidence-based audit

> **Date:** 2026-06-23. **Method:** static read of every system + a windowed pixel-capture run +
> the full GUT suite executed headless. Anchored to **code truth**, not `REVAMP_SPEC.md` (which is
> pre-implementation aspiration and still references an abandoned TS+Pixi plan). 254 mechanics were
> mapped across 10 domains by parallel archaeologists; the highest-leverage claims were re-verified
> by hand against primary source. Companion docs: `LEGACY_PORT_MATRIX.md`, `GODOT_WIRING_AUDIT.md`,
> `FIRST_HUNT_SLICE_PLAN.md`, `RISK_REGISTER.md`, `CUT_OR_DELAY_LIST.md`, `STEAM_VALUE_AUDIT.md`,
> `AGENT_WORKSTREAM_PLAN.md`.

## TL;DR (the one paragraph that matters)

Vampire City is **not** the usual AI "100 systems at 60%" mess. It is the **inverse**: a deterministic,
unit-tested **backend at ~85%** (clans, powers, skill tree, economy, missions, domains, coterie, haven,
nemesis, events, mastery, loot — all ported into `SimMeta.gd` and green under GUT) sitting under a
**playable-but-felt layer at ~15%** (programmer-art circles on a black void, **zero audio**, no
particles, no authored night). The mechanical spine of the target slice — *feed → fight → heat → escape*
— **already exists, renders, and is deterministic-tested**. The work to a sellable slice is therefore
**convergence, not construction**: art, lighting legibility, combat juice, audio-from-zero, and the
*authored* night structure (gulp skill, resonance, humanity-changes-world, clan-keystone-necessity,
dawn pressure, nemesis tease). Freeze backend breadth; pour everything into one night that looks,
sounds, feels, and reads like a real game.

---

## 1. What currently RUNS (verified, first-hand)

| Check | Result | Evidence |
|---|---|---|
| Engine | Godot **4.7.stable** (`5b4e0cb0f`) present at `~/bin/Godot_v4.7-stable_win64.exe` | `--version` |
| Headless boot | `Boot.tscn` boots clean, **zero script/resource errors** | `--headless --quit-after 2` |
| Test suite | **38/38 GUT tests pass** in 8.9s, 291 asserts, 7 files | `gut_cmdln -gexit` |
| Windowed render | `GameView` renders a playable scene; **player moves, camera follows, power cast surfaces on-screen ("Quicken")**, 6 live entities, 31 cue events, HP 100, over 273 ticks | `test/CaptureSlice.tscn`, screenshots in `docs/evidence/` |
| Determinism | LCG RNG, all randomness via `Sim.rng`; **zero** `randf/randi/Time.*` in `src/sim` + `src/entities` | determinism cross-check + `test_determinism.gd` |

**Boot is genuinely clean except one real error:** `project.godot` points `config/icon` at
`res://art/icon.png`, which **does not exist** (`art/ui/icon_placeholder.png` does). Logged every launch.

The 38 tests cover: determinism (20-run identical hash + replay), the skill-gap (scripted expert takes
≥40% less damage than a masher on the same seed), the vertical-slice backend loop (feed/fight/heat/escape),
HUD↔Sim read-only binding, input capture + remap persistence, UI flow + pause, and a 23-test breadth
sweep of the meta systems (powers, tree, economy, haven, coterie, domains, missions, elite affixes,
projectiles, vehicles, day/night roll, save/restore, nemesis, events, mastery, codex, alchemy).

## 2. What is WIRED (real, working, integrated)

- **Deterministic Sim authority** (`Sim.gd` 882 ln) — fixed-step tick, seeded LCG, state hashing,
  input-as-intent recording/replay. The architecture contract (Sim authoritative, scene tree = view)
  is **upheld and lint-clean**. This is the project's crown jewel; do not disturb the contract.
- **Feeding spine** — grab → drain → **kill-vs-spare** decision (hold = lethal, release = spare),
  hunger 0–5, frenzy at hunger 5, blood-as-mana, body left unconscious vs dead, witness discovery →
  investigation → heat. (`SimPlayer.gd:506-627`, tested.)
- **Combat grammar** — `ActionDef` frame data (startup/active/recovery/cancel) for the **3 melee
  verbs** (light/heavy/dash) as `.tres`; cancel-window combo proven by `test_skill_gap`. **Hitstop is
  applied** (Sim.gd:210-213, both entities), **knockback** (216), **lifesteal** (228-229), crit,
  armor, front-armor, status effects (burn/bleed/poison/shock/weaken/mark/fear/stun), ward absorption.
- **Powers** — 36 ported in `GameCatalog` (exceeds the 12–15 slice target); 9 pre-taught at start;
  cooldown/cost/cast all wired and cue-emitting.
- **Heat / Masquerade** — witnessed-crime heat 0–6, **last-known-position responder spawning (not
  psychic)**, 6s provoke window, decay-when-hidden, star-tier responders, star-clear stand-down,
  escape check. (`Sim.gd:_update_heat`, tested.)
- **Nemesis loop** — flee → persist → return scarred with adaptive resist → rank up; serialize/reinject
  across save. (`SimMeta`, tested.) **The slice's ending hook is already in code.**
- **Perception AI** — `can_see_player` (LOS + exposure + faction + range), states
  wander/investigate/search/guard/follow/chase/attack/flee, A* pathfinding, body/witness alarms.
- **Progression** — 7 clans w/ boon+bane (mutual-exclusion keystones enforced), 74-node skill tree,
  17 derived stats from 6 aggregate sources, 3-currency economy (Vitae/Coin/Legend — sprawl already
  collapsed), loot rarity+affixes, inventory/equipment mod stacking. (tested.)
- **Meta world** — missions (8 types + modifiers), domains (claim/contest/tithe/raid), coterie
  (embrace/summon/jobs), haven (6 rooms), reputation (5 factions), legend caps, mastery (6 tracks),
  codex, trophies, alchemy, the radiant **event director**. All deterministic + autosaved + tested.
- **UI/Input** — `UIManager` screen stack + pause routing, HUD reads Sim read-only, `Rebind` input
  capture + 3 accessibility presets + ConfigFile persistence, settings round-trip. **`art/ui/` has
  real authored sprite pieces** (HP/vitae bars, hunger teeth, heat stars, slot bg).

## 3. What is HALF-WIRED (present but incomplete — the real backlog)

| System | What's there | What's missing | Slice-critical? |
|---|---|---|---|
| **Gulp mini-game** | `feed.gulp` cue + magnitude | no timing window, no skill→vitae/slowmo coupling — expert & masher feed identically | **Yes** — feeding skill pillar |
| **Resonance/humours** | victim *yields* ported | no humour type on victims, no Auspex aura read, no feed buffs | **Yes** — "who you feed on is a build choice" |
| **Humanity-changes-world** | stat moves on kill/spare, `humanity.lost` cue | no exposure scaling, no pedestrian flinch, no screen state, no banners | **Yes** — DoD: "changes world within 1s" |
| **Clan keystones (runtime)** | nodes + conflicts + static mods; `bs_key` cost-halving works | rule-changing keystones not hooked to actions: Perfect Predator (CD reset on spare), Blood Rage (frenzy toggle), Voices (random proc), etc. | **Yes** — slice requires keystone *necessity* |
| **Dawn pressure** | `resolve_dawn` rolls day, one-shot sun damage if not in haven (tested) | no *continuous* exposure scramble, no countdown UX, no humanity scaling | **Yes** — core vampire tension |
| **Presentation cues** | CueBus + CameraDirector + VisualFX | **clobber bug** (see §6) drops camera shake on hit/frenzy/masquerade; no particles; no post-FX (heat pulse, feed frame, dawn grade) | **Yes** — game feel |
| **Lighting** | `LightingDirector` scaffold, static world lights | no **player follow-light** (chiaroscuro), no dynamic intensity by clock, no emitter grid | **Yes** — the whole look |
| **Powers as ActionDef** | 3 melee `.tres`; 36 powers as dicts | the other 33 powers are stat-lookup dicts, not frame-data resources (acceptable, but no authored hitboxes) | Partial |
| **UI screens** | SkillTree/Inventory/Shop/Coterie have data plumbing | buttons not wired to backend (allocate/equip/buy); no HavenScreen; HUD hotbar hardcodes 4 powers | Slice can hide these |
| **Save/load** | round-trips full Sim *in tests* | `Boot._on_save_game` persists only **seed + clan**, not the live Sim; no scene re-sync test | **Yes** for slice DoD |
| **Audio** | CueBus `_play_audio` exists | **completely stubbed; zero audio files; no bus graph** | **Yes** — silent game |

## 4. Legacy strength MISSING/weak in Godot

- **Audio:** legacy had a full procedural WebAudio synth (tones, noise, adaptive music, heartbeat,
  ducking). Godot has **nothing**. (`legacy/js/core/audio.js` → `—`.)
- **Particles/VFX:** legacy `powervfx.js` had ~40 effect hooks (blood, sparks, dash trails, rune
  rings, afterimages); Godot has floating text + a flash overlay only.
- **Dynamic lighting:** legacy `lightworker.js` had an emitter grid + the **player vision bubble**
  (the chiaroscuro that made night legible — see memory `visual-night-legibility`). Godot lighting is
  scaffold-only.
- **Props / district art:** legacy had procedural lamps/trees/signs + a parallax skyline with lit
  windows. Godot renders a flat tile grid; **no props at all**.
- **Systemic surfaces:** legacy + spec want fire/blood/water/sun/electric as *interacting* surfaces.
  Godot has the `SimWorld.Surface` enum + tile colors but **zero gameplay** (fire doesn't spread, sun
  isn't lethal mid-night). *(Defer — Phase 2; see CUT list.)*
- **Sprite animation:** legacy animated idle/walk/attack/feed. Godot draws circles.

## 5. In Godot but NOT proven by tests or play

- **The entire present/render layer** — 0 of 38 tests touch rendering (headless can't). Verified only
  by the one windowed capture run in this audit. *(New harness `test/CaptureSlice.tscn` added.)*
- **Full save→quit→load→scene-resync** — backend hash round-trips, but no test loads a save into a
  live scene tree.
- **AI search diversity** — spec DoD wants ≥3 materially different hunter behaviors over 100 seeds;
  the search is currently linear-to-LKP. **No property test exists.**
- **Skill-gap in the *slice*** — `test_skill_gap` proves it for a melee dummy; the *slice* (12–18 min
  night) has no expert-vs-masher benchmark.
- **Audio, captions, gamepad round-trip, reduced-motion transforms** — all untested.

## 6. Duplicated / stale / orphaned / dangerous

(Full detail with `file:line` in `GODOT_WIRING_AUDIT.md`.) Headlines:
- **DANGEROUS — CueBus clobber:** `define()` is full-replace; CameraDirector and VisualFX both define
  `hit.connect` / `frenzy.start` / `masquerade.broken`, and VisualFX (loaded last) wins with vfx-only
  defs → **camera shake silently dropped on 3 combat/critical beats**. Verified.
- **BUG — missing `art/icon.png`** (boot error). Verified.
- **ORPHAN:** `break_responder_locks` (Sim.gd:361) never called.
- **Stat-only stub:** Humanity moves but never touches `_compute_exposure` (legacy did).
- **Audio + caption stubs** that *silently no-op* — any `emit_cue` with an audio key fails quietly.
- **Two agent-audit errors corrected by hand:** the combat archaeologist wrongly claimed hitstop is
  "never read" and lifesteal "doesn't heal" — both are applied in `Sim.damage_entity` (210-213,
  228-229). The world archaeologist wrongly called `resolve_dawn` "dead code" — it's called at
  SimMeta.gd:217. These corrections matter: combat and dawn are in **better** shape than the raw
  matrix rows suggest.
- **No true dead systems** in the meta layer — the breadth is intentional, not abandoned. The risk is
  the opposite: too much *un-surfaced* breadth competing for polish attention (see CUT list).

## 7–10

Highest-value path, what to cut, the slice definition, and the staged agent plan live in their own
docs: `FIRST_HUNT_SLICE_PLAN.md` (path + slice), `CUT_OR_DELAY_LIST.md` (cut/delay/forbid),
`AGENT_WORKSTREAM_PLAN.md` (parallel workstreams), `STEAM_VALUE_AUDIT.md` (product), `RISK_REGISTER.md`.

**One-line verdict:** the hard, un-fun-to-build part (a correct deterministic simulation) is *done and
proven*; the project is one disciplined convergence pass — art + audio + juice + an authored night —
away from a genuinely sellable vertical slice. That is a rare and strong position.
