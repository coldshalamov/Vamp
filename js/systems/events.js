/* =========================================================================
 * VAMPIRE CITY — systems/events.js  (#23 Emergent random events)
 * Spawns unscripted city moments every couple of minutes to keep the open
 * world alive between contracts: gang wars, police crackdowns, blood-hunts,
 * wandering VIPs, and fainting mortals (free feed). Purely additive — all
 * events build on existing NPC/spawn machinery, so nothing else changes.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  const DEFS = [
    { id: 'gangwar',    weight: 3, minStars: 0, run: gangWar,    name: 'Gang War' },
    { id: 'crackdown',  weight: 2, minStars: 2, run: crackDown,  name: 'Police Crackdown' },
    { id: 'bloodhunt',  weight: 2, minStars: 3, run: bloodHunt,  name: 'Blood Hunt' },
    { id: 'vip',        weight: 2, minStars: 0, run: vipSight,   name: 'Aristocrat Sighting' },
    { id: 'faint',      weight: 2, minStars: 0, run: fainters,   name: 'Fainting Mortals' },
    { id: 'domainraid', weight: 2, minStars: 0, run: domainRaid, name: 'Rival Domain Raid', needsDomain: true },
  ];

  function pickPosNear(game, minD, maxD) {
    const p = game.player;
    const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
    for (let i = 0; i < 30; i++) {
      const a = Math.random() * U.TAU, d = U.range(minD, maxD);
      const x = px + Math.cos(a) * d, y = py + Math.sin(a) * d;
      if (game.world.isWalkable(x, y)) return { x, y };
    }
    return game.world.randomWalkPos(Math.random);
  }

  // a skirmish between two rival gangs near the player — they fight EACH OTHER, not you.
  // (No berserk: a berserker attacks anyone, which used to drag a calm player into a fight
  //  for standing nearby. Mutual retaliation keeps the brawl self-contained — pure spectacle
  //  unless you choose to wade in.)
  function gangWar(game) {
    const pos = pickPosNear(game, 500, 900); if (!pos) return false;
    const red = [], blue = [];
    for (let i = 0; i < 3; i++) {
      const a = VAMP.Npc.create(game.world, 'gunner', pos.x + (Math.random() - 0.5) * 70, pos.y + (Math.random() - 0.5) * 70, {});
      a.faction = 'gang'; a.shirt = '#6a1f2a'; red.push(a); game.addNPC(a);
      const b = VAMP.Npc.create(game.world, Math.random() < 0.5 ? 'gunner' : 'thug', pos.x + 100 + (Math.random() - 0.5) * 70, pos.y + (Math.random() - 0.5) * 70, {});
      b.faction = 'gang'; b.shirt = '#2a1f6a'; blue.push(b); game.addNPC(b);
    }
    red.forEach((e, i) => { e.aggro = true; e.retaliateAgainst = blue[i % blue.length]; e.retaliateT = 40; e.state = 'chase'; });
    blue.forEach((e, i) => { e.aggro = true; e.retaliateAgainst = red[i % red.length]; e.retaliateT = 40; e.state = 'chase'; });
    VAMP.UI.notify('A gang war erupts nearby — let them thin each other out.', '#ff9030');
    return true;
  }
  // cops flood the area (triggered by high heat)
  function crackDown(game) {
    const pos = pickPosNear(game, 400, 700); if (!pos) return false;
    for (let i = 0; i < 4; i++) {
      const c = VAMP.Npc.create(game.world, 'swat', pos.x + (Math.random() - 0.5) * 120, pos.y + (Math.random() - 0.5) * 120, {});
      c.faction = 'police'; c.aggro = false; game.addNPC(c);
    }
    VAMP.UI.notify('Sirens — a police crackdown sweeps the district. Lay low.', '#5a8cff');
    return true;
  }
  // Second Inquisition hunters actively hunting the player
  function bloodHunt(game) {
    const pos = pickPosNear(game, 600, 1000); if (!pos) return false;
    for (let i = 0; i < 3; i++) {
      const h = VAMP.Npc.create(game.world, 'hunter', pos.x + (Math.random() - 0.5) * 60, pos.y + (Math.random() - 0.5) * 60, {});
      h.faction = 'inquis'; h.aggro = true; h.hostileToPlayer = true; game.addNPC(h);
    }
    VAMP.UI.banner('BLOOD HUNT', 'Second Inquisition hunters have your scent. Flee or fight.', '#ff3030');
    if (VAMP.Audio) VAMP.Audio.play('siren');
    return true;
  }
  // a rich aristocrat wanders by — high-yield prey
  function vipSight(game) {
    const pos = pickPosNear(game, 300, 600); if (!pos) return false;
    const v = VAMP.Npc.create(game.world, 'ped', pos.x, pos.y, { victimType: 'noble' });
    v.victimType = 'noble'; v.vip = true; v.money = 0; game.addNPC(v);
    game.addBlip({ ref: v, color: '#ffd24a', kind: 'event', ttl: game.time + 30 });
    VAMP.UI.notify('An Aristocrat lingers nearby — rich, potent blood. (♥ gold)', '#ffd24a');
    return true;
  }
  // a few dazed mortals — easy feed
  function fainters(game) {
    const pos = pickPosNear(game, 200, 500); if (!pos) return false;
    for (let i = 0; i < 3; i++) {
      const f = VAMP.Npc.create(game.world, 'ped', pos.x + (Math.random() - 0.5) * 60, pos.y + (Math.random() - 0.5) * 60, { victimType: 'junkie' });
      f.victimType = 'junkie'; f.mesmerizedT = 0; f.speed *= 0.5; game.addNPC(f);
    }
    VAMP.UI.notify('Revelers stumble past, dazed — easy prey.', '#9a8');
    return true;
  }

  // rival gang moves into a player-owned domain, raises terror and cuts tithe unless player intervenes
  function domainRaid(game) {
    if (!VAMP.Domains || !game.world.districts) return false;
    const owned = game.world.districts.filter((d) => VAMP.Domains.isOwned(game, d.id));
    if (!owned.length) return false;
    const target = owned[(Math.random() * owned.length) | 0];
    // spawn raiders in the district's center area
    const cx = (target.x + target.w / 2) || 0, cy = (target.y + target.h / 2) || 0;
    let pos = null;
    for (let i = 0; i < 30; i++) { const a = Math.random() * U.TAU, d = U.range(80, 300); const x = cx + Math.cos(a) * d, y = cy + Math.sin(a) * d; if (game.world.isWalkable(x, y)) { pos = { x, y }; break; } }
    if (!pos) pos = pickPosNear(game, 400, 800);
    if (!pos) return false;
    const count = 4 + Math.floor(Math.random() * 3);
    for (let i = 0; i < count; i++) {
      const r = VAMP.Npc.create(game.world, Math.random() < 0.5 ? 'gunner' : 'thug', pos.x + (Math.random() - 0.5) * 100, pos.y + (Math.random() - 0.5) * 100, {});
      r.faction = 'gang'; r.hostileToPlayer = false; r.aggro = false; r.domainRaider = true;
      r.onDead = () => { if (VAMP.UI) VAMP.UI.notify('Raider down — defend your domain!', '#ffd24a'); };
      game.addNPC(r);
    }
    game.addBlip({ pos, color: '#ff9030', kind: 'event', ttl: game.time + 120 });
    // after 90s if raiders still alive → raise terror
    const raiderGroup = game.npcs.filter((n) => n.domainRaider && !n.dead);
    setTimeout(() => {
      const stillAlive = game.npcs.filter((n) => n.domainRaider && !n.dead && !n._terrorApplied).length;
      if (stillAlive > 0) {
        VAMP.Domains.raiseTerror(game, pos.x, pos.y, 0.25);
        if (VAMP.UI) VAMP.UI.notify('Rival gang seized ground in ' + (VAMP.Domains.distName ? VAMP.Domains.distName(game, target.id) : 'your domain') + ' — tithe cut!', '#ff7030');
        for (const n of game.npcs) if (n.domainRaider) n._terrorApplied = true;
      }
    }, 90000);
    VAMP.UI.banner('DOMAIN UNDER ATTACK', 'Rival gang moves into ' + (VAMP.Domains.distName ? VAMP.Domains.distName(game, target.id) : 'your district') + '! Drive them out within 90 seconds.', '#ff9030');
    if (VAMP.Audio) VAMP.Audio.play('siren');
    return true;
  }

  function create(game) {
    return {
      timer: U.range(60, 110),  // first event a minute or two in
      update(dt, g) {
        this.timer -= dt;
        if (this.timer > 0) return;
        this.timer = U.range(90, 160);   // then every ~2 minutes
        // build a weighted pool gated by current heat and domain ownership
        const stars = g.masquerade ? g.masquerade.stars : 0;
        const hasDomain = VAMP.Domains && VAMP.Domains.ownedCount && VAMP.Domains.ownedCount(g) > 0;
        const pool = [];
        for (const d of DEFS) { if (stars < d.minStars) continue; if (d.needsDomain && !hasDomain) continue; for (let i = 0; i < d.weight; i++) pool.push(d); }
        if (!pool.length) return;
        const def = pool[(Math.random() * pool.length) | 0];
        try { def.run(g); } catch (e) { /* never let an event break the loop */ }
      },
    };
  }

  VAMP.Events = { create, DEFS };
})();
