# GODOT_WIRING_AUDIT.md — what is wired, half-wired, orphaned, or dangerous

> Code-truth wiring map of the Godot 4.7 project. Severity-ordered. Every claim cites `file:line`.
> Items marked **✔ verified** were re-checked by hand against primary source during this audit
> (some correct earlier-agent errors). Companion: `CURRENT_STATE.md`, `RISK_REGISTER.md`.

## Architecture verdict

The contract holds. `Sim` (autoload) is authoritative; `src/sim/` + `src/entities/` are deterministic
(LCG `Sim.rng`, **zero** `randf/randi/Time.*` — grep-clean ✔); the scene tree reads Sim and never
mutates it (`test_hud_binding`, `test_ui_flow` prove UI is read-only). `CueBus` is the semantic
seam between sim and presentation. This is a genuinely sound, testable foundation. The defects below
are **wiring and content gaps in the presentation/UX layer**, not architectural rot.

---

## P0 — Dangerous / breaks a feature silently (fix first)

### 1. CueBus `define()` clobber — camera shake lost on 3 beats ✔ verified
- `CueBus.define()` is **full-replace**: `_cue_defs[event_id] = cue` (`CueBus.gd:44`). The intended
  design is **one def per event carrying all modality keys** (`camera`+`audio`+`vfx`+`hud`, see the
  comment block `CueBus.gd:29-31`).
- `CameraDirector._register_cues()` defines `hit.connect`, `frenzy.start`, `masquerade.broken` with a
  `camera` callable (`CameraDirector.gd:31-54`).
- `VisualFX._register_cues()` defines the **same three** events with a `vfx`-only callable and **no
  `camera` key** (`VisualFX.gd:35,43,51`).
- `GameRenderer._ready()` adds CameraDirector (`:49-51`) **before** VisualFX (`:53-55`), so VisualFX's
  `_ready()` runs last and overwrites. At emit time, `emit_cue` only calls `def["camera"]` *if present*
  (`CueBus.gd:60`) — it isn't → **no shake/push-in on hit, frenzy, or masquerade break**.
- Events that still get camera (no VisualFX collision): `pounce.hit`, `finisher.start`, `heat.rise`.
- **Fix options:** (A) make `define()` *merge* modality keys instead of replacing (best — matches the
  one-def-per-event design); (B) give each system distinct event IDs; (C) reorder `add_child`. Recommend
  **(A)**. This is a ~10-line change in `CueBus.gd` + a regression test asserting a def retains all keys.

### 2. Missing `art/icon.png` — boot error every launch ✔ verified
- `project.godot:24` `config/icon="res://art/icon.png"`; the file does not exist (`art/ui/icon_placeholder.png`
  does). Trivial: create `art/icon.png` or repoint config. Add to a boot-clean test.

### 3. Audio + caption are silent no-op stubs ✔ verified
- `CueBus._play_audio()` (`CueBus.gd:81-84`) and `_show_caption()` (`:86-88`) are empty `pass`. Any
  cue carrying an `audio`/`caption` key **fails silently** — no error, no sound. There is **no
  AudioServer bus graph** (Master only) and **zero audio files** (`audio/` empty). The game is mute.
- This is a P0 for *shippability* but architecturally trivial to start (the seam exists).

---

## P1 — Half-wired (works partly; blocks a slice beat)

### 4. Save/load persists only seed + clan
- `Boot._on_save_game()` (`scenes/Boot.gd:70-77`) writes `{seed, clan, tick}` only. The full
  `SimMeta.serialize()`/`restore()` exists and round-trips in `test_backend_port_systems` (~:100-113),
  but Boot never calls it, and nothing re-syncs the scene tree after load. Slice DoD "save/load works"
  is **not** met by the menu path.

### 5. Clan keystones — rule changes not hooked to runtime
- Static-mod keystones work (e.g. `bs_key` cost-halving, `SimMeta.effective_power_cost():405-407`).
  Rule-changing keystones are **declared but unreachable from gameplay**:
  - `cel_key` Perfect Predator (reset all CDs on spare) — not in the `feed.spare` handler.
  - `pot_key` Blood Rage (frenzy toggle) — no input/toggle state.
  - `aus_key` Voices Know (20% free random power) — no proc in cast resolution.
  - `obf_key` One With Shadow, `pro_key` Wild Hunt stacks, `bs_key` HP-bleed half — all spec-only.
- **Slice impact:** the slice requires "use a clan keystone (mechanically necessary)". The 3 chosen
  slice clans must have *working* keystones (see `FIRST_HUNT_SLICE_PLAN.md`).

### 6. SkillTree / Inventory / Shop screens — UI records intent, never calls backend
- `SkillTreeScreen` keystone picker stores `_keystones` intent but **never sends allocation** to
  `meta` (note at its line ~57); `KEYSTONE_PAIRS` are hardcoded and partly wrong (e.g. lists
  `cel_dash/cel_haste` instead of the real `cel_key/pot_key` conflict).
- `InventoryScreen` / `ShopScreen` use **hardcoded data**, not `meta.inventory`/`meta.money`; buttons
  not wired to `equip_item`/`buy_item`/`sell_item`.
- No `HavenScreen` exists though `upgrade_haven()` backend does.
- **Slice stance:** the slice should **hide** these menus (see CUT list), so this is P2 for the slice
  but P1 for Phase 2.

### 7. HUD hotbar hardcodes 4 powers
- `HUD.gd` shows 4 starter powers instead of reading `player.slots` / `meta.slot_power(i)`. Diverges
  from the real hotbar source; `test_hud_binding` doesn't validate slot interactivity.

### 8. Humanity never affects the world ✔ verified (stat-only)
- Humanity moves (`SimPlayer.gd:490-491,568-571,581`) and emits `humanity.lost`, but
  `_compute_exposure()` (`SimPlayer.gd:701-713`) has **no humanity term** (legacy `stealth.js:52-54`
  scaled exposure by tier). No pedestrian flinch, no screen state, no banners. DoD unmet.

### 9. Gulp is a cue with no skill ✔ verified
- `feed.gulp` cue is emitted with a magnitude (`SimPlayer.gd:547`) and VisualFX shows a "+N" number
  (`VisualFX.gd:199-202`), but `_tick_feeding` drains **linearly** — no timing window, no input, no
  vitae/slowmo coupling. Expert and masher feed identically.

### 10. Dawn is a one-shot, not a scramble ✔ verified (NOT dead code)
- `resolve_dawn()` **is** called from `meta.tick` (`SimMeta.gd:217`), rolls the day, pays income, and
  applies **one** sun hit (`38*(1-sunResist)`) iff the player isn't in a haven (`:1684-1686`), emitting
  `player.torpor` on death. Tested for day-roll (`test_backend_port_systems:95-99`). **Missing:**
  continuous over-time sun exposure, the "last-60-seconds" pressure, a dawn countdown UX, and humanity
  scaling. (Corrects the matrix row that called this "dead code".)

---

## P2 — Orphans / stubs / minor (clean up or quarantine)

- **Orphan:** `break_responder_locks` (`Sim.gd:361`) — never called. Remove or wire.
- **Orphan resources (partial):** only `data/powers/{dash,melee_light,melee_heavy}.tres` exist; the
  other 33 powers are dict-driven in `GameCatalog` and never resolve a `.tres`. Not "dead code" (the
  dicts are authoritative) but the `.tres` path is under-used and the spec's "every action is an
  ActionDef" is only true for melee. Decide: author `.tres` for slice powers, or formalize dicts.
- **Charge input grammar declared, not processed:** `ActionDef.input_grammar` includes `charge`
  (`ActionDef.gd:~42`) but `SimPlayer.apply_action` has no charge branch — charge powers cast instantly.
- **`on_damage_dealt` is a tracker, not a healer** — but lifesteal **is** applied separately in
  `Sim.damage_entity` (`:228-229`) ✔, so no functional bug; just a naming foot-gun.
- **Nemesis name gen:** `_roll_name` referenced; legacy 7-name pool not ported — verify it produces a
  name (`SimMeta` nemesis path).
- **Codex `killedKinds`** not marked on NPC death (only fed/power events) — partial codex.
- **Particles entirely absent** — `VisualFX` has floating text + flash only; ~40 legacy effect hooks
  have no target. (Content gap, tracked in slice plan.)
- **Lighting scaffold-only** — `LightingDirector` places static `world.lights`; no player follow-light,
  no clock-driven intensity, no emitter grid, no bloom config.
- **`CameraDirector` shake uses `Time.get_ticks_msec()`** (`:80,87`) — acceptable (view-layer, not
  authoritative) but note it breaks replay-of-presentation determinism; fine for single-player.
- **`VisualFX.set_time_scale` writes `Engine.time_scale`** (`:157`) — intentional hitstop; safe because
  Sim ticks on `FIXED_DT`, but it's a cross-layer touch worth a comment.

---

## What "all 38 green" does NOT prove (the test blind spots)

Rendering/animation/camera fidelity • audio • full save→load→scene-resync • AI search diversity
(no property test) • slice-level skill gap • accessibility transforms • gamepad round-trip • vehicle
save/load • day/night *visual* progression. These are the untested risks; see `RISK_REGISTER.md`.

## Recommended fix order (small, safe, high-leverage first)

1. `art/icon.png` (P0-2) — trivial, removes the only boot error.
2. CueBus merge-define + regression test (P0-1) — restores juice on 3 beats; ~10 lines.
3. Audio bus graph + `_play_audio` bridge + a handful of cues (P0-3) — ends the silence.
4. Save the full Sim from Boot + a load→resync smoke test (P1-4).
5. Then the slice-mechanic gaps (gulp, resonance, humanity-world, keystones, dawn pressure) per the
   slice plan — these are *content/feature* work, not bug-fixes, and belong to Milestone 3–4.
