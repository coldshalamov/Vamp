/* =========================================================================
 * VAMPIRE CITY — systems/legacy.js  (#20 Generational Legacy / Prestige)
 * At a high Legend title your elder enters torpor and passes the mantle to a
 * new generation that starts fresh but retains a growing Bloodline bonus and
 * a ledger of ancestors. Stored in a SEPARATE localStorage key that survives
 * run-save clears — progression across lives, not just within one.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const KEY = 'vampcity_bloodline_v1';

  function load() { try { const r = localStorage.getItem(KEY); return r ? JSON.parse(r) : null; } catch (e) { return null; } }
  function store(blob) { try { localStorage.setItem(KEY, JSON.stringify(blob)); } catch (e) {} }

  // apply the carried bloodline bonus onto a fresh player (called from newGame)
  function applyNewGame(game) {
    const blob = load();
    const p = game.player;
    if (!blob || !blob.generation) { p.generation = 1; p.bloodlineMods = null; return; }
    p.generation = blob.generation;
    const b = blob.bonus || 0;
    p.bloodlineMods = { add: {}, pct: { meleeDmg: b, spellPower: b, maxHP: b, maxBlood: b, feedYield: b } };
    VAMP.Stats.recompute(p);
    if (b > 0) VAMP.UI.notify('Bloodline of the ' + ordinal(blob.generation) + ' generation: +' + Math.round(b * 100) + '% to your might.', '#c79bff');
  }

  function canTorpor(p) { return (p.legend || 0) >= 650; } // Prince of the City
  function enterTorpor(game) {
    const p = game.player;
    if (!canTorpor(p)) { VAMP.UI.notify('Only a Prince may pass into torpor and sire a dynasty.', '#a66'); return false; }
    const prev = load() || { generation: 1, bonus: 0, ledger: [] };
    const blob = {
      generation: (prev.generation || 1) + 1,
      bonus: Math.min(0.6, (prev.bonus || 0) + 0.05),
      ledger: (prev.ledger || []).concat([{ title: VAMP.Legend ? VAMP.Legend.title(p).name : 'Elder', clan: p.clan, legend: Math.round(p.legend), domains: VAMP.Domains ? VAMP.Domains.ownedCount(game) : 0, night: game.day }]).slice(-12),
    };
    store(blob);
    VAMP.Save.clear(); // the old life's run-save is retired
    VAMP.UI.banner('TORPOR', 'Your elder sleeps. A new childe of the ' + ordinal(blob.generation) + ' generation rises — stronger by blood.', '#c79bff');
    return true;
  }
  function ledger() { const b = load(); return b ? (b.ledger || []) : []; }
  function ordinal(n) { const s = ['th', 'st', 'nd', 'rd'], v = n % 100; return n + (s[(v - 20) % 10] || s[v] || s[0]); }

  VAMP.Legacy = { load, applyNewGame, canTorpor, enterTorpor, ledger };
})();
