/* =========================================================================
 * VAMPIRE CITY — systems/haven.js  (#1 Haven Ownership & Upgrade Rooms)
 * The retention anchor: an ownable base you upgrade room-by-room. Bonuses
 * fold into derived stats via Stats.persistentMods; the cellar stores vitae
 * from tithe/overflow; barracks raises your coterie cap; it's where you rest
 * and respawn. Stored on player.haven so it persists for free.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  function rooms() { return VAMP.Data.HAVEN_ROOMS; }

  function ensure(p) {
    if (!p.haven) p.haven = { rooms: {}, cellarVitae: 0 };
    if (!p.haven.rooms) p.haven.rooms = {};
    for (const r of rooms()) if (p.haven.rooms[r.id] == null) p.haven.rooms[r.id] = 0;
    return p.haven;
  }
  function level(p, id) { return (p.haven && p.haven.rooms && p.haven.rooms[id]) || 0; }
  function def(id) { return rooms().find((r) => r.id === id); }
  function cost(p, id) { const d = def(id); return d ? Math.round(d.cost(level(p, id))) : 0; }

  function mods(p) {
    const out = { add: {}, pct: {} };
    if (!p.haven || !p.haven.rooms) return out;
    for (const r of rooms()) {
      const lv = p.haven.rooms[r.id] || 0; if (!lv) continue;
      const m = r.mod(lv);
      if (m.add) for (const a in m.add) out.add[a] = (out.add[a] || 0) + m.add[a];
      if (m.pct) for (const c in m.pct) out.pct[c] = (out.pct[c] || 0) + m.pct[c];
    }
    return out;
  }

  function canUpgrade(game, id) {
    const p = game.player; const d = def(id); if (!d) return false;
    return level(p, id) < d.max && p.money >= cost(p, id);
  }
  function upgrade(game, id) {
    const p = game.player; const d = def(id); if (!d) return false;
    ensure(p);
    if (level(p, id) >= d.max) { if (VAMP.UI) VAMP.UI.notify(d.name + ' is fully upgraded', '#a88'); return false; }
    const c = cost(p, id);
    if (p.money < c) { if (VAMP.UI) VAMP.UI.notify('Not enough money', '#a66'); return false; }
    p.money -= c; p.haven.rooms[id]++;
    VAMP.Stats.recompute(p);
    if (VAMP.UI) VAMP.UI.notify(d.name + ' upgraded to ' + p.haven.rooms[id], '#9affd0');
    if (VAMP.Audio) VAMP.Audio.play('cash');
    return true;
  }

  function cellarCap(p) { return 200 + level(p, 'cellar') * 400; }
  function depositVitae(p, amount) { ensure(p); p.haven.cellarVitae = Math.min(cellarCap(p), (p.haven.cellarVitae || 0) + amount); }
  function collectVitae(game) {
    const p = game.player; ensure(p);
    const amt = Math.floor(p.haven.cellarVitae || 0);
    if (amt <= 0) return 0;
    const head = Math.max(0, p.derived.maxBlood - p.blood);
    const drawn = Math.min(head, amt);
    p.blood += drawn; p.haven.cellarVitae = amt - drawn;   // keep what doesn't fit — never destroyed
    if (VAMP.UI) VAMP.UI.notify('Drew ' + Math.round(drawn) + ' vitae' + (amt - drawn > 0 ? ' (' + Math.round(amt - drawn) + ' left in cellar)' : ''), '#ff2f6e');
    return drawn;
  }

  function thrallCap(p) { return 3 + level(p, 'barracks') + (p.attributes && p.attributes.presence > 6 ? 1 : 0); }
  function respawnBlood(p) { return 0.4 + level(p, 'coffin') * 0.08; }       // fraction of max
  function deathPenalty(p) { return Math.max(0.05, 0.20 - level(p, 'coffin') * 0.03); }
  function hasWorkshop(p) { return level(p, 'workshop') > 0; }

  VAMP.Haven = { ensure, level, def, cost, mods, canUpgrade, upgrade, cellarCap, depositVitae, collectVitae, thrallCap, respawnBlood, deathPenalty, hasWorkshop, rooms };
})();
