# Visual Revamp 2026 — Implementation Report

## Executive result

The live game no longer renders humanoids as articulated lines, circles, and programmer polygons. The presentation path now uses authored, light-reactive atlas materials for every player/NPC archetype, authored car materials for the two vehicles in the vertical slice, and organic blood decals for the most repeated ground effect.

This pass establishes a production foundation for a dark modern-gothic action RPG: grounded adult proportions, strong faction silhouettes, restrained crimson accents, readable weapons, eight authored directions, semantic combat poses, and normal/specular response under Godot's 2D lights. It deliberately does **not** pretend that a small 2D project has suddenly acquired the character budget of a full AAA 3D production. The target borrowed from Diablo is the useful part—silhouette hierarchy, material separation, darkness with readable form, and combat-state clarity—without making a false fidelity claim.

## Root cause found

The repository's own art specification requires authored hero assets, but the live renderer had drifted to `CharacterRig2D.gd`: every body was assembled at runtime from jointed limb segments, circles, and polygons. That explains the “giant asparagus people” failure more directly than the old PNGs do. Cars were built from procedural chamfered polygons in the same hot draw loop.

The revamp changes the live path rather than painting over the symptom:

- `EntityRenderer.gd` instantiates `CharacterAtlas2D.gd`, not `CharacterRig2D.gd`.
- Every actor resolves to a `CanvasTexture` with diffuse, normal, and specular maps.
- Vehicles use one material-rich texture draw plus inexpensive dynamic headlight/lightbar geometry.
- Blood pools use one organic decal per wet cell instead of stacked concentric circles.
- The old procedural character file remains only as historical/fallback code and is rejected by the new validation gate if it returns to the live renderer.

## Assets delivered

The shipping contract contains ten actor archetypes:

`hero`, `thug`, `gunner`, `cop`, `swat`, `hunter`, `elder`, `thrall`, `civilian`, and `rat`.

Each actor atlas contains:

- 8 authored directions: east, southeast, south, southwest, west, northwest, north, northeast;
- 16 semantic rows: two idles, six walk frames, anticipation, strike, follow-through, recovery, hit, feed, downed, and corpse;
- 96 × 128 source frames in a 768 × 2048 diffuse atlas;
- a 384 × 1024 normalized normal atlas;
- a 192 × 512 grayscale specular atlas;
- a Godot `CanvasTexture` resource that binds those maps.

That is 1,280 directional semantic actor frames. The high-frequency world set adds a civilian sedan, police cruiser, and four blood decal variants. The production output is 49 generated files, approximately 9.94 MB compressed and 72.5 MiB as a conservative uncompressed texture-memory estimate before engine import compression.

Review sheets generated from the exact shipping PNGs—not separate concept art—live in `docs/evidence/visual_revamp/`.

## Art and rendering techniques

### 1. Deterministic source generation

The source atlases are authored as deterministic SVG. Every pose, direction, silhouette, color decision, and decal seed is reproducible from code. This avoids the usual “mystery PSD on one person's laptop” failure and lets an agent rebuild or audit the entire set.

The characters use tapered limb volumes, broad clavicles, cinched waists, weighted boots, explicit joints, overlapping coat planes, readable weapons, grounded contact shadows, and separate downed/corpse compositions. Faction identity is carried by silhouette and equipment before color:

- hero: long black coat, masked pale face, crimson lining, claws;
- thug: heavy shoulders, blunt weapon, earth/leather values;
- gunner: compact street silhouette with pistol;
- police: navy uniform, badge/vest breaks, sidearm;
- SWAT: helmet, plate carrier, rifle, broad tactical mass;
- hunter/elder: hood, ivory/brass plate, long rifle;
- thrall: narrow violet-black silhouette and pallid skin;
- civilian: neutral streetwear and deterministic palette variants;
- rat: low quadruped body, tail, ears, feet, whiskers, and attack/downed states.

### 2. Cell-safe rasterization

Each atlas cell is hard-clipped before rasterization, so a rifle, claw arc, coat tail, or blood ribbon cannot bleed into the adjacent animation frame. Inkscape rasterizes the SVGs, then the pipeline performs alpha-edge dilation and restrained unsharp masking so linear filtering does not produce dark halos around moving sprites.

### 3. Per-cell normal maps

Normal maps are generated independently for each semantic frame. A height field combines silhouette distance, luminance structure, alpha, and material mass; gradients are normalized into tangent-space RGB. Transparent pixels are forced to a flat normal. Processing each cell independently prevents pose-to-pose normal bleed.

### 4. Material-aware specular maps

Specular intensity is generated at a lower resolution because highlight frequency does not justify full diffuse resolution at this game scale. Characters receive restrained cloth/skin/metal response, animals remain matte, and cars receive stronger glass/paint highlights. This saves memory while preserving the visual information players can actually perceive.

### 5. Semantic animation selection

`CharacterAtlas2D.gd` maps authoritative simulation state to visual rows. It reads movement, facing, `ActionDef` startup/active/recovery frames, hit reactions, feeding, downed state, corpse state, dash cues, faction, weapon, and entity tags. The simulation remains untouched; the scene tree is still only a view.

### 6. Distance-aware redraw cadence

Actor transforms remain on the fixed physics cadence for interpolation, while visual redraw frequency is bounded by distance:

- near actors: 30 Hz;
- mid-distance actors: 15 Hz;
- far actors: 8 Hz.

A frame or direction change still requests an immediate redraw. This keeps the closest combat readable without spending the same CPU time on distant pedestrians.

## Performance discipline

The previous actor path issued many primitive draw operations per character every render frame. The new steady-state body path is one atlas-region draw per actor, with small overlays only when a status, alert, resonance ring, flash, or dash afterimage is actually visible. Cars similarly collapse to one material draw plus lights. Blood collapses from multiple circles per wet cell to one decal.

Performance is not accepted by inspection. The repository already has a real windowed Godot capture workflow under Xvfb and Mesa software rendering. The stress scene exercises more than thirty actors plus projectiles and VFX, captures six distinct 1280 × 720 frames, and fails if average sampled performance is below 30 FPS. This revamp adds the atlas integrity gate before that render test. The PR's `Visual evidence` check is the authoritative runtime result; a green check is required before merge.

## Automated quality gates

`tools/visual/validate_visual_assets.py` rejects:

- missing or stale generated files;
- hash or byte-count drift from the manifest;
- wrong diffuse, normal, specular, vehicle, or decal dimensions;
- empty animation cells;
- narrow, low-area, or sparsely connected standing silhouettes that suggest a stick-figure regression;
- baseline drift that makes actors float;
- non-normalized normal vectors;
- non-flat normal-map backgrounds;
- broken `res://` material paths;
- loss of the near/mid/far redraw cadence;
- any live `EntityRenderer` preload of `CharacterRig2D.gd`.

`test/unit/test_visual_assets.gd` independently proves that Godot can import every `CanvasTexture` and that all texture map dimensions match the contract.

## Reproduction

Install Inkscape plus the Python dependencies, then run:

```bash
python3 -m pip install -r tools/visual/requirements.txt
python3 tools/visual/generate_visual_atlas.py
python3 tools/visual/rasterize_visual_assets.py --force
python3 tools/visual/validate_visual_assets.py \
  --json-out docs/evidence/visual_revamp/asset_metrics.json
python3 tools/visual/render_visual_contact_sheet.py
```

The last command creates review sheets from the production raster output. Commit generated assets only when the validator passes and the manifest hashes have changed intentionally.

## Honest boundary and next leverage point

This pass removes the visual regression and replaces it with a coherent, performant, testable 2D material pipeline. It is a strong foundation, not the end of visual development. The same 96 × 128 / 8-direction / 16-row contract can later ingest higher-budget Blender renders, hand-painted frames, or carefully controlled generative renders without changing simulation code or animation-state mapping.

The highest-return next work is bespoke hero and boss animation, more civilian silhouettes rather than tint-only variants, wall occluders for selective 2D shadows, and a dedicated environment-material pass. The foundation is now clean enough that those improvements compound instead of fighting a procedural stick-figure renderer.
