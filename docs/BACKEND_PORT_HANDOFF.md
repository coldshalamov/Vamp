# Backend Port Handoff — Legacy JS → Godot

> Paste this to the backend/systems agent. Frontend (UI/HUD/menus/input-remap/audio-bus-wiring/visual-feedback) is owned by the frontend agent; do not build UI, only emit Sim/CueBus events the UI can consume.

## Context for the backend agent

- The Godot project is the active codebase. The `legacy/js/` directory is READ-ONLY reference; port logic and data, do not import JS files.
- Architecture: `Sim` autoload is the **authoritative** state. `src/sim/` and `src/entities/` must stay deterministic — no `randf()`, `randi()`, or `Time.*` calls. Route all RNG through `Sim.rng`.
- Scene tree is a **view**. Nodes read Sim state; they never mutate it. State changes happen in `Sim.tick_sim(delta)` or via `Sim.apply_input(...)`.
- `ActionDef` resource already exists with frame data (startup/active/recovery/cancel/hitbox/cost). Use it for every player and AI action.
- `CueBus` autoload exists for semantic presentation events (`feed.start`, `humanity.lost`, `masquerade.broken`, etc.). Backend emits events; frontend handles camera/audio/VFX/HUD.
- Current data: only `data/powers/melee_light.tres`, `melee_heavy.tres`, and `dash.tres` exist. Expand this folder.
- Assets in `assets/images/` are mostly opaque JPGs. Backend should not depend on art; use placeholder Sprite2D/ColorRects and emit CueBus events. Frontend will replace visuals.
- Tests use GUT. Add deterministic/unit tests for every system you port.

## Priority 1 — Core verbs (vertical slice blocker)

| System | Legacy source | What to port | Output / events |
|---|---|---|---|
| Blood / hunger / frenzy | `legacy/js/systems/blood.js` | Hunger meter (0–5), frenzy risk, start/end frenzy, passive regen, blood-as-HP-mana resource. | `blood.changed`, `frenzy.start`, `frenzy.end` |
| Feeding + Gulp mini-game | `legacy/js/systems/blood.js` | `tryFeed`, `tickFeeding`, `gulpHit`, `finishFeeding`, kill vs spare, body evidence, victim resonance types. | `feed.start`, `feed.gulp.perfect`, `feed.kill`, `feed.spare`, `humanity.lost` |
| Player controller | `legacy/js/entities/player.js` | Movement, sprint (blood cost), sneak toggle, GTA-style aim (move-facing + free-aim), pounce, finisher, carrying bodies. | `move.*`, `pounce.start`, `finisher.start` |
| Melee combo | `legacy/js/entities/player.js` | 3-hit claw combo with finisher swing, soft-aim assist, knockback, hitstop. | `attack.*`, `hit.connect` |
| Discipline casting | `legacy/js/systems/disciplines.js` | Known powers, hotbar slots, cooldowns, blood cost, toggle upkeep, `castSlot`. | `power.cast`, `power.cooldown`, `power.toggle` |
| Power effects | `legacy/js/systems/powers.js` | Implement ~12 core powers as `ActionDef` resources + effect callables. Start with dash, blood bolt, mesmerize, cloak, mend, slam, mark, dread gaze. | Per-power CueBus events |

## Priority 2 — Enemies & AI (vertical slice blocker)

| System | Legacy source | What to port | Output / events |
|---|---|---|---|
| NPC base + presets | `legacy/js/entities/npc.js` | Presets (ped, thug, gunner, cop, swat, hunter), elite affixes, factions, threat levels. | `npc.spawn`, `npc.death` |
| AI state machine | `legacy/js/entities/npc.js` | `wander / chase / flee / investigate / follow` with pathfinding, panic contagion, stagger on hit. | `npc.state_changed`, `npc.alarm` |
| Perception / exposure | `legacy/js/entities/npc.js`, `player.js` | `canSee` based on distance, light/shadow, sneaking, sprinting, frenzy, Obfuscate. | `player.spotted`, `player.lost` |
| Combat resolution | `legacy/js/systems/combat.js` | Damage types, armor, crit, status effects (burn/bleed/poison/shock), knockback, stagger. | `damage.dealt`, `damage.taken`, `status.applied` |

## Priority 3 — Masquerade / world (vertical slice blocker)

| System | Legacy source | What to port | Output / events |
|---|---|---|---|
| Masquerade / heat | `legacy/js/systems/masquerade.js` | Witnessed acts, heat 0–6, last-known-position search, responder spawning, decay when hidden, star-clear stand-down. | `masquerade.broken`, `heat.rise`, `heat.fall`, `heat.lost_them` |
| World / level block | `legacy/js/world/districtart.js`, `propvariants.js` | One handcrafted street block with roads, sidewalks, buildings, props, collision. | `level.loaded` |
| Pathfinding | `legacy/js/world/pathfinding.js` | Grid-based A* for NPCs. | None (internal) |
| Day/night + dawn | `legacy/js/core/loop.js`, `game.js` | Night clock, dawn deadline, sun damage, haven safety. | `dawn.warning`, `dawn.arrive`, `player.torpor` |
| Vehicles | `legacy/js/entities/vehicleroad.js` | Car spawning, driving, drive-by shooting, hijacking. | `vehicle.enter`, `vehicle.exit` |

## Priority 4 — Progression & meta (Phase 2)

| System | Legacy source | Notes |
|---|---|---|
| Skill tree / keystones | `legacy/js/systems/skilltree.js`, `gamedata.js` | Port the tree data; keystones must be rule changes, not +% buffs. |
| Stats / attributes | `legacy/js/systems/stats.js` | Derived stats from attributes + equipment + buffs. |
| Inventory / equipment | `legacy/js/systems/inventory.js` | Loot rarity, affixes, charms/attire/weapons. |
| Economy / shops | `legacy/js/systems/economy.js` | Buy/sell, haven services (heal, blood refill, bribe, clear heat, respec). |
| Coterie / childer | `legacy/js/systems/coterie.js` | Thrall roster, summon, jobs, Embrace. |
| Domains / territory | `legacy/js/systems/domains.js` | District claims, terror/prosperity, income. |
| Nemesis | `legacy/js/systems/nemesis.js` | Persistent hunters that return scarred. |
| Reputation / quests | `legacy/js/systems/reputation.js`, `quests.js` | Faction standing, mission templates. |
| Haven | `legacy/js/systems/haven.js` | Safehouse upgrades, sanctum. |
| Save/load | `legacy/js/systems/save.js` | Plain-data serialization; must handle the new Sim structure. |

## Priority 5 — Audio / FX / rendering hooks

Backend does **not** build final art/audio, but must emit the right events and state:

| System | Legacy source | Backend responsibility |
|---|---|---|
| CueBus events | `CueBus.gd` | Define all events listed above; ensure every combat/feed/heat/frenzy beat emits one. |
| Audio triggers | `legacy/js/core/audio.js` | Emit `CueBus` audio cues; frontend wires AudioStreamPlayers. |
| Camera hooks | `legacy/js/core/camera.js` | Provide trauma/pos data; frontend shakes camera. |
| Lighting data | `legacy/js/render/lightworker.js` | Expose light positions/ranges in SimWorld for frontend lights. |
| VFX triggers | `legacy/js/render/powervfx.js`, `fx.js` | Emit `vfx.*` events with position/type. |
| PostFX state | `legacy/js/render/postfx.js` | Expose frenzy/dawn/rain state; frontend applies shaders. |

## Integration contract with frontend

1. **Sim state is public.** Frontend reads `Sim.player`, `Sim.entities`, `Sim.world`, etc. every frame. No private state.
2. **All events go through CueBus.** Do not call Node methods directly from Sim code.
3. **Use semantic event IDs.** Prefer `feed.start` over `play_sound_17`.
4. **Accessibility data included.** Every cue should carry `pos`, `magnitude`, and a `caption` string when applicable.
5. **Player-facing strings in data.** Power names, descriptions, and buff names should live in `.tres` resources so frontend can localize later.

## Stop condition

The backend agent is done when a headless GUT test can:
1. Start a new game.
2. Spawn the player in the slice level.
3. Move, attack, dash, feed on a civilian, kill/spare them.
4. Trigger Masquerade heat by being witnessed.
5. Have a hunter search and lose the player.
6. Survive until dawn or reach a haven.
7. Produce identical state hashes across 20 runs with the same seed.

After that, frontend takes over to make it look, sound, and feel like a game.
