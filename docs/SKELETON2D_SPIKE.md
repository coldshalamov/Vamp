# Skeleton2D Spike — Hero Character Animation (Part 5 / A3 #10)

**Status:** Research + honest assessment. No rig was built and none is claimed to work.
**Basis of recommendation:** architecture + pipeline analysis of `tools/visual/` and
`src/present/CharacterAtlas2D.gd`, plus visual inspection of the shipped `hero_diffuse.png`.
This report does **not** assert that a Skeleton2D rig "fails" empirically — it shows the
cost/fit is wrong for *this* game and that the sanctioned cheaper path already exists.

**Recommendation (headline): (b) + (c).** The current authored atlas is a sufficient
shipping baseline for the hero **now**, and the correct upgrade path is the plan's own
**option 12** — bump the atlas resolution and add animation frames via the existing
parametric generator. **Do not** commit to Skeleton2D rigging (option a/11).

---

## 1. What the pipeline actually does

The hero (and every actor) is authored as **deterministic SVG, baked per cell**, then
rasterized to a single atlas PNG and bound to a Godot `CanvasTexture`:

- `tools/visual/visual_asset_core.py` — primitive emitters (`polygon`, `ellipse`,
  `line`, `path`), the `CharacterProfile` color/feature model, the 16-row pose table
  (`_pose_for_row`), gradient `<defs>`, and the asset writer.
- `tools/visual/generate_visual_atlas.py` — the heavy art logic. `draw_character(p, angle,
  row, seed)` computes **every joint position inline** for the given facing + pose, then
  emits a flat list of SVG shapes for that one cell. The atlas writer wraps each cell in a
  hard-clipped `<svg overflow="hidden">` so no weapon/claw/coat-tail bleeds into the
  neighbouring frame.
- `tools/visual/rasterize_visual_assets.py` — Playwright/Chromium (cairosvg/resvg
  fallback) renders the 768×2048 SVG to RGBA PNG; flat normal `(128,128,255)` and low-grey
  specular maps are emitted alongside.
- `tools/visual/write_character_materials.py` — writes one `CanvasTexture` `.tres` per
  archetype (diffuse + normal + specular).

Contract (from `visual_asset_core.py` and `AGENT_VISUAL_REVAMP_GUIDE.md`): **96×128 cell,
8 direction columns (E,SE,S,SW,W,NW,N,NE), 16 semantic rows** (idle A/B, walk 0–5, attack
anticipate/strike/follow-through/recover, hit, feed, downed, corpse), baseline Y=112.

`CharacterAtlas2D.gd` is the live renderer (`EntityRenderer.gd` preloads it — `CharacterRig2D`
is dead/fallback). It maps authoritative sim state → row (`_select_row`) and facing → column
(`_direction_column`), and draws **one `draw_texture_rect_region` per actor** plus a shared
rim-light shader (`art/shaders/character_rim.gdshader`) and small conditional overlays
(status arcs, alert pip, resonance ring, hit-flash, dash afterimages).

### The structural fact that decides this spike

In `draw_character()` the body is **not** composed of separable, registered, reusable parts
with stable pivots. Each frame derives `chest`, `pelvis`, `sh_l/sh_r`, `hip_l/hip_r`,
`knee`, `ankle`, `toe`, `el`, `hand` as functions of `angle`, `pose['phase']`, `gait`,
`attack`, `hit`, `feed`, and `view_w = .70 + .30*abs(front)` (foreshortening per facing).
Limbs, torso, coat skirt, hood/face and weapons are drawn into a flat list and **baked**.
The geometry is *parametric* (you could re-derive parts from code), but as authored it is a
single layered image per cell, not a layer stack.

---

## 2. Current hero quality (visual inspection of the shipped atlas)

Cropped and upscaled cells from `assets/visual/atlases/hero_diffuse.png` (S idle, S
attack-strike, E walk) show a **grounded adult silhouette**: long dark coat with sculpted
torso shading, pale masked face with crimson eyes, red lapel/lining accent, claws on a
consistent (right) hand, weighted boots, and a baked contact shadow. It reads clearly as a
*person*, not a stick figure or blob, at game scale. The downed/corpse rows are distinct
compositions, and the rat atlas is a proper low quadruped. This is the explicit antithesis
of the killed "asparagus people" `CharacterRig2D` and it succeeds at that bar.

The real weaknesses are not anatomy — they are **animation density** (6 walk frames; idle is
a 2-frame breathing swap) and **resolution** (96×128, soft under the 3× zoom but fine in
play). Both are fixable inside the existing generator.

---

## 3. Skeleton2D feasibility for an 8-direction top-down rig

A Godot `Skeleton2D` + `Bone2D` + `AnimationPlayer` rig is a **single-plane puppet**: a tree
of `Sprite2D`/`Polygon2D` parts deformed by bones, viewed from one angle, animated once and
reused. That economy is exactly what makes it great for side-scrollers — and exactly what
collapses here. Two discriminating obstacles, specific to this game:

1. **8 directions kill the rig economy.** A 2D rig cannot be rotated in 3D. A coat, hood,
   masked face and claw seen from N are *different art* than from S/E/W. To keep the
   project's no-mirror rule (weapons/normals must not flip), you would author **8
   direction-specific part-sets** and either rig 8 skeletons or one rig that swaps every
   bone's sprite per direction. The "rig once, get all animations free" payoff — the entire
   reason to choose Skeleton2D — evaporates. This is why most 8-direction top-down games
   ship sheets, not rigs.

2. **Per-direction depth interleaving.** `draw_character()` draws in mass order: far-leg →
   far-arm → coat skirt → torso → near-leg → near-arm, and which limb is "near" flips with
   `near_r = side >= 0` as facing crosses the vertical. Godot `Skeleton2D` has a fixed
   per-node z-order; getting the correct arm/leg in front for each of 8 facings requires
   per-direction z-reshuffles or wholesale sprite swaps. A concrete, named obstacle — not a
   hand-wave.

**Honest scope of the claim:** parts *can* be extracted (the generator already knows every
joint), so "impossible" would be false. The accurate, stronger claim is: extraction yields
**8 direction-specific part-sets with per-direction depth order**, which negates the rig's
advantage and adds the depth problem on top — for no net animation reuse.

### Perf and lineage (the GL-Compat / iGPU constraint)

- The atlas path is deliberately **one draw call per actor**; a rig is **N nodes/draws per
  actor**. The hero alone is affordable, but the plan's success branch (option 11) is "rig
  **all** characters." On the documented ~26 FPS iGPU ceiling under the 30-actor stress
  gate, multiplying draws/nodes across the crowd is a likely regression of the perf gate the
  revamp explicitly defends.
- Skeleton2D is the **same family** (runtime-articulated limbs) as `CharacterRig2D.gd` — the
  renderer the project killed for producing "asparagus people." Re-introducing runtime
  limb articulation as the shipping path walks back toward that failure mode.

### The fair pro-rig case (and why it doesn't tip the call)

A rig would give smooth interpolated motion, Line2D weapon trails, IK hit-stagger, and
RigidBody2D ragdoll death — the A3 #11 wishlist. But most of that felt benefit is reachable
**on the atlas at the Node2D/presentation layer without any rig**, and some already exists in
`CharacterAtlas2D.gd`: dash afterimages, a dedicated hit-react row, hit-flash brighten,
speed-blended gait, distance-aware redraw. Weapon trails (Line2D), a juicier directional hit
shove, and a death tween/peel are all addable as cheap overlays. You get the juice without
paying the 8-direction × depth × per-actor-draw tax.

---

## 4. Effort contrast

| Path | Work | Risk | Perf |
|---|---|---|---|
| **Skeleton2D rig (a/11)** | Rewrite generator to emit registered per-part sprites, ×8 directions; build scene tree + AnimationPlayer clips; solve per-direction z-order; re-validate perf; then redo or hybridize for the whole crowd | **High** — likely fails the 30-actor perf gate; re-opens the killed runtime-limb lineage | N draws/nodes per actor |
| **Atlas resolution + frames (b/12)** | Change `FRAME_W/FRAME_H` (e.g. 192×256) + baseline; add walk/idle pose rows in `_pose_for_row` + matching `_select_row` cases; re-rasterize; update manifest/validator/tests | **Low** — same architecture, same renderer contract | **One draw call per actor (unchanged)** |
| **Ship as-is (c)** | None | None | Unchanged |

Rig path: **days to weeks**, high risk. Fallback path: **hours**, perf-neutral, preserves the
single-draw-call design.

---

## 5. Recommendation

**Do NOT commit to Skeleton2D rigging.** It is the wrong tool for an 8-direction top-down
predator on a GL-Compat iGPU: the multi-direction requirement destroys the rig's reuse
economy, per-direction depth order is an unsolved cost, the crowd-scale draw multiplication
threatens the defended 30-FPS gate, and it re-treads the killed "asparagus" runtime-limb
lineage.

**Ship the current atlas now (c)** — the hero already clears the project's quality bar — and
when animation richness is wanted, take the plan's own **option 12 (b)**: raise the atlas
cell to ~192×256 and add walk/idle frames through the existing parametric SVG generator. It
is a render-scale + pose-table change, costs hours not weeks, keeps one draw call per actor,
and compounds cleanly because it never leaves the atlas architecture.

If extra "rig-like" feel is desired before/instead of a resolution bump, add it as
presentation-layer overlays on the atlas (Line2D weapon trail, stronger directional
hit-shove, death peel/tween) — cheap, perf-safe, and within the existing renderer contract.
