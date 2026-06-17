# Vampire City — Ultra Graphics & UX Makeover (Execution Plan)

> **Status:** WAITING FOR HANDOFF SIGNAL  
> **Trigger:** User confirms the feature agent has finished. Do not execute implementation until then.  
> **Final step:** Delete this file and `GRAPHICS_REVAMP_PLAN.md` when the makeover is verified complete.

---

## Mission

Complete an **ultra-ambitious, front-to-back** graphics and UX iteration on **this game** — same Canvas 2D stack, same `VAMP.*` architecture, same gothic-noir vampire city identity. **Extend and finish**, never reinvent.

**End state:** Districts feel like different films. Characters animate. Buildings read illustrated. Every discipline has spectacle. Masquerade/dawn/weather are cinematic. UI feels designed. All verified in browser with zero console errors.

**Anti-patterns (do not do):**
- Renderer rewrite (Pixi/WebGL world, React menus, new TILE size)
- Refactoring gameplay systems (`gamedata.js` logic, missions, combat math)
- Deleting vector/asset fallbacks
- Leaving stale plan markdown in repo when done

---

## Parallel-safe contract (feature agent vs graphics agent)

| Layer | Owns | Touches only via |
|-------|------|------------------|
| **Gameplay** | `js/systems/*`, `gamedata.js` content, entity sim | `fx` strings, `VAMP.FX.*`, `VAMP.Decals.spawn`, `VAMP.PowerVFX.play` |
| **Graphics** | `assets/*`, `js/render/*`, `js/core/assets.js`, `artbake.js`, `artconstants.js`, render fns in entities | Hooks above + `VAMP.Theme` |

**Rule:** If a new power/POI/NPC type exists after handoff, register its look — do not change how it works.

---

## Phase 0 — Mandatory reconnaissance (before any code)

When the user gives the handoff signal, **reread everything**. Do not assume v4 state.

### 0.1 Read list (in order)

1. `index.html` — script order
2. `js/data/artconstants.js`, `js/core/artbake.js`, `js/core/assets.js`
3. `js/core/theme.js`, `js/core/loop.js`, `js/core/camera.js`
4. `js/world/world.js`, `render.js`, `decals.js`, `props.js`
5. `js/render/postfx.js`, `powervfx.js`
6. `js/ui/fx.js`, `hud.js`, `menus.js`
7. `js/entities/player.js`, `npc.js`, `vehicle.js`, `projectile.js`, `sprites.js`
8. `js/game.js` — `init`, `render`, `renderTitle`, lighting order
9. `js/data/gamedata.js` — all `POWERS` ids + `fx` field names
10. `js/systems/powers.js` — which `PowerVFX.play` calls exist
11. Any files changed by feature agent (git diff / file mtimes if available)

### 0.2 Inventory snapshot

Record in session notes (not a new markdown file):

- [ ] `assets/images/*` list + dimensions
- [ ] All `ArtPaths` keys vs files on disk
- [ ] All `fx` names in `gamedata.js` vs `powervfx.js` registrations
- [ ] All district ids in `world.js` vs `DistrictGrade`
- [ ] New systems/POIs/powers added by feature agent

### 0.3 Baseline verification

```bash
npx serve .
node -e "/* syntax-check all js */"
# Playwright smoke: assets load, newGame, render(1), zero errors
```

Do not proceed until baseline is green or regressions are logged as pre-existing.

---

## Phase 1 — Retina pipeline (code-only, immediate lift)

Upgrade **existing** assets before mass regeneration.

- [ ] Ground tile bake: 128 → **512** (`assets.js` / `artbake.js`)
- [ ] Per-asset flags in `artconstants.js`: `{ smooth, displayScale, sharpen }`
- [ ] `artbake.sharpen()` pass after chroma (unsharp / contrast)
- [ ] Display scale bump: player ~48–64px, NPCs, vehicles, props (tune collision radii if needed)
- [ ] `imageSmoothingEnabled` per asset (false for pixel sprites, true for painterly)
- [ ] Minimap rebuild uses 512 patterns (`hud.js`)
- [ ] `applyQualityTier()` matrix updated for new flags

**Verify:** ground detail visible at zoom 1.15; player silhouette readable.

---

## Phase 2 — Asset manifest & PNG migration

Single registry — no scattered magic paths.

- [ ] Create `js/data/assetmanifest.js` (or JSON loaded by `assets.js`) — key, path, chroma, sheet slices, smooth, scale
- [ ] Migrate character/prop/projectile assets to **PNG alpha** (commit to `assets/images/`)
- [ ] Optional dev helper `scripts/bake-assets.mjs` (chroma→PNG, sharpen, atlas pack) — output committed; **players still need no build step**
- [ ] Deprecate duplicate legacy paths (`icon_celerity.jpg` → discipline slice only)
- [ ] IndexedDB optional cache for processed tiles (behind flag)

**Verify:** all manifest keys load; fallback when file missing.

---

## Phase 3 — Animation system (`js/render/spriter.js`)

One new module; entity logic unchanged.

- [ ] `Spriter.draw(ctx, key, x, y, { dir, frame, scale, tint, alpha })`
- [ ] Sheet slice at load (reuse `sliceHorizontalSheet` / grid slice)
- [ ] Integrate in `player.js`, `npc.js`, `vehicle.js` with **fallback to `drawKey`**

### Image-gen / install

- [ ] `player_walk.png` — 8 dir × 4 frames (designed for ~56px display)
- [ ] `npc_civilian_walk.png` — 4 dir × 2 frames
- [ ] `npc_gang.png`, `npc_cop.png`, `npc_hunter.png`, `npc_thrall.png`
- [ ] `vehicle_sedan.png`, `vehicle_sport.png`, `vehicle_van.png`, `vehicle_hearse.png` (+ headlight frame)
- [ ] `rat.png` — tiny scurry

**Verify:** walk cycles at 60fps; far LOD still blob; no pop-in crash.

---

## Phase 4 — District identity kits (7 districts)

Each kit keyed by `district.id` from `world.js`. Feature agent adds district → add kit row only.

Per district:

| Asset | Purpose |
|-------|---------|
| `skyline_{id}_back.png` | Parallax layer 0.3 |
| `skyline_{id}_front.png` | Parallax layer 0.6 |
| `roof_{id}.png` | Roof module atlas |
| `wall_{id}.png` | Extruded wall face |
| `decal_{id}_*.png` | 8–12 ground clutter stamps |
| Grade tweak in `DistrictGrade` | Already exists — tune |

### Code

- [ ] `js/world/districtart.js` — kit lookup, parallax draw, decal weights
- [ ] `render.js` — wall atlas on extrusion faces; roof modules on `drawRoofDetail`
- [ ] `decals.js` — spawn weights per district
- [ ] Parallax pass in `game.js` render (before buildings)
- [ ] POI façade stamps: haven, bloodbank, club, board, market

**Verify:** stand in each district — distinct silhouette and color.

---

## Phase 5 — Ground & city density

- [ ] **16-tile autotile** atlas for road/sidewalk/grass/water (replace color-blend edges)
- [ ] Grass, concrete, dirt, plaza authored tiles (match `GROUND_PATTERN`)
- [ ] Decal kinds: graffiti, litter, tire marks, dried blood, steam vent, manhole variants
- [ ] Weather-ground interaction: rain wet multiply, fog desaturate (ground pass only)
- [ ] Street prop expansion: dumpster, hydrant, bench, fence (district-gated)

**Verify:** road corners look intentional; clutter doesn't tank FPS.

---

## Phase 6 — Full discipline spectacle

Register **every** `fx` in `gamedata.js` in `powervfx.js` (grep-driven checklist).

| Discipline | VFX vocabulary |
|------------|----------------|
| Celerity | afterimage, dash streak, time desat overlay |
| Potence | spriteRing rune, dust decals, shock |
| Fortitude | stone shell overlay, heal shimmer |
| Obfuscate | smoke particles, opacity ripple |
| Auspex | target outline, weak-point glyph |
| Dominate | beam, puppet lines, mesmerize ring |
| Presence | aura disk, charm hearts, majesty shell |
| Protean | claw arcs, mist particles, beast swap |
| Sorcery | bolt streak, cauldron pool, ward hex, storm radial |
| Dark Arts | tendril sprite, confusion invert flash |

- [ ] Projectile family: bolt, bullet, blood, shadow tints
- [ ] `FX.spriteRing` / particles for ground spells
- [ ] Audio-visual bus hooks optional (`VAMP.bus` listen for siren/bass — no audio rewrite)

**Verify:** trigger each power in dev; no missing registration; no `game.ctx` draw outside render.

---

## Phase 7 — Cinematic pressure (masquerade · time · weather)

Extend `postfx.js` + `fx.js` + `camera.js` only.

- [ ] Heat 1–5 escalating edge treatment (pulse → scanline → searchlight → strobe)
- [ ] Dawn curve on `game.clock` (warm grade, window dim, sun shaft)
- [ ] Feeding: letterbox + vignette art + vitae drift to HUD
- [ ] Frenzy: red pulse, sprite override tint
- [ ] Death/respawn: brief desaturate + coffin frame
- [ ] Nemesis/elite: intro ring + persistent elite glow (read `nemesis.js` for hooks)
- [ ] Camera: feed zoom, discipline punch zoom (extend existing shake)

**Verify:** hit 3+ heat stars; advance clock to dawn; feed NPC; die once.

---

## Phase 8 — UX completion (`theme.js` widget library)

Ambitious UI on **existing** menu/HUD structure.

- [ ] `Theme.drawPanel`, `drawSlot`, `drawBanner`, `drawDistrictCard`
- [ ] District entry card (2.5s, skippable) on `districtAt` change
- [ ] Hotbar: discipline frames, cooldown radial, toggle glow
- [ ] Damage numbers: crit/heal/block tiers in `fx.js`
- [ ] Character header: clan emblem + vitae orb
- [ ] Mission tracker icons from atlas
- [ ] Map panel: fog edge, district regions
- [ ] Menu backdrops: board, map (match haven pattern)
- [ ] Custom CSS cursors on `#game` (interact, attack, feed, sprint)
- [ ] Splash load bar as blood fill

**Verify:** open every menu tab; no layout break at 1280×720 and 1920×1080.

---

## Phase 9 — Post-processing upgrade

- [ ] Separable Gaussian bloom (replace or augment 0.25× downscale)
- [ ] 1D LUT grade per district + dawn/dusk curve
- [ ] Optional `ArtFlags.useLightWorker` — OffscreenCanvas blur prep (new `js/render/lightworker.js`)
- [ ] Quality tiers: low = no worker, no grain, no parallax

**Verify:** neon blooms; FPS ≥ 45 on high tier with 40 NPCs.

---

## Phase 10 — Full agentic QA loop

Run until green. No shortcuts.

### 10.1 Automated

- [ ] JS syntax check all `js/**/*.js`
- [ ] HTTP 200 all `ArtPaths`
- [ ] Playwright: title load, asset 15+/N, `newGame`, `render(1)`, zero errors
- [ ] Playwright: haven open, character menu, map, pause

### 10.2 Manual browser pass

- [ ] Title → new game → move, sprint, attack, feed
- [ ] Use one power per discipline family
- [ ] Enter each district; confirm kit
- [ ] Trigger heat; survive to dawn warning
- [ ] Rain/fog weather if available
- [ ] Save/load; assets still ready

### 10.3 Code review pass

- [ ] No direct `game.ctx` draw in `powers.js` / systems
- [ ] All new files in `index.html`
- [ ] `ArtFlags` respected everywhere
- [ ] Vector fallback still works (disable one asset, reload)

### 10.4 Bug fix loop

For each failure: reproduce → patch → re-run 10.1–10.3. Repeat until zero open issues.

---

## Phase 11 — Post-implementation optimization

After everything works, **second pass with real-world eyes:**

- [ ] Remove ideas that looked good on paper but clutter (overdense decals, too many parallax layers)
- [ ] Merge duplicate assets (JPG legacy vs PNG)
- [ ] Tune display scales down if silhouettes blob together
- [ ] Profile: bloom cost, decal cap, light pool 256
- [ ] Simplify any over-engineered manifest fields
- [ ] Document only in code comments where non-obvious (no new plan markdown)

**Deliverable:** short user-facing summary of what changed (in chat, not a repo doc).

---

## Phase 12 — Finalize & cleanup (mandatory last step)

Remove process artifacts. Repo should contain **the game**, not the journey.

- [ ] Delete `GRAPHICS_ULTRA_MAKEOVER_PLAN.md` (this file)
- [ ] Delete `GRAPHICS_REVAMP_PLAN.md` (superseded v4 doc)
- [ ] Delete any `tmp/verify-*.mjs` or scratch notes added during execution
- [ ] Remove orphaned unused images in `assets/images/`
- [ ] Remove dead `ArtPaths` keys pointing to deleted files
- [ ] Confirm no references to deleted plan files in code or README

**Optional keep:** `scripts/bake-assets.mjs` if useful for future asset regeneration (not a player build step).

---

## Asset production checklist (~70–90 images)

Use image-gen; chroma `#ff00ff` or PNG alpha; copy to `assets/images/`; register in manifest.

### Core

- [ ] player_walk.png (8×4 grid)
- [ ] Ground: grass, concrete, dirt, plaza tiles
- [ ] autotile_16.png

### NPCs & vehicles

- [ ] npc_civilian_walk, npc_gang, npc_cop, npc_hunter, npc_thrall, rat
- [ ] vehicle_sport, vehicle_van, vehicle_hearse + headlight variant

### District kits (×7)

- [ ] skyline back + front per district
- [ ] roof + wall per district
- [ ] 8 decal stamps per district

### FX & UI

- [ ] discipline ground FX sheets (10)
- [ ] projectile variants (shadow, bullet)
- [ ] poi_facades (5)
- [ ] ui_chrome atlas (panels, slots, stars, cursors)
- [ ] feeding_vignette.png, mission_icons.png
- [ ] menu_bg_board.png, menu_bg_map.png

### Regenerate higher fidelity (replace JPG)

- [ ] player, props, vehicles, ground — PNG native

---

## Execution order (strict)

```
0 Recon → 1 Pipeline → 2 Manifest/PNG → 3 Spriter → 4 District kits
→ 5 Ground density → 6 Discipline VFX → 7 Cinematic → 8 UX
→ 9 PostFX → 10 QA loop → 11 Optimize → 12 Cleanup
```

Phases 4–6 can parallelize asset gen while 1–3 land in code.

---

## Signal to begin

User message equivalent to: **"The other agent is finished — execute the ultra makeover plan."**

On signal: open this file, start Phase 0, check boxes as you go, do not stop until Phase 12 complete.