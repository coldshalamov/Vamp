# Vampire City — Character Asset Pipeline Spec

This is the production spec for animated character assets. It exists because earlier passes
shipped low-effort results (procedural "asparagus" rigs, smooth top-heavy Blender dolls, and a
single floating generated frame). None of those meet the bar. This document fixes the bar and the
process so we stop restarting.

## 1. Visual target (the bar)

- **Reference:** Vampire: the Masquerade (Bloodlines / LA by Night), Hellsing, gritty hand-painted.
- **Camera:** fixed 3/4 top-down (~40–50° above), 8 facing directions.
- **Quality:** detailed, textured, **a real face**, stylized-but-believable proportions (NOT
  top-heavy, NOT stick-leg/box-torso). Gritty/rotoscoped finish, restrained crimson + blood.
- **Animation (non-negotiable):** every actor is **animated at ~10 FPS** — at minimum idle, walk,
  attack. No static/floating single frames, ever. Feet plant; figures are grounded.

## 2. The only pipeline that delivers animated, multi-direction 2D characters

3D-render-to-sprite — the method Diablo and Dead Cells actually use. Image generation **cannot**
produce frame-coherent animation (identity/lighting drift → flicker), so it is used for **design
and textures**, never for the animation frames themselves.

```
design (image-gen, many candidates → filter)
  → proportioned 3D model (Rigify meta-rig proportions; NOT primitives-from-scratch)
  → generated textures (face + leather + skin) mapped on
  → rig (Rigify) + keyframed cycles (idle / walk / attack) authored at 10 FPS
  → render 8 directions × every frame from the 3/4 camera
  → stylize pass (painterly / rotoscope grit)
  → integrate as an animated sprite sheet; verify in-engine, grounded
```

## 3. Tools — tested strengths/weaknesses (2026-06-26)

| Tool | Image gen? | Use |
|---|---|---|
| **agy** | ✓ reliable | clean full-body character-design sheets; **modeling + texture reference** |
| **grok** | ✓ reliable | dramatic painterly final-look renders; **style/texture reference** |
| **codex** | ✗ (coding agent gpt-5.5) | not for art |
| **Blender 5.1 Rigify** | n/a | ✓ human **meta-rig = correct anatomical proportions + face bones**; generate full control rig for animation |
| Blender CPU Cycles | n/a | slow but works; render to sprites |
| `stylize_atlas.py` | n/a | ✓ painterly/ink/grit post (already built) |

Generate 5× more designs than needed and filter; agy+grok give two distinct styles to choose from.

## 4. Locked hero design

Pale gaunt lean adult-male vampire. Fitted **open** black leather longcoat to mid-calf, collar up
(coat, never a cape). Dark vest/shirt, dark trousers, heavy boots. Slicked dark hair. Fresh blood
on clawed hands. Cold blue moon key + warm sodium rim. (Reference renders in scratchpad/cmp.)

## 5. Phase plan (build ONE hero to the bar, document, then scale)

- **P0 Design + tool test** — DONE (above).
- **P1 Model** — body mesh built to **Rigify proportions**, real head/hands, decent topology. Gate:
  renders as a believable proportioned human at 80px, NOT a doll.
- **P2 Texture** — generated face + leather + skin mapped on (image-gen → projection/UV). Gate: has
  a readable face and material detail, not blank clay.
- **P3 Rig + animate** — Rigify control rig; idle + walk + attack cycles at 10 FPS, feet planted.
  Gate: the walk reads as weighted locomotion, grounded.
- **P4 Render** — 8 directions × frames from the 3/4 camera. Gate: consistent identity/lighting.
- **P5 Stylize + integrate** — grit pass; animated sprite sheet; in-engine, grounded, at 10 FPS.
  Gate: **looks cool in-game** (the only gate that counts) — confirmed with the user.
- **P6 Document + scale** — record the exact repeatable steps, then run the roster.

## 5b. VALIDATED technique — "paint the render" (the breakthrough)

Tested and working. The 3D render does NOT need to look good; it only needs correct
pose/angle/proportions. `agy` repaints it into the gorgeous VtM look while preserving the pose:

1. **Rough 3D** — proportioned figure (Rigify proportions), coat, head. Render grey/clay from the
   3/4 camera. Pose via moving the skeleton verts (idle/walk/attack frames); rotate the figure for
   each of the 8 facing directions. (Reuses `blender_render_atlas.py` pose×direction infra.)
2. **Paint each frame** — `agy --dangerously-skip-permissions -p "<reference bible img> ... repaint
   <clay frame> as the EXACT SAME character, preserve pose/angle/framing, save to <abs path>"`.
   - Anchor every frame to ONE reference paint (the "character bible") for identity consistency.
   - Per-frame works; identity holds across directions (minor variation = rotoscope boiling).
   - ~4 min/call (slow). Run in parallel/background. (Wide multi-frame "strip" paints were
     unreliable — paint per-frame.)
3. **Cut out** — flood-fill from the grey/dark background → alpha (scipy.ndimage, already built).
4. **Align + assemble** — scale to cell, feet on baseline Y=224, edge-dilate, into the 8×16 atlas.
5. **Integrate** — bind atlas; **the character material MUST be `render_mode unshaded`** (the art is
   pre-lit; the night 2D-lights + grade would otherwise crush it to a silhouette). Verify in-engine.

Tools: `agy` ✓ (paint + design), `grok` ✓ (design), `codex`/`gemini` ✗. Cutout + atlas + stylize
scripts already exist in `tools/visual/`.

## 5c. PRODUCTION STATUS + RESUME (2026-06-26)

The whole pipeline is BUILT and working end-to-end. Every step runs except the paint pass is
gated on the `agy` image-gen **daily rate limit**, which was exhausted by the day's generation
(designs + tool tests + ~6 painted frames). When quota resets, production finishes autonomously.

Done & in the repo:
- `tools/visual/render_hero_clay.py` — renders the proportioned hero in idle/walk/attack × N
  directions as rough clay (24 frames @ 4 dirs verified). Deterministic; re-runnable.
- `tools/visual/paint_grind.sh` — robust paint engine: each clay frame → `agy` repaint, separate
  process, cooldown + 3× retry, idempotent (skips done). Anchored to `assets/visual/reference/hero_bible.png`.
- `tools/visual/assemble_painted_hero.py` — cutout (scipy flood-fill) + baseline-align + 8-col atlas.
- Scene brightness lifted so pre-lit painted art reads in-engine: `hero_rim.gdshader`
  `render_mode unshaded` + `body_gain 1.85`; `post_process.gdshader` exposure 1.28 / tonemap 0.32.
- 4 painted hero directions already shipped in the live atlas (`docs/evidence/hero_painted_directions.png`).

**Tool limits learned:** `agy` = only scriptable image-gen, BUT ~1–2 images/session and a daily
rate cap (exhausted today; empty-log instant-exit = limited). `grok` = TUI only, not headless.
`codex`/`gemini` = no usable image gen. So paint throughput is the production bottleneck; the grind
must run patiently across the rate window.

**Resume (when agy quota is back):**
```bash
blender --background --python tools/visual/render_hero_clay.py -- --out <clay> --dirs 8   # clay frames
bash tools/visual/paint_grind.sh <clay> <painted> assets/visual/reference/hero_bible.png 70  # paint (hours)
python tools/visual/assemble_painted_hero.py     # -> hero_diffuse.png (update its in/out paths)
# godot --headless --import ; capture to verify (hero material is unshaded)
```

## 6. Standards (the actual problem to fix)

Every phase has a GATE that must visibly pass before moving on. Nothing is "done" until it is an
animated, textured, proportioned character that looks cool **in the game**. No shipping first-pass
output and rationalizing. If a step's result is bad, fix that step — do not silently restart the
whole approach.
