/* =========================================================================
 * VAMPIRE CITY — systems/reputation.js  (#3 Faction Reputation & Influence)
 * Durable standing per faction (separate from short-term Heat). High standing
 * = cheaper services & friendlier streets; low = ambushes. Perks fold into
 * derived stats via Stats.persistentMods. The world remembers you.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  const FACTIONS = {
    camarilla: { name: 'Camarilla', color: '#6c7bd6' },
    anarch: { name: 'Anarchs', color: '#e0457b' },
    inquis: { name: 'Second Inquisition', color: '#ff5a5a' },
    gang: { name: 'Street Gangs', color: '#d6953f' },
    police: { name: 'Police', color: '#5a8cff' },
  };

  function ensure(p) {
    if (!p.reputation) p.reputation = { camarilla: 0, anarch: 0, inquis: 0, gang: 0, police: 0 };
    return p.reputation;
  }
  function change(p, faction, amount) {
    ensure(p);
    if (!(faction in p.reputation)) return;
    const before = p.reputation[faction];
    p.reputation[faction] = U.clamp(before + amount, -100, 100);
    const crossed = Math.floor(p.reputation[faction] / 25) !== Math.floor(before / 25);
    if (crossed) { VAMP.Stats.recompute(p); if (VAMP.UI) VAMP.UI.notify((FACTIONS[faction] ? FACTIONS[faction].name : faction) + ' standing: ' + Math.round(p.reputation[faction]), FACTIONS[faction] ? FACTIONS[faction].color : '#cdd'); }
  }

  // killing a faction lowers your standing with it (and raises rivals a touch)
  function onKill(p, npc, cause) {
    ensure(p);
    const f = npc.faction;
    if (f === 'police') { change(p, 'police', -2); change(p, 'anarch', 0.5); }
    else if (f === 'gang') { change(p, 'gang', -1.5); }
    else if (f === 'inquis') { change(p, 'inquis', -3); change(p, 'camarilla', 1); change(p, 'anarch', 1); }
    else if (npc.innocent) { change(p, 'camarilla', -0.4); } // Masquerade frowns on sloppy kills
  }
  function onMission(p, faction, amount) { change(p, faction || 'anarch', amount || 6); }

  // perk: total positive standing gives a small price discount + a little xp
  function mods(p) {
    const out = { add: {}, pct: {} };
    if (!p.reputation) return out;
    let pos = 0; for (const k in p.reputation) pos += Math.max(0, p.reputation[k]);
    out.pct.discount = Math.min(0.18, pos / 1000);
    out.pct.xpMult = Math.min(0.1, pos / 2000);
    return out;
  }
  // high gang standing => gangs leave you alone (read by npc AI)
  function gangFriendly(p) { return p.reputation && p.reputation.gang >= 40; }
  function standing(p, f) { return (p.reputation && p.reputation[f]) || 0; }

  VAMP.Reputation = { FACTIONS, ensure, change, onKill, onMission, mods, gangFriendly, standing };
})();
