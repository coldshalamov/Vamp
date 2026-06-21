// Weighted scoring for deduped RPG features for a vampire top-down GTA RPG (vanilla JS Canvas)
// Weights: fun 0.25, depth 0.20, replayability 0.20, browser_feasibility 0.20, vampire_fit 0.15

const W = { fun: 0.25, depth: 0.20, replayability: 0.20, browser_feasibility: 0.20, vampire_fit: 0.15 };

// Each feature: name, category, scores {fun, depth, replayability, browser_feasibility, vampire_fit}, design_note
// ~50 deduped features. Heavy clusters merged per advisor guidance.
const features = [
  // ===== PROGRESSION / CHARACTER GROWTH =====
  {
    name: "Use-Based Skill Growth (learn by doing)",
    category: "progression",
    scores: { fun: 8, depth: 7, replayability: 7, browser_feasibility: 9, vampire_fit: 8 },
    design_note: "Skills rise from the actions you perform: feeding raises a Predation skill, sprinting on rooftops raises Agility, gunfights raise Firearms, mind-control raises Dominate. No separate XP grind — playing IS leveling. A counter per skill + threshold checks is trivial in JS. Becoming a 'feral brawler' vs 'silent stalker' emerges from how you actually hunt the city.",
  },
  {
    name: "Perk Trees gated by Core Attributes (SPECIAL-style)",
    category: "progression",
    scores: { fun: 8, depth: 9, replayability: 8, browser_feasibility: 8, vampire_fit: 8 },
    design_note: "Vampiric attributes (Strength/Celerity/Fortitude/Presence/Obfuscate) gate qualitative perks that add VERBS, not +1%: 'Mist Form' to pass under doors, 'Blood Boil' AoE, new dialogue intimidation. Two-axis climb (raise the discipline to open a column, gain levels for deeper ranks) gives long-horizon goals. Distinct from the mandated bare skill tree by being attribute-gated and verb-granting.",
  },
  {
    name: "Branching Ability + Mutagen/Slot Synergy Build Tree",
    category: "progression",
    scores: { fun: 8, depth: 9, replayability: 8, browser_feasibility: 8, vampire_fit: 7 },
    design_note: "Layers ON TOP of the in-scope skill tree, adding an active-slotting + synergy-multiplier mechanic rather than being another tree. Limited 'discipline slots' mean only socketed powers fire, and grouping same-school powers (all Blood-magic, all Beast) with a matching 'Vitae mutagen' multiplies that school's bonus. Forces deliberate synergy builds (blood-mage vs claw-duelist vs charm-thrall) and respec-driven experimentation rather than passively hoarding everything the tree unlocks.",
  },
  {
    name: "Grid-Based Stat/Skill Growth (Sphere-Grid-style)",
    category: "progression",
    scores: { fun: 7, depth: 8, replayability: 7, browser_feasibility: 8, vampire_fit: 6 },
    design_note: "A visible bloodline lattice where you move a token node-to-node spending 'Vitae spheres', SEEING your path. Branch off your clan's native path to poach another clan's powers. Tactile and min-maxable, renders cleanly on Canvas as a node graph. A spatial alternative/companion to the mandated linear skill tree.",
  },
  {
    name: "Dual-Class / Clan Mastery Combination",
    category: "progression",
    scores: { fun: 8, depth: 8, replayability: 9, browser_feasibility: 8, vampire_fit: 8 },
    design_note: "Layers ON TOP of the in-scope skill tree, adding a two-mastery combination mechanic rather than a new tree: pick TWO clan masteries and blend them (e.g. Brute + Shadow, Seer + Blood) to form named hybrid identities, multiplying build diversity from few branches. The second-mastery unlock is a memorable mid-game milestone, and replaying with a different pairing is effectively a new build path — a strong alt/replay driver.",
  },
  {
    name: "Set Bonuses (wear-N-pieces breakpoints)",
    category: "progression",
    scores: { fun: 7, depth: 6, replayability: 7, browser_feasibility: 9, vampire_fit: 6 },
    design_note: "Themed regalia sets ('Garb of the Nosferatu', 'Ventrue Court Attire') grant escalating bonuses at 2/4/6 pieces, the final piece delivering a build-defining leap. Creates clear collection checklists across the sandbox and a dramatic power threshold. Pure data tables + equip-count checks — easy in JS.",
  },
  {
    name: "Socketing, Runes & Gems (player-installed augments)",
    category: "progression",
    scores: { fun: 7, depth: 7, replayability: 7, browser_feasibility: 9, vampire_fit: 7 },
    design_note: "Weapons/relics have sockets for blood-gems and sigils that reshape stats; exact-order 'rune words' carved into the right base weapon unlock chase items (a stake that ignites, a blade that drinks vitae). Lets a beloved early item stay relevant by upgrading its inserts. Simple socket arrays in item objects.",
  },
  {
    name: "Paragon / Infinite Post-Cap Leveling",
    category: "meta",
    scores: { fun: 6, depth: 6, replayability: 8, browser_feasibility: 8, vampire_fit: 6 },
    design_note: "After the 50+ cap, every further kill/feed funnels XP into a never-ending stream of small permanent bonuses via a 'Elder Power' board with glyph sockets that amplify nearby nodes. Solves 'XP worthless at cap' and guarantees every monster moves a bar forever. Distinct from the mandated leveling because it is post-cap and board-based.",
  },
  {
    name: "Modular Ability-Item System (socket spells into gear)",
    category: "progression",
    scores: { fun: 8, depth: 9, replayability: 8, browser_feasibility: 7, vampire_fit: 7 },
    design_note: "Materia/skill-gem hybrid: powers live in 'blood orbs' you socket into weapons/armor; linked sockets transform them (Drain + Spread, Charm + Area). Orbs level independently with use. Decouples power from character so any build can wield anything — a combinatorial puzzle layered over the mandated spell list.",
  },
  {
    name: "Thrall Fusion & Co-op Combo Attacks",
    category: "progression",
    scores: { fun: 7, depth: 8, replayability: 8, browser_feasibility: 7, vampire_fit: 9 },
    design_note: "Persona-fusion logic applied to vampiric thralls: capture ghouls/beasts by draining them, then fuse two into a stronger servant, hand-picking inherited abilities (collection + sacrifice + inheritance). When the right thralls are fielded together, unlock joint attacks (you blink an enemy, your ghoul impales it), making brood COMPOSITION a creative axis. Perfectly on-theme — a vampire commands a recyclable, combo-capable brood.",
  },

  // ===== COMBAT FEEL & SYSTEMS =====
  {
    name: "Tactical Slow-Motion Targeting (Dead-Eye / V.A.T.S.)",
    category: "combat",
    scores: { fun: 9, depth: 7, replayability: 7, browser_feasibility: 7, vampire_fit: 8 },
    design_note: "A 'Predator Sense' meter that slows time so you paint targets/body parts then unleash a choreographed flurry of strikes or thrown stakes. Power fantasy + spend-the-meter resource decision; upgrades expand capacity and add crit-spot highlighting. Time-scaling the game loop is feasible in Canvas with a global dt multiplier.",
  },
  {
    name: "Dodge / Parry / Riposte Active-Defense Timing",
    category: "combat",
    scores: { fun: 9, depth: 8, replayability: 7, browser_feasibility: 8, vampire_fit: 7 },
    design_note: "A tight timing window to deflect/parry that opens an enemy for a deathblow feed. Moves mastery into the player's hands so an early enemy becomes trivial through SKILL, not stats — the purest felt progression. A vampire dash/blink as the dodge fits the fantasy. Hitbox+timing-window logic is standard Canvas fare.",
  },
  {
    name: "Stealth & Assassination Burst Multipliers",
    category: "combat",
    scores: { fun: 9, depth: 7, replayability: 7, browser_feasibility: 8, vampire_fit: 10 },
    design_note: "Undetected feeds/strikes deal massive multipliers — the silent-predator fantasy incarnate. Position in shadow, get the guaranteed amplified kill; sneak perks raise the multiplier until encounters collapse to a single pre-emptive bite. Core to being a vampire stalking prey from rooftops and alleys.",
  },
  {
    name: "Ability Cooldowns & Resource Rotations (builder/spender)",
    category: "combat",
    scores: { fun: 7, depth: 8, replayability: 7, browser_feasibility: 9, vampire_fit: 8 },
    design_note: "Blood is the resource: basic strikes/feeds GENERATE vitae, powerful disciplines SPEND it, each on a cooldown. Mastery = fluency sequencing the rotation, aligning burst windows. Builder/spender + cooldowns is a clean real-time economy and trivial to implement with timers. Blood-as-mana is deeply thematic.",
  },
  {
    name: "Status Effects & Damage-Over-Time (Bleed/Burn/Stun/Charm)",
    category: "combat",
    scores: { fun: 8, depth: 8, replayability: 7, browser_feasibility: 9, vampire_fit: 8 },
    design_note: "A second strategy layer: Bleed (thematic — victims hemorrhage vitae you can lap up), Burn (sunlight/fire), Charm/Fear (Presence disciplines), Stun. Investing in ailment chance/duration unlocks bleed-stacker or fear-lock build identities. Tick timers + status flags on entities; very JS-friendly.",
  },
  {
    name: "Elemental/Surface Interaction Chains",
    category: "combat",
    scores: { fun: 8, depth: 8, replayability: 7, browser_feasibility: 7, vampire_fit: 7 },
    design_note: "The battlefield as a chemistry set: spilled blood pools conduct a 'Blood Lash', oil ignites, water spreads fire-immunity, fog clouds break line-of-sight for stealth. Consistent rules the AI obeys too, so creativity beats raw stats. Tile/zone effect grid is moderately involved but very doable on Canvas.",
  },
  {
    name: "Armor-Gated Crowd Control (two-layer defense)",
    category: "combat",
    scores: { fun: 7, depth: 8, replayability: 6, browser_feasibility: 8, vampire_fit: 6 },
    design_note: "Two depletable bars (physical 'Flesh' / mystic 'Ward') over health; disables like Stun/Charm only land once the matching bar is zeroed — no RNG lock-loops. Makes focus-fire and damage-type mixing a tactical puzzle. Clean numeric model, easy to render as twin bars over enemies.",
  },
  {
    name: "Critical Hits & Floating Damage Numbers",
    category: "combat",
    scores: { fun: 8, depth: 5, replayability: 6, browser_feasibility: 10, vampire_fit: 6 },
    design_note: "Crit variance turns every strike into a micro-gamble; big floating numbers convert stat growth into legible spectacle and instant feedback on whether a gear swap mattered. As crit/damage scale, numbers inflate from tens to thousands — power read directly off-screen. Trivial Canvas text-sprite system; near-mandatory juice.",
  },
  {
    name: "Weakness-Break + Action-Stacking (Break/Boost)",
    category: "combat",
    scores: { fun: 8, depth: 8, replayability: 7, browser_feasibility: 8, vampire_fit: 7 },
    design_note: "Tough foes have a shield value and hidden weaknesses (silver, fire, holy, sunlight); hitting weaknesses Breaks them for a stun+damage window, while a banked Boost pool lets you stack actions for a burst exactly when they're Broken. A satisfying patience/timing rhythm; shield+weakness flags are simple data.",
  },

  // ===== LOOT / ITEMIZATION / ECONOMY (heavily merged) =====
  {
    name: "Loot Rarity Tiers + Mystery-Reveal (ID loop)",
    category: "economy",
    scores: { fun: 9, depth: 6, replayability: 7, browser_feasibility: 10, vampire_fit: 6 },
    design_note: "A color ladder (common/blooded/cursed/relic/legendary) makes every drop legible at a glance and delivers the dopamine slot-machine spike when a higher color hits; higher tier = more affix slots + bigger rolls. Cursed/unidentified relics drop with hidden rolls and require a ritual or scroll to reveal — a wrapped-gift suspense beat between 'found' and 'known' that also gates info for vendor-gambling. A color enum + drop-table weighting + one hidden flag; among the cheapest high-impact systems to build.",
  },
  {
    name: "Procedural Affixes + Bad-Luck Protection",
    category: "economy",
    scores: { fun: 8, depth: 9, replayability: 9, browser_feasibility: 9, vampire_fit: 6 },
    design_note: "Items assembled from randomized prefixes/suffixes with value ranges — the combinatorial engine of near-infinite loot. The hunt shifts from 'bigger numbers' to 'life + sun-resist + my damage type on one relic'; tiered mod brackets reward affix literacy. Layer a hidden pity counter that raises odds (or guarantees a chase relic after N kills) so dry streaks feel fair and finite, converting randomness into a climbing bar that prevents rage-quit on a coveted legendary. A weighted affix pool + roll function + one escalating-odds counter; pays off for hundreds of hours.",
  },
  {
    name: "Deterministic & Currency-Based Crafting",
    category: "economy",
    scores: { fun: 7, depth: 9, replayability: 8, browser_feasibility: 8, vampire_fit: 7 },
    design_note: "Spend farmed 'Vitae orbs / blood-currencies' to reroll, add, or remove item mods — MANUFACTURE upgrades instead of only praying for drops. Doubles as the economy. Late game = farm currency, deterministically push an item toward perfect. Rich depth from a set of orb functions; thematically blood is literally the currency.",
  },
  {
    name: "District-Tiered Scaling & Item-Level Gating",
    category: "world",
    scores: { fun: 7, depth: 7, replayability: 7, browser_feasibility: 9, vampire_fit: 6 },
    design_note: "Per-district level floors/ceilings tune enemy tier AND loot ceiling to where you are, so a non-linear sandbox never trivializes and deadlier districts physically produce better drops — your farming LOCATION becomes a progression dial and pushing into the worst slums/cathedral crypts is the only route to top mod tiers. Preserves the thrill of a district 'graduating' in danger and keeps combat advancement meaningful end-to-end. A scaling function on spawn + drop tables; watch immersion (no rats in relic armor).",
  },
  {
    name: "Gold / Economy Sinks (meaningful spending)",
    category: "economy",
    scores: { fun: 6, depth: 6, replayability: 6, browser_feasibility: 9, vampire_fit: 6 },
    design_note: "Give blood-money purpose: havens to buy and upgrade, respec rituals, gambling for relics, repair/recharge of corruptible gear, cosmetic coffins/garb. Sinks keep currency meaningful and turn a full wallet into latent power. Straightforward shop/cost logic; prevents runaway inflation in the open economy.",
  },

  // ===== WORLD REACTIVITY / SYSTEMIC OPEN WORLD =====
  {
    name: "Wanted-Level / Notoriety Escalation",
    category: "world",
    scores: { fun: 9, depth: 7, replayability: 8, browser_feasibility: 8, vampire_fit: 9 },
    design_note: "Feeding in public or leaving drained corpses raises a 'Masquerade-breach' heat ladder: from beat cops to SWAT to a vampire-hunter Inquisition with stakes and UV weapons. Lose line-of-sight, mist away, or dump the body to cool down. The purest engine of emergent player stories; GTA-core and perfectly vampiric (don't get seen feeding).",
  },
  {
    name: "Honor / Morality Reputation Axis",
    category: "social",
    scores: { fun: 8, depth: 7, replayability: 9, browser_feasibility: 9, vampire_fit: 9 },
    design_note: "A 'Humanity vs Beast' meter quietly tracks countless choices — feed-to-kill or feed-and-release, spare or slaughter, help or prey. High Humanity unlocks human passing/discounts/ally trust; low Humanity unlocks monstrous powers but NPCs flee and hunters swarm. Drives divergent endings. A single axis + threshold checks; emotionally on-theme.",
  },
  {
    name: "Reputation Gate (Street-Cred style unlock track)",
    category: "progression",
    scores: { fun: 7, depth: 7, replayability: 7, browser_feasibility: 9, vampire_fit: 8 },
    design_note: "A second bar separate from XP — 'Infamy among the Damned' — that gates access to elite blood-merchants, forbidden disciplines, fixer 'gigs', and the prince's court. Rising by doing notable underworld deeds keeps aspirational content visible-but-locked, a strong pull-forward. Just a points track with unlock thresholds.",
  },
  {
    name: "Branching Consequence & Faction Reputation",
    category: "world",
    scores: { fun: 8, depth: 9, replayability: 9, browser_feasibility: 7, vampire_fit: 9 },
    design_note: "Dual-axis fame/infamy per faction (Camarilla, Anarchs, Hunters, human gangs) reacting with prices, hostility, disguises-seen-through, and unique quest paths; choices surface hours later. Steering rep toward an endgame alignment is a long-term strategic layer. Branching content is authoring-heavy but the tracking is light; the vampire-clan-politics fit is ideal.",
  },
  {
    name: "Gang/Territory Control & Respect Metagame",
    category: "world",
    scores: { fun: 8, depth: 7, replayability: 8, browser_feasibility: 7, vampire_fit: 9 },
    design_note: "Layer a turf metagame: contest rival vampire broods or human gangs for city blocks that turn your color on the map, spawn friendly thralls, and yield blood/cash income while rivals try to retake them. A snowballing conquest loop independent of story missions — a vampire prince carving out a domain. AI waves + map-region ownership are moderate but classic.",
  },
  {
    name: "Day/Night Cycle with Stealth/Power Interplay",
    category: "world",
    scores: { fun: 9, depth: 7, replayability: 8, browser_feasibility: 8, vampire_fit: 10 },
    design_note: "THE defining vampire system: night grants power, concealment, sleeping prey; dawn is a lethal clock forcing you to a haven or to seek shade, with sun damage and weaker disciplines by day. Choosing WHEN to act becomes core tactics. A time variable driving lighting, spawn, and stat modifiers — very feasible and maximally on-theme.",
  },
  {
    name: "Enemy Variety & Affixes (elite modifiers)",
    category: "world",
    scores: { fun: 8, depth: 7, replayability: 8, browser_feasibility: 9, vampire_fit: 7 },
    design_note: "Procedural elite affixes (a hunter that's Blessed + Fast, a ghoul that's Frenzied + Regenerating) recombine a finite roster into endless tactical micro-puzzles, defeating combat fatigue across the sandbox. Higher districts stack deadlier mods. Just affix flags modifying stats/behavior — cheap variety multiplier.",
  },
  {
    name: "Augmentation-Driven Multi-Route Level Design",
    category: "world",
    scores: { fun: 8, depth: 8, replayability: 8, browser_feasibility: 6, vampire_fit: 8 },
    design_note: "Build every objective with multiple solutions keyed to disciplines: Mist-form under the door, Strength to rip the grate, Dominate the guard, or climb via wall-crawl. The world respects your character sheet, so build = playstyle. Authoring-intensive (handcrafted multi-path maps) but the immersive-sim payoff is huge and deeply vampiric.",
  },

  // ===== EXPLORATION / DISCOVERY / TRAVERSAL =====
  {
    name: "Discovery-Driven Exploration, Map Reveal & Fast Travel",
    category: "meta",
    scores: { fun: 8, depth: 6, replayability: 8, browser_feasibility: 9, vampire_fit: 7 },
    design_note: "Reward looking at the horizon: spot a cathedral spire or a glowing crypt, go there, find a hand-crafted site with loot, lore notes, a mini-story. The compass surfaces nearby undiscovered points and the filling map becomes a visible progress bar that sustains self-directed detours. Discovered havens/sewer entrances then double as fast-travel nodes — so the travel menu is a record of conquest, removes backtracking tedium, and is thematically a vampire 'mist-travelling' between claimed lairs to escape the killing dawn. Fog-of-war + POI markers + warp; standard and cheap once POIs exist.",
  },
  {
    name: "Radiant / Procedurally-Generated Quests",
    category: "world",
    scores: { fun: 7, depth: 6, replayability: 9, browser_feasibility: 8, vampire_fit: 7 },
    design_note: "Plug variable targets (a random feeding mark, a rival to dust, a relic to fetch) into reusable templates so bounty boards and court errands never run dry — perpetual 'next objective' after authored content ends, pulling you to unexplored corners. Template + target-picker is light JS and keeps the progression machine fed indefinitely.",
  },

  // ===== SOCIAL / DIALOGUE / NARRATIVE =====
  {
    name: "Dice-Roll Dialogue Checks & Social-Boss Duels",
    category: "social",
    scores: { fun: 8, depth: 7, replayability: 8, browser_feasibility: 8, vampire_fit: 9 },
    design_note: "Surface a visible roll + modifier vs a DC so conversations are build-dependent gambles with authored failure states; Dominate/Presence/Auspex grant bonuses and 'inspiration' re-rolls. Escalate select beats into dedicated 'social duel' set-pieces where reading a target and deploying the right argument resolves a major story moment WITHOUT violence — a Mesmerize/charm-vampire win condition that legitimizes a pure-talk build. RNG + modifier math plus authored conversation state machines; no new engine tech.",
  },
  {
    name: "Relationship / Confidant Mechanical Progression",
    category: "social",
    scores: { fun: 8, depth: 8, replayability: 8, browser_feasibility: 8, vampire_fit: 8 },
    design_note: "Deepening bonds with key NPCs (a ghoul retainer, a clanmate, a mortal lover/blood-doll) grants concrete perks: new disciplines, follow-up attacks, fusion discounts, safehouses. Budget limited nights to visit them — time-as-resource. Ranked relationship tracks + perk unlocks; makes the social layer mechanically load-bearing.",
  },
  {
    name: "Persistent Narrative via Death/Failure (one-more-run hook)",
    category: "social",
    scores: { fun: 8, depth: 7, replayability: 8, browser_feasibility: 8, vampire_fit: 8 },
    design_note: "Make 'death' diegetic: being staked/burned returns you to your haven/torpor where the story advances, NPCs react to your latest debacle, and relationships deepen via gifting vitae. Failure generates content so you're never just punished. Braids emotional investment into the loop; mostly writing + state flags.",
  },
  {
    name: "Origin/Clan/Background Dialogue Tags",
    category: "social",
    scores: { fun: 7, depth: 6, replayability: 9, browser_feasibility: 9, vampire_fit: 9 },
    design_note: "Hidden tags from your clan, mortal background (Noble, Criminal, Occultist) and embrace story surface bespoke lines and unique solutions only your character can use, checked continually as you progress. Makes creation a narrative investment and powers replay — a Nosferatu reads different text than a Ventrue. Just tag flags on dialogue nodes.",
  },
  {
    name: "Disposition/Personality Reputation Tracking",
    category: "social",
    scores: { fun: 6, depth: 7, replayability: 7, browser_feasibility: 9, vampire_fit: 7 },
    design_note: "Track HOW you speak (Cruel, Honest, Cunning, Regal) separately from faction standing; crossing a disposition rank unlocks unique persuasion lines and quest resolutions, so consistent role-play compounds into agency. Rewards committing to a vampiric persona. Lightweight counters nudged per dialogue pick.",
  },
  {
    name: "Skills-as-Internal-Voices (Thought Cabinet)",
    category: "progression",
    scores: { fun: 7, depth: 8, replayability: 7, browser_feasibility: 8, vampire_fit: 8 },
    design_note: "Reframe stats as competing inner voices — the Beast, the Hunger, old Humanity, clan instinct — that interrupt narration and gate which truths you can perceive. A 'Thought Cabinet' internalizes ideologies over time for permanent buffs/penalties. Character growth as a narrative/psychological act; a vampire's internal Beast-struggle is perfect for it. Mostly text + passive-effect flags.",
  },

  // ===== ROGUELITE / RUN-BASED BUILD-UP (adapted to optional modes) =====
  {
    name: "Boon-Stacking / God-Synergy Draft (per-incursion)",
    category: "combat",
    scores: { fun: 9, depth: 8, replayability: 9, browser_feasibility: 8, vampire_fit: 7 },
    design_note: "For optional 'blood hunt' incursions or the Inquisition's catacombs: each room offer a boon from a patron (Cain, Lilith, the clans) and let them combine into emergent build identities, with rare 'duo boons' rewarding committing to a pairing. Constrained-but-deep choice means no two runs alike. Offer-pool + stacking modifiers; great replay engine.",
  },
  {
    name: "Item Stacking with Multiplicative Interactions",
    category: "combat",
    scores: { fun: 8, depth: 8, replayability: 9, browser_feasibility: 8, vampire_fit: 6 },
    design_note: "Run-scoped pickups that stack multiplicatively so one hit chains into a screen-wipe — the snowball from fragile to unstoppable, with discovering broken combos as the joy. Pair with a time-pressure clock so you race your own power curve. Stacking counters applied to fire-rate/damage/proc-chance; the 'my build came online' payoff.",
  },
  {
    name: "Difficulty-Scales-With-Time Pressure Clock",
    category: "world",
    scores: { fun: 7, depth: 6, replayability: 8, browser_feasibility: 9, vampire_fit: 8 },
    design_note: "A persistent clock raises enemy HP/damage/spawn rate over a session — no safe farming, forcing push-vs-linger risk/reward. Doubles as the literal DAWN clock: linger feeding and the sun (and hunters) close in. Elegant pacing pressure; just a time-scaled difficulty multiplier. The sunrise framing is uniquely vampiric.",
  },
  {
    name: "Risk/Reward Gated Rooms (devil-deals / self-imposed heat)",
    category: "economy",
    scores: { fun: 8, depth: 7, replayability: 8, browser_feasibility: 9, vampire_fit: 8 },
    design_note: "Optional high-stakes choices: a cursed shrine trades max-Humanity (or max-blood capacity) for a powerful relic; voluntarily stacking 'Pact of the Hunt' handicaps raises rewards and unlocks deeper content. Player-authored difficulty makes power feel earned. Trade-a-resource-you-have-for-one-you-need; simple and addictive.",
  },
  {
    name: "Reusable Meta-Unlock Economy (blueprints widen the pool)",
    category: "meta",
    scores: { fun: 7, depth: 7, replayability: 9, browser_feasibility: 8, vampire_fit: 7 },
    design_note: "Run currency (collected 'souls/cells') spent to permanently unlock new weapons, disciplines, and starting kits INTO the drop pool — widening build variety rather than flatly inflating power, preserving skill ceiling. Funds endless 'one-more-incursion'. A persistent unlock ledger + pool filter; strong long-term retention for optional modes.",
  },
  {
    name: "Curated Draft with Steering + Convergent Investment",
    category: "progression",
    scores: { fun: 8, depth: 7, replayability: 8, browser_feasibility: 9, vampire_fit: 6 },
    design_note: "On each incursion power-up, draft from a small random set with steering tools — reroll, banish an option from the pool forever, skip-for-currency — so players author the build toward target synergies instead of being at RNG's mercy. Complement it with color/stat scrolls that scale only matching gear, forcing specialization into one or two colors for the classic mid-run 'build converged' spike (off-color drops abandoned). Converts a slot-machine into a controllable, snowballing engine; just pool manipulation + matching multipliers on the level-up menu.",
  },
  {
    name: "Rule-Rewriting Keystone Relics",
    category: "meta",
    scores: { fun: 9, depth: 8, replayability: 9, browser_feasibility: 8, vampire_fit: 8 },
    design_note: "A few transformative relics that CHANGE RULES, not numbers: 'your bite fires a blood-laser', 'you no longer take sun damage but lose all healing', 'feeding heals allies'. Finding one mid-game pivots the whole plan and creates stories. Each is a bespoke conditional, but a handful deliver outsized memorability and theorycraft depth.",
  },
  {
    name: "Weapon Evolution via Passive-Item Synergy",
    category: "combat",
    scores: { fun: 8, depth: 7, replayability: 8, browser_feasibility: 9, vampire_fit: 7 },
    design_note: "A maxed weapon + its specific passive evolves into a dramatically stronger form (Stake + Zealot's Fervor -> Sunfire Lance; Blood Whip + Crimson Heart -> Sanguine Scourge). Turns a run into a puzzle of assembling the right pairs before the clock escalates, with a screen-clearing payoff. Lookup-table on max-level + passive-owned; cheap and very satisfying.",
  },

  // ===== ENDGAME / DIFFICULTY LADDER / RETENTION =====
  {
    name: "Endgame Infinite Difficulty Ladder (Greater-Rift/Maps style)",
    category: "world",
    scores: { fun: 8, depth: 8, replayability: 9, browser_feasibility: 8, vampire_fit: 7 },
    design_note: "Beyond the story, an open-ended ladder of harder, better-rewarding instances ('Descent into the Catacombs', tier N) where your build quality is expressed as the highest tier you clear — vague 'getting stronger' becomes a precise, self-pacing, leaderboard-able metric that gives loot a purpose. One scaling multiplier + tier counter; the true endgame engine.",
  },
  {
    name: "Rotating-Modifier Keystone Dungeons (Mythic+ style)",
    category: "combat",
    scores: { fun: 8, depth: 8, replayability: 8, browser_feasibility: 8, vampire_fit: 7 },
    design_note: "Layer onto the ladder a weekly-rotating set of modifier affixes plus an optional timer, so the same crypt plays differently and carries score stakes; beating it upgrades your 'key', failing downgrades it. Rotating affixes defeat content fatigue. Affix-set rotation + timer + key state; reuses existing dungeons for huge replay value.",
  },
  {
    name: "Seasonal Reset + Recurring Objective Cadence",
    category: "progression",
    scores: { fun: 6, depth: 5, replayability: 8, browser_feasibility: 7, vampire_fit: 6 },
    design_note: "Optional fresh-start 'Bloodlines' seasons that wipe a ladder character, restoring the addictive early power curve plus a unique seasonal mechanic and a guided objective journey that dispenses rewards. Layer shorter rotating 'nightly contracts' (feed on 3 marks, clear a crypt) with guaranteed rewards and a weekly 'Vault'-style CHOICE of loot from a pool you filled by varied play — a 10-minute reason to return. For an offline browser game these are real-clock timers + an objective generator + a separate save-slot model; heavier lift, best post-launch.",
  },
  {
    name: "Prestige Collection & Long-Tail Mastery Capes",
    category: "collection",
    scores: { fun: 7, depth: 6, replayability: 8, browser_feasibility: 9, vampire_fit: 8 },
    design_note: "Once power plateaus, prestige retains the devoted on two fronts. Collection: transmog coffins/garb/cloaks, mounts (a dire-bat?), a hunted-prey bestiary, and earned titles ('Scourge of the Cathedral District') shown on your profile — decoupling reward from power into a personal museum + status. Mastery: several disciplines/professions (Hunting, blood-brewing, Lockpicking) get their own steep individually-levelable curves to a 'mastery cape', so the PLAYER picks which months-long self-directed goal to chase. Pure data + appearance swaps + counters with exponential curves; evergreen long-tail.",
  },
];

// Compute weighted totals
for (const f of features) {
  const s = f.scores;
  f.weighted_total = +(W.fun*s.fun + W.depth*s.depth + W.replayability*s.replayability + W.browser_feasibility*s.browser_feasibility + W.vampire_fit*s.vampire_fit).toFixed(3);
}

// Sort best-first, with deterministic tiebreak: total, then fun, then vampire_fit, then name
features.sort((a, b) =>
  b.weighted_total - a.weighted_total ||
  b.scores.fun - a.scores.fun ||
  b.scores.vampire_fit - a.scores.vampire_fit ||
  a.name.localeCompare(b.name)
);

// Mandated exclusions: features that would essentially BE a mandated system.
// Rule: exclude only features that simply ARE the mandate; keep mechanics that ENRICH it.
const mandatedExcludeNames = new Set([
  // "a skill tree" -> the plain attribute/skill-tree systems themselves
  "Perk Trees gated by Core Attributes (SPECIAL-style)",
  "Grid-Based Stat/Skill Growth (Sphere-Grid-style)",
  // "50+ levels" -> the base use-based leveling METHOD itself
  "Use-Based Skill Growth (learn by doing)",
  // "learnable magic spells" -> kept distinct ability/item SYSTEMS (modular orbs, thrall fusion,
  //   mutagen-slotting, dual-mastery) as ENRICHMENTS, not as "a spell list"
]);

const top20 = features
  .filter(f => !mandatedExcludeNames.has(f.name))
  .slice(0, 20)
  .map(f => f.name);

console.log("=== RANKED (best first) ===");
features.forEach((f, i) => {
  const mark = mandatedExcludeNames.has(f.name) ? " [MANDATE-EXCLUDED]" : "";
  console.log(`${String(i+1).padStart(2)}. ${f.weighted_total.toFixed(3)}  ${f.name}${mark}`);
});
console.log(`\nTotal features: ${features.length}`);
console.log(`\n=== TOP 20 (additional, excluding mandates) ===`);
top20.forEach((n, i) => console.log(`${String(i+1).padStart(2)}. ${n}`));

// Sanity: weights sum
console.log(`\nWeights sum: ${Object.values(W).reduce((a,b)=>a+b,0)}`);

const methodology =
  "Weighted score out of 10 per dimension, combined as weighted_total = 0.25*fun + 0.20*depth + " +
  "0.20*replayability + 0.20*browser_feasibility + 0.15*vampire_fit (weights sum to 1.0, so max = 10). " +
  "Raw 1-10 scores were assigned by design judgment; browser_feasibility and vampire_fit (combined 0.35 weight) " +
  "were scored with deliberate spread as the game-specific discriminators — MMO/live-service/trilogy-import " +
  "primitives drop on feasibility for a single-player vanilla-JS Canvas build, while night/stealth/notoriety/" +
  "honor systems spike on vampire_fit. The ~60 source features were deduped to 51 by merging heavy-overlap " +
  "clusters (itemization, infinite-difficulty ladders, reputation/morality, run-based drafts, live-service " +
  "retention), each merge re-scored with a union design_note. Totals are computed and sorted programmatically " +
  "(tiebreak: total -> fun -> vampire_fit -> name). " +
  "top20 = the 20 highest-ranked features AFTER excluding only those that simply ARE a user-mandated system " +
  "(per the rule 'exclude what IS the mandate, keep what ENRICHES it'): the SPECIAL-style perk tree and the " +
  "Sphere-grid both ARE 'a skill tree', and use-based growth IS the '50+ levels' method, so all three are " +
  "excluded from top20 (they remain ranked). By contrast Dual-Mastery combination and the Mutagen/active-slot " +
  "synergy layer are kept as ADDITIVE mechanics on top of the in-scope tree, and the modular ability-item / " +
  "thrall-fusion systems are kept as distinct from 'a learnable spell list', not duplicates of it.";

// Emit JSON for the structured output
const out = {
  methodology,
  ranked: features.map(f => ({
    name: f.name,
    category: f.category,
    scores: f.scores,
    weighted_total: f.weighted_total,
    design_note: f.design_note,
  })),
  top20,
};
require('fs').writeFileSync('C:/Users/93rob/Documents/GitHub/Vamp/scored.json', JSON.stringify(out, null, 2));
console.log("\nWrote scored.json");

// ===== VERIFICATION =====
console.log("\n=== VERIFICATION ===");
const names = features.map(f => f.name);
const dupes = names.filter((n, i) => names.indexOf(n) !== i);
console.log("Duplicate feature names:", dupes.length ? dupes : "none");
console.log("top20 length:", top20.length, "(expect 20)");
const nameSet = new Set(names);
const unmatched = top20.filter(n => !nameSet.has(n));
console.log("top20 names not matching a ranked name:", unmatched.length ? unmatched : "none");
const excludedInTop20 = top20.filter(n => mandatedExcludeNames.has(n));
console.log("mandate-excluded names leaking into top20:", excludedInTop20.length ? excludedInTop20 : "none");
// Spot-check tie boundary around the cut
const cutCandidates = features.filter(f => !mandatedExcludeNames.has(f.name));
console.log("Boundary (ranks 18-22 of eligible):");
cutCandidates.slice(17, 22).forEach((f, i) =>
  console.log(`  elig#${i+18}  ${f.weighted_total.toFixed(3)}  fun${f.scores.fun} vfit${f.scores.vampire_fit}  ${f.name}`));
