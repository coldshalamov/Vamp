/* =========================================================================
 * VAMPIRE CITY — data/gamedata.js
 * All static content: Disciplines & Powers, the Skill Tree, loot tables,
 * mission/quest templates, achievements, and name pools.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  // ---------------------------------------------------------------- POWERS
  const POWERS = {
    // Celerity
    cel_dash:   { name: 'Quicken', disc: 'celerity', type: 'active', cost: 8, cooldown: 3.5, fx: 'celDash', dist: 205, iframes: 0.35, glyph: '»', sound: 'spell', desc: 'Blink-dash forward, briefly intangible.' },
    cel_haste:  { name: 'Fleetness', disc: 'celerity', type: 'toggle', cost: 0, upkeep: 2.4, cooldown: 0.5, fx: 'celHaste', glyph: '≫', desc: 'Toggle: +40% move, +50% attack speed. Drains vitae.' },
    cel_flurry: { name: 'Blood Flurry', disc: 'celerity', type: 'active', cost: 12, cooldown: 10, fx: 'celFlurry', dur: 3.5, glyph: 'ϟ', desc: '+140% attack speed for 3.5s.' },
    cel_bullet: { name: 'Quicksilver', disc: 'celerity', type: 'active', cost: 25, cooldown: 28, fx: 'celBullet', dur: 4, glyph: 'O', desc: 'Slow time for all but you (4s).' },
    // Potence
    pot_slam:   { name: 'Earthshock', disc: 'potence', type: 'active', cost: 14, cooldown: 7, fx: 'potSlam', radius: 115, dmg: 24, knockback: 240, stun: 1.2, glyph: '*', sound: 'explode', desc: 'Ground slam: AoE damage, knockback & stun.' },
    pot_charge: { name: 'Brutal Charge', disc: 'potence', type: 'active', cost: 10, cooldown: 6, fx: 'potCharge', dist: 210, dmg: 26, glyph: '>', desc: 'Lunge through foes, stunning them.' },
    pot_quake:  { name: 'Cataclysm', disc: 'potence', type: 'active', cost: 30, cooldown: 22, fx: 'potQuake', radius: 185, dmg: 42, glyph: '#', sound: 'explode', desc: 'Massive shockwave; huge knockback + stun.' },
    // Fortitude
    for_mend:   { name: 'Mend Flesh', disc: 'fortitude', type: 'active', cost: 25, cooldown: 5, fx: 'forMend', heal: 48, glyph: '+', desc: 'Spend vitae to heal grievous wounds.' },
    for_stone:  { name: 'Stone Skin', disc: 'fortitude', type: 'active', cost: 12, cooldown: 14, fx: 'forStone', dur: 8, armor: 0.4, glyph: '◈', desc: '+40% damage resistance for 8s.' },
    for_unkill: { name: 'Unkillable', disc: 'fortitude', type: 'active', cost: 30, cooldown: 36, fx: 'forUnkill', dur: 2.6, glyph: '❂', desc: 'Become invulnerable for 2.6s.' },
    // Obfuscate
    obf_cloak:  { name: 'Cloak of Shadows', disc: 'obfuscate', type: 'toggle', cost: 6, upkeep: 1.4, cooldown: 0.5, fx: 'obfCloak', glyph: '◐', desc: 'Toggle stealth; enemies barely see you. Breaks on attack.' },
    obf_vanish: { name: 'Vanish', disc: 'obfuscate', type: 'active', cost: 18, cooldown: 22, fx: 'obfVanish', radius: 240, heat: 0.5, dur: 3, glyph: '◌', desc: 'Instantly break pursuit and slip away.' },
    obf_mask:   { name: 'Mask of a Thousand Faces', disc: 'obfuscate', type: 'active', cost: 35, cooldown: 55, fx: 'obfMask', stars: 2, glyph: '☻', desc: 'Assume a new face; clear up to 2 Heat stars.' },
    // Auspex
    aus_senses: { name: 'Heightened Senses', disc: 'auspex', type: 'toggle', cost: 0, upkeep: 0.6, cooldown: 0.5, fx: 'ausSenses', glyph: '◉', desc: 'Reveal foes & loot; +10% crit. Drains vitae slowly.' },
    aus_premon: { name: 'Premonition', disc: 'auspex', type: 'active', cost: 12, cooldown: 12, fx: 'ausPremon', dur: 6, dodge: 0.4, glyph: '⟁', desc: '+40% dodge for 6s.' },
    aus_mark:   { name: 'Aura of Frailty', disc: 'auspex', type: 'active', cost: 8, cooldown: 6, fx: 'ausMark', range: 380, dur: 10, amount: 0.35, glyph: '⊕', desc: 'Mark a foe: +35% damage taken, revealed.' },
    // Dominate
    dom_mesmer: { name: 'Mesmerize', disc: 'dominate', type: 'active', cost: 10, cooldown: 5, fx: 'domMesmerize', radius: 130, dur: 5, arc: 1.4, glyph: '๏', desc: 'Freeze foes ahead — set up a feed.' },
    dom_command:{ name: 'Command: Flee', disc: 'dominate', type: 'active', cost: 12, cooldown: 9, fx: 'domCommand', range: 220, dur: 5, glyph: '!', desc: 'Force a target to flee in terror.' },
    dom_forget: { name: 'Forgetful Mind', disc: 'dominate', type: 'active', cost: 20, cooldown: 26, fx: 'domForget', heat: 1, glyph: '☁', desc: 'Erase witnesses; reduce Heat.' },
    dom_thrall: { name: 'Bind Thrall', disc: 'dominate', type: 'active', cost: 30, cooldown: 40, fx: 'domThrall', range: 95, glyph: '⚇', desc: 'Enslave a weakened soul to fight for you.' },
    // Presence
    pre_dread:  { name: 'Dread Gaze', disc: 'presence', type: 'active', cost: 16, cooldown: 12, fx: 'preDread', radius: 165, dur: 5, glyph: '☠', desc: 'Terrify everyone nearby into flight.' },
    pre_majesty:{ name: 'Majesty', disc: 'presence', type: 'active', cost: 25, cooldown: 26, fx: 'preMajesty', dur: 6, glyph: '♔', desc: 'For 6s, mortals dare not strike you.' },
    pre_entr:   { name: 'Entrancement', disc: 'presence', type: 'active', cost: 18, cooldown: 18, fx: 'preEntrance', radius: 185, dur: 8, glyph: '♥', desc: 'Charm civilians into willing prey.' },
    // Protean
    pro_claws:  { name: 'Feral Claws', disc: 'protean', type: 'toggle', cost: 0, upkeep: 1.2, cooldown: 0.5, fx: 'proClaws', dmg: 0.5, lifesteal: 0.08, glyph: 'Ψ', desc: 'Grow claws: +50% melee, +8% lifesteal.' },
    pro_mist:   { name: 'Mist Form', disc: 'protean', type: 'active', cost: 25, cooldown: 18, fx: 'proMist', dur: 3, glyph: '≋', desc: 'Become mist: intangible & immune for 3s.' },
    pro_beast:  { name: 'Beast Form', disc: 'protean', type: 'active', cost: 30, cooldown: 28, fx: 'proBeast', dur: 10, glyph: 'Ϫ', sound: 'frenzy', desc: 'Transform: +60% melee, +35% speed, +30% HP.' },
    // Blood Sorcery
    bs_bolt:    { name: 'Blood Bolt', disc: 'sorcery', type: 'active', cost: 8, cooldown: 1.2, fx: 'bsBolt', dmg: 24, speed: 540, glyph: '•', desc: 'Hurl a bolt of congealed blood.' },
    bs_cauldron:{ name: 'Cauldron of Blood', disc: 'sorcery', type: 'active', cost: 14, cooldown: 7, fx: 'bsCauldron', range: 320, dps: 18, dur: 5, splash: 70, glyph: '≈', desc: "Boil a victim's blood; spreads to nearby." },
    bs_ward:    { name: 'Blood Ward', disc: 'sorcery', type: 'active', cost: 20, cooldown: 16, fx: 'bsWard', shield: 60, dur: 12, glyph: '⛨', desc: 'A shield of vitae absorbs damage.' },
    bs_theft:   { name: 'Theft of Vitae', disc: 'sorcery', type: 'active', cost: 5, cooldown: 4, fx: 'bsTheft', range: 300, dmg: 18, steal: 0.6, glyph: '⤚', desc: 'Rip blood from afar to refill your own.' },
    bs_storm:   { name: 'Blood Storm', disc: 'sorcery', type: 'active', cost: 35, cooldown: 20, fx: 'bsStorm', bolts: 14, dmg: 16, glyph: '✺', desc: 'Erupt in a radial storm of blood bolts.' },
    // Dark Arts
    shd_tendril:{ name: 'Shadow Tendrils', disc: 'dark', type: 'active', cost: 14, cooldown: 9, fx: 'shdTendrils', range: 280, radius: 95, dur: 3, dmg: 8, glyph: '♆', desc: 'Roots of darkness pin foes in place.' },
    shd_arms:   { name: 'Arms of the Abyss', disc: 'dark', type: 'active', cost: 12, cooldown: 7, fx: 'shdArms', range: 340, dmg: 14, pull: 130, glyph: '⇲', desc: 'Drag a distant foe to your fangs.' },
    dem_confuse:{ name: 'Dementation', disc: 'dark', type: 'active', cost: 18, cooldown: 15, fx: 'demConfuse', radius: 190, dur: 6, glyph: '⊗', desc: 'Madness! Foes turn on each other.' },
    vic_horrid: { name: 'Horrid Form', disc: 'dark', type: 'active', cost: 30, cooldown: 36, fx: 'vicHorrid', dur: 12, glyph: '⩕', sound: 'frenzy', desc: 'Monstrous form: +60% HP, +30% armor, +50% melee.' },
  };

  // clan weaknesses — supplied to recompute via Stats.persistentMods (never wiped on respawn/load)
  const CLAN_BANES = {
    brujah: { pct: { frenzyResist: -0.15 } },
    gangrel: { pct: { discount: -0.08 } },
    tremere: { pct: { maxHP: -0.10 } },
    ventrue: { pct: { feedYield: -0.12 } },
    toreador: { pct: { armor: -0.06 } },
    nosferatu: { pct: { discount: -0.12 } },
    malkavian: { pct: { maxBlood: -0.08 } },
  };

  // clan BOONS — a signature strength that gives each clan a distinct identity from minute one,
  // and leans your build toward an approach. Mirrors CLAN_BANES; folded via Stats.persistentMods.
  // (Nosferatu also get a stealth boon applied in code — Stealth.exposure reads p.clan.)
  const CLAN_BOONS = {
    brujah:   { pct: { meleeDmg: 0.15 } },                    // the warrior — open violence
    gangrel:  { pct: { moveSpeed: 0.10, hpRegen: 0.25 } },    // the beast — mobility & recovery
    tremere:  { pct: { spellPower: 0.18 } },                  // the sorcerer — Blood magic
    ventrue:  { add: { influence: 2 }, pct: { discount: 0.10 } }, // the lord — social/economic
    toreador: { pct: { feedYield: 0.15, critChance: 0.04 } }, // the artist — predation & finesse
    nosferatu:{ pct: { maxHP: 0.10 } },                       // the hidden — stealth (see Stealth.exposure)
    malkavian:{ pct: { cdr: 0.10 } },                         // the seer — faster disciplines
  };

  const DISCIPLINES = {
    celerity:  { name: 'Celerity', color: '#7ad0ff' },
    potence:   { name: 'Potence', color: '#e0b050' },
    fortitude: { name: 'Fortitude', color: '#9aa0a8' },
    obfuscate: { name: 'Obfuscate', color: '#8a8fb0' },
    auspex:    { name: 'Auspex', color: '#aef0ff' },
    dominate:  { name: 'Dominate', color: '#b98cff' },
    presence:  { name: 'Presence', color: '#ff9ecf' },
    protean:   { name: 'Protean', color: '#c1722a' },
    sorcery:   { name: 'Blood Sorcery', color: '#e0203f' },
    dark:      { name: 'Dark Arts', color: '#8a4bd0' },
    predator:  { name: 'Predator', color: '#c0303a' },
  };

  // ---------------------------------------------------------------- SKILL TREE
  // builder helpers
  function branch(id, name, color) { return { id, name, color, nodes: [] }; }
  function PW(b, id, name, power, tier, desc) { b.nodes.push({ id, branch: b.id, type: 'power', name, power, tier, desc, cost: 1, maxRank: 1, glyph: POWERS[power] && POWERS[power].glyph }); }
  function PS(b, id, name, tier, mods, desc, maxRank) { b.nodes.push({ id, branch: b.id, type: 'passive', name, tier, mods, desc, cost: 1, maxRank: maxRank || 1 }); }
  function KEY(b, id, name, tier, mods, desc) { b.nodes.push({ id, branch: b.id, type: 'keystone', name, tier, mods, desc, cost: 1, maxRank: 1 }); }

  const TREE = [];

  // -- Celerity branch
  let b = branch('celerity', 'Celerity', '#7ad0ff'); TREE.push(b);
  PS(b, 'cel_p0', 'Swift', 0, { pct: { moveSpeed: 0.05 } }, '+5% move speed', 3);
  PW(b, 'cel_n1', 'Quicken', 'cel_dash', 1, 'Unlock the dash.');
  PS(b, 'cel_p1', 'Reflexes', 1, { pct: { attackSpeed: 0.06, dodge: 0.02 } }, '+6% attack speed, +2% dodge', 3);
  PW(b, 'cel_n2', 'Fleetness', 'cel_haste', 2, 'Unlock the Fleetness toggle.');
  PS(b, 'cel_p2', 'Wind Step', 2, { pct: { moveSpeed: 0.07, cdr: 0.03 } }, '+7% speed, +3% cooldown reduction', 3);
  PW(b, 'cel_n3', 'Blood Flurry', 'cel_flurry', 3, 'Unlock Blood Flurry.');
  PW(b, 'cel_n4', 'Quicksilver', 'cel_bullet', 4, 'Bend time itself.');
  KEY(b, 'cel_key', 'Perfect Predator', 4, {}, 'Keystone [Toreador]: Sparing a target (release during feed) instantly resets ALL power cooldowns. Mercy is mechanically optimal.');

  // -- Potence
  b = branch('potence', 'Potence', '#e0b050'); TREE.push(b);
  PS(b, 'pot_p0', 'Brawn', 0, { pct: { meleeDmg: 0.07 } }, '+7% melee damage', 3);
  PW(b, 'pot_n1', 'Brutal Charge', 'pot_charge', 1, 'Unlock the charge.');
  PS(b, 'pot_p1', 'Heavy Hands', 1, { pct: { meleeDmg: 0.08, critMult: 0.05 } }, '+8% melee, +0.05 crit mult', 3);
  PW(b, 'pot_n2', 'Earthshock', 'pot_slam', 2, 'Unlock the ground slam.');
  PS(b, 'pot_p2', 'Crushing Blows', 2, { pct: { meleeDmg: 0.09 }, add: { critChance: 3 } }, '+9% melee, +3% crit', 3);
  PW(b, 'pot_n3', 'Cataclysm', 'pot_quake', 3, 'Unlock the cataclysm.');
  KEY(b, 'pot_key', 'Blood Rage', 4, {}, 'Keystone [Brujah]: Frenzy becomes an opt-in toggle (hold F+G). Frenzied: +40% damage, CC-immune, Disciplines blocked. Choose when to unleash the Beast.');

  // -- Fortitude
  b = branch('fortitude', 'Fortitude', '#9aa0a8'); TREE.push(b);
  PS(b, 'for_p0', 'Tough Hide', 0, { pct: { armor: 0.03, maxHP: 0.04 } }, '+3% armor, +4% HP', 4);
  PW(b, 'for_n1', 'Mend Flesh', 'for_mend', 1, 'Unlock self-healing.');
  PS(b, 'for_p1', 'Resilient', 1, { pct: { maxHP: 0.06, hpRegen: 0.15 } }, '+6% HP, +15% regen', 4);
  PW(b, 'for_n2', 'Stone Skin', 'for_stone', 2, 'Unlock Stone Skin.');
  PS(b, 'for_p2', 'Cold Blood', 2, { pct: { frenzyResist: 0.1, sunResist: 0.08 } }, '+10% frenzy resist, +8% sun resist', 3);
  PW(b, 'for_n3', 'Unkillable', 'for_unkill', 3, 'Unlock invulnerability.');
  KEY(b, 'for_key', 'Undying', 4, { pct: { armor: 0.15, maxHP: 0.15 } }, 'Keystone: +15% armor, +15% HP.');

  // -- Obfuscate
  b = branch('obfuscate', 'Obfuscate', '#8a8fb0'); TREE.push(b);
  PS(b, 'obf_p0', 'Soft Steps', 0, { add: { detectRange: -20 } }, 'Harder to detect', 3);
  PW(b, 'obf_n1', 'Cloak of Shadows', 'obf_cloak', 1, 'Unlock stealth.');
  PS(b, 'obf_p1', 'Predator', 1, { pct: { critChance: 0.05 } }, '+5% crit (ambush)', 3);
  PW(b, 'obf_n2', 'Vanish', 'obf_vanish', 2, 'Unlock combat escape.');
  PS(b, 'obf_p2', 'Night Cloak', 2, { pct: { bloodEff: 0.05 } }, '-5% vitae cost', 3);
  PW(b, 'obf_n3', 'Mask of Faces', 'obf_mask', 3, 'Unlock Heat clearing.');
  KEY(b, 'obf_key', 'One With Shadow', 4, {}, 'Keystone [Nosferatu]: Killing from stealth does not break cloak for 2s. Silent kills can chain indefinitely — become the dark itself.');

  // -- Auspex
  b = branch('auspex', 'Auspex', '#aef0ff'); TREE.push(b);
  PS(b, 'aus_p0', 'Keen Eye', 0, { add: { critChance: 3 } }, '+3% crit', 3);
  PW(b, 'aus_n1', 'Aura of Frailty', 'aus_mark', 1, 'Unlock the mark.');
  PS(b, 'aus_p1', 'Foresight', 1, { pct: { dodge: 0.04 } }, '+4% dodge', 3);
  PW(b, 'aus_n2', 'Heightened Senses', 'aus_senses', 2, 'Unlock sensory toggle.');
  PS(b, 'aus_p2', 'Killing Eye', 2, { pct: { critMult: 0.1 } }, '+0.1 crit multiplier', 3);
  PW(b, 'aus_n3', 'Premonition', 'aus_premon', 3, 'Unlock Premonition.');
  KEY(b, 'aus_key', 'The Voices Know', 4, {}, 'Keystone [Malkavian]: Each power cast has a 20% chance to trigger a free random power simultaneously. Manage the chaos.');

  // -- Dominate
  b = branch('dominate', 'Dominate', '#b98cff'); TREE.push(b);
  PS(b, 'dom_p0', 'Iron Will', 0, { pct: { cdr: 0.03 } }, '+3% cooldown reduction', 3);
  PW(b, 'dom_n1', 'Mesmerize', 'dom_mesmer', 1, 'Unlock crowd-freeze.');
  PS(b, 'dom_p1', 'Commanding', 1, { pct: { bloodEff: 0.04 } }, '-4% vitae cost', 3);
  PW(b, 'dom_n2', 'Command: Flee', 'dom_command', 2, 'Unlock the command.');
  PW(b, 'dom_n3', 'Forgetful Mind', 'dom_forget', 3, 'Erase witnesses.');
  PW(b, 'dom_n4', 'Bind Thrall', 'dom_thrall', 4, 'Recruit a thrall.');
  KEY(b, 'dom_key', 'Iron Will', 4, {}, 'Keystone [Ventrue]: Dominated thralls are permanent (up to Influence÷5). Mesmerize becomes a bind — your will is law.');

  // -- Presence
  b = branch('presence', 'Presence', '#ff9ecf'); TREE.push(b);
  PS(b, 'pre_p0', 'Charm', 0, { pct: { discount: 0.04, feedYield: 0.04 } }, '-4% prices, +4% feed yield', 3);
  PW(b, 'pre_n1', 'Dread Gaze', 'pre_dread', 1, 'Unlock fear AoE.');
  PS(b, 'pre_p1', 'Allure', 1, { pct: { feedSpeed: 0.08, xpMult: 0.03 } }, '+8% feed speed, +3% XP', 3);
  PW(b, 'pre_n2', 'Entrancement', 'pre_entr', 2, 'Charm willing prey.');
  PW(b, 'pre_n3', 'Majesty', 'pre_majesty', 3, 'Become untouchable.');
  KEY(b, 'pre_key', 'Star of the Damned', 4, { pct: { xpMult: 0.1, discount: 0.1, feedYield: 0.1 } }, 'Keystone: +10% XP, prices, & feed.');

  // -- Protean
  b = branch('protean', 'Protean', '#c1722a'); TREE.push(b);
  PS(b, 'pro_p0', 'Beast Blood', 0, { pct: { meleeDmg: 0.06, lifesteal: 0.02 } }, '+6% melee, +2% lifesteal', 3);
  PW(b, 'pro_n1', 'Feral Claws', 'pro_claws', 1, 'Grow lethal claws.');
  PS(b, 'pro_p1', 'Thick Pelt', 1, { pct: { armor: 0.05, maxHP: 0.05 } }, '+5% armor, +5% HP', 3);
  PW(b, 'pro_n2', 'Mist Form', 'pro_mist', 2, 'Become intangible.');
  PW(b, 'pro_n3', 'Beast Form', 'pro_beast', 3, 'Unleash the beast.');
  KEY(b, 'pro_key', 'The Wild Hunt', 4, {}, 'Keystone [Gangrel]: Moving without stopping builds Hunt Stacks (max 5). Each stack: +8% damage, +6% speed. Any stop or hit resets all stacks.');

  // -- Blood Sorcery
  b = branch('sorcery', 'Blood Sorcery', '#e0203f'); TREE.push(b);
  PS(b, 'bs_p0', 'Vitae Conduit', 0, { pct: { spellPower: 0.06 } }, '+6% spell power', 4);
  PW(b, 'bs_n1', 'Blood Bolt', 'bs_bolt', 1, 'Unlock the bolt.');
  PS(b, 'bs_p1', 'Hemomancer', 1, { pct: { spellPower: 0.07, bloodEff: 0.03 } }, '+7% spell power, -3% cost', 4);
  PW(b, 'bs_n2', 'Theft of Vitae', 'bs_theft', 2, 'Steal blood at range.');
  PW(b, 'bs_n3', 'Cauldron of Blood', 'bs_cauldron', 2, 'Boil their blood.');
  PW(b, 'bs_n4', 'Blood Ward', 'bs_ward', 3, 'Shield of vitae.');
  PW(b, 'bs_n5', 'Blood Storm', 'bs_storm', 4, 'Radial bolt storm.');
  KEY(b, 'bs_key', 'Vitae Alchemy', 4, {}, 'Keystone [Tremere]: Discipline blood costs halved. The other half drains from HP instead. Glass cannon blood mage — power from your own flesh.');

  // -- Dark Arts
  b = branch('dark', 'Dark Arts', '#8a4bd0'); TREE.push(b);
  PS(b, 'dk_p0', 'Shadowtouched', 0, { pct: { spellPower: 0.05 } }, '+5% spell power', 3);
  PW(b, 'dk_n1', 'Arms of the Abyss', 'shd_arms', 1, 'Pull foes to you.');
  PW(b, 'dk_n2', 'Shadow Tendrils', 'shd_tendril', 2, 'Root the wicked.');
  PS(b, 'dk_p1', 'Dread Presence', 2, { pct: { spellPower: 0.06, armor: 0.03 } }, '+6% spell power, +3% armor', 3);
  PW(b, 'dk_n3', 'Dementation', 'dem_confuse', 3, 'Sow madness.');
  PW(b, 'dk_n4', 'Horrid Form', 'vic_horrid', 4, 'Become a monster.');
  KEY(b, 'dk_key', 'Lord of Night', 4, { pct: { spellPower: 0.2, maxHP: 0.12 } }, 'Keystone: +20% spell power, +12% HP.');

  // -- Predator (general: feeding, blood, sustain, humanity)
  b = branch('predator', 'Predator', '#c0303a'); TREE.push(b);
  PS(b, 'prd_p0', 'Bloodhound', 0, { pct: { feedYield: 0.08, feedSpeed: 0.08 } }, '+8% feed yield & speed', 4);
  PS(b, 'prd_p1', 'Sanguine Pool', 1, { pct: { maxBlood: 0.1 } }, '+10% max vitae', 4);
  PS(b, 'prd_p2', 'Efficient Predator', 1, { pct: { bloodEff: 0.04 } }, '-4% power vitae cost', 3);
  PS(b, 'prd_p3', 'Vampiric Vigor', 2, { pct: { lifesteal: 0.04, hpRegen: 0.2 } }, '+4% lifesteal, +20% regen', 3);
  PS(b, 'prd_p4', 'Hardened Soul', 2, { pct: { frenzyResist: 0.12 } }, '+12% frenzy resistance', 3);
  PS(b, 'prd_p5', 'Glutton', 3, { pct: { xpMult: 0.06, maxBlood: 0.08 } }, '+6% XP, +8% vitae', 3);
  KEY(b, 'prd_key', 'Diablerie', 4, { pct: { lifesteal: 0.1, meleeDmg: 0.12, spellPower: 0.12 } }, 'Keystone: +10% lifesteal, +12% all damage.');

  // build flat index
  const TREE_INDEX = {};
  for (const br of TREE) for (const n of br.nodes) TREE_INDEX[n.id] = n;

  // ---------------------------------------------------------------- LOOT
  const RARITY = {
    common:    { name: 'Common', color: '#b8b8c0', affixes: 1, mult: 1.0 },
    uncommon:  { name: 'Uncommon', color: '#5ad06a', affixes: 2, mult: 1.25 },
    rare:      { name: 'Rare', color: '#5a9cff', affixes: 3, mult: 1.6 },
    epic:      { name: 'Epic', color: '#c060ff', affixes: 4, mult: 2.1 },
    legendary: { name: 'Legendary', color: '#ff9a30', affixes: 5, mult: 2.8 },
    relic: { name: 'Relic', color: '#ff7a30', affixes: 0, mult: 4.5 },
  };
  const RARITY_ORDER = ['common', 'uncommon', 'rare', 'epic', 'legendary', 'relic'];

  // weapons the player can equip (ranged); claws are innate
  const WEAPONS = [
    { kind: 'pistol',  name: 'Pistol',       dmg: 12, fireRate: 0.28, spread: 0.05, speed: 600, slot: 'weapon', glyph: 'r' },
    { kind: 'smg',     name: 'SMG',          dmg: 9,  fireRate: 0.10, spread: 0.10, speed: 640, slot: 'weapon', glyph: 'r' },
    { kind: 'shotgun', name: 'Shotgun',      dmg: 8,  fireRate: 0.7,  spread: 0.05, speed: 560, pellets: 6, slot: 'weapon', glyph: 'r' },
    { kind: 'magnum',  name: 'Magnum',       dmg: 30, fireRate: 0.6,  spread: 0.02, speed: 720, pierce: 1, slot: 'weapon', glyph: 'r' },
    { kind: 'rifle',   name: 'Assault Rifle',dmg: 16, fireRate: 0.13, spread: 0.06, speed: 720, slot: 'weapon', glyph: 'r' },
    { kind: 'stake',   name: 'Stake Launcher', dmg: 40, fireRate: 0.9, spread: 0.01, speed: 540, pierce: 2, slot: 'weapon', glyph: 'r' },
  ];

  // affix pools: each gives mods scaled by item level & rarity
  const AFFIXES = [
    { id: 'sharp', name: 'Sharp', mod: (lv) => ({ pct: { meleeDmg: 0.05 + lv * 0.004 } }), label: (lv) => `+${Math.round((0.05 + lv * 0.004) * 100)}% melee` },
    { id: 'arcane', name: 'Arcane', mod: (lv) => ({ pct: { spellPower: 0.05 + lv * 0.004 } }), label: (lv) => `+${Math.round((0.05 + lv * 0.004) * 100)}% spell power` },
    { id: 'cruel', name: 'Cruel', mod: (lv) => ({ add: { critChance: 3 + lv * 0.2 } }), label: (lv) => `+${(3 + lv * 0.2).toFixed(0)}% crit` },
    { id: 'savage', name: 'Savage', mod: (lv) => ({ pct: { critMult: 0.1 + lv * 0.006 } }), label: (lv) => `+${(0.1 + lv * 0.006).toFixed(2)} crit mult` },
    { id: 'swift', name: 'Swift', mod: (lv) => ({ pct: { attackSpeed: 0.04 + lv * 0.003 } }), label: (lv) => `+${Math.round((0.04 + lv * 0.003) * 100)}% attack speed` },
    { id: 'fleet', name: 'Fleet', mod: (lv) => ({ pct: { moveSpeed: 0.03 + lv * 0.002 } }), label: (lv) => `+${Math.round((0.03 + lv * 0.002) * 100)}% move speed` },
    { id: 'vital', name: 'Vital', mod: (lv) => ({ add: { maxHP: 15 + lv * 3 } }), label: (lv) => `+${Math.round(15 + lv * 3)} max HP` },
    { id: 'sanguine', name: 'Sanguine', mod: (lv) => ({ add: { maxBlood: 10 + lv * 2 } }), label: (lv) => `+${Math.round(10 + lv * 2)} max vitae` },
    { id: 'leeching', name: 'Leeching', mod: (lv) => ({ pct: { lifesteal: 0.02 + lv * 0.0015 } }), label: (lv) => `+${(2 + lv * 0.15).toFixed(1)}% lifesteal` },
    { id: 'warded', name: 'Warded', mod: (lv) => ({ pct: { armor: 0.03 + lv * 0.002 } }), label: (lv) => `+${Math.round((0.03 + lv * 0.002) * 100)}% armor` },
    { id: 'evasive', name: 'Evasive', mod: (lv) => ({ pct: { dodge: 0.02 + lv * 0.0015 } }), label: (lv) => `+${(2 + lv * 0.15).toFixed(1)}% dodge` },
    { id: 'attuned', name: 'Attuned', mod: (lv) => ({ pct: { cdr: 0.02 + lv * 0.0012 } }), label: (lv) => `+${(2 + lv * 0.12).toFixed(1)}% cooldown reduction` },
    { id: 'opulent', name: 'Opulent', mod: (lv) => ({ pct: { xpMult: 0.03 + lv * 0.002 } }), label: (lv) => `+${Math.round((0.03 + lv * 0.002) * 100)}% XP` },
    { id: 'predatory', name: 'Predatory', mod: (lv) => ({ pct: { feedYield: 0.05 + lv * 0.003 } }), label: (lv) => `+${Math.round((0.05 + lv * 0.003) * 100)}% feed yield` },
  ];

  const ATTIRE = [
    { kind: 'coat', name: 'Leather Coat', slot: 'attire', base: { pct: { armor: 0.05 } } },
    { kind: 'cloak', name: 'Midnight Cloak', slot: 'attire', base: { pct: { dodge: 0.05 } } },
    { kind: 'suit', name: 'Tailored Suit', slot: 'attire', base: { pct: { discount: 0.06 } } },
    { kind: 'mail', name: 'Hidden Mail', slot: 'attire', base: { add: { maxHP: 25 } } },
    { kind: 'shroud', name: 'Shroud of Night', slot: 'attire', base: { pct: { spellPower: 0.08 } } },
  ];
  const CHARMS = [
    { kind: 'signet', name: 'Bloodstone Signet', slot: 'charm', base: { pct: { maxBlood: 0.08 } } },
    { kind: 'fang', name: 'Ancient Fang', slot: 'charm', base: { pct: { feedYield: 0.1 } } },
    { kind: 'locket', name: 'Cursed Locket', slot: 'charm', base: { pct: { spellPower: 0.06 } } },
    { kind: 'ring', name: 'Ring of Celerity', slot: 'charm', base: { pct: { cdr: 0.05 } } },
    { kind: 'idol', name: 'Obsidian Idol', slot: 'charm', base: { add: { critChance: 5 } } },
  ];

  // ---------------------------------------------------------------- RELICS (build-defining legendary uniques)
  const RELICS = [
    { id: 'sanguine_heart', name: 'The Sanguine Heart', slot: 'charm', glyph: '♥', mods: { pct: { lifesteal: 0.30, maxHP: -0.15 } }, lore: 'It beats for none but the Beast.' },
    { id: 'tyrant_crown', name: 'Crown of the Tyrant', slot: 'attire', glyph: '♔', mods: { pct: { meleeDmg: 0.25, spellPower: 0.25, armor: -0.10 }, add: { influence: 3 } }, lore: 'Kneel, or be unmade.' },
    { id: 'antediluvian_fang', name: 'Fang of the Antediluvian', slot: 'charm', glyph: 'Ψ', mods: { pct: { feedYield: 0.50, feedSpeed: 0.30, lifesteal: 0.05 } }, lore: 'The first hunger, distilled.' },
    { id: 'mirror_nights', name: 'Mirror of Endless Nights', slot: 'charm', glyph: '◇', mods: { pct: { dodge: 0.25, cdr: 0.20, maxHP: -0.12 } }, lore: 'You were never truly there.' },
    { id: 'cauldron_stone', name: 'The Cauldron Stone', slot: 'charm', glyph: '≈', mods: { pct: { spellPower: 0.55, maxBlood: 0.25 }, add: { critChance: -5 } }, lore: 'Their blood remembers how to boil.' },
    { id: 'tempest_striders', name: 'Striders of the Tempest', slot: 'attire', glyph: '≫', mods: { pct: { moveSpeed: 0.35, attackSpeed: 0.20 } }, lore: 'Faster than dread itself.' },
    { id: 'obsidian_grin', name: 'The Obsidian Grin', slot: 'weapon', glyph: 'r', weaponBase: 'magnum', mods: { pct: { critChance: 0.15, critMult: 0.50 } }, lore: 'It only smiles at the very end.' },
    { id: 'shroud_methuselah', name: 'Shroud of the Methuselah', slot: 'attire', glyph: '☾', mods: { pct: { armor: 0.20, sunResist: 0.40, frenzyResist: 0.20 } }, lore: 'Centuries woven into cloth.' },
  ];

  // ---------------------------------------------------------------- HAVEN ROOMS (#1 base-building)
  const HAVEN_ROOMS = [
    { id: 'coffin', name: 'Elder Coffin', glyph: '⚰', desc: 'Rest deeper: +regen, fuller respawn, softer death penalty.', max: 5, cost: (l) => 200 + l * 280, mod: (l) => ({ pct: { hpRegen: 0.25 * l, bloodRegen: 0.12 * l } }) },
    { id: 'cellar', name: 'Blood Cellar', glyph: 'B', desc: 'Store bottled vitae (tithe & overflow) and raise max vitae.', max: 5, cost: (l) => 250 + l * 320, mod: (l) => ({ pct: { maxBlood: 0.06 * l } }) },
    { id: 'shrine', name: 'Blood Shrine', glyph: '✦', desc: '+XP gain and attunement to Elder Vitae.', max: 5, cost: (l) => 300 + l * 380, mod: (l) => ({ pct: { xpMult: 0.05 * l } }) },
    { id: 'barracks', name: 'Barracks', glyph: '⚔', desc: 'House more thralls & coterie (cap +1 per level).', max: 5, cost: (l) => 350 + l * 420, mod: () => ({}) },
    { id: 'sanctum', name: 'Hidden Sanctum', glyph: '◈', desc: 'Heat fades faster here; +frenzy resistance.', max: 5, cost: (l) => 300 + l * 360, mod: (l) => ({ pct: { frenzyResist: 0.04 * l, sunResist: 0.04 * l } }) },
    { id: 'workshop', name: 'Workshop', glyph: '⚒', desc: 'Craft elixirs & reforge gear; +spell power.', max: 3, cost: (l) => 500 + l * 600, mod: (l) => ({ pct: { spellPower: 0.05 * l } }) },
  ];

  // ---------------------------------------------------------------- BUSINESSES (#16 passive income)
  const BUSINESSES = [
    { id: 'bloodbank', name: 'Blood Bank Front', glyph: '♥', cost: 1200, cash: 28, vitae: 16, desc: 'Skims vitae from the city\'s veins.' },
    { id: 'club', name: 'Red Light Club', glyph: '♫', cost: 1700, cash: 70, vitae: 6, desc: 'Revelers, cash, and easy prey.' },
    { id: 'warehouse', name: 'Dockside Warehouse', glyph: '▣', cost: 2200, cash: 95, vitae: 0, desc: 'Smuggling pays well at night.' },
    { id: 'antiquities', name: 'Old Town Antiquities', glyph: '◇', cost: 2900, cash: 130, vitae: 0, desc: 'Relics and laundering.' },
    { id: 'casino', name: 'Underground Casino', glyph: '$', cost: 4500, cash: 210, vitae: 0, desc: 'The house always wins.' },
  ];

  // ---------------------------------------------------------------- MISSIONS
  // 8 mission types. Logic in missions.js keys off `type`.
  const MISSION_TYPES = [
    { type: 'feed', name: 'The Hunger', icon: '✚', color: '#c0303a', desc: 'Drain blood from {n} marked mortals without killing in the open.', baseReward: { xp: 160, money: 120 } },
    { type: 'assassinate', name: 'Blood Debt', icon: '☠', color: '#a02030', desc: 'Eliminate the target {name} — discreetly if you can.', baseReward: { xp: 260, money: 320 } },
    { type: 'collect', name: 'Relic Run', icon: '◆', color: '#c0a030', desc: 'Recover {n} relics scattered across the district before dawn.', baseReward: { xp: 200, money: 200 } },
    { type: 'escort', name: 'Safe Passage', icon: '♟', color: '#5a9cff', desc: 'Escort the Anarch courier to the haven alive.', baseReward: { xp: 240, money: 260 } },
    { type: 'cleanse', name: 'Purge the Nest', icon: '✖', color: '#e07020', desc: 'Wipe out the hunter cell — {n} foes — holed up nearby.', baseReward: { xp: 300, money: 360 } },
    { type: 'heist', name: 'Vitae Heist', icon: '$', color: '#30c060', desc: 'Raid the blood bank and escape with the vitae cache.', baseReward: { xp: 280, money: 500 } },
    { type: 'survive', name: 'Second Inquisition', icon: '✚', color: '#ff4040', desc: 'Survive {n} waves of the Inquisition.', baseReward: { xp: 340, money: 300 } },
    { type: 'courier', name: 'Night Errand', icon: '➤', color: '#9a6cff', desc: 'Deliver the sealed message across the city against the clock.', baseReward: { xp: 180, money: 160 } },
  ];

  // Per-contract APPROACH MODIFIERS — the lever that makes *how* you play a contract matter.
  // Rolled in missions.js; an optional constraint for a fatter purse, so a stealth build and a
  // gunline build optimise the same board differently. Violating the constraint just forfeits the bonus.
  const MISSION_MODIFIERS = [
    { id: 'none', name: '', tag: '', color: '#cdd', bonus: 0 },
    { id: 'none', name: '', tag: '', color: '#cdd', bonus: 0 },
    { id: 'nokill', name: 'Leave No Trace', tag: 'NO-KILL', color: '#7cc', desc: 'Bonus reward if no innocent dies.', bonus: 0.4 },
    { id: 'silent', name: 'Lights Out', tag: 'STEALTH', color: '#9bd', desc: 'Bonus reward if Heat never rises.', bonus: 0.45 },
    { id: 'fortified', name: 'Fortified', tag: 'HEAVY', color: '#e08', desc: 'Extra guards — but a bigger purse.', bonus: 0.35, harder: true },
    { id: 'bounty', name: 'High Profile', tag: 'BOUNTY', color: '#ffd24a', desc: 'Richer pay, but the city watches closer.', bonus: 0.5, hot: true },
  ];

  // ---------------------------------------------------------------- ACHIEVEMENTS
  const ACHIEVEMENTS = [
    { id: 'first_blood', name: 'First Blood', desc: 'Feed for the first time.', check: (g) => g.player.bloodState.fedCount >= 1 },
    { id: 'glutton', name: 'Insatiable', desc: 'Feed 50 times.', check: (g) => g.player.bloodState.fedCount >= 50 },
    { id: 'level10', name: 'Fledgling Rises', desc: 'Reach level 10.', check: (g) => g.player.level >= 10 },
    { id: 'level25', name: 'Ancilla', desc: 'Reach level 25.', check: (g) => g.player.level >= 25 },
    { id: 'level50', name: 'Methuselah', desc: 'Reach level 50.', check: (g) => g.player.level >= 50 },
    { id: 'arsenal', name: 'Diverse Arts', desc: 'Learn 10 powers.', check: (g) => Object.keys(g.player.powers).length >= 10 },
    { id: 'kills100', name: 'Reaper', desc: 'Slay 100 foes.', check: (g) => g.player.bloodState.kills >= 100 },
    { id: 'rich', name: 'Patron of the Night', desc: 'Hold $5000.', check: (g) => g.player.money >= 5000 },
    { id: 'mission10', name: 'Made Kindred', desc: 'Complete 10 missions.', check: (g) => g.missionsDone >= 10 },
    { id: 'driver', name: 'Road Reaver', desc: 'Hijack 10 vehicles.', check: (g) => g.player.stats.hijacks >= 10 },
    { id: 'untouchable', name: 'Untouchable', desc: 'Clear 5 Heat stars at once.', check: (g) => g._clearedFive },
    { id: 'humane', name: 'Golconda Seeker', desc: 'Reach level 20 with Humanity 8+.', check: (g) => g.player.level >= 20 && g.player.bloodState.humanity >= 8 },
    { id: 'monster', name: 'Embrace the Beast', desc: 'Drop to Humanity 2 or below.', check: (g) => g.player.bloodState.humanity <= 2 },
    { id: 'thralls', name: 'Sire', desc: 'Bind 5 thralls.', check: (g) => (g.player.stats.thralls || 0) >= 5 },
  ];

  // ---------------------------------------------------------------- NAMES
  const FIRST = ['Lucretia', 'Dorian', 'Vasilica', 'Mireille', 'Caine', 'Octavia', 'Sava', 'Isolde', 'Marquel', 'Drusilla', 'Tariq', 'Yvette', 'Bishop', 'Carmilla', 'Strauss', 'Nadia', 'Velvet', 'Gideon', 'Pisha', 'Jeanette'];
  const LAST = ['Ash', 'Vane', 'Mercurio', 'Voerman', 'LaCroix', 'Nostromo', 'Black', 'Stryker', 'Grout', 'Andrei', 'Ka', 'Holloway', 'Vermeer', 'Cross', 'Dane', 'Rourke'];
  const STREETS = ['Hollow St', 'Mourn Ave', 'Crimson Row', 'Vein Blvd', 'Gloom Lane', 'Pallor Way', 'Sable Dr', 'Wraith Ct', 'Dusk Mile', 'Ravensgate', 'Coffin Walk', 'Ash Quay'];

  VAMP.Data = {
    POWERS, DISCIPLINES, CLAN_BANES, CLAN_BOONS, TREE, TREE_INDEX, RARITY, RARITY_ORDER, WEAPONS, AFFIXES, ATTIRE, CHARMS, RELICS,
    HAVEN_ROOMS, BUSINESSES, MISSION_TYPES, MISSION_MODIFIERS, ACHIEVEMENTS, FIRST, LAST, STREETS,
  };
})();
