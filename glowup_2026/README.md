# Vampire City — 2026 Hidden-Game Glow-Up Kit

This directory is a review-safe delivery package for the next stage of Vampire City. It does not replace the deterministic `Sim` architecture, broaden the vertical slice, or silently change shipping behavior. It supplies the difficult connective systems, technical-art assets, content grammar, and agent contracts needed to turn the existing backend breadth into a coherent, replayable predator RPG.

The governing idea is:

> Every strong player action solves the immediate problem, leaves residue, teaches the city something about the player, and changes the next situation.

That creates the hidden game already latent in the repository: the player develops a style through practiced behavior rather than a class-picker, while witnesses, factions, heat, nemeses, districts, dawn, and opportunities compose consequences around that style.

## Included

- `docs/GLOWUP_2026_SPEC.md` — unified game, feel, graphics, physics, audio, and replayability specification.
- `docs/GLOWUP_2026_AGENT_PLAN.md` — dependency-ordered implementation map with file ownership and measurable gates.
- `reference/PlayerStyleProfile.gd` — deterministic organic playstyle inference.
- `reference/RumorGraph.gd` — deterministic witness claims, uncertainty, propagation, and faction belief summaries.
- `reference/OpportunityDirector.gd` — pressure-, faction-, geography-, novelty-, and style-aware opportunity selection using caller-owned RNG.
- `content/opportunity_templates.json` — authored systemic opportunity grammar tied to the existing Vampire City systems.
- `shaders/resonance_aura.gdshader` — readable pre-feed resonance aura for top-down sprites.
- `shaders/wet_asphalt.gdshader` — restrained rain/wet-road treatment for the current 2D GL Compatibility renderer.
- `shaders/nocturne_grade.gdshader` — coordinated heat, humanity, frenzy, and dawn screen grade with reduced-flash support.
- `art/residue_icons.svg` — original SVG atlas for Exposure, Heat, Need, Debt, Anomaly, and Dawn.
- `test/unit/test_glowup_hidden_game.gd` — deterministic reference tests.

## Integration doctrine

1. Keep `Sim` authoritative and deterministic.
2. Keep the scene tree as presentation.
3. Route presentation through `CueBus`.
4. Run style, rumor, and opportunity systems in shadow mode first: observe real events and expose debug state without changing outcomes.
5. Close the current First Hunt slice before surfacing campaign breadth.
6. Prefer dense causal reuse of existing systems over adding another standalone feature.

## First integration seam

Add one `hidden_game_event(event_id, payload)` call from `Sim.emit_cue` into an owner held by `SimMeta`. That owner receives only semantic, serializable facts and caller-supplied deterministic rolls. It must not read `Time`, scene nodes, input devices, or presentation state.

The initial milestone is successful when a 12–18 minute First Hunt produces a reproducible trace showing:

- the player’s emerging style vector,
- witnessed and uncertain claims,
- local identity-linked exposure,
- pressure changes with explicit causes,
- and ranked future opportunity candidates,

while the playable outcome remains otherwise unchanged.

## What this kit deliberately does not do

It does not open all four districts, wire every menu, ship an online service, add more currencies, replace Godot physics with rigid-body actors, or turn the game into a generic procgen sandbox. It is a convergence package: first make one night irresistible, then let the existing meta systems become the campaign.