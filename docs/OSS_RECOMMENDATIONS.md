# Godot 4 OSS Recommendations

Research date: 2026-06-21. Target: Godot 4.3, GDScript, 2D top-down action-RPG. Last-commit dates below are default-branch metadata from GitHub/GitLab unless noted.

## 1. Unit Testing / CI

| Name | Repo URL | License | Last commit | Godot 4 status | Verdict |
|---|---|---:|---:|---|---|
| GUT (Godot Unit Test) | https://github.com/bitwes/Gut | MIT | 2026-06-19 | GUT 9.x is Godot 4.x; for Godot 4.3 use GUT 9.4.0, not the latest 4.6+ asset. Upstream CLI docs support recursive headless runs, but this repo must not run raw recursive GUT on Windows; use `scripts/RunGutSafe.ps1` locally and CI for the full suite. | Install first. The `--script` SceneTree runner is useful for deterministic-sim tests, but local Windows runs must stay bounded. |
| GdUnit4 | https://github.com/godot-gdunit-labs/gdUnit4 | MIT | 2026-06-15 | Compatibility matrix includes Godot 4.3 via v5.x. Headless command-line/CI and JUnit/HTML reports are supported. | Good alternative if we later want richer reports or C# coverage; GUT is simpler for GDScript-first sim tests. |

## 2. Steering / Behavior AI

| Name | Repo URL | License | Last commit | Godot 4 status | Verdict |
|---|---|---:|---:|---|---|
| Godot Steering AI Framework (GSAI) | https://github.com/GDQuest/godot-steering-ai-framework | MIT | 2024-09-13 | Current project file marks Godot 4.1; supports seek, flee, arrive, wander, separation, avoidance, paths, blends. | Best candidate, but vendor only after a spike. Good math and API reference; do not trust it alone for 200+ NPC crowd performance. |
| Steering Behaviors in Godot 4 | https://github.com/konbel/steering-behaviors-godot-4 | MIT | 2024-09-18 | Godot 4 demo project. | Avoid as dependency: useful examples, too small to be battle-tested infrastructure. |

## 3. 2D Lighting / Shadows / Normal Maps

Use native first. Godot has `PointLight2D`, `DirectionalLight2D`, `LightOccluder2D`, `CanvasModulate`, and `CanvasTexture` normal/specular maps documented for 2D lighting: https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html.

| Name | Repo URL | License | Last commit | Godot 4 status | Verdict |
|---|---|---:|---:|---|---|
| Native 2D lights and occluders | https://github.com/godotengine/godot | MIT | engine feature | Godot 4.3 native. | Use this for darkness with pools of light. Add authored light textures and occluder layers before considering addons. |
| Normal Map Generator | https://github.com/krosseye/godot_normalMap_generator | MIT | 2025-03-30 | Ported for Godot 4.4. | Optional art-tool addon after engine upgrade; too small and 4.4-targeted for first install. |
| Laigter | https://github.com/azagaya/laigter | GPL-3.0 | 2024/2025 activity | External normal/specular generator, not a Godot dependency. | Avoid as vendored/shipped dependency because GPL. Use only as an external art tool if license review is comfortable. |

## 4. Spatial Partitioning For 200+ Entities

| Name | Repo URL | License | Last commit | Godot 4 status | Verdict |
|---|---|---:|---:|---|---|
| Project-owned uniform spatial hash | internal | project | N/A | Godot 4 GDScript `Dictionary[Vector2i, Array]` buckets. | Roll our own. For top-down NPC queries, a uniform grid is simpler, deterministic, testable, and faster to reason about than a generic quadtree addon. |
| PhysicsDirectSpaceState2D queries | https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate2d.html | MIT docs/engine | native | Godot 4 has `intersect_shape`, `intersect_point`, `intersect_ray`. | Use when entities already have physics shapes or collision masks; avoid making physics the authoritative sim query layer. |
| godot4-quadtree | https://github.com/DigitallyTailored/godot4-quadtree | no license detected | 2023-12-13 | Godot 4 terrain/chunk script. | Avoid: not licensed/maintained enough and not aimed at NPC neighborhood queries. |

## 5. Deterministic Networking / Rollback

| Name | Repo URL | License | Last commit | Godot 4 status | Verdict |
|---|---|---:|---:|---|---|
| netfox | https://github.com/foxssake/netfox | MIT | 2026-06-10 | Godot 4.x docs; implements timing, rollback, and multiplayer helpers. | Best thing to know about for future multiplayer/replay, but too broad for the Phase 1 single-player sim. |
| Godot Rollback Netcode | https://gitlab.com/snopek-games/godot-rollback-netcode | MIT | 2026-06-06 | Canonical Godot 4 asset is 1.0.0-alpha for Godot 4.2; GitHub mirrors are stale. | Flag for later deterministic replay experiments; not install-first. |

## 6. Tilemap / Handcrafted Level Editing

| Name | Repo URL | License | Last commit | Godot 4 status | Verdict |
|---|---|---:|---:|---|---|
| Native TileMapLayer | https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html | MIT docs/engine | native | Godot 4.3 path; old `TileMap` is deprecated. | Use first for handcrafted multi-route levels; pair layers with navigation, occluders, tags, and authored encounter data. |
| LDtk Importer | https://github.com/heygleeson/godot-ldtk-importer | MIT | 2025-02-02 | Godot 4, asset targets 4.3; imports LDtk scenes, entities, tile layers, custom data. | Install only if designers prefer LDtk's external workflow. Strong for authored maps, not procgen. |
| YATI Tiled Importer | https://github.com/Kiamo2/YATI | MIT | 2026-03-19 | Godot 4 only; latest needs 4.3+. | Good Tiled fallback; avoid until native/LDtk workflow pain is proven. |

## 7. Input Rebinding UI

| Name | Repo URL | License | Last commit | Godot 4 status | Verdict |
|---|---|---:|---:|---|---|
| Native InputMap plus existing Rebind autoload | internal/native | project/MIT | N/A | Godot 4 native. | Keep unless the UI is already costing time. |
| Maaack's Input Remapping | https://github.com/Maaack/Godot-Input-Remapping | MIT | 2025-12-22 | Godot 4.4, says 4.3+ compatible; includes remapping menu and persisted config. | Best full UI addon to know; install if replacing our settings UI. |
| Input Helper | https://github.com/nathanhoad/godot_input_helper | MIT | 2025-06-08 | Godot 4; latest release targets Godot 4.4. | Useful helper for device detection/prompts/remap calls, but not a full menu. Note: Nathan Hoad, not Nathan Lovato. |
| Godot Input Remap | https://github.com/KoBeWi/Godot-Input-Remap | MIT | 2026-05-01 | Resource-based remap storage. | Good reference if keeping our own UI; not enough to replace it. |

## 8. Save System / Slots / Migration

| Name | Repo URL | License | Last commit | Godot 4 status | Verdict |
|---|---|---:|---:|---|---|
| Project-owned save schema | internal | project | N/A | Godot 4 `user://`, JSON/resources, atomic temp-write/rename. | Roll our own: `schema_version`, migration registry, explicit DTOs, multiple slots, metadata, backup recovery, deterministic tests. |
| SaveKit | https://github.com/fernforestgames/godot-savekit | MIT | 2026-06-17 | Godot 4.5+; saves nodes/resources, JSON/binary serializers. | Promising, but young and above our 4.3 target; no clear migration/versioning story. |
| SaveState Lite | https://github.com/youssof20/savestate | MIT | 2026-04-03 | Godot 4; atomic writes, backups, schema migrations, named slots. | Closest feature match, but tiny/new. Inspect later, do not anchor the project on it now. |
| Save Made Easy | https://github.com/AdamKormos/SaveMadeEasy | MIT | 2025-01-01 | Godot 4.1; PlayerPrefs-like nested values/resources/encryption. | Avoid for this game: convenient settings store, not robust slot/migration infrastructure. |

## Install These First

1. GUT 9.4.0 for Godot 4.3 headless CI.
2. Nothing for lighting: use native 2D lights, occluders, `CanvasModulate`, and `CanvasTexture` maps.
3. Nothing for level editing at first: use native `TileMapLayer`; add LDtk Importer only if external map authoring wins.
4. Nothing for saves yet: implement the project-owned schema and migration tests.
5. GSAI only after a focused movement/avoidance spike.
6. Maaack's Input Remapping only if our existing Rebind UI becomes draggy.
7. Defer netfox/Godot Rollback Netcode until replay or multiplayer becomes real scope.
