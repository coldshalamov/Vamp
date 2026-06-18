/* =========================================================================
 * VAMPIRE CITY — systems/save.js
 * Serialize / deserialize the run to localStorage. Captures only plain data
 * (no entity refs or functions). Settings persisted separately.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const KEY = 'vampcity_save_v1';                    // legacy single-slot key (kept for migration)
  const SLOT_KEYS = ['vampcity_save_v1_0', 'vampcity_save_v1_1', 'vampcity_save_v1_2'];
  const SET = 'vampcity_settings_v1';
  const VERSION = 3;
  const CLANS = { brujah: 1, gangrel: 1, tremere: 1, ventrue: 1, toreador: 1, nosferatu: 1, malkavian: 1 };

  function obj(v) { return v && typeof v === 'object' && !Array.isArray(v); }
  function isLoadableSave(data) { return obj(data) && obj(data.player) && data.seed != null; }
  function parseStoredSave(raw) {
    if (!raw) return null;
    const data = JSON.parse(raw);
    return isLoadableSave(data) ? data : null;
  }
  function cleanClan(v) {
    const clan = typeof v === 'string' ? v.toLowerCase() : '';
    return CLANS[clan] ? clan : 'brujah';
  }

  function migrateLegacy() {
    try {
      const legacy = localStorage.getItem(KEY);
      if (!legacy) return;
      if (localStorage.getItem(SLOT_KEYS[0])) { localStorage.removeItem(KEY); return; }
      localStorage.setItem(SLOT_KEYS[0], legacy);
      localStorage.removeItem(KEY);
    } catch (e) {}
  }

  function hasSaveSlot(i) {
    try { return !!parseStoredSave(localStorage.getItem(SLOT_KEYS[i])); } catch (e) { return false; }
  }
  function hasSave() {
    if (hasSaveSlot(0) || hasSaveSlot(1) || hasSaveSlot(2)) return true;
    try { return !!parseStoredSave(localStorage.getItem(KEY)); } catch (e) { return false; }
  }

  function getSlotSummary(i) {
    try {
      const d = parseStoredSave(localStorage.getItem(SLOT_KEYS[i]));
      if (!d) return null;
      const p = obj(d.player) ? d.player : {};
      const blood = obj(p.bloodState) ? p.bloodState : {};
      return {
        clan: cleanClan(p.clan),
        level: Math.floor(num(p.level, 1, 1, VAMP.Stats && VAMP.Stats.MAX_LEVEL || 60)),
        day: Math.floor(num(d.day, 1, 1, 1000000)),
        humanity: num(blood.humanity, 5, 0, 10),
      };
    } catch (e) { return null; }
  }

  function serialize(game) {
    const p = game.player;
    const data = {
      v: VERSION,
      seed: game.world.seed,
      time: game.time,
      clock: game.clock,
      day: game.day,
      missionsDone: game.missionsDone || 0,
      activeMission: VAMP.Missions && VAMP.Missions.serialize ? VAMP.Missions.serialize(game) : null,
      heat: game.masquerade.heat,
      difficulty: game.difficulty || 'normal',
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
        chainProgress: p.chainProgress || {}, chainTitles: p.chainTitles || {},   // contract-chain storyline progress
        // progression-reveal ledger + signature-verb unlocks
        progress: VAMP.Progress ? VAMP.Progress.serialize(p) : null,
        finisherUnlocked: p.finisherUnlocked || false,
        pounceUnlocked: p.pounceUnlocked || false,
      },
      domains: game.domains, districtState: game.districtState,
    };
    return data;
  }

  function saveSlot(i, game) {
    try {
      localStorage.setItem(SLOT_KEYS[i], JSON.stringify(serialize(game)));
      return true;
    } catch (e) { console.warn('save failed', e); return false; }
  }

  function save(game) {
    const slot = (game && game._saveSlot != null) ? game._saveSlot : 0;
    return saveSlot(slot, game);
  }

  function loadSlot(i) {
    try {
      return parseStoredSave(localStorage.getItem(SLOT_KEYS[i]));
    } catch (e) { return null; }
  }

  function load() {
    // First occupied slot (for backward-compat callers)
    for (let i = 0; i < SLOT_KEYS.length; i++) { const d = loadSlot(i); if (d) return d; }
    try { return parseStoredSave(localStorage.getItem(KEY)); } catch (e) { return null; }
  }

  function clearSlot(i) { try { localStorage.removeItem(SLOT_KEYS[i]); } catch (e) {} }
  function clear() { for (let i = 0; i < SLOT_KEYS.length; i++) clearSlot(i); try { localStorage.removeItem(KEY); } catch (e) {} }

  function safeLoadedPosition(p, sp) {
    const x = +sp.x, y = +sp.y;
    const world = VAMP.Game && VAMP.Game.world;
    if (isFinite(x) && isFinite(y) && (!world || !world.isWalkable || world.isWalkable(x, y))) return { x, y };
    if (world && world.randomWalkPos) return world.randomWalkPos();
    return { x: isFinite(p.x) ? p.x : 0, y: isFinite(p.y) ? p.y : 0 };
  }

  function num(v, fallback, min, max) {
    let n = +v;
    if (!isFinite(n)) n = fallback;
    if (min != null && n < min) n = min;
    if (max != null && n > max) n = max;
    return n;
  }

  function boolMap(src) {
    const out = {};
    if (!obj(src)) return out;
    for (const k in src) if (src[k]) out[k] = true;
    return out;
  }
  function savedTrue(v) { return v === true || v === 1; }

  function modMap(src, min, max) {
    const out = {};
    if (!obj(src)) return out;
    for (const k in src) {
      const v = num(src[k], 0, min, max);
      if (v) out[k] = v;
    }
    return out;
  }

  function cleanModBag(src) {
    if (!obj(src)) return null;
    const add = modMap(src.add, -100000, 100000);
    const pct = modMap(src.pct, -0.95, 10);
    return (Object.keys(add).length || Object.keys(pct).length) ? { add, pct } : null;
  }

  function cleanTreeNodes(src) {
    const out = {};
    const idx = VAMP.Data && VAMP.Data.TREE_INDEX;
    if (!obj(src) || !idx) return out;
    for (const id in src) {
      const node = idx[id];
      if (!node) continue;
      const rank = Math.floor(num(src[id], 0, 0, node.maxRank || 1));
      if (rank > 0) out[id] = rank;
    }
    // strip conflicting keystones — impossible in new saves (allocate() blocks them),
    // but defensive for saves created before mutual exclusion was introduced.
    for (const id in out) {
      const node = idx[id];
      if (!node || !node.conflicts) continue;
      for (const cid of node.conflicts) { if (out[cid]) delete out[cid]; }
    }
    return out;
  }

  function cleanPowers(src) {
    const out = {};
    const defs = VAMP.Data && VAMP.Data.POWERS;
    if (!obj(src)) return out;
    for (const id in src) if (src[id] && (!defs || defs[id])) out[id] = true;
    return out;
  }

  function cleanSlots(src, powers) {
    const out = [null, null, null, null, null, null, null, null];
    if (!Array.isArray(src)) return out;
    for (let i = 0; i < out.length; i++) {
      const id = typeof src[i] === 'string' ? src[i] : null;
      out[i] = id && powers[id] ? id : null;
    }
    return out;
  }

  function cleanBloodState(src) {
    const b = VAMP.Blood.newBloodState();
    if (!obj(src)) return b;
    b.hunger = num(src.hunger, b.hunger, 0, 5);
    b.humanity = num(src.humanity, b.humanity, 0, 10);
    b.stains = Math.floor(num(src.stains, b.stains, 0, 999));
    b.frenzy = num(src.frenzy, b.frenzy, 0, 1);
    b.frenzied = src.frenzied === true;
    b.frenzyCooldown = num(src.frenzyCooldown, b.frenzyCooldown, 0, 9999);
    b.kills = Math.floor(num(src.kills, b.kills, 0, 1000000000));
    b.innocentKills = Math.floor(num(src.innocentKills, b.innocentKills, 0, 1000000000));
    b.fedCount = Math.floor(num(src.fedCount, b.fedCount, 0, 1000000000));
    b.elderVitae = Math.floor(num(src.elderVitae, b.elderVitae, 0, 1000000));
    b.elderProgress = num(src.elderProgress, b.elderProgress, 0, VAMP.Stats.ELDER_XP || 2000);
    b.dawnStreak = Math.floor(num(src.dawnStreak, b.dawnStreak, 0, 1000000));
    b.elderSpent = {};
    const elderKeys = VAMP.Stats.ELDER_KEYS || {};
    if (obj(src.elderSpent)) {
      for (const k in src.elderSpent) {
        if (!elderKeys[k]) continue;
        const spent = Math.floor(num(src.elderSpent[k], 0, 0, 1000000));
        if (spent) b.elderSpent[k] = spent;
      }
    }
    return b;
  }

  function cleanStats(src, fallback) {
    const out = Object.assign({}, fallback || {});
    if (!obj(src)) return out;
    for (const k in src) out[k] = num(src[k], out[k] || 0, 0, 1000000000);
    return out;
  }

  function cleanHaven(src) {
    if (!obj(src)) return null;
    const out = { rooms: {}, cellarVitae: num(src.cellarVitae, 0, 0, 1000000000) };
    const rooms = (VAMP.Data && VAMP.Data.HAVEN_ROOMS) || [];
    for (const r of rooms) out.rooms[r.id] = Math.floor(num(src.rooms && src.rooms[r.id], 0, 0, r.max || 99));
    return out;
  }

  function cleanMastery(src) {
    if (!obj(src) || !VAMP.Mastery) return null;
    const out = {};
    for (const k in VAMP.Mastery.TRACKS) {
      const tr = obj(src[k]) ? src[k] : {};
      const xp = num(tr.xp, 0, 0, 1000000000);
      out[k] = { xp, rank: VAMP.Mastery.rankFor ? VAMP.Mastery.rankFor(xp) : Math.floor(num(tr.rank, 0, 0, VAMP.Mastery.CAP || 12)) };
    }
    return out;
  }

  function cleanReputation(src) {
    if (!obj(src)) return null;
    const out = {};
    const factions = (VAMP.Reputation && VAMP.Reputation.FACTIONS) || { camarilla: 1, anarch: 1, inquis: 1, gang: 1, police: 1 };
    for (const k in factions) out[k] = num(src[k], 0, -100, 100);
    return out;
  }

  function cleanBusinesses(src) {
    if (!obj(src)) return null;
    const out = {};
    const defs = VAMP.Data && VAMP.Data.BUSINESSES || [];
    for (const d of defs) {
      const b = obj(src[d.id]) ? src[d.id] : null;
      if (!b || !b.owned) continue;
      out[d.id] = { owned: true, tier: Math.floor(num(b.tier, 0, 0, VAMP.Business ? VAMP.Business.MAXTIER : 4)) };
    }
    return out;
  }

  function cleanReagents(src) {
    if (!obj(src)) return null;
    const out = {};
    for (const k in src) {
      const key = String(k).slice(0, 40);
      const count = Math.floor(num(src[k], 0, 0, 1000000000));
      if (key && count > 0) out[key] = (out[key] || 0) + count;
    }
    return Object.keys(out).length ? out : null;
  }

  function cleanCoterie(src) {
    if (!Array.isArray(src)) return [];
    const jobs = VAMP.Coterie && VAMP.Coterie.JOBS || { none: 1 };
    return src.slice(0, 12).filter(obj).map((m) => {
      const assignment = jobs[m.assignment] ? m.assignment : 'none';
      return {
        id: Math.floor(num(m.id, 0, 0, 1000000000)),
        name: typeof m.name === 'string' && m.name ? m.name.slice(0, 80) : 'Thrall',
        archetype: typeof m.archetype === 'string' ? m.archetype.slice(0, 40) : 'thrall',
        level: Math.floor(num(m.level, 1, 1, 1000)),
        xp: num(m.xp, 0, 0, 1000000000),
        loyalty: num(m.loyalty, 50, 0, 100),
        assignment,
        isChilde: m.isChilde === true,
      };
    });
  }

  function cleanNemeses(src) {
    if (!Array.isArray(src)) return [];
    return src.slice(0, 12).filter(obj).map((r) => {
      const out = {
        name: typeof r.name === 'string' && r.name ? r.name.slice(0, 80) : 'Unknown Hunter',
        rank: Math.floor(num(r.rank, 1, 1, 1000)),
      };
      if (typeof r.scar === 'string' && r.scar) out.scar = r.scar.slice(0, 80);
      if (typeof r.resistType === 'string' && r.resistType) out.resistType = r.resistType.slice(0, 40);
      return out;
    });
  }

  function cleanTrophies(src) {
    if (!Array.isArray(src)) return [];
    const defs = VAMP.Trophies && VAMP.Trophies.DEFS || {};
    const seen = {};
    const out = [];
    for (const t of src) {
      if (!obj(t) || typeof t.id !== 'string' || !defs[t.id] || seen[t.id]) continue;
      seen[t.id] = true;
      out.push({ id: t.id, name: typeof t.name === 'string' ? t.name : defs[t.id].name, desc: typeof t.desc === 'string' ? t.desc : defs[t.id].desc });
    }
    return out;
  }

  function cleanItem(item) {
    if (!obj(item)) return null;
    const slot = item.slot === 'weapon' || item.slot === 'attire' || item.slot === 'charm' ? item.slot : 'charm';
    const out = {
      id: Math.floor(num(item.id, 0, 0, 1000000000)),
      slot,
      rarity: typeof item.rarity === 'string' ? item.rarity : 'common',
      level: Math.floor(num(item.level, 1, 1, 1000)),
      name: typeof item.name === 'string' && item.name ? item.name.slice(0, 120) : 'Item',
      baseName: typeof item.baseName === 'string' && item.baseName ? item.baseName.slice(0, 120) : 'Item',
      glyph: typeof item.glyph === 'string' && item.glyph ? item.glyph.slice(0, 4) : '?',
      color: typeof item.color === 'string' && item.color ? item.color : '#cdd',
      mods: cleanModBag(item.mods) || { add: {}, pct: {} },
      affixes: Array.isArray(item.affixes) ? item.affixes.filter((x) => typeof x === 'string').slice(0, 8) : [],
    };
    if (item.relic) out.relic = true;
    if (obj(item.weaponStats)) {
      out.weaponStats = {
        kind: typeof item.weaponStats.kind === 'string' ? item.weaponStats.kind : 'pistol',
        name: typeof item.weaponStats.name === 'string' ? item.weaponStats.name : out.name,
        dmg: num(item.weaponStats.dmg, 10, 0, 10000),
        fireRate: num(item.weaponStats.fireRate, 0.35, 0.02, 10),
        spread: num(item.weaponStats.spread, 0.04, 0, 10),
        speed: num(item.weaponStats.speed, 620, 1, 5000),
        pellets: Math.floor(num(item.weaponStats.pellets, 1, 1, 100)),
        pierce: Math.floor(num(item.weaponStats.pierce, 0, 0, 100)),
        dmgMult: num(item.weaponStats.dmgMult, 1, 0, 100),
        rangeBonus: num(item.weaponStats.rangeBonus, 0, 0, 1000),
      };
    }
    return out;
  }

  function cleanInventory(src) {
    if (!Array.isArray(src)) return [];
    return src.map(cleanItem).filter(Boolean).slice(0, 40);
  }

  function cleanEquip(src) {
    src = obj(src) ? src : {};
    return {
      attire: cleanItem(src.attire),
      charm1: cleanItem(src.charm1),
      charm2: cleanItem(src.charm2),
      weaponItem: cleanItem(src.weaponItem),
    };
  }

  function cleanChainProgress(src) {
    const out = {};
    const chains = VAMP.Missions && VAMP.Missions.CHAINS || {};
    if (!obj(src)) return out;
    for (const k in chains) out[k] = Math.floor(num(src[k], 0, 0, chains[k].steps.length));
    return out;
  }

  function cleanChainTitles(src) {
    const out = {};
    const chains = VAMP.Missions && VAMP.Missions.CHAINS || {};
    if (!obj(src)) return out;
    for (const k in chains) if (src[k] && typeof src[k] === 'string') out[k] = src[k].slice(0, 80);
    return out;
  }

  function sanitizeRun(data) {
    if (!obj(data)) return data;
    const diffs = { normal: 1, easy: 1, hard: 1 };
    return Object.assign({}, data, {
      seed: Math.floor(num(data.seed, 12345, 1, 0xffffffff)),
      time: num(data.time, 0, 0, 1000000000),
      clock: num(data.clock, 21, 0, 24),
      day: Math.floor(num(data.day, 1, 1, 1000000)),
      missionsDone: Math.floor(num(data.missionsDone, 0, 0, 1000000000)),
      heat: num(data.heat, 0, 0, 100),
      difficulty: diffs[data.difficulty] ? data.difficulty : 'normal',
    });
  }

  function sanitizeWorldState(data, world) {
    const domains = {}, districtState = {};
    const ds = obj(data && data.districtState) ? data.districtState : {};
    const dm = obj(data && data.domains) ? data.domains : {};
    const districts = world && world.districts || [];
    for (const d of districts) {
      const sd = obj(dm[d.id]) ? dm[d.id] : {};
      // Baron fights are transient NPC encounters; bosses are not serialized.
      domains[d.id] = { owner: sd.owner === 'player' ? 'player' : null, contesting: false };
      const st = obj(ds[d.id]) ? ds[d.id] : {};
      districtState[d.id] = { terror: num(st.terror, 0, 0, 1), prosperity: num(st.prosperity, 0, 0, 1) };
    }
    return { domains, districtState };
  }

  // apply a loaded data blob onto a freshly-created player
  function applyToPlayer(p, sp) {
    p.level = Math.floor(num(sp.level, 1, 1, VAMP.Stats.MAX_LEVEL || 60));
    p.xp = Math.floor(num(sp.xp, 0, 0));
    p.xpTotal = Math.floor(num(sp.xpTotal, p.xp, 0));
    // sanitize attributes: missing/garbage field must not NaN-brick the run
    p.attributes = Object.assign(VAMP.Stats.newAttributes(), sp.attributes || {});
    for (const k in p.attributes) { const v = +p.attributes[k]; p.attributes[k] = isFinite(v) && v >= 1 ? v : 1; }
    p.attrPoints = Math.floor(num(sp.attrPoints, 0, 0));
    p.skillPoints = Math.floor(num(sp.skillPoints, 0, 0));
    p.treeNodes = cleanTreeNodes(sp.treeNodes); p.powers = cleanPowers(sp.powers); p.slots = cleanSlots(sp.slots, p.powers);
    p.money = Math.floor(num(sp.money, 0, 0));
    p.respecs = Math.floor(num(sp.respecs, 0, 0));
    p.aimMode = sp.aimMode || 'move';
    p.inventory = cleanInventory(sp.inventory);
    p.bloodState = cleanBloodState(sp.bloodState);
    p.stats = cleanStats(sp.stats, p.stats);
    p.toggles = {}; p.cloaked = false; p.buffs = [];
    const pos = safeLoadedPosition(p, sp);
    p.x = pos.x; p.y = pos.y; p.clan = cleanClan(sp.clan);
    // continuing-value persistent blocks (all default-safe for old saves)
    p.haven = cleanHaven(sp.haven); p.mastery = cleanMastery(sp.mastery); p.codex = sp.codex || null;
    p.reputation = cleanReputation(sp.reputation); p.coterie = cleanCoterie(sp.coterie); p.legend = num(sp.legend, 0, 0, 1000000000);
    p.factionRank = sp.factionRank || null; p.relations = sp.relations || null; p.nemeses = cleanNemeses(sp.nemeses);
    p.trophies = cleanTrophies(sp.trophies); p.blessings = boolMap(sp.blessings); p.businesses = cleanBusinesses(sp.businesses);
    p.reagents = cleanReagents(sp.reagents); p.blessingMods = cleanModBag(sp.blessingMods); p.childeCount = Math.floor(num(sp.childeCount, 0, 0));
    p.chainProgress = cleanChainProgress(sp.chainProgress); p.chainTitles = cleanChainTitles(sp.chainTitles);   // contract-chain storyline progress
    // signature-verb unlocks (grandfather older saves that already passed the level gate)
    p.finisherUnlocked = savedTrue(sp.finisherUnlocked) || p.level >= 3;
    p.pounceUnlocked = savedTrue(sp.pounceUnlocked) || p.level >= 2;
    if (VAMP.Progress) VAMP.Progress.restore(p, sp.progress);   // ensure + backfill (default-safe when undefined)
    if (VAMP.Haven) VAMP.Haven.ensure(p);
    if (VAMP.Mastery) VAMP.Mastery.ensure(p);
    if (VAMP.Codex) VAMP.Codex.ensure(p);
    if (VAMP.Reputation && VAMP.Reputation.ensure) VAMP.Reputation.ensure(p);
    // equipment
    const equip = cleanEquip(sp.equip);
    p.equipment.attire = equip.attire;
    p.equipment.charm1 = equip.charm1;
    p.equipment.charm2 = equip.charm2;
    VAMP.Stats.recompute(p);
    if (equip.weaponItem) {
      p.inventory.push(equip.weaponItem);
      VAMP.Inventory.equip(p, equip.weaponItem);
    }
    VAMP.Stats.recompute(p);
    p.hp = num(sp.hp, p.derived.maxHP, 0, p.derived.maxHP);          // NaN/garbage → full, never brick survival
    p.blood = num(sp.blood, p.derived.maxBlood, 0, p.derived.maxBlood);
  }

  // ---- settings ----
  function saveSettings(s) { try { localStorage.setItem(SET, JSON.stringify(s)); } catch (e) {} }
  function loadSettings() { try { const r = localStorage.getItem(SET); return r ? JSON.parse(r) : null; } catch (e) { return null; } }

  VAMP.Save = { hasSave, hasSaveSlot, save, saveSlot, load, loadSlot, clear, clearSlot, migrateLegacy, getSlotSummary, applyToPlayer, serialize, sanitizeRun, sanitizeWorldState, saveSettings, loadSettings, VERSION };
})();
