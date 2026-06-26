# Advanced Visual Brief — Dead Cells rotoscope x VtM Bloodlines urban gothic

> Scope: this is an **implementer checklist**, not concept prose. Every item names the exact
> file + function it plugs into. The pipeline is fixed (do not redesign it): Blender 5.1 CPU
> Cycles renders a parametric humanoid into 192x256 cells x 8 dirs x 16 rows -> three passes
> (`diffuse` / `normal` / `spec`) -> `assemble_atlas.py` stitches atlases -> Godot relights them
> at runtime via `CanvasTexture` (diffuse+normal+spec) under 2D lights + the shared
> `character_rim` shader -> one full-frame `nocturne_grade` post pass.
>
> Insertion points referenced throughout:
> - `tools/visual/blender_render_atlas.py` -> `new_material`, `build_scene`, `loft_coat`, `prof` (L296-304), `configure_render` (L474-495), `PROFILES`/`SPEC`
> - `tools/visual/assemble_atlas.py` -> `edge_dilate`, `assemble_diffuse/normal/specular`
> - `glowup_2026/shaders/nocturne_grade.gdshader` -> the single full-frame post pass to extend
> - `art/shaders/character_rim.gdshader` + `src/present/CharacterAtlas2D.gd` -> per-actor relight/edge
> - `src/present/GameRenderer.gd` -> CanvasLayer ordering (NocturneGrade=2, ScreenFX=3, HUD=100)

---

## 0. The art target in one paragraph (read before touching anything)

Dead Cells look = 3D models rendered to 2D sprites, then **flattened and unified** so the lighting
reads as one cohesive painted plane, not a busy 3D render — strong silhouette, high local contrast,
a thin selective dark accent on form-defining edges (cavity/AO, *not* a uniform toon outline),
and a tight restrained palette. VtM Bloodlines look = wet **urban gothic**: cold blue-black night,
sodium-amber streetlamps, grime and edge-wear on every surface, materially believable leather /
denim / oxidized metal / pale skin, with crimson reserved for blood and faction cues. The figures
must read as **modern urban predators in fitted clothing**, never costumed Draculas. If a render is
smooth, clean, low-contrast, or the coat flares like a bell — it has failed.

---

## 1. KILL THE CAPE — this is geometry, not material (do this FIRST)

The current longcoat reads as a cape because of the **loft profile**, and no material/post trick can
fix a silhouette. In `blender_render_atlas.py` `build_scene`, the long-coat `prof` (L296-297) is:

```
[(1.49,0.150,0.115),(1.41,0.265,0.180),(1.18,0.225,0.165),
 (0.95,0.185,0.150),(0.66,0.220,0.180),(0.34,0.275,0.220)]
```

The hem `rx=0.275` is **wider than the shoulders** (`0.265`) and far wider than the waist (`0.185`).
That bottom-heavy A-line flare is literally a bell/cape. Fix it:

- [ ] **Hem must be <= waist radius.** Make the coat hang as a near-vertical column or taper slightly
      *inward* toward the hem. Target profile (straight, fitted, Bloodlines-trenchcoat, NOT bell):
      ```
      [(1.49,0.150,0.112),(1.41,0.232,0.170),(1.18,0.205,0.158),
       (0.95,0.188,0.150),(0.66,0.178,0.146),(0.34,0.170,0.142)]
      ```
      Shoulders are the widest ring; every ring below is equal-or-narrower. Reads as cloth falling
      under gravity, not a sail.
- [ ] **Widen the open-front gap so the legs/torso show through** (kills the "solid bell" silhouette
      and makes the figure read tall + adult). In `loft_coat(prof, 24, {16,17,18,19,20}, ...)` the gap
      is 5 of 24 segments (~75 deg). Widen to e.g. `{15,16,17,18,19,20,21}` (~105 deg) for long coats so
      the front splits and the legs separate the silhouette.
- [ ] **Reduce coat lean swing.** `apply_pose` rotates the coat by `chest.y * 22.0` deg (L407). On
      attack/feed lunges this throws the hem out like a flapping cape. Cap it: `chest.y * 10.0`,
      and add a tiny `min`/`clamp` so no pose tilts the coat past ~6 deg.
- [ ] **Belt the waist.** Add a thin dark cinch ring (a flattened torus or a 1-segment-tall darker
      material band) at `z≈0.95` so the coat reads as *belted at the waist then hanging* — the single
      strongest "fitted longcoat, not cape" cue. Assign it `mats["under"]` (matte) so it stays a shadow.
- [ ] Jackets (`long_coat=False`, L301) are already waist-length and fine; just apply the same
      "hem <= waist" rule to their `prof` so they don't bell out at the bottom hem.

**Acceptance:** in the S (col 2) and SE (col 1) idle cells, the coat hangs as two straight vertical
panels with the legs visible between them. If the bottom is the widest part of the figure, it failed.

---

## 2. Per-material PBR targets (procedural only — there are NO UVs)

**Hard constraint:** the meshes are Skin-modifier bodies + UV-sphere heads + lofted coats + primitive
props. **None are UV-unwrapped.** Every texture, grit, weave, and wear pattern MUST be a UV-free
procedural node graph driven by `Object`/`Generated` texture coordinates, `Geometry.Pointiness`, and
`ShaderNodeAmbientOcclusion`. Do NOT introduce image-texture PBR maps — there is nothing to map them to.

Extend `new_material(name, base, rough, metal, emis, emis_str, sss)` so it can optionally inject a
detail sub-graph (add a `detail=` kwarg or a small set of `material_class` presets). Keep the existing
`PROFILES` base colors and `SPEC` per-region values as the *signature* and layer procedural variation
on top — do not build a parallel system.

Roughness/metalness are authored values fed to the Principled BSDF; the **break-up** is a procedural
node multiplied/added into the Roughness input. Targets:

| Material | Base roughness | Metalness | Normal/bump source | Notes |
|---|---|---|---|---|
| **Leather (coat/jacket)** | 0.55 center -> 0.30 on edges | 0.0 | fine Voronoi(F1) grain + low Noise | semi-gloss when wet; edge-wear lightens roughness on seams/cuffs. Current `cloth` rough=0.88 is too matte/dead for leather — split a `leather` class at ~0.5. |
| **Denim / cotton (under, civilian)** | 0.92 | 0.0 | tight cross Wave/Voronoi weave, very low amplitude | stays matte, no specular hits; this is the only truly flat material. |
| **Pale vampire skin** | 0.42 | 0.0 | very low Noise pore bump | keep `sss=0.28` + radius `(0.12,0.05,0.03)`; push base toward `(0.78,0.72,0.74)` cool-pale, lift roughness slightly on lips/cheekbone highlight. Waxy, not plastic. |
| **Oxidized metal (weapons/armor)** | 0.22 base, 0.55 on corroded patches | 1.0 | Voronoi cell pitting + Pointiness scratches | mottle metalness DOWN to ~0.6 on oxidized patches (oxide is dielectric). Current rough=0.22 metal=1.0 is clean chrome — break it up or it looks toy-shiny. |
| **Wet asphalt (ground — see note)** | 0.12 in puddles -> 0.6 dry | 0.0 | n/a (no ground plane in atlas) | handled in-engine by `glowup_2026/shaders/wet_asphalt.gdshader`, NOT in the character render. Keep it in the palette/lighting section only. |
| **Blood (stains + fresh)** | 0.15 fresh wet -> 0.45 dried | 0.0 | Noise mask for spatter placement | base `(0.18,0.012,0.02)` deep crimson; fresh blood gets a thin clearcoat/low-rough sheen. Apply as a procedural overlay on coat/skin/hands (see §3). |

Per-material plug-in: each gets its own `new_material(...)` call inside `build_scene` `mats = {...}`
(L246-254). Add `leather`, keep `cloth` for non-leather garments, and add a `blood` mask graph that
mixes into existing materials rather than a new object.

---

## 3. HOW to get grit/detail on a clean 3D render (UV-free recipes)

These are the node graphs that turn "smooth clay" into "materially believable, weathered." All operate
on `Object` or `Generated` coords so they need no UVs. Build them once as helper functions
(`_grit_nodes(bsdf, ...)`) called from `new_material`.

- [ ] **Micro-normal / surface texture** — `Noise Texture` (scale ~120-300, detail 2) -> `Bump`
      (strength 0.03-0.08) -> BSDF Normal. Adds pore/fabric/leather micro-relief.
      **CRITICAL (see §5):** this only shows in the **diffuse** pass; the normal atlas pass ignores it.
      So treat micro-normal as *baked diffuse shading*, not as something dynamic light will pick up.
- [ ] **Roughness break-up** — `Musgrave`/`Noise` (scale ~40) -> `ColorRamp` -> `MixFloat` into the
      Roughness input. Never ship a flat roughness; uniform roughness is the #1 "CG plastic" tell.
- [ ] **Edge wear** — `Geometry.Pointiness` -> `ColorRamp` (clamp convex edges to ~1.0) -> drive
      roughness DOWN and base color toward a lighter scuff on cuffs, collar, shoulder seams, weapon
      edges. This is what sells leather/metal as *used*.
- [ ] **Cavity / contact AO** — `ShaderNodeAmbientOcclusion` (distance ~0.08, inside ON) -> `ColorRamp`
      -> multiply into Base Color in recesses (armpits, under collar, between coat panels, eye sockets).
      Bakes the Dead Cells "dark in the creases" read. Cheap and high-impact.
- [ ] **Grime gradient** — `Generated` Z coordinate -> `ColorRamp` -> darken/desaturate the lower
      ~30% of the coat and boots (street filth rises from the ground). Subtle (`mix 0.0->0.25`).
- [ ] **Bloodstains** — `Noise`/`Voronoi` thresholded `ColorRamp` mask -> `MixColor` toward `blood`
      base on hands, mouth/chin (skin), coat front. Drive a few PROFILES (`hero` claws, `thug`,
      anything that fed). Keep it sparse — a smear, not a paint bucket. This is the *only* sanctioned
      large use of crimson on the body.

**Acceptance per cell:** zoom the diffuse cell to 200%. You must see roughness variation, a darker
crease line where panels meet, a lighter scuff on at least one edge, and no flat untextured plane.

---

## 4. Palette (lock these, do not free-paint)

Cold blue-black night + restrained crimson + sodium-amber. This palette already lives in `PROFILES`
(coats `0.01-0.16` in cold blue-black) and the light rig (`KeyMoon` blue, `RimLamp` amber). Reinforce:

- **Body / night base:** blue-black family. RGB stays in `(0.01..0.18)` with blue >= red >= ... cool.
  Pure neutral grey is forbidden; everything tints toward `(.., .., +blue)`.
- **Key light (moon):** `KeyMoon` `(0.50,0.64,1.0)` cold — keep. This is the dominant shaper.
- **Rim/practical (sodium lamp):** `RimLamp` `(1.0,0.50,0.18)` warm amber — keep. The ONLY warm in
  the frame; it defines the wet-street mood. Amber rim vs blue key = the whole VtM contrast.
- **Crimson:** reserved. Faction collar (`accent`, long-coat only, L309-312) + blood (§3) + the
  in-engine heat/frenzy grade. Never use red for general clothing.
- **In-engine grade** (`nocturne_grade.gdshader`) already pushes shadows blue (`humanity_loss`
  `vec3(0.83,0.94,1.08)`) and dawn warm (`vec3(1.08,0.91,0.70)`). The atlas palette must *agree* with
  this so the grade reinforces rather than fights — keep atlas shadows cool-blue, not warm-brown.

---

## 5. The normal-pass trap (decide this explicitly or detail vanishes)

`make_normal_material` (L442) is a `material_override` that **replaces every material** with a
geometry-normal emission shader. Therefore:

- Micro-normal / bump added to the diffuse BSDF appears in the **diffuse atlas only**.
- The **normal atlas** captures macro mesh form (`Geometry.Normal`) — it does NOT see any procedural
  bump you added to the diffuse material.
- Consequence: in-engine 2D-light relight (driven by the normal atlas) reacts to the body's *gross
  form*, not to leather grain or fabric weave.

**Decision (recommended default — write this into the renderer comments):**
- Bake fine micro-detail (grain, weave, pores, grime, edge-wear, bloodstains) into the **diffuse**
  pass. It is "painted-in" shading, consistent with the Dead Cells flattened-render aesthetic.
- Keep the **normal** atlas as clean macro form so dynamic streetlamp pools sweep believably across the
  silhouette without noisy micro-flicker.
- Only promote detail into the normal pass if it is *large* form (e.g. coat panel folds) — and if so,
  it must be real geometry (so `Geometry.Normal` captures it), not a bump node.

Do not promise the implementer that leather grain will catch dynamic light — it won't, by design.

---

## 6. Tonemap — exactly ONE authoritative curve (avoid the double-grade mud)

Today `configure_render` bakes **Filmic + Medium High Contrast + exposure -0.3** into the diffuse atlas
(L486-488). The wishlist wants in-engine ACES over the full frame. Doing BOTH double-tonemaps:
Filmic-baked sprites then ACES-graded on screen = crushed, muddy, low-detail — exactly the failure mode
the user is angry about. Pick one:

- [ ] **Authoritative tonemap = in-engine, once, full-frame.** Change `configure_render` beauty branch
      to bake the atlas in a **near-neutral, low-contrast** transform:
      `view_transform = "AgX"` with `look="None"` (or `"Standard"` if AgX unavailable), `exposure=0.0`.
      This gives a flat-ish, full-range sprite that does not pre-bake heavy contrast.
- [ ] Apply the **single** final ACES-style tonemap + contrast + grade in the extended
      `nocturne_grade.gdshader` (§7), so the whole composited frame is graded once and consistently.
- [ ] Keep `film_transparent = True` and the `Standard`/`None` transform on the **normal/spec** passes
      (already correct, L491-495) — those are data, never tonemapped.

Net: atlas = neutral material data; the screen pass = the one place tone and mood are decided.

---

## 7. Post-process recipe — fold into the ONE existing screen pass (fps budget)

**Hard constraint:** the game is gl_compatibility on an Intel iGPU at ~26 fps baseline (hardware-bound).
Every `hint_screen_texture` shader is a backbuffer copy. Do **not** stack new CanvasLayers. Extend the
existing single `nocturne_grade.gdshader` (NocturneGrade, layer 2) in place — it already samples
`screen_texture` once, has `vignette`, desaturate, and tint machinery, and runs below ScreenFX(3)/HUD(100).
Add these stages inside its one `fragment()`, after the existing semantic-grade math, before the final
vignette:

| Stage | What | Suggested strength | Reconciliation with BANNED list |
|---|---|---|---|
| **Edge ink** | Sobel/luma-diff on `screen_texture`, but **darken only** (multiply, no flat color line) | mix toward `*0.82` at strong edges; clamp so it reads as cavity/contact darkening | NOT a uniform toon outline. Selective, luminance-weighted, dark-only. A toon cel line is BANNED — this is AO-style edge darkening. |
| **Painterly quantize** | Posterize **shadows/midtones only**, ~6-8 bands, weighted by `(1 - luma)` | quantize amount `* (1 - luma) * 0.4`; highlights stay smooth | NOT flat cel-shading. Gentle shadow banding for a painted, not cartoon, read. If highlights band, it failed. |
| **Color grade** | Lift shadows cool-blue, gentle S-curve contrast, slight crimson in deep midtones | shadow tint `vec3(0.92,0.97,1.06)`, contrast ~1.08 | — |
| **ACES tonemap** | The single authoritative tonemap (see §6), full-frame | standard ACES fit | This is THE tonemap; nothing else applies one. |
| **Vignette** | Already present (`vignette_strength=0.28`) | keep; it composes with heat/frenzy edges | — |
| **Film grain** | `fract(sin(dot(uv, ...)) * ...) * TIME` animated luma grain | `0.025-0.04`, scaled by `(1 - luma)` so darks are grainier | respects existing `reduced_flash`/`reduced_motion` uniforms — gate grain animation by them. |
| **Anti-alias** | Single-pass luma-FXAA inside this same shader | standard FXAA quality preset | True multi-pass SMAA is too expensive at 26 fps; one FXAA tap-set is the budget-correct choice. |

- [ ] Drive new stage strengths from new `uniform float` params with sane defaults so they tune without
      recompiling, matching the file's existing uniform style.
- [ ] Order inside `fragment()`: semantic grade (existing) -> edge ink -> quantize -> grade ->
      ACES -> FXAA -> grain -> vignette -> output. Tonemap before grain so grain isn't tone-crushed.

---

## 8. Per-character relight tuning (`character_rim` + `CharacterAtlas2D`)

The atlas is relit at runtime; the brief's render choices must agree with these:

- [ ] **Rim shader** (`art/shaders/character_rim.gdshader`): its header comment still says "Cells are
      96x128" (L16) — the new atlas is 192x256. Re-verify `rim_width` taps (1-2 texels) stay inside the
      ~20px transparent cell margin at the larger cell size; bump margin assumptions in the comment.
- [ ] Keep `rim_color` cold `(0.74,0.83,1.0)` to match `KeyMoon` — the rim is the moon wrapping the
      silhouette. Do not warm it.
- [ ] **Contact shadow** is drawn in-engine (`CharacterAtlas2D._draw_contact_shadow`), NOT baked —
      confirmed correct; do not add a ground plane / baked shadow in Blender (it would smear across the
      cell and pollute the normal/spec passes, per `build_scene` L358-360).
- [ ] Spec atlas is the relight glint source. Make sure §3's edge-wear/oxidation reads in the **spec**
      pass by driving the per-object `["spec"]` attribute (used by `make_spec_material`, L462) — it is
      currently a single flat per-object value (`SPEC` dict). For wet-leather/metal glints to relight,
      either (a) vary the `spec` object attribute per part, or (b) accept flat per-part spec and let the
      diffuse-baked highlights carry it. Pick (b) for now unless glints look dead; note the tradeoff.

---

## 9. assemble_atlas.py — atlas-level treatment

- [ ] `edge_dilate` (L45) already bleeds RGB under the alpha edge — keep (prevents black halos under
      linear filtering/mipmaps). Do not remove.
- [ ] If §3 grain/grit is baked per-cell in Blender, do NOT add a second grain in the assembler — grain
      belongs in the single screen pass (§7) so it doesn't crawl per-frame inconsistently across cells.
- [ ] Normal renormalize + `flip_g` (L80-101) is correct for Godot 2D (+Y up) — leave it.
- [ ] Keep diffuse at full res, normal half, spec quarter (L31-32) — correct VRAM tradeoff for iGPU.

---

## 10. BANNED tropes (reject any render that shows these)

- **Capes, cloaks, flaring/bell/A-line coat hems** (see §1 — geometry fix is mandatory).
- **Count-Dracula tropes:** high collars worn as a cape frame, opera silhouette, tuxedo formality.
- **Cartoon / anime / chibi / cel-shaded:** flat color fills, uniform toon outlines, big-head
  proportions, hard 2-tone shading. (§7 edge-ink and quantize are explicitly the *restrained,
  shadow-only* versions — if either reads as cel-shading, it has violated this list.)
- **Smooth, featureless, clean clay:** any surface with no roughness break-up, no grit, no AO in the
  creases, no edge-wear (see §3 — every material must be weathered).
- **Warm/neutral overall cast:** the night is cold blue-black; amber is a *rim accent only* (§4).
- **Crimson as general clothing color:** red is blood + faction cue + heat grade only.
- **VtM cues done wrong:** vampire = FANGS + blood + pallor + predator stance. Never = cape.

---

## 11. Implementation order (smallest risk -> biggest payoff)

1. **§1 coat geometry** — change `prof` + gap + lean cap. No new code, immediate silhouette fix, kills
   the #1 complaint. Re-render the `hero`/`hunter`/`elder`/`thrall` long-coat archetypes only to verify.
2. **§6 tonemap decision** — flip `configure_render` to neutral/AgX. One-line-ish change; prevents the
   double-grade mud before you invest in detail.
3. **§3 grit recipes in `new_material`** — add the UV-free detail sub-graph (roughness break-up + AO +
   edge-wear + micro-bump). Biggest "materially believable" jump.
4. **§2 material split** — add `leather`/`blood` classes, retune skin pallor + metal oxidation.
5. **§7 screen post** — extend `nocturne_grade.gdshader` in place (edge-ink, quantize, ACES, grain,
   FXAA). Verify fps does not drop below the ~26 baseline (it's still one pass).
6. **§8 relight verify** — confirm rim margin + spec read at 192x256 in-engine.

**Final acceptance:** view an in-engine `CapturePlay` screenshot (not just an atlas cell — relight +
grade + rim only exist in-engine). Pass = cold wet urban gothic, fitted straight-hanging coats,
visible material grit and grime, blue-black palette with amber rim and crimson only on blood/faction,
no bell-coats, no toon lines. Fail = any banned trope in §10.
