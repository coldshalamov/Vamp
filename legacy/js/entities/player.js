/* =========================================================================
 * VAMPIRE CITY — entities/player.js
 * The vampire: on-foot & driving control, aim, claw/weapon attack, feeding,
 * ability hotbar, buffs, sprint (blood-fueled), stealth, regen, rendering.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const In = () => VAMP.Input;
  const C = () => VAMP.Combat;
  const POUNCE_COST = 8, POUNCE_RANGE = 220, POUNCE_CD = 1.4;

  function newPlayer(world, spawn) {
    const p = {
      x: spawn.x, y: spawn.y, vx: 0, vy: 0, angle: 0, r: 10,
      level: 1, xp: 0, xpTotal: 0,
      attributes: VAMP.Stats.newAttributes(),
      attrPoints: 0, skillPoints: 0,
      powers: {}, slots: [null, null, null, null, null, null, null, null],
      cooldowns: {}, toggles: {}, buffs: [],
      treeNodes: {},               // allocated skill-tree node ids -> rank
      bloodState: VAMP.Blood.newBloodState(),
      money: 50,
      inventory: [], equipment: { weapon: null, charm1: null, charm2: null, attire: null },
      stats: { castsTotal: 0, distance: 0, hijacks: 0 },
      inVehicle: null, feeding: null, holdingFeed: false,
      aimMode: 'move', freeAiming: false,   // GTA-style keyboard facing by default; hold RMB / toggle V for mouse free-aim
      cloaked: false, invuln: 0, ward: 0,
      sprinting: false, attackCD: 0, interactCD: 0,
      lastAttackT: -99, lastHurtT: -99,
      facing: 0,
      dead: false,
      flags: {},
      hp: undefined, blood: undefined,
    };
    p.addBuff = (b) => addBuff(p, b);
    p.hasBuff = (id) => p.buffs.some((x) => x.id === id);
    VAMP.Stats.recompute(p);
    p.hp = p.derived.maxHP; p.blood = p.derived.maxBlood;
    // starting kit: claws known
    p.equipment.weapon = { kind: 'claws', name: 'Vampiric Claws', dmgMult: 1, rangeBonus: 0, rarity: 'innate', auto: false };
    return p;
  }

  function addBuff(p, b) {
    const existing = p.buffs.find((x) => x.id === b.id);
    if (existing) { existing.dur = Math.max(existing.dur, b.dur); existing._max = Math.max(existing._max || 0, b.dur); }
    else { p.buffs.push({ ...b, _t: 0, _max: b.dur }); if (b.onApply) b.onApply(p); }   // _max drives the HUD countdown pie
    VAMP.Stats.recompute(p);
  }
  function updateBuffs(p, dt) {
    let changed = false;
    for (let i = p.buffs.length - 1; i >= 0; i--) {
      const b = p.buffs[i];
      if (b.dur === Infinity) continue;
      b.dur -= dt;
      if (b.dur <= 0) { if (b.onExpire) b.onExpire(p); p.buffs.splice(i, 1); changed = true; }
    }
    if (changed) VAMP.Stats.recompute(p);
  }

  function update(p, dt, game) {
    if (p.dead) return;
    const input = In();
    if (p.invuln > 0) p.invuln -= dt;
    if (p.majestyT > 0) p.majestyT -= dt;
    if (p.attackCD > 0) p.attackCD -= dt;
    if (p.interactCD > 0) p.interactCD -= dt;
    if (p.pounceCD > 0) p.pounceCD -= dt;
    if (p.dashCD > 0) p.dashCD -= dt;       // dodge cooldown
    if (p.swingT > 0) p.swingT -= dt;       // claw-swing animation timer
    if (p.ward > 0 && !p.hasBuff('blood_ward')) p.ward = Math.max(0, p.ward - dt * 4);

    // AIM MODEL (GTA 1/2-style): you face the way you MOVE by default — the weapon points where
    // you run, so the game is fully playable on the keyboard alone. HOLD RIGHT-MOUSE (or flip the
    // mouse-aim toggle, V) to free-aim at the cursor — that's how you run one way and shoot another
    // (e.g. firing backward while fleeing). aimX/aimY always track the cursor for the HUD reticle.
    const mw = game.cam.screenToWorld(input.mouse.x, input.mouse.y);
    p.aimX = mw.x; p.aimY = mw.y;
    p.freeAiming = input.mouse.rdown || p.aimMode === 'mouse';
    if (p.freeAiming) p.facing = U.angleTo(p.x, p.y, mw.x, mw.y);

    VAMP.Disc.update(p, game, dt);
    updateBuffs(p, dt);
    VAMP.Blood.updateHunger(p, dt);
    C().updateStatuses(p, dt, game, true);

    // ---- scripted cinematic verbs own the frame ----
    if (p.finisher) { tickFinisher(p, dt, game); return; }
    if (p.pounce) { tickPounce(p, dt, game); return; }
    if (p.dash) { tickDash(p, dt, game); return; }

    // ---- feeding overrides everything ----
    if (p.feeding) {
      // hold F to drain to death; release to spare — BUT a finisher-spawned feed always drains lethally
      p.holdingFeed = input.isDown('keyf') || !!p.feeding.execution;
      VAMP.Blood.tickFeeding(p, dt, game);
      if (input.mouse.pressed) VAMP.Blood.gulpHit(p, game);  // mini-game: click on the sweet window for a Perfect Gulp
      if (input.wasPressed('keyg') && p.feeding && VAMP.Coterie) { if (VAMP.Coterie.embrace(game, p.feeding.npc)) VAMP.Blood.stopFeeding(p, game); } // Embrace into a childe
      if (input.wasPressed('space') || input.wasPressed('keye')) VAMP.Blood.stopFeeding(p, game); // hard cancel -> always returns control
      return;
    }

    if (p.inVehicle) { updateInVehicle(p, dt, game); return; }

    // ---- on foot ----
    const resting = (game.time - p.lastHurtT > 5) && game.masquerade.stars === 0 && !p.bloodState.frenzied;
    VAMP.Blood.passiveRegen(p, dt, resting);

    let mx = input.moveX(), my = input.moveY();
    const moving = mx !== 0 || my !== 0;
    if (C().isRooted(p)) { mx = 0; my = 0; }
    // face the movement direction (unless free-aiming at the cursor). standing still keeps your
    // last facing, so you hold a guard direction like in GTA.
    if (!p.freeAiming && (mx !== 0 || my !== 0)) p.facing = U.angleLerp(p.facing, Math.atan2(my, mx), U.clamp(dt * 18, 0, 1));
    // toggle persistent mouse-aim (for players who prefer twin-stick feel)
    if (input.wasPressed('keyv')) { p.aimMode = (p.aimMode === 'mouse') ? 'move' : 'mouse'; if (VAMP.UI) VAMP.UI.notify('Aim: ' + (p.aimMode === 'mouse' ? 'Mouse — cursor (free-aim)' : 'Movement — hold RMB to free-aim'), '#9bf'); }

    // sneak (X toggle): a slow, quiet, low-exposure gait — the deliberate predator's approach
    if (input.wasPressed('keyx')) { p.sneaking = !p.sneaking; if (VAMP.UI) VAMP.UI.notify(p.sneaking ? 'Sneaking — slow, quiet, hard to see' : 'No longer sneaking', '#9bf'); }
    const carrying = !!p.carrying;

    // ---- DODGE (double-tap a direction): a quick i-frame dash — the action-combat skill floor that
    // turns enemy telegraphs into read-and-react moments instead of damage you just eat. ----
    if (!carrying && !(p.dashCD > 0) && !C().isRooted(p)) {
      if (!p._tapT) p._tapT = { up: -99, down: -99, left: -99, right: -99 };
      const TAPS = [
        ['up', (input.wasPressed('keyw') || input.wasPressed('arrowup')), 0, -1],
        ['down', (input.wasPressed('keys') || input.wasPressed('arrowdown')), 0, 1],
        ['left', (input.wasPressed('keya') || input.wasPressed('arrowleft')), -1, 0],
        ['right', (input.wasPressed('keyd') || input.wasPressed('arrowright')), 1, 0],
      ];
      for (let i = 0; i < TAPS.length; i++) {
        const t = TAPS[i]; if (!t[1]) continue;
        if (game.time - p._tapT[t[0]] < 0.28) { tryDash(p, game, t[2], t[3]); break; }
        p._tapT[t[0]] = game.time;
      }
    }

    // sprint (blood-fueled vampiric burst) — Shift
    p.sprinting = false;
    let speed = p.derived.moveSpeed * C().speedFactor(p);
    if (p.bloodState.frenzied) speed *= 1.25;
    if (p.sneaking) speed *= 0.5;       // creep
    if (carrying) speed *= 0.6;         // hauling dead weight
    const wantSprint = !p.sneaking && !carrying && (input.isDown('shiftleft') || input.isDown('shiftright')) && moving;
    if (wantSprint && p.blood > 1) {
      p.sprinting = true; speed *= 1.7; p.blood = Math.max(0, p.blood - 6 * dt);
      if (VAMP.FX && Math.random() < 0.5) VAMP.FX.afterimage(p.x, p.y, p.facing);
    } else if (wantSprint && p.blood <= 1) {
      if (p.sprintCueT === undefined || game.time - p.sprintCueT > 3) { p.sprintCueT = game.time; if (VAMP.UI) VAMP.UI.notify('Too little Vitae to sprint — feed!', '#a88'); }
    }
    // pro_key Wild Hunt: stacks from prior frames boost speed live (no recompute needed)
    if (p.huntStacks) speed *= 1 + p.huntStacks * 0.06;

    if (moving) {
      const l = Math.hypot(mx, my) || 1;
      const targetVx = (mx / l) * speed, targetVy = (my / l) * speed;
      if (p._vx === undefined) { p._vx = targetVx; p._vy = targetVy; }
      const accel = 1 - Math.pow(0.0008, dt);
      p._vx = U.lerp(p._vx, targetVx, accel);
      p._vy = U.lerp(p._vy, targetVy, accel);
      const nx = p.x + p._vx * dt;
      const ny = p.y + p._vy * dt;
      const prev = { x: p.x, y: p.y };
      p.x = nx; p.y = ny;
      if (!p.mistForm) {
        game.world.collideCircle(p, p.r);
        if (p._inWater) {
          // vampires hate running water — push back
          p.x = prev.x; p.y = prev.y;
        }
      } else {
        // mist form phases through walls but not the world edge
        p.x = U.clamp(p.x, game.world.border * game.world.TILE, game.world.w - game.world.border * game.world.TILE);
        p.y = U.clamp(p.y, game.world.border * game.world.TILE, game.world.h - game.world.border * game.world.TILE);
      }
      p.stats.distance += U.dist(prev.x, prev.y, p.x, p.y);
      p.walkPhase = (p.walkPhase || 0) + speed * dt * 0.05;   // drives the walk cycle
    }
    // pro_key (The Wild Hunt): continuous movement builds stacks, stopping or being hit resets
    if (p.treeNodes && p.treeNodes['pro_key']) {
      if (!p.huntStacks) p.huntStacks = 0;
      if (!p._huntT) p._huntT = 0;
      if (moving && !p.feeding) {
        p._huntT += dt;
        if (p._huntT >= 0.8) { p._huntT = 0; p.huntStacks = Math.min(5, (p.huntStacks || 0) + 1); if (p.huntStacks === 5 && VAMP.FX) VAMP.FX.number(p.x, p.y - 36, 'HUNT×5', '#c1722a', { crit: true }); }
      } else if (!moving) {
        if (p.huntStacks > 0) p.huntStacks = 0, p._huntT = 0;
      }
    } else { p.huntStacks = 0; }

    // frenzy trail positions — ring buffer of last 6 world positions
    const frenzy = p.bloodState.frenzied || p.bloodState.hunger >= 4;
    if (frenzy) {
      if (!p._trail) p._trail = [];
      p._trail.push({ x: p.x, y: p.y, t: game.time });
      if (p._trail.length > 6) p._trail.shift();
    } else if (p._trail && p._trail.length) {
      p._trail = [];
    }

    p.moving = moving;
    // how visible am I (light/shadow/sneak/sprint/frenzy) — drives every NPC's perception range
    p.exposure = VAMP.Stealth ? VAMP.Stealth.exposure(p, game) : 0.85;

    // ---- primary attack (Space — GTA-style — or LMB). hands are full while hauling a body. ----
    if (!carrying && (input.mouse.down || input.isDown('space') || input.isDown('keyj'))) primaryAttack(p, game);

    // ---- abilities (1-8 / Q E R) ----
    const slotKeys = ['digit1', 'digit2', 'digit3', 'digit4', 'digit5', 'digit6', 'digit7', 'digit8'];
    for (let i = 0; i < slotKeys.length; i++) if (input.wasPressed(slotKeys[i])) VAMP.Disc.castSlot(p, game, i);
    if (input.wasPressed('keyq')) VAMP.Disc.castSlot(p, game, 0);  // Q = slot 1 alt-bind
    if (input.wasPressed('keyr')) VAMP.Disc.castSlot(p, game, 2);  // R = slot 3 alt-bind
    // pot_key (Blood Rage): B enters/exits deliberate frenzy — the player commands the Beast
    if (p.treeNodes && p.treeNodes['pot_key'] && input.wasPressed('keyb')) {
      if (p.bloodState.frenzied) {
        VAMP.Blood.endFrenzy(p); p._bloodRageCD = 3;
        if (VAMP.UI) VAMP.UI.notify('Blood Rage fades', '#c79bff');
      } else if ((p._bloodRageCD || 0) > 0) {
        if (VAMP.UI) VAMP.UI.notify('Blood Rage cooling down…', '#a88');
      } else if (p.blood < 2) {
        if (VAMP.UI) VAMP.UI.notify('Not enough vitae to enter Blood Rage', '#a88');
      } else {
        p.blood -= 2; VAMP.Blood.startFrenzy(p);
        if (VAMP.UI) VAMP.UI.notify('BLOOD RAGE — [B] to end', '#c01028');
      }
    }
    if (p._bloodRageCD > 0) p._bloodRageCD -= dt;

    // ---- shadow-pounce (Ctrl): leap onto distant prey (Space is now the attack button) ----
    if (!carrying && (input.wasPressed('controlleft') || input.wasPressed('controlright')) && p.pounceUnlocked) tryPounce(p, game);

    // ---- feeding start (F) ----
    if (input.wasPressed('keyf')) tryFeed(p, game);

    // ---- intimidate (T): a social verb — cow a lone mortal without a fight, spends Influence ----
    if (input.wasPressed('keyt')) tryIntimidate(p, game);

    // ---- interact (E): vehicles & POIs ----
    if (input.wasPressed('keye')) interact(p, game);
  }

  function updateInVehicle(p, dt, game) {
    const v = p.inVehicle;
    if (VAMP.Audio) VAMP.Audio.setRadioActive(true);
    VAMP.Vehicle.update(v, dt, game);
    p.x = v.x; p.y = v.y;
    // drive-by always aims with the cursor (you steer with the keys, aim the gun with the mouse)
    const mw = game.cam.screenToWorld(In().mouse.x, In().mouse.y);
    p.aimX = mw.x; p.aimY = mw.y; p.facing = U.angleTo(v.x, v.y, mw.x, mw.y); p.freeAiming = true;
    if (In().wasPressed('keye')) VAMP.Vehicle.exit(p, game);
    // R: cycle radio stations — GTA staple, 4 procedural synth moods
    if (In().wasPressed('keyr') && VAMP.Audio && VAMP.Audio.nextStation) {
      const st = VAMP.Audio.nextStation();
      if (VAMP.UI) VAMP.UI.notify('♬ ' + st.name, st.color);
      VAMP.Audio.play('ui');
    }
    // drive-by: shoot toward mouse if has gun (LMB — Space is the handbrake while driving)
    if ((In().mouse.down) && p.equipment.weapon && p.equipment.weapon.kind !== 'claws' && p.attackCD <= 0) {
      rangedShot(p, game, true);
    }
    // (attackCD already decremented once at the top of update())
    // abilities still usable in car (some)
    const slotKeys = ['digit1', 'digit2', 'digit3', 'digit4', 'digit5', 'digit6', 'digit7', 'digit8'];
    for (let i = 0; i < slotKeys.length; i++) if (In().wasPressed(slotKeys[i])) VAMP.Disc.castSlot(p, game, i);
    if (v.dead || v.burning && v.burnT < 0.2) VAMP.Vehicle.exit(p, game, true);
  }

  function primaryAttack(p, game) {
    if (p.attackCD > 0) return;
    const w = p.equipment.weapon || { kind: 'claws' };
    if (w.kind === 'claws') clawAttack(p, game, w);
    else rangedShot(p, game, false);
  }

  function clawAttack(p, game, w) {
    const now = game.time;
    // 3-hit combo: 1st/2nd faster, 3rd a slower, heavier finisher swing
    if (now - (p.lastAttackT || -99) > 0.9) p.comboN = 0;
    p.comboN = (p.comboN || 0) % 3 + 1;
    const finisherSwing = p.comboN === 3;
    p.attackCD = (finisherSwing ? 0.50 : 0.34) / p.derived.attackSpeed;
    p.swingT = Math.min(0.26, p.attackCD * 0.85);   // trigger the claw-swing animation
    p.swingDir = (p.comboN % 2) ? 1 : -1;            // alternate L/R sweep
    p.lastAttackT = now;
    const reach = 40 + (w.rangeBonus || 0);
    const arc = finisherSwing ? 1.3 : 1.1;
    const huntMult = (p.treeNodes && p.treeNodes['pro_key'] && p.huntStacks) ? 1 + p.huntStacks * 0.08 : 1;
    const dmg = p.derived.meleeDmg * (w.dmgMult || 1) * (finisherSwing ? 1.6 : 1) * huntMult;
    const kb = finisherSwing ? 170 : 90;
    // soft-aim: nudge facing toward the best in-arc target so swings land at 16px (assist, not auto-aim)
    let bestN = null, bestScore = Infinity;
    for (const n of game.npcs) {
      if (n.dead || n.ally) continue;
      const d = U.dist(p.x, p.y, n.x, n.y);
      if (d > reach + n.r + 14) continue;
      const off = Math.abs(U.wrapAngle(U.angleTo(p.x, p.y, n.x, n.y) - p.facing));
      if (off > arc + 0.4) continue;
      const score = off + d * 0.004;
      if (score < bestScore) { bestScore = score; bestN = n; }
    }
    if (bestN) p.facing = U.angleLerp(p.facing, U.angleTo(p.x, p.y, bestN.x, bestN.y), 0.5);
    let hit = false;
    for (const n of game.npcs) {
      if (n.dead || n.ally) continue;
      const d = U.dist(p.x, p.y, n.x, n.y);
      if (d > reach + n.r) continue;
      const a = U.angleTo(p.x, p.y, n.x, n.y);
      if (Math.abs(U.wrapAngle(a - p.facing)) < arc) {
        C().damageNPC(game, n, dmg, { knockback: kb, heavy: finisherSwing, angle: p.facing, color: '#d33', dmgType: 'phys' });
        hit = true;
      }
    }
    if (VAMP.FX) VAMP.FX.slash(p.x, p.y, p.facing, reach);
    if (hit) {
      if (VAMP.Audio) VAMP.Audio.play('hit');
      if (game.cam) { game.cam.shake(finisherSwing ? 4 : 2.4, finisherSwing ? 0.14 : 0.10, p.facing); game.cam.punch(finisherSwing ? 0.06 : 0.035); }
      if (game.hitStop) game.hitStop(finisherSwing ? 0.05 : 0.03);   // the "crunch" on connect only
      if (game.masquerade) game.masquerade.combatNear(p.x, p.y);
    } else if (VAMP.Audio) VAMP.Audio.play('step');   // whiff is light — no shake/stop
  }

  // keyboard-aim assist: when NOT free-aiming, nudge facing toward the best foe in a forward cone so
  // shots land (mirrors the claw soft-aim). Skips fleeing civilians so you don't waste lead on panic.
  function assistAim(p, game, cone, range) {
    let best = null, bestScore = Infinity;
    for (const n of game.npcs) {
      if (n.dead || n.ally) continue;
      if ((n.faction === 'civ' || n.faction === 'animal') && n.state === 'flee') continue;
      const d = U.dist(p.x, p.y, n.x, n.y);
      if (d > range) continue;
      const off = Math.abs(U.wrapAngle(U.angleTo(p.x, p.y, n.x, n.y) - p.facing));
      if (off > cone) continue;
      const score = off + d * 0.001;
      if (score < bestScore) { bestScore = score; best = n; }
    }
    if (best) p.facing = U.angleLerp(p.facing, U.angleTo(p.x, p.y, best.x, best.y), 0.55);
  }

  function rangedShot(p, game, driveby) {
    const w = p.equipment.weapon;
    if (!w) return;
    if (!driveby && !p.freeAiming) assistAim(p, game, 0.45, (w.speed || 620) * 0.85);
    p.attackCD = (w.fireRate || 0.25) / (driveby ? 1 : p.derived.attackSpeed);
    p.lastAttackT = game.time;
    const spread = w.spread || 0.04;
    const pellets = w.pellets || 1;
    for (let i = 0; i < pellets; i++) {
      const a = p.facing + (Math.random() - 0.5) * spread * (pellets > 1 ? 3 : 1);
      game.spawnProjectile({
        x: p.x + Math.cos(a) * (p.r + 8), y: p.y + Math.sin(a) * (p.r + 8),
        vx: Math.cos(a) * (w.speed || 620), vy: Math.sin(a) * (w.speed || 620),
        owner: 'player', dmg: (w.dmg || 14) * (1 + p.derived.bloodPotency * 0.05), r: 3.5,
        color: '#ffe9a8', life: 1.0, kind: 'bullet', knockback: 40, pierce: w.pierce || 0, dmgType: 'phys',
      });
    }
    if (VAMP.Audio) VAMP.Audio.play('gun');
    if (game.cam) { const heavy = (w.pellets || 1) > 1; game.cam.shake(heavy ? 4 : 2.2, heavy ? 0.13 : 0.10, p.facing + Math.PI); if (heavy) game.cam.punch(0.05); }   // kick BACK from the muzzle
    if (game.masquerade) game.masquerade.gunfire(p.x, p.y, true);   // YOUR gunshots draw heat
  }

  // shared by tryFeed and the HUD prompt so they never disagree
  function findFeedTarget(p, game) {
    let best = null, bestD = 52;
    for (const n of game.npcs) {
      if (n.dead || n.ally) continue;
      const d = U.dist(p.x, p.y, n.x, n.y);
      if (d > bestD) continue;
      const grabbable = n.mesmerizedT > 0 || C().isDisabled(n) || n.downed || n.faction === 'civ' || n.faction === 'animal' || n.hp < n.maxHp * 0.4;
      if (!grabbable) continue;
      bestD = d; best = n;
    }
    return best;
  }

  function tryFeed(p, game) {
    // SILENT TAKEDOWN: if you're unseen behind ANY foe (even a healthy gangster/cop), grab them
    // straight into a feed — no struggle, no alarm. The stealth lane's signature opener.
    const st = VAMP.Stealth && VAMP.Stealth.findStealthTarget(p, game);
    if (st) {
      st.mesmerizedT = Math.max(st.mesmerizedT || 0, 1.5);
      if (VAMP.Blood.startFeeding(p, st)) {
        p.feeding.stealth = true; st.state = 'fed'; st.path = null;
        if (VAMP.FX) VAMP.FX.number(p.x, p.y - 30, 'SILENT TAKEDOWN', '#9bd', { small: true });
      }
      return;
    }
    // an execution-eligible foe (helpless or near-dead) → brutal finisher that flows into a feed
    const ex = findExecuteTarget(p, game);
    if (ex && p.finisherUnlocked && !game.reducedMotion) { startFinisher(p, game, ex); return; }
    const best = findFeedTarget(p, game);
    if (best) {
      VAMP.Blood.startFeeding(p, best);
      best.state = 'fed'; best.path = null;
    } else {
      if (VAMP.UI) VAMP.UI.notify('No victim in reach (mesmerize or weaken them first)', '#a88');
    }
  }

  // a stricter predicate than feeding: helpless OR near-dead (no bosses)
  function findExecuteTarget(p, game) {
    let best = null, bestD = 46;
    for (const n of game.npcs) {
      if (n.dead || n.ally || n.boss) continue;
      const d = U.dist(p.x, p.y, n.x, n.y);
      if (d > bestD) continue;
      const helpless = n.mesmerizedT > 0 || C().isDisabled(n);
      const lowHp = n.hp < n.maxHp * 0.25 && !n.elite;
      if (!helpless && !lowHp) continue;
      bestD = d; best = n;
    }
    return best;
  }

  // ---- FINISHER: a short scripted cinematic that ends in a feed (reuses finishFeeding reward) ----
  function startFinisher(p, game, npc) {
    let kind = 'snap';
    if (npc.hp < npc.maxHp * 0.25) kind = 'rip';
    else if (C().isDisabled(npc)) kind = 'impale';
    p.finisher = { npc, kind, t: 0, dur: 0.85, struck: false };
    p.invuln = Math.max(p.invuln, 0.9);
    p.facing = U.angleTo(p.x, p.y, npc.x, npc.y);
    npc.mesmerizedT = Math.max(npc.mesmerizedT || 0, 1);
    npc.vx = npc.vy = 0;
    if (game.setSlowmo) game.setSlowmo(0.85, 0.22);   // world crawls; player runs full simDt → "you move, they're frozen"
    if (VAMP.Audio) VAMP.Audio.play('bite');
  }
  function tickFinisher(p, dt, game) {
    const f = p.finisher, n = f.npc;
    if (!n || n.dead) { p.finisher = null; return; }
    f.t += dt;   // full speed (player on simDt), while enemies crawl in slowmo
    const fx = p.x + Math.cos(p.facing) * (p.r + n.r), fy = p.y + Math.sin(p.facing) * (p.r + n.r);
    n.x = U.lerp(n.x, fx, 0.4); n.y = U.lerp(n.y, fy, 0.4);
    p.swingT = 0.26;   // keep the claw animation alive through the cinematic
    if (!f.struck && f.t > f.dur * 0.45) {
      f.struck = true;
      if (game.hitStop) game.hitStop(0.06);   // SHORT freeze at the strike frame ONLY
      if (VAMP.FX) { VAMP.FX.flash('rgba(150,0,20,0.30)', 0.18); VAMP.FX.ring(n.x, n.y, 34, '#c01028'); VAMP.FX.blood(n.x, n.y, 18); }
      if (game.cam) { game.cam.shake(6, 0.18, p.facing); game.cam.punch(0.09); }
      if (VAMP.Audio) VAMP.Audio.play('death');
    }
    if (f.t >= f.dur) {
      p.finisher = null;
      if (VAMP.Blood.startFeeding(p, n)) {
        p.feeding.execution = f.kind;
        if (f.kind !== 'snap') p.feeding.drained = n.maxHp;   // rip/impale = near-lethal; snap becomes a clean feed
        p.holdingFeed = true;
      }
    }
  }

  // ---- SHADOW-POUNCE: a blood-fuelled leap that closes onto prey and bites ----
  function findPounceTarget(p, game) {
    let best = null, bestScore = Infinity;
    for (const n of game.npcs) {
      if (n.dead || n.ally) continue;
      const d = U.dist(p.x, p.y, n.x, n.y);
      if (d > POUNCE_RANGE + n.r || d < 40) continue;
      const off = Math.abs(U.wrapAngle(U.angleTo(p.x, p.y, n.x, n.y) - p.facing));
      if (off > 0.7) continue;
      const score = off + d * 0.002;
      if (score < bestScore) { bestScore = score; best = n; }
    }
    return best;
  }
  function tryPounce(p, game) {
    if (p.pounceCD > 0 || p.blood < POUNCE_COST || C().isRooted(p)) {
      if (p.blood < POUNCE_COST && VAMP.UI && (p._pounceCue === undefined || game.time - p._pounceCue > 3)) { p._pounceCue = game.time; VAMP.UI.notify('Too little Vitae to pounce — feed!', '#a88'); }
      return;
    }
    const tgt = findPounceTarget(p, game);
    const ang = tgt ? U.angleTo(p.x, p.y, tgt.x, tgt.y) : p.facing;
    const dist = Math.min(POUNCE_RANGE, tgt ? U.dist(p.x, p.y, tgt.x, tgt.y) - 12 : POUNCE_RANGE);
    p.pounce = { ang, t: 0, dur: 0.20, fromX: p.x, fromY: p.y, toX: p.x + Math.cos(ang) * dist, toY: p.y + Math.sin(ang) * dist };
    p.pounceCD = POUNCE_CD;
    p.blood = Math.max(0, p.blood - POUNCE_COST);
    p.invuln = Math.max(p.invuln, 0.24);
    p.facing = ang;
    if (VAMP.Audio) VAMP.Audio.play('frenzy');
  }
  function tickPounce(p, dt, game) {
    const pc = p.pounce; pc.t += dt;
    const k = U.clamp(pc.t / pc.dur, 0, 1);
    const e = U.ease ? U.ease.outCubic(k) : k;
    const px = p.x, py = p.y;
    p.x = U.lerp(pc.fromX, pc.toX, e); p.y = U.lerp(pc.fromY, pc.toY, e);
    if (!p.mistForm) {
      game.world.collideCircle(p, p.r);                   // arrested by walls, like normal movement
      if (p._inWater) { p.x = px; p.y = py; onPounceLand(p, game); p.pounce = null; return; }   // vampires can't cross running water
    }
    if (VAMP.FX && Math.random() < 0.8) VAMP.FX.dashTrail(p.x, p.y, pc.ang);
    if (k >= 1) { onPounceLand(p, game); p.pounce = null; }
  }
  function onPounceLand(p, game) {
    if (VAMP.FX) VAMP.FX.shadow(p.x, p.y, 30);
    if (game.cam) game.cam.shake(3, 0.12, p.pounce.ang);
    const ex = findExecuteTarget(p, game);
    if (ex && p.finisherUnlocked && !game.reducedMotion) { startFinisher(p, game, ex); return; }
    const prey = findFeedTarget(p, game);
    if (prey) { prey.mesmerizedT = Math.max(prey.mesmerizedT || 0, 1.2); VAMP.Blood.startFeeding(p, prey); prey.state = 'fed'; prey.path = null; return; }
    const enemy = game.nearestNPC ? game.nearestNPC(p.x, p.y, (m) => !m.dead && !m.ally, 44) : null;
    if (enemy) C().damageNPC(game, enemy, p.derived.meleeDmg * 1.2, { knockback: 200, heavy: true, angle: p.pounce.ang, color: '#d33', dmgType: 'phys' });
  }

  // ---- DODGE DASH: a free, low-cooldown evade with brief i-frames (no targeting — purely defensive).
  // Kept free + cooldown-gated (not vitae-cost) so it's a RELIABLE answer to telegraphs even when your
  // vitae is spent on spells — the whole point of a skill-floor defense. ----
  function tryDash(p, game, dx, dy) {
    if (p.dashCD > 0 || C().isRooted(p) || p.feeding) return;
    const ang = Math.atan2(dy, dx);
    const dist = 128;
    p.dash = { ang, t: 0, dur: 0.16, fromX: p.x, fromY: p.y, toX: p.x + Math.cos(ang) * dist, toY: p.y + Math.sin(ang) * dist };
    p.dashCD = 0.6;
    p.invuln = Math.max(p.invuln, 0.30);   // i-frames — phase through the blow you read
    p.facing = ang;
    if (VAMP.FX) VAMP.FX.dashTrail(p.x, p.y, ang);
    if (VAMP.Audio) VAMP.Audio.play('step');
  }
  function tickDash(p, dt, game) {
    const d = p.dash; d.t += dt;
    const k = U.clamp(d.t / d.dur, 0, 1);
    const e = U.ease ? U.ease.outCubic(k) : k;
    const px = p.x, py = p.y;
    p.x = U.lerp(d.fromX, d.toX, e); p.y = U.lerp(d.fromY, d.toY, e);
    if (!p.mistForm) { game.world.collideCircle(p, p.r); if (p._inWater) { p.x = px; p.y = py; p.dash = null; return; } }
    if (VAMP.FX && Math.random() < 0.9) VAMP.FX.afterimage(p.x, p.y, p.facing);
    if (k >= 1) p.dash = null;
  }

  // SOCIAL VERB — intimidate a lone, unalarmed mortal: they break and flee (no combat, calm
  // preserved), a gangster coughs up protection money. Costs Influence, so it's paced.
  function tryIntimidate(p, game) {
    let best = null, bd = 84;
    for (const n of game.npcs) {
      if (n.dead || n.ally || n.downed || n.aggro) continue;
      if (n.faction !== 'civ' && n.faction !== 'gang') continue;
      const d = U.dist(p.x, p.y, n.x, n.y);
      if (d < bd) { bd = d; best = n; }
    }
    if (!best) { if (VAMP.UI) VAMP.UI.notify('No one to intimidate nearby', '#a88'); return; }
    if (!(VAMP.Reputation && VAMP.Reputation.spendInfluence(p, 1))) { if (VAMP.UI) VAMP.UI.notify('Not enough Influence — it refills over time (raise Presence for more)', '#a88'); return; }
    C().applyStatus(best, 'fear', { dur: 4 });
    best.state = 'flee'; best.fleeT = 4; best.panicReported = true;   // panicReported => this flight draws no Heat
    p.facing = U.angleTo(p.x, p.y, best.x, best.y);
    const drop = best.faction === 'gang' ? (30 + (Math.random() * 40 | 0)) : (8 + (Math.random() * 16 | 0));
    if (game.addMoney) game.addMoney(drop, best.x, best.y);
    if (best.faction === 'gang' && VAMP.Reputation) VAMP.Reputation.change(p, 'gang', -0.5);
    if (VAMP.Mastery) VAMP.Mastery.gain(p, 'predation', 4);
    if (VAMP.FX) { VAMP.FX.number(best.x, best.y - 18, 'COWED', '#ff9ecf', { small: true }); VAMP.FX.ring(best.x, best.y, 24, '#ff9ecf'); }
    if (VAMP.Audio) VAMP.Audio.play('ui');
    if (VAMP.UI) VAMP.UI.notify('Intimidated — they flee and drop $' + drop, '#ff9ecf');
  }

  function interact(p, game) {
    if (p.interactCD > 0) return;
    p.interactCD = 0.3;
    // bodies first: grab / drop / dump (context-aware) takes priority over vehicles & POIs
    if (VAMP.Stealth && VAMP.Stealth.handleBody(p, game)) return;
    // nearest vehicle
    let bestV = null, bvd = 46;
    for (const v of game.vehicles) {
      if (v.dead || v.burning) continue;
      const d = U.dist(p.x, p.y, v.x, v.y);
      if (d < bvd) { bvd = d; bestV = v; }
    }
    // nearest POI
    const poi = game.nearestPOI ? game.nearestPOI(p.x, p.y, 60) : null;
    if (poi && (!bestV || U.dist(p.x, p.y, poi.x, poi.y) < bvd)) {
      game.usePOI(poi);
      return;
    }
    if (bestV) {
      if (bestV.driver && bestV.driver !== 'player') { p.stats.hijacks++; game.onHijack && game.onHijack(bestV); }
      VAMP.Vehicle.enter(p, bestV, game);
      if (VAMP.Progress) VAMP.Progress.markSeen(p, 'vehicles');
    }
  }

  // ---- render (animated: walk cycle, claw swing, feeding lunge) ----
  function render(p, ctx, game) {
    if (p.inVehicle) return; // drawn as vehicle
    const r = p.r;
    const t = game.time;
    const moving = p.moving;
    const wp = p.walkPhase || 0;
    const stepA = moving ? Math.sin(wp) * 3.2 : 0;             // feet travel (opposed)
    const stepB = moving ? Math.sin(wp + Math.PI) * 3.2 : 0;
    const armSwing = moving ? Math.sin(wp + Math.PI) * 0.45 : Math.sin(t * 2.4) * 0.06;
    const feeding = !!p.feeding;
    const fin = !!p.finisher;
    const pouncing = !!p.pounce;
    const swingT = p.swingT || 0;
    // finisher drives the claw sweep from its own progress; else the attack timer
    const swingP = fin ? U.clamp(p.finisher.t / p.finisher.dur, 0, 1) : (swingT > 0 ? 1 - swingT / 0.26 : -1);
    const frenzy = p.bloodState.frenzied || p.bloodState.hunger >= 4;
    const w = p.equipment.weapon;

    // frenzy trail — drawn in world space before the player transform
    if (p._trail && p._trail.length && frenzy) {
      for (let ti = 0; ti < p._trail.length; ti++) {
        const pt = p._trail[ti];
        const alpha = (ti / p._trail.length) * 0.35;
        ctx.globalAlpha = alpha;
        ctx.fillStyle = '#ff1020';
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, p.r * 0.7, 0, U.TAU);
        ctx.fill();
      }
      ctx.globalAlpha = 1;
    }

    ctx.save();
    ctx.translate(p.x, p.y);
    // shadow — pulses blood-red during frenzy (ground-plane read of beast state)
    const shadowPulse = frenzy ? 0.45 + Math.sin(t * 6) * 0.08 : 0.4;
    ctx.fillStyle = frenzy ? 'rgba(70,0,10,' + shadowPulse + ')' : 'rgba(0,0,0,0.4)';
    ctx.beginPath(); ctx.ellipse(0, r * 0.55, r * 1.25, r * 0.6, 0, 0, U.TAU); ctx.fill();

    ctx.globalAlpha = (p.cloaked || p.mistForm) ? 0.4 : 1;
    const idleSway = (!moving && !feeding && !fin) ? Math.sin(t * 2) * 0.03 : 0;
    ctx.rotate(p.facing + idleSway);
    if (feeding || fin) ctx.translate(r * (fin ? 0.6 : 0.45), 0);   // lunge toward the victim
    else if (pouncing) ctx.translate(r * 0.35, 0);                  // stretched mid-leap
    else if (p.sprinting) ctx.translate(r * 0.18, 0);              // forward run lean

    // cape (trailing flaps that flutter)
    const flutter = Math.sin(t * 6 + wp) * 2 + (moving ? 3 : 0);
    // #11 — cape tinted by clan palette; frenzy overrides to blood-red
    const cc = p.clanColor || { cape: '#160814', cape2: '#34122a', collar: '#7a1530', eye: '#d83040', aura: '#7a4bff' };
    ctx.fillStyle = frenzy ? '#5a0010' : cc.cape;
    ctx.beginPath();
    ctx.moveTo(-r * 0.3, -r * 0.5);
    ctx.quadraticCurveTo(-r * 1.7 - flutter, -r * 0.95, -r * 2.0, -flutter);
    ctx.quadraticCurveTo(-r * 1.7 - flutter, r * 0.95, -r * 0.3, r * 0.5);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = frenzy ? '#7a0018' : cc.cape2;
    ctx.beginPath(); ctx.moveTo(-r * 0.3, -r * 0.4); ctx.quadraticCurveTo(-r * 1.1, -r * 0.3, -r * 1.25, 0); ctx.quadraticCurveTo(-r * 1.1, r * 0.3, -r * 0.3, r * 0.4); ctx.closePath(); ctx.fill();

    const useSpr = VAMP.ArtFlags && VAMP.ArtFlags.useSpriter && VAMP.Spriter && VAMP.Spriter.has('player_walk');
    const useBmp = !useSpr && VAMP.ArtFlags && VAMP.ArtFlags.useBitmapPlayer && VAMP.Assets.ready && VAMP.Assets.has('player_vampire');
    const bob = moving ? Math.sin(wp) * 1.5 : 0;
    if (useSpr) {
      const dir = VAMP.Spriter.dirFromAngle(p.facing);
      const frame = moving ? VAMP.Spriter.walkFrame(game.time, 9, 4) : 0;
      const sz = r * 3.6;
      const tint = frenzy ? '#8a2030' : (cc.cape || '#36223e');
      VAMP.Spriter.draw(ctx, 'player_walk', r * 0.05, bob, {
        dir, frame, w: sz, h: sz * 1.05, ax: 0.42, ay: 0.55, tint, smooth: false,
        alpha: (p.cloaked || p.mistForm) ? 0.4 : 1,
        fallbackKey: 'player_vampire',
      });
    } else if (useBmp) {
      const sz = r * 3.6;
      const tint = frenzy ? '#8a2030' : (cc.cape || '#36223e');
      VAMP.Assets.drawKey(ctx, 'player_vampire', r * 0.05, bob, { w: sz, h: sz * 1.05, ax: 0.42, ay: 0.55, tint: tint, alpha: (p.cloaked || p.mistForm) ? 0.4 : 1, smooth: false });
    } else {
      // --- gothic fallback: angular predator silhouette ---

      // boot tips: narrow rectangles stepping fore/aft (in facing-axis coords: x=fore, y=right)
      ctx.fillStyle = '#0e0910';
      // boot A: right side of body
      ctx.beginPath();
      ctx.moveTo(stepA + r * 0.35, -r * 0.60);
      ctx.lineTo(stepA + r * 0.35, -r * 0.32);
      ctx.lineTo(stepA - r * 0.20, -r * 0.32);
      ctx.lineTo(stepA - r * 0.20, -r * 0.60);
      ctx.closePath(); ctx.fill();
      // boot B: left side
      ctx.beginPath();
      ctx.moveTo(stepB + r * 0.35,  r * 0.32);
      ctx.lineTo(stepB + r * 0.35,  r * 0.60);
      ctx.lineTo(stepB - r * 0.20,  r * 0.60);
      ctx.lineTo(stepB - r * 0.20,  r * 0.32);
      ctx.closePath(); ctx.fill();

      // torso: angular V-shape — wide at shoulders, pinched at waist
      // in rotated frame: shoulders are at ±y (left/right), waist narrows, front tapers to a point
      const grd = ctx.createLinearGradient(r * 0.6, 0, -r * 0.5, 0);
      grd.addColorStop(0, '#2e1a38');
      grd.addColorStop(0.5, '#1c1024');
      grd.addColorStop(1, '#110b18');
      ctx.fillStyle = grd;
      ctx.beginPath();
      // rear shoulder corners (wide at back)
      ctx.moveTo(-r * 0.55, -r * 0.78);   // rear-right shoulder
      ctx.lineTo( r * 0.05, -r * 0.52);   // front-right armpit
      ctx.lineTo( r * 0.30, -r * 0.20);   // front-right waist pinch
      ctx.lineTo( r * 0.40,  0);           // chest front point (facing direction)
      ctx.lineTo( r * 0.30,  r * 0.20);   // front-left waist pinch
      ctx.lineTo( r * 0.05,  r * 0.52);   // front-left armpit
      ctx.lineTo(-r * 0.55,  r * 0.78);   // rear-left shoulder
      ctx.lineTo(-r * 0.20,  r * 0.30);   // rear waist
      ctx.lineTo(-r * 0.20, -r * 0.30);   // rear waist other side
      ctx.closePath(); ctx.fill();

      // shoulder mass — angular blocks on each side
      ctx.fillStyle = '#251530';
      ctx.beginPath();
      ctx.moveTo(-r * 0.55, -r * 0.78);
      ctx.lineTo(-r * 0.10, -r * 0.72);
      ctx.lineTo( r * 0.05, -r * 0.52);
      ctx.lineTo(-r * 0.20, -r * 0.30);
      ctx.closePath(); ctx.fill();
      ctx.beginPath();
      ctx.moveTo(-r * 0.55,  r * 0.78);
      ctx.lineTo(-r * 0.10,  r * 0.72);
      ctx.lineTo( r * 0.05,  r * 0.52);
      ctx.lineTo(-r * 0.20,  r * 0.30);
      ctx.closePath(); ctx.fill();

      // collar / cravat: angular V pointing forward
      ctx.fillStyle = frenzy ? '#c01028' : (cc.collar || '#7a1530');
      ctx.beginPath();
      ctx.moveTo(-r * 0.10, -r * 0.28);   // base right
      ctx.lineTo( r * 0.38,  0);           // front tip
      ctx.lineTo(-r * 0.10,  r * 0.28);   // base left
      ctx.lineTo( r * 0.08,  0);           // inner indent
      ctx.closePath(); ctx.fill();
      // blood-soaked chest glow during feeding or frenzy
      if (feeding || frenzy) {
        const chestGrd = ctx.createRadialGradient(r * 0.40, 0, 0, r * 0.40, 0, r * 0.9);
        chestGrd.addColorStop(0, 'rgba(160,0,20,' + (0.3 + Math.sin(t * 8) * 0.15) + ')');
        chestGrd.addColorStop(1, 'rgba(120,0,15,0)');
        ctx.fillStyle = chestGrd;
        ctx.beginPath();
        ctx.ellipse(r * 0.25, 0, r * 0.80, r * 0.70, 0, 0, U.TAU);
        ctx.fill();
      }
    }

    // front arm + claw / weapon (swings on attack)
    let armAng = -armSwing * 0.6;
    if (swingP >= 0) armAng = U.lerp(-1.15, 1.15, swingP);      // sweep across the front
    const hx = Math.cos(armAng) * r * 1.05 + r * 0.15, hy = Math.sin(armAng) * r * 0.95 + r * 0.4;
    ctx.strokeStyle = '#2a1838'; ctx.lineWidth = r * 0.4;
    ctx.beginPath(); ctx.moveTo(r * 0.15, r * 0.5); ctx.lineTo(hx, hy); ctx.stroke();
    if (!w || w.kind === 'claws') {
      ctx.strokeStyle = swingP >= 0 ? '#ffffff' : '#d3ccda'; ctx.lineWidth = 1.7; ctx.lineCap = 'round';
      for (let i = -1; i <= 1; i++) { const ca = armAng + i * 0.2; ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(hx + Math.cos(ca) * r * 0.6, hy + Math.sin(ca) * r * 0.6); ctx.stroke(); }
      if (swingP >= 0) { ctx.strokeStyle = `rgba(255,255,255,${1 - swingP})`; ctx.lineWidth = 2.5; ctx.beginPath(); ctx.arc(0, 0, r * 1.5, U.lerp(-1.15, 1.15, Math.max(0, swingP - 0.25)), armAng); ctx.stroke(); }
    } else {
      ctx.fillStyle = '#111'; ctx.fillRect(r * 0.5, -1.9, 15, 3.8);
      ctx.fillStyle = '#333'; ctx.fillRect(r * 0.5, -1.9, 4, 3.8);
    }

    if (!useBmp) {
      const headX = feeding ? r * 0.7 : r * 0.46;
      const headY = feeding ? Math.sin(t * 16) * 1.4 : 0;
      // subtle eye-track offset — idle sway when standing still, suppressed while moving/feeding
      const idleLook = !moving && !feeding ? Math.sin(t * 0.8) * r * 0.03 : 0;

      // neck: thin rectangle bridging torso to head
      ctx.fillStyle = '#c8bec6';
      ctx.beginPath();
      ctx.moveTo(headX - r * 0.32, headY - r * 0.10);
      ctx.lineTo(headX - r * 0.06, headY - r * 0.10);
      ctx.lineTo(headX - r * 0.06, headY + r * 0.10);
      ctx.lineTo(headX - r * 0.32, headY + r * 0.10);
      ctx.closePath(); ctx.fill();

      // skull: narrow almond — taller (y-axis = width in rotated frame) than it is deep
      ctx.fillStyle = '#d8cdd6';
      ctx.beginPath();
      ctx.ellipse(headX, headY, r * 0.32, r * 0.46, 0, 0, U.TAU);
      ctx.fill();

      // gaunt shadow — dark wash from rear half to hollow the cheeks
      const faceShd = ctx.createLinearGradient(headX - r * 0.32, headY, headX + r * 0.32, headY);
      faceShd.addColorStop(0, 'rgba(10,5,14,0.72)');
      faceShd.addColorStop(0.45, 'rgba(10,5,14,0.18)');
      faceShd.addColorStop(1, 'rgba(10,5,14,0)');
      ctx.fillStyle = faceShd;
      ctx.beginPath();
      ctx.ellipse(headX, headY, r * 0.32, r * 0.46, 0, 0, U.TAU);
      ctx.fill();

      // sunken eye sockets: dark smudges above the midline
      ctx.fillStyle = 'rgba(8,4,12,0.82)';
      ctx.beginPath();
      ctx.ellipse(headX + r * 0.06, headY - r * 0.16, r * 0.14, r * 0.09, 0, 0, U.TAU);
      ctx.fill();
      ctx.beginPath();
      ctx.ellipse(headX + r * 0.06, headY + r * 0.16, r * 0.14, r * 0.09, 0, 0, U.TAU);
      ctx.fill();

      // eye slits: sharp almond cuts; glow red on frenzy
      // aimDelta+idleLook shifts gaze laterally so the eyes track the aim direction
      const lookOff = idleLook;
      const eyeColor = frenzy ? '#ff2030' : (cc.eye || '#d83040');
      if (frenzy) {
        ctx.shadowColor = '#ff2030'; ctx.shadowBlur = 6;
      }
      ctx.fillStyle = eyeColor;
      // upper eye slit
      ctx.beginPath();
      ctx.moveTo(headX + r * 0.01, headY - r * 0.16 + lookOff);
      ctx.quadraticCurveTo(headX + r * 0.14, headY - r * 0.22 + lookOff, headX + r * 0.22, headY - r * 0.16 + lookOff);
      ctx.quadraticCurveTo(headX + r * 0.14, headY - r * 0.10 + lookOff, headX + r * 0.01, headY - r * 0.16 + lookOff);
      ctx.closePath(); ctx.fill();
      // lower eye slit
      ctx.beginPath();
      ctx.moveTo(headX + r * 0.01, headY + r * 0.16 + lookOff);
      ctx.quadraticCurveTo(headX + r * 0.14, headY + r * 0.10 + lookOff, headX + r * 0.22, headY + r * 0.16 + lookOff);
      ctx.quadraticCurveTo(headX + r * 0.14, headY + r * 0.22 + lookOff, headX + r * 0.01, headY + r * 0.16 + lookOff);
      ctx.closePath(); ctx.fill();
      ctx.shadowBlur = 0; ctx.shadowColor = 'transparent';

      // angular jaw line: dark underside of the skull
      ctx.fillStyle = 'rgba(8,4,12,0.55)';
      ctx.beginPath();
      ctx.moveTo(headX - r * 0.12, headY - r * 0.36);
      ctx.lineTo(headX + r * 0.28, headY - r * 0.20);
      ctx.lineTo(headX + r * 0.32, headY);
      ctx.lineTo(headX + r * 0.28, headY + r * 0.20);
      ctx.lineTo(headX - r * 0.12, headY + r * 0.36);
      ctx.lineTo(headX + r * 0.04, headY);
      ctx.closePath(); ctx.fill();

      // fangs: always visible — this is a vampire
      ctx.fillStyle = '#f0ecf2';
      // upper fang
      ctx.beginPath();
      ctx.moveTo(headX + r * 0.22, headY - r * 0.09);
      ctx.lineTo(headX + r * 0.32, headY - r * 0.04);
      ctx.lineTo(headX + r * 0.22, headY);
      ctx.closePath(); ctx.fill();
      // lower fang
      ctx.beginPath();
      ctx.moveTo(headX + r * 0.22, headY + r * 0.09);
      ctx.lineTo(headX + r * 0.32, headY + r * 0.04);
      ctx.lineTo(headX + r * 0.22, headY);
      ctx.closePath(); ctx.fill();
      // blood-tip on fangs when feeding or frenzied
      if (feeding || frenzy) {
        ctx.fillStyle = '#cc0020';
        ctx.beginPath();
        ctx.moveTo(headX + r * 0.27, headY - r * 0.04);
        ctx.lineTo(headX + r * 0.32, headY - r * 0.04);
        ctx.lineTo(headX + r * 0.27, headY + r * 0.01);
        ctx.closePath(); ctx.fill();
        ctx.beginPath();
        ctx.moveTo(headX + r * 0.27, headY + r * 0.04);
        ctx.lineTo(headX + r * 0.32, headY + r * 0.04);
        ctx.lineTo(headX + r * 0.27, headY - r * 0.01);
        ctx.closePath(); ctx.fill();
      }
    } else if (feeding || frenzy) {
      ctx.fillStyle = frenzy ? '#ff2030' : (cc.eye || '#d83040');
      ctx.beginPath(); ctx.arc(r * 0.55, -r * 0.1, 2, 0, U.TAU); ctx.arc(r * 0.55, r * 0.1, 2, 0, U.TAU); ctx.fill();
    }

    ctx.restore();
    ctx.globalAlpha = 1;

    // powered-up aura (world space)
    if (p.sprinting || frenzy || (p.toggles && Object.values(p.toggles).some(Boolean))) {
      ctx.globalAlpha = 0.16 + 0.05 * Math.sin(t * 6);
      ctx.fillStyle = p.bloodState.frenzied ? '#ff2030' : (cc.aura || '#7a4bff');
      ctx.beginPath(); ctx.arc(p.x, p.y, r * 2.1, 0, U.TAU); ctx.fill();
      ctx.globalAlpha = 1;
    }

    // feeding: bite link to victim + progress ring
    if (feeding) {
      const f = p.feeding, n = f.npc;
      if (n && !n.dead) {
        ctx.strokeStyle = 'rgba(180,0,28,0.6)'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(p.x + Math.cos(p.facing) * r, p.y + Math.sin(p.facing) * r); ctx.lineTo(n.x, n.y); ctx.stroke();
      }
      const frac = U.clamp(f.drained / (f.vt.yield * 1.55), 0, 1);
      ctx.strokeStyle = '#ff2f6e'; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.arc(p.x, p.y, r + 9, -Math.PI / 2, -Math.PI / 2 + frac * U.TAU); ctx.stroke();
      // rhythm mini-game ring: sweet zone (gold) + sweeping marker — click LMB in the zone
      const rr2 = r + 16;
      ctx.strokeStyle = 'rgba(255,210,74,0.5)'; ctx.lineWidth = 4;
      ctx.beginPath(); ctx.arc(p.x, p.y, rr2, 0.42 * U.TAU, 0.62 * U.TAU); ctx.stroke();
      const ma = (f.beat || 0) * U.TAU;
      ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(p.x + Math.cos(ma) * rr2, p.y + Math.sin(ma) * rr2, 3.5, 0, U.TAU); ctx.fill();
      // live kill-vs-spare readout — the central predator choice, made legible (you SEE the consequence)
      const lethal = p.holdingFeed;
      ctx.font = 'bold 9px Verdana'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillStyle = lethal ? '#ff6a6a' : '#86ffae';
      ctx.fillText(lethal ? '☠ HOLD F — draining to death' : '○ release to SPARE (leaves a body)', p.x, p.y - r - 20);
      ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic';
    }
  }

  VAMP.Player = { newPlayer, update, render, addBuff, primaryAttack, tryFeed, interact, findFeedTarget, findExecuteTarget };
})();
