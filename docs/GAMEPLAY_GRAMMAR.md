# THE BLOOD GRAMMAR — Vampire City's Gameplay Spec
### The moment-to-moment system: composable, physical, casual-to-pro, and unlike anything shipped.

> Companion to `VAMPIRE_CITY_BIBLE.md` (the macro game) — this is the **micro**: the verbs, the physics,
> and the build-craft that give the game Diablo/PoE-grade continuous-play depth and genuine
> self-expression. It is the synthesis of a 10-agent design brainstorm (7 divergent lenses → an
> architect / devil's-advocate / skill-curve panel). It is deliberately **disciplined**: §7 lists what we
> are NOT building, because the brainstorm's own auditor found 38 ideas were really 9 decisions wearing
> costumes. Every hook named here is real in the current codebase.

---

## 0. THE ONE IDEA EVERYTHING COLLAPSES INTO

**Spending blood and creating battlefield terrain are the same physical act.**

Every cost in the game bleeds — out of you, out of victims — onto the floor as a *real fluid you can move,
react, and drink back.* The instant that's true, your **HP bar, your ammo, your wallet, your food, your
traversal medium, your evidence trail, and your spellbook's ink are one substance on one grid.** The 9
disciplines stop being a menu of 46 powers and become *46 ways to spill, shape, react, or reclaim the same
liquid.*

This is the cure for the disease the codebase already names in `ActionDef.gd`: *"every system built on top
could only add numbers, not playstyle."* The Blood Grammar makes every number a **physical act on a shared
medium**, so adding content adds *composability*, not stats. A vampire is the only fantasy where that
quad-identity (life = ammo = money = food = commandable matter) is coherent rather than a gimmick — and the
project's **deterministic fixed-tick sim over a `PackedByteArray` surface grid is exactly the substrate**
that makes a Noita-lite fluid genuinely shippable on a 2D game.

**The reviewer's one-liner:** *"A vampire game where you don't cast spells — you bleed your own life onto
the floor as a liquid you command like water, react like chemistry, drink back to survive, and write the
laws of the night in. Every night you author a persistent red memory of where you fed, what you changed,
and who you were."*

---

## 1. THE FIVE ATOMS

Everything in combat, feeding, traversal, and world-state is built from exactly five verbs. The 9
disciplines, the surface reactions, and the signature innovations are all *recompositions of these five.*

| # | Atom | Input grammar | What it does | Real engine hook |
|---|------|---------------|--------------|------------------|
| **1 · SPILL** | passive on every cost | none — it's the side-effect of *acting* | Blood you spend doesn't vanish from a HUD number; it **deposits onto the grid cell beneath you** as fluid carrying `depth + owner + the action's damage_type/status`. Casting, dash i-frames, getting hit while bleeding — all write fluid. | `cast_power` already debits `blood`; redirect that debit into a `world.spill(cell, depth, owner, status)` write |
| **2 · COMMAND** | `aim_release` (hold-aim) | grab → shape → throw | Telekinetically grab standing fluid and **push it**: into a wall (cover), a wave (knockback projectile), a slick (under enemies), or a coat (onto a target). Cost scales with *volume moved*, so the world's spilled blood is free ammo. | new `aim_release` ActionDef + `SimProjectile` reading grid cells |
| **3 · REACT** | passive, fixed-tick | none | Adjacent cells transform deterministically: BLOOD+FIRE→burning slick, BLOOD+ELECTRIC→conductive stun-net, BLOOD+SUN→boils away, BLOOD+SHADOW→thickens to walkable wall, WATER washes BLOOD. Blood **remembers its last status**, so a bleeding crowd is a pre-loaded detonation graph. | fixed-tick reaction pass over `SimWorld.surfaces` |
| **4 · DRINK** | `hold` (the shipped GULP) | hold + just-frame tap | Re-absorb fluid you're standing in, or feed on a downed target → fluid becomes blood/HP. A perfect just-frame tap (the shipped `GULP_WINDOW`) **doubles yield and refunds the cancel.** This is how greed becomes life again — it closes the loop. | `GULP_WINDOW`/`heal_blood()` already exist; extend to read grid cells |
| **5 · INSCRIBE** | `charge` (paint a sigil) | burn blood to write one rule | Spend a pool to paint a **Vitae Sigil** that overwrites *one rule* in its radius while fed: `SUN IS BLOOD`, `BLOOD IS WALL`, `FEAR IS DAMAGE`, `THE FED ARE FRIENDS`. Sigils are physical — enemies scuff them, REACT washes them, you chain them. | new sigil entity reading/writing the grid + `opts`/surface rules in radius |

**Spill** makes terrain · **Command** moves it · **React** transforms it · **Drink** reclaims it ·
**Inscribe** rewrites its law. Every discipline is one of these wearing a costume.

---

## 2. THE 9 DISCIPLINES AS ATOMS-IN-COSTUME

This is *why they compose without bespoke glue* — each discipline is a flavor of the five primitives:

- **Blood Sorcery** = SPILL + COMMAND made explicit (bolt spills, cauldron pools, theft drinks, storm sprays).
- **Potence** = COMMAND by force (`pot_slam` *atomizes* a blood pool into a damaging splash; quake ignites a slick).
- **Celerity** = SPILL as traversal (dash refreshes over wet blood — *Vitae Skating*); `cel_bullet` **freezes the REACT pass itself** so you sculpt fluid at leisure.
- **Fortitude** = DRINK defense (mend/ward; stone-skin lets you stand in your own electrified blood unharmed).
- **Obfuscate** = SPILL suppression (leave no trail; command your spoor into a WATER tile to go dark).
- **Auspex** = READ the grid (replay any stain's owner/age/last-status — *Hemography*; mark routes combos).
- **Dominate** = COMMAND the blood *inside* a living body (puppet them by their veins; over-pull = exsanguination spill).
- **Presence** = REACT applied to morale (fear is a contagious field that flows through crowd topology like fluid).
- **Protean** = phase through the medium (mist-dash through bodies; claws apply bleed = SPILL-on-hit).

---

## 3. THE COMPOSITION ENGINE — five atoms × 9 disciplines × 6 surfaces × sockets = near-infinite builds

You don't *pick* a build from a list — you *discover* one by noticing what spill reacts with what surface
under what sigil. Three orthogonal axes, **all real hooks**:

1. **The `opts` bus.** `damage_entity(attacker, target, dmg, opts)` is *already* a per-hit modifier dict
   (`status`, `status_ticks`, `aoe_radius`, `knockback`, `lifesteal`, `damage_type`, `crit_chance`). Build
   modifiers are entries written into `opts` at cast time — `Fork`, `Chain`, `Ignite`, `Bloodbound` (pay
   HP not blood), `Echo`. The same `bs_bolt` becomes a 4-target chaining ignite-lance or a single
   Bloodbound nuke depending on which modifiers are socketed.
2. **The discipline-as-atom map** (§2) — composition needs no glue because everything is the same 5 verbs.
3. **The surface reaction matrix** — 6 surfaces × your `damage_type` = a chemistry table the *floor* runs
   whether or not you scripted it. The floor is a second combo string you author with your feet.

**The composition is ONE system, not five.** Per the audit (§7), we ship **the Trigger Web** as the single
build engine — a craftable event bus binding any power to auto-fire `ON-CRIT`, `ON-KILL`,
`ON-FEED-GULP-PERFECT`, `ON-BLOOD-BELOW-30%`, `ON-DODGE` (the gulp/crit/kill cues already emit). Sockets,
fusions, and HP-cost casting are *card types inside* it, layered later — not five parallel grammars on day one.

### Three worked builds — same five atoms, three unrecognizably different games

> The proof of *"system, not list"*: none introduces a mechanic absent from §1. They differ only in *which
> atoms they chain and in what order.*

**A · "The Dam-and-Drink Bunker"** *(Tremere · Blood Sorcery · sloped alley)* — a defensive hydrologist.
SPILL three thugs to bleed; let it run *downhill* (React's flow) into a chokepoint; COMMAND the pooled tide
up into a 3-tile `BLOOD IS WALL` clot funneling hunters single-file; DRINK the wall back as HP via theft.
Tremere's keystone (powers cost HP) means her casts *also* spill from her own body — the bunker is built
from her life and re-absorbed before she runs dry. **Loop: Spill → React(flow) → Command(wall) → Drink.**

**B · "The Red Line Skater"** *(Brujah · Celerity · open plaza)* — a momentum dancer who never stops. SPILL
a pool with one bite, then *skate* it: over wet blood `cel_dash` refreshes and velocity persists, ramping a
Tony-Hawk multiplier that makes dash *free* and lifesteal *higher* the longer the line is unbroken. The
trail is also his scent (Hemography) — so his skill expression is keeping the line short enough to be deadly
but not traceable. **Loop: Spill → Skate → Drink-multiplied.**

**C · "The Sun-Drinker Lawgiver"** *(Toreador · Inscribe-focused · dawn deathtrap)* — a rule-author who
reshapes hostile terrain instead of fighting it. Cornered in a sunlit plaza at dawn, she INSCRIBEs `SUN IS
BLOOD` across the square — the killing daylight now *pools as drinkable vitae*, which she DRINKs to tank the
dawn. A second `FEAR IS WALL` sigil turns her dread-pulse into a barricade of cowering bodies. Toreador's
keystone (sparing resets cooldowns) lets her re-paint endlessly by spare-biting. **Loop: Inscribe → Drink →
spare → re-Inscribe.**

Three players, five shared atoms, three different games. **That's the engine.**

---

## 4. THE OPEN VEIN — the flow system & continuous-play thrill

Combat has **no cooldown bar; it has a wound.** Every blood-spending action applies a literal `bleed` to
*you*, draining vitae each tick *and* SPILLing a real trail beneath your feet. You are the cauldron. The
aggression/greed dance becomes physical and visible — the harder you fight, the more of your life is on the floor.

- **Casual reading:** *"I bleed when I fight, so I bite to heal back. Don't let the wound run me dry."*
  The literal vampire fantasy, graspable in thirty seconds.
- **Pro reading:** the fight is a *closed economy* — spend blood to open combos, reabsorb it through
  frame-perfect feeds, theft, and standing in your own pools, **before the wound outpaces the intake.** A
  master plays a 60-second fight at net-zero blood, cycling the same vitae a dozen times.

**Why it's continuous (the Diablo/PoE "never stop" pull):** Spill→Command→React→Drink is self-feeding.
Every kill spills more reservoir, every reaction opens a new line, every drink funds the next spend. There
is no "wait for cooldown" dead-time — there is only *managing the tide.* The resource you flow is the floor itself.

---

## 5. THE THREE SIGNATURE PILLARS (what reviewers lead with)

All three hang off the *one* fluid spine; none is bolted on.

1. **THE OPEN VEIN** — *your resource bar is a controllable liquid you bleed onto the battlefield and drink
   back.* In every other action game mana is an abstraction behind glass; here greed is *visible on the
   floor*, and a master plays the encounter as a closed hydraulic loop. The pillar the other 45 ideas orbit.
2. **VITAE INSCRIPTION** — *you don't pick powers, you write the laws of a room in blood.* Baba Is You
   proved rules can be objects you rewrite — but its ink is free and its canvas resets. Here the **ink is
   your life** and the **canvas is persistent terrain the city erases** (rain washes it, enemies scuff it,
   React boils it). Rule-authoring becomes a tense *economic* gamble paid in the same vitae that is your HP.
3. **THE LIQUID CITY THAT REMEMBERS** — *persistent commandable blood is the city's memory across nights.*
   Every drop ever spilled flows, pools, seeps, and dries into stains. A Tremere with the never-cools
   keystone pre-seeds a building with kill-pools across multiple nights, then ignites the whole accumulated
   map at once — a strategy *impossible for any other clan and unscriptable by the designer.*

---

## 6. THE BLOOD GRADIENT — easy to learn, a lifetime to master

The casual mechanic and the pro mechanic are **the same knob read at two ends**, never bolted side by side.
Four cores that already ship, each with a Night-1 read needing zero theorycraft and a frame-measurable ceiling:

| Core | Night-1 casual read | 100-hour mastery ceiling |
|---|---|---|
| **A · Claw Combo** (`melee_light`, cancels into Heavy + Dash) | "Press attack, it feels good." Calm world → sloppy recovery is consequence-free. | The cancel window is **action-ticks 9–13 (~83ms)** in the back half of recovery; a pro reads the swing-end beat and dash-cancels Heavy's punish. *(Shipped skill-gap test: expert takes ≥40% less damage, same seed.)* |
| **B · Dash** (i-frames, cancels any recovery, ~0.4s cd) | "Tap twice, teleport out of danger." Panic button. | Dash *through* a telegraphed shot on its active frame; dash-cancel a whiffed Heavy to neutral. Casual dashes away; pro dashes through-and-into. |
| **C · Gulp Feed** (`GULP_WINDOW=15` ticks) | "Hold to bite; tap the flash for more." Forgiving; missing only slows the drain. | The same tap-timing, generalized into **Vein-Tap**, becomes the universal half-cost combat cancel stringing `bolt→bolt→dash` for the price of one. *The feed rhythm a casual learns Night 1 is the combat rhythm a pro masters.* |
| **D · Blood Is Everything** (unified Vitae) | "One red bar. Drink to refill, spend to cast." Intuitive because it's *one* number. | Every spend is a four-way tradeoff; Bloodbound builds make lifesteal outrun HP-cost ("unkillable while attacking"). Casual sees one bar; pro sees an economy. |

**The depth ramp** (complexity unlocks by *playing*, never a tutorial wall — a casual can stop at any phase
and still have a complete game):

| Phase | Hrs | Unlocks | Player feels |
|---|---|---|---|
| **The Bite** | 0–2 | Cores A–D raw, calm world, lone prey | "I'm a predator and it feels good." |
| **The Hunt** | 2–8 | First discipline; surfaces wake (spilled BLOOD is wet tile); hunters retaliate during recovery | "Oh — *when* I press matters." |
| **The Verb** | 8–20 | 2nd/3rd disciplines; surface reactions live; Vein-Tap bridge | "The floor is part of my combo." |
| **The Build** | 20–50 | Trigger Web + sockets; theorycraft *available, never required* | "This is MY build." |
| **The Lord** | 50–∞ | Hemo-Parry, Discipline Fusion, diablerie keystones, Red Tide hydrology | "I invent things designers never scripted." |

**Self-expression on-ramps:** because the cores are composable primitives, style emerges from *preference,
not theorycraft.* The casual who likes feeding drifts into a lifesteal-sustain style; the panicker becomes a
hit-and-run kiter; nobody chose a class — *their habits became their identity.* The same primitives invert
into a pro theorycraft space (herd-then-exsanguinate pumps, multi-night pre-seeded arson). One substance,
three skill tiers reading it differently.

**Accessibility that doesn't gut mastery** — assists widen *windows*, never remove the *skill*: Generous
Gulp (15→24-tick window), Sticky Cancel (input-buffer on the combo window), and the **calm-world rule itself
as the difficulty slider** (don't provoke heat → face no hunters). Never auto-combo or auto-aim — that's the
exact disease `ActionDef` was built to cure. Telegraphs make depth *visible*: the gulp flash teaches the
game's hardest rhythm in its safest moment; the animation swing-peak signals the cancel seam; hitstop
doubles as feedback and a timing anchor; a BLOOD tile near FIRE visibly shimmers "about to ignite."

---

## 7. WHAT WE ARE **NOT** BUILDING (the discipline that makes this shippable)

The brainstorm's auditor found the 38-idea pool was **9 decisions wearing costumes**, and that shipping all
of it would be the feature-factory the project keeps warning against. The cuts are part of the spec:

- **CUT · Crimson Rank (variety-gated style meter).** It *taxes mastery* — punishes a player who found a
  beautiful two-button loop for not spamming all nine disciplines. Anti-self-expression; the opposite of the goal.
- **CUT · Hitstop Banking, Blood Ante (menu slider), Sigil per-tick upkeep tax.** Meta-noise / spreadsheet
  decisions divorced from the moment / a main-skill that bleeds you for using it.
- **CUT · five parallel composition systems.** Ship **one** (Trigger Web); fold sockets/fusion/Bloodbound
  in as card-types later. Five grammars on day one is the disease.
- **RESHAPE · The Beast as second player.** Keep the *negotiation fantasy*; **never fight the player's
  stick** (drifting aim mid-combo feels like a broken controller). The Beast *adds tempting opportunities*
  (highlights prey, offers a free pounce you decline by acting, widens cancel windows when you "feed it
  slack") — it influences cost/reward, never overwrites input.
- **RESHAPE · all blood-memory ideas → one "The Long Night."** Death ages you on a Humanity↔power axis
  (getting stronger *is* getting more monstrous); Hemography + trail-forensics + false-trail bluffs fold in
  as its "blood remembers" sub-system.
- **DEFER · Marionette (full second avatar), Quicksilver-edits-the-fluid.** Great late-game toys; double the
  input/perf surface — not day one.

**The intuitive core a casual actually touches:** the blood bar + one cancel rhythm (gulp) + one composition
system (triggers) + the fluid floor. Everything else is opt-in mastery layered on top.

---

## 8. ENGINEERING CONSTITUTION — the one expensive prerequisite, built deterministically

The **fluid spine is the only true novelty and the only expensive prerequisite** — build it first or nothing
downstream is real. Today `SimWorld.surfaces` is *one inert byte per cell, set once at load, read only by
the renderer.* The Grammar upgrades each cell to **`{material, depth, owner, age, last_status}`** plus a
**fixed-tick flow + reaction pass.** The determinism rules are non-negotiable (Noita is famously *non*-
deterministic across machines — and this game's whole identity is deterministic replay):

- **Integer / fixed-point depth, never float.** No `randf()`/`randi()`/`Time.*` anywhere in the flow rule —
  all randomness via `Sim.rng`. (Grep-clean + the 20-run hash test gates it.)
- **Bounded active-set, not a full-grid scan.** A dirty-set of changed cells (+ neighbors) with a hard
  per-tick iteration cap, so a city-wide blood flood degrades gracefully instead of stalling the frame.
- **Fixed iteration order + double-buffered read/write** (ascending index, not Dictionary order) so replay
  is bit-identical.
- **Triggers defer to the next tick + are cooldown-gated** — prevents ON-KILL→kill→ON-KILL recursion within
  one tick (unbounded stack). Then the Trigger Web is deterministic and overflow-proof.
- **Slow-mo (`cel_bullet`) is an integer tick-divisor** (process flow every Nth tick), never a float
  timescale on the automaton.

The combat cluster (cancels, gulp-as-master-cancel, puppet-cancel) has **no sim-breakers** — `cancel_into`,
`combo_window_start/end`, `in_combo_window()`, `is_active_at()`, `hitstop_ticks` all already exist and are
tick-quantized. They are the *safest, cheapest* things to build, and the gulp window already ships.

---

## 9. BUILD ORDER

1. **Fluid spine** (int-depth buffer + bounded dirty-set flow/react pass). The prerequisite for everything.
2. **Gulp-as-master-cancel (Vein-Tap)** — cheapest high-impact skill-ceiling win; the window + `cancel_into`
   already ship. Fuses predation with combat.
3. **Surface Reaction Matrix** — one integer rule table once the fluid layer is live.
4. **Trigger Web** — the single composition system, next-tick-deferred + cooldown-gated.
5. **Vitae Inscription** — the signature rule-rewriting verb, on the fluid layer.
6. *(Later)* Command/Hemokinesis depth, The Long Night, diablerie keystones, the hydrology mastery ceiling.

*Validate each on the deterministic gate (20-run hash + GUT + capture) and prove the casual read is fun
before adding the next mastery tier.* The floor of the game and the ceiling of the game are the literal same
floor — the one covered in blood.
