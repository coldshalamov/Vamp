/* =========================================================================
 * VAMPIRE CITY — systems/businesses.js  (#16 Night Businesses)
 * Ownable fronts that pay cash/vitae every night (collected at dawn-bank),
 * scaling with tier and any district you control. A compounding money sink.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const MAXTIER = 4;

  function list() { return VAMP.Data.BUSINESSES; }
  function ensure(p) { if (!p.businesses) p.businesses = {}; return p.businesses; }
  function def(id) { return list().find((b) => b.id === id); }
  function owned(p, id) { return p.businesses && p.businesses[id] && p.businesses[id].owned; }
  function tier(p, id) { return (p.businesses && p.businesses[id] && p.businesses[id].tier) || 0; }
  function upgradeCost(p, id) { const d = def(id); return Math.round(d.cost * 0.6 * (tier(p, id) + 1)); }

  function buy(game, id) {
    const p = game.player; const d = def(id); if (!d) return false;
    ensure(p);
    if (owned(p, id)) return upgrade(game, id);
    if (p.money < d.cost) { if (VAMP.UI) VAMP.UI.notify('Not enough money', '#a66'); return false; }
    p.money -= d.cost; p.businesses[id] = { owned: true, tier: 0 };
    if (VAMP.UI) VAMP.UI.notify('Acquired ' + d.name, '#9affd0'); if (VAMP.Audio) VAMP.Audio.play('cash');
    if (VAMP.Legend) VAMP.Legend.add(game, 4);
    return true;
  }
  function upgrade(game, id) {
    const p = game.player; const d = def(id); if (!d || !owned(p, id)) return false;
    if (tier(p, id) >= MAXTIER) { if (VAMP.UI) VAMP.UI.notify(d.name + ' is fully upgraded', '#a88'); return false; }
    const c = upgradeCost(p, id);
    if (p.money < c) { if (VAMP.UI) VAMP.UI.notify('Not enough money', '#a66'); return false; }
    p.money -= c; p.businesses[id].tier++;
    if (VAMP.UI) VAMP.UI.notify(d.name + ' upgraded to tier ' + p.businesses[id].tier, '#9affd0'); if (VAMP.Audio) VAMP.Audio.play('cash');
    return true;
  }

  function collect(game) {
    const p = game.player; let cash = 0, vitae = 0;
    if (!p.businesses) return { cash, vitae };
    const ownedDistricts = VAMP.Domains ? VAMP.Domains.ownedCount(game) : 0;
    const dmMult = 1 + ownedDistricts * 0.12;
    for (const id in p.businesses) {
      if (!p.businesses[id].owned) continue;
      const d = def(id); if (!d) continue;
      const t = p.businesses[id].tier;
      cash += Math.round(d.cash * (1 + t) * dmMult);
      vitae += Math.round(d.vitae * (1 + t) * dmMult);
    }
    return { cash, vitae };
  }

  VAMP.Business = { list, ensure, def, owned, tier, upgradeCost, buy, upgrade, collect, MAXTIER };
})();
