/* =========================================================================
 * VAMPIRE CITY — entities/vehicle.js
 * Arcade top-down driving + simple road-following traffic. Hijackable.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const In = () => VAMP.Input;

  const TYPES = {
    sedan:  { w: 46, h: 24, maxSpeed: 330, accel: 240, handling: 2.6, hp: 120, colors: ['#7a2630', '#26407a', '#2a2a2a', '#5a5a5a', '#2a5a3a', '#6a5a1a'] },
    sport:  { w: 44, h: 22, maxSpeed: 460, accel: 340, handling: 3.2, hp: 100, colors: ['#a01828', '#101018', '#d0a000', '#103a6a'] },
    van:    { w: 54, h: 28, maxSpeed: 270, accel: 190, handling: 2.0, hp: 180, colors: ['#3a3a4a', '#5a4a3a', '#2a3a3a'] },
    police: { w: 48, h: 24, maxSpeed: 400, accel: 300, handling: 3.0, hp: 160, colors: ['#1a2a55'], siren: true },
    hearse: { w: 56, h: 26, maxSpeed: 300, accel: 210, handling: 2.3, hp: 200, colors: ['#0a0a0e'] },
  };

  let VID = 1;
  function create(world, type, x, y, opts) {
    const t = TYPES[type] || TYPES.sedan;
    opts = opts || {};
    const VR = VAMP.VehicleRoad;
    const axis = VR ? VR.roadAxisAt(world, x, y) : 0;
    const dir = Math.random() < 0.5 ? 1 : -1;
    const ang = opts.angle != null ? opts.angle : (VR ? VR.angleForAxis(axis, dir) : 0);
    return {
      id: VID++, type, ...{ ...t },
      x, y,
      angle: ang,
      roadAxis: axis, roadDir: dir,
      speed: 0, vx: 0, vy: 0,
      r: Math.max(t.w, t.h) * 0.5,
      maxHp: opts.hp || t.hp, hp: opts.hp || t.hp,
      color: opts.color || t.colors[(VID * 3) % t.colors.length],
      driver: opts.driver || null,         // null | 'player' | npc
      ai: opts.ai || (opts.driver && opts.driver !== 'player' ? true : false),
      aiDir: Math.random() < 0.5 ? 1 : -1,
      aiTurnCD: 0,
      smokeT: 0,
      burning: false,
      siren: t.siren && opts.siren,
      sirenPhase: 0,
    };
  }

  function update(v, dt, game) {
    if (v.hp <= 0 && !v.burning) { v.burning = true; v.burnT = 2.5; v.deathT = game.time; if (v.driver && v.driver !== 'player' && v.driver.dead === false) v.driver = null; if (VAMP.Audio) VAMP.Audio.play('crash'); }
    if (v.burning) {
      v.burnT -= dt;
      if (VAMP.FX && Math.random() < 0.6) VAMP.FX.spark(v.x + (Math.random() - 0.5) * v.w, v.y + (Math.random() - 0.5) * v.h, '#ff7a2a', 3);
      if (v.burnT <= 0 && !v.exploded) { explode(v, game); }
      v.speed *= 0.9;
    }

    if (v.driver === 'player') drivePlayer(v, dt, game);
    else if (v.ai && v.driver) driveAI(v, dt, game);
    else { v.speed *= Math.pow(0.2, dt); } // parked friction

    if (v.ai && v.driver && VAMP.VehicleRoad) VAMP.VehicleRoad.integrateAxis(v, dt);
    else {
      const moveAng = v.angle;
      v.x += Math.cos(moveAng) * v.speed * dt;
      v.y += Math.sin(moveAng) * v.speed * dt;
    }

    // collision with buildings
    const before = { x: v.x, y: v.y };
    const moved = game.world.collideCircle(v, v.r * 0.8);
    if (moved) {
      const impact = Math.abs(v.speed);
      if (impact > 140) {
        v.hp -= impact * 0.04 * dt * 60;
        if (game.cam && v.driver === 'player') game.cam.shake(Math.min(6, impact * 0.02), 0.15);
        if (VAMP.Audio && impact > 220 && Math.random() < 0.1) VAMP.Audio.play('crash');
      }
      v.speed *= 0.6;
    }
    if (v._inWater) { v.hp -= 40 * dt; v.speed *= 0.7; }

    // run over NPCs — ONLY the player's car. AI traffic does not mow down
    // pedestrians (and must never blame the player for ambient deaths).
    if (v.driver === 'player' && Math.abs(v.speed) > 120) {
      for (const n of game.npcs) {
        if (n.dead || n.ally) continue;
        if (U.dist2(v.x, v.y, n.x, n.y) < (v.r + n.r) * (v.r + n.r)) {
          const wasDead = n.dead;
          VAMP.Combat.damageNPC(game, n, Math.abs(v.speed) * 0.12, { knockback: Math.abs(v.speed) * 0.5, angle: v.angle, color: '#a00', cause: 'vehicle' });
          if (!wasDead && n.dead && n.innocent && game.masquerade) game.masquerade.witnessedAct(n.x, n.y, 'kill', 2);
        }
      }
    }

    v.x = U.clamp(v.x, 0, game.world.w);
    v.y = U.clamp(v.y, 0, game.world.h);

    if (v.siren) v.sirenPhase += dt * 8;
    // engine sound
    if (v.driver === 'player' && Math.abs(v.speed) > 30 && VAMP.Audio && Math.random() < 0.06) VAMP.Audio.play('engine');
  }

  function drivePlayer(v, dt, game) {
    const input = In();
    let throttle = 0, steer = 0;
    throttle = input.moveY() * -1; // W = up = forward (negative y)... but our forward is along angle
    // Use forward/back relative to facing: W accelerates forward, S brakes/reverse
    const fwd = (input.isDown('keyw') || input.isDown('arrowup')) ? 1 : 0;
    const back = (input.isDown('keys') || input.isDown('arrowdown')) ? 1 : 0;
    steer = ((input.isDown('keyd') || input.isDown('arrowright')) ? 1 : 0) - ((input.isDown('keya') || input.isDown('arrowleft')) ? 1 : 0);

    const accel = v.accel * (game.player.derived.vehicleHandling || 1);
    if (fwd) v.speed += accel * dt;
    else if (back) v.speed -= accel * 0.8 * dt;
    else v.speed *= Math.pow(0.55, dt); // coast/engine brake

    const max = v.maxSpeed * (game.player.derived.vehicleHandling || 1);
    v.speed = U.clamp(v.speed, -max * 0.4, max);

    // steering scales with speed (need to be moving)
    const speedRatio = U.clamp(Math.abs(v.speed) / 120, 0, 1);
    const handling = v.handling * (game.player.derived.vehicleHandling || 1);
    v.angle += steer * handling * dt * speedRatio * (v.speed < 0 ? -1 : 1);

    // handbrake (space) -> drift
    if (input.isDown('space')) { v.speed *= Math.pow(0.25, dt); if (VAMP.FX && Math.abs(v.speed) > 100 && Math.random() < 0.5) VAMP.FX.skid(v.x, v.y); }
  }

  function driveAI(v, dt, game) {
    const world = game.world;
    const VR = VAMP.VehicleRoad;
    if (!VR) return;
    v.aiTurnCD -= dt;
    const cruise = v.maxSpeed * 0.42;
    const axis = v.roadAxis != null ? v.roadAxis : VR.axisFromAngle(v.angle);
    const dir = v.roadDir != null ? v.roadDir : 1;
    const ahead = VR.probe(world, v.x, v.y, axis, dir, 56);
    if (!ahead || v.aiTurnCD <= 0) {
      const pick = VR.pickAxis(v, world);
      v.roadAxis = pick.axis;
      v.roadDir = pick.dir;
      v.angle = VR.angleForAxis(pick.axis, pick.dir);
      v.aiTurnCD = 1.4 + Math.random() * 1.2;
    }
    let target = cruise;
    const p = game.player;
    const pv = p.inVehicle || p;
    const lookX = v.x + Math.cos(v.angle) * 48;
    const lookY = v.y + Math.sin(v.angle) * 48;
    if (U.dist(lookX, lookY, pv.x, pv.y) < 52) target = 0;
    else if (!VR.probe(world, v.x, v.y, v.roadAxis, v.roadDir, 56)) target = cruise * 0.2;
    v.speed = U.approach(v.speed, target, v.accel * dt);
  }

  function explode(v, game) {
    v.exploded = true; v.dead = true;
    if (VAMP.FX) { VAMP.FX.explosion(v.x, v.y); }
    if (VAMP.Audio) VAMP.Audio.play('explode');
    if (game.cam) game.cam.shake(14, 0.5);
    // AoE damage — only the PLAYER's own car blast is attributed to the player.
    // Ambient/AI/parked car explosions must not credit the player (lifesteal/crit)
    // nor charge them humanity/XP for bystanders caught in the blast.
    // a blast is the player's fault only while driving, or within a few seconds of bailing out (you
    // ditched a burning car). A long-abandoned car that later blows up is NOT on you — otherwise the
    // city would turn hostile for a death you had nothing to do with (a calm-world violation).
    const byPlayer = v.driver === 'player' || (v.lastDriver === 'player' && (game.time - (v.lastDriveT || -1e9)) < 6);
    for (const n of game.npcs) {
      if (n.dead || U.dist(v.x, v.y, n.x, n.y) >= 90) continue;
      const ang = U.angleTo(v.x, v.y, n.x, n.y);
      if (byPlayer) VAMP.Combat.damageNPC(game, n, 80, { knockback: 300, angle: ang, cause: 'explosion' });
      else VAMP.Combat.damageNpcByNpc(game, v, n, 80, { knockback: 300, angle: ang });
    }
    const p = game.player;
    const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
    if (U.dist(v.x, v.y, px, py) < 90) {
      if (p.inVehicle === v) { exit(p, game, true); }
      VAMP.Combat.damagePlayer(game, 60, { unavoidable: true });
    }
  }

  // ---- enter / exit ----
  function enter(p, v, game) {
    if (v.burning || v.dead) return false;
    p.inVehicle = v; v.driver = 'player'; v.ai = false; v.lastDriver = 'player';
    p.x = v.x; p.y = v.y;
    if (VAMP.Audio) VAMP.Audio.play('ui');
    if (VAMP.UI) VAMP.UI.notify('Entered ' + v.type, '#9bf');
    game.bus && game.bus.emit('enterVehicle', v);
    return true;
  }
  function exit(p, game, ejected) {
    const v = p.inVehicle;
    if (!v) return;
    v.driver = null; v.lastDriveT = game.time; v.speed *= 0.3;   // stamp the bail-out time for blast attribution
    p.inVehicle = null;
    // place beside car
    const a = v.angle + Math.PI / 2;
    p.x = v.x + Math.cos(a) * (v.r + 12);
    p.y = v.y + Math.sin(a) * (v.r + 12);
    if (game.world.pointBlocked(p.x, p.y, p.r)) { p.x = v.x - Math.cos(a) * (v.r + 12); p.y = v.y - Math.sin(a) * (v.r + 12); }
    game.bus && game.bus.emit('exitVehicle', v);
  }

  function render(v, ctx) {
    // #11 — headlight cones at night (additive glow ahead of the car)
    const darkness = (window.VAMP && VAMP.Game ? VAMP.Game.darkness : 0) || 0;
    if (darkness > 0.15 && !v.burning) {
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      ctx.translate(v.x, v.y);
      ctx.rotate(v.angle);
      const a = 0.22 * darkness;
      const grad = ctx.createLinearGradient(v.w / 2, 0, v.w / 2 + 120, 0);
      grad.addColorStop(0, 'rgba(255,240,180,' + a + ')');
      grad.addColorStop(1, 'rgba(255,240,180,0)');
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.moveTo(v.w / 2, -v.h * 0.35);
      ctx.lineTo(v.w / 2 + 120, -55);
      ctx.lineTo(v.w / 2 + 120, 55);
      ctx.lineTo(v.w / 2, v.h * 0.35);
      ctx.closePath(); ctx.fill();
      ctx.restore();
    }
    ctx.save();
    ctx.translate(v.x, v.y);
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.save(); ctx.rotate(v.angle); ctx.fillRect(-v.w / 2 + 3, -v.h / 2 + 4, v.w, v.h); ctx.restore();
    ctx.rotate(v.angle);
    const vKey = VAMP.PropVariants ? VAMP.PropVariants.vehicleKey(v.type) : 'vehicle_sedan';
    const useCar = VAMP.Assets.ready && VAMP.Assets.get(vKey);
    if (useCar) {
      VAMP.Assets.drawKey(ctx, vKey, 0, 0, { w: v.w * 1.45, h: v.h * 1.45, ax: 0.5, ay: 0.5, tint: v.color, smooth: true });
    } else {
      const grd = ctx.createLinearGradient(0, -v.h / 2, 0, v.h / 2);
      grd.addColorStop(0, U.shade(v.color, 0.18));
      grd.addColorStop(0.5, v.color);
      grd.addColorStop(1, U.shade(v.color, -0.3));
      ctx.fillStyle = grd;
      roundRect(ctx, -v.w / 2, -v.h / 2, v.w, v.h, 5); ctx.fill();
    }
    if (!useCar) {
    // windshield
    ctx.fillStyle = 'rgba(120,170,210,0.55)';
    roundRect(ctx, v.w * 0.06, -v.h / 2 + 4, v.w * 0.26, v.h - 8, 3); ctx.fill();
    ctx.fillStyle = 'rgba(90,130,170,0.45)';
    roundRect(ctx, -v.w * 0.30, -v.h / 2 + 4, v.w * 0.22, v.h - 8, 3); ctx.fill();
    // roof line
    ctx.strokeStyle = 'rgba(0,0,0,0.3)'; ctx.lineWidth = 1;
    ctx.strokeRect(-v.w * 0.06, -v.h / 2 + 3, v.w * 0.12, v.h - 6);
    // headlights
    ctx.fillStyle = 'rgba(255,240,180,0.9)';
    ctx.fillRect(v.w / 2 - 3, -v.h / 2 + 2, 3, 4); ctx.fillRect(v.w / 2 - 3, v.h / 2 - 6, 3, 4);
    }
    // siren
    if (v.siren) {
      const on = Math.sin(v.sirenPhase) > 0;
      ctx.fillStyle = on ? '#ff3a3a' : '#3a6aff';
      ctx.fillRect(-3, -v.h / 2, 6, 4);
    }
    // moonlight rim — a cool edge highlight so the car silhouette separates from dark
    // asphalt (top-down cars were reading as invisible black blobs at night otherwise).
    if (!v.burning) {
      ctx.strokeStyle = 'rgba(164,184,224,0.40)';
      ctx.lineWidth = 1.3;
      roundRect(ctx, -v.w / 2 + 0.6, -v.h / 2 + 0.6, v.w - 1.2, v.h - 1.2, 5); ctx.stroke();
    }
    ctx.restore();

    // damage smoke
    if (v.hp < v.maxHp * 0.4 && !v.burning) {
      ctx.fillStyle = 'rgba(40,40,40,0.4)';
      ctx.beginPath(); ctx.arc(v.x - Math.cos(v.angle) * v.w * 0.4, v.y - Math.sin(v.angle) * v.w * 0.4, 6, 0, U.TAU); ctx.fill();
    }
  }

  function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  VAMP.Vehicle = { create, update, render, enter, exit, TYPES };
})();
