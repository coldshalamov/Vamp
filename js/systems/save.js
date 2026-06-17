/* =========================================================================
 * VAMPIRE CITY — systems/save.js
 * Serialize / deserialize the run to localStorage. Captures only plain data
 * (no entity refs or functions). Settings persisted separately.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const KEY = 'vampcity_save_v1';
  const SET = 'vampcity_settings_v1';
  const VERSION = 3;

  function hasSave() { try { return !!localStorage.getItem(KEY); } catch (e) { return false; } }

  function serialize(game) {
    const p = game.player;
    const data = {
      v: VERSION,
      seed: game.world.seed,
      time: game.time,
      clock: game.clock,
      day: game.day,
      missionsDone: game.missionsDone || 0,
      heat: game.masquerade.heat,
      achievements: game.achievements ? game.achievements.unlocked : {},
      player: {
        x: p.x, y: p.y, clan: p.clan,
        level: p.level, xp: p.xp, xpTotal: p.xpTotal,
        attributes: p.attributes, attrPoints: p.attrPoints, skillPoints: p.skillPoints,
        treeNodes: p.treeNodes, powers: p.powers, slots: p.slots,
        money: p.money, respecs: p.respecs || 0, aimMode: p.aimMode || 'move',
        inventory: p.inventory,
        equip: {
          attire: p.equipment.attire || null,
          charm1: p.equipment.charm1 || null,
          charm2: p.equipment.charm2 || null,
          weaponItem: (p.equipment.weapon && p.equipment.weapon.item) ? p.equipment.weapon.item : null,
        },
        bloodState: p.bloodState,
        stats: p.stats,
        hp: p.hp, blood: p.blood,
        // continuing-value persistent blocks
        haven: p.haven, mastery: p.mastery, codex: p.codex,
        reputation: p.reputation, coterie: p.coterie, legend: p.legend,
        factionRank: p.factionRank, relations: p.relations, nemeses: p.nemeses,
        trophies: p.trophies, blessings: p.blessings, businesses: p.businesses,
        reagents: p.reagents, blessingMods: p.blessingMods, childeCount: p.childeCount || 0,
        // progression-reveal ledger + signature-verb unlocks
        progress: VAMP.Progress ? VAMP.Progress.serialize(p) : null,
        finisherUnlocked: p.finisherUnlocked || false,
        pounceUnlocked: p.pounceUnlocked || false,
      },
      domains: game.domains, districtState: game.districtState,
    };
    return data;
  }

  function save(game) {
    try {
      localStorage.setItem(KEY, JSON.stringify(serialize(game)));
      return true;
    } catch (e) { console.warn('save failed', e); return false; }
  }

  function load() {
    try {
      const raw = localStorage.getItem(KEY);
      if (!raw) return null;
      return JSON.parse(raw);
    } catch (e) { return null; }
  }

  function clear() { try { localStorage.removeItem(KEY); } catch (e) {} }

  // apply a loaded data blob onto a freshly-created player
  function applyToPlayer(p, sp) {
    p.level = sp.level || 1; p.xp = sp.xp || 0; p.xpTotal = sp.xpTotal || 0;
    // sanitize attributes: missing/garbage field must not NaN-brick the run
    p.attributes = Object.assign(VAMP.Stats.newAttributes(), sp.attributes || {});
    for (const k in p.attributes) { const v = +p.attributes[k]; p.attributes[k] = isFinite(v) && v >= 1 ? v : 1; }
    p.attrPoints = sp.attrPoints || 0; p.skillPoints = sp.skillPoints || 0;
    p.treeNodes = sp.treeNodes || {}; p.powers = sp.powers || {}; p.slots = sp.slots || [null, null, null, null, null, null, null, null];
    p.money = sp.money || 0; p.respecs = sp.respecs || 0; p.aimMode = sp.aimMode || 'move';
    p.inventory = sp.inventory || [];
    p.bloodState = Object.assign(VAMP.Blood.newBloodState(), sp.bloodState || {});
    p.stats = sp.stats || p.stats;
    p.toggles = {}; p.cloaked = false; p.buffs = [];
    p.x = sp.x; p.y = sp.y; p.clan = sp.clan || 'brujah';
    // continuing-value persistent blocks (all default-safe for old saves)
    p.haven = sp.haven || null; p.mastery = sp.mastery || null; p.codex = sp.codex || null;
    p.reputation = sp.reputation || null; p.coterie = sp.coterie || []; p.legend = sp.legend || 0;
    p.factionRank = sp.factionRank || null; p.relations = sp.relations || null; p.nemeses = sp.nemeses || [];
    p.trophies = sp.trophies || []; p.blessings = sp.blessings || {}; p.businesses = sp.businesses || null;
    p.reagents = sp.reagents || null; p.blessingMods = sp.blessingMods || null; p.childeCount = sp.childeCount || 0;
    // signature-verb unlocks (grandfather older saves that already passed the level gate)
    p.finisherUnlocked = sp.finisherUnlocked || (sp.level >= 3) || false;
    p.pounceUnlocked = sp.pounceUnlocked || (sp.level >= 2) || false;
    if (VAMP.Progress) VAMP.Progress.restore(p, sp.progress);   // ensure + backfill (default-safe when undefined)
    if (VAMP.Haven) VAMP.Haven.ensure(p);
    if (VAMP.Mastery) VAMP.Mastery.ensure(p);
    if (VAMP.Codex) VAMP.Codex.ensure(p);
    if (VAMP.Reputation && VAMP.Reputation.ensure) VAMP.Reputation.ensure(p);
    // equipment
    p.equipment.attire = sp.equip ? sp.equip.attire : null;
    p.equipment.charm1 = sp.equip ? sp.equip.charm1 : null;
    p.equipment.charm2 = sp.equip ? sp.equip.charm2 : null;
    VAMP.Stats.recompute(p);
    if (sp.equip && sp.equip.weaponItem) {
      p.inventory.push(sp.equip.weaponItem);
      VAMP.Inventory.equip(p, sp.equip.weaponItem);
    }
    VAMP.Stats.recompute(p);
    p.hp = isFinite(sp.hp) ? Math.min(p.derived.maxHP, sp.hp) : p.derived.maxHP;          // NaN/garbage → full, never brick survival
    p.blood = isFinite(sp.blood) ? Math.min(p.derived.maxBlood, sp.blood) : p.derived.maxBlood;
  }

  // ---- settings ----
  function saveSettings(s) { try { localStorage.setItem(SET, JSON.stringify(s)); } catch (e) {} }
  function loadSettings() { try { const r = localStorage.getItem(SET); return r ? JSON.parse(r) : null; } catch (e) { return null; } }

  VAMP.Save = { hasSave, save, load, clear, applyToPlayer, serialize, saveSettings, loadSettings, VERSION };
})();
