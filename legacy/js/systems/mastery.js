/* =========================================================================
 * VAMPIRE CITY — systems/mastery.js  (#4 Use-Based Mastery Tracks)
 * Every action quietly levels a hidden track; milestone bonuses fold into
 * derived stats via Stats.persistentMods. A second always-on progression
 * spine parallel to the point-buy tree — you're never NOT advancing.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  // per-rank mod for each track (compounds; rank caps at 12)
  const TRACKS = {
    predation:   { name: 'Predation', desc: 'feeding', per: { pct: { feedYield: 0.02, feedSpeed: 0.02 } } },
    sorcery:     { name: 'Hemomancy', desc: 'casting blood/dark powers', per: { pct: { spellPower: 0.025 } } },
    brawn:       { name: 'Brutality', desc: 'melee kills', per: { pct: { meleeDmg: 0.025 } } },
    survival:    { name: 'Fortitude', desc: 'enduring harm', per: { pct: { maxHP: 0.02, armor: 0.01 } } },
    driving:     { name: 'Road Reaver', desc: 'driving & hijacks', per: { pct: { vehicle: 0.03 } } },
    nightstalker:{ name: 'Nightstalker', desc: 'stealth & speed', per: { add: { critChance: 1.0 }, pct: { moveSpeed: 0.01 } } },
  };
  const CAP = 12;
  function rankFor(xp) { return Math.min(CAP, Math.floor(Math.sqrt((xp || 0) / 28))); }

  function ensure(p) {
    if (!p.mastery) p.mastery = {};
    for (const k in TRACKS) if (!p.mastery[k]) p.mastery[k] = { xp: 0, rank: 0 };
    return p.mastery;
  }

  function gain(p, trackId, amount) {
    if (!TRACKS[trackId]) return;
    ensure(p);
    const tr = p.mastery[trackId];
    tr.xp += amount;
    const nr = rankFor(tr.xp);
    if (nr > tr.rank) {
      tr.rank = nr;
      VAMP.Stats.recompute(p);
      if (VAMP.UI) VAMP.UI.notify(TRACKS[trackId].name + ' Mastery ' + nr, '#9affd0');
      if (VAMP.Audio) VAMP.Audio.play('skill');
    }
  }

  function mods(p) {
    const out = { add: {}, pct: {} };
    if (!p.mastery) return out;
    for (const k in TRACKS) {
      const tr = p.mastery[k]; if (!tr || !tr.rank) continue;
      const per = TRACKS[k].per;
      if (per.add) for (const a in per.add) out.add[a] = (out.add[a] || 0) + per.add[a] * tr.rank;
      if (per.pct) for (const c in per.pct) out.pct[c] = (out.pct[c] || 0) + per.pct[c] * tr.rank;
    }
    return out;
  }

  VAMP.Mastery = { TRACKS, CAP, rankFor, ensure, gain, mods };
})();
