# Nocturne agent playbook

This is the operating procedure for agents extending Vampire City’s graphics and UX. Read `docs/VISUAL_OVERHAUL_SPEC.md`, inspect `visual-lab/`, and open `final-styleguide.webp` before editing production code.

## Prime directive

Do not optimize for the number of visible effects. Optimize for player readability, material credibility, hierarchy, atmosphere, and a coherent semantic language.

Every change must answer: **what becomes easier to read, more believable, more distinctive, or more emotionally precise?**

## Required workflow

### 1. Establish a deterministic baseline

Record:

- branch and commit;
- screen resolution and DPR;
- quality tier;
- district, weather, game clock, player state, and camera position;
- random seed or save fixture;
- UI scale and accessibility settings.

Capture the existing frame before making changes.

### 2. Classify the task

Choose one primary class:

- environment/material;
- lighting/atmosphere;
- character/vehicle;
- VFX/combat feedback;
- HUD;
- menu/dialogue/inventory;
- typography/iconography;
- rendering/performance;
- accessibility;
- art pipeline/tooling.

Name the governing Nocturne pillar and semantic colors involved.

### 3. Inspect the live visual stack

For world work, trace:

1. ground;
2. decals;
3. flat props;
4. structures;
5. depth-sorted entities;
6. world FX and markers;
7. lighting;
8. post FX;
9. weather;
10. UI.

For UI work, inspect existing component helpers before drawing one-off rectangles.

### 4. Prototype the smallest complete slice

A complete slice includes all relevant states, not one beauty state.

Examples:

- a hotbar slot needs idle, hover, selected, cooldown, disabled, toggled, keyboard, and controller states;
- a wet road needs dry/wet transition, lamp reflection, headlight reflection, shadow, low quality, and rain;
- an enemy telegraph needs anticipation, active, hit, canceled, obscured, and color-vision-safe forms;
- a menu needs 16:9, ultrawide, 80% UI, 140% UI, mouse, keyboard, controller, and reduced motion.

### 5. Test in motion

A still frame can hide:

- shimmer and temporal noise;
- unreadable short-lived text;
- bloom that lags or stacks;
- effects peaking before contact;
- camera motion that obscures attacks;
- flicker that becomes irritating;
- allocation or frame-time spikes.

Run the game and inspect at normal speed, slow motion, and during stress.

### 6. Capture and score

Use the weighted scorecard in the main specification. A change is not accepted because its author likes it. Record the strongest criticism a skeptical player would make.

No category relevant to the task may be below 9.0 for a final exemplar. A score of 9 requires evidence, not adjectives.

### 7. Update documentation

Update:

- component inventory;
- screenshots/golden scene;
- performance notes;
- asset provenance;
- quality-tier behavior;
- accessibility behavior;
- known limitations.

## Visual acceptance tests

### World and materials

- player remains locatable in under 250 ms;
- reflections point to a plausible source;
- wetness changes material response instead of tinting the whole screen;
- detail density forms clusters and quiet zones;
- the scene works in grayscale;
- architectural family is identifiable by silhouette;
- no procedural motif repeats conspicuously inside one viewport;
- low quality retains palette, hierarchy, and silhouette.

### UI

- selected state uses shape/value as well as hue;
- body text remains readable against the worst moving background;
- 80% scale retains key labels;
- 140% scale does not collide or leave the safe area;
- keyboard and controller prompts are unambiguous;
- hover is not required to discover critical information;
- ornament density follows importance;
- UI semantic colors match world semantic colors.

### VFX

- anticipation shape is readable before brightness peaks;
- effect origin and impact are visually distinct;
- effect does not hide target state longer than necessary;
- particles have material behavior and a source;
- bloom is proportional to emissive intensity;
- effect has a low-tier form;
- reduced motion has a valid substitute;
- residue/decal is appropriate to the event.

### Performance

- no unbounded array growth;
- no repeated canvas or texture creation in hot paths;
- no avoidable per-frame closures in dense loops;
- pools have explicit caps;
- offscreen systems sleep;
- frame-time measurement uses 95th/99th percentile, not only average fps;
- a visual regression capture can reproduce the state.

## Anti-patterns

Reject these during review:

- “make it premium” implemented as more bloom;
- perfect ellipse puddles;
- random steam without a vent;
- neon without housing, wiring, or reflection;
- every window randomized independently;
- every district using crimson plus cyan at the same intensity;
- pure black sprites with no grounding shadow;
- five unrelated border styles in one menu;
- rarity shown only by color;
- fonts downloaded at runtime;
- animation tied directly to frame count;
- particle count used as a quality metric;
- copying a reference game’s assets, logo, UI layout, or distinctive trade dress.

## File map

- `js/render/nocturne.js` — live integration layer and semantic visual tokens.
- `css/nocturne.css` — first-impression/loading treatment.
- `visual-lab/` — executable visual examples and component study.
- `docs/VISUAL_OVERHAUL_SPEC.md` — art direction and architecture.
- `docs/visual-overhaul/COMPONENT_INVENTORY.md` — implementation map.
- `docs/visual-overhaul/SCORECARD.md` — three-pass critique.
- `scripts/nocturne-smoke.mjs` — dependency-free wrapper smoke test.

## Agent task template

Copy this into an issue or agent prompt:

```text
Task: [one visual component or scene]
Nocturne pillar served: [darkness / motivated emissive / interface lineage / readability]
Player-readable information: [what must be recognized, distance, time]
Semantic colors: [token names, not arbitrary hex values]
Required states: [complete state list]
Quality tiers: [low / medium / high]
Accessibility: [UI scale, reduced motion, shape redundancy, contrast]
Performance budget: [time, particles, lights, texture memory]
Golden scene: [fixture, camera, time, weather, seed]
Reference lessons: [what to learn, what not to copy]
Acceptance evidence: [before/after, motion capture, frame data, score]
```

## Review language

Prefer precise criticism:

- “The player and hunter share the same mid-value silhouette at combat zoom.”
- “The puddle reflection has no corresponding source and reads as a decal.”
- “Crimson is simultaneously selection, damage, rarity, and neutral decoration.”
- “The panel ornament has more contrast than the objective title.”
- “This effect peaks 90 ms before the hit, weakening contact.”

Avoid empty criticism:

- “looks cheap”;
- “needs polish”;
- “make it more Gothic”;
- “add juice.”

The goal is not to protect the work. The goal is to make the next iteration inevitable.
