# Agent Guide: Building Production Visual Assets for Vampire City

This guide is the operating contract for agents extending the 2026 visual foundation. It is intentionally strict. A pretty isolated PNG is not a game asset; a game asset is a coherent set of directional states, material maps, runtime bindings, performance evidence, and regression tests.

## Visual north star

Vampire City is a modern-gothic predator fantasy viewed from a fixed top-down/three-quarter camera. The image should feel cold, wet, dangerous, and materially believable. Darkness must reveal form rather than erase it.

Use these principles:

- realistic adult proportions; no chibi, anime, mascot, toy, or cel-shaded anatomy;
- silhouette first: faction and combat role should read at 64–90 display pixels;
- black is a family of blue-black, charcoal, leather, wet asphalt, and oxidized metal—not one crushed value;
- crimson is an accent and consequence, not wallpaper;
- cloth stays mostly matte, skin broad and soft, metal/glass tight and bright;
- one consistent camera, lens, ground plane, light direction, and baseline across every frame;
- combat poses must be readable at a glance: anticipation, strike, follow-through, recovery, hit, feed, downed, corpse;
- weapons and asymmetric costume details must never be mirrored accidentally.

## Shipping atlas contract

| Property | Contract |
|---|---|
| Character cell | 96 × 128 RGBA |
| Character atlas | 768 × 2048 |
| Columns | E, SE, S, SW, W, NW, N, NE |
| Rows | idle A/B; walk 0–5; attack anticipate/strike/follow-through/recover; hit; feed; downed; corpse |
| Baseline | Y = 112 in each cell |
| Normal atlas | 384 × 1024 RGB, normalized, flat `(128,128,255)` outside silhouette |
| Specular atlas | 192 × 512 grayscale |
| Vehicle diffuse/normal | 192 × 96 |
| Vehicle specular | 96 × 48 |
| Runtime material | Godot `CanvasTexture` |
| Live actor renderer | `CharacterAtlas2D.gd` |

Changing this contract is an engine task, not an art convenience. Update the renderer, manifest, validator, tests, evidence, and documentation together or do not change it.

## End-to-end workflow

### 1. Audit the live path before making art

Trace the asset from simulation entity to screen. Confirm which `type_id`, faction, weapon tag, responder state, and special tags choose the archetype. Search for procedural drawing in the actual runtime path. Do not assume that an attractive file in `assets/` is ever loaded.

### 2. Write the archetype brief

Specify, in one compact paragraph:

- role and threat level;
- silhouette language;
- anatomy/build;
- costume layers and materials;
- weapon and handedness;
- palette with one accent;
- face/head treatment;
- unique read at game scale;
- what must remain visible in downed/corpse states.

Reject briefs that distinguish characters only by hue.

### 3. Author a turntable first

Before animation, create all eight directional idles. Compare them in a single strip. Lock:

- camera elevation and azimuth;
- scale and baseline;
- shoulder/hip/head proportions;
- weapon side;
- coat and accessory placement;
- key/rim light direction;
- shadow footprint.

Do not animate an inconsistent turntable. Errors multiply by sixteen rows.

### 4. Build semantic poses, not decorative motion

Every row must communicate gameplay. Use the authoritative `ActionDef` phases as the timing source:

- anticipation stores energy and exposes intent;
- strike reaches maximum threat/readability;
- follow-through shows momentum and direction;
- recovery returns mass to the base stance;
- hit breaks the silhouette away from the attacker;
- feed visibly closes distance and commits the head/arms;
- downed still reads as alive;
- corpse is inert and materially grounded.

Walk cycles need weight transfer, not merely alternating feet. Keep the upper body stable enough for combat readability.

### 5. Generate or paint at high resolution

When using Blender, hand painting, or image generation, produce frames at least 4× the shipping cell dimensions and downsample once at the end. Maintain transparent or chroma-keyable backgrounds and preserve complete feet, weapons, coat tails, and shadows.

A useful generative prompt skeleton is:

> Production game sprite of [archetype], fixed orthographic three-quarter overhead camera, realistic adult anatomy, grounded dark modern-gothic clothing, [materials], [weapon and handedness], cold moon key light with restrained warm practical rim, isolated full body, consistent scale and baseline, readable silhouette at 64 pixels, physically plausible folds and equipment, no scenery, no text, no UI.

Negative constraints:

> no cartoon, anime, chibi, mascot, cel shading, comic outline, bobble head, elongated stick limbs, giant hands, cropped feet, floating pose, duplicated weapon, extra fingers, inconsistent camera, perspective lens, background scene, glow haze, watermark, logo, text.

Generate one controlled archetype/pose/direction batch at a time. Do not ask a model for a complete sprite sheet in one uncontrolled image; cell alignment, identity, and camera consistency will collapse.

### 6. Clean alpha and cell boundaries

Place each frame in an isolated cell and clip it. Dilate RGB beneath the alpha edge before downsampling or linear filtering will expose black fringes. Verify that no weapon, muzzle flash, coat tail, blood ribbon, or shadow crosses a cell boundary.

### 7. Build material maps

Normal maps must be generated per cell, not from the complete atlas as one image. Normalize vectors after every resize. Force transparent pixels to the flat normal. Inspect the map under a moving point light; a mathematically valid normal can still have inverted or noisy form.

Specular maps should express material identity rather than duplicate luminance:

- cloth and hair: low, broad response;
- skin: restrained response;
- leather: medium, broken response;
- metal/glass/wet paint: high, tighter response;
- blood: dark body with sparse wet highlights.

Lower-resolution normal/specular maps are acceptable only when visual tests show no temporal shimmer or loss of material separation.

### 8. Integrate without touching the simulation

Map the new archetype in `CharacterAtlas2D._select_atlas_key()`. Preserve the renderer's public contract. Visual code may read simulation state but must not mutate it. Use semantic cues for transient reactions and keep authoritative timing in the simulation.

### 9. Run every gate

```bash
python3 tools/visual/generate_visual_atlas.py
python3 tools/visual/rasterize_visual_assets.py --force
python3 tools/visual/validate_visual_assets.py
python3 tools/visual/render_visual_contact_sheet.py
```

Then run the full Godot import/GUT suite and the windowed `Visual evidence` workflow. Review the uploaded six-frame evidence at 100% scale. A green script is necessary, not sufficient; humans must inspect silhouette, temporal consistency, faction identity, and scene readability.

## Performance budget

Treat 30 FPS under the repository's software-rendered stress capture as the floor, not the aspiration. Preserve these rules:

- one main atlas draw per ordinary actor;
- overlays only when semantically active;
- no per-actor light nodes by default;
- near/mid/far redraw cadence remains bounded;
- no full-atlas duplication per instance;
- no per-frame image processing or texture creation;
- no particle system for an effect that can be a bounded decal or short ring buffer;
- measure with the real `GameView`, not an empty test scene.

Any change that adds a draw, node, light, material, or texture allocation to every actor needs an explicit before/after stress result.

## Review checklist

Reject the asset if any answer is “no”:

1. Does the silhouette read without color?
2. Is the anatomy convincingly adult and weighted?
3. Are all eight camera directions authored and consistent?
4. Is handedness stable?
5. Are anticipation, strike, hit, downed, and corpse instantly distinct?
6. Are feet and contact shadows on the common baseline?
7. Are alpha edges clean under linear filtering?
8. Do normal/specular maps improve volume rather than add noise?
9. Does the asset remain readable under dark moonlight and warm practical light?
10. Does the live runtime actually load it?
11. Does the validator pass with fresh hashes?
12. Does the real stress capture remain at or above 30 FPS?

## Common failure modes

- **“Concept-art trap”**: a beautiful standalone render with no directional or animation consistency.
- **“Palette clone”**: identical body/gear silhouettes with different colors.
- **“Black hole costume”**: all dark materials collapse into one value.
- **“Mirror crime”**: weapons, badges, scars, or normals flip between directions.
- **“Atlas bleed”**: attack effects leak into neighboring cells.
- **“Smooth but weightless”**: interpolated transforms hide a locomotion cycle with no mass transfer.
- **“GPU confetti”**: every actor receives unique materials, lights, particles, or generated textures.
- **“Test theater”**: screenshots from a hand-built scene while the real `GameView` still uses fallback art.

## Provenance

The current baseline assets are original deterministic SVG/raster output generated entirely inside this repository. No third-party character art or vehicle photography is embedded. Agents that introduce external source material must add its license and provenance before the asset can ship.
