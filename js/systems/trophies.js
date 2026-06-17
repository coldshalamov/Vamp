/* =========================================================================
 * VAMPIRE CITY — systems/trophies.js  (#18 Trophy Hall)
 * Notable kills yield a unique trophy granting a small PERMANENT passive
 * (folds into Stats.persistentMods). Each trophy type is earned once — a
 * quiet checklist of legendary foes to hunt across the whole game.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  const DEFS = {
    hunter: { name: "Hunter's Fang", mod: { pct: { sunResist: 0.08 } }, desc: '+8% sun resistance' },
    inquis: { name: "Inquisitor's Badge", mod: { pct: { armor: 0.05 } }, desc: '+5% armor' },
    elder: { name: "Elder's Skull", mod: { pct: { maxHP: 0.08 } }, desc: '+8% max HP' },
    baron: { name: "Baron's Sigil", mod: { pct: { discount: 0.06, maxBlood: 0.05 } }, desc: '-6% prices, +5% vitae' },
    nemesis: { name: "Nemesis' Heart", mod: { pct: { meleeDmg: 0.08, spellPower: 0.08 } }, desc: '+8% all damage' },
  };

  function sourceKey(npc) {
    if (npc.baronOf) return 'baron';
    if (npc.nemesis) return 'nemesis';
    if (npc.type === 'elder') return 'elder';
    if (npc.faction === 'inquis') return (npc.elite || npc.type === 'swat') ? 'inquis' : 'hunter';
    return null;
  }
  function has(p, key) { return p.trophies && p.trophies.some((t) => t.id === key); }

  function award(game, npc) {
    const key = sourceKey(npc); if (!key) return;
    const p = game.player;
    if (!p.trophies) p.trophies = [];
    if (has(p, key)) return;
    const d = DEFS[key];
    p.trophies.push({ id: key, name: d.name, desc: d.desc });
    VAMP.Stats.recompute(p);
    VAMP.UI.banner('TROPHY: ' + d.name, 'Mounted in your haven — ' + d.desc + ' (permanent).', '#ffd24a');
    if (VAMP.Audio) VAMP.Audio.play('win');
    if (VAMP.Legend) VAMP.Legend.add(game, 4);
  }

  function mods(p) {
    const out = { add: {}, pct: {} };
    if (!p.trophies) return out;
    for (const t of p.trophies) {
      const d = DEFS[t.id]; if (!d) continue;
      if (d.mod.add) for (const a in d.mod.add) out.add[a] = (out.add[a] || 0) + d.mod.add[a];
      if (d.mod.pct) for (const c in d.mod.pct) out.pct[c] = (out.pct[c] || 0) + d.mod.pct[c];
    }
    return out;
  }

  VAMP.Trophies = { DEFS, award, mods, has };
})();
