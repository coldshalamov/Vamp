/* =========================================================================
 * VAMPIRE CITY — systems/inventory.js
 * Loot generation (rarity + affixes), equipment, stat aggregation, pickups.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  let IID = 1;

  function rollRarity(level, luck) {
    luck = (luck || 0) + (level || 0) * 0.002; // drops trend rarer as you level
    const r = Math.random() + luck;
    if (r > 0.985) return 'legendary';
    if (r > 0.93) return 'epic';
    if (r > 0.80) return 'rare';
    if (r > 0.52) return 'uncommon';
    return 'common';
  }

  function generate(level, rarityKey, slotPref) {
    const D = VAMP.Data;
    level = Math.max(1, level | 0);
    const rarity = rarityKey || rollRarity(level);
    const rinfo = D.RARITY[rarity];
    // choose slot
    const slots = ['weapon', 'attire', 'charm'];
    const slot = slotPref || slots[(Math.random() * slots.length) | 0];

    let base, weaponStats = null, name, glyph = '?';
    const mods = { add: {}, pct: {} };
    const affixLabels = [];

    if (slot === 'weapon') {
      const w = D.WEAPONS[(Math.random() * D.WEAPONS.length) | 0];
      base = w; glyph = 'r';
      weaponStats = {
        kind: w.kind, name: w.name, dmg: Math.round(w.dmg * (1 + level * 0.06) * rinfo.mult),
        fireRate: w.fireRate, spread: w.spread, speed: w.speed, pellets: w.pellets || 1, pierce: w.pierce || 0,
        dmgMult: 1, rangeBonus: 0,
      };
      name = w.name;
    } else if (slot === 'attire') {
      const a = D.ATTIRE[(Math.random() * D.ATTIRE.length) | 0];
      base = a; glyph = 'A'; name = a.name;
      mergeMods(mods, scaleMods(a.base, level, rinfo.mult));
    } else {
      const c = D.CHARMS[(Math.random() * D.CHARMS.length) | 0];
      base = c; glyph = '◆'; name = c.name;
      mergeMods(mods, scaleMods(c.base, level, rinfo.mult));
    }

    // affixes
    const nAff = rinfo.affixes;
    const pool = D.AFFIXES.slice();
    U.makeRNG; // no-op
    for (let i = 0; i < nAff && pool.length; i++) {
      const ai = (Math.random() * pool.length) | 0;
      const af = pool.splice(ai, 1)[0];
      const m = af.mod(level);
      mergeMods(mods, m);
      affixLabels.push(af.label(level));
    }

    const prefix = rarity === 'common' ? '' : rinfo.name + ' ';
    return {
      id: IID++, slot, rarity, level, name: prefix + name, baseName: name,
      glyph, color: rinfo.color, mods, affixes: affixLabels, weaponStats,
    };
  }

  // build-defining legendary unique
  function generateRelic(level, relicId) {
    const D = VAMP.Data;
    level = Math.max(1, level | 0);
    const pool = D.RELICS;
    const def = relicId ? pool.find((r) => r.id === relicId) : pool[(Math.random() * pool.length) | 0];
    if (!def) return generate(level, 'legendary');
    const mods = { add: {}, pct: {} };
    // pct mods are fixed (the relic's identity); add mods scale gently with level
    if (def.mods.pct) for (const k in def.mods.pct) mods.pct[k] = def.mods.pct[k];
    if (def.mods.add) for (const k in def.mods.add) mods.add[k] = def.mods.add[k] * (1 + level * 0.04);
    let weaponStats = null;
    if (def.slot === 'weapon') {
      const w = D.WEAPONS.find((x) => x.kind === def.weaponBase) || D.WEAPONS[0];
      weaponStats = { kind: w.kind, name: def.name, dmg: Math.round(w.dmg * (1 + level * 0.08) * 2.8), fireRate: w.fireRate, spread: w.spread, speed: w.speed, pellets: w.pellets || 1, pierce: (w.pierce || 0) + 1, dmgMult: 1, rangeBonus: 0 };
    }
    return {
      id: IID++, slot: def.slot, rarity: 'relic', level, name: def.name, baseName: def.name,
      glyph: def.glyph, color: '#ff7a30', mods, affixes: [def.lore], weaponStats, relic: true,
    };
  }

  function scaleMods(m, level, mult) {
    const out = { add: {}, pct: {} };
    if (m.add) for (const k in m.add) out.add[k] = m.add[k] * (1 + level * 0.05) * mult;
    if (m.pct) for (const k in m.pct) out.pct[k] = m.pct[k] * mult;
    return out;
  }
  function mergeMods(dst, src) {
    if (!src) return;
    if (src.add) for (const k in src.add) dst.add[k] = (dst.add[k] || 0) + src.add[k];
    if (src.pct) for (const k in src.pct) dst.pct[k] = (dst.pct[k] || 0) + src.pct[k];
  }

  // sum mods of equipped items (for stats.recompute)
  function aggregateMods(p) {
    const out = { add: {}, pct: {} };
    const e = p.equipment;
    for (const slot in e) {
      const it = e[slot];
      if (it && it.mods) mergeMods(out, it.mods);
    }
    return out;
  }

  function equip(p, item) {
    if (!item) return null;
    let slotKey = item.slot;
    if (item.slot === 'charm') slotKey = p.equipment.charm1 ? (p.equipment.charm2 ? 'charm1' : 'charm2') : 'charm1';
    const prev = p.equipment[slotKey] || null;
    p.equipment[slotKey] = item;
    if (item.slot === 'weapon') {
      // map weaponStats into the weapon the player.attack reads
      p.equipment.weapon = Object.assign({}, item.weaponStats, { item, mods: item.mods, name: item.name, rarity: item.rarity });
    }
    // remove from bag
    const i = p.inventory.indexOf(item);
    if (i >= 0) p.inventory.splice(i, 1);
    if (prev && prev.kind !== 'claws') p.inventory.push(prev.item ? prev.item : prev);
    VAMP.Stats.recompute(p);
    if (VAMP.Audio) VAMP.Audio.play('pickup');
    return prev;
  }

  function unequipWeapon(p) {
    // revert to claws
    const prev = p.equipment.weapon;
    if (prev && prev.item) p.inventory.push(prev.item);
    p.equipment.weapon = { kind: 'claws', name: 'Vampiric Claws', dmgMult: 1, rangeBonus: 0, rarity: 'innate' };
    VAMP.Stats.recompute(p);
  }

  function addItem(p, item) {
    p.inventory.push(item);
    if (p.inventory.length > 40) {
      // bag full: auto-sell the least valuable item (by value, which factors level), credit money + notify
      p.inventory.sort((a, b) => sellValue(a) - sellValue(b));
      const junk = p.inventory.shift();
      const v = sellValue(junk);
      p.money += v;
      if (VAMP.UI) VAMP.UI.notify('Bag full — auto-sold ' + junk.name + ' (+$' + v + ')', '#a98');
    }
  }

  function sellValue(item) {
    const r = VAMP.Data.RARITY[item.rarity] || { mult: 1 };
    return Math.round(20 * r.mult * (1 + item.level * 0.4));
  }

  // #9 — compute the net stat delta if `item` were equipped, vs current gear.
  // Returns a short list of {label, signed, better} lines, or [] if nothing to say.
  function compareItem(p, item) {
    if (!item) return [];
    // figure out which slot key it would occupy
    let slotKey = item.slot;
    if (item.slot === 'charm') slotKey = (p.equipment.charm1 ? (p.equipment.charm2 ? 'charm1' : 'charm2') : 'charm1');
    const cur = p.equipment[slotKey];
    const aCur = cur ? aggregateMods({ equipment: { s: cur } }) : { add: {}, pct: {} };
    const aNew = aggregateMods({ equipment: { s: item } });
    const names = { maxHP: 'Max HP', maxBlood: 'Max Vitae', moveSpeed: 'Move Speed', meleeDmg: 'Melee Dmg', spellPower: 'Spell Power', critChance: 'Crit', critMult: 'Crit Mult', armor: 'Armor', dodge: 'Dodge', lifesteal: 'Lifesteal', hpRegen: 'HP Regen', bloodRegen: 'Vitae Regen', attackSpeed: 'Atk Speed', cooldownMult: 'Cooldown', feedYield: 'Feed Yield', xpMult: 'XP', sunResist: 'Sun Resist', bloodPotency: 'Blood Pot.', frenzyResist: 'Frenzy Resist', priceMult: 'Prices' };
    const lines = [];
    const all = (k) => (aNew.add[k] || 0) - (aCur.add[k] || 0);
    const allp = (k) => (aNew.pct[k] || 0) - (aCur.pct[k] || 0);
    const fmtAdd = (k) => { const d = all(k); if (Math.abs(d) < 0.5) return null; return { label: names[k] || k, val: (d > 0 ? '+' : '') + Math.round(d), better: d > 0 }; };
    const fmtPct = (k) => { const d = allp(k); if (Math.abs(d) < 0.005) return null; return { label: names[k] || k, val: (d > 0 ? '+' : '') + Math.round(d * 100) + '%', better: (k === 'cooldownMult' || k === 'priceMult') ? d < 0 : d > 0 }; };
    const order = ['maxHP', 'maxBlood', 'meleeDmg', 'spellPower', 'attackSpeed', 'critChance', 'critMult', 'armor', 'dodge', 'lifesteal', 'moveSpeed', 'hpRegen', 'bloodRegen', 'feedYield', 'cooldownMult', 'xpMult', 'sunResist'];
    for (const k of order) { const a = fmtAdd(k); if (a) lines.push(a); const b = fmtPct(k); if (b) lines.push(b); }
    // weapon damage comparison
    if (item.weaponStats) {
      const curW = (cur && cur.weaponStats) || (slotKey === 'weapon' && p.equipment.weapon && p.equipment.weapon.item ? p.equipment.weapon.item.weaponStats : null);
      const dDmg = item.weaponStats.dmg - (curW ? curW.dmg : 0);
      if (curW) lines.unshift({ label: 'Weapon Dmg', val: (dDmg > 0 ? '+' : '') + Math.round(dDmg), better: dDmg > 0 });
      else lines.unshift({ label: 'Weapon Dmg', val: '+' + item.weaponStats.dmg, better: true });
    }
    return lines;
  }

  VAMP.Inventory = { generate, generateRelic, aggregateMods, equip, unequipWeapon, addItem, sellValue, rollRarity, mergeMods, compareItem };
})();
