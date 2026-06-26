# Verification report

## Completed in this build environment

- Static package integrity check: **PASS**
  - 5 GDScript files checked
  - 1,743 GDScript lines checked
  - balanced delimiters
  - required interfaces and features present
  - authoritative projectile file contains no `randf`, `randi`, wall-clock, or new RNG objects
  - every ballistic state variable is represented in `state_hash()`
  - Python installer/uninstaller compile and parse
  - manifest and preview assets verified
- Installer dry run against a mock Vampire City tree: **PASS**
- Installer copy with timestamped backup: **PASS**
- Uninstaller restore of overwritten files and removal of added files: **PASS**
- Original mock files restored byte-for-byte by marker check: **PASS**

## Not executable in this build environment

- Godot import/parser run
- GUT runtime suite
- Windowed gameplay capture
- GPU/FPS profiling

The environment had no Godot executable and raw network cloning/downloading was unavailable. The package therefore includes:

- a new ballistic GUT regression test,
- an expanded windowed capture harness,
- a GitHub Actions Xvfb workflow that runs the full suite and uploads screenshots.

Those runtime gates are mandatory before merge.

## Design preview status

`rig_preview_v1.png` and `rig_preview_v2.png` are two visual design iterations used to tune silhouette, scale, weapons, cloth planes, hit reaction, and dash ghosts. They are **not represented as screenshots produced by the final Godot overlay**.
