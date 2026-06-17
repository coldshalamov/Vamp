/* =========================================================================
 * VAMPIRE CITY — entities/npc.js
 * Pedestrians, gangs, police, Second Inquisition hunters, thralls, animals.
 * State-machine AI with pathfinding for pursuers, steering for wanderers.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const C = () => VAMP.Combat;

  const PRESETS = {
    ped:    { hp: 28, speed: 78,  r: 9,  innocent: true,  faction: 'civ',   weapon: null,    armor: 0,    threat: 0 },
    thug:   { hp: 60, speed: 96,  r: 10, innocent: false, faction: 'gang',  weapon: 'bat',   armor: 0.05, threat: 1, hostileOnSight: false },
    gunner: { hp: 55, speed: 92,  r: 10, innocent: false, faction: 'gang',  weapon: 'pistol',armor: 0.05, threat: 1.2, burst: true },
    cop:    { hp: 85, speed: 122, r: 10, innocent: false, faction: 'police',weapon: 'pistol',armor: 0.1,  threat: 1.5 },
    swat:   { hp: 150,speed: 120, r: 11, innocent: false, faction: 'police',weapon: 'rifle', armor: 0.25, threat: 2.4, frontArmor: 0.72 },
    hunter: { hp: 180,speed: 132, r: 11, innocent: false, faction: 'inquis',weapon: 'rifle', armor: 0.3,  threat: 3.2, potent: true },
    elder:  { hp: 420,speed: 120, r: 13, innocent: false, faction: 'inquis',weapon: 'rifle', armor: 0.4,  threat: 5, boss: true, potent: true },
    thrall: { hp: 70, speed: 118, r: 9,  innocent: false, faction: 'player',weapon: 'pistol',armor: 0.1,  threat: 1, ally: true },
    rat:    { hp: 8,  speed: 64,  r: 5,  innocent: true,  faction: 'animal',weapon: null,    armor: 0,    threat: 0, animal: true },
  };

  const SKIN = ['#caa07a', '#a87b53', '#7c5436', '#d8b48c', '#9c6b45'];
  const SHIRT = {
    civ: ['#3b4a66', '#5a4a6a', '#4a5a4a', '#6a4a4a', '#445566', '#705a3a'],
    gang: ['#6a1f2a', '#2a1f6a', '#1f1f1f', '#5a2a1a'],
    police: ['#1a2a55'], inquis: ['#2a2a2a'], player: ['#3a2a55'], animal: ['#5a4a3a'],
  };

  // ---- elite affixes (research top-20 #19) ----
  const ELITE_AFFIXES = {
    brute:    { name: 'Brute', color: '#e0703a', hp: 2.2, dmg: 1.5, r: 1.3, armor: 0.1 },
    swift:    { name: 'Swift', color: '#7ad0ff', hp: 1.4, speed: 1.45 },
    warded:   { name: 'Warded', color: '#9aa0ff', hp: 1.6, armor: 0.35 },
    venomous: { name: 'Venomous', color: '#6fbf3a', hp: 1.4, venom: true },
    vampiric: { name: 'Vampiric', color: '#c0303a', hp: 1.8, vampiric: true },
    juggernaut: { name: 'Juggernaut', color: '#ffd24a', hp: 3.0, dmg: 1.6, r: 1.4, armor: 0.25, speed: 0.85 },
  };
  function makeElite(n, key) {
    const keys = Object.keys(ELITE_AFFIXES);
    key = key || keys[(Math.random() * keys.length) | 0];
    const a = ELITE_AFFIXES[key]; if (!a) return n;
    n.elite = { key, name: a.name, color: a.color };
    n.maxHp = Math.round(n.maxHp * (a.hp || 1)); n.hp = n.maxHp;
    if (a.speed) n.speed *= a.speed;
    if (a.dmg) n.dmgMul = a.dmg;
    if (a.armor) n.armor = (n.armor || 0) + a.armor;
    if (a.r) n.r = Math.round(n.r * a.r);
    if (a.venom) n.eliteVenom = true;
    if (a.vampiric) n.eliteVampiric = true;
    if (key === 'warded' || key === 'juggernaut') n.wardedMind = true;   // can't be feared/cowed — shred armor instead
    n.threat = (n.threat || 1) + 1.5;
    return n;
  }

  let NID = 1;
  function create(world, type, x, y, opts) {
    const pre = PRESETS[type] || PRESETS.ped;
    opts = opts || {};
    const vt = opts.victimType || pickVictim(type);
    const n = {
      id: NID++, type, ...{ ...pre },
      x, y, vx: 0, vy: 0, angle: Math.random() * U.TAU,
      maxHp: pre.hp, hp: pre.hp,
      victimType: vt,
      state: pre.ally ? 'follow' : 'wander',
      path: null, pathI: 0, pathT: 0,
      target: null, aggro: false, hostile: !!pre.hostileOnSight,
      fleeT: 0, mesmerizedT: 0, investigateX: 0, investigateY: 0, investigateT: 0,
      attackCD: 0, walkPhase: Math.random() * 10, alertT: 0,
      status: null, bloodLeft: undefined,
      skin: U.makeRNG ? SKIN[(NID * 7) % SKIN.length] : '#caa',
      shirt: (SHIRT[pre.faction] || SHIRT.civ)[(NID * 5) % (SHIRT[pre.faction] || SHIRT.civ).length],
      mission: opts.mission || null,
      vip: opts.vip || false,
      carrying: opts.carrying || 0,
      name: opts.name || null,
      homeX: x, homeY: y,
      panicReported: false,
    };
    if (opts.hp) { n.maxHp = opts.hp; n.hp = opts.hp; }
    if (opts.speed) n.speed = opts.speed;
    if (n.boss) n.wardedMind = true;   // elders/barons resist mind-affecting will
    if (opts.resist) n.resist = opts.resist;
    if (pre.faction === 'civ') { n._jogger = (n.id % 7 === 0); n._loiter = (n.id % 4 === 0); n.idleT = 0; }   // ambient-life variety
    n.onDamaged = function (dmg, o, game) {
      n.aggro = true;
      n.hitFlashT = (o && o.heavy) ? 0.20 : 0.15;   // #10 — white flash so hits read; heavier hits flash longer
      // unified hit-reaction (stagger): a brief lean away from the blow + interrupts windup
      n.staggerT = Math.max(n.staggerT || 0, (o && o.heavy) ? 0.26 : 0.15);
      n.staggerA = (o && o.angle != null) ? o.angle : n.angle;
      if (n.faction === 'civ' || n.faction === 'animal') { n.state = 'flee'; n.fleeT = 6; reportPanic(n, game); }
      else if (n.state === 'wander' || n.state === 'follow') n.state = n.ally ? 'follow' : 'chase';
    };
    return n;
  }

  function pickVictim(type) {
    if (type === 'rat') return 'rat';
    if (type === 'cop' || type === 'swat') return 'cop';
    if (type === 'hunter' || type === 'elder') return 'hunter';
    if (type === 'thug' || type === 'gunner') return 'thug';
    const pool = ['civilian', 'civilian', 'junkie', 'addict', 'athlete', 'noble'];
    return pool[(Math.random() * pool.length) | 0];
  }

  // playerCaused (default true) controls whether the panic raises the PLAYER's Heat. Civilians who
  // bolt from an AMBIENT fight (a gang war that has nothing to do with you) still scatter and spread
  // fear, but must NOT pin Heat on an idle bystander — that was making the world hunt you for nothing.
  function reportPanic(n, game, playerCaused) {
    if (n.panicReported) return;
    n.panicReported = true;
    if (playerCaused !== false && game && game.masquerade) game.masquerade.witnessedAct(n.x, n.y, 'panic', 1.2);
    // PANIC CONTAGION: fear ripples through the crowd — nearby mortals catch it and scatter too.
    // Bounded (max 4) and marks them reported so it can't cascade into an infinite chain or heat spam.
    let spread = 0;
    for (const m of game.npcs) {
      if (m === n || m.dead || m.downed || m.faction !== 'civ' || m.state === 'flee') continue;
      if (U.dist(m.x, m.y, n.x, n.y) < 130) { m.state = 'flee'; m.fleeT = 3.2; m.panicReported = true; if (++spread >= 4) break; }
    }
  }

  // ---- movement with collision ----
  function moveTo(n, tx, ty, dt, world, speedMul) {
    const a = U.angleTo(n.x, n.y, tx, ty);
    n.angle = U.angleLerp(n.angle, a, U.clamp(dt * 10, 0, 1));
    const sp = n.speed * (speedMul || 1) * C().speedFactor(n);
    n.gait = sp;                        // real locomotion speed (NOT vx/vy, which is knockback)
    n.x += Math.cos(a) * sp * dt;
    n.y += Math.sin(a) * sp * dt;
    n.walkPhase += sp * dt * 0.05;
    collide(n, world);
  }
  function step(n, dt, world) {
    n.x += n.vx * dt; n.y += n.vy * dt;
    n.vx *= 0.86; n.vy *= 0.86;
    collide(n, world);
  }
  function collide(n, world) {
    world.collideCircle(n, n.r);
    if (n._inWater) {
      // bounce back toward home / last safe
      const a = U.angleTo(n.x, n.y, n.homeX, n.homeY);
      n.x += Math.cos(a) * 4; n.y += Math.sin(a) * 4;
    }
    n.x = U.clamp(n.x, world.border * world.TILE, world.w - world.border * world.TILE);
    n.y = U.clamp(n.y, world.border * world.TILE, world.h - world.border * world.TILE);
  }

  function repath(n, world, tx, ty) {
    const path = VAMP.Path.findPath(world, n.x, n.y, tx, ty, 1400);
    if (path && path.length) { n.path = path; n.pathI = Math.min(1, path.length - 1); }
    else n.path = null;
    n.pathT = 0.4 + Math.random() * 0.3;
  }
  function followPath(n, dt, world, speedMul, arrive) {
    if (!n.path) return false;
    const wp = n.path[n.pathI];
    if (!wp) { n.path = null; return false; }
    if (U.dist(n.x, n.y, wp.x, wp.y) < (arrive || 16)) {
      n.pathI++;
      if (n.pathI >= n.path.length) { n.path = null; return true; }
    }
    const t = n.path[Math.min(n.pathI, n.path.length - 1)];
    moveTo(n, t.x, t.y, dt, world, speedMul);
    return false;
  }

  // ---- perception ----
  function canSee(n, p, game) {
    const d = U.dist(n.x, n.y, p.x, p.y);
    let range = (n.faction === 'police' || n.faction === 'inquis') ? 320 : 230;
    // player EXPOSURE (light/shadow, sneaking, sprinting, frenzy) scales how far you read — the
    // heart of the optional stealth game. Computed once per frame on the player (Stealth.exposure).
    const exp = (p.exposure != null) ? p.exposure : 0.85;
    range *= (0.45 + 0.65 * exp);
    if (p.cloaked) range *= 0.25;           // Obfuscate
    if (p.inVehicle) range *= 1.2;
    if (game.timeOfDay && game.timeOfDay.night) range *= 0.92;
    if (d > range) return false;
    // directional vision: an UNALERTED npc only notices you inside a frontal cone, so you can slip
    // behind a mark for a silent takedown. Alerted/hunting npcs (and point-blank range) see all around.
    if (!n.aggro && n.state !== 'chase' && n.state !== 'attack' && n.state !== 'investigate' && d > 58) {
      const off = Math.abs(U.wrapAngle(U.angleTo(n.x, n.y, p.x, p.y) - n.angle));
      if (off > 1.25) return false;
    }
    // occlusion: a building between us blocks the view — duck behind cover to break a pursuer's sight
    // (point-blank is always "sensed"). This is what lets you lose the law GTA-style.
    if (d > 40 && !game.world.sightClear(n.x, n.y, p.x, p.y)) return false;
    return true;
  }

  // ---- combat target resolution (player, enemy npc for thralls/berserkers) ----
  function getCombatTarget(n, game) {
    const p = game.player;
    if (n.ally) {
      const e = game.nearestNPC(n.x, n.y, (m) => !m.dead && !m.ally && (m.faction === 'police' || m.faction === 'gang' || m.faction === 'inquis') && m.aggro, 360)
        || game.nearestNPC(n.x, n.y, (m) => !m.dead && !m.ally && (m.faction === 'police' || m.faction === 'gang' || m.faction === 'inquis'), 240);
      return e ? { x: e.x, y: e.y, isPlayer: false, ref: e } : null;
    }
    if (n.berserkT > 0) {
      const e = game.nearestNPC(n.x, n.y, (m) => m !== n && !m.dead, 320);
      if (e) return { x: e.x, y: e.y, isPlayer: false, ref: e };
    }
    if (n.retaliateAgainst && !n.retaliateAgainst.dead) {
      const e = n.retaliateAgainst;
      return { x: e.x, y: e.y, isPlayer: false, ref: e };
    }
    // CALM BY DEFAULT: only hunt the player if this NPC was deliberately spawned to hunt
    // (responder / hunter / nemesis / boss) OR the player has actually provoked it. An
    // un-provoked loiterer falls through to null -> back to wander, so nobody walks up and
    // attacks you for standing still. This is the single chokepoint for "chaos is opt-in".
    if (!n.hostileToPlayer) return null;
    const tx = p.inVehicle ? p.inVehicle.x : p.x, ty = p.inVehicle ? p.inVehicle.y : p.y;
    return { x: tx, y: ty, isPlayer: true, ref: p };
  }

  // ---- main update ----
  function update(n, dt, game) {
    if (n.dead) return;
    const world = game.world, p = game.player;
    n.gait = Math.max(0, (n.gait || 0) - dt * 6);   // gait decays toward idle each tick
    if (n.staggerT > 0) n.staggerT -= dt;            // hit-reaction lean
    if (n.slumpT > 0 && n.state !== 'fed') n.slumpT = Math.max(0, n.slumpT - dt * 3);
    if (n.attackCD > 0) n.attackCD -= dt;
    if (n.hitFlashT > 0) n.hitFlashT -= dt;   // #10 — hit-flash decay
    if (n.alertT > 0) n.alertT -= dt;
    if (n.berserkT > 0) n.berserkT -= dt;
    if (n.retaliateT > 0) { n.retaliateT -= dt; if (n.retaliateT <= 0) n.retaliateAgainst = null; }
    if (n.retaliateAgainst && n.retaliateAgainst.dead) { n.retaliateAgainst = null; n.retaliateT = 0; }   // target died → stop, don't freeze chasing a corpse
    C().updateStatuses(n, dt, game, false);

    // integrate knockback impulse
    if (Math.abs(n.vx) > 2 || Math.abs(n.vy) > 2) step(n, dt, world);

    // externally controlled NPCs (mission couriers, set-pieces)
    if (n.scripted) return;

    // if anything interrupts the attack flow, drop a pending wind-up so no stale telegraph lingers
    if (n.windupT > 0 && (n.mesmerizedT > 0 || n.staggerT > 0 || C().isDisabled(n) || C().isFeared(n) || (game.player.feeding && game.player.feeding.npc === n))) {
      n.windupT = 0; n._telegraph = null;
    }

    // being fed upon
    if (p.feeding && p.feeding.npc === n) { n.state = 'fed'; return; }

    // UNCONSCIOUS (a non-lethal feed / soft KO): an inert body that can be found, dragged or
    // fed on again. Wakes after a while, dazed, and stumbles off.
    if (n.downed) {
      if (n.carried) return;   // a body slung over your shoulder can't wake up & wander off mid-carry
      if (game.time - (n.downT || 0) > (n.wakeDur || 38)) {
        n.downed = false; n.discovered = false;
        n.state = (n.faction === 'civ' || n.faction === 'animal') ? 'flee' : 'wander';
        n.fleeT = 4; n.panicReported = false; n.mesmerizedT = 1;
      }
      return;
    }

    // mesmerized / disabled
    if (n.mesmerizedT > 0) { n.mesmerizedT -= dt; return; }
    if (C().isDisabled(n)) return;

    // feared -> flee
    if (C().isFeared(n)) { fleeFrom(n, p.x, p.y, dt, world); return; }

    // berserk / retaliation forces combat
    if ((n.berserkT > 0 || n.retaliateAgainst) && n.state !== 'attack' && n.state !== 'chase') n.state = 'chase';

    // GIVE UP THE HUNT: a provoked foe that loses sight of a now-calm player for a while breaks off
    // and returns to its routine — so you can actually shake pursuers (stealth/escape payoff).
    // Committed hunters (responders / Inquisition / a nemesis) and any active Heat keep them coming.
    if (n.hostileToPlayer && !n.responder && !n.nemesis && n.faction !== 'inquis' && (n.berserkT || 0) <= 0 && !n.retaliateAgainst) {
      if (n.seePlayerT === undefined) n.seePlayerT = game.time;   // start the clock once
      if (canSee(n, p, game)) n.seePlayerT = game.time;           // refresh while you're in view
      else if (game.masquerade.stars === 0 && (game.time - n.seePlayerT) > 7 && (game.time - (p.lastAttackT || -99)) > 5 &&
               (n.state === 'chase' || n.state === 'attack' || n.state === 'investigate')) {
        n.hostileToPlayer = false; n.aggro = false; n.state = 'wander'; n.path = null; n.windupT = 0; n._telegraph = null;
      }
    }

    switch (n.state) {
      case 'wander': wander(n, dt, game); break;
      case 'flee': flee(n, dt, game); break;
      case 'chase': chase(n, dt, game); break;
      case 'attack': attack(n, dt, game); break;
      case 'investigate': investigate(n, dt, game); break;
      case 'follow': followMaster(n, dt, game); break;
      case 'fed':
        // feed has ended and the post-feed daze expired (earlier early-returns guarantee this) —
        // release the victim so they don't stay slumped/AI-inert forever
        if (n.faction === 'civ' || n.faction === 'animal') { n.state = 'flee'; n.fleeT = 4; n.panicReported = false; }
        else n.state = 'wander';
        n.path = null; n.slumpT = 0;
        break;
      default: n.state = 'wander';
    }
  }

  function wander(n, dt, game) {
    const world = game.world, p = game.player;
    // perceive threats / become hostile
    if (!n.ally && canSee(n, p, game)) {
      const playerThreat = game.masquerade.stars > 0 || p.bloodState.frenzied || (game.time - (p.lastAttackT || -99) < 1.5);
      if (n.faction === 'police' && (game.masquerade.stars >= 1 || playerThreat)) { n.state = 'chase'; n.aggro = true; n.hostileToPlayer = true; return; }
      if (n.faction === 'inquis') { n.state = 'chase'; n.aggro = true; n.hostileToPlayer = true; return; }
      const gangFriendly = VAMP.Reputation && VAMP.Reputation.gangFriendly(p);
      // gangs stay NEUTRAL until YOU provoke them — the calm sandbox baseline. Key off
      // hostileToPlayer, NOT raw n.aggro: a gang-war loser shot by its RIVAL has n.aggro=true
      // (damageNpcByNpc) but you didn't touch it — keying off aggro made those survivors turn on an
      // idle bystander (the intermittent unprovoked-attack bug). Only a 4+ star alert recruits loiterers.
      if (n.faction === 'gang' && !(gangFriendly && !n.hostileToPlayer) && (n.hostileToPlayer || (game.masquerade.stars >= 4 && U.dist(n.x, n.y, p.x, p.y) < 200))) { n.state = 'chase'; n.hostileToPlayer = true; return; }
      if ((n.faction === 'civ' || n.faction === 'animal') && (p.bloodState.frenzied && U.dist(n.x, n.y, p.x, p.y) < 140)) { n.state = 'flee'; n.fleeT = 5; reportPanic(n, game); return; }
    }
    // idle pause — loiterers linger on the corner; gives the street a varied, unhurried pulse
    if (n.idleT > 0) { n.idleT -= dt; n.gait = 0; return; }
    n.pathT -= dt;
    if (!n.path || n.pathT <= 0) {
      // civilians glance for danger as they set off — a fight in view sends them running (and panics
      // the crowd). Throttled to the ~2Hz repath tick so it stays cheap.
      if (n.faction === 'civ' && !n.panicReported) {
        for (const m of game.npcs) {
          if (m === n || m.dead || m.faction === 'civ' || m.faction === 'animal') continue;
          if (m.aggro && (m.state === 'chase' || m.state === 'attack') && U.dist(m.x, m.y, n.x, n.y) < 155) { n.state = 'flee'; n.fleeT = 4; reportPanic(n, game, m.hostileToPlayer === true); return; }
        }
      }
      // civilians COMMUTE toward distant goals (a living street of people going places); others mill
      const reach = (n.faction === 'civ') ? U.range(220, 720) : U.range(60, 200);
      const ang = Math.random() * U.TAU;
      const tx = n.x + Math.cos(ang) * reach, ty = n.y + Math.sin(ang) * reach;
      if (world.isWalkable(tx, ty)) { repath(n, world, tx, ty); if (n._loiter && Math.random() < 0.4) n.idleT = U.range(0.8, 2.6); }
      else n.pathT = 0.5;
    }
    if (n.path) followPath(n, dt, world, n._jogger ? 0.9 : 0.5);
  }

  function flee(n, dt, game) {
    n.fleeT -= dt;
    const p = game.player;
    fleeFrom(n, p.x, p.y, dt, game.world);
    if (n.fleeT <= 0 && U.dist(n.x, n.y, p.x, p.y) > 260) {
      if (n._fledAway) { n.dead = true; n.deathT = -999; return; }   // a scarred nemesis truly escapes into the night (immediate cull, no corpse)
      n.state = 'wander'; n.path = null; n.panicReported = false;
    }
  }
  function fleeFrom(n, fx, fy, dt, world) {
    const a = U.angleTo(fx, fy, n.x, n.y); // away
    const tx = n.x + Math.cos(a) * 80, ty = n.y + Math.sin(a) * 80;
    moveTo(n, tx, ty, dt, world, 1.25);
  }

  function chase(n, dt, game) {
    const world = game.world, p = game.player;
    const tgt = getCombatTarget(n, game);
    if (!tgt) { n.state = n.ally ? 'follow' : 'wander'; return; }
    // MORALE: a lone, badly-wounded ganger loses its nerve and bolts (cops/Inquisition/elites hold).
    if (!n.ally && !n.boss && !n.elite && !n.nemesis && n.faction === 'gang' && n.hp < n.maxHp * 0.25) {
      let allies = 0;
      for (const m of game.npcs) { if (m !== n && !m.dead && m.faction === 'gang' && m.aggro && U.dist(m.x, m.y, n.x, n.y) < 170) { if (++allies >= 2) break; } }
      if (allies < 2) { n.state = 'flee'; n.fleeT = 5; n.hostileToPlayer = false; n.aggro = false; return; }
    }
    const d = U.dist(n.x, n.y, tgt.x, tgt.y);
    // track line of sight: remember WHERE we last saw the player so losing them means searching that
    // spot, not psychically tracking their live position. This is what makes breaking LOS / fleeing work.
    const sees = tgt.isPlayer ? canSee(n, p, game) : true;
    if (sees && tgt.isPlayer) { n.seePlayerT = game.time; n.lastSeenX = tgt.x; n.lastSeenY = tgt.y; }
    if (tgt.isPlayer && !n.ally && (n.berserkT || 0) <= 0 && !n.retaliateAgainst && !sees && n.lastSeenX !== undefined && (game.time - (n.seePlayerT || 0)) > 2.0) {
      n.investigateX = n.lastSeenX; n.investigateY = n.lastSeenY; n.investigateT = 6; n.state = 'investigate'; return;
    }
    const atkRange = n.sniper ? 470 : n.weapon === 'pistol' ? 230 : n.weapon === 'rifle' ? 320 : 26;
    if (d < atkRange && (sees || d < 34)) { n.state = 'attack'; return; }
    // FLANK: melee attackers fan out around the target and converge from different angles instead of
    // conga-lining into one spot — groups feel coordinated.
    let aimX = tgt.x, aimY = tgt.y;
    if (tgt.isPlayer && !n.weapon && d > 55 && d < 240) {
      const side = ((n.id % 2) ? 1 : -1) * (0.55 + (n.id % 3) * 0.22);
      const ang = U.angleTo(tgt.x, tgt.y, n.x, n.y) + side;
      aimX = tgt.x + Math.cos(ang) * 44; aimY = tgt.y + Math.sin(ang) * 44;
    }
    n.pathT -= dt;
    if (!n.path || n.pathT <= 0) repath(n, world, aimX, aimY);
    if (!n.path) moveTo(n, aimX, aimY, dt, world, 1);
    else followPath(n, dt, world, 1, 14);
  }

  function attack(n, dt, game) {
    const tgt = getCombatTarget(n, game);
    if (!tgt) { n.state = n.ally ? 'follow' : 'wander'; n.windupT = 0; n._telegraph = null; return; }
    const d = U.dist(n.x, n.y, tgt.x, tgt.y);
    n.angle = U.angleLerp(n.angle, U.angleTo(n.x, n.y, tgt.x, tgt.y), U.clamp(dt * 12, 0, 1));
    const atkRange = n.sniper ? 490 : n.weapon === 'pistol' ? 250 : n.weapon === 'rifle' ? 340 : 30;
    if (d > atkRange * 1.1) { n.state = 'chase'; n.windupT = 0; n._telegraph = null; return; }
    // a MARKSMAN holds the line at long range — backs away if you close the gap
    if (n.sniper && d < 300) { const a = U.angleTo(tgt.x, tgt.y, n.x, n.y); moveTo(n, n.x + Math.cos(a) * 50, n.y + Math.sin(a) * 50, dt, game.world, 1.05); }
    // resolve an in-progress wind-up (telegraph) -> fire at the TELEGRAPHED spot so it's dodgeable
    if (n.windupT > 0) {
      n.windupT -= dt;
      if (n.windupT <= 0) { doAttack(n, game, { x: n._telegraph.x, y: n._telegraph.y, isPlayer: tgt.isPlayer, ref: tgt.ref }); n._telegraph = null; }
      return;
    }
    // kite (ranged) / close (melee)
    if (n.weapon && d < atkRange * 0.5) { const a = U.angleTo(tgt.x, tgt.y, n.x, n.y); moveTo(n, n.x + Math.cos(a) * 40, n.y + Math.sin(a) * 40, dt, game.world, 0.8); }
    else if (!n.weapon && d > 30) { moveTo(n, tgt.x, tgt.y, dt, game.world, 1); }
    // begin a wind-up when the weapon is ready
    if (n.attackCD <= 0) {
      const rangedAtPlayer = n.weapon && tgt.isPlayer && !n.ally;
      if (rangedAtPlayer && (game._shootersThisTick || 0) >= 3) {
        // incoming-fire cap: too many already opening up this frame — kite instead of joining the wall
        const a = U.angleTo(tgt.x, tgt.y, n.x, n.y); moveTo(n, n.x + Math.cos(a) * 30, n.y + Math.sin(a) * 30, dt, game.world, 0.7);
        return;
      }
      if (rangedAtPlayer) game._shootersThisTick = (game._shootersThisTick || 0) + 1;
      n.windupT = (n.sniper ? 0.7 : n.weapon === 'rifle' ? 0.35 : n.weapon === 'pistol' ? 0.28 : 0.4) * (n.elite ? 1.25 : 1);
      n._telegraph = { x: tgt.x, y: tgt.y, melee: !n.weapon };
    }
  }

  function doAttack(n, game, tgt) {
    const p = game.player;
    // vs another NPC (thrall, berserk, gang war): instant hitscan
    if (!tgt.isPlayer) {
      const ref = tgt.ref;
      if (!ref || ref.dead) { n.state = n.ally ? 'follow' : 'wander'; return; }
      const dmg = n.weapon === 'rifle' ? 14 : n.weapon === 'pistol' ? 9 : (n.weapon === 'bat' ? 12 : 7);
      C().damageNpcByNpc(game, n, ref, dmg, { knockback: 40, angle: U.angleTo(n.x, n.y, ref.x, ref.y) });
      if (VAMP.FX) { if (n.weapon === 'pistol' || n.weapon === 'rifle') VAMP.FX.beam(n.x, n.y, ref.x, ref.y, '#ffe9a8'); else VAMP.FX.hit(ref.x, ref.y, '#d33'); }
      if ((n.weapon === 'pistol' || n.weapon === 'rifle') && VAMP.Audio && Math.random() < 0.5) VAMP.Audio.play('gun');
      n.attackCD = n.weapon ? 0.75 : 0.85;
      return;
    }
    // vs player
    if (p.majestyT > 0) { n.attackCD = 0.5; if (VAMP.FX && Math.random() < 0.1) VAMP.FX.number(n.x, n.y - 16, '...', '#ffd24a', { small: true }); return; }
    const tx = tgt.x, ty = tgt.y;
    const dmgMul = n.dmgMul || 1;
    if (n.weapon === 'pistol' || n.weapon === 'rifle') {
      const a = U.angleTo(n.x, n.y, tx, ty) + (Math.random() - 0.5) * 0.12;
      const spd = n.weapon === 'rifle' ? 520 : 440;
      game.spawnProjectile({
        x: n.x + Math.cos(a) * (n.r + 6), y: n.y + Math.sin(a) * (n.r + 6),
        vx: Math.cos(a) * spd, vy: Math.sin(a) * spd,
        owner: 'npc', dmg: (n.weapon === 'rifle' ? 16 : 10) * dmgMul, r: 3.5,
        color: n.elite ? n.elite.color : (n.faction === 'inquis' ? '#ffcf6a' : '#ffe'), life: 1.1, kind: 'bullet',
        status: n.eliteVenom ? { kind: 'poison', dur: 4, dps: 4 } : null,
      });
      // burst-fire signature: 3 rapid shots then a long reload — a readable "incoming burst, dodge!" rhythm
      if (n.burst) {
        n.burstN = (n.burstN || 0) + 1;
        if (n.burstN < 3) n.attackCD = 0.13;
        else { n.burstN = 0; n.attackCD = 1.5; }
      } else n.attackCD = n.weapon === 'rifle' ? 0.9 : 0.7;
      if (VAMP.Audio) VAMP.Audio.play('gun');
      if (game.masquerade) game.masquerade.gunfire(n.x, n.y);
    } else {
      if (U.dist(n.x, n.y, tx, ty) < 34 && !p.inVehicle) {
        C().damagePlayer(game, (n.weapon === 'bat' ? 12 : 8) * dmgMul, {});
        if (n.eliteVenom) C().applyStatus(p, 'poison', { dur: 4, dps: 4 });
        if (n.eliteVampiric && !C().hasStatus(n, 'burn')) n.hp = Math.min(n.maxHp, n.hp + 6);   // burn cauterizes the lifesteal
        if (VAMP.FX) VAMP.FX.hit(p.x, p.y, '#d33');
      } else if (p.inVehicle && U.dist(n.x, n.y, tx, ty) < 36) {
        p.inVehicle.hp -= 6 * dmgMul;
      }
      n.attackCD = 0.8;
    }
  }

  function investigate(n, dt, game) {
    n.investigateT -= dt;
    moveTo(n, n.investigateX, n.investigateY, dt, game.world, 0.9);
    if (canSee(n, game.player, game) && !game.player.cloaked) { n.state = 'chase'; return; }
    if (n.investigateT <= 0 || U.dist(n.x, n.y, n.investigateX, n.investigateY) < 24) n.state = 'wander';
  }

  function followMaster(n, dt, game) {
    const p = game.player;
    // find an enemy to attack
    const enemy = game.nearestNPC(n.x, n.y, (m) => !m.dead && m.aggro && m.faction !== 'player' && (m.faction === 'police' || m.faction === 'gang' || m.faction === 'inquis'), 280);
    if (enemy) { n.target = enemy; n.state = 'chase'; return; }
    const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
    const d = U.dist(n.x, n.y, px, py);
    if (d > 70) {
      n.pathT -= dt;
      if (!n.path || n.pathT <= 0) repath(n, game.world, px, py);
      if (!n.path) moveTo(n, px, py, dt, game.world, 1.1);
      else followPath(n, dt, game.world, 1.1, 18);
    }
  }

  // ---- rendering (LOD: corpse / far blob / near baked-sprite / full live-limbs) ----
  function spriteOf(n) { return VAMP.Sprites.get(n.type, n.ally ? 'player' : n.faction, n.skin, n.shirt, n.r); }

  function render(n, ctx, game) {
    const cam = game.cam, r = n.r;
    if (n.dead) return renderCorpse(n, ctx, game);
    if (n.downed) return renderDowned(n, ctx, game);

    const px = cam.zoom * r;
    const dToPlayer = game._pcx !== undefined ? Math.abs(n.x - game._pcx) + Math.abs(n.y - game._pcy) : 9999;
    let tier;
    if (px < 7) tier = 'far';
    else if (n.boss || n.elite || n.aggro || dToPlayer < 360 || game._feedTarget === n) tier = 'full';
    else tier = 'near';

    // feeding-victim slump (one NPC at a time) — overrides the gait pose
    if (n.state === 'fed' && VAMP.Sprites) {
      n.slumpT = Math.min(1, (n.slumpT || 0) + 0.05);
      ctx.save(); ctx.translate(n.x, n.y);
      ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.beginPath(); ctx.ellipse(0, r * 0.5, r * 1.1, r * 0.55, 0, 0, U.TAU); ctx.fill();
      ctx.rotate(n.angle);
      ctx.translate(n.slumpT * r * 0.2, 0);
      ctx.transform(1, 0, n.slumpT * 0.4, 1 - n.slumpT * 0.25, 0, 0);   // sag toward feeder
      const sp = spriteOf(n); ctx.globalAlpha = 0.95; ctx.drawImage(sp.canvas, -sp.cx, -sp.cy); ctx.globalAlpha = 1;
      ctx.restore();
      ctx.fillStyle = 'rgba(255,47,110,' + (0.2 + 0.15 * Math.sin(game.time * 8)) + ')';
      ctx.beginPath(); ctx.arc(n.x + Math.cos(n.angle) * r * 0.4, n.y + Math.sin(n.angle) * r * 0.4, 2.5, 0, U.TAU); ctx.fill();
      drawOverlays(n, ctx, game);
      return;
    }

    ctx.save();
    ctx.translate(n.x, n.y);
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.beginPath(); ctx.ellipse(0, r * 0.5, r * 1.1, r * 0.55, 0, 0, U.TAU); ctx.fill();

    // FAR: one faction-coloured blob, no rotation/anim/overlays
    if (tier === 'far') {
      ctx.fillStyle = n.hitFlashT > 0 ? '#fff' : (n.ally ? '#3a6a4a' : n.shirt);
      ctx.beginPath(); ctx.ellipse(0, 0, r, r * 0.8, 0, 0, U.TAU); ctx.fill();
      ctx.restore();
      return;
    }

    // animation state (shared near + full)
    const amp = (n.gait > 4) ? (n.gait > n.speed * 1.05 ? 3.0 : 1.8) : 0;   // run vs amble vs idle
    const sway = (amp === 0) ? Math.sin(game.time * 2 + n.id) * 0.04 : 0;
    const stag = n.staggerT > 0 ? n.staggerT / 0.22 : 0;
    const aiming = (n.state === 'attack' && n.weapon);

    ctx.rotate(n.angle + sway);
    if (stag > 0) ctx.translate(-Math.cos(n.staggerA - n.angle) * stag * 5, 0);   // lean away from blow (a real flinch, not a twitch)
    else if (aiming) ctx.translate(r * 0.12, 0);
    if (n.hitFlashT > 0) { const pop = 1 + Math.min(0.18, n.hitFlashT * 0.9); ctx.scale(pop, pop); }   // brief sprite "pop" sells the impact
    const sp = spriteOf(n);
    const sheetKey = n.faction === 'gang' ? 'npc_gang'
      : n.faction === 'police' ? 'npc_cop'
      : n.faction === 'inquis' || n.faction === 'hunter' ? 'npc_hunter'
      : n.ally ? 'npc_thrall'
      : n.type === 'rat' ? 'rat'
      : 'npc_civilian_walk';
    const useSpr = VAMP.ArtFlags && VAMP.ArtFlags.useSpriter && VAMP.Spriter && VAMP.Spriter.has(sheetKey) && tier !== 'far';
    const useBmp = !useSpr && VAMP.ArtFlags && VAMP.ArtFlags.useBitmapNPCs && VAMP.Assets.ready && VAMP.Assets.has('npc_civilian')
      && (n.type === 'ped' || n.faction === 'civ') && tier !== 'far';

    if (useSpr || useBmp) {
      const bob = amp ? Math.sin(n.walkPhase) * 0.5 : 0;
      const sz = r * (n.type === 'rat' ? 1.8 : 2.4);
      if (n.hitFlashT > 0) { ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = 0.85; }
      if (useSpr) {
        const dir = VAMP.Spriter.dirFromAngle(n.angle);
        const frame = amp ? VAMP.Spriter.walkFrame(game.time + n.id, 8, sheetKey === 'rat' ? 1 : 2) : 0;
        VAMP.Spriter.draw(ctx, sheetKey, 0, -bob, {
          dir, frame, w: sz, h: sz * 1.1, ax: 0.5, ay: 0.5, tint: n.shirt, smooth: false,
          fallbackKey: 'npc_civilian',
        });
      } else {
        VAMP.Assets.drawKey(ctx, 'npc_civilian', 0, -bob, { w: sz, h: sz * 1.1, ax: 0.5, ay: 0.5, tint: n.shirt });
      }
      ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
      ctx.restore();
      drawOverlays(n, ctx, game);
      return;
    }

    if (tier === 'near') {
      const bob = amp ? Math.sin(n.walkPhase) * 0.5 : 0;
      const sq = amp ? 1 + Math.sin(n.walkPhase * 2) * 0.05 : 1;
      ctx.scale(1, sq);
      ctx.drawImage(sp.canvas, -sp.cx, -sp.cy - bob);
      if (n.hitFlashT > 0) { ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = 0.8; ctx.drawImage(sp.canvas, -sp.cx, -sp.cy - bob); ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1; }
      ctx.restore();
      drawOverlays(n, ctx, game);
      return;
    }

    // FULL: striding legs + baked body + live gun arm + flash
    const sA = amp ? Math.sin(n.walkPhase) * amp : 0;
    const sB = amp ? Math.sin(n.walkPhase + Math.PI) * amp : 0;
    ctx.fillStyle = '#181018';
    ctx.beginPath(); ctx.ellipse(sA, -r * 0.45, r * 0.3, r * 0.2, 0, 0, U.TAU); ctx.fill();
    ctx.beginPath(); ctx.ellipse(sB, r * 0.45, r * 0.3, r * 0.2, 0, 0, U.TAU); ctx.fill();
    ctx.drawImage(sp.canvas, -sp.cx, -sp.cy);
    if (n.hitFlashT > 0) { ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = 0.85; ctx.drawImage(sp.canvas, -sp.cx, -sp.cy); ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1; }
    // live gun arm that extends when aiming (reads as "about to shoot")
    if (n.weapon === 'pistol' || n.weapon === 'rifle') {
      const ext = aiming ? r * 0.5 : 0;
      ctx.strokeStyle = '#15151a'; ctx.lineWidth = r * 0.3; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(r * 0.2, r * 0.25); ctx.lineTo(r * 0.55 + ext, r * 0.14); ctx.stroke();
      ctx.fillStyle = '#111'; ctx.fillRect(r * 0.55 + ext, -1.5, n.weapon === 'rifle' ? 13 : 7, 3);
      if (n.windupT > 0 && n.windupT < 0.08) { ctx.fillStyle = '#ffe9a8'; ctx.beginPath(); ctx.arc(r * 0.55 + ext + (n.weapon === 'rifle' ? 13 : 7), r * 0.14, 3, 0, U.TAU); ctx.fill(); }
    } else if (n.weapon === 'bat') {
      const sw = n.windupT > 0 ? (1 - n.windupT / 0.4) * 1.2 - 0.6 : 0;
      ctx.strokeStyle = '#5a3a1a'; ctx.lineWidth = 3; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(r * 0.3, 0); ctx.lineTo(r * 0.3 + Math.cos(sw) * 12, Math.sin(sw) * 12); ctx.stroke();
    }
    ctx.restore();
    drawOverlays(n, ctx, game);
  }

  // toppling corpse + the moment-of-death blood pool (replaces the static ellipse)
  function renderCorpse(n, ctx, game) {
    const age = game.time - (n.deathT || game.time);
    const settle = (U.ease ? U.ease.outCubic(Math.min(1, age / 0.45)) : Math.min(1, age / 0.45));
    if (!n._pooled) { n._pooled = true; if (VAMP.FX) VAMP.FX.bloodPool(n.x, n.y, n.r); if (game.cam) game.cam.punch(0.04); }
    ctx.save(); ctx.translate(n.x, n.y);
    ctx.fillStyle = 'rgba(0,0,0,0.25)'; ctx.beginPath(); ctx.ellipse(0, n.r * 0.4, n.r * 1.2, n.r * 0.5, 0, 0, U.TAU); ctx.fill();
    ctx.rotate(n.angle);
    ctx.globalAlpha = 0.9;
    ctx.translate(0, settle * n.r * 0.3);
    ctx.transform(1, 0, settle * 0.65, 1 - settle * 0.55, 0, 0);   // shear + squash = falling over
    const sp = spriteOf(n);
    ctx.drawImage(sp.canvas, -sp.cx, -sp.cy);
    ctx.globalAlpha = 1; ctx.restore();
  }

  // unconscious body: slumped on the ground (alive — faint breathing, no blood pool). A "Z" tells
  // it apart from a corpse, and a soft marker shows it's draggable.
  function renderDowned(n, ctx, game) {
    const breathe = 1 + Math.sin(game.time * 2 + n.id) * 0.03;
    ctx.save(); ctx.translate(n.x, n.y);
    ctx.fillStyle = 'rgba(0,0,0,0.22)'; ctx.beginPath(); ctx.ellipse(0, n.r * 0.4, n.r * 1.2, n.r * 0.5, 0, 0, U.TAU); ctx.fill();
    ctx.rotate(n.angle);
    ctx.globalAlpha = 0.92;
    ctx.translate(0, n.r * 0.28);
    ctx.transform(1, 0, 0.6, 0.5 * breathe, 0, 0);   // squashed flat = lying down
    const sp = spriteOf(n);
    ctx.drawImage(sp.canvas, -sp.cx, -sp.cy);
    ctx.globalAlpha = 1; ctx.restore();
    // "zzz" so it reads as out-cold, not dead
    ctx.fillStyle = 'rgba(150,180,220,0.7)'; ctx.font = 'italic bold 9px Verdana'; ctx.textAlign = 'center';
    ctx.fillText('z', n.x + n.r * 0.9, n.y - n.r - 2 + Math.sin(game.time * 3) * 1.5);
    ctx.textAlign = 'left';
    if (n.carried) return;
    if (n.hidden) { ctx.fillStyle = 'rgba(120,200,150,0.5)'; ctx.font = '8px Verdana'; ctx.textAlign = 'center'; ctx.fillText('hidden', n.x, n.y + n.r + 8); ctx.textAlign = 'left'; }
  }

  // markers / telegraph / elite ring / healthbar — world-space, skipped at far tier
  function drawOverlays(n, ctx, game) {
    // attack telegraph (wind-up tell) — gives the player time to react/dodge
    if (n.windupT > 0 && n._telegraph) {
      const tel = n._telegraph;
      const pulse = 0.4 + 0.5 * Math.abs(Math.sin(game.time * 18));
      ctx.globalAlpha = pulse;
      ctx.strokeStyle = n.elite ? '#ff3030' : '#ff5a5a';
      if (tel.melee) {
        ctx.lineWidth = 3;
        ctx.beginPath(); ctx.arc(n.x, n.y, n.r + 14, n.angle - 0.7, n.angle + 0.7); ctx.stroke();
      } else {
        ctx.lineWidth = 2;
        ctx.setLineDash([6, 6]);
        ctx.beginPath(); ctx.moveTo(n.x, n.y); ctx.lineTo(tel.x, tel.y); ctx.stroke();
        ctx.setLineDash([]);
      }
      ctx.globalAlpha = 1;
    }

    // elite / boss / nemesis ring + tag
    if (n.elite || n.boss || n.nemesis) {
      const col = n.elite ? n.elite.color : (n.boss ? '#ff3030' : '#c060ff');
      const pulse = 4 + Math.sin(game.time * (n.boss ? 7 : 5)) * (n.boss ? 2.5 : 1.5);
      if (VAMP.Assets && VAMP.Assets.glowTinted) {
        ctx.save(); ctx.globalCompositeOperation = 'lighter';
        ctx.globalAlpha = 0.18 + 0.08 * Math.sin(game.time * 6);
        const gr = (n.r + pulse + 8) * 2;
        ctx.drawImage(VAMP.Assets.glowTinted(col), n.x - gr / 2, n.y - gr / 2, gr, gr);
        ctx.restore();
      }
      ctx.strokeStyle = col; ctx.lineWidth = n.boss ? 2.5 : 2;
      ctx.globalAlpha = 0.85;
      ctx.beginPath(); ctx.arc(n.x, n.y, n.r + pulse, 0, U.TAU); ctx.stroke();
      ctx.globalAlpha = 1;
      if (n.elite) {
        ctx.fillStyle = col; ctx.font = 'bold 8px Verdana'; ctx.textAlign = 'center';
        ctx.fillText(n.elite.name, n.x, n.y - n.r - 16); ctx.textAlign = 'left';
      } else if (n.boss) {
        ctx.fillStyle = '#ff6060'; ctx.font = 'bold 9px Verdana'; ctx.textAlign = 'center';
        ctx.fillText('BOSS', n.x, n.y - n.r - 16); ctx.textAlign = 'left';
      }
    }

    // state markers (small, above head, not rotated)
    const my = n.y - n.r - 10;
    if (n.faction === 'police') drawBadge(ctx, n.x, my, '#5a8cff');
    else if (n.faction === 'inquis') drawBadge(ctx, n.x, my, '#ff5a5a');
    else if (n.ally) drawBadge(ctx, n.x, my, '#5aff8c');
    if (n.mesmerizedT > 0) floatIcon(ctx, n.x, my, '#c9f', '◉');
    else if (C().isFeared(n)) floatIcon(ctx, n.x, my, '#c7f', '!');
    else if (n.state === 'flee') floatIcon(ctx, n.x, my, '#fc6', '!');
    else if (n.aggro && (n.state === 'chase' || n.state === 'attack')) floatIcon(ctx, n.x, my, '#f55', '▲');
    if (n.vip) floatIcon(ctx, n.x, my - 8, '#ffd24a', '★');
    if (game._feedTarget === n) { const pl = 0.6 + 0.4 * Math.sin(game.time * 6); ctx.globalAlpha = pl; floatIcon(ctx, n.x, my, '#ff6a8a', '♥'); ctx.globalAlpha = 1; }
    // prey legible BEFORE contact: a faint heart over feedable civilians nearby (not just the 52px target)
    else if ((n.faction === 'civ' || n.faction === 'animal') && !n.aggro && n.state !== 'flee' && (n.mesmerizedT || 0) <= 0 && game._pcx !== undefined && !(game.player && game.player.feeding)
             && (Math.abs(n.x - game._pcx) + Math.abs(n.y - game._pcy)) < 180) {
      ctx.globalAlpha = 0.26; floatIcon(ctx, n.x, my, '#ff6a8a', '♥'); ctx.globalAlpha = 1;
    }

    // health bar when damaged (#13 — chunkier for elites/bosses, boss gets the top bar too)
    if (n.hp < n.maxHp && !n.dead) {
      const isBoss = n.boss;
      const isElite = !!n.elite;
      const bw = n.r * (isBoss ? 3.4 : isElite ? 2.8 : 2.2);
      const bh = isBoss ? 5 : (isElite ? 4 : 3);
      const by = n.y - n.r - (isBoss ? 10 : 6);
      ctx.fillStyle = 'rgba(0,0,0,0.65)'; ctx.fillRect(n.x - bw / 2, by, bw, bh);
      const col = n.ally ? '#5aff8c' : (isBoss ? '#ff3030' : isElite ? '#ff7a30' : (n.faction === 'civ' ? '#cccccc' : '#ff5a5a'));
      ctx.fillStyle = col; ctx.fillRect(n.x - bw / 2, by, bw * (n.hp / n.maxHp), bh);
      if (isBoss || isElite) { ctx.strokeStyle = 'rgba(0,0,0,0.8)'; ctx.lineWidth = 1; ctx.strokeRect(n.x - bw / 2 + 0.5, by + 0.5, bw - 1, bh - 1); }
    }
  }
  function drawBadge(ctx, x, y, color) {
    ctx.fillStyle = color; ctx.beginPath(); ctx.arc(x, y, 2.4, 0, U.TAU); ctx.fill();
  }
  function floatIcon(ctx, x, y, color, ch) {
    ctx.fillStyle = color; ctx.font = 'bold 11px monospace'; ctx.textAlign = 'center';
    ctx.fillText(ch, x, y - 2); ctx.textAlign = 'left';
  }

  VAMP.Npc = { create, update, render, PRESETS, moveTo, canSee, makeElite, ELITE_AFFIXES };
})();
