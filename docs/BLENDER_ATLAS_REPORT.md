# Blender 3D → 2D Character Atlas Pipeline — Implementation Report

## What changed

The character atlases are no longer procedural SVG vectors faked into a 2.5D look.
The hero (and the full humanoid roster) is now a **real Blender 3D render baked to
2D sprite atlases** — the "Dead Cells rotoscoped / Vampire-the-Masquerade
modern-gothic" target: a posed 3D model lit by a cold moonlight key and a warm
streetlamp rim, rendered to an 8-direction × 16-action grid with diffuse, normal,
and specular passes, then re-lit dynamically inside Godot's 2D light engine.

This replaces the flat vector silhouettes with grounded, material-believable
figures that actually respond to in-game lighting.

## Pipeline (all under `tools/visual/`)

| Stage | Tool | What it does |
|---|---|---|
| Render | `blender_render_atlas.py` | Headless `bpy`. Builds a parametric humanoid (Skin-modifier body on a vertex skeleton + Subdivision Surface + a lofted open-front coat + separate head/hood/helmet/mask/armor/weapon), poses the 16 semantic rows, rotates through 8 directions, and renders 3 passes/cell via material overrides. |
| Assemble | `assemble_atlas.py` | Pure PIL/numpy. Edge-dilates the diffuse, renormalizes + green-flips the normal map and forces a flat background, builds the material-keyed specular, and stitches the three atlas PNGs. |
| Validate | `validate_visual_assets.py` | Size-aware gate: dimensions/ratios, empty cells, stick/narrow silhouettes, baseline drift, normalized + flat-bg normals, `.tres` resolution, live-renderer wiring. Writes `asset_metrics.json`. |
| Evidence | `render_visual_contact_sheet.py` | Night-palette contact sheet + a normal-mapped relight panel ("verify lighting response by eye"). |

### Render passes (per cell)

- **Diffuse** — lit beauty (Filmic, medium-high contrast), figure-only alpha.
- **Normal** — camera-space surface normal via a `Vector Transform (World→Camera)`
  override material, encoded `N*0.5+0.5`, green-flipped for Godot (+Y up),
  renormalized after downscale, flat `(128,128,255)` outside the silhouette.
- **Specular** — per-object material-keyed grayscale (matte cloth / soft skin /
  glossy metal) via an `Object`-attribute override.

### Contract (new)

| Property | Value |
|---|---|
| Character cell | **192 × 256** RGBA (was 96 × 128) |
| Baseline | Y = **224** (feet), 7/8 of cell height |
| Diffuse atlas | 1536 × 4096 |
| Normal atlas | 768 × 2048 (half-res) |
| Specular atlas | 384 × 1024 (quarter-res) |
| Columns / rows | 8 directions (E…NE) × 16 semantic rows |

`CharacterAtlas2D.gd` now **derives cell size and baseline per-atlas from the bound
texture**, so 192×256 (Blender) and 96×128 (legacy SVG) atlases coexist during the
roster rollout — no flag-day migration required.

## Integration

- `src/present/EntityRenderer.gd` was restored to the **atlas-based** renderer
  (it instantiates a `CharacterAtlas2D` per humanoid). The cinematic-overlay
  version had dropped the `physics_sync` contract `GameRenderer` calls every
  frame and orphaned the atlas — that is why the live path was rendering broken.
- The Blender sprites are **figure-only** (no baked ground shadow, which would
  smear across the cell and pollute the normal pass); `CharacterAtlas2D` draws a
  tight contact shadow in-engine instead.
- Hero is proven live in `GameView` via `CapturePlay` (see `docs/evidence/play_*`).

## Reproduction

```bash
# render one archetype (headless Blender, CPU Cycles)
blender --background --python tools/visual/blender_render_atlas.py -- \
    --archetype hero --out <cells_dir> --cell 192x256 --samples 28
# assemble -> assets/visual/atlases/<arche>_{diffuse,normal,specular}.png
python tools/visual/assemble_atlas.py --archetype hero --cells <cells_dir>
# validate + evidence
python tools/visual/validate_visual_assets.py --json-out docs/evidence/visual_revamp/asset_metrics.json
python tools/visual/render_visual_contact_sheet.py --archetypes hero
# safe tests
powershell -ExecutionPolicy Bypass -File .\scripts\RunGutSafe.ps1 -Select test_visual_assets
```

## Performance

- The atlas is **one textured quad per actor** (plus small semantic overlays) —
  strictly cheaper than the procedural renderer's many primitives per actor.
- Atlas textures import with **mipmaps + VRAM (BC) compression** (normal maps use
  the normal-aware mode). This cuts the texture-memory budget dramatically vs the
  old uncompressed estimate and gives clean minified sampling.
- The windowed stress gate (`CaptureGraphicsPass`, ~40 actors + projectiles + FX,
  1280×720, gl_compatibility) measured 11.4 FPS while the machine was thermally
  loaded from the multi-hour CPU render session, recovering to 14.4 FPS after a
  short cooldown — an upward trend consistent with **thermal throttling** of the
  shared-die Intel iGPU, not a fixed draw cost.
- Diagnostic: enabling mipmaps and then VRAM compression each moved FPS by < 1 —
  i.e. the atlas textures are **not** the bottleneck. The render path matches the
  project's prior **~26 FPS** GL-compat baseline (the `gl-compat-render-perf` notes
  already flag this iGPU as hardware-bound and advise against chasing 30 via
  polish). **Re-measure on a cool/idle machine** for a representative number; the
  atlas change adds no per-actor draw cost (one quad vs the old many primitives).

## Honest quality boundary

- **Hero (long coat): showcase quality.** The flaring coat carries the silhouette
  and the lighting carries the mood; it reads as a modern-gothic predator at game
  scale and close up.
- **Remaining humanoids: functional first pass.** They are coherent, grounded,
  normal-mapped 3D figures with correct faction silhouettes (swat helmet, hunter
  hood, cop mass) that read at the 64–90px game-display size, but at close range
  the skin-modifier torso reads a little stocky. The high-leverage next lever is
  per-archetype body shaping (shoulder/torso/build differentiation) — the pipeline
  already supports it; it is an art-tuning pass, not new engineering.
- **Vehicles (5) are not yet atlas-based.** The live renderer still draws cars
  procedurally; a vehicle 3D→atlas extension is the next pipeline addition.
- **Rat** stays on its legacy 96×128 SVG atlas (non-humanoid quadruped); the
  validator handles the mixed size.

CPU-only Cycles on this machine makes a full archetype ~2 min (128 cells × 3
passes); GPU would cut that substantially.
