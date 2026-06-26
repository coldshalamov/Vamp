# SILHOUETTE_SPEC.md — Kill the Cape

Authoritative clothing spec for the 9 humanoid archetypes rendered by
`tools/visual/blender_render_atlas.py`. Every number here is authored at
**reference build = 1.0** and is a drop-in for `loft_coat()` profile tuples,
the `front_gap` slit set, the collar/bloodstain poly predicates, and a new
per-archetype `profile["body"]` skin-radius hook.

**ART TARGET:** Dead Cells rotoscope + Vampire: the Masquerade Bloodlines urban
gothic. Cold, wet, dangerous, materially believable. Fitted modern clothing on
real bodies. VtM vampire cues = **FANGS + BLOODSTAINS**, never capes.

**FORBIDDEN:** capes, cloaks, Count-Dracula bell coats, flaring hems, smooth
featureless clay, cartoon/anime/chibi/cel-shaded.

---

## 1. Why the current renders read as capes

The long-coat loft uses a profile whose **hem is wider than the shoulders**:

```python
# CURRENT (FLARED — this is the cape):
prof = [(1.49,0.150,0.115),(1.41,0.265,0.180),(1.18,0.225,0.165),
        (0.95,0.185,0.150),(0.66,0.220,0.180),(0.34,0.275,0.220)]
#                                               ^^^^^^^^^^^^^^^^^^
# hem rx=0.275 > shoulder rx=0.265 > waist rx=0.185 -> a bell. A bell that
# widens toward the floor is a cape, not a coat.
```

Two more silhouette bugs compound it:

1. **The open slit is on the BACK.** `front_gap={16,17,18,19,20}` at `M=24`
   centers on vertex `j=18`, which sits at **−Y**. But the anatomical front is
   **+Y** (the feed row-13 lean and the walk lean both push chest/head +Y, and
   the camera azimuth offset aligns local +Y with "forward"). So the coat
   currently splits up the spine and stays sealed across the chest — the exact
   read of a closed cape worn from behind. The **front** slit set is
   `{4,5,6,7,8}` (centered on `j=6` at +Y). **Fix this in the same pass.**

2. **No collar-up, no center break, no grit.** The collar exists (poly material
   swap above z>1.42) but the bell hem dominates the read before anyone sees it.

---

## 2. The new authoring rule (paste into `loft_coat` profiles)

A coat is a **monotonically non-increasing cone of revolution from the shoulder
ring down to the hem**, with the hem landing inside a hard window:

```
RULE (every (z, rx, ry) profile, top to bottom):
  • rx is NON-INCREASING from the shoulder ring downward. Never widens.
  • hem rx  ≤  waist rx            (≤, never >  — this is what kills the flare)
  • hem rx  ≥  LEG-ENVELOPE FLOOR  (or the calves clip through the coat side)
  • ry      ≈  0.76 · rx           (front-back thinner than side-side: a body,
                                    not a barrel; ry must also be non-increasing)
```

**The leg-envelope floor is not optional.** Measured from the actual joint
coords + skin radii in `blender_render_atlas.py`:

| Hem height z | Leg outer edge `|x|+r` | Min hem `rx` |
|---|---|---|
| 0.34 (mid-calf) | 0.177 | **≥ 0.175** |
| 0.20 (lower-calf) | 0.173 | **≥ 0.172** |
| 0.10 (ankle) | 0.170 | **≥ 0.170** |

Combined with `hem ≤ waist`, this forces **waist rx ≥ ~0.19** — below that
there is no legal window and you either flare or clip. So:

- **"Straight" coat** = hold `rx` ≈ constant at the waist value from the waist
  down to the hem (a true vertical tube of the body's width). A coat that hangs
  straight *from the shoulders* would have hem ≈ shoulder width, which violates
  `hem ≤ waist` — so "straight" here means **straight from the waist**.
- **"Tapered" coat** = shrink `rx` below the waist toward the floor (stops at
  the floor). This is the fitted-predator read.

Both keep `hem ≤ waist`. Pick per archetype below.

**Validator note:** `validate_visual_assets.py` flags stick/narrow silhouettes.
The ~0.17 floor keeps every coat clear of that gate — do **not** taper tighter
than the floor to "look more fitted." Fitted comes from `ry < rx` and the front
slit, not from a pencil hem.

**Floor applies to coats that hang past the knee.** The leg-envelope floor table
is for long-coat hems at z ≤ 0.40 (the legs are the obstacle there). The shared
**jacket** hem sits at **z = 0.92 (hip height)**, where the obstacle is the
torso/hip, not the legs: the hip skin cage edge is ~0.185 but the body's Subsurf-2
modifier shrinks the rendered hull to ~0.172, which the stock jacket hem `rx=0.180`
clears. So the jacket hem `0.180` is correct **as shipped** — do not "fix" it to
the 0.183 thigh number; that table does not apply at hip height.

---

## 3. Per-archetype specs

For each archetype: the garment concept, the exact loft profile (drop into the
`if profile.get("long_coat")` / `else` jacket branch of `build_scene`), the
slit set, the body-shaping multipliers, and where fangs/bloodstains go.

Profiles below are validated against the rule: `rx` non-increasing,
`hem ∈ [floor, waist]`, `ry ≈ 0.76·rx`. The four `long_coat=True` archetypes
get new 6-tuple profiles that replace the bell. The five jacket archetypes
already taper (`0.232→0.205→0.180`, no flare) — their tuples are reaffirmed and
lightly tuned, **not** rescued from a flare they never had.

### 3.1 hero — fitted black leather longcoat, collar up

- **Concept:** Matte/semi-gloss black fitted leather longcoat hanging **straight
  to mid-calf**, high collar popped, center-front zip break open as a vertical
  slit. Edge-worn leather grain, oxidized zipper hardware. The most predatory
  silhouette in the game — tall, narrow, vertical. No flare, ever.
- **`long_coat` profile (REPLACES the bell):**
  ```python
  # hero: shoulder 0.250 -> straight tube at waist 0.190 -> mid-calf hem 0.180
  prof = [(1.49,0.150,0.114),(1.41,0.250,0.190),(1.18,0.215,0.163),
          (0.95,0.190,0.144),(0.66,0.185,0.140),(0.34,0.180,0.137)]
  # rx: 0.150,0.250,0.215,0.190,0.185,0.180  (non-increasing below shoulder ✓)
  # hem 0.180 ≤ waist 0.190 ✓   hem 0.180 ≥ floor 0.175 ✓
  ```
- **slit:** front `{4,5,6,7,8}` (corrected from `{16..20}`).
- **body (`profile["body"]`):** `{"shL":1.10,"shR":1.10,"chest":0.96,"hipC":0.90,"hipL":0.94,"hipR":0.94}` — broad shoulders, trimmed waist/hips: the inverted-triangle predator.
- **FANGS:** yes (vampire). **BLOODSTAINS:** chin/jaw + right hand/claws (feeder), plus a low-front coat smear.

### 3.2 elder — ankle-length fitted greatcoat, collar up

- **Concept:** Severe ankle-length wool/leather greatcoat, **tapered** to a
  narrow ankle hem, tall stand collar, double-breasted front read with a thin
  center slit low. Old-money menace. Pale, gaunt, the tallest mass — authority
  from height and stillness, not bulk. Still NOT a robe: the legs read through
  the lower slit when walking.
- **`long_coat` profile:**
  ```python
  # elder: shoulder 0.245 -> waist 0.198 -> ankle hem 0.172 (tapered, longer)
  prof = [(1.50,0.150,0.114),(1.42,0.245,0.186),(1.16,0.214,0.162),
          (0.90,0.198,0.150),(0.55,0.186,0.141),(0.20,0.172,0.131)]
  # rx: 0.150,0.245,0.214,0.198,0.186,0.172 (non-increasing ✓)
  # hem 0.172 ≤ waist 0.198 ✓   hem 0.172 ≥ floor@z0.20 0.172 ✓ (at the floor)
  ```
- **slit:** front `{5,6,7}` — a narrower 3-vertex slit (a fitted greatcoat barely parts).
- **body:** `{"shL":1.06,"shR":1.06,"chest":0.92,"hipC":0.88,"neck":0.86,"hipL":0.92,"hipR":0.92}` — gaunt torso, slightly stooped narrow neck; `profile["build"]` already adds his height/mass, so shape only trims.
- **FANGS:** yes (elder vampire — prominent, this is a portrait/feed archetype). **BLOODSTAINS:** subtle — old dried stain at the cuff and lower-front coat hem, not fresh.

### 3.3 hunter — fitted trench / waxed field coat, collar up

- **Concept:** Knee-length fitted waxed-cotton trench over a tactical vest, belt
  cinched (visible waist nip), **tapered** to a knee hem. Practical, militarized,
  hooded. Grime and rain-darkening on the shoulders. Reads as a professional, not
  a brawler.
- **`long_coat` profile:**
  ```python
  # hunter: shoulder 0.244 -> belted waist 0.188 -> knee hem 0.178 (tapered)
  prof = [(1.49,0.150,0.114),(1.41,0.244,0.185),(1.17,0.210,0.160),
          (0.92,0.188,0.143),(0.62,0.182,0.138),(0.40,0.178,0.135)]
  # rx: 0.150,0.244,0.210,0.188,0.182,0.178 (non-increasing ✓)
  # hem 0.178 ≤ waist 0.188 ✓   hem 0.178 ≥ floor@z0.40 0.176 ✓
  ```
- **slit:** front `{4,5,6,7,8}`.
- **body:** `{"shL":1.08,"shR":1.08,"chest":1.02,"hipC":0.96}` — capable, squared shoulders, a touch of vest bulk at the chest. (`armored=True` already adds the chest plate cube.)
- **FANGS:** no (human hunter). **BLOODSTAINS:** none of his own; splatter on the lower coat/boots is acceptable as combat wear.

### 3.4 thrall — hooded fitted jacket (FLAG CHANGE)

- **DECISION:** the task calls thrall a **"hooded fitted jacket,"** but
  `PROFILES["thrall"]` currently has `long_coat=True` (a coat). **Flip the flag:
  set `long_coat=False`** so thrall builds on the already-tapered jacket loft.
  This is the cleanest cape-kill for thrall: a jacket cannot flare. Keep
  `hooded=True`, `masked=True`.
  ```python
  # in PROFILES["thrall"]: change   long_coat=True   ->   long_coat=False
  ```
- **Concept:** Drab hooded fitted zip jacket (think modern parka shell, hood up),
  hands close, a servant's hunch. Lower-status, smaller silhouette than the
  predators. The hood + mask carry the "in thrall" anonymity.
- **profile:** uses the shared jacket branch (no per-archetype tuple needed):
  ```python
  prof = [(1.49,0.138,0.108),(1.40,0.232,0.162),(1.16,0.205,0.158),(0.92,0.180,0.148)]
  # already tapered: 0.232 -> 0.205 -> 0.180, no flare ✓
  ```
- **slit:** front `{4,5,6,7,8}` (apply the corrected front-slit to the jacket branch too — the back-slit bug affects both branches).
- **body:** `{"shL":0.96,"shR":0.96,"chest":0.96,"hipC":0.98,"neck":0.94}` — narrow, slightly hunched, unimposing.
- **FANGS:** no (a thrall is a living human servant, not yet turned). **BLOODSTAINS:** a feeder's mark — small stain at the side of the neck/collar (where the master fed), nowhere else.

### 3.5 thug — bomber jacket / hoodie

- **Concept:** Heavy bomber jacket or zip hoodie over a wide brawler's frame.
  Ribbed cuffs/hem (the jacket loft's slight taper *is* the elastic hem). Street,
  not gothic. Bulk in the shoulders and chest.
- **profile:** shared jacket branch (reaffirmed):
  ```python
  prof = [(1.49,0.138,0.108),(1.40,0.232,0.162),(1.16,0.205,0.158),(0.92,0.180,0.148)]
  ```
- **slit:** front `{4,5,6,7,8}`.
- **body:** `{"shL":1.16,"shR":1.16,"chest":1.10,"hipC":1.02}` — heaviest upper body; `build=1.16` already adds bulk, so these *shape* it toward the shoulders rather than a uniform balloon.
- **FANGS:** no. **BLOODSTAINS:** none by default (knuckle/cuff grime only).

### 3.6 gunner — leather moto jacket

- **Concept:** Fitted leather motorcycle jacket — asymmetric zip, short waist
  cut, collar up. Glossier leather than the hero's matte coat (slightly lower
  cloth roughness reads on the spec pass). Lean, mobile shooter.
- **profile:** shared jacket branch.
- **slit:** front `{4,5,6,7,8}`.
- **body:** `{"shL":1.04,"shR":1.04,"chest":1.00,"hipC":0.96}` — athletic, trim waist.
- **FANGS:** no. **BLOODSTAINS:** none by default.

### 3.7 cop — duty uniform + vest

- **Concept:** Police duty uniform: a fitted utility jacket over a stab/ballistic
  vest (the `armored=True` chest plate), duty belt bulk at the waist. Squared,
  institutional. Navy uniform cloth.
- **profile:** shared jacket branch (the vest plate sits on top via `armored`).
- **slit:** front `{4,5,6,7,8}`.
- **body:** `{"shL":1.06,"shR":1.06,"chest":1.06,"hipC":1.04,"hipL":1.02,"hipR":1.02}` — the duty-belt waist is as wide as the chest: a solid rectangular cop mass.
- **FANGS:** no. **BLOODSTAINS:** none by default.

### 3.8 swat — tactical plate carrier

- **Concept:** Bulky tactical plate carrier over fatigues, helmet
  (`helmeted=True`), balaclava (`masked=True`). The heaviest, blockiest
  silhouette — square shoulders, thick torso, no taper read because the carrier
  is a slab. Matte tactical nylon + oxidized-metal buckles.
- **profile:** shared jacket branch; the plate carrier mass comes from
  `armored=True` + the body multipliers (do NOT widen the loft hem to fake
  bulk — that re-introduces a flare).
- **slit:** front `{4,5,6,7,8}` (the carrier reads closed over it regardless).
- **body:** `{"shL":1.20,"shR":1.20,"chest":1.16,"hipC":1.04,"neck":1.08}` — broadest shoulders and a slab chest; `build=1.19` already adds height/mass.
- **FANGS:** no. **BLOODSTAINS:** none by default.

### 3.9 civilian — streetwear coat / puffer

- **Concept:** Ordinary urban streetwear — a puffer, peacoat, or zip overcoat in
  muted colors (the `CIVILIAN_TINTS` recolor handles variety). Soft, unthreatening,
  hands-in-pockets posture. Reads as a person, not a combatant.
- **profile:** shared jacket branch.
- **slit:** front `{4,5,6,7,8}`.
- **body:** `{"shL":0.98,"shR":0.98,"chest":1.00,"hipC":1.00}` — neutral, average.
- **FANGS:** no. **BLOODSTAINS:** none — civilians are prey; a *fed-on* civilian gets the neck-bite stain via the runtime, not the atlas.

---

## 4. Implementer changes (3 concrete edits to `blender_render_atlas.py`)

### 4.1 Correct the slit to the FRONT (+Y) and parameterize it

The slit set is currently hard-coded in `build_scene`:

```python
# CURRENT (back slit):
cm = loft_coat(prof, 24, {16,17,18,19,20}, "vc_coat")
```

Make it per-profile (so elder gets a narrower slit) and default to the **front**:

```python
# in build_scene, replace the loft_coat call:
slit = profile.get("front_slit", {4, 5, 6, 7, 8})   # +Y front slit (was {16..20} = back)
cm = loft_coat(prof, 24, slit, "vc_coat")
```

Then add `front_slit={5,6,7}` only to `PROFILES["elder"]` (narrow greatcoat).
All others inherit the default `{4,5,6,7,8}`. **This applies to BOTH the
long-coat and the jacket branches** — the back-slit bug is in the shared
`loft_coat` call, so fixing it here fixes every archetype.

### 4.2 Add the per-archetype `profile["body"]` skin-radius hook

Today the only per-archetype body knob is the scalar `profile["build"]`; `RADII`
is global, which is why every torso reads the same "stocky." Add an optional
per-joint multiplier dict. In `PROFILES`, add a `body=dict(...)` entry to each
archetype using the multipliers from §3 (omit it to mean "all 1.0").

Then change the skin-radius loop in `build_scene` (currently):

```python
sv = bm.skin_vertices[0].data
for i, r in RADII.items():
    rr = r * (profile["build"] ** 0.5)
    sv[i].radius = (rr, rr)
```

to consult the body dict by joint name (ORDER[i] maps index → joint):

```python
sv = bm.skin_vertices[0].data
body_mul = profile.get("body", {})
for i, r in RADII.items():
    rr = r * (profile["build"] ** 0.5) * body_mul.get(ORDER[i], 1.0)
    sv[i].radius = (rr, rr)
```

**Author shape only, never bulk.** The coat is already scaled by `build`
(linear) and the body by `build**0.5`; the multipliers in §3 are *deltas on top
of build*, so do not bake an archetype's overall size into them or it
double-scales.

### 4.3 Add fangs + bloodstain material indices (reuse the existing poly trick)

The collar already does targeted poly-material assignment; bloodstains and fangs
use the same pattern.

**Bloodstain material + coat assignment.** Add a dark-crimson dried-blood
material and assign it to **front-facing lower-coat polys** for the archetypes
flagged in §3 (hero, elder). Add to `mats` in `build_scene`:

```python
"blood": new_material("vc_blood", C(0.18, 0.012, 0.018), rough=0.55),
```

Append it as a third coat slot and key it by region (after the collar loop):

```python
coat.data.materials.append(mats["blood"])   # index 2
if profile.get("bloodstain"):
    for poly in cm.polygons:
        c = poly.center
        # low-front of the coat: a feeder's drip down the chest/belly, +Y front
        if 0.60 < c.z < 1.05 and c.y > 0.04:
            poly.material_index = 2
coat["spec"] = SPEC["cloth"]   # base; the blood mat carries its own slightly wet spec
```

Set `bloodstain=True` in `PROFILES` for **hero** and **elder** only. Also tint
the **right-hand claws** (hero) by appending `mats["blood"]` instead of
`mats["metal"]` on the inner claw of the right set, and darken the chin region of
the head sphere — but at 64–90px game scale these are sub-pixel; they pay off in
the **feed row (13)** and any close-up/portrait, not in moment-to-moment play.
Spec them, render them, don't over-invest.

**Fangs.** Build two tiny cones at the mouth, mirroring the existing claw-cone
construction, gated on a `fanged` flag. After the weapon block in `build_scene`:

```python
if profile.get("fanged"):
    parts["fangs"] = []
    for sgn in (-1, 1):
        bpy.ops.mesh.primitive_cone_add(radius1=0.006, radius2=0.0, depth=0.022,
            location=(sgn * 0.018, 0.135, 1.560))   # mouth: +Y front, just below head center
        f = bpy.context.active_object; f.name = "vc_fang"
        f.rotation_euler = (math.radians(180), 0, 0)  # point downward
        f.data.materials.append(new_material("vc_fang", C(0.92,0.90,0.86), rough=0.30))
        f["spec"] = SPEC["skin"]
        parts["fangs"].append((f, sgn))
```

Parent them to the head and follow it in `apply_pose` alongside hood/mask:

```python
if "fangs" in parts:
    for (f, sgn) in parts["fangs"]:
        f.location = j["head"] + Vector((sgn * 0.018, 0.130, -0.025))
```

Set `fanged=True` in `PROFILES` for **hero, elder, thrall**. (Thrall is a living
human in §3.4 → if you keep thrall human, set `fanged=False`; the only consumer
of fangs is the turned predator. Author's call, but be consistent with §3.4.)

Honest scope note: fangs are ~1–2px at game-display size. They exist for the
feed pose, the death/feed-row read, and future portraits. Build them, but don't
expect them to carry the silhouette — **the fitted, non-flared coat does that.**

---

## 5. Acceptance checklist (run before declaring the cape dead)

For every `long_coat` profile you paste:

1. **Monotonic:** `rx` is non-increasing from the shoulder ring (tuple index 1)
   down to the hem (last tuple). No value exceeds the one above it.
2. **Hem window:** `hem_rx ≤ waist_rx` AND `hem_rx ≥` the floor for its hem `z`
   (0.175 @ z0.34, 0.172 @ z0.20, 0.170 @ z0.10).
3. **Body, not barrel:** `ry ≈ 0.76·rx` and `ry` also non-increasing.
4. **Front slit:** the `loft_coat` call uses `{4,5,6,7,8}` (or `{5,6,7}` for
   elder), NOT `{16,17,18,19,20}`.
5. **Eye test:** render rows 0 (idle) and 9 (strike) at cols 2 (S) and 0 (E).
   The hem must not fan out below the knees; the chest must show a vertical
   center break (the front slit); the collar must stand. If the lower coat reads
   as a triangle widening to the floor, the flare is still there — re-check
   step 2.
6. **Validator:** `validate_visual_assets.py` must still pass (no stick/narrow
   flag). If it newly flags "narrow," a hem dipped below the floor — raise it,
   do not widen the shoulders.

The four edits (new long-coat profiles, front-slit fix, body multipliers,
fangs/bloodstains) are independent and can land incrementally. The profile
swap + slit fix alone kills the cape; body shaping and fangs/blood are the
quality pass on top.
