# Vampire City 2026 Glow-Up Specification

## Executive call

Vampire City’s unusual advantage is already present: a deterministic, tested simulation containing clans, powers, missions, heat, witnesses, domains, coterie, haven, economy, mastery, loot, events, dawn, and nemeses. The remaining risk is not lack of systems. It is lack of convergence.

The game should become a dense top-down urban predator RPG with three simultaneous virtues:

1. **Hades-tight contact quality** — movement, attacks, feeding, powers, camera, sound, and recovery feel trustworthy at the hand.
2. **GTA-readable city pressure** — crimes create understandable local pursuit, last-known-position search, evidence, escalation, and satisfying escape.
3. **Bloodlines-grade identity and consequence** — clan, prey, mercy, reputation, allies, territory, and recurring enemies change how the player solves problems.

The 2026 version does not win by matching a giant studio’s acreage. It wins by making one block remember more than most open worlds remember about an entire campaign.

---

## 1. The hidden game: power leaves residue

Every meaningful action produces four outputs:

```text
IMMEDIATE RESULT
+ RESOURCE CHANGE
+ RESIDUE
+ FUTURE POSSIBILITY
```

Examples:

- A brutal kill removes an enemy, heals or rewards the vampire, creates noise/evidence/fear, and may seed a nemesis, crackdown, or intimidation opportunity.
- A spared feeding target restores less immediately, preserves Humanity, creates a living witness or grateful contact, and can reset a clan-specific flow tool.
- Obfuscation breaks pursuit but leaves anomalies, contradictory accounts, or a technical gap in surveillance.
- A coterie intervention wins the fight but creates debt, injury, or faction visibility.
- Claiming a domain grants income and heat cover, but creates ownership, upkeep, raids, and local expectations.

Residue is not a morality lecture. It is content fuel.

### 1.1 Pressure channels

The player should reason about a compact set of pressures:

| Channel | Meaning | Typical sources | Typical relief | New play it opens |
|---|---|---|---|---|
| Exposure | How strongly an identity is linked to acts | witnesses, cameras, bodies, vehicles, public powers | disguise, misinformation, cleanup, favors | prepared enemies, social notoriety, identity jobs |
| Heat | Immediate institutional pursuit in a district | alarms, combat, vehicle crimes, body discovery | LOS break, haven, bribery, diversion, time | chases, checkpoints, hunter deployment |
| Need | The internal cost of vampiric power | blood spend, hunger, injury, frenzy | feeding, haven, restraint, specific prey | risky shortcuts, resonance decisions, frenzy play |
| Injury | Reduced physical reliability | damage, crashes, sun, overextension | treatment, feeding, haven rooms, allies | clinic jobs, altered handling, scars |
| Debt | Promises and interventions owed | coterie rescue, faction help, borrowed access | service, payment, renegotiation, betrayal | relationship arcs and compelled opportunities |
| Anomaly | Evidence of the impossible | overt disciplines, impossible movement, occult residue | suppression, disinformation, containment | specialist hunters, cult interest, research jobs |
| Volatility | Instability of a district or holding | faction conflict, scarcity, leadership loss, raids | stabilization or decisive victory | radiant events and emergent contracts |

Every increase must be attributable in debug state and player-facing language. Every channel needs at least two relief methods. High pressure must open at least one opportunity before it closes content.

### 1.2 Local memory, not psychic police

Memory has location, identity, source, and confidence.

A witness does not create truth. It creates a claim:

```text
subject + predicate + value + confidence + valence
+ source chain + district + identity key + origin event
```

A terrified civilian may remember a red coat and impossible speed but not a face. A camera may link a vehicle but not motive. A hunter may combine several partial claims. A faction can fear the player while misidentifying them.

This supports:

- disguises and alternate identities,
- framing and misinformation,
- vehicle linkage,
- witness recruitment or intimidation,
- local reputation repair,
- faction disagreement,
- and consequences that feel caused rather than spawned.

---

## 2. The player authors a style

Do not ask the player to choose a rigid class. Track how they actually solve risk.

The five style axes are:

- **Force** — damage, threat, armor, interruption, direct control.
- **Stealth** — concealment, silent access, timing, misdirection.
- **Influence** — favors, persuasion, status, empathy, blackmail, coterie command.
- **Mobility** — chase control, escape, vehicles, verticality, positioning.
- **Systems** — surveillance, environment, traps, blood magic setups, logistics.

The style vector is exponentially decayed and records completed semantic resolutions, not button spam. It should answer: “How does this player habitually turn danger into advantage?”

### 2.1 What style changes

Style influences:

- the three choices offered at mastery thresholds,
- which radiant opportunities are most relevant,
- what enemies and factions believe the player is capable of,
- which nemesis adaptations are plausible,
- which barks and epithets circulate,
- and how the night recap describes the player.

It must not secretly nerf the dominant style. Across any three generated opportunities:

- at least one strongly supports the dominant style,
- at most one contains a soft counter,
- at least one offers a bridge to another style,
- no hard counter erases a signature verb,
- and all counters are discoverable before commitment.

### 2.2 Clan as a rule change

Clan identity sits above style and bends the game’s grammar:

- **Brujah — Blood Rage:** opt-in frenzy turns Need into tempo; high force, unstable defense and disciplines.
- **Nosferatu — One With Shadow:** correct stealth takedowns and unseen feeding preserve or extend cloak.
- **Tremere — Vitae Alchemy:** powers can convert HP and prepared blood states into spell tempo.
- **Toreador — Perfect Predator:** mercy and controlled feeding reset flow resources/cooldowns.
- **Ventrue — Iron Will:** social domination creates persistent infrastructure and coterie power.
- **Gangrel — Wild Hunt:** uninterrupted movement and pursuit build momentum stacks.
- **Malkavian — Voices Know:** controlled unpredictability creates unusual combo routes and information.

The keystone should be visible in the first ten minutes and mechanically necessary at least once in the First Hunt.

---

## 3. Fun at every temporal scale

### Every 80–150 ms

- Input is acknowledged.
- Attack, dash, feed, and power presses are buffered through short transition windows.
- Interactable selection is stable before the press.
- Contact produces pose, hitstop, sound, particle, camera, and impulse as one cue packet.
- No animation steals control without an explicit readable rule.

### Every 3–8 seconds

- The player reads a threat, route, prey trait, witness, search state, or resource.
- An action changes local state.
- The result is legible without opening a menu.
- A follow-up choice opens or closes.

### Every 30–90 seconds

- The encounter changes phase: stalking, feeding, suspicion, search, combat, chase, cleanup, escape.
- A resource or relationship moves.
- The player’s method becomes visible to the world.

### Every 12–18 minutes

- A night has an opening intention, escalating middle, dawn pressure, and meaningful recap.
- The result changes access, pressure, ownership, information, obligation, or a recurring rival.

### Every 1–3 hours

- A faction agenda advances.
- A district changes physically and mechanically.
- A relationship crosses a threshold.
- A prior consequence returns in altered form.
- The player gains a new verb combination, not merely a larger number.

---

## 4. Moment-to-moment gameplay

## 4.1 Movement and camera

The current top-down action foundation should become precise and forgiving rather than physically simulated for its own sake.

Requirements:

- 60 Hz authoritative fixed-step remains intact.
- Movement uses acceleration and braking curves rather than instantaneous velocity changes.
- Dash accepts a 3–5 frame input buffer and preserves intentional direction.
- Wall collision resolves without diagonal snagging or corner vibration.
- Short action queues are explicit: one buffered attack, dash, feed, or power, with priority rules.
- Camera follow uses velocity-aware look-ahead capped by combat distance.
- Camera trauma is frequency-separated: hit impact, alert, pursuit, and frenzy use distinct envelopes.
- Reduced-motion mode removes rotation and high-frequency shake while preserving critical positional cues.
- Aim direction remains readable through sprite pose, ground marker, projectile path, or reticle—not a permanent developer nub.

The game must feel controllable before it feels cinematic.

## 4.2 Combat grammar

Use the existing ActionDef startup/active/recovery/cancel architecture as the constitution.

Add:

- 3–6 frame input buffering,
- explicit on-hit versus on-whiff recovery,
- flank/back-angle bonuses against front-armored enemies,
- guard/poise for readable interruption,
- short attack-slot reservations so squads do not dogpile identically,
- telegraphed enemy commitment,
- and damage-scaled hit response.

A hit resolves through one impact packet:

```text
source, target, point, normal, direction, damage type,
health damage, poise damage, impulse, material/body zone,
crit, status, hitstop, presentation magnitude
```

The packet drives gameplay, audio, particles, decals, camera, rumble, AI attention, and semantic events. Do not let each presentation system recalculate severity.

### Enemy micro-puzzles

- Civilian/witness: social and Masquerade problem, not a combat target.
- Thug: basic timing and spacing.
- Gunner: LOS, pressure, and gap close.
- Shield/SWAT: flank, dash-through, control, or environmental counter.
- Hunter: search discipline, anti-power tools, adaptive resistance.
- Elder/rival vampire: mirrors player grammar and punishes repetition.
- Specialist: responds to anomaly or a known signature, but arrives only when the city plausibly learned enough.

No enemy should merely be a larger health bar.

## 4.3 Feeding as a build decision

Feeding is the game’s signature interaction and must combine execution, prey selection, and consequence.

The complete feed loop:

```text
READ PREY → APPROACH → GRAB → GULP TIMING →
CONTROL / KILL / INTERRUPT → RESONANCE BUFF → RESIDUE
```

### Resonance

Victims carry a deterministic humour/resonance:

- Sanguine: recovery, social confidence, flow.
- Choleric: force, stagger, frenzy control or damage.
- Melancholic: sorcery, cooldown, anomaly management.
- Phlegmatic: stealth, stability, exposure reduction.

Auspex or close observation reveals the aura before commitment. Resonance is represented by both color and shape/pulse language for accessibility. Feed quality, victim state, and lethal/spare outcome change buff strength and duration.

The player should sometimes pass up the nearest body because the wrong blood would distort the build or the right blood is worth the risk.

## 4.4 Heat, search, and pursuit

Heat is local, staged, and legible.

States:

```text
UNNOTICED → SUSPICIOUS → SEARCHING → CONFIRMED →
COORDINATED → LOST THEM / STAND-DOWN
```

Responders act on last-known position, witness description, known identity, and likely goal. Search strategies are seed-driven and include at least:

- direct sweep of last-known position,
- exit containment,
- flank/quadrant search,
- objective or body check,
- give-up ambush,
- and call-for-specialist when anomaly knowledge permits.

Search visualization should show only information the player could perceive: flashlight cones, radio barks, footsteps, last-known marker, closing exits, and heat pulse. The debug overlay may reveal the full uncertainty model.

## 4.5 Dawn

Dawn is the night’s hard dramatic clock.

- Final 90 seconds shift music, sky, street lighting, NPC behavior, and objective urgency.
- First light creates localized dangerous bands before full exposure.
- Sun damage escalates continuously outside haven/shade.
- Humanity/Need/injury can affect survivability, but must be communicated.
- Vehicles and claimed havens become strategic routes.
- Reaching safety triggers an authored recap moment, not an accounting spreadsheet.
- Failure creates torpor and a cost/state change rather than deleting the campaign unless the selected difficulty demands it.

---

## 5. Systemic opportunity director

Procedural generation should arrange authored meaning, not generate errands.

An opportunity template contains:

- premise,
- required and forbidden world tags,
- role slots,
- locations/spatial affordances,
- objective graph,
- phase transitions,
- complications and revelations,
- resolution methods,
- fail-forward outcomes,
- pressure relief and pressure generation,
- faction effects,
- reward forms,
- cooldown/novelty tags,
- and authored bark/narrative hooks.

Candidate score begins with:

```text
22% pressure relevance
18% faction agenda
16% novelty / cooldown
12% style support
 8% gentle counterpoint
 8% geography
 8% relationship relevance
 5% resource-state fit
 3% authored priority
```

The director receives all randomness from `Sim.draw_float` or an explicit deterministic stream. Candidate order is sorted before weighted choice. Rejected preconditions and score components are visible in debug state.

The result is continuous play value: existing districts, factions, enemies, vehicles, bodies, domains, coterie members, and nemeses recombine around actual campaign state.

---

## 6. Progression and replayability

Progression has four distinct tracks:

1. **Practice:** sidegrades and grammar expansion for frequently demonstrated methods.
2. **Infrastructure:** haven rooms, fronts, routes, vehicles, surveillance, clinics, businesses.
3. **Relationships:** coterie, contacts, faction trust/fear/respect, nemeses, dependents.
4. **Knowledge:** identities, schedules, weaknesses, district shortcuts, evidence, recipes.

Raw health/damage inflation is bounded. The late-game vampire is stronger because more situations can be composed, controlled, outsourced, survived, or reframed.

### Replay structure

A campaign seed controls:

- district prosperity/volatility,
- faction leadership and initial agendas,
- available safe routes and fronts,
- resonance distribution tendencies,
- early nemesis traits,
- opportunity slot filling,
- and selected authored complications.

Random streams are partitioned by domain so cosmetic randomness cannot perturb gameplay replay.

### New Bloodline / legacy

A completed campaign may preserve:

- one altered district trait,
- one inherited haven service or route,
- one relationship complication,
- one mythic rumor about the prior character,
- and a bounded bloodline sidegrade.

Legacy creates texture and different problems. It must not create runaway power.

---

## 7. Visual direction: dirty urban horror with disciplined clarity

The target is nocturnal density, not darkness for its own sake.

### 7.1 Material hierarchy

Common gameplay surfaces need the most attention:

- wet asphalt,
- sidewalk and curb,
- building wall/window bands,
- doors and barriers,
- vehicles,
- clothing/skin,
- blood and occult residue.

Wetness is not simply low roughness. In this 2D renderer it should be expressed through:

- restrained darkening,
- broad reflection streaks aligned to road flow,
- selective ripple response,
- light-dependent highlight lift,
- puddle masks that do not cover the whole tile,
- and stable seeded motion.

### 7.2 Lighting

Compose three scales:

- navigation: routes, exits, haven, danger,
- encounter: faces/silhouettes, cover edges, attack telegraphs,
- mood: district identity, rain, faction presence, dawn.

Player follow-light is a readability tool, not a glowing halo. Scale it with Humanity/Need only subtly. Add occluder shadows only after wall/door silhouettes are stable and performance-measured.

### 7.3 VFX language

Every effect uses:

```text
anticipation → contact → peak → decay → residue
```

Required families:

- blood impact and feed stream,
- dash trail/afterimage,
- guard/armor impact,
- poise break,
- resonance aura,
- search/alert state,
- heat escalation,
- frenzy,
- dawn and sun damage,
- nemesis scar/adaptation,
- and environmental hazards.

Use pools. Keep particles below entities or above them intentionally. Never hide the next attack.

### 7.4 Screen grade

Heat, Humanity, frenzy, feed, and dawn must not independently stack full-screen overlays. One grade director blends semantic parameters into one coordinated pass. The included shader is the starting point.

Reduced-flash mode lowers temporal amplitude and substitutes persistent edge/icon language.

---

## 8. Audio

Audio is a gameplay channel.

Priority:

1. imminent offscreen threats and confirmations,
2. dialogue/barks,
3. player body/action,
4. nearby causality,
5. music,
6. ambience.

Required systems:

- adaptive exploration/combat/chase/dawn stems,
- hunger-scaled heartbeat,
- positional hunter footsteps and radio,
- witness/alarm stings,
- heat-tier escalation,
- clan keystone motifs,
- material-specific footsteps/impacts,
- and captions/sound radar for information-bearing cues.

AI hearing and audible sound must use the same semantic event severity. A crash the player hears cannot be ignored by nearby guards unless a documented rule explains why.

---

## 9. UI/UX

Gameplay HUD stays Predator-Minimal:

- HP/condition,
- Vitae/Need,
- Hunger,
- Heat,
- Humanity,
- active resonance,
- keystone state,
- dynamic hotbar,
- dawn timer,
- and contextual interaction.

The hidden game uses a compact **Residue Strip** showing:

- current identity,
- local exposure band,
- known evidence/witness icons,
- factions actively searching,
- and the most likely near-term consequence.

Detailed dossier screens expose discovered claims and source chains without revealing omniscient truth.

Accessibility requirements:

- remapping for all verbs,
- controller glyphs,
- hold/toggle alternatives,
- subtitle size/background/speaker/direction,
- critical-sound captions,
- color-independent resonance and faction signals,
- camera shake/rotation/bob controls,
- flash/chromatic-aberration controls,
- timing-window assist,
- social-information clarity,
- and consequence-severity controls.

---

## 10. Performance and technical constitution

Preserve:

- deterministic `Sim` authority,
- fixed 60 Hz simulation,
- explicit caller-owned RNG,
- view-only scene tree,
- semantic CueBus presentation,
- lossless save data,
- and headless tests.

Target budgets for the First Hunt scene:

- 60 fps on the selected minimum PC/Steam Deck profile,
- no per-frame allocation in authoritative hot loops,
- bounded cue and particle concurrency,
- ≤0.25 ms aggregate hidden-game observer cost in the slice,
- ≤0.4 ms presentation cost for pooled VFX outside stress peaks,
- stable save size and versioned migrations,
- and reproducible 10,000-event traces.

Simulation LOD for later districts:

- Tier 0: full nearby encounter AI/physics/perception.
- Tier 1: nearby block with reduced scheduled logic.
- Tier 2: district aggregate operations, actors, claims, and assets.
- Tier 3: faction agenda and macro pressure only.

No system may poll every entity every frame to discover semantic facts that existing code can emit once.

---

## 11. Definition of A-list quality

The game reaches the intended bar when:

- the first thirty seconds communicate predator, prey, risk, and direction without a text wall;
- movement, camera, feeding, and contact invite mastery;
- a player can explain why pursuit began and how it ended;
- two players complete the same night through visibly different methods;
- lethal and merciful play both create compelling, nontrivial futures;
- clan keystones change rules, not just percentages;
- the herald’s return feels personally caused;
- dawn creates stories rather than a timer chore;
- screenshots look authored and motion remains stable;
- the game is fully playable offline and with analytics disabled;
- accessibility options preserve decisions while relaxing motor/sensory demands;
- and after the First Hunt, a blind player asks to play another night.

That last sentence remains the expansion gate. No amount of backend breadth is allowed to negotiate around it.