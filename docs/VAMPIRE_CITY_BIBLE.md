# VAMPIRE CITY — The Game Bible
### The A-list game hidden in this repo, with every piece wired, surfaced, and feeding the others.

> This is the unifying vision: not a wishlist, but the design that makes **optimal use of what already
> exists** in this codebase and adds only the connective tissue that ties the pieces into one game.
> Everything below is anchored to real systems that are already coded (mostly in the deterministic
> `Sim`/`SimMeta` backend) or real assets already in the repo. The job it describes is **surfacing and
> interlocking** — turning ~25 quarantined backend systems and a pile of orphaned art into a coherent,
> sellable, replayable predator RPG. Read `CURRENT_STATE.md` for what's built, `MASTER_PLAN.md` for the
> build order, and `LEGACY_PORT_MATRIX.md` for the inventory this synthesizes.

---

## 0. The one-line pitch

**You are a newly-Embraced vampire clawing from street-predator to Lord of the Night across the nights
of one cursed city — hunting, feeding, and fighting with skill while a living city of hunters, rivals,
and factions remembers everything you do.** Diablo's build-depth, GTA's living-city wanted-system,
Hades' tight action, and Bloodlines' clan-as-identity, top-down, gothic, and dripping with consequence.

The four pillars (unchanged, now load-bearing on real systems):
- **Predator** — feeding and combat are *skills* (the gulp window, frame-data cancels, positioning).
- **Rise** — a visible climb from Fledgling to Prince, measured in Legend, territory, and power.
- **Cost** — every gain is paid in Humanity, Heat, Hunger, Masquerade exposure, or dawn risk.
- **Continuous** — the city simulates, escalates, and remembers between, during, and after your acts.

---

## 1. THE FLYWHEEL — how every piece feeds the others (the heart of this spec)

The whole point of the request: *make the pieces tie together.* Here is the loop where **no system is a
dead end — each one feeds at least two others.** This is the spec's spine; every later section serves it.

```
            ┌──────────────────────────────────────────────────────────────────┐
            │                         THE NIGHT                                  │
            │                                                                    │
   FEED (gulp+resonance) ──vitae──► POWERS / LAIR / EMBRACE                       │
        │                                   │                                    │
   humanity↓ / hunger / frenzy         skill tree / mastery                      │
        │                                   │                                    │
        ▼                                   ▼                                    │
   THE MASQUERADE  ◄──witnesses──  COMBAT (clan keystone + frame-data)           │
        │  heat↑                          │  loot drops                          │
        │                                 ▼                                      │
   HUNTERS / RESPONDERS ──spare/wound──► NEMESIS ──returns scarred──┐            │
        │  chase / last-known-pos                                    │           │
        ▼                                                            │           │
   ESCAPE / TERRITORY (domains) ──income+heat-cover+coterie jobs──► LEGEND ──────┘
        │                                                            │
        ▼                                                            ▼
   DAWN SCRAMBLE ──reach lair──► THE LAIR (hub) ──spend──► RISE (titles, NG, endgame)
```

**Read it as sentences (each is a wiring contract):**
1. **Feeding** (with the gulp skill + resonance choice) pays **Vitae**, the currency of powers, healing,
   the lair, and the Embrace — but costs **Humanity** (when you kill) and risks **Heat** (when seen).
2. **Humanity** isn't a number: it scales **exposure** (the city sees the monster) and **frenzy** risk,
   and gates the dawn — so the Cost pillar is *felt* in feeding, combat, and traversal.
3. **Combat** is where the **clan keystone** + **frame-data grammar** + **powers** (bought with Vitae,
   unlocked on the **skill tree**, sharpened by **mastery**) pay off — and where **loot** drops to feed
   **builds**, and where you wound hunters who become **nemeses**.
4. **The Masquerade/Heat** turns witnessed acts into **responders** who **search your last-known
   position** (not you) — the chase loop — and the **nemesis** you spared returns scarred and adapted.
5. **Territory (Domains)** claimed by surviving and winning pays **income**, gives **heat cover** on your
   turf, and hosts **coterie jobs** — turning a night's violence into a standing empire.
6. **Reputation** with the five factions routes which **contracts**, **events**, and **nemeses** you
   get; **Legend** earned from all of it unlocks **titles** that raise your domain/coterie caps and the
   **endgame** — the Rise.
7. **Dawn** ends every night as a scramble to a safe **haven**; the **Lair** is the hub where you spend
   Vitae/Coin/Legend on powers, rooms, the coterie, and the build — then the next night raises the
   stakes. **NG+/New Bloodline** carries prestige forward.

Every existing backend system has a node in this loop. The remaining work is *surfacing* each node and
*wiring the arrows* — most arrows are already coded in `SimMeta`; they're just not yet exposed to play.

---

## 2. MACRO STRUCTURE — the Rise (the connective frame that was missing)

The legacy had systems but no **destination**. This is the campaign spine that gives them one.

### 2.1 The arc: Fledgling → Prince of the City
A run is a sequence of **nights**. Your **Legend** and **Titles** (already coded: Fledgling → … →
Prince, gating domain/coterie caps) are the visible climb. The city has a **power structure** — a
sitting Prince (Camarilla), an Anarch movement, the Inquisition, and the gangs/police — and your nightly
choices push you up one of several **paths to rule**:
- **Camarilla Ladder** — play the Masquerade, do the Prince's contracts, inherit the throne.
- **Anarch Uprising** — burn the old order, rule by territory and force.
- **The Crucible** — survive and break the Inquisition; rule by being the last monster standing.

These are the legacy's **contract-chains** (already designed) re-cast as the macro objective.

### 2.2 The night loop (ties moment-to-moment to meta)
```
DUSK at the Lair  →  pick contracts / set goals (board)  →  go into the city (districts)
   →  hunt + feed + fight + claim + chase  →  ESCALATION (events, nemesis, heat)
   →  DAWN scramble to a haven  →  RECAP (a moment, not a menu)  →  spend at the Lair  →  next night
```
Each night is a **12–18 minute** session with a beginning (goals), middle (escalation), and a hard
deadline (dawn). The **Lair** is the hub between nights; the **city map** (districts) is the overworld.

### 2.3 The city as overworld (using the 4 districts that already exist)
The four coded districts — **Old Town, Docks, Red Row, Financial** — become a navigable map with
**distinct identity, danger, factions, and resources**, connected by streets (drive) and by **mist-travel
between claimed havens** (fast-travel, the "Lord of the night" fantasy). District **terror/prosperity**
state (already coded) makes them visibly pulse: a terrorized district has fled streets and heavy
responders; a prosperous one is rich hunting. *The slice "The First Hunt" is one block of one district.*

---

## 3. THE PREDATOR — moment-to-moment verbs (every one a skill)

The verbs already exist or are mid-build; this is how they interlock into a skill-ceiling grammar.

- **Move / Stalk** — GTA-facing movement + free-aim; **sneak** (silent, low exposure) vs **sprint**
  (fast, loud, blood cost). Light/shadow and **Humanity** modulate how seen you are.
- **Feed** *(built)* — grab → **gulp timing window** (tap on the beat for bonus Vitae + slowmo) →
  **kill or spare** (hold vs release). **Resonance**: every victim carries a humour (sanguine/choleric/
  melancholic/phlegmatic); reading it (Auspex aura) and choosing your prey grants a clan-synergistic
  buff. *Who, when, and how you feed is a build decision, not a pickup.*
- **Fight** — the **frame-data grammar** (startup/active/recovery, **cancel windows**, **hitstop**,
  knockback, lifesteal, status effects — all coded). Light→heavy→dash cancels reward execution;
  **input buffering**, **flank bonus**, and **dash i-frames** are the skill ceiling. A masher eats
  recovery; an expert flows. (The disease-denying metric: scripted expert beats masher on the same seed.)
- **Powers** — ~12–15 surfaced from the **46 coded powers** across 9 disciplines, each a *distinct input
  grammar*: Bolt (aim+lead), Slam (hold-charge), Dash (double-tap i-frames), Mesmerize (cone-channel),
  Mend (hold-immobile), Cloak/Vanish (stealth), Mark→Detonate (predator combo). Cost Vitae; on cooldown.
- **Drive** — vehicles as a real traversal/combat verb (hijack, drive-by, ram). Cars are also a dawn
  escape and a heat liability.
- **Escape** — break line-of-sight, duck the alley, watch the heat stars fade (the GTA loop).

---

## 4. CLANS AS IDENTITY — 7 forks, each a different game (full wiring)

All 7 clans already have boon/bane mods and a mutually-exclusive **keystone** in the catalog. The spec
makes each keystone a **rule change** that reshapes the loop (not a stat bump). This is the single biggest
"makes full use of the pieces" win — the clans exist; wire their keystones to the verbs.

| Clan | Keystone — the rule it rewrites | How it bends the flywheel |
|---|---|---|
| **Brujah** | *Blood Rage* — frenzy is an opt-in toggle (+dmg, CC-immune, no discipline) | turns the Beast from a cost into a weapon; pairs with choleric resonance |
| **Nosferatu** | *One With Shadow* — stealth kills don't break cloak; chain indefinitely | a pure-predator stealth game; feeds the heat-avoidance arrow |
| **Tremere** | *Vitae Alchemy* — half each power's blood cost comes from HP (glass-cannon mage) | spell-spam build; melancholic/sage resonance fuels it |
| **Ventrue** | *Iron Will* — dominated thralls become permanent (Influence÷5) | a coterie/empire game; feeds Domains + Embrace |
| **Toreador** | *Perfect Predator* — sparing a target resets ALL cooldowns | rewards mercy + flow; bends the kill/spare and Humanity arrows |
| **Gangrel** | *The Wild Hunt* — moving without stopping builds Hunt Stacks (+dmg/speed) | a momentum bruiser; pairs with vehicles + protean |
| **Malkavian** | *The Voices Know* — chance on cast for a free random power | chaotic combo engine; input/sanity noise as flavor |

Clan also gates **bespoke dialogue/solutions** (Fallout-tag style) and a **leitmotif** (audio) — a
Nosferatu reads a different city than a Ventrue. **`clan_emblems.jpg`** (already in repo) becomes the
clan-select sigils, the HUD clan badge, and the territory banners.

---

## 5. THE MASQUERADE, HUNTERS & THE NEMESIS WEB (the chase + the stakes)

All coded; this is the interlock.

- **Heat (0–6)** rises from **witnessed** crimes (scaled by witness rank: civ < thug < cop). Responders
  spawn at your **last-known-position** and **search** (perception cones, spreading uncertainty, ≥3
  distinct search behaviors). Star tiers escalate: cop → SWAT → **hunter** → **elder/Inquisition** (UV,
  stakes). Heat **bleeds when unseen**; clearing a tier disperses responders (the satisfying GTA payoff).
- **Witnesses** are people: they flee, call police, or describe you — and **bodies** you leave are
  evidence that raises heat when found. Disposing of bodies (dumpster/sewer) is a verb.
- **The Nemesis Web** — a hunter you **wound or spare** can flee, become a **named persistent rival**,
  and **return scarred and resistant to the damage type you used** (coded). Add **rival vampires** from
  enemy factions as the late-game mirror fights. These are your *personal* stakes threaded through the
  Rise — the city remembers you by name.

---

## 6. THE LIVING CITY — factions, territory, the world that pulses (surfacing the meta)

This is where the largest quarantined backend gets surfaced.

- **Five factions** (already coded): **Camarilla, Anarch, Inquisition, Gangs, Police**, with rival pairs.
  Your **reputation** with each routes which **contracts** you're offered, which **events** fire, who
  hunts you, and which **path to rule** opens. Rep is moved by your kills, spares, and contracts.
- **Domains (territory)** — the 4 districts subdivide into claimable turf. **Contest a Baron → claim →
  collect a nightly tithe.** Owned turf gives **heat cover**, **income**, and **coterie job** slots.
  District **terror/prosperity** reacts to your reign (coded) and visibly changes the streets.
- **Radiant events** (coded `EVENT_DEFS`): **gang war, crackdown, blood hunt, VIP, faint, bounty, domain
  raid** — a director fires them gated by heat + holdings, so the city *acts on its own* and your empire
  must be *defended*, not just collected. A **domain raid** on your turf is a defend-or-lose drama.

---

## 7. PROGRESSION & THE RISE (the climb, fully wired)

- **XP / Level (to 60)** → **skill points** → the **74-node skill tree** across the 9 disciplines, with
  **keystones as mutually-exclusive rule changes**. (Tree + powers coded; surface the tree screen with the
  sliced `discipline_icons`.)
- **Mastery (6 tracks, cap 12)** — predation, sorcery, brawn, survival, driving, nightstalker — passive
  ranks earned by *doing* (feeding levels predation, which **widens the gulp window** — a direct flywheel
  arrow). Persistent across nights.
- **Legend** → **Titles** (Fledgling → Prince) gate **domain cap, coterie cap, and the Embrace** — the
  visible Rise. **Codex** (collection: fed-types, killed-kinds, relics, districts, powers) gives
  completion bonuses and doubles as the in-fiction lore log. **Trophies** mark notable kills.

---

## 8. THE ECONOMY FLYWHEEL — 3 currencies, one compounding chain

Collapsed (per the design audit) to **Vitae** (blood — the resource/HP/mana), **Coin** (money), and
**Legend** (meta-progression). The compounding chain:

```
FEED → Vitae → powers / heal / Embrace / cellar storage
HOLDINGS: businesses (fronts) → Coin → upgrade businesses + claim domains
DOMAINS → tithe (Coin + Vitae) + heat cover + coterie job slots
COTERIE jobs (Herd/Fence/Spy/Guard) → passive Coin/Vitae while you hunt
UPKEEP (bribes, vitae wages, domain costs) at dawn → the SINK that keeps money meaningful
LEGEND from all of it → titles → bigger caps → more of everything
```
**5 businesses** (bloodbank/club/warehouse/antiquities/casino) and the domain/coterie systems are coded;
the spec wires the **upkeep sink at dawn** so the economy is a real decision, not idle income.

---

## 9. LOOT & BUILD IDENTITY (the Diablo layer, already coded)

**6 rarities** (common→relic), **14 affixes**, and **relics** are coded in the catalog. The spec's rule
(from the design audit): **relics rewrite verbs, not numbers.** Affix tiers + synergies + legendary
on-hit procs + the occasional **curse** (risk/reward) create the "hunt the roll" dopamine ladder.
Resonance-affinity on items ties loot to the feeding choice. This is the long-horizon endgame engine.

---

## 10. THE LAIR / HAVEN — the hub that ties it all together

The **6 haven rooms** (coffin, cellar, shrine, barracks, sanctum, workshop) are coded; the spec makes the
Lair the **hub-and-spoke center**:
- **The one guaranteed dawn-safe zone** (losing it = the endgame Final Siege).
- **Services**: heal, refill Vitae (cellar), bribe/clear-heat, respec, **alchemy** (workshop — refine/
  extract, coded), **Embrace** (sire a childe at the shrine).
- **Base-building**: rooms grant real mechanical effects (cellar = max blood, shrine = Humanity/frenzy
  control, barracks = coterie cap, workshop = crafting). A coin **sink** with permanent payoff.
- **The dawn recap** lives here — night duration, hunts, feeds, kills/spares, heat survived, Humanity
  delta, an authored epitaph line. A *moment*. **`haven_bg.jpg`** (already in repo) is this screen.

The **Coterie** (named, leveling childer with Herd/Fence/Spy/Guard jobs — coded, incl. the **Embrace**)
is your standing crew: combat allies you can summon, and passive income while you hunt. Ventrue's
keystone supercharges it. `npc_civilian.jpg` / portraits give them faces.

---

## 11. THE NIGHT — day/night/dawn as the core tension

The clock is coded; the spec makes dawn the **central dramatic pressure** (not a one-shot):
- Dusk (21:00) → dawn (05:00) ≈ 12–16 real minutes; the sky **lerps** through the gradient, lighting
  intensifying deep-night → pre-dawn blue → **killing gold**.
- Sun damage is **lethal and escalating** once it rises; the last 60s are a **scramble** to a haven.
  Failing = **torpor** (respawn at last haven with a Humanity/permanent cost). **Humanity scales** the
  danger. *Where you end the night is a real decision.*

---

## 12. THE SYSTEMIC WORLD — the immersive-sim layer (the "wait, I can do THAT?")

The **`SimWorld.Surface`** enum (blood, fire, water, sun, electric, shadow, haven) is coded as tiles; the
spec wires the **rules** so the world is a weapon (capped at ~6 strong interactions for legibility):
- **Sunlight patches** (dawn, UV lamps, broken skylights) — lure a rival vampire in to **dust** them
  (reuses the nemesis + sun-damage code; the single highest-ROI interaction — ship it first).
- **Fire** spreads along blood/oil, ignites enemies, deals aggravated damage to vampires.
- **Blood pools** conduct a chain "Blood Lash"; vampires can drink from them.
- **Water** conducts shock; **electricity** shocks anyone in water.
- **The AI obeys the same rules** — a warded Inquisitor shoved into fire dies regardless of who shoved
  him. This makes the 9 enemy types' counters *emergent*, not scripted (the Fallout/Dishonored payoff).

---

## 13. ENEMIES — 9 presets, 9 distinct micro-puzzles

Coded presets — **ped, thug, gunner, cop, swat, hunter, elder, thrall, rat** — each with a forced counter
(shield cop = flank/dash-behind; warded inquisitor = environmental kill; blood-mage rival = interrupt;
sniper = silence-first; swarm = AoE; bruiser = dodge-punish; **rival vampire** = fight your own optimal
combo). Elite affixes (coded) add modifiers. No two share an optimal counter.

---

## 14. AUDIO — the atmosphere half (architecture built; content to fill)

The **bus graph + CueBus bridge + procedural heartbeat** are built. The spec completes it:
- **Adaptive stems** (exploration/combat/chase/dawn) cross-faded by a tension value the CueBus drives;
  a 6-note "hunting call" leitmotif weaves through; **clan leitmotifs** sting on keystone use.
- **Positional audio** — hearing an offscreen **hunter's bootstep** or a victim's **heartbeat** is core
  predator fantasy. **Ducking + priority** (a kill sting ducks a footstep). **Radio** in vehicles (Ph.2).
- **Captions** for every meaningful cue (accessibility). The heartbeat already scales with hunger.

---

## 15. ART DIRECTION & UI — Dirty Urban Horror + NIGHT SHIFT (asset homes)

- **Art**: *Dirty Top-Down Urban Horror* — grimy concrete, headlight/police/neon light cones, wet
  asphalt, blood trails, GTA-readable silhouettes. Real **Light2D** + occluder shadows + neon bloom +
  dawn color-grade. Authored top-down sprites (generated) for every actor; **zero hero primitives**.
- **UI**: *NIGHT SHIFT* — occult police-scanner / crime-dossier (charcoal/crimson/amber/scanner-cyan/
  bone; Cinzel display, Oswald UI, ShareTechMono data). **Predator-Minimal HUD** in play (vitae/flesh/
  hunger fangs/heat stars/keystone badge/hotbar), **Occult-Dossier menus** (the case-file language) for
  the Lair, clan-select, skill tree, codex, map, and contracts board.

### 15.1 Asset utilization map (every existing piece gets a home — the explicit ask)
| Asset (in repo) | Wired home |
|---|---|
| `title_bg.jpg` | Main menu splash *(done)* |
| `player_vampire.jpg` | Menu portrait *(done)* + dossier/character screen + dialogue |
| `npc_civilian.jpg` | Coterie/victim portraits, codex, dialogue |
| `clan_emblems.jpg` | Clan-select sigils + HUD clan badge + territory banners |
| `discipline_icons.jpg` | Hotbar + skill-tree power icons *(sliced, done)* |
| `icon_celerity.jpg` | Discipline header / power tooltip art |
| `haven_bg.jpg` | The Lair hub screen + dawn recap + loading |
| `neon_sign.jpg`, `prop_lamp*`, `prop_tree*` | World dressing / billboards *(done)* |
| `projectile_blood.jpg` | Blood-bolt projectile *(done)* |
| `vehicle_{sedan,police,sport,van,hearse}.jpg` (side-view) | **Garage / Fleet screen** + vehicle-select + drive-by side-panel; generate top-down variants for in-world |
| `art/ui/*` (bars, fangs, stars, slot) | HUD *(done)* |
| 3 fonts, generated sprites | UI + actors *(done)* |

The side-view vehicle art finally earns its place as a **Garage/Fleet** dossier screen (where the empire's
cars live), while top-down generated variants drive the streets — *both* pieces used.

---

## 16. NARRATIVE — embodied in mechanics

Not a novel — enough authored content to make it a real vampire game, all hung on existing systems:
- **The sire's brief** (clan-specific) opens the campaign; the **herald** (first nemesis) is seeded at
  wake, demands your clan keystone at the first forced fight, and flees scarred — the slice's hook.
- **Faction contracts** carry the macro story (the 3 paths to rule).
- **Barks & reactive lines** — NPCs name you by your reputation/Humanity; hunters taunt; nemeses
  remember. **One banner per Humanity step**; a **dawn recap** epitaph each night.
- The **Codex** is the lore log; district identity + clan flavor + consequence text do the rest.

---

## 17. ENDGAME & REPLAYABILITY

- **Lord of the Night** — max Legend/title; you rule a path. The **Final Siege**: your Lair is raided
  (the standing threat behind base-building) — defend it or fall.
- **New Bloodline / NG+** — the coded **bloodline prestige** carries forward cosmetic/mechanical unlocks
  across generations; replay as a different clan, different path, harder city.
- **The loot ladder** + **difficulty modifiers** (Coin-purchased) + **radiant events** give the
  hundreds-of-hours tail. Difficulty-as-accessibility (the "Masquerade" easy mode is first-class).

---

## 18. TECHNICAL CONSTITUTION (already true — keep it)

- **Deterministic `Sim` autoload** is authority; the scene tree is a view; **`CueBus`** is the semantic
  seam. Zero `randf/randi/Time.*` in authoritative paths (all RNG via `Sim.rng`).
- **Save/load** persists the full run (var_to_str, lossless). **CI** runs headless GUT + a determinism
  gate on every push. **F3 debug overlay** reads sim truth. **50+ unit tests**, every feature
  determinism-gated. Performance budget: 60 FPS, object pools, spatial hash, no per-frame allocs in hot loops.

---

## 19. WHAT "OPTIMALLY USED" MEANS HERE — the wiring checklist

The game is "fully wired" when each of these arrows, **most of which are already coded in `SimMeta`**, is
*surfaced into play*:

- [ ] Feeding → gulp skill + resonance choice + Humanity/heat consequence *(gulp+humanity done)*
- [ ] Combat → clan keystone necessity + frame-data skill + loot drops
- [ ] Heat → last-known-pos search + witness reports + nemesis seeding
- [ ] Reputation → contracts offered + events fired + path-to-rule + who hunts you
- [ ] Domains → income + heat cover + coterie jobs + raid-defense drama
- [ ] Coterie → summonable allies + passive income + the Embrace + Ventrue synergy
- [ ] Skill tree + mastery → power unlocks + the gulp-window widen + build identity
- [ ] Legend → titles → caps → endgame (the Rise made visible)
- [ ] Economy → businesses → domains → lair → dominion, with the dawn **upkeep sink**
- [ ] Loot → relics-that-rewrite-verbs → builds → the endgame ladder
- [ ] Lair → hub services + base-building + dawn recap + the Final Siege stake
- [ ] Dawn → continuous scramble + Humanity-scaled sun + torpor cost
- [ ] Systemic surfaces → emergent enemy counters (start with the sun-dust kill)
- [ ] Every asset → its home (§15.1)
- [ ] Audio → adaptive stems + positional + leitmotifs + captions
- [ ] Narrative → sire/herald/nemesis + faction paths + barks + recaps

When every box is checked, the ~25 backend systems and the asset library are no longer a quarry — they're
**one game**, and it's the A-list predator RPG this repo has been hiding.

---

## 20. THE PATH TO IT (build order — see MASTER_PLAN.md for detail)

1. **Finish the vertical slice "The First Hunt"** — prove the predator core (gulp ✓, humanity ✓,
   resonance, keystones, dawn, the authored night) is *fun* in one block.
2. **Surface the meta** — the Lair hub, the contracts board, the skill-tree/codex/map/garage screens
   (wire the coded backend to real Occult-Dossier UI). This is the single biggest "use what we have" leap.
3. **Open the city** — the 4 districts as an overworld, territory/factions/events live, the Rise spine.
4. **Deepen** — loot ladder, systemic surfaces, rival vampires, audio stems, the Final Siege, NG+.
5. **Polish to Steam** — the capsule promise (§15), trailer beats, accessibility, performance gate.

*Do not begin step 2's breadth until step 1 is genuinely fun.* The slice is the proof; this bible is the
promise the slice is making.
