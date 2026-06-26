# Visual Revamp — Integration Status & Handoff (2026-06-24)

A prior agent produced a **character-rendering overhaul** for Vampire City: an authored,
light-reactive atlas pipeline (`CharacterAtlas2D.gd`) that replaces the procedural
`CharacterRig2D.gd` stick-figures (the "giant asparagus people"). The art is excellent and
unambiguously this game (see `docs/evidence/visual_revamp/visual_revamp_contact_sheet.jpg`:
10 archetypes — hero/thug/gunner/cop/swat/hunter/elder/thrall/civilian/rat — across
idle→walk→anticipate→strike→follow-through→hit→feed→downed→corpse, plus sedan/cruiser/blood).

This document records what was delivered, what was integrated, and **the one thing missing that
blocks going live.**

## Classification of the downloaded files (by content, not download order)

| File | Verdict | Disposition |
|---|---|---|
| `CharacterAtlas2D.gd` | Vampire City (new atlas renderer) | Staged → `tools/visual/` (Godot-ignored; see below) |
| `generate_visual_atlas.py` | Vampire City (one pipeline stage) | Staged → `tools/visual/` — **incomplete, see blocker** |
| `VISUAL_REVAMP_REPORT.md` | Vampire City | Installed → `docs/VISUAL_REVAMP_REPORT.md` |
| `AGENT_VISUAL_REVAMP_GUIDE.md` | Vampire City | Installed → `docs/AGENT_VISUAL_REVAMP_GUIDE.md` |
| `SKILL.md` (`vamp-visual-revamp`) | Vampire City (the skill you asked for) | Installed → `.claude/skills/vamp-visual-revamp/SKILL.md` |
| `asset_metrics.json` | Vampire City | Installed → `docs/evidence/visual_revamp/` |
| `visual_revamp_contact_sheet.jpg` | Vampire City (review art) | Installed → `docs/evidence/visual_revamp/` |
| `hero_material_breakdown.jpg` | Vampire City (review art) | Installed → `docs/evidence/visual_revamp/` |
| `ART_PIPELINE_HANDOFF.md` | Vampire City (earlier graphics handoff) | **Already in repo / superseded by the report** |
| `GRAPHICS_PHYSICS_RESEARCH_2026.md` | Vampire City (research) | Already-covered infra batch |
| `CaptureGraphicsPass.gd` | Vampire City | **Already in repo** (`test/CaptureGraphicsPass.gd`) |
| `verify_visual_capture.py` | Vampire City | **Already in repo** (`test/verify_visual_capture.py`) |
| `visual.yml` | Vampire City (CI "Visual evidence") | **Already in repo** (`.github/workflows/visual.yml`) |
| `capture_stream.py`, `capture_segments.py`, `capture_all_streams.py`, `capture_visible.py` | **NEITHER GAME** — Playwright movie-stream scrapers (2embed/vsembed). | **Excluded — do not add to this repo** |

## What is integrated now (safe, committed)

- The reusable skill `vamp-visual-revamp` is installed.
- The report + guide are in `docs/`; the contact sheet, hero material breakdown, and validated
  metrics are in `docs/evidence/visual_revamp/`.
- `CharacterAtlas2D.gd` and `generate_visual_atlas.py` are version-controlled under `tools/visual/`,
  which carries a `.gdignore` so Godot does **not** parse the renderer (its `preload(...)` of
  not-yet-present `.tres` materials would otherwise break boot). Boot stays clean (verified).

## ⛔ BLOCKER — the headline overhaul cannot go live yet

`CharacterAtlas2D.gd` preloads `res://assets/visual/materials/characters/{hero,thug,…}.tres`.
**Those generated assets, and most of the generation pipeline, are NOT in the downloads, the repo,
any local/remote branch, or anywhere on disk.** Specifically missing:

1. **`assets/visual/` — the 49 generated production files** (per `asset_metrics.json`): the 10
   character `CanvasTexture` `.tres` + diffuse/normal/specular atlas PNGs, 2 vehicle materials,
   4 blood decals. **This is the critical missing piece.** Without it the renderer draws magenta
   error-polygons — worse than the current rigs.
2. **The rest of `tools/visual/`**: `visual_asset_core.py` (the SVG/atlas builder that
   `generate_visual_atlas.py` imports — without it the generator won't even run),
   `rasterize_visual_assets.py`, `validate_visual_assets.py`, `render_visual_contact_sheet.py`,
   `requirements.txt`.
3. **Inkscape** (the rasterizer dependency) — not installed on this machine.

## To complete the overhaul (once the missing pieces are provided)

Preferred path — **provide the generated `assets/visual/` folder** (the 49 files the prior agent
already made and validated). Then:

1. Move `assets/visual/` into the repo at `res://assets/visual/`.
2. Move `tools/visual/CharacterAtlas2D.gd` → `src/present/CharacterAtlas2D.gd`.
3. Wire the live path: in `src/present/EntityRenderer.gd`, replace
   `preload("res://src/present/CharacterRig2D.gd")` with `CharacterAtlas2D.gd` (the report says it
   exposes the same setup/physics_sync/advance_visual/notify_event/set_detail_level contract).
4. Add `test/unit/test_visual_assets.gd` (imports every `CanvasTexture`, checks map dims).
5. On local Windows, use only the bounded `scripts/RunGutSafe.ps1` smoke wrapper; full boot/GUT and
   windowed `CapturePlay`/`CaptureGraphicsPass` captures belong in CI or on an explicitly approved
   machine. **Review the frames by eye** (the project's law: green tests do not prove the screen).

Alternate path — provide the full `tools/visual/` pipeline + install Inkscape, then run the four
generator commands in `docs/AGENT_VISUAL_REVAMP_GUIDE.md` §9 to regenerate `assets/visual/`, and
proceed from step 2.

**Where to find the missing files:** they live wherever the prior visual-revamp agent ran (its
session/worktree/cloud environment). Retrieve `assets/visual/` (and ideally the full
`tools/visual/`) from there.
