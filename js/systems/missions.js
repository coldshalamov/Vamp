/* =========================================================================
 * VAMPIRE CITY — systems/missions.js
 * Mission framework with 8 distinct types. Each is made more interesting by
 * the progression systems (stealth/feeding/AoE/driving/control builds).
 * One active contract at a time; offers come from Mission Boards.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  let MID = 1;

  function offers(game) {
    const D = VAMP.Data;
    const lvl = game.player.level;
    const list = [];
    const types = D.MISSION_TYPES.slice();
    U.makeRNG;
    // pick 3 distinct
    const pool = types.slice();
    for (let i = 0; i < 3 && pool.length; i++) {
      const t = pool.splice((Math.random() * pool.length) | 0, 1)[0];
      list.push(build(game, t, lvl));
    }
    return list;
  }

  function build(game, t, lvl) {
    const n = t.type === 'feed' ? 3 + (lvl / 8 | 0)
      : t.type === 'collect' ? 3 + (lvl / 10 | 0)
        : t.type === 'cleanse' ? 4 + (lvl / 6 | 0)
          : t.type === 'survive' ? 3 + (lvl / 8 | 0)
            : 1;
    const name = VAMP.Data.FIRST[(Math.random() * VAMP.Data.FIRST.length) | 0] + ' ' + VAMP.Data.LAST[(Math.random() * VAMP.Data.LAST.length) | 0];
    const desc = t.desc.replace('{n}', n).replace('{name}', name);
    const reward = {
      xp: Math.round(t.baseReward.xp * (1 + lvl * 0.12)),
      money: Math.round(t.baseReward.money * (1 + lvl * 0.15)),
      itemChance: 0.6,
    };
    return {
      id: MID++, type: t.type, name: t.name, icon: t.icon, color: t.color, desc,
      level: lvl, need: n, progress: 0, state: 'available', reward, targetName: name,
      markers: [], spawned: [], timeLimit: 0, timer: 0, phase: 0, data: {},
    };
  }

  function accept(game, m) {
    if (game.activeMission) { if (VAMP.UI) VAMP.UI.notify('Finish your current contract first', '#a66'); return false; }
    m.state = 'active';
    game.activeMission = m;
    setup(game, m);
    if (VAMP.Progress) VAMP.Progress.markSeen(game.player, 'missions');
    if (VAMP.UI) VAMP.UI.notify('Contract accepted: ' + m.name, m.color);
    if (VAMP.Audio) VAMP.Audio.play('uiBig');
    VAMP.bus && VAMP.bus.emit('mission', m);
    return true;
  }

  function spot(game, minD, maxD) {
    const p = game.player; const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
    for (let i = 0; i < 80; i++) {
      const a = Math.random() * U.TAU, d = U.lerp(minD, maxD, Math.random());
      const x = px + Math.cos(a) * d, y = py + Math.sin(a) * d;
      if (x < 60 || y < 60 || x > game.world.w - 60 || y > game.world.h - 60) continue;
      if (game.world.isWalkable(x, y)) return { x, y };
    }
    return game.world.randomWalkPos(Math.random);
  }

  function setup(game, m) {
    const lvl = m.level;
    switch (m.type) {
      case 'feed': {
        m.desc = 'Feed on ' + m.need + ' mortals (don\'t kill in the open).';
        break; // feeds tracked via event
      }
      case 'assassinate': {
        const pos = spot(game, 360, 800);
        const tgt = VAMP.Npc.create(game.world, 'gunner', pos.x, pos.y, { hp: 120 + lvl * 8, vip: true, name: m.targetName });
        tgt.type = 'gunner'; tgt.weapon = 'pistol'; tgt.faction = 'gang'; tgt.mission = m.id; tgt.vip = true; tgt.aggro = false;
        game.addNPC(tgt); m.spawned.push(tgt); m.data.target = tgt;
        // guards
        for (let i = 0; i < 2 + (lvl / 10 | 0); i++) { const gp = { x: pos.x + (Math.random() - 0.5) * 80, y: pos.y + (Math.random() - 0.5) * 80 }; const g = VAMP.Npc.create(game.world, 'gunner', gp.x, gp.y, { hp: 60 + lvl * 4 }); g.faction = 'gang'; g.mission = m.id; game.addNPC(g); m.spawned.push(g); }
        m.markers.push({ ref: tgt, color: m.color, label: 'TARGET' });
        break;
      }
      case 'collect': {
        for (let i = 0; i < m.need; i++) {
          const pos = spot(game, 200, 900);
          const pk = game.addPickup({ x: pos.x, y: pos.y, kind: 'relic', color: '#c0a030', glyph: '◆', mission: m.id });
          m.markers.push({ ref: pk, color: '#c0a030', label: 'RELIC' });
        }
        break;
      }
      case 'escort': {
        const start = spot(game, 60, 160);
        const dest = game.nearestHaven ? game.nearestHaven(start.x, start.y, true) : spot(game, 700, 1300);
        const courier = VAMP.Npc.create(game.world, 'thrall', start.x, start.y, { name: 'Courier', hp: 90 + lvl * 6 });
        courier.scripted = true; courier.ally = true; courier.faction = 'player'; courier.weapon = null; courier.mission = m.id; courier.vip = true;
        game.addNPC(courier);
        m.data.courier = courier; m.data.dest = dest; m.spawned.push(courier);
        m.markers.push({ ref: courier, color: '#5aff8c', label: 'COURIER' });
        m.markers.push({ x: dest.x, y: dest.y, color: '#5a9cff', label: 'HAVEN' });
        // ambushers spawn over time
        m.timer = 0;
        break;
      }
      case 'cleanse': {
        const center = spot(game, 360, 800);
        for (let i = 0; i < m.need; i++) {
          const gp = { x: center.x + (Math.random() - 0.5) * 160, y: center.y + (Math.random() - 0.5) * 160 };
          const type = (lvl > 15 && Math.random() < 0.4) ? 'hunter' : (Math.random() < 0.5 ? 'gunner' : 'thug');
          const e = VAMP.Npc.create(game.world, type, gp.x, gp.y, { hp: VAMP.Npc.PRESETS[type].hp * (1 + lvl * 0.05) });
          e.mission = m.id; e.aggro = false; game.addNPC(e); m.spawned.push(e);
        }
        m.markers.push({ x: center.x, y: center.y, color: m.color, label: 'NEST' });
        m.data.center = center;
        break;
      }
      case 'heist': {
        const bank = game.findPOI ? game.findPOI('bloodbank') : null;
        const pos = bank ? { x: bank.x, y: bank.y } : spot(game, 400, 900);
        m.data.crackPos = pos; m.data.cracked = false; m.data.crackT = 0;
        m.markers.push({ x: pos.x, y: pos.y, color: '#30c060', label: 'BLOOD BANK' });
        break;
      }
      case 'survive': {
        m.data.wave = 0; m.data.waveT = 1.5; m.data.alive = 0;
        break;
      }
      case 'courier': {
        const dest = spot(game, 800, 1500);
        m.data.dest = dest;
        m.timeLimit = 60 + lvl * 1.5; m.timer = m.timeLimit;
        m.markers.push({ x: dest.x, y: dest.y, color: m.color, label: 'DELIVER' });
        break;
      }
    }
  }

  function onEvent(game, evt, data) {
    const m = game.activeMission;
    if (!m || m.state !== 'active') return;
    if (evt === 'feed' && m.type === 'feed') {
      m.progress++;
      if (VAMP.UI) VAMP.UI.notify('Fed ' + m.progress + '/' + m.need, m.color);
      if (m.progress >= m.need) complete(game, m);
    }
    if (evt === 'kill') {
      if (m.type === 'assassinate' && data.npc === m.data.target) complete(game, m);
      if (m.type === 'cleanse') {
        const remaining = m.spawned.filter((n) => !n.dead).length;
        if (remaining <= 0) complete(game, m);
      }
    }
    if (evt === 'pickup' && m.type === 'collect' && data.mission === m.id) {
      m.progress++;
      m.markers = m.markers.filter((mk) => mk.ref !== data.pickup);
      if (VAMP.UI) VAMP.UI.notify('Relic ' + m.progress + '/' + m.need, m.color);
      if (m.progress >= m.need) complete(game, m);
    }
    if (evt === 'npcDead' && m.type === 'escort' && data.npc === m.data.courier) fail(game, m, 'The courier is dead.');
  }

  function update(game, dt) {
    const m = game.activeMission;
    if (!m || m.state !== 'active') return;

    if (m.type === 'escort') {
      const c = m.data.courier;
      if (!c || c.dead) { fail(game, m, 'The courier is dead.'); return; }
      // drive courier toward dest
      driveTo(c, m.data.dest, dt, game);
      if (U.dist(c.x, c.y, m.data.dest.x, m.data.dest.y) < 50) complete(game, m);
      // spawn ambushers
      m.timer -= dt;
      if (m.timer <= 0 && game.npcs.filter((n) => n.mission === m.id && !n.ally && !n.dead).length < 4) {
        m.timer = 5;
        const ap = { x: c.x + (Math.random() - 0.5) * 400, y: c.y + (Math.random() - 0.5) * 400 };
        if (game.world.isWalkable(ap.x, ap.y)) { const e = VAMP.Npc.create(game.world, 'gunner', ap.x, ap.y, {}); e.mission = m.id; e.aggro = true; e.state = 'chase'; e.hostileToPlayer = true; e.target = c; game.addNPC(e); }
      }
    }

    if (m.type === 'heist') {
      const p = game.player; const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
      if (!m.data.cracked) {
        if (U.dist(px, py, m.data.crackPos.x, m.data.crackPos.y) < 60) {
          m.data.crackT += dt;
          game.crackProgress = U.clamp(m.data.crackT / 5, 0, 1);
          if (((m.data.crackT * 2) | 0) % 2 === 0) game.masquerade.add(0.02);
          if (m.data.crackT >= 5) {
            m.data.cracked = true; game.crackProgress = 0;
            game.masquerade.add(2.5);
            if (VAMP.UI) VAMP.UI.notify('Vault cracked! Escape to a haven!', '#30c060');
            m.markers = [];
            const haven = game.nearestHaven ? game.nearestHaven(px, py, false) : null;
            if (haven) { m.data.dest = haven; m.markers.push({ x: haven.x, y: haven.y, color: '#5a9cff', label: 'ESCAPE' }); }
          }
        } else { m.data.crackT = Math.max(0, m.data.crackT - dt); game.crackProgress = U.clamp(m.data.crackT / 5, 0, 1); }
      } else if (m.data.dest) {
        if (U.dist(px, py, m.data.dest.x, m.data.dest.y) < 60) complete(game, m);
      }
    }

    if (m.type === 'survive') {
      m.data.waveT -= dt;
      const aliveEnemies = game.npcs.filter((n) => n.mission === m.id && !n.dead).length;
      if (m.data.waveT <= 0 && aliveEnemies === 0) {
        m.data.wave++;
        if (m.data.wave > m.need) { complete(game, m); return; }
        if (VAMP.UI) VAMP.UI.notify('Wave ' + m.data.wave + '/' + m.need, m.color);
        const count = 3 + m.data.wave + (m.level / 8 | 0);
        for (let i = 0; i < count; i++) {
          const pos = spot(game, 380, 720);
          const type = m.data.wave >= 3 && Math.random() < 0.4 ? 'hunter' : (Math.random() < 0.5 ? 'swat' : 'gunner');
          const e = VAMP.Npc.create(game.world, type, pos.x, pos.y, { hp: VAMP.Npc.PRESETS[type].hp * (1 + m.level * 0.05) });
          e.mission = m.id; e.aggro = true; e.state = 'chase'; e.hostileToPlayer = true; game.addNPC(e);
        }
        m.data.waveT = 2;
      }
    }

    if (m.type === 'courier') {
      m.timer -= dt;
      const p = game.player; const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
      if (U.dist(px, py, m.data.dest.x, m.data.dest.y) < 50) complete(game, m);
      else if (m.timer <= 0) fail(game, m, 'Out of time.');
    }

    // prune dead marker refs
    m.markers = m.markers.filter((mk) => !mk.ref || !mk.ref.dead || mk.keep);
  }

  function driveTo(n, dest, dt, game) {
    // simple pathfollow
    n.pathT = (n.pathT || 0) - dt;
    if (!n.path || n.pathT <= 0) {
      const path = VAMP.Path.findPath(game.world, n.x, n.y, dest.x, dest.y, 2000);
      n.path = path; n.pathI = 0; n.pathT = 0.5;
    }
    if (n.path && n.path.length) {
      const wp = n.path[Math.min(n.pathI, n.path.length - 1)];
      if (U.dist(n.x, n.y, wp.x, wp.y) < 16) n.pathI++;
      VAMP.Npc.moveTo(n, wp.x, wp.y, dt, game.world, 1.0);
    } else {
      VAMP.Npc.moveTo(n, dest.x, dest.y, dt, game.world, 1.0);
    }
  }

  function complete(game, m) {
    if (m.state !== 'active') return;
    m.state = 'complete';
    game.activeMission = null;
    game.missionsDone = (game.missionsDone || 0) + 1;
    cleanup(game, m, false);
    if (game.player) VAMP.Blood.adjustHumanity(game.player, 0.15, ''); // honoring a pact steadies the soul
    const r = m.reward;
    VAMP.Stats.gainXP(game.player, r.xp);
    game.addMoney(r.money, game.player.x, game.player.y);
    let itemMsg = '';
    if (Math.random() < r.itemChance) {
      const it = VAMP.Inventory.generate(m.level + 2, VAMP.Inventory.rollRarity(m.level, 0.3));
      VAMP.Inventory.addItem(game.player, it);
      itemMsg = ' + ' + it.name;
    }
    if (VAMP.UI) { VAMP.UI.banner('CONTRACT COMPLETE', m.name + '  —  +' + r.xp + ' XP, +$' + r.money + itemMsg, m.color); }
    if (VAMP.Audio) VAMP.Audio.play('win');
    VAMP.bus && VAMP.bus.emit('missionDone', m);
  }

  function fail(game, m, why) {
    if (m.state !== 'active') return;
    m.state = 'failed';
    game.activeMission = null;
    cleanup(game, m, true);
    if (VAMP.UI) VAMP.UI.banner('CONTRACT FAILED', why || '', '#a02030');
    if (VAMP.Audio) VAMP.Audio.play('death');
  }

  function abandon(game) {
    const m = game.activeMission;
    if (!m) return;
    m.state = 'failed';
    game.activeMission = null;
    cleanup(game, m, true);
    if (VAMP.UI) VAMP.UI.notify('Contract abandoned', '#a66');
  }

  function cleanup(game, m, killSpawned) {
    game.crackProgress = 0;
    for (const e of m.spawned) {
      if (!e) continue;
      if (e.ally || e.scripted) { e.dead = true; }
      else if (killSpawned && !e.dead) { e.dead = true; }
    }
    // sweep ALL mission-tagged npcs (including untracked wave/ambush spawns) so none leak
    for (const n of game.npcs) {
      if (n.mission === m.id && !n.dead) {
        if (killSpawned) n.dead = true;        // fail/abandon -> remove
        else n.mission = null;                 // success -> release to normal distance culling
      }
    }
    // collect pickups left behind
    game.pickups = game.pickups.filter((pk) => pk.mission !== m.id);
  }

  VAMP.Missions = { offers, accept, abandon, update, onEvent };
})();
