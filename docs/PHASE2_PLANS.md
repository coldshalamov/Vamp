# Phase 2 Plans — Post-Track Expansion

> **Baseline assumption:** Tracks A, B, and C from `GAME_OVERHAUL_PLAN.md` are DONE. The game now
> has: GPUParticles2D effects, CanvasItem shaders (rim-light, hit flash), LightOccluder2D shadows,
> TileMapLayer world, screen effects (vignette, bloom), parallax backdrop, per-discipline spell
> visuals, a combo trigger system with status effects, charged/channeled cast mechanics, melee
> rework, 6 enemy archetypes with telegraphs, feeding redesign (power loop, spare/kill choice,
> resonance), XP/leveling/skill tree, heat system, functional HUD (damage numbers, status icons,
> cooldowns, blood bar, health bars, XP bar, heat stars), enemy readability indicators, feeding
> UX, onboarding flow, and death explanations.
>
> Phase 2 builds ON that foundation. These two plans can run **in parallel** — Plan 1 is art
> production, Plan 2 is gameplay code. They share a small interface (a few assets serve new
> mechanics) documented in the Integration Notes at the bottom.

---

## Plan 1: Visual Asset Expansion (Revised)

### What Changed Post-Tracks

The tracks created SYSTEMS that are now starved for CONTENT:

| Track A shipped... | ...which now NEEDS: |
|---|---|
| GPUParticles2D across all combat/spell/ambient effects | **Authored particle sprite atlas** — without it, every particle is a default Godot circle/square. Blood mist, embers, smoke wisps, sparks need shaped textures. |
| TileMapLayer world rendering (multiple layers: ground, detail, walls, foreground) | **Tile art for every layer** — the renderer exists but the tiles are the gap. Without authored tiles, TileMapLayer renders... colored rectangles in a fancier way. This is now the #1 priority asset. |
| LightOccluder2D shadows + improved LightingDirector | **Authored light cone textures** — the shadow system works but every light still uses one generic circle gradient. Shaped cones make the difference between "shadows work" and "this looks like a noir film." |
| Per-discipline spell visuals (10 discipline color palettes) | **Spell-specific particle textures** — discipline colors are set, but the particle shapes within each discipline should be distinct (blood sorcery = liquid tendrils, celerity = electric streaks, obfuscate = smoke wisps). |
| Parallax city backdrop (2-3 layers, distant buildings) | **Per-district landmark silhouettes** — the parallax scrolls but shows generic cityscape. Each district needs its own skyline anchor. |
| Skeleton2D rigs OR higher-res atlases | **Feeding-specific animation frames** — lean-in, victim struggle/weaken/limp. Whether skeletal or atlas, these poses need authoring. |
| Screen effects (vignette, bloom, damage vignette) | These are shader-driven — no additional assets needed. ✅ |

| Track B shipped... | ...which now NEEDS: |
|---|---|
| 6 enemy archetypes (rusher, tank, shooter, healer, summoner, ambusher) | **Archetype visual distinction** — all 6 use existing atlas materials (thug, gunner, cop, etc.) but a rusher should LOOK fast (light gear, forward lean) and a tank should LOOK heavy (armor, shield). Overlays or new profiles. |
| Status effects (bleeding, burning, stunned, rooted, feared, mesmerized, marked, frozen, weakened, empowered) | **Status effect icon sprites** — Track C shows icons above enemies but needs authored 16×16 or 24×24 icon art for each status. |
| Gear drops with rarity tiers (common/uncommon/rare/legendary) | **Gear item icons** — every droppable item needs an icon for the pickup popup and inventory. Weapon silhouettes, cloak shapes, ring/amulet/trinket icons. Rarity border treatments (white/green/blue/purple/gold glow). |
| Skill tree with branching upgrades | **Skill tree node art** — the tree UI needs node graphics: locked (grey), available (pulsing), chosen (lit), and path-specific icons showing what each upgrade does. |
| Blood resonance (4 types: sanguine/choleric/melancholic/phlegmatic) | **Resonance aura textures** — NPCs need visible colored auras. Soft radial glow in red/orange/blue/green around their feet or as a subtle body outline. |
| Combo trigger system (hemorrhage, execute, shatter, soul_rend, pyre) | **Combo splash art** — Track C shows "COMBO: HEMORRHAGE ×1.5" as text. Authored combo name art (stylized lettering + small icon per combo) would be more impactful. |
| Heat system (5 tiers, GTA stars) | **Heat star icons** — the GTA-style stars in the HUD corner need authored art: empty star, filling star, full star, with a cracked/burning variant for max heat. |

| Track C shipped... | ...which now NEEDS: |
|---|---|
| Functional HUD (blood bar, XP bar, cooldown rings, hotbar) | **Diegetic HUD replacement art** — Track C makes it WORK, this makes it LOOK professional. Glass-tube vitae gauge, fang hunger pips, discipline-framed hotbar slots, masquerade seal. |
| Death explanation screen | **Death screen art** — themed frame, cause-of-death icons (stake, sunlight, gunshot, fang), "THE NIGHT TOOK YOU" typography treatment. |
| Level-up moment (flash, banner) | **Level-up frame art** — ornate border, discipline emblem, stat-up iconography. |

### The Revised 15 Assets (Expanded from 10)

Reordered by post-track urgency. Assets that FEED INTO track-shipped systems come first.

#### 1. Building Block Tileset (CRITICAL — Track A's TileMapLayer needs this)
**Why #1 now:** Track A converted to TileMapLayer. Without tile art, it renders nothing useful.
This is the bottleneck.

Modular 32px seamless tiles with diffuse + normal:
- **Ground layer:** asphalt (cracked, clean, wet variants), concrete sidewalk, cobblestone
  (Old Town), grated metal (Docks), painted lane markings, crosswalk stripes, manhole covers
- **Wall layer:** brick face (2-3 variants), concrete block, corrugated metal, brownstone,
  glass curtain wall. Each with a windowed variant (warm interior glow from some windows).
- **Transition tiles:** wall-to-ground edge (with shadow bake), doorway, alley mouth, awning,
  fire escape ladder base, shopfront (neon sign slot), loading dock
- **Rooftop edge:** parapet, AC unit, water tank silhouette (seen from top-down angle)
- **Foreground layer:** railing, chain-link fence top, overhanging sign, awning front edge
  (these overlap the player for depth parallax)

Autotile rules for proper edge matching. Each district gets a palette variant:
- Old Town: warm brick, cobblestone, wrought iron
- Docks: corrugated metal, concrete, rust stains, oil patches
- Red Row: painted brick, neon-lit shopfronts, wet asphalt
- Financial: glass+steel, clean concrete, brass trim

**Spec:** 32×32px tiles at 4× source (128×128 authored, downsampled). Diffuse + normal map.
Organized as Godot TileSet .tres with terrain sets for autotiling.
**Integration:** Direct consumption by Track A's TileMapLayer in WorldRenderer. Replace the
current flat-color or single-texture tile rendering.

#### 2. Particle Sprite Atlas (CRITICAL — Track A's GPUParticles2D needs this)
**Why #2:** Every GPUParticles2D node Track A shipped is currently using default textures.
Authored particle sprites are the difference between "particles exist" and "particles look good."

128×128 alpha sprites, additive-friendly, normalized for bloom:
- **Blood:** mist puff, directional splatter, drip, coagulating pool edge, arterial spray streak
- **Fire:** ember (small bright dot), flame lick, smoke wisp (grey, translucent), ash flake
- **Shadow/Void:** dark tendril segment, void particle (inverse glow — dark center), wisp
- **Electric/Celerity:** spark, lightning arc segment, speed line streak, afterimage blur
- **Earth/Potence:** debris chunk (2-3 shapes), dust cloud, crack line, pebble scatter
- **Generic:** soft glow orb (for ambient motes), star burst, ring expand, directional arrow
- **Weather:** raindrop (elongated), rain splash (ground impact ring), fog band

**Spec:** Single 512×512 atlas PNG (or 1024×1024) with 64×64 or 128×128 cells. Alpha channel
only — tinted by particle color_ramp at runtime (one atlas serves ALL disciplines).
**Integration:** Set as `texture` on every GPUParticles2D node Track A created. Each particle
system references a specific atlas cell via `tex_region`.

#### 3. Status Effect Icon Sprites (Track C's indicators need this)
**Why #3:** Track C shows status icons above enemies. Without authored icons, they're either
missing or placeholder text.

24×24px crisp pixel art, readable at game zoom:
- 🔥 `burning` — flame icon (orange/red)
- 💧 `bleeding` — blood drops (crimson)
- ⭐ `stunned` — spinning stars (yellow)
- ❄️ `frozen` — snowflake/ice crystal (cyan)
- 👁️ `marked` — eye/crosshair (gold)
- ⛓️ `mesmerized` — spiral/chains (purple)
- 💀 `weakened` — cracked shield (grey)
- ⬆️ `empowered` — up arrow/fist (green glow)
- 🌿 `rooted` — vine/roots (dark green)
- 😱 `feared` — scream face (yellow/red)

**Spec:** 24×24 with 1px dark outline for readability against any background. PNG with alpha.
**Integration:** Referenced by Track C's status indicator system in EntityRenderer/VisualFX.

#### 4. Enemy Archetype Visual Distinction (Track B's archetypes need identity)
**Why #4:** Track B added 6 enemy archetypes but they all use existing atlas materials (thug,
cop, etc.). A rusher wearing the same sprite as a tank defeats the purpose — the player can't
read the encounter at a glance.

Two approaches (choose based on Track A's animation outcome):

**If Skeleton2D shipped:** Per-archetype costume overlays on the base rigs:
- Rusher: light gear, no armor, sprint pose lean, blade or claws
- Tank: heavy coat/armor plating, shield on arm, wide stance
- Shooter: visible rifle/pistol, ammunition belt, ranged stance
- Healer: robes/coat with medical/occult symbols, staff/focus
- Summoner: hooded figure, ritual circles at feet, floating minions
- Ambusher: dark cloak, face obscured, crouching pose

**If higher-res atlas shipped:** 6 new atlas materials extending the existing pipeline:
- Each archetype gets a distinct CharacterProfile with unique colors, build, equipment
- Generated through `tools/visual/` the same way the 10 existing profiles were made
- Key differentiation: silhouette must be readable at game zoom. A tank's wide shoulders
  vs. a rusher's lean frame vs. a shooter's extended arm = instant archetype recognition.

**Spec:** Same pipeline as existing characters (768×2048 atlas, 8-dir × 16-row, diffuse +
normal + specular). 6 new profiles.
**Integration:** Map archetype → atlas_key in EntityRenderer._select_atlas_key() or equivalent.

#### 5. Rival Vampire Archetype (The defining fantasy — vampire vs. vampire)
Track B added enemy archetypes but they're all HUMAN enemies. The game is called Vampire City.
Where are the rival vampires?

Three deliverables:

**a. Elder Rival profile:** A new CharacterProfile — crimson-eyed, fanged, long dark cloak,
blood-sorcery tendril weapon, gold/crimson accents. Full 8-dir × 16-row atlas with diffuse +
normal + specular. This is the mirror-match enemy that uses YOUR powers against you.

**b. Elite-affix overlays:** Small overlay atlas (crown, rune circle, elemental aura) drawn
above elite enemies. Tinted per affix:
- Brute (red): damage aura ring
- Warded (blue): shield shimmer
- Venomous (green): poison drip particles
- Arcane (purple): rune orbit
- Enraged (orange): fire crown
Drawn by EntityRenderer when entity has an affix tag.

**c. Nemesis-scar decals:** The nemesis system (already in Sim) returns scarred enemies. Scar
overlays (ash-burned face, fang-split jaw, silver-pin wound) applied to the returning nemesis
sprite. Visual evidence that "this one remembers you."

**Spec:** Elder rival = standard atlas pipeline. Overlays = 64×64 sprite sheet. Scars = 32×32
alpha overlays positioned on face/torso region.
**Integration:** PROFILES dict, ATLAS_MATERIALS, EntityRenderer overlay layer.

#### 6. Gear Item Icons (Track B's loot drops need visual identity)
Track B added gear drops with rarity tiers. Each item the player picks up needs an icon.

**Weapon icons** (32×32, 8-12 variants):
- Knife/dagger (starting), machete, katana, claws (Protean), blood lance, shadow blade,
  stake (anti-vampire), baseball bat, fire axe, silver chain

**Armor/cloak icons** (32×32, 6-8 variants):
- Leather jacket, trenchcoat, tactical vest, ancient robe, shadow shroud, blessed vestments

**Trinket icons** (24×24, 8-10 variants):
- Ring, amulet, earring, bracelet, vial (blood potion), relic, charm, sigil stone

**Rarity border treatments:**
- Common: no border
- Uncommon: thin green glow border
- Rare: blue glow + corner ornaments
- Legendary: gold glow + animated shimmer + unique silhouette

**Spec:** 32×32 and 24×24 PNG with alpha. Dark silhouette + colored accent style (Diablo/PoE
icon language). Readable at small size.
**Integration:** Referenced by Track C's loot popup and any future inventory UI.

#### 7. Diegetic HUD Replacement Art (Make Track C's HUD look professional)
Track C shipped functional HUD elements. This replaces programmer-art bars with themed art.

- **Vitae gauge:** Glass-tube blood meter. Meniscus wobble when moving. Rising bubbles when
  full. Cracks + dim when low. Low-value pulse glow.
- **Health frame:** Ornate iron frame around HP bar. Tarnishes as HP drops.
- **Masquerade stars:** Engraved seal stars (GTA star treatment). Cracked variant when heat
  is decaying. Burning variant at max heat.
- **Hunger pips:** Fang icons (full = white fang, empty = grey outline fang). Pulse when
  very hungry.
- **Hotbar slots:** Discipline-themed frame per slot (Celerity = lightning border, Potence =
  stone border, etc.). Radial cooldown overlay. Flash-ready glow.
- **XP bar segments:** Notched iron bar with fill glow. Level marker gems.

**Spec:** 9-slice-able panels for scalability. 16×16, 32×32, 64×8 pieces. PNG + NinePatchRect
compatible. Consistent with noir palette (#08080c base, #c01028 accent, cold blue-steel trim).
**Integration:** Drop into art/ui/. Track C's HUD scenes reference these as textures.

#### 8. Urban Clutter Prop Pack (Density + environmental interaction)
Track B added environmental interaction concepts (throw dumpsters, break through doors). Those
throwable/breakable objects need visual representation.

Base-anchored billboard sprites matching existing prop style:
- **Interactive (Track B uses these):** dumpster (throwable), crates (breakable), fire hydrant
  (water hazard), trash bags (cover), police barricade (obstacle), body bag (body-carrying
  system), payphone, chain-link fence segment (breakable)
- **Decorative (density):** newspaper box, park bench, traffic cones, shopping cart, mailbox,
  parking meter, bus stop sign, potted plant, AC unit (wall-mounted), graffiti tags (wall decal)
- **District-specific:** Old Town: wrought iron fence, stone bench, cathedral notice board.
  Docks: cargo containers, rope coils, fishing nets. Red Row: velvet rope, bouncer stand,
  neon "OPEN" sign. Financial: bike rack, food cart, planter box.

**Spec:** 64×96 to 128×128 base-anchored PNG. Diffuse only (normal optional for large props).
**Integration:** PropRenderer.PLACEMENTS (extended). Interactive props need a collision/trigger
area definition matching their visual footprint.

#### 9. District Landmark Silhouettes (The city becomes legible)
Track A added parallax backdrop but it's generic cityscape. Each district needs a skyline anchor
so the player knows WHERE they are by looking at the background.

- **Old Town:** Gothic cathedral spire with rose window glow (#ff7a3c warm)
- **Red Row:** Brick building with crimson/magenta neon bands (#c01028)
- **Docks:** Smokestack + gantry crane, oxidized metal (#6f7d5a)
- **Financial:** Glass tower with vertical mullioned windows, cold cyan (#5a7090)

**Spec:** 512×768 base-anchored PNG, diffuse + specular (for neon/window glow). Silhouette-first
design — readable as pure black shape against night sky.
**Integration:** Extend Track A's ParallaxBackground with district-specific layers. Swap
landmark visibility based on current district (from SimWorld district data).

#### 10. Authored Light Cone Textures (Mood — from "lights work" to "noir")
Track A's LightOccluder2D casts shadows, but every Light2D still uses one generic circle
gradient. Shaped light cones are what make the difference.

- **Sodium streetlamp:** Elongated vertical cone, warm amber (#ffb060), hard-ish edge on sides,
  soft falloff bottom. The classic "pool of light on wet pavement" shape.
- **Neon sign wash:** Wide, shallow, colored (takes tint from sign). Hugs the wall surface.
- **Moonbeam shaft:** Cold blue (#8090b0), narrow, angled as if through a gap between buildings.
  Creates dramatic slashes of light across the street.
- **Predator aura:** Player's follow-light. Softer penumbra, slightly warm, radius matches
  Track A's player light. Feels like YOUR presence in the world.
- **Interior glow:** Warm yellow (#ffcc80), spills from windows and doorways. Rectangle-ish
  shape, not circular. Makes buildings feel inhabited.
- **Emergency flash:** Red/blue alternating (police). Harsh, rotating. Wire to heat system.

**Spec:** 256×256 greyscale PNG per shape. The gradient IS the texture — Light2D.texture.
**Integration:** LightingDirector assigns texture by light type (already parameterized per
world.lights entries — extend with a shape/texture field).

#### 11. Skill Tree Node Art (Track B's progression needs visual form)
Track B added branching skill upgrades. The skill tree UI needs graphics.

Per discipline (10 disciplines × 3 tiers = 30 base nodes + 90 branch nodes):
- **Node states:** locked (grey, padlock icon), available (pulsing border, discipline color),
  chosen (fully lit, discipline emblem), branch point (3-way split indicator)
- **Branch path icons:** small 16×16 icons that indicate what the upgrade DOES:
  - AoE expansion icon, DoT icon, burst icon, sustain icon, mobility icon, CC icon, etc.
- **Connection lines:** glowing lines between nodes in discipline color. Unlit = locked,
  lit = active path.
- **Discipline emblems:** 48×48 detailed emblem per discipline for the tree header.
  (10 discipline icons already exist at art/ui/icons/ but at basic quality — these should
  be the premium versions)

**Spec:** Node frames: 32×32 with 9-slice. Icons: 16×16 crisp. Emblems: 48×48 detailed.
**Integration:** Track C's skill tree UI (or a new SkillTreeUI scene).

#### 12. Resonance Aura Textures (Track B's blood types need visibility)
Track B added blood resonance but NPCs need a pre-feed visible indicator.

- **Sanguine (red):** Warm crimson pulse around feet, like a slow heartbeat glow
- **Choleric (orange):** Bright aggressive aura, sharp edges, fire-like
- **Melancholic (blue):** Cool soft aura, flowing/watery, calm
- **Phlegmatic (green):** Gentle green glow, steady, earth-like

**Spec:** 64×64 radial alpha sprite per type. Tinted by the resonance color. Gentle animation
via shader UV scroll or particle orbit.
**Integration:** EntityRenderer draws aura below NPC when player has Auspex active or is within
feed range. Wire to Auspex sense mode if implemented.

#### 13. Persistent Impact Decals (World memory)
Fights should SCAR the environment. Blood decal SVG source already exists at
`assets/visual/source/fx/blood_decals.svg` but hasn't been rasterized.

64×64 decal atlas extending the existing blood decal pattern:
- **Blood:** directional splatter (4 rotations), pool (2 sizes), smear (drag trail), arterial
  spray arc, handprint (feed site)
- **Damage:** bullet hole (concrete pock), claw gouge (3 parallel lines), scorch ring (fire
  spell), frost crack (ice spell), void stain (shadow spell)
- **Environmental:** cracked pavement (Potence impact), shattered glass, tire skid

**Spec:** 64×64 alpha sprites, 2-3 tint variants each. Placed into world grid at impact
positions. Fade over time (120s) to prevent infinite accumulation.
**Integration:** BloodRenderer-style persistent decal layer. Triggered by existing CueBus
events: hit.connect (blood), kill (pool), damage.dealt (type-specific).

#### 14. Dawn Sunrise & Sky Gradient (Cinematic — central tension)
Track A handles dawn sky color shift but it's a flat color lerp. Authored sky art makes the
dawn feel CINEMATIC — the thing the player DREADS.

- **Night sky:** Deep blue-black with subtle star field, cold moon disc
- **Pre-dawn (5:30):** Eastern horizon warms to indigo, stars fade
- **Dawn approach (5:45):** Horizon band of amber/gold, sky shifting to deep purple
- **Killing dawn (6:00):** Brilliant gold-white sun disc breaching horizon, sky turns warm,
  DANGER — the vampire burns

**Spec:** 1920×256 horizontal gradient strips (or 2-3 ParallaxLayer textures). Lerped based
on dawn_phase (already computed by AtmosphereDirector/nocturne_grade).
**Integration:** Sky layer behind Track A's ParallaxBackground. Lerp between night/pre-dawn/
dawn textures based on game time. The sun disc rises via Y-position animation.

#### 15. Blood Moon Event Kit (Screenshot moment — spectacle event)
Neither track covers this. An entirely new special-night event.

- **Blood moon disc:** Large crimson moon (256×256) replacing the normal moon
- **Sky tint overlay:** Full-viewport red-shift overlay (alpha 0.15) that stains everything
- **Blood sigil:** A pulsing occult sigil that appears in the sky (the game's existing sigil
  mechanic scaled to cosmic)
- **Ground blood-rain particles:** Rare crimson droplets falling (particle texture from atlas #2)
- **NPC behavior modifier flag:** Blood moon → NPCs are more aggressive, feeding gives 2× blood,
  heat rises faster — a high-risk high-reward night

**Spec:** Moon: 256×256 PNG. Overlay: shader uniform (red tint + alpha). Sigil: 128×128
animated sprite.
**Integration:** `blood_moon` flag in SimMeta, consumed by sky/atmosphere layers. Randomly
triggered (1 in 7 nights?) or tied to narrative events. Wire to AtmosphereDirector/CueBus.

### Production Order (Leverage × Urgency)

| Priority | Asset | Why |
|---|---|---|
| 1 | Building Block Tileset (#1) | Track A's TileMapLayer is EMPTY without tiles |
| 2 | Particle Sprite Atlas (#2) | Track A's GPUParticles2D uses default circles without textures |
| 3 | Status Effect Icons (#3) | Track C's status indicators need icons NOW |
| 4 | Enemy Archetype Visuals (#4) | Track B's 6 archetypes are invisible without visual distinction |
| 5 | Gear Item Icons (#6) | Track B's loot drops are meaningless without item identity |
| 6 | Diegetic HUD Art (#7) | Track C works but looks like programmer art |
| 7 | Rival Vampire (#5) | The core fantasy (vampire vs. vampire) has no face |
| 8 | Urban Clutter (#8) | World density + environmental interaction visuals |
| 9 | Light Cones (#10) | Mood upgrade — from "lights work" to "noir" |
| 10 | Resonance Auras (#12) | Blood type visibility for strategic feeding |
| 11 | Impact Decals (#13) | World memory — fights scar the environment |
| 12 | Landmarks (#9) | District identity in the parallax layer |
| 13 | Skill Tree Art (#11) | Progression UI treatment |
| 14 | Dawn Sky (#14) | Cinematic dawn pressure |
| 15 | Blood Moon (#15) | Special event spectacle |

---

## Plan 2: Game-Feel Mechanics (Revised)

### What Track B Already Shipped (Don't Rebuild These)

| Mechanic from original list | Status |
|---|---|
| Telegraphed enemy attacks w/ dodge windows (#10) | **SHIPPED** by Track B. Enemy telegraphs with 0.25-0.5s wind-up, CueBus `enemy.telegraph` event. |
| Kill-streak counter (#19) | **SUBSUMED** by momentum meter below. |
| Stamina bar (#20) | **REJECTED** — blood IS the resource. Adding stamina confuses the economy. |
| Charged attacks (#3 "charge-and-release blood lance") | **PARTIALLY SHIPPED** — Track B added charged cast mechanic type. The specific blood lance with aim+pierce+overcharge is a particular ability that uses the system. Build it as content, not as a new system. |

### Re-Scored Mechanics (Post-Track B Baseline)

The scoring axes stay the same (fun-first, 11 axes, weights sum to 100%). But the scores shift
because Track B changed the baseline — telegraphs are free, combos exist, cast variety exists.
Mechanics that BUILD ON the new foundation score higher. Mechanics that duplicate it score 0.

| Rank | Mechanic | Score | Status |
|---|---|---|---|
| 1 | Perfect-dodge "witch-time" | **5.0** | NOT in any track. The #1 game-feel mechanic in action games. |
| 2 | Momentum/Frenzy escalation meter | **4.85** | EXTENDS Track B's flow_stacks. Makes the invisible visible. |
| 3 | Perfect-timing melee (gulp-DNA in combat) | **4.60** | EXTENDS Track B's melee rework. Adds a timing skill floor. |
| 4 | Counter-riposte post-dodge | **4.45** | SYNERGIZES with #1. Natural extension of witch-time. |
| 5 | Launch + juggle | **4.20** | FRESH. Adds a vertical combo dimension. |
| 6 | Flow-storm finisher (spend meter) | **4.05** | EXTENSION of #2. The payoff for building momentum. |
| 7 | Cleave-through-crowds chain | **3.90** | EXTENDS Track B's melee. Hitting multiple enemies per swing. |
| 8 | Blood-pool power zones | **3.75** | FRESH + cheap. SimWorld already has blood grid. Stand in blood = buff. |
| 9 | Grab & throw into hazards | **3.60** | FRESH. Environmental interaction from the overhaul plan. |
| 10 | Rhythm-cast to heartbeat | **3.45** | FRESH. Cast in time with heartbeat BPM for bonus. Unique to vampire. |
| 11 | Aim weak-points (heart/head shots) | **3.30** | FRESH but complex. Needs entity hit-zone system. |
| 12 | Directional combos (fwd/back attacks) | **3.15** | FRESH. Age of Conan DNA. |
| 13 | Slow-mo aim mode | **2.80** | Partially subsumed by witch-time. Lower priority. |
| 14 | Shove/kick knockback | **2.65** | FRESH but simple. Environmental kill setup. |
| 15 | QTE execution finishers | **2.40** | FRESH. Finisher animation on low-HP enemies. |
| 16 | Target-lock toggle | **2.10** | QoL, not game-feel. Low priority. |

### The Top 6 — Detailed Specs (Adapted to Post-Track Systems)

#### #1: Perfect-Dodge "Witch-Time" (Score: 5.0)

**The pitch:** Dash through an enemy attack during the last 6 ticks (100ms) before it connects →
time slows to 0.3× for 60 ticks (1s), screen desaturates to crimson, and a counter-attack window
opens where all your attacks deal 1.5× damage. The player WANTS enemies to attack them. Dodging
becomes an offensive verb, not a defensive one.

**Why it's #1:** Hades, Bayonetta, and Dead Cells all build on this because it converts
"don't get hit" from a passive goal into an active, greedy, addictive one. The player leans
FORWARD. Every ingredient already exists in the post-track codebase:
- I-frame dashes (cel_dash, Track B's melee has dodge)
- Enemy telegraphs (Track B ships these with timing data)
- Present-only slow-mo (VisualFX.set_time_scale / Engine.time_scale)
- Hit detection with timing (ImpulsePhysics)
- Status effects (Track B's framework can apply "witch_time_active" as a timed buff)
What's MISSING is the trigger that rewards proximity-to-danger.

**Sim-side implementation (src/sim/ — deterministic):**
```
# In ImpulsePhysics or Sim, when an enemy attack resolves:
# Check if player dashed within WITCH_TIME_WINDOW ticks of the attack connecting
const WITCH_TIME_WINDOW := 6  # ~100ms at 60Hz
const WITCH_TIME_DURATION := 60  # ~1s

func _check_witch_time(player: SimEntity, attack_tick: int) -> bool:
    if player.last_dash_tick > 0 and (attack_tick - player.last_dash_tick) <= WITCH_TIME_WINDOW:
        player.apply_status("witch_time", WITCH_TIME_DURATION, 1.0, player.eid)
        # witch_time status: +50% damage dealt, enemies slowed to 0.3× speed
        CueBus.emit("witch_time.trigger", { entity_id: player.eid, pos: player.pos })
        return true  # attack whiffed — player dodged perfectly
    return false
```

**Presentation-side (consumes CueBus — Track A territory):**
- `witch_time.trigger` → screen desaturates, time_scale drops to 0.3, crimson vignette,
  dramatic sound sting, brief camera zoom
- While `witch_time` status active → all player attacks have enhanced trail VFX
- On expire → time snaps back, color returns, whoosh sound

**CueBus events (add to contract):**
```
witch_time.trigger   { entity_id, pos }
witch_time.expire    { entity_id }
```

**Design notes:**
- The 6-tick window is tight enough that it feels EARNED, not free. Skilled players will
  learn to bait enemy telegraphs and dash through them on purpose.
- Stacks with combo triggers: witch-time + hemorrhage combo = devastating burst.
- Does NOT break determinism — it's a status effect check, pure integer math.

#### #2: Momentum / Frenzy Escalation Meter (Score: 4.85)

**The pitch:** A visible meter (0-100) that fills with combat actions and drains on inactivity or
taking damage. As it climbs, the game TRANSFORMS: movement accelerates, attack speed increases,
VFX intensify, heartbeat BPM rises. At 100, you enter FRENZY — 5 seconds of free cancels,
lifesteal, enhanced VFX, screen-wide crimson tint. The Hotline Miami / Sifu / Devil May Cry
loop: ride the high, don't get hit, keep pushing.

**Why it's #2:** Track B shipped flow_stacks but they're invisible and passive. A meter that
visibly transforms game-feel as it fills is the dopamine engine combat is missing. It gives every
fight a RISING ARC instead of a flat line. The player SEES themselves getting better mid-fight.

**Sim-side implementation:**
```
# On SimPlayer:
var momentum: float = 0.0
const MOMENTUM_MAX := 100.0
const MOMENTUM_DECAY_IDLE := 2.0   # per second when not fighting
const MOMENTUM_DECAY_HIT := 30.0   # instant loss on taking damage
const FRENZY_THRESHOLD := 100.0
const FRENZY_DURATION := 300       # 5 seconds at 60Hz

# Momentum gain sources:
# hit.connect → +5 momentum
# kill → +15 momentum
# combo.trigger → +10 momentum
# perfect dodge (witch-time) → +20 momentum
# feed.gulp.perfect → +10 momentum

# Momentum effects (continuous, scaled by momentum/100):
# move_speed: base × (1.0 + momentum/100 × 0.3)  → up to +30% at max
# attack_speed: base × (1.0 + momentum/100 × 0.2) → up to +20% at max

# Frenzy state (momentum >= 100, lasts FRENZY_DURATION ticks):
# All attacks have lifesteal (15% damage → blood)
# Ability cooldowns reduced 50%
# Immune to stagger
# Momentum locked at 100, drains after frenzy ends
```

**Presentation-side:**
- Meter HUD element (Track C's hotbar area — a rising bar alongside blood)
- As meter fills: subtle screen saturation increase, heartbeat BPM rises (AudioDirector),
  character gets faint aura glow (intensity = momentum/100)
- At 80+: screen edges pulse, particles orbit player, combat music intensifies
- FRENZY trigger: flash, screen goes deep crimson tint, "FRENZY" slam text, beast-mode
  visual transformation (eyes glow, aura erupts)
- On frenzy end: snap back, desaturation, exhaustion beat

**CueBus events:**
```
momentum.changed     { entity_id, old_val, new_val, max_val }
frenzy.trigger       { entity_id, pos, duration }
frenzy.expire        { entity_id }
```

**Design notes:**
- Taking damage TANKS momentum (−30 instant). This creates the core tension: aggression
  builds the meter, but getting sloppy resets your progress. You're INCENTIVIZED to dodge
  perfectly (witch-time!) to maintain your streak.
- Frenzy + witch-time + combo triggers = the triple-layer skill ceiling. A master player
  chains: witch-time dodge → combo detonation → momentum surge → frenzy → devastating burst.
- Synergizes with Track B's feeding: frenzy lifesteal reduces need to feed mid-combat,
  but STARTING a fight well-fed (high blood) lets you cast more → build momentum faster.

#### #3: Perfect-Timing Melee — Gulp-DNA in Combat (Score: 4.60)

**The pitch:** Track B shipped melee rework (light/heavy/combo). This adds a timing layer:
each swing has a "perfect timing" window (like the gulp window in feeding). Hit the next attack
input during the 4-tick sweet spot between swings → the next attack is faster and stronger.
Miss the window → normal attack. Hit too early → attack cancels (punished for button mashing).

**Why it's #3:** The gulp timing minigame is the game's most original mechanic. Applying that
DNA to ALL melee combat turns every swing into a micro-decision. Button mashers get normal
damage. Rhythm players get 1.5× damage and faster chains. It's the same principle as parry
timing in Souls games: the skill floor is "press attack," the skill ceiling is "press attack
at exactly the right moment."

**Sim-side implementation:**
```
# Extend Track B's melee combo system:
const PERFECT_WINDOW := 4    # ticks (67ms) — same as gulp window DNA
const EARLY_CANCEL := 8      # if you input attack this many ticks before the window → cancel

# On melee attack:
# Record attack_end_tick (when swing animation completes)
# Perfect window = [attack_end_tick - PERFECT_WINDOW, attack_end_tick]
# If next attack input lands in window:
#   → next attack speed × 0.7 (30% faster), damage × 1.5
#   → emit combo.trigger with combo_name "perfect_chain"
#   → increment flow_stacks (Track B)
# If next attack input lands in [attack_end_tick - EARLY_CANCEL, window_start]:
#   → cancel current attack, brief stagger (punish mashing)
# If input after window: normal next attack
```

**Presentation-side:**
- During the perfect window: brief flash/pulse on the weapon (visual timing cue)
- On perfect chain: satisfying crunch sound, weapon trail intensifies, "PERFECT" text flash
- On early cancel: stumble animation, weapon spark (whiff)
- Chain counter: "×2" "×3" "×4" building in the corner as consecutive perfects land

**CueBus events:**
```
melee.perfect_chain  { entity_id, chain_count, damage_bonus }
melee.early_cancel   { entity_id, pos }
```

#### #4: Counter-Riposte Post-Dodge (Score: 4.45)

**The pitch:** After a perfect dodge (witch-time trigger), your NEXT melee attack within 30
ticks is a guaranteed critical hit with a unique riposte animation — you dash THROUGH the
enemy's attack and immediately strike back. It's the payoff for #1: witch-time gives you the
window, riposte gives you the punish.

**Sim-side:** When witch_time status is applied, set `player.riposte_ready = true`. Next melee
attack while riposte_ready → guaranteed crit (2× damage), consumes riposte_ready. Emit
`melee.riposte` cue.

**Presentation-side:** Unique riposte animation (quick diagonal slash), dramatic camera angle
shift, enemy stagger-back, enhanced blood spray. If Track A shipped Skeleton2D, this is a
distinct AnimationPlayer clip.

#### #5: Launch + Juggle (Score: 4.20)

**The pitch:** Certain abilities launch enemies into the air (metaphorical — top-down game shows
this as a "knocked up" state where the enemy floats slightly above their shadow and can't act).
While airborne, follow-up attacks deal bonus damage and extend air time. Chain enough hits →
enemy never touches the ground. Devil May Cry in 2D.

**Sim-side:** New status `launched` (duration 30 ticks). Launched entities: can't act, take 1.3×
damage, each hit extends launch by 5 ticks (capped at 60 total). Potence slam, shove/kick, and
certain melee heavies can launch. Gravity: after duration expires, entity "lands" (brief stun).

**This creates a combo flowchart:**
Stun → Launch (Potence) → Juggle (melee chain with perfect timing) → Witch-time dodge the
NEXT enemy's attack → Riposte → Momentum surge → Frenzy.

That's 6 interlocking systems creating one emergent combat sequence. THAT is what makes combat
feel like Hades instead of a clicker.

#### #6: Flow-Storm Finisher (Score: 4.05)

**The pitch:** When the momentum/frenzy meter (#2) is above 80, a new ability becomes available:
BLOOD STORM. Press the finisher key → spend the entire meter → devastating screen-clearing AoE
that deals damage proportional to how full the meter was. The more you've earned, the bigger the
payoff. It's the Limit Break / Mega Man X charge shot / Hades Call.

**Sim-side:** New action `flow_storm`. Requires momentum >= 80. Damage = base × (momentum/100).
AoE radius = 128 + (momentum/100 × 64). Costs ALL momentum (resets to 0). Applies `weakened`
status to all survivors.

**Presentation-side:** Camera pulls out slightly (capture the scale), blood erupts in a radial
wave (GPUParticles2D), screen shakes hard, all enemies stagger. Enemy death particles cascade.
Brief slow-mo on the explosion frame. Then silence. The aftermath.

### The Complete Combat Loop (All 6 Integrated)

Here's what a skilled player's 15 seconds of combat looks like with all mechanics active:

1. **Enter encounter** — 4 enemies (tank + 2 rushers + healer). Momentum at 0.
2. **Assess** — identify the healer in back. Plan: CC tank, AoE rushers, dash to healer.
3. **Root the tank** (shadow tendril) → **AoE the rushers** (Potence slam, launches them)
4. **Juggle one rusher** with perfect-timing melee chains (×1, ×2, ×3 — momentum climbing)
5. Rusher #2 swings → **perfect dodge** → **WITCH-TIME** → screen goes crimson, time slows
6. During witch-time: **riposte** the rusher (guaranteed crit) → **Blood Bolt** the healer
   (she's marked from Auspex) → **COMBO: SOUL REND** detonates → healer dead
7. Witch-time expires. Momentum at 85. **FRENZY TRIGGER** → lifesteal, free cancels
8. **Clean up** tank and last rusher during frenzy (attacks are fast, healed by lifesteal)
9. Momentum at 95 from the killing spree. **FLOW STORM** → spend meter → radial blood wave
   finishes everything. Screen shakes. Silence.
10. **Feed** on the last surviving civilian who watched. Choleric blood → +30% spell damage.
    Blood refilled. Ready for the next encounter.

Total time: ~15 seconds. Decisions made: ~20+. Systems engaged: 6 interlocking. THIS is
Diablo/Hades-level combat.

### New CueBus Events (Add to Contract)

```
witch_time.trigger   { entity_id, pos }
witch_time.expire    { entity_id }
momentum.changed     { entity_id, old_val, new_val, max_val }
frenzy.trigger       { entity_id, pos, duration }
frenzy.expire        { entity_id }
melee.perfect_chain  { entity_id, chain_count, damage_bonus }
melee.early_cancel   { entity_id, pos }
melee.riposte        { entity_id, target_id, damage }
launch.start         { entity_id, target_id, pos }
launch.juggle_hit    { entity_id, target_id, air_time_remaining }
launch.land          { entity_id, pos }
flow_storm.trigger   { entity_id, pos, radius, damage }
```

---

## Integration Notes (Where Plans 1 & 2 Overlap)

These are the specific points where the visual asset work and the gameplay mechanic work
need to coordinate:

| Mechanic (Plan 2) | Asset Required (Plan 1) | Notes |
|---|---|---|
| Witch-time | Particle atlas (#2): crimson desaturation particles, time-distortion effect | Could be shader-only (crimson tint + time_scale), particles are bonus |
| Momentum/Frenzy meter | HUD art (#7): momentum bar design, frenzy frame treatment | The bar design is part of the diegetic HUD set |
| Momentum/Frenzy VFX | Particle atlas (#2): aura particles, frenzy eruption, beast-mode glow | Uses existing particle system, just needs the right textures |
| Perfect-timing melee | No new assets needed | Visual feedback is shader flash + existing weapon trail |
| Counter-riposte | Feeding animation frames or atlas additions | Riposte pose needs to be in the character animation set |
| Launch + juggle | No new assets needed | Shadow-offset effect is a draw_circle below the sprite |
| Flow Storm finisher | Particle atlas (#2): blood wave ring, aftermath residue decal | Big radial particle effect + ground decal from impact atlas (#13) |
| Blood-pool power zones (#8 from ranked list) | Impact decals (#13): blood pool texture variants | Player stands in blood pool → buff visual needs pool glow |

**Parallelization:** Plans 1 and 2 can run concurrently. Plan 1 produces assets that Plan 2's
presentation layer consumes, but Plan 2's SIM-SIDE work is asset-independent. Sequence: start
both, then do a final integration pass to wire Plan 2's new CueBus events to Plan 1's assets.

---

## Agent Prompts

### Plan 1 Agent Prompt — Visual Asset Production

```
You are producing visual assets for Vampire City, a Godot 4.7 / GDScript top-down vampire ARPG.
The game just completed a major engine overhaul (Tracks A/B/C) that shipped: GPUParticles2D
effects, CanvasItem shaders, LightOccluder2D shadows, TileMapLayer world rendering, combo-based
combat with status effects, 6 enemy archetypes, feeding redesign, functional HUD with damage
numbers/status icons/cooldowns/health bars/XP bar. Your job is to fill the CONTENT GAP — the
systems exist but are starved for authored art.

READ THESE FILES FIRST:
1. docs/PHASE2_PLANS.md — Plan 1 section. Your full asset list with specs and integration points.
2. docs/GAME_OVERHAUL_PLAN.md — the overhaul that just shipped. Understand what systems exist.
3. tools/visual/visual_asset_core.py — the SVG generation pipeline for character atlases.
4. tools/visual/rasterize_visual_assets.py — SVG→PNG via Chromium/Playwright.
5. src/present/CharacterAtlas2D.gd — character rendering. Understand PROFILES, atlas format.
6. src/present/WorldRenderer.gd — world rendering with TileMapLayer. Understand tile format.
7. src/present/EntityRenderer.gd — entity rendering. Understand overlay/indicator system.

THE ART CONTRACT (match existing style):
- Noir palette: #08080c (near-black base), #c01028 (crimson accent), cold blue-steel trim
- Realistic adult proportions (not chibi/cartoon)
- Cold moon key light + warm practical rim light
- Blue-black family of darks (never pure black, never warm shadows)
- All authored at 4× source resolution, downsampled once for production
- PBR where applicable: diffuse + normal + specular (character atlases have all three)
- Alpha-friendly: assets must composite cleanly over the dark game world

PRODUCTION ORDER (do in this sequence — each unlocks the next):
1. Building Block Tileset — 32px seamless tiles for TileMapLayer (ground, walls, detail,
   foreground layers). 4 district palette variants. Diffuse + normal. Autotile-ready.
2. Particle Sprite Atlas — 128×128 alpha sprites for GPUParticles2D (blood, fire, shadow,
   electric, earth, weather, generic). Single tinted atlas, colored at runtime.
3. Status Effect Icons — 24×24 crisp icons for all 10 status effects Track B added.
4. Enemy Archetype Visuals — 6 new CharacterProfiles for rusher/tank/shooter/healer/
   summoner/ambusher via the existing SVG pipeline. Distinct silhouettes.
5. Gear Item Icons — 32×32 weapon, armor, trinket icons with rarity border treatments.
6. Diegetic HUD Art — glass-tube vitae gauge, masquerade stars, hotbar frames. 9-slice.

Items 7-15 (rival vampire, clutter props, light cones, resonance auras, impact decals,
landmarks, skill tree art, dawn sky, blood moon) follow in the order specified in the plan.

PIPELINE:
For character atlases: extend tools/visual/ pipeline (add new CharacterProfile → generate
SVG → rasterize → create .tres CanvasTexture). Same 768×2048 format, 8-dir × 16-row.

For tiles/icons/particles/HUD: create SVG source files in assets/visual/source/, rasterize
to PNG, create Godot resource files (.tres) where needed.

For TileSet: create a Godot TileSet resource (.tres) with terrain sets for autotiling.
Multiple layers (ground, wall, detail, foreground) as separate TileMapLayer nodes.

VERIFICATION:
- LOCAL WINDOWS SAFETY: do not run raw Godot/windowed capture on this machine without explicit
  user approval. If approved, use `PlayGame.bat` for the normal full-presentation game and stop
  immediately on memory growth. `PlayGame.bat --safe` is only an emergency reduced-visual fallback.
  Does it look right? Is it readable at game zoom? Does it match the noir palette?
- Character atlases: verify all 16 rows render correctly in CharacterAtlas2D.
- Tiles: verify autotiling works at district boundaries.
- Particles: verify they look good when spawned by GPUParticles2D (not just as static images).
- Icons: verify they're readable at 24×24 against both dark ground and bright effects.

DO NOT:
- Modify gameplay logic (src/sim/, src/entities/)
- Change existing art that's working — only ADD new assets
- Use placeholder rectangles — every asset should be authored to the noir standard
- Skip the 4× source → downsample step (prevents aliasing artifacts)
```

### Plan 2 Agent Prompt — Game-Feel Mechanics

```
You are adding game-feel mechanics to Vampire City, a Godot 4.7 / GDScript top-down vampire
ARPG. The game just completed a major engine overhaul (Tracks A/B/C) that shipped:

ALREADY EXISTS (do not rebuild):
- Status effects: bleeding, burning, stunned, rooted, feared, mesmerized, marked, frozen,
  weakened, empowered. Framework in SimEntity with apply/tick/expire + CueBus events.
- Combo triggers: hemorrhage, execute, shatter, soul_rend, pyre. Check target status on hit
  for bonus damage. CueBus combo.trigger event.
- Cast mechanics: instant (cooldown), charged (hold to power, hit interrupts), channeled
  (hold for continuous effect, drains blood/tick).
- Melee rework: light attack (fast, free), heavy attack (slow, free, telegraph), combo string
  (light→light→heavy). Flow stacks reward timing.
- Enemy telegraphs: 0.25-0.5s wind-up on heavy attacks, CueBus enemy.telegraph event.
- 6 enemy archetypes: rusher, tank, shooter, healer, summoner, ambusher.
- Feeding redesign: power loop, spare/kill choice at 70%, resonance buffs, non-combat approaches.
- XP/leveling, skill tree branching, heat system.
- Visual feedback: damage numbers, status icons, cooldown display, blood bar, health bars.

YOUR JOB — add 6 game-feel mechanics that BUILD ON this foundation:

READ THESE FILES FIRST:
1. docs/PHASE2_PLANS.md — Plan 2 section. Full specs for all 6 mechanics.
2. docs/GAME_OVERHAUL_PLAN.md — the overhaul that shipped. Understand the architecture.
3. src/sim/Sim.gd — main simulation loop. Your changes go here.
4. src/entities/SimPlayer.gd — player entity. Your changes go here.
5. src/entities/SimEntity.gd — base entity with status effects. Extend this.
6. src/sim/ImpulsePhysics.gd — physics/hit detection. Witch-time check goes here.
7. src/present/CueBus.gd — event bus. Register new events here.

ARCHITECTURE RULES (same as Track B):
1. DETERMINISM IS SACRED — LCG RNG only, no randf/randi/Time.*, 20-run hash must hold.
2. CueBus events: emit all new events through CueBus with the EXACT names from the plan.
3. Do NOT touch src/present/ except CueBus.gd event registration.

THE 6 MECHANICS (in priority order):

1. PERFECT-DODGE WITCH-TIME
   Dash through an enemy attack in the last 6 ticks before it connects → witch_time status
   (60 ticks). During witch-time: enemies move at 0.3× speed, player deals 1.5× damage.
   Implementation: in the attack resolution code, check if player.last_dash_tick is within
   WITCH_TIME_WINDOW of the attack. If yes → apply witch_time status, emit witch_time.trigger.
   The presentation layer handles the slow-mo visual — you handle the gameplay effects (damage
   bonus, enemy speed reduction via status).

2. MOMENTUM / FRENZY ESCALATION METER
   Float 0-100 on SimPlayer. Gains: hit (+5), kill (+15), combo (+10), witch-time (+20),
   perfect gulp (+10). Decays: 2/sec idle, -30 instant on taking damage.
   Continuous effects (scaled by momentum/100): move_speed up to +30%, attack_speed up to +20%.
   At 100 → FRENZY for 300 ticks: lifesteal 15%, cooldowns halved, stagger immune.
   Emit momentum.changed on every change, frenzy.trigger/expire at thresholds.

3. PERFECT-TIMING MELEE (GULP-DNA IN COMBAT)
   Each melee swing has a 4-tick perfect window at the end. Next attack input during window →
   next swing is 30% faster and 50% stronger, emit melee.perfect_chain. Input too early
   (8 ticks before window) → cancel + brief stagger, emit melee.early_cancel.
   Consecutive perfects build a chain counter (×2, ×3, ×4...).

4. COUNTER-RIPOSTE POST-DODGE
   After witch-time triggers, set riposte_ready flag. Next melee attack while riposte_ready →
   guaranteed crit (2× damage), unique attack properties (faster, wider arc), consumes flag.
   Emit melee.riposte. Natural reward for perfect dodging.

5. LAUNCH + JUGGLE
   New status: launched (30 ticks). Launched entities can't act, take 1.3× damage, each hit
   extends launch by 5 ticks (cap 60). Abilities that launch: pot_slam, heavy melee, shove.
   On launch expire → entity "lands" with brief stun (10 ticks). Emit launch.start,
   launch.juggle_hit, launch.land.

6. FLOW-STORM FINISHER
   New action: flow_storm. Requires momentum >= 80. AoE radius 128 + (momentum% × 64).
   Damage = base × momentum%. Costs ALL momentum. Applies weakened to survivors.
   Emit flow_storm.trigger. This is the Limit Break payoff for building momentum.

NEW CUEBUS EVENTS (register these):
witch_time.trigger, witch_time.expire, momentum.changed, frenzy.trigger, frenzy.expire,
melee.perfect_chain, melee.early_cancel, melee.riposte, launch.start, launch.juggle_hit,
launch.land, flow_storm.trigger

VERIFICATION:
- LOCAL WINDOWS SAFETY: do not run raw Godot or recursive GUT on this machine. Use
  `powershell -ExecutionPolicy Bypass -File .\scripts\RunGutSafe.ps1` for local checks.
  Full recursive GUT belongs in CI or requires an explicit `VAMP_ALLOW_FULL_GUT=1` override.
- Write NEW GUT tests for each mechanic:
  * Witch-time: dash at tick T, attack resolves at T+5 (within 6-tick window) → witch_time applied
  * Witch-time: dash at tick T, attack resolves at T+10 (outside window) → no witch_time
  * Momentum: hit 3 enemies → momentum = 15, take damage → momentum drops by 30
  * Frenzy: momentum reaches 100 → frenzy triggers, lasts 300 ticks, lifesteal active
  * Perfect melee: input during 4-tick window → chain counter increments, damage boosted
  * Perfect melee: input too early → cancel, no chain
  * Riposte: witch_time active → next melee is crit, riposte_ready consumed
  * Launch: pot_slam on entity → launched status, hit during launch extends duration
  * Flow storm: momentum 90 → flow_storm → AoE deals damage, momentum resets to 0
- DETERMINISM: 20-run hash check with these mechanics active.
- Do not launch locally unless the user explicitly asks. If playtesting is approved, use
  `PlayGame.bat` for the normal full-presentation game, fight enemies, try to chain witch-time → riposte → momentum →
  frenzy → flow storm. Does it feel like Hades? If not, tune the numbers.

DO NOT:
- Rebuild status effects, combo triggers, or cast mechanics (Track B shipped these)
- Touch presentation files (src/present/) except CueBus.gd
- Add new enemy types or abilities (this is game-FEEL, not game-CONTENT)
- Break determinism
```

---

## Launch Checklist

1. Verify Tracks A/B/C are complete (play the game, confirm all systems work)
2. Launch Plan 1 agent (visual assets) and Plan 2 agent (game-feel mechanics) in parallel
3. After both complete: integration pass to wire Plan 2's CueBus events to Plan 1's
   particle/icon assets
4. Play the game. Does combat feel like Hades? Does the world look like a real city?
   Do you want to play for 5 more minutes?
