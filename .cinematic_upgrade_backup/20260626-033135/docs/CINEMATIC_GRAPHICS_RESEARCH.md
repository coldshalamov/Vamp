# Cinematic graphics / animation / physics research for Vampire City

## Executive decision

Do **not** migrate the game again. The current project already has the valuable part: a deterministic 60 Hz simulation, frame-data actions, tested combat, AI, powers, heat, and persistence. The graphics problem is a presentation-layer problem. Moving the backend into a different scene architecture or replacing the 2D simulation with a 3D character-controller stack would create the exact failure mode this project has already suffered: apparent visual ambition purchased by losing working mechanics.

The selected path is a staged hybrid:

1. **Now:** continuous procedural 2.5D character meshes rendered in CanvasItem, driven directly by existing simulation state.
2. **Next asset pass:** authored weighted `Polygon2D`/`Skeleton2D` skins or 3D-to-2D baked material atlases can replace individual mesh surfaces without changing the pose driver or simulation.
3. **Optional later:** a true 3D presentation viewport may be explored behind the same read-only entity adapter, but only after a parity harness proves that no gameplay feature is lost.

This is not the absolute ceiling of visual fidelity. It is the highest-leverage route that substantially changes the screen now while respecting the architecture that already works.

## Constraints discovered in the repository

- Godot 4.7, GL Compatibility renderer.
- 1280×720 fixed design viewport.
- Fixed 60 Hz authoritative simulation.
- `Sim` owns mutation; scene nodes are views.
- `ActionDef` already exposes startup, active, recovery, cancel windows, hitstop, damage, range, and cues.
- `SimEntity` exposes position, velocity, facing, radius, action frame, hitstop, knockback, faction, AI state, statuses, equipment tags, and projectile behavior.
- `GameRenderer.gd` already isolates world, entity, lighting, camera, world FX, post-grade, and UI.
- Existing `EntityRenderer.gd` is the visual bottleneck: it composes characters largely from circles and a few polygons.

That makes the correct seam unusually clear: replace the entity presentation and enrich projectile behavior without touching the rest of the game.

## Techniques evaluated

### 1. Conventional hand-authored sprite sheets

**Strengths:** excellent painterly results, cheap runtime, straightforward directional readability.

**Failure modes here:** a serious top-down action RPG needs multiple directions, locomotion blends, weapon sets, hit reactions, feeding, finishers, powers, status poses, and dozens of enemy variants. A small 4–8 frame sheet will repeat visibly and produce the same floating-cardboard result the project is escaping. Generated frames also drift in costume, anatomy, lighting, and camera angle unless a strict production pipeline is used.

**Verdict:** viable only with a real art pipeline and a large animation budget. Not selected as the immediate fix.

### 2. Cutout animation with `Skeleton2D`, `Bone2D`, and weighted `Polygon2D`

**Strengths:** native Godot workflow, continuous interpolation, reusable animation graphs, deformable clothing, replaceable skins, good editor tooling.

**Failure modes here:** it still requires coherent authored meshes, weights, pivots, attachments, and animations. Agents can wire the system but cannot conjure production-quality anatomy and materials by connecting a few body-part images.

**Verdict:** the best long-term authored-asset destination. The delivered procedural pose system is intentionally compatible with this direction: its joint semantics can be mapped to a future `Skeleton2D` rig.

Reference: Godot `Skeleton2D` class documentation: https://docs.godotengine.org/en/stable/classes/class_skeleton2d.html

### 3. Full 3D characters and environments

**Strengths:** physically based materials, real depth, dynamic lighting, animation blending, IK, ragdolls, and a much higher fidelity ceiling.

**Failure modes here:** a full conversion changes camera, collisions, navigation, occlusion, animation import, content scale, combat readability, and performance assumptions. It is not a graphics dependency; it is a second game implementation. A mixed 3D character viewport is possible, but it introduces synchronization, depth-sorting, shadow, picking, and export complexity.

**Verdict:** rejected as the immediate intervention. A later 3D presentation prototype must be a replaceable view adapter, not a rewrite of `Sim`.

### 4. 3D-to-2D baking

Render high-quality 3D characters offline into directional animation atlases, including albedo, normal, depth, and emissive channels. This is how a small team can obtain consistent anatomy and material lighting while keeping a 2D runtime.

**Strengths:** high visual ceiling, cheap runtime, deterministic framing, reusable model/animation library.

**Costs:** requires Blender automation, coherent models, licensed motion data, many atlas variants, and careful compression. Frame counts should be at least 12–24 for locomotion and 18–40 for attacks, not single digits.

**Verdict:** recommended next production pipeline once character silhouettes and action timing are approved.

### 5. Procedural vector/SDF humanoids

Build actors from articulated continuous geometry and shade them with faceted planes, outlines, rim lighting, material accents, and equipment silhouettes.

**Strengths:** immediate, resolution-independent, no sprite inconsistency, unlimited temporal smoothness, directly driven by `ActionDef`, easy faction variation, tiny asset footprint, safe under the existing renderer.

**Weaknesses:** procedural geometry cannot equal a senior character artist’s sculpt and materials. Poor proportions can still look like icons or paper dolls.

**Verdict:** selected for this pass, but with an explicit anti-icon quality bar: no three-circle bodies, no giant heads, no flat single-color silhouettes, no bounce-only locomotion. The implementation uses projected 3D joints, tapered quad limbs, layered torso planes, clothing tails, armor plates, hands, boots, weapons, head/hood facets, and state-specific poses.

Reference: Godot custom CanvasItem drawing documentation: https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html

### 6. GPU particles and shader-heavy VFX

`GPUParticles2D` can support large effect counts efficiently. However, this project currently creates presentation nodes in code and targets GL Compatibility. A dependency-heavy particle rewrite would add import and renderer risk.

**Verdict:** use bounded procedural CPU effects now, keep the CueBus data model, and migrate hot effects to `GPUParticles2D` after profiling. The delivered FX system has explicit caps and adaptive density.

Reference: Godot `GPUParticles2D` documentation: https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html

### 7. Physics interpolation

The simulation is fixed at 60 Hz, which is already a strong base. Presentation should never mutate authoritative transforms to “smooth” them. The renderer therefore maintains visual positions that exponentially converge to simulation positions and snap on teleport-scale discontinuities.

Godot also has engine-level physics interpolation. It should be evaluated after the custom render interpolation is validated, because enabling it globally can require resetting interpolation on teleports/spawns.

Reference: Godot physics interpolation guide: https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html

## Open-source games and engines examined for transferable ideas

### FLARE Engine / FLARE Game

FLARE treats animations as named sets with explicit frame count, duration, direction, playback mode, and active frames. The important idea is not its sprites; it is that gameplay timing and presentation timing have explicit contracts.

Vampire City already has the stronger primitive: `ActionDef` startup/active/recovery. The delivered rig maps its continuous attack pose directly onto that authoritative frame data instead of playing an unrelated canned animation.

- https://github.com/flareteam/flare-engine
- https://github.com/flareteam/flare-game

### OpenRA

OpenRA’s sequence-driven presentation keeps simulation and rendering concerns separable and makes effects data-addressable. The transferable lesson is to route visual events through semantic events rather than hard-code effects into combat functions. Vampire City’s CueBus already provides that seam; the upgraded `WorldFX` expands it rather than bypassing it.

- https://github.com/OpenRA/OpenRA

### OpenDiablo2 / OpenD2-derived projects

Diablo-style isometric animation pipelines rely on directional action sets, equipment-layer consistency, and strict naming. The transferable lesson is production discipline: every actor must expose the same action vocabulary even when the rendering backend changes.

- https://github.com/OpenDiablo2/OpenDiablo2

### Godot demo projects

The official demos show native 2D skeleton, polygon deformation, particles, lighting, and shader composition. They confirm that the current engine can support a much stronger presentation without changing engines.

- https://github.com/godotengine/godot-demo-projects

## Delivered architecture

### Continuous 2.5D pose driver

Each character pose is generated from:

- measured displacement and velocity,
- facing,
- action startup/active/recovery and action damage class,
- dash cue lifetime,
- hit cue direction and hitstop,
- knockback-adjacent state,
- faction, type, weapon tags, AI state, status, downed/dead state.

The local rig uses `Vector3` joints. The third coordinate is projected into screen-space height, producing a readable oblique body without moving the game into 3D. Limbs are tapered meshes rather than circles. Clothing and armor are layered planes. Weapons are grounded in hand joints.

### Performance policy

- One renderer node; no node-per-limb scene-tree explosion.
- Bounded trail history.
- High-detail cap at 56 humanoids; silhouettes remain functional beyond it.
- FX cap: 96 effects and 280 particles.
- FX density automatically reduces below 46 FPS.
- No per-frame texture generation or image upload.
- Existing GL Compatibility renderer remains supported.

### Ballistic physics channel

The existing ground-plane projectile system is extended with deterministic:

- height,
- vertical velocity,
- gravity,
- bounce count and restitution,
- horizontal ground friction,
- collision height,
- fuse,
- spin,
- surface effect.

A projectile can now sail over actors, descend, bounce, detonate, apply AoE/status/knockback, and ignite existing world surfaces. State hashing includes every new variable, so replay and save determinism remain testable.

Example call:

```gdscript
Sim.spawn_projectile(origin, direction * 235.0, {
    "owner_id": Sim.player.id,
    "faction": "player",
    "kind": "volatile_flask",
    "radius": 6.0,
    "aoe_damage": 18.0,
    "aoe_radius": 92.0,
    "damage_type": "fire",
    "status": "burn",
    "status_ticks": 150,
    "ballistic": true,
    "vertical_velocity": 220.0,
    "gravity": 560.0,
    "bounces": 1,
    "bounce_factor": 0.30,
    "surface_effect": "fire",
})
```

## Quality gates before merge

1. Full GUT suite passes, including the new ballistic tests.
2. Determinism test still passes across repeated seeds.
3. Capture harness produces all eight PNGs.
4. No script errors on clean import.
5. Measured gameplay remains at or above 60 FPS on the project’s reference hardware with the normal vertical-slice population.
6. Spawn stress test at 60 humanoids remains above 30 FPS with automatic detail reduction.
7. Player, civilian, gang, police/SWAT, hunter/elder, and thrall silhouettes are distinguishable at gameplay zoom.
8. Attack startup, active, and recovery frames are visibly different.
9. Thrown flask visibly separates from its ground shadow, bounces, and creates an impact effect.
10. Existing save/replay hashes are unchanged except where a live ballistic projectile is intentionally part of the state.

## What should happen next

The next serious art investment should not be “more procedural detail.” It should be a controlled asset pipeline:

1. Lock silhouette sheets for each faction at gameplay camera scale.
2. Build one production vampire and one production hunter in Blender.
3. Retarget a curated locomotion/combat set.
4. Bake 16 or 24 directions with albedo, normal, depth, and emissive channels.
5. Drive the atlases with the same `ActionDef` envelope and CueBus events.
6. Compare the baked renderer and procedural renderer in the same capture harness.
7. Replace only when the baked path is measurably superior and feature-complete.

That keeps the game intact while raising the ceiling. No more engine roulette.
