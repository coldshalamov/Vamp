# Nocturne component inventory

This inventory maps every major visual element named by the specification to a working example and a production next step.

| Element | Executable example | Live integration | Production next step |
|---|---|---|---|
| wet asphalt | visual lab gameplay, passes 2–3 | sparse sheen and puddle lips in `nocturne.js` | authored asphalt atlas, wetness mask, source-aligned reflection system |
| sidewalk/curb | gameplay | sparse moisture detail | slab variants, grime masks, curb drainage and damage families |
| building extrusion | gameplay | existing renderer retained | authored district silhouette kits and facade atlases |
| Gothic architecture | church/club roofs in gameplay | selective roof rim and narrative props | landmark kits, arches, spires, fire escapes, entrances |
| rooftop props | gameplay | antennas and cables | water tanks, HVAC, access hatches, utility routing |
| windows | gameplay | existing windows preserved | occupancy clusters, interior color scripts, curtains/blinds |
| neon signs | gameplay/title/dialogue | existing emitters preserved | housings, mounts, cable paths, reflection anchors, irregular faults |
| sodium/cyan/violet light | gameplay | split-tone grade and current light pool | source categories, occlusion, reflection response, light budgets |
| rain | gameplay/title | current weather preserved | three depth bands, surface response, runoff, quality tiers |
| fog/steam | gameplay | current fog preserved | source-aware fields, light pickup, low-resolution render texture |
| blood decal | gameplay | existing decal systems preserved | event-specific blood families and rain aging |
| manhole/drain | pass 3 gameplay | exemplar only | prop variants and world-generation rules |
| environmental storytelling | gameplay roofs/streets | rooftop narrative hints | density clusters driven by building function and events |
| player silhouette | gameplay/inventory | focus arc in `nocturne.js` | authored directional sprite/animation retaining wedge footprint |
| civilian | gameplay | existing NPC renderer | posture/gait/costume silhouette taxonomy |
| hunter | gameplay/dialogue target | existing NPC renderer | distinct coat/weapon/ward silhouette and telegraph |
| police | gameplay | existing NPC renderer | readable uniform geometry, lights, investigation props |
| vehicle | gameplay | existing vehicle renderer | authored class atlases, normal/emissive masks, damage states |
| objective marker | gameplay | existing marker retained | unified shapes, occlusion, distance and edge behavior |
| player focus cue | pass 3 gameplay | implemented in `nocturne.js` | tune by combat density and accessibility setting |
| health/vitae/hunger | gameplay/inventory/style guide | existing HUD plus shared frame | convert to tokenized components and UI-scale constraints |
| masquerade state | gameplay | existing HUD | shape-redundant heat states and escalation animation |
| minimap | gameplay | existing minimap | semantic marker shapes, label collision rules, zoom/rotation policy |
| objective card | gameplay/style guide | existing mission UI | component refactor and responsive sizing |
| hotbar | gameplay/style guide | slot crown accent in `nocturne.js` | authored icons, controller labels, all interaction states |
| interaction prompt | gameplay/style guide | existing prompt | device-aware prompt component, hold/toggle alternatives |
| notifications/status | gameplay | existing HUD | queue hierarchy, grouping, accessibility timing |
| title screen | `final-title.webp`, visual lab `?screen=title` | splash upgraded by `nocturne.css` | integrate final title composition into `Game.renderTitle` |
| pause menu | `final-pause.webp` | menu atmosphere/frame in `nocturne.js` | convert menus to common panel/navigation components |
| inventory | `final-inventory.webp` | exemplar only | production layout, comparison, sorting/filtering, UI-scale tests |
| dialogue | `final-dialogue.webp` | exemplar only | portrait pipeline, choice states, subtitle/accessibility controls |
| portrait | dialogue/inventory | exemplar only | painterly portrait brief and asset contract |
| typography | all screens/style guide | CSS splash and existing fonts | local OFL fonts, deterministic metrics, font-safe mode |
| iconography | gameplay/inventory/style guide | exemplar plus slot treatment | project-owned icon set at 16/24/48/96 px |
| panel grammar | all UI screens/style guide | Theme panel wrappers | refactor legacy one-off panels to shared component API |
| cinematic grade | gameplay | implemented in `nocturne.js` | district-authored LUT/curve system in GPU path |
| screen frame/safe area | gameplay/menus | implemented in `nocturne.js` | configurable by UI scale and aspect ratio |
| reduced motion | visual lab control | Nocturne skips animated focus behavior | complete settings surface and replacements for every effect |
| quality tiers | specification | Nocturne respects low/high | profile and formalize low/medium/high budgets |
| visual regression | three pass captures | capture assets in docs | Playwright fixtures and CI golden scenes |
| art pipeline | specification | not runtime | AssetPack, atlases, masks, provenance manifest |
| GPU migration | architecture section | adapter not yet implemented | one-district PixiJS parity prototype |
