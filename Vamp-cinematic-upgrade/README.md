# Vampire City — Cinematic Character / Physics Presentation Upgrade

This is a **safe overlay package** for `coldshalamov/Vamp`. It is designed for the current Godot 4.7 project and preserves the project’s deterministic authority boundary:

- `Sim` remains authoritative and fixed-step.
- Rendering remains a read-only view of `SimEntity` state.
- Existing scenes and `GameRenderer.gd` wiring remain intact.
- No engine migration, no scene-tree rewrite, and no replacement of backend systems.

## What changes immediately

1. **All humanoids stop being circle assemblies.** `EntityRenderer.gd` becomes a continuous procedural 2.5D mesh rig: projected joints, faceted limbs, layered clothing, faction silhouettes, weapons, hit reactions, action-frame posing, contact shadows, dash ghosts, downed poses, and corpses.
2. **Animation has no frame-count ceiling.** Poses are continuous functions of velocity, facing, `ActionDef` startup/active/recovery, hitstop, knockback, AI state, and CueBus events.
3. **Combat effects become materially richer.** `WorldFX.gd` adds bounded procedural slash ribbons, impacts, blood spray, sparks, smoke, embers, shockwaves, discipline-specific casts, and explosion effects.
4. **Projectiles gain a real ballistic channel.** `SimProjectile.gd` supports height, vertical velocity, gravity, bounce, friction, fuse, collision height, spin, AoE, status, and fire-surface ignition while keeping the ground-plane simulation deterministic.
5. **Verification is reproducible.** The capture harness now records idle, run, attack startup/active, power, ballistic arc, impact, and camera follow. A GUT regression file checks ballistic determinism and AoE. A GitHub Actions workflow runs tests and uploads screenshots.

## Install

From the extracted package:

```bash
python install.py /path/to/Vamp --git-branch cinematic-graphics-upgrade
```

On Windows PowerShell:

```powershell
py .\install.py C:\path\to\Vamp --git-branch cinematic-graphics-upgrade
```

The installer verifies the project, creates a timestamped backup inside the repo, optionally creates a Git branch, and copies only the overlay files.

To install without creating a branch:

```bash
python install.py /path/to/Vamp
```

## Verify locally

Use the same Godot 4.7 binary as the project:

```bash
Godot_v4.7-stable_win64.exe --headless --path . --import
Godot_v4.7-stable_win64.exe --headless --path . -s res://addons/gut/gut_cmdln.gd -gexit
Godot_v4.7-stable_win64.exe --path . res://test/CaptureSlice.tscn
```

Captured PNGs are written to `docs/evidence/`.

## Files replaced

- `src/present/EntityRenderer.gd`
- `src/present/WorldFX.gd`
- `src/entities/SimProjectile.gd`
- `test/CaptureSlice.gd`

## Files added

- `test/unit/test_ballistic_projectile.gd`
- `.github/workflows/visual-proof.yml`
- `docs/CINEMATIC_GRAPHICS_RESEARCH.md`
- `docs/CINEMATIC_UPGRADE_HANDOFF.md`
- `docs/evidence/rig_preview_v1.png`
- `docs/evidence/rig_preview_v2.png`
- `docs/evidence/rig_preview_comparison.png`

## Important honesty note

The package was statically checked and built against the current repository file interfaces. This execution environment did not contain a Godot binary and could not clone GitHub over raw networking, so the live Godot capture and GUT suite were not executed here. The included workflow and capture scene are the verification gate; do not merge until they pass. The two included rig previews are design iterations, not claimed runtime screenshots.
