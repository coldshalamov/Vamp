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

  // ---- AUTHORED CONTRACT CHAINS (the mid-game spine: opt-in storylines that escalate to a climax) ----
  // Each step reuses an existing mission TYPE but with authored framing, gating, and escalating reward.
  // They appear on Boards alongside radiant contracts — the player CHOOSES to pursue them, so a passive
  // player keeps a calm world (the chaos is opt-in). Completing a chain grants a title + a Legend surge.
  const CHAINS = {
    anarch: {
      name: 'The Anarch Uprising', color: '#e0457b', icon: '⚑',
      steps: [
        { name: 'First Blood', type: 'assassinate', gate: 1, desc: 'Put down {name}, a rival lieutenant — announce yourself to the streets.' },
        { name: 'Clear the Den', type: 'cleanse', gate: 3, desc: 'Wipe out the rival crew holed up in the block. Leave no one standing.' },
        { name: 'Bleed the Bank', type: 'heist', gate: 6, desc: 'Crack a blood bank — the Uprising runs on vitae.' },
        { name: 'Hold the Line', type: 'survive', gate: 9, desc: 'They want you dead. Survive the retaliation and break them.' },
        { name: 'Crown of the Streets', type: 'assassinate', gate: 12, climax: true, desc: 'End {name}, Baron of the gangs. Take the crown of the streets.' },
      ],
      title: 'Anarch Warlord',
    },
    camarilla: {
      name: 'The Camarilla Ladder', color: '#6c7bd6', icon: '♛',
      steps: [
        { name: 'A Discreet Favor', type: 'courier', gate: 2, desc: 'Carry a sealed writ to an Elder — quietly, on time.' },
        { name: 'Silence a Witness', type: 'assassinate', gate: 5, desc: 'A mortal saw too much. {name} must not speak.' },
        { name: 'Reclaim the Regalia', type: 'collect', gate: 8, desc: 'Recover the Camarilla relics scattered across the city.' },
        { name: 'Defend the Elysium', type: 'survive', gate: 11, desc: 'Anarchs strike the Elysium. Hold it, and prove your worth.' },
        { name: 'The Prince’s Seat', type: 'assassinate', gate: 14, climax: true, desc: 'Unseat {name} and claim Princedom of the city.' },
      ],
      title: 'Prince of the City',
    },
    inquis: {
      name: 'The Crucible', color: '#ffcf6a', icon: '✝',
      steps: [
        { name: 'Whispers of the Hunt', type: 'cleanse', gate: 4, desc: 'Hunters scout the district. Snuff out their forward cell.' },
        { name: 'Burn the Safehouse', type: 'heist', gate: 8, desc: 'Raid the hunter chapter-house and seize their ledger.' },
        { name: 'The Witch-Hunter', type: 'assassinate', gate: 12, desc: 'Their best blade, {name}, hunts YOU. Hunt them first.' },
        { name: 'The Final Siege', type: 'survive', gate: 15, climax: true, desc: 'The Inquisition moves against you in force. Survive the purge.' },
      ],
      title: 'Scourge of the Inquisition',
    },
  };

  function nextChainStep(game, cid) {
    const cp = game.player.chainProgress || (game.player.chainProgress = {});
    const step = cp[cid] || 0;
    const ch = CHAINS[cid];
    return step < ch.steps.length ? step : -1;
  }

  function offers(game) {
    const D = VAMP.Data;
    const lvl = game.player.level;
    const list = [];
    // STORY chain steps first — the available next beat of each chain whose level gate is met
    for (const cid in CHAINS) {
      const step = nextChainStep(game, cid);
      if (step < 0) continue;                          // chain finished
      if (lvl < CHAINS[cid].steps[step].gate) continue; // not yet earned
      list.push(buildChain(game, cid, step, lvl));
      if (list.length >= 2) break;                     // at most 2 story offers on a board
    }
    // fill the rest with radiant contracts
    const pool = D.MISSION_TYPES.slice();
    while (list.length < 4 && pool.length) {
      const t = pool.splice((Math.random() * pool.length) | 0, 1)[0];
      list.push(build(game, t, lvl));
    }
    return list;
  }

  function buildChain(game, cid, stepIdx, lvl) {
    const ch = CHAINS[cid], s = ch.steps[stepIdx];
    const tdef = VAMP.Data.MISSION_TYPES.find((t) => t.type === s.type) || VAMP.Data.MISSION_TYPES[0];
    const m = build(game, tdef, lvl);
    m.chain = cid; m.chainStep = stepIdx; m.isStory = true; m.climax = !!s.climax;
    m.name = s.name; m.color = ch.color; m.icon = ch.icon;
    m.desc = s.desc.replace('{name}', m.targetName);
    m.modifier = { id: 'none', bonus: 0 };             // story beats stand on their own, no extra constraint
    m.reward.xp = Math.round(m.reward.xp * (1.6 + stepIdx * 0.35));
    m.reward.money = Math.round(m.reward.money * (1.6 + stepIdx * 0.35));
    if (s.climax) m.bossMission = true;                // setup() beefs the target into a real boss
    return m;
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
    // roll an optional APPROACH MODIFIER — a strategic constraint for a fatter purse
    const MM = VAMP.Data.MISSION_MODIFIERS || [{ id: 'none', bonus: 0 }];
    const modifier = MM[(Math.random() * MM.length) | 0];
    return {
      id: MID++, type: t.type, name: t.name, icon: t.icon, color: t.color, desc,
      level: lvl, need: n, progress: 0, state: 'available', reward, targetName: name,
      modifier, markers: [], spawned: [], timeLimit: 0, timer: 0, phase: 0, data: {},
    };
  }

  function accept(game, m) {
    if (game.activeMission) { if (VAMP.UI) VAMP.UI.notify('Finish your current contract first', '#a66'); return false; }
    m.state = 'active';
    game.activeMission = m;
    m._snapInnocent = game.player.bloodState.innocentKills;   // baselines for approach-modifier tracking
    m._violated = false;
    setup(game, m);
    if (VAMP.Progress) VAMP.Progress.markSeen(game.player, 'missions');
    if (VAMP.UI) VAMP.UI.notify('Contract accepted: ' + m.name + (m.modifier && m.modifier.tag ? '  [' + m.modifier.tag + ']' : ''), m.color);
    if (m.modifier && m.modifier.desc && VAMP.UI) VAMP.UI.notify(m.modifier.name + ': ' + m.modifier.desc, m.modifier.color);
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

  function spotNear(game, center, spread, fallbackMin, fallbackMax) {
    for (let i = 0; i < 40; i++) {
      const x = center.x + (Math.random() - 0.5) * spread;
      const y = center.y + (Math.random() - 0.5) * spread;
      if (game.world.isWalkable(x, y)) return { x, y };
    }
    return spot(game, fallbackMin || 240, fallbackMax || 900);
  }

  function objectiveSpot(game, x, y) {
    if (game.world.isWalkable(x, y)) return { x, y };
    if (game.walkableNear) {
      const p = game.walkableNear(x, y);
      if (p && game.world.isWalkable(p.x, p.y)) return p;
    }
    for (let r = 48; r <= 256; r += 32) {
      for (let i = 0; i < 12; i++) {
        const a = (i / 12) * U.TAU;
        const px = x + Math.cos(a) * r, py = y + Math.sin(a) * r;
        if (game.world.isWalkable(px, py)) return { x: px, y: py };
      }
    }
    return null;
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
        if (m.bossMission) { tgt.maxHp = tgt.hp = Math.round((120 + lvl * 8) * 3.4); tgt.boss = true; tgt.wardedMind = true; tgt.r = Math.round(tgt.r * 1.4); tgt.dmgMul = 1.7; tgt.armor = 0.28; tgt.weapon = 'rifle'; }
        game.addNPC(tgt); m.spawned.push(tgt); m.data.target = tgt;
        // guards
        for (let i = 0; i < 2 + (lvl / 10 | 0); i++) { const gp = spotNear(game, pos, 80, 320, 760); const g = VAMP.Npc.create(game.world, 'gunner', gp.x, gp.y, { hp: 60 + lvl * 4 }); g.faction = 'gang'; g.mission = m.id; game.addNPC(g); m.spawned.push(g); }
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
          const gp = spotNear(game, center, 160, 360, 800);
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
        const pos = bank ? (objectiveSpot(game, bank.x, bank.y) || spot(game, 400, 900)) : spot(game, 400, 900);
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
    // FORTIFIED / HIGH-PROFILE: reinforce the objective with extra guards. They start NEUTRAL, so a
    // stealth player can still slip past or pick them off quietly — only a loud approach must fight them.
    // (Skip 'survive' — its own wave gate counts mission-tagged npcs, and static guards would stall it.)
    if (m.modifier && (m.modifier.harder || m.modifier.hot) && m.type !== 'survive') {
      const anchor = m.data.center || m.data.target || (m.markers[0] && m.markers[0].x != null ? m.markers[0] : null) || spot(game, 320, 720);
      const extra = 2 + (lvl / 12 | 0);
      for (let i = 0; i < extra; i++) {
        const gp = { x: anchor.x + (Math.random() - 0.5) * 170, y: anchor.y + (Math.random() - 0.5) * 170 };
        if (!game.world.isWalkable(gp.x, gp.y)) continue;
        const type = Math.random() < 0.5 ? 'gunner' : 'swat';
        const e = VAMP.Npc.create(game.world, type, gp.x, gp.y, { hp: VAMP.Npc.PRESETS[type].hp * (1 + lvl * 0.05) });
        e.mission = m.id; e.faction = type === 'swat' ? 'police' : 'gang';
        game.addNPC(e); m.spawned.push(e);
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

    // approach-modifier bookkeeping: forfeit the bonus the moment its constraint is broken
    if (m.modifier && !m._violated) {
      if (m.modifier.id === 'nokill' && game.player.bloodState.innocentKills > (m._snapInnocent || 0)) { m._violated = true; if (VAMP.UI) VAMP.UI.notify('No-Trace bonus lost — an innocent died', '#a66'); }
      else if (m.modifier.id === 'silent' && game.masquerade.stars > 0) { m._violated = true; if (VAMP.UI) VAMP.UI.notify('Lights-Out bonus lost — you were noticed', '#a66'); }
    }

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
    // approach-modifier bonus: honored constraint => fatter purse
    const bonusMult = (m.modifier && m.modifier.bonus && !m._violated) ? (1 + m.modifier.bonus) : 1;
    const xpR = Math.round(r.xp * bonusMult), moneyR = Math.round(r.money * bonusMult);
    VAMP.Stats.gainXP(game.player, xpR);
    game.addMoney(moneyR, game.player.x, game.player.y);
    let itemMsg = '';
    if (Math.random() < r.itemChance) {
      const it = VAMP.Inventory.generate(m.level + 2, VAMP.Inventory.rollRarity(m.level, 0.3));
      VAMP.Inventory.addItem(game.player, it);
      itemMsg = ' + ' + it.name;
    }
    const bonusMsg = (bonusMult > 1) ? ('  [' + m.modifier.tag + ' +' + Math.round(m.modifier.bonus * 100) + '%]') : '';
    if (VAMP.UI) { VAMP.UI.banner('CONTRACT COMPLETE', m.name + '  —  +' + xpR + ' XP, +$' + moneyR + itemMsg + bonusMsg, m.color); }
    if (VAMP.Audio) VAMP.Audio.play('win');
    // CONTRACT-CHAIN advancement — the opt-in storyline spine that gives the mid-game a destination
    if (m.chain && CHAINS[m.chain]) {
      const cp = game.player.chainProgress || (game.player.chainProgress = {});
      cp[m.chain] = Math.max(cp[m.chain] || 0, m.chainStep + 1);
      const ch = CHAINS[m.chain];
      if (cp[m.chain] >= ch.steps.length) {
        // chain COMPLETE — a felt climax: a title, a Legend surge, and a fat purse
        game.player.chainTitles = game.player.chainTitles || {};
        game.player.chainTitles[m.chain] = ch.title;
        if (VAMP.Legend && VAMP.Legend.add) VAMP.Legend.add(game, 50);
        if (game.addMoney) game.addMoney(Math.round(1500 * (1 + game.player.level * 0.2)), game.player.x, game.player.y);
        if (VAMP.UI) VAMP.UI.banner(ch.title.toUpperCase(), 'You completed ' + ch.name + '. The night remembers your name.', ch.color);
      } else {
        const ns = ch.steps[cp[m.chain]];
        if (VAMP.UI) VAMP.UI.notify(ch.icon + ' ' + ch.name + ' — next: "' + ns.name + '"' + (game.player.level < ns.gate ? ' (reach level ' + ns.gate + ')' : ' — take it from a Board'), ch.color);
      }
    }
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

  VAMP.Missions = { offers, accept, abandon, update, onEvent, CHAINS };
})();
