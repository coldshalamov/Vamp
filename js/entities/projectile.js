/* =========================================================================
 * VAMPIRE CITY — entities/projectile.js
 * Bullets & spell projectiles. owner: 'player' | 'npc'. Supports pierce,
 * homing, AoE on impact, status application, trails.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const C = () => VAMP.Combat;

  function make(opts) {
    return {
      x: opts.x, y: opts.y,
      vx: opts.vx || 0, vy: opts.vy || 0,
      r: opts.r || 4,
      dmg: opts.dmg || 10,
      owner: opts.owner || 'player',
      color: opts.color || '#fff',
      glow: opts.glow,
      life: opts.life || 1.4,
      maxLife: opts.life || 1.4,
      pierce: opts.pierce || 0,
      hits: 0,
      hitSet: new Set(),
      homing: opts.homing || 0,
      target: opts.target || null,
      aoe: opts.aoe || 0,
      aoeDmg: opts.aoeDmg || 0,
      status: opts.status || null,    // {kind,dur,dps,...}
      knockback: opts.knockback || 0,
      crit: opts.crit,
      dmgType: opts.dmgType || null,
      gravity: opts.gravity || 0,
      trail: [],
      kind: opts.kind || 'bolt',
      dead: false,
      onImpact: opts.onImpact || null,
    };
  }

  function update(pr, dt, game) {
    if (pr.dead) return;
    pr.life -= dt;
    if (pr.life <= 0) { explode(pr, game); pr.dead = true; return; }

    // homing
    if (pr.homing > 0) {
      let tgt = pr.target;
      if (pr.owner === 'player' && (!tgt || tgt.dead)) tgt = game.nearestNPC(pr.x, pr.y, (n) => !n.dead && !n.ally && n.faction !== 'civ' && n.faction !== 'animal', 600);
      pr.target = tgt;
      if (tgt && !tgt.dead) {
        const a = U.angleTo(pr.x, pr.y, tgt.x, tgt.y);
        const sp = Math.hypot(pr.vx, pr.vy);
        const ca = Math.atan2(pr.vy, pr.vx);
        const na = U.angleLerp(ca, a, U.clamp(pr.homing * dt, 0, 1));
        pr.vx = Math.cos(na) * sp; pr.vy = Math.sin(na) * sp;
      }
    }
    if (pr.gravity) pr.vy += pr.gravity * dt;

    const nx = pr.x + pr.vx * dt;
    const ny = pr.y + pr.vy * dt;

    // trail — reuse fixed slot objects (after it fills) instead of push/shift'ing a new {x,y} every frame
    const tr = pr.trail;
    if (tr.length < 8) tr.push({ x: pr.x, y: pr.y });
    else { for (let i = 0; i < 7; i++) { tr[i].x = tr[i + 1].x; tr[i].y = tr[i + 1].y; } tr[7].x = pr.x; tr[7].y = pr.y; }

    // world collision (buildings/water)
    if (game.world.pointBlocked(nx, ny, pr.r)) { explode(pr, game); pr.dead = true; return; }
    const ox = pr.x, oy = pr.y;   // for swept (anti-tunneling) collision
    pr.x = nx; pr.y = ny;

    // entity collision — swept segment vs circle so fast shots never tunnel
    if (pr.owner === 'player') {
      const hits = [];
      for (const n of game.npcs) {
        if (n.dead || n.ally || pr.hitSet.has(n)) continue;
        if (U.segCircle(ox, oy, pr.x, pr.y, n.x, n.y, pr.r + n.r)) hits.push(n);
      }
      if (hits.length > 1) hits.sort((a, b) => U.dist2(ox, oy, a.x, a.y) - U.dist2(ox, oy, b.x, b.y));
      for (const n of hits) { hitNPC(pr, n, game); if (pr.dead) return; }
    } else {
      const p = game.player;
      if (p && !p.dead && !p.inVehicle && U.segCircle(ox, oy, pr.x, pr.y, p.x, p.y, pr.r + p.r)) {
        C().damagePlayer(game, pr.dmg, { type: pr.kind });
        if (pr.status) C().applyStatus(p, pr.status.kind, pr.status);
        explode(pr, game); pr.dead = true; return;
      }
      // npc bullets can also hit the player's vehicle
      if (p && p.inVehicle && U.segCircle(ox, oy, pr.x, pr.y, p.inVehicle.x, p.inVehicle.y, pr.r + p.inVehicle.r)) {
        p.inVehicle.hp -= pr.dmg; explode(pr, game); pr.dead = true; return;
      }
    }
  }

  function hitNPC(pr, n, game) {
    pr.hitSet.add(n);
    pr.hits++;
    C().damageNPC(game, n, pr.dmg, { knockback: pr.knockback, angle: Math.atan2(pr.vy, pr.vx), color: pr.color, crit: pr.crit, type: pr.kind, dmgType: pr.dmgType });
    if (pr.status) C().applyStatus(n, pr.status.kind, pr.status);
    if (pr.onImpact) pr.onImpact(pr, n, game);
    if (pr.hits > pr.pierce) { explode(pr, game); pr.dead = true; }
  }

  function explode(pr, game) {
    if (pr.aoe > 0) {
      if (VAMP.FX) VAMP.FX.ring(pr.x, pr.y, pr.aoe, pr.color);
      const list = pr.owner === 'player' ? game.npcs : [game.player];
      for (const n of list) {
        if (!n || n.dead) continue;
        if (U.dist2(pr.x, pr.y, n.x, n.y) < pr.aoe * pr.aoe) {
          if (pr.owner === 'player') {
            C().damageNPC(game, n, pr.aoeDmg || pr.dmg * 0.6, { knockback: pr.knockback, color: pr.color });
            if (pr.status) C().applyStatus(n, pr.status.kind, pr.status);
          } else {
            C().damagePlayer(game, pr.aoeDmg || pr.dmg * 0.6, {});
          }
        }
      }
    }
    if (VAMP.FX) VAMP.FX.spark(pr.x, pr.y, pr.color, 6);
  }

  function render(pr, ctx) {
    const useBmp = VAMP.ArtFlags && VAMP.ArtFlags.useBitmapFX && VAMP.Assets.ready && VAMP.Assets.has('projectile_blood')
      && (pr.kind === 'bolt' || pr.glow);
    const ang = Math.atan2(pr.vy, pr.vx);
    if (useBmp) {
      for (let i = 0; i < pr.trail.length; i++) {
        const t = pr.trail[i];
        const a = (i / pr.trail.length) * 0.45;
        ctx.save();
        ctx.globalAlpha = a;
        ctx.translate(t.x, t.y);
        ctx.rotate(ang);
        const pKey = pr.kind === 'shadow' ? 'projectile_blood' : pr.kind === 'bullet' ? 'projectile_blood' : 'projectile_blood';
        const pTint = pr.kind === 'shadow' ? (pr.color || '#6040a0') : pr.kind === 'bullet' ? (pr.color || '#e8e0c0') : pr.color;
        VAMP.Assets.drawKey(ctx, pKey, 0, 0, { w: pr.r * 5, h: pr.r * 2.2, ax: 0.5, ay: 0.5, tint: pTint });
        ctx.restore();
      }
      ctx.save();
      ctx.translate(pr.x, pr.y);
      ctx.rotate(ang);
      const pTint = pr.kind === 'shadow' ? (pr.color || '#6040a0') : pr.kind === 'bullet' ? (pr.color || '#e8e0c0') : pr.color;
      if (pr.glow) {
        ctx.globalAlpha = 0.35;
        VAMP.Assets.drawKey(ctx, 'projectile_blood', 0, 0, { w: pr.r * 7, h: pr.r * 3.2, ax: 0.5, ay: 0.5, tint: pTint });
      }
      ctx.globalAlpha = 1;
      VAMP.Assets.drawKey(ctx, 'projectile_blood', 0, 0, { w: pr.r * 5.5, h: pr.r * 2.6, ax: 0.5, ay: 0.5, tint: pTint });
      ctx.restore();
      return;
    }
    for (let i = 0; i < pr.trail.length; i++) {
      const t = pr.trail[i];
      const a = (i / pr.trail.length) * 0.5;
      ctx.fillStyle = pr.color;
      ctx.globalAlpha = a;
      ctx.beginPath(); ctx.arc(t.x, t.y, pr.r * (i / pr.trail.length), 0, U.TAU); ctx.fill();
    }
    ctx.globalAlpha = 1;
    if (pr.glow) {
      ctx.fillStyle = pr.color; ctx.globalAlpha = 0.3;
      ctx.beginPath(); ctx.arc(pr.x, pr.y, pr.r * 2.4, 0, U.TAU); ctx.fill();
      ctx.globalAlpha = 1;
    }
    ctx.fillStyle = pr.color;
    ctx.beginPath(); ctx.arc(pr.x, pr.y, pr.r, 0, U.TAU); ctx.fill();
    ctx.fillStyle = '#fff'; ctx.globalAlpha = 0.7;
    ctx.beginPath(); ctx.arc(pr.x, pr.y, pr.r * 0.45, 0, U.TAU); ctx.fill();
    ctx.globalAlpha = 1;
  }

  VAMP.Projectile = { make, update, render };
})();
