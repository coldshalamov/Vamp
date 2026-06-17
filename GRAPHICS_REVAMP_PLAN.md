# Vampire City — Graphics Revamp Plan v4 (Implementation)

> Synthesizes codebase constraints, indie/AAA visual lessons, and AI-generated assets.
> Checkboxes track implementation status in this repo.

## Constraints (real vs workaround)

| Constraint | Reality | Workaround used |
|------------|---------|-----------------|
| No build step | `index.html` script order | New modules as plain `.js` files |
| `file://` loading | Relative `assets/images/*.jpg` works | Inline `artconstants.js` paths, no fetch required |
| Canvas 2D only | No WebGL | Bloom, lighting, post-FX stay canvas-based |
| No sprite tool in repo | — | `ArtBake` chroma-key + resize at runtime |
| Image gen moderation | Gore splats blocked | Procedural splat decals + rune FX in code |
| Performance | 40 NPCs, 256 lights | Bitmap gated by `ArtFlags` + quality tier |

## Lessons from popular games (applied)

| Game | Technique borrowed | Our implementation |
|------|-------------------|-------------------|
| **Hotline Miami** | Top-down readability, neon on dark | District grade + bloom on emissives |
| **Hades** | Impact freeze, screen punch | Existing `hitStop` + camera punch (kept) |
| **Dead Cells** | Strong character silhouette | AI player sprite + vector claw overlay |
| **GTA 1/2** | Tile variation, street clutter | Authored ground tiles + decals + props |
| **Disco Elysium** | UI as mood | Power icons, feeding frame, heat pulse |
| **Ruiner / Katana ZERO** | Rain, scanlines, grain | Film grain, puddles, weather (extended) |
| **Vampire: The Masquerade — Bloodlines** | Gothic noir palette | `theme.js` + district tints |

## Five NEW image-gen asset categories (added in v4)

1. **District mood panorama strips** — future: menu/map tint per district (paths stubbed in `DistrictGrade`)
2. **Window emissive sheets** — `windows_sheet.jpg` on building roofs ✓
3. **Neon tube sign strips** — `neon_sign.jpg` tinted per emitter ✓
4. **Feeding vignette frame** — procedural `PostFX.feedingFrame` (code; portrait gen optional)
5. **Discipline ground runes** — procedural `rune_shockwave` + Potence slam hook ✓

## Generated assets installed

| File | Use |
|------|-----|
| `assets/images/asphalt_wet.jpg` | Road tile pattern |
| `assets/images/sidewalk.jpg` | Sidewalk tile pattern |
| `assets/images/player_vampire.jpg` | Player body (chroma keyed) |
| `assets/images/prop_lamp.jpg` | Street lamps |
| `assets/images/prop_tree.jpg` | Trees |
| `assets/images/vehicle_sedan.jpg` | Sedan/sport/hearse |
| `assets/images/neon_sign.jpg` | Building neon |
| `assets/images/windows_sheet.jpg` | Roof windows |
| `assets/images/title_bg.jpg` | Title screen |
| `assets/images/icon_celerity.jpg` | Celerity power icons |

---

## Phase 0 — Infrastructure

- [x] `js/data/artconstants.js` — flags, paths, district grades, power icons
- [x] `js/core/artbake.js` — chroma key, tile resize, enhance
- [x] `js/core/assets.js` — bitmap loader, `drawKey`, pattern rebuild
- [x] `index.html` script order updated
- [x] Async load with splash progress (`game.js` + `main.js`)

## Phase 1 — Environment

- [x] Authored asphalt + sidewalk ground patterns
- [x] `js/world/decals.js` — rain puddles, cracks, manholes
- [x] `js/world/props.js` — lamp + tree bitmaps
- [x] `js/world/render.js` — neon signs + window sheets on buildings
- [ ] Autotile road/sidewalk transitions (future)
- [ ] Minimap resample from authored tiles (future)

## Phase 2 — Player & vehicles

- [x] Player bitmap render with clan tint + vector claws/cape
- [x] Movement acceleration smoothing (`player.js`)
- [x] Vehicle sedan bitmap with color tint
- [ ] Full 8-dir player animation sheet (future)
- [ ] NPC painted sprites from silhouette export (future)

## Phase 3 — FX & powers

- [x] Improved blood splat decals (`fx.js`)
- [x] `js/render/powervfx.js` — Potence/Celerity hooks
- [x] Procedural shockwave rune for slams
- [ ] Per-discipline icons for all 40 powers (future)
- [ ] Projectile streak sprites (future)

## Phase 4 — Post-processing & UI

- [x] `js/render/postfx.js` — district grade, grain, heat pulse, feeding frame
- [x] Title screen background art
- [x] HUD hotbar bitmap icons (Celerity family)
- [ ] Haven menu backdrop image (future)
- [ ] Clan emblem set (future)

## Phase 5 — Polish & QA

- [x] Vector fallback when assets missing (`ArtFlags.vectorFallback`)
- [ ] Screenshot regression suite (future)
- [ ] Mobile quality tier atlas (future)

---

## Architecture

```
artconstants.js → ArtPaths, ArtFlags
artbake.js      → chroma key, tile bake
assets.js       → loadAll(), drawKey(), patterns
render.js       → ground, buildings (windows/neon)
props.js        → standing props
decals.js       → ground decals
postfx.js       → screen passes after lighting
powervfx.js     → discipline visual hooks
```

## Running

Open via local server (recommended for consistent image loading):

```bash
npx serve .
```

Then visit `http://localhost:3000` (or the port shown).

## Remaining high-ROI work

1. Generate + wire remaining power icons (40)
2. NPC faction sprite sheets via silhouette img2img
3. Building roof module atlas per district
4. Autotiling at terrain borders
5. Haven interior menu background