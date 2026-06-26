# Cinematic upgrade handoff and wiring specification

## Zero-extra-wiring path

The overlay intentionally replaces files at paths that are already preloaded by the game:

- `GameRenderer.gd` already preloads `res://src/present/EntityRenderer.gd`.
- `GameRenderer.gd` already preloads `res://src/present/WorldFX.gd`.
- `Sim.gd` already preloads `res://src/entities/SimProjectile.gd`.
- `test/CaptureSlice.tscn` already points at `res://test/CaptureSlice.gd`.

Therefore installing the overlay wires the core upgrade automatically. Do **not** rewrite `GameRenderer.gd`, `Sim.gd`, Boot, scenes, input, HUD, or the deterministic backend to make this work.

## Files and responsibilities

### `src/present/EntityRenderer.gd`

Read-only presentation of all `SimEntity` instances. It:

- interpolates visual positions without writing back to `e.pos`,
- derives locomotion phase from actual displacement,
- derives attacks from `current_action`, `action_frame`, and `ActionDef`,
- derives hit and dash accents from CueBus,
- renders humanoid joint meshes, clothing, armor, weapons, status, downed/dead states,
- renders straight and ballistic projectiles,
- preserves vehicles.

Do not add authoritative damage, collision, cooldown, or AI decisions here.

### `src/present/WorldFX.gd`

Read-only transient world effects. It uses bounded arrays rather than creating hundreds of short-lived nodes. New effects should be added by semantic cue ID.

Do not call simulation mutation from this file.

### `src/entities/SimProjectile.gd`

Authoritative deterministic projectile behavior. Existing callers do not change because ballistic behavior defaults to off. New thrown objects opt in through spawn options.

Any added ballistic variable must also be added to `state_hash()`.

## Adding a playable flask/potion power

The physics system is fully implemented, but the overlay does not silently rewrite the player’s progression or hotbar. To expose a production flask:

1. Add a canonical power or consumable definition, for example `alc_volatile_flask`, to the existing data catalog.
2. In `SimPlayer.cast_power`, add a match branch that calls `sim.spawn_projectile()` with the options shown in `CINEMATIC_GRAPHICS_RESEARCH.md`.
3. Use `entity.facing` or the current aim vector for horizontal direction.
4. Put resource cost/cooldown in the existing catalog, not in the renderer.
5. Teach/bind the power through `SimMeta`, inventory, or alchemy as appropriate.
6. Add a unit test proving cost, cooldown, deterministic flight, AoE, status, heat/witness behavior, and save/restore.
7. Add a CueBus caption/audio definition for accessibility.

The capture harness invokes the API directly only to prove the physics and rendering path; it does not grant the player a debug power in normal play.

## Optional authored-skin migration

Agents may replace the procedural surfaces with `Skeleton2D`/weighted polygons later. Preserve this interface:

- root visual position,
- facing,
- joint vocabulary,
- action envelope,
- equipment tag,
- faction/type profile,
- status/downed/dead state.

A future renderer should be selectable behind a project setting, for example:

```ini
[presentation]
character_renderer="procedural_2_5d"
```

Do not remove the procedural fallback until every faction, weapon, action, and status has parity.

## Verification commands

```bash
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gexit
godot --path . --rendering-method gl_compatibility res://test/CaptureSlice.tscn
```

Inspect:

- `docs/evidence/01_cinematic_idle.png`
- `docs/evidence/02_cinematic_run.png`
- `docs/evidence/03_cinematic_attack_startup.png`
- `docs/evidence/04_cinematic_attack_active.png`
- `docs/evidence/05_cinematic_power.png`
- `docs/evidence/06_ballistic_arc.png`
- `docs/evidence/07_ballistic_impact.png`
- `docs/evidence/08_camera_follow.png`

## Required follow-up if CI fails

1. Fix syntax/import errors before adjusting visuals.
2. Preserve old projectile behavior when `ballistic == false`.
3. Never remove state-hash fields to make determinism tests pass.
4. If performance is low, reduce FX particle caps or high-detail entity cap before deleting animation states.
5. If a faction reads poorly, change its palette/profile and weapon silhouette rather than adding floating UI symbols.
6. Commit captured screenshots with the exact Godot build and GPU noted in the PR description.

## PR description template

**Scope:** replaces presentation-only character and world FX renderers; extends deterministic projectiles with opt-in ballistic height/gravity/bounce.

**Architecture preserved:** Sim authoritative, fixed 60 Hz, no scene migration, no backend deletion.

**Evidence:** link eight captured frames, GUT count, determinism result, reference hardware FPS, and a 60-actor stress result.

**Known limitations:** procedural materials are a bridge to authored skins; no normal-map asset pipeline included; production flask is not silently inserted into progression.
