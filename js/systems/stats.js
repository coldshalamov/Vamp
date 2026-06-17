/* =========================================================================
 * VAMPIRE CITY — systems/stats.js
 * Attributes, derived-stat recomputation, XP curve (1..60), level-ups,
 * Blood Potency / Generation. Data-driven; recompute() folds attributes +
 * skill tree + equipment + buffs into player.derived.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  const MAX_LEVEL = 60;
  const ELDER_XP = 2000;   // XP per Elder Vitae point past the cap

  // The six core attributes (VtM-inspired, action-RPG tuned)
  const ATTRS = [
    { id: 'might', name: 'Might', desc: 'Melee damage & knockback' },
    { id: 'finesse', name: 'Finesse', desc: 'Move & attack speed, dodge' },
    { id: 'vitality', name: 'Vitality', desc: 'Max health & regeneration' },
    { id: 'bloodcraft', name: 'Bloodcraft', desc: 'Max vitae & discipline potency' },
    { id: 'wits', name: 'Wits', desc: 'Cooldown reduction & critical chance' },
    { id: 'presence', name: 'Presence', desc: 'Feeding, influence, prices, XP gain' },
  ];

  // ---- XP curve ----
  // XP needed to advance FROM level L to L+1.
  // Geometric growth that hard-caps at L45, so late levels stay ~flat (~5-6k) instead of a wall.
  function xpToNext(L) {
    const cl = Math.min(L, 45);
    return Math.floor(70 * Math.pow(1.085, cl - 1) + 55 * cl + 40 * Math.max(0, L - 45));
  }
  function totalXpForLevel(L) {
    let t = 0; for (let i = 1; i < L; i++) t += xpToNext(i); return t;
  }

  // Blood Potency rises every ~7 levels and keeps climbing to L57+ (no dead late levels)
  function bloodPotency(level) { return Math.min(9, Math.floor((level - 1) / 7)); }
  function generation(level) { return 13 - bloodPotency(level); }

  function newAttributes() {
    return { might: 1, finesse: 1, vitality: 1, bloodcraft: 1, wits: 1, presence: 1 };
  }

  // ---- derived-stat recompute ----
  // pulls from: base + attributes + skill-tree mods (player.mods) + equipment (player.equipMods) + buffs (player.buffMods)
  function recompute(p) {
    const a = p.attributes;
    const bp = bloodPotency(p.level);

    // accumulate additive & multiplicative modifier bags
    const m = blankMods();
    addMods(m, treeMods(p));
    addMods(m, equipMods(p));
    addMods(m, buffMods(p));
    addMods(m, persistentMods(p));   // clan bane + haven + mastery + codex + reputation + elder + trophies (never wiped)
    p.mods = m; // expose for UI

    const get = (k) => m.add[k] || 0;
    const mul = (k) => 1 + (m.pct[k] || 0);

    const d = p.derived || (p.derived = {});

    d.bloodPotency = bp;
    d.generation = generation(p.level);

    // Max HP / Vitae
    d.maxHP = Math.round((100 + (a.vitality - 1) * 9 + (p.level - 1) * 4 + get('maxHP')) * mul('maxHP'));
    d.maxBlood = Math.round((100 + (a.bloodcraft - 1) * 6 + bp * 12 + get('maxBlood')) * mul('maxBlood'));
    if (!isFinite(d.maxHP) || d.maxHP < 1) d.maxHP = 100;     // never let a bad input brick survival
    if (!isFinite(d.maxBlood) || d.maxBlood < 1) d.maxBlood = 100;

    // movement / attack
    d.moveSpeed = (158 + (a.finesse - 1) * 1.6 + get('moveSpeed')) * mul('moveSpeed');
    d.attackSpeed = (1 + (a.finesse - 1) * 0.012 + get('attackSpeed')) * mul('attackSpeed');
    d.attackSpeed = U.clamp(d.attackSpeed, 0.4, 4);

    // damage
    d.meleeDmg = (14 + (a.might - 1) * 2.6 + bp * 3 + get('meleeDmg')) * mul('meleeDmg');
    d.spellPower = (1 + (a.bloodcraft - 1) * 0.05 + bp * 0.08) * mul('spellPower') + get('spellPower') * 0.01;

    // crit
    d.critChance = U.clamp(0.05 + (a.wits - 1) * 0.004 + (m.pct.critChance || 0) + get('critChance') * 0.01, 0, 0.85);
    d.critMult = 1.8 + (m.pct.critMult || 0) + get('critMult') * 0.01;

    // cooldown (lower = faster). represented as multiplier on ability cooldowns
    const cdr = U.clamp((a.wits - 1) * 0.006 + (m.pct.cdr || 0), 0, 0.7);
    d.cooldownMult = 1 - cdr;

    // defense
    d.armor = U.clamp((m.pct.armor || 0) + get('armor') * 0.01, 0, 0.85); // damage reduction
    d.dodge = U.clamp((a.finesse - 1) * 0.0035 + (m.pct.dodge || 0) + get('dodge') * 0.01, 0, 0.7);
    d.lifesteal = (m.pct.lifesteal || 0) + get('lifesteal') * 0.01;

    // regen
    d.hpRegen = (0.4 + (a.vitality - 1) * 0.18 + get('hpRegen')) * mul('hpRegen'); // hp/sec
    d.bloodRegen = (0.5 + (a.bloodcraft - 1) * 0.05 + get('bloodRegen')) * mul('bloodRegen'); // vitae/sec (resting only)

    // economy / social
    d.xpMult = (1 + (a.presence - 1) * 0.012 + (m.pct.xpMult || 0)) * (1 + get('xpMult') * 0.01);
    d.feedSpeed = (1 + (a.presence - 1) * 0.02 + get('feedSpeed')) * mul('feedSpeed');
    d.feedYield = Math.max(0.1, (1 + (a.presence - 1) * 0.015 + bp * 0.05 + get('feedYield')) * mul('feedYield')); // floor so feeding can't stall
    d.priceMult = U.clamp(1 - (a.presence - 1) * 0.008 - (m.pct.discount || 0), 0.4, 1);
    d.influence = (a.presence - 1) + Math.floor((m.add.influence || 0));

    // misc thresholds
    d.detectRange = 220 + (a.wits - 1) * 4 + get('detectRange');
    d.frenzyResist = U.clamp(0.3 + (a.vitality - 1) * 0.02 + (m.pct.frenzyResist || 0), 0, 0.95);
    d.sunResist = U.clamp((m.pct.sunResist || 0) + get('sunResist') * 0.01, 0, 0.95);
    d.vehicleHandling = 1 + (m.pct.vehicle || 0);
    d.bloodEff = U.clamp((m.pct.bloodEff || 0), 0, 0.6); // discipline vitae-cost reduction

    // clamp current pools
    if (p.hp === undefined) p.hp = d.maxHP; else p.hp = Math.min(p.hp, d.maxHP);
    if (p.blood === undefined) p.blood = d.maxBlood; else p.blood = Math.min(p.blood, d.maxBlood);

    return d;
  }

  function blankMods() { return { add: {}, pct: {} }; }
  function addMods(dst, src) {
    if (!src) return;
    if (src.add) for (const k in src.add) dst.add[k] = (dst.add[k] || 0) + src.add[k];
    if (src.pct) for (const k in src.pct) dst.pct[k] = (dst.pct[k] || 0) + src.pct[k];
  }
  function treeMods(p) {
    // VAMP.SkillTree aggregates allocated passive node effects
    return (VAMP.SkillTree && VAMP.SkillTree.aggregateMods) ? VAMP.SkillTree.aggregateMods(p) : null;
  }
  function equipMods(p) {
    return (VAMP.Inventory && VAMP.Inventory.aggregateMods) ? VAMP.Inventory.aggregateMods(p) : null;
  }
  function buffMods(p) {
    const out = blankMods();
    if (!p.buffs) return out;
    for (const b of p.buffs) if (b.mods) addMods(out, b.mods);
    return out;
  }
  // Persistent bonuses pulled straight into recompute (NOT buffs) so respawn/load never wipe them.
  function persistentMods(p) {
    const out = blankMods();
    const bane = VAMP.Data && VAMP.Data.CLAN_BANES && VAMP.Data.CLAN_BANES[p.clan];
    if (bane) addMods(out, bane);
    if (VAMP.Haven && VAMP.Haven.mods) addMods(out, VAMP.Haven.mods(p));
    if (VAMP.Mastery && VAMP.Mastery.mods) addMods(out, VAMP.Mastery.mods(p));
    if (VAMP.Codex && VAMP.Codex.mods) addMods(out, VAMP.Codex.mods(p));
    if (VAMP.Reputation && VAMP.Reputation.mods) addMods(out, VAMP.Reputation.mods(p));
    if (VAMP.Trophies && VAMP.Trophies.mods) addMods(out, VAMP.Trophies.mods(p));
    addMods(out, elderMods(p));
    if (p.blessingMods) addMods(out, p.blessingMods);     // hand-placed Places of Power
    if (p.bloodlineMods) addMods(out, p.bloodlineMods);   // generational Legacy bonus
    return out;
  }
  // ---- Elder Vitae (Paragon): overflow XP past L60 buys tiny permanent global bonuses ----
  const ELDER_KEYS = {
    feedYield: { pct: 'feedYield', step: 0.03, name: 'Sanguine Mastery (+feed yield)' },
    spellPower: { pct: 'spellPower', step: 0.03, name: 'Elder Sorcery (+spell power)' },
    meleeDmg: { pct: 'meleeDmg', step: 0.03, name: 'Ancient Strength (+melee)' },
    maxBlood: { pct: 'maxBlood', step: 0.03, name: 'Deep Vitae (+max vitae)' },
    critChance: { add: 'critChance', step: 1.5, name: 'Killer Instinct (+crit)' },
    sunResist: { pct: 'sunResist', step: 0.04, name: 'Sun-Hardened (+sun resist)' },
    cdr: { pct: 'cdr', step: 0.02, name: 'Timeless (+cooldown reduction)' },
  };
  function elderMods(p) {
    const out = blankMods();
    const spent = p.bloodState && p.bloodState.elderSpent;
    if (!spent) return out;
    for (const k in spent) {
      const def = ELDER_KEYS[k]; if (!def) continue;
      if (def.pct) out.pct[def.pct] = (out.pct[def.pct] || 0) + spent[k] * def.step;
      if (def.add) out.add[def.add] = (out.add[def.add] || 0) + spent[k] * def.step;
    }
    return out;
  }
  function spendElder(p, key) {
    const def = ELDER_KEYS[key]; if (!def) return false;
    const bs = p.bloodState;
    if ((bs.elderVitae || 0) < 1) return false;
    bs.elderVitae -= 1;
    bs.elderSpent = bs.elderSpent || {};
    bs.elderSpent[key] = (bs.elderSpent[key] || 0) + 1;
    recompute(p);
    if (VAMP.Audio) VAMP.Audio.play('skill');
    return true;
  }

  // ---- XP / level up ----
  // returns array of level-up reward objects (one per level gained)
  function gainXP(p, amount) {
    amount = Math.max(0, Math.round(amount * (p.derived ? p.derived.xpMult : 1)));
    p.xp += amount;
    p.xpTotal = (p.xpTotal || 0) + amount;
    const ups = [];
    while (p.level < MAX_LEVEL && p.xp >= xpToNext(p.level)) {
      p.xp -= xpToNext(p.level);
      p.level++;
      const reward = levelReward(p);
      ups.push(reward);
    }
    if (p.level >= MAX_LEVEL && p.xp > 0) {
      // overflow becomes Elder Vitae — never wasted; the climb toward Caine continues forever
      const per = ELDER_XP;
      const bs = p.bloodState;
      bs.elderProgress = (bs.elderProgress || 0) + p.xp; p.xp = 0;
      let got = 0;
      while (bs.elderProgress >= per) { bs.elderProgress -= per; bs.elderVitae = (bs.elderVitae || 0) + 1; got++; }
      if (got) { if (VAMP.UI) VAMP.UI.banner('ELDER VITAE +' + got, 'Spend it in Character → Elder (centuries of the Blood)', '#ff7a30'); if (VAMP.Audio) VAMP.Audio.play('levelup'); if (VAMP.Progress) VAMP.Progress.reveal(VAMP.Game, 'elder'); }
    }
    if (ups.length) { recompute(p); p.hp = p.derived.maxHP; p.blood = p.derived.maxBlood; } // full heal AFTER recompute
    return { gained: amount, ups };
  }

  function levelReward(p) {
    const ap = 2;            // attribute points per level
    let sp = 1;              // skill points per level
    if (p.level % 5 === 0) sp += 1; // bonus every 5
    p.attrPoints = (p.attrPoints || 0) + ap;
    p.skillPoints = (p.skillPoints || 0) + sp;
    // (full heal/refill happens in gainXP after recompute, so it uses fresh maxima)
    return { level: p.level, attrPoints: ap, skillPoints: sp, bp: bloodPotency(p.level) };
  }

  function spendAttribute(p, id) {
    if ((p.attrPoints || 0) <= 0) return false;
    if (!(id in p.attributes)) return false;
    if (p.attributes[id] >= 50) return false;
    p.attributes[id]++;
    p.attrPoints--;
    recompute(p);
    return true;
  }

  VAMP.Stats = {
    MAX_LEVEL, ELDER_XP, ATTRS, xpToNext, totalXpForLevel, bloodPotency, generation,
    newAttributes, recompute, gainXP, spendAttribute, levelReward,
    blankMods, addMods, persistentMods, elderMods, spendElder, ELDER_KEYS,
  };
})();
