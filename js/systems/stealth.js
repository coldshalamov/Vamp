/* =========================================================================
 * VAMPIRE CITY — systems/stealth.js  (VAMP.Stealth)
 * The predator's craft — an OPTIONAL way to play that rewards patience:
 *   - light/shadow VISIBILITY + directional vision cones (slip behind a mark)
 *   - behind-the-back silent TAKEDOWNS (grab any unaware foe into a feed)
 *   - a non-lethal feed leaves the victim UNCONSCIOUS — a body that can be FOUND
 *   - a discovered body raises an investigation: a danger zone where police
 *     converge and you're hunted if seen at the scene
 *   - a fleeing WITNESS runs to raise the alarm — silence them first
 *   - DRAG the body off and DUMP it (dumpster / manhole) or stash it in shadow
 * Pure systemic layer over the existing NPC / masquerade machinery; no new
 * persistent entities (bodies ARE npcs, so they ride normal culling & cleanup).
 * Load after world/render.js + masquerade.js, before missions.js.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const T = VAMP.World.T;

  // matches props.js placement hash so dump points line up with the drawn dumpsters/manholes
  function hash2(c, r, seed) { let h = (c * 374761393 + r * 668265263 + (seed | 0) * 0x9E3779B1) | 0; h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; }

  let acc = 0;

  // is a world point under a streetlamp (or daylight)? drives exposure + alley-hiding.
  function isLit(game, x, y) {
    if (game.timeOfDay && game.timeOfDay.day) return true;
    const world = game.world, TILE = world.TILE;
    const lamp = VAMP.WorldRender && VAMP.WorldRender.lampHere;
    if (!lamp) return false;
    const c0 = Math.floor(x / TILE), r0 = Math.floor(y / TILE);
    for (let dr = -2; dr <= 2; dr++) for (let dc = -2; dc <= 2; dc++) {
      const c = c0 + dc, r = r0 + dr;
      if (c < 0 || r < 0 || c >= world.cols || r >= world.rows) continue;
      if (world.tile[world.idx(c, r)] === T.SIDEWALK && lamp(c, r) && U.dist(x, y, (c + 0.5) * TILE, (r + 0.5) * TILE) < TILE * 2.0) return true;
    }
    return false;
  }

  // 0.05..1.1 — how visible the player is right now. fed into npc.canSee's range.
  function exposure(p, game) {
    let e = 0.55;
    if (p.sprinting) e += 0.30;
    else if (!p.moving) e -= 0.15;
    if (p.sneaking) e -= 0.35;
    if (isLit(game, p.x, p.y)) e += 0.25; else e -= 0.20;
    if (p.bloodState && p.bloodState.frenzied) e += 0.20;
    if (p.toggles && Object.values(p.toggles).some(Boolean)) e += 0.10;
    return U.clamp(e, 0.05, 1.1);
  }

  function isBody(n) { return !n.ally && (n.downed || (n.dead && !n._disposed)); }

  // nearest corpse / unconscious body on the ground within rad px
  function nearestBody(game, x, y, rad) {
    let best = null, bd = rad;
    for (const n of game.npcs) {
      if (!isBody(n) || n.carried) continue;
      const d = U.dist(x, y, n.x, n.y);
      if (d < bd) { bd = d; best = n; }
    }
    return best;
  }

  // nearest dumpster/manhole (seed-derived, matches props.js) within rad px
  function nearestDumpSpot(world, x, y, rad) {
    const TILE = world.TILE, tr = Math.ceil(rad / TILE);
    const c0 = Math.floor(x / TILE), r0 = Math.floor(y / TILE);
    let best = null, bd = rad;
    for (let dr = -tr; dr <= tr; dr++) for (let dc = -tr; dc <= tr; dc++) {
      const c = c0 + dc, r = r0 + dr;
      if (c < world.border || r < world.border || c >= world.cols - world.border || r >= world.rows - world.border) continue;
      const t = world.tile[world.idx(c, r)];
      const hs = hash2(c, r, world.seed);
      let kind = null;
      if ((t === T.DIRT || t === T.CONCRETE) && hs < 0.04) kind = 'dumpster';
      else if (t === T.ROAD && hs < 0.03) kind = 'manhole';
      if (!kind) continue;
      const cx = (c + 0.5) * TILE, cy = (r + 0.5) * TILE, d = U.dist(x, y, cx, cy);
      if (d < bd) { bd = d; best = { x: cx, y: cy, kind }; }
    }
    return best;
  }

  // a feed/strike-free silent takedown target: a foe who is unaware (in your
  // rear arc or can't see you) and not already alerted. Lets you grab ANYONE.
  function findStealthTarget(p, game) {
    let best = null, bd = 44;
    for (const n of game.npcs) {
      if (n.dead || n.ally || n.boss || n.downed) continue;
      if (n.aggro || n.state === 'chase' || n.state === 'attack') continue;
      const d = U.dist(p.x, p.y, n.x, n.y);
      if (d > bd) continue;
      const rear = Math.abs(U.wrapAngle(U.angleTo(n.x, n.y, p.x, p.y) - n.angle)) > 1.3;
      const unaware = rear || !(VAMP.Npc && VAMP.Npc.canSee(n, p, game));
      if (!unaware) continue;
      bd = d; best = n;
    }
    return best;
  }

  // collapse a victim into an unconscious body (a non-lethal feed, or a soft KO)
  function knockOut(npc, game) {
    if (!npc || npc.dead) return;
    npc.downed = true; npc.downT = game.time; npc.wakeDur = 34 + Math.random() * 16;
    npc.state = 'downed'; npc.path = null; npc.aggro = false; npc.hostileToPlayer = false;
    npc.vx = npc.vy = 0; npc.mesmerizedT = 0; npc.discovered = false;
  }

  // ---- carry / dump (driven by the E interact key, context-aware) ----
  // returns true if it consumed the interaction
  function handleBody(p, game) {
    if (p.carrying) {
      const dump = nearestDumpSpot(game.world, p.x, p.y, 52);
      if (dump) { disposeBody(p, game, dump); return true; }
      dropBody(p, game); return true;
    }
    const body = nearestBody(game, p.x, p.y, 42);
    if (body) {
      p.carrying = body; body.carried = true;
      if (VAMP.UI) VAMP.UI.notify('Hefting the body — a dumpster/manhole erases it, or stash it in shadow', '#b9a');
      return true;
    }
    return false;
  }
  function dropBody(p, game) {
    const b = p.carrying; if (!b) return;
    b.carried = false; b.x = p.x; b.y = p.y; b.discovered = false;
    b.hidden = !isLit(game, p.x, p.y);   // shadow stash = much harder to find
    p.carrying = null;
    if (VAMP.UI) VAMP.UI.notify(b.hidden ? 'Body stashed in shadow — far harder to spot' : 'Body dropped in the open — exposed', b.hidden ? '#7c9' : '#c96');
  }
  function disposeBody(p, game, dump) {
    const b = p.carrying; if (!b) return;
    b._disposed = true; b.dead = true; b.downed = false; b.carried = false;
    b.deathT = game.time - 100;          // flag for immediate cull — gone as evidence
    p.carrying = null;
    if (game.investigations) for (const inv of game.investigations) if (U.dist(inv.x, inv.y, dump.x, dump.y) < 260) inv.t = inv.ttl + 1;
    if (VAMP.Mastery) VAMP.Mastery.gain(p, 'predation', 8);
    if (VAMP.FX) VAMP.FX.shadow(dump.x, dump.y, 22);
    if (VAMP.Audio) VAMP.Audio.play('ui');
    if (VAMP.UI) VAMP.UI.notify('Evidence gone — the ' + dump.kind + ' swallows the body', '#7c9');
  }

  function update(dt, game) {
    if (!game.investigations) game.investigations = [];
    const p = game.player;

    // a carried body trails just behind you
    if (p.carrying) {
      const b = p.carrying;
      if (!b || b._disposed) p.carrying = null;
      else { b.x = p.x - Math.cos(p.facing) * 16; b.y = p.y - Math.sin(p.facing) * 16; b.angle = p.facing; }
    }

    // advance investigations every frame (cheap, few of them)
    for (let i = game.investigations.length - 1; i >= 0; i--) {
      const inv = game.investigations[i]; inv.t += dt;
      if (inv.t >= inv.ttl) { game.investigations.splice(i, 1); continue; }
      // caught at the scene: if you linger visibly inside the zone, the law converges on YOU
      if (!p.cloaked && U.dist(p.x, p.y, inv.x, inv.y) < inv.r && exposure(p, game) > 0.3) {
        inv.hot = true; inv.t = Math.min(inv.t, inv.ttl - 4);   // keep it alive while you're present
        for (const n of game.npcs) {
          if (n.dead || n.ally) continue;
          if ((n.faction === 'police' || n.responder) && U.dist(n.x, n.y, inv.x, inv.y) < inv.r + 240) {
            n.hostileToPlayer = true; n.aggro = true;
            if (n.state === 'wander' || n.state === 'investigate') n.state = 'chase';
          }
        }
      }
    }

    // throttle the heavier body scan
    acc += dt;
    if (acc < 0.18) return;
    const adt = acc; acc = 0;
    const px = p.x, py = p.y;

    // body discovery
    for (const b of game.npcs) {
      if (!isBody(b) || b.carried || b.discovered) continue;
      if (U.dist(px, py, b.x, b.y) > 760) continue;     // only matters near the player
      const findRange = b.hidden ? 46 : 132;
      let finder = null;
      for (const n of game.npcs) {
        if (n === b || n.dead || n.ally || n.downed) continue;
        if (n.faction !== 'civ' && n.faction !== 'police') continue;
        if (n.aggro) continue;
        if (U.dist(n.x, n.y, b.x, b.y) < findRange) { finder = n; break; }
      }
      if (!finder) continue;
      b.discovered = true;
      game.investigations.push({ x: b.x, y: b.y, r: 150, t: 0, ttl: 22, hot: false });
      game.masquerade.witnessedAct(b.x, b.y, 'body', 1.0);
      if (game.addBlip) game.addBlip({ x: b.x, y: b.y, color: '#ff7a30', kind: 'event', ttl: game.time + 22 });
      if (finder.faction === 'civ') {
        finder.state = 'flee'; finder.fleeT = 6; finder.witness = true; finder.witnessT = game.time + 6.5;
        if (game.addBlip) game.addBlip({ ref: finder, color: '#ffd24a', kind: 'event', ttl: game.time + 7 });
      } else { finder.state = 'investigate'; finder.investigateX = b.x; finder.investigateY = b.y; finder.investigateT = 6; }
      if (VAMP.UI) VAMP.UI.notify('A body has been found!', '#ff7a30');
      if (VAMP.Audio) VAMP.Audio.play('siren');
    }

    // a fleeing witness who survives the countdown raises the alarm (a heat spike)
    for (const n of game.npcs) {
      if (n.dead || !n.witness) continue;
      if (game.time >= n.witnessT) { n.witness = false; game.masquerade.add(1.0); if (VAMP.UI) VAMP.UI.notify('The witness reached the law — heat rises!', '#ff5a5a'); }
    }

    // carrying a body past mortal eyes is its own crime
    if (p.carrying && !p.cloaked) {
      for (const n of game.npcs) {
        if (n.dead || n.ally || n.downed) continue;
        if ((n.faction === 'civ' || n.faction === 'police') && !n.witness && U.dist(n.x, n.y, p.x, p.y) < 170) { game.masquerade.add(0.6 * adt); break; }
      }
    }
  }

  function render(ctx, game) {
    if (!game.investigations || !game.investigations.length) return;
    ctx.save();
    for (const inv of game.investigations) {
      const k = U.clamp(1 - inv.t / inv.ttl, 0, 1);
      const pulse = 0.3 + 0.25 * Math.abs(Math.sin(game.time * 4));
      ctx.globalAlpha = pulse * k;
      ctx.strokeStyle = inv.hot ? '#ff3030' : '#ff9a30';
      ctx.lineWidth = 2; ctx.setLineDash([8, 8]);
      ctx.beginPath(); ctx.arc(inv.x, inv.y, inv.r, 0, U.TAU); ctx.stroke();
      ctx.setLineDash([]);
      ctx.globalAlpha = pulse * k * 0.85; ctx.fillStyle = inv.hot ? '#ff5a5a' : '#ffb060';
      ctx.font = 'bold 9px Verdana'; ctx.textAlign = 'center';
      ctx.fillText(inv.hot ? 'CRIME SCENE' : 'INVESTIGATING', inv.x, inv.y - inv.r - 4);
    }
    ctx.restore();
    ctx.textAlign = 'left';
  }

  VAMP.Stealth = {
    update, render, isLit, exposure, isBody, nearestBody, nearestDumpSpot,
    findStealthTarget, knockOut, handleBody,
  };
})();
