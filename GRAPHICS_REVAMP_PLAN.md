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

## Five NEW image-gen asset categories (v4)

1. **District mood panorama strips** — future: menu/map tint per district (paths stubbed in `DistrictGrade`)
2. **Window emissive sheets** — `windows_sheet.jpg` on building roofs ✓
3. **Neon tube sign strips** — `neon_sign.jpg` tinted per emitter ✓
4. **Feeding vignette frame** — procedural `PostFX.feedingFrame` ✓
5. **Discipline ground runes** — procedural `rune_shockwave` + Potence slam hook ✓

## Six additional image-gen categories (v4.1)

1. **Discipline icon sprite sheet** — `discipline_icons.jpg` → 10 sliced HUD icons ✓
2. **Haven interior backdrop** — `haven_bg.jpg` on haven menu ✓
3. **Civilian NPC sprite** — `npc_civilian.jpg` with shirt tint ✓
4. **Blood projectile streak** — `projectile_blood.jpg` for spell bolts ✓
5. **Clan emblem row** — `clan_emblems.jpg` → 7 emblems on title screen ✓

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
| `assets/images/icon_celerity.jpg` | Celerity power icons (legacy) |
| `assets/images/discipline_icons.jpg` | All 10 discipline HUD icons (sliced) |
| `assets/images/haven_bg.jpg` | Haven menu backdrop |
| `assets/images/npc_civilian.jpg` | Civilian NPC sprite |
| `assets/images/projectile_blood.jpg` | Blood bolt projectile streak |
| `assets/images/clan_emblems.jpg` | Title screen clan emblems (sliced) |

---

## Phase 0 — Infrastructure

- [x] `js/data/artconstants.js` — flags, paths, district grades, power icons
- [x] `js/core/artbake.js` — chroma key, tile resize, enhance
- [x] `js/core/assets.js` — bitmap loader, `drawKey`, pattern rebuild, sheet slicing
- [x] `index.html` script order updated
- [x] Async load with splash progress (`game.js` + `main.js`)

## Phase 1 — Environment

- [x] Authored asphalt + sidewalk ground patterns
- [x] `js/world/decals.js` — rain puddles, cracks, manholes
- [x] `js/world/props.js` — lamp + tree bitmaps
- [x] `js/world/render.js` — neon signs + window sheets on buildings
- [x] Autotile road/sidewalk edge blends (`renderGroundEdges`)
- [x] Minimap resample from authored tiles (`hud.js buildMinimap`)

## Phase 2 — Player & vehicles

- [x] Player bitmap render with clan tint + vector claws/cape
- [x] Movement acceleration smoothing (`player.js`)
- [x] Vehicle sedan bitmap with color tint
- [x] Civilian NPC bitmap sprites (`npc.js`)
- [ ] Full 8-dir player animation sheet (future)
- [ ] NPC faction sprite sheets (gang/cop/hunter) (future)

## Phase 3 — FX & powers

- [x] Improved blood splat decals (`fx.js`)
- [x] `js/render/powervfx.js` — Potence/Celerity hooks
- [x] Procedural shockwave rune for slams (via `FX.spriteRing`)
- [x] Per-discipline icons for all 36 powers (`powerIconKey` → sliced sheet)
- [x] Projectile streak sprites (`projectile_blood.jpg`)

## Phase 4 — Post-processing & UI

- [x] `js/render/postfx.js` — district grade, grain, heat pulse, feeding frame
- [x] Title screen background art + clan emblems
- [x] HUD hotbar bitmap icons (all disciplines)
- [x] Haven menu backdrop image
- [x] Clan emblem set (title screen)

## Phase 5 — Polish & QA

- [x] Vector fallback when assets missing (`ArtFlags.vectorFallback`)
- [x] Mobile quality tier atlas gating (`Game.applyQualityTier`)
- [ ] Screenshot regression suite (future)

---

## Architecture

```
artconstants.js → ArtPaths, ArtFlags, powerIconKey, clanEmblemKey
artbake.js      → chroma key, tile bake
assets.js       → loadAll(), drawKey(), patterns, sheet slicing
render.js       → ground, autotile edges, buildings (windows/neon)
props.js        → standing props
decals.js       → ground decals
postfx.js       → screen passes after lighting
powervfx.js     → discipline visual hooks
fx.js           → spriteRing for rune shockwaves
```

## Running

Open via local server (recommended for consistent image loading):

```bash
npx serve .
```

Then visit `http://localhost:3000` (or the port shown).

## Remaining high-ROI work

1. NPC faction sprite sheets (gang, cop, hunter) via img2img
2. Building roof module atlas per district
3. Full 8-dir player walk animation sheet
4. District mood panorama strips for map/menu
5. Screenshot regression suite for visual QA