/* =========================================================================
 * VAMPIRE CITY — systems/codex.js  (#5 Codex & Collection Sets)
 * Auto-fills as you encounter the world. Completing a category grants a
 * PERMANENT passive (via Stats.persistentMods). A calm, save-spanning goal.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  // category -> {label, of:N (computed), set:modbag, done:fn}
  function CATS() {
    const D = VAMP.Data;
    return {
      fedTypes:   { label: 'Vitae of the City (feed on every mortal kind)', total: Object.keys(VAMP.Blood.VICTIM_TYPES).length, set: { pct: { feedYield: 0.10, maxBlood: 0.05 } } },
      killedKinds:{ label: 'Bestiary (slay every faction)', total: 5, set: { pct: { meleeDmg: 0.08 } } },
      relicsSeen: { label: 'Reliquary (discover every Relic)', total: D.RELICS.length, set: { pct: { spellPower: 0.08, meleeDmg: 0.08 } } },
      districts:  { label: 'Cartographer (set foot in every district)', total: D.DISCIPLINES ? 7 : 7, set: { pct: { moveSpeed: 0.06 }, add: { critChance: 3 } } },
      powers:     { label: 'Arts of the Damned (learn 20 powers)', total: 20, set: { pct: { cdr: 0.06 } } },
    };
  }

  function obj(v) { return v && typeof v === 'object' && !Array.isArray(v); }

  function ensure(p) {
    if (!obj(p.codex)) p.codex = {};
    for (const k of ['fedTypes', 'killedKinds', 'relicsSeen', 'districts', 'complete']) if (!obj(p.codex[k])) p.codex[k] = {};
    return p.codex;
  }
  function countOf(p, cat) { return p.codex && p.codex[cat] ? Object.keys(p.codex[cat]).length : 0; }

  function mark(p, cat, key) {
    ensure(p);
    if (cat === 'powers') return checkComplete(p); // derived from p.powers
    if (!p.codex[cat]) p.codex[cat] = {};
    if (p.codex[cat][key]) return;
    p.codex[cat][key] = 1;
    if (VAMP.UI) VAMP.UI.notify('Codex: ' + cat + ' ' + countOf(p, cat), '#cdd');
    checkComplete(p);
  }

  function checkComplete(p) {
    ensure(p);
    const cats = CATS();
    let changed = false;
    for (const id in cats) {
      if (p.codex.complete[id]) continue;
      const have = id === 'powers' ? Object.keys(p.powers || {}).length : countOf(p, id);
      if (have >= cats[id].total) {
        p.codex.complete[id] = 1; changed = true;
        if (VAMP.UI) VAMP.UI.banner('CODEX COMPLETE', cats[id].label + ' — permanent bonus unlocked!', '#ffd24a');
        if (VAMP.Audio) VAMP.Audio.play('win');
      }
    }
    if (changed) VAMP.Stats.recompute(p);
  }

  function mods(p) {
    const out = { add: {}, pct: {} };
    if (!p.codex || !p.codex.complete) return out;
    const cats = CATS();
    for (const id in p.codex.complete) {
      const set = cats[id] && cats[id].set; if (!set) continue;
      if (set.add) for (const a in set.add) out.add[a] = (out.add[a] || 0) + set.add[a];
      if (set.pct) for (const c in set.pct) out.pct[c] = (out.pct[c] || 0) + set.pct[c];
    }
    return out;
  }

  VAMP.Codex = { CATS, ensure, mark, checkComplete, mods, countOf };
})();
