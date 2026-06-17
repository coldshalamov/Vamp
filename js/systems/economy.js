/* =========================================================================
 * VAMPIRE CITY — systems/economy.js
 * Money math, shop stock generation, transactions, and haven services.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  function price(item) {
    const r = VAMP.Data.RARITY[item.rarity] || { mult: 1 };
    return Math.round((60 * r.mult) * (1 + item.level * 0.6));
  }

  function buy(game, item) {
    const p = game.player;
    const cost = Math.round(price(item) * p.derived.priceMult);
    if (p.money < cost) { if (VAMP.UI) VAMP.UI.notify('Not enough money', '#a66'); if (VAMP.Audio) VAMP.Audio.play('ui'); return false; }
    p.money -= cost;
    VAMP.Inventory.addItem(p, item);
    if (VAMP.Audio) VAMP.Audio.play('cash');
    if (VAMP.UI) VAMP.UI.notify('Bought ' + item.name, item.color);
    return true;
  }

  function sell(game, item) {
    const p = game.player;
    const v = VAMP.Inventory.sellValue(item);
    const i = p.inventory.indexOf(item);
    if (i < 0) return false;
    p.inventory.splice(i, 1);
    p.money += v;
    if (VAMP.Audio) VAMP.Audio.play('cash');
    if (VAMP.UI) VAMP.UI.notify('Sold ' + item.name + ' (+$' + v + ')', '#7c7');
    return true;
  }

  function generateStock(level, count, slotPref) {
    const out = [];
    for (let i = 0; i < count; i++) {
      const r = VAMP.Inventory.rollRarity(level, 0.1);
      out.push(VAMP.Inventory.generate(level + ((Math.random() * 4) | 0) - 1, r, slotPref));
    }
    return out;
  }

  // ---- haven / shop services ----
  const SERVICES = {
    refillBlood: { name: 'Vitae Pack (refill blood)', cost: 80, run: (g) => { g.player.blood = g.player.derived.maxBlood; g.player.bloodState.hunger = 0; } },
    heal: { name: 'Mend Wounds (full heal)', cost: 60, run: (g) => { g.player.hp = g.player.derived.maxHP; } },
    respecTree: { name: 'Reflect on the Path (respec skill tree)', cost: 250, run: (g) => { const n = VAMP.SkillTree.respec(g.player); let refunded = n; if (g.player.clan && g.applyClan) { g.applyClan(g.player.clan, false); g.player.skillPoints = Math.max(0, (g.player.skillPoints || 0) - 1); refunded = Math.max(0, n - 1); } if (VAMP.UI) VAMP.UI.notify('Refunded ' + refunded + ' skill points — re-bind powers in [C]', '#9bf'); } },
    clearHeat: { name: 'Lay Low (clear all Heat)', cost: 200, run: (g) => { g.masquerade.clearAll(); } },
    bribe: { name: 'Bribe Officials (-2 Heat)', cost: 120, run: (g) => { g.masquerade.clearStars(2); } },
  };
  function useService(game, key) {
    const s = SERVICES[key];
    if (!s) return false;
    const cost = Math.round(s.cost * (key.startsWith('respec') ? 1 : game.player.derived.priceMult));
    if (game.player.money < cost) { if (VAMP.UI) VAMP.UI.notify('Not enough money', '#a66'); return false; }
    game.player.money -= cost;
    s.run(game);
    if (VAMP.Audio) VAMP.Audio.play('cash');
    if (VAMP.UI) VAMP.UI.notify(s.name, '#7c7');
    return true;
  }

  VAMP.Economy = { price, buy, sell, generateStock, SERVICES, useService };
})();
