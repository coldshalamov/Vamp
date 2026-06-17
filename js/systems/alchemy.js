/* =========================================================================
 * VAMPIRE CITY — systems/alchemy.js  (Workshop Alchemy)
 * Unlocked by building the Workshop room in the Haven. Lets the player
 * salvage item surplus into higher-quality gear, or extract vitae from
 * unwanted loot. Three salvage recipes (Refine/Distill/Sublime) that
 * unlock per Workshop level, plus a vitae-extraction one-shot.
 * All state lives on player.inventory — no new save keys needed.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  const RECIPES = [
    { id: 'refine',  name: '3 Common → 1 Uncommon',  inRarity: 'common',   outRarity: 'uncommon', need: 3, minWS: 1 },
    { id: 'distill', name: '3 Uncommon → 1 Rare',    inRarity: 'uncommon', outRarity: 'rare',     need: 3, minWS: 2 },
    { id: 'sublime', name: '3 Rare → 1 Epic',         inRarity: 'rare',     outRarity: 'epic',     need: 3, minWS: 3 },
    { id: 'extract', name: 'Extract Essence (→ vitae)', inRarity: null,       outRarity: null,       need: 1, minWS: 1 },
  ];

  // vitae yielded by extracting one item of each rarity
  const EXTRACT_VITAE = { common: 4, uncommon: 10, rare: 22, epic: 48, legendary: 100, relic: 200 };

  function available(p, workshopLv) {
    return RECIPES.filter((r) => r.minWS <= workshopLv);
  }

  function inputCount(p, recipe) {
    if (recipe.id === 'extract') return p.inventory.length;
    return p.inventory.filter((it) => it.rarity === recipe.inRarity).length;
  }

  function brew(game, recipeId) {
    const p = game.player;
    const recipe = RECIPES.find((r) => r.id === recipeId);
    if (!recipe) return;

    if (recipe.id === 'extract') {
      if (!p.inventory.length) { VAMP.UI.notify('Nothing to extract', '#a88'); return; }
      // extract the cheapest item in the bag
      const sorted = p.inventory.slice().sort((a, b) => VAMP.Inventory.sellValue(a) - VAMP.Inventory.sellValue(b));
      const item = sorted[0];
      const vitae = EXTRACT_VITAE[item.rarity] || 4;
      p.inventory.splice(p.inventory.indexOf(item), 1);
      if (VAMP.Haven) VAMP.Haven.depositVitae(p, vitae);
      if (VAMP.UI) VAMP.UI.notify('Extracted ' + vitae + ' vitae from ' + item.name + ' → cellar', '#ff5a8c');
      if (VAMP.Audio) VAMP.Audio.play('ui');
      return;
    }

    const pool = p.inventory.filter((it) => it.rarity === recipe.inRarity);
    if (pool.length < recipe.need) {
      VAMP.UI.notify('Need ' + recipe.need + ' ' + recipe.inRarity + ' items (have ' + pool.length + ')', '#a88');
      return;
    }
    for (let i = 0; i < recipe.need; i++) {
      const idx = p.inventory.indexOf(pool[i]);
      if (idx >= 0) p.inventory.splice(idx, 1);
    }
    const out = VAMP.Inventory.generate(p.level, recipe.outRarity);
    VAMP.Inventory.addItem(p, out);
    const col = (VAMP.Data.RARITY[recipe.outRarity] || {}).color || '#ffd24a';
    VAMP.UI.notify('Crafted: ' + out.name, col);
    if (VAMP.Audio) VAMP.Audio.play('cash');
  }

  VAMP.Alchemy = { available, inputCount, brew, RECIPES };
})();
