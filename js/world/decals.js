/* =========================================================================
 * VAMPIRE CITY — world/decals.js
 * Ground decals: puddles, cracks, litter, graffiti, manholes, tire marks.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const T = VAMP.World.T;
  const CAP = 280;
  const pool = [];
  for (let i = 0; i < CAP; i++) pool.push({ x: 0, y: 0, k: 'crack', r: 8, rot: 0, a: 0.5, col: '#888', life: 0 });

  function hash2(c, r, seed, salt) {
    let h = (c * 374761393 + r * 668265263 + (seed | 0) * 0x9E3779B1 + (salt | 0) * 1013) | 0;
    h = Math.imul(h ^ (h >>> 13), 1274126177);
    return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
  }

  function spawn(x, y, k, r, col, extra) {
    let slot = null;
    for (const d of pool) { if (!d.life || d.life <= 0) { slot = d; break; } }
    if (!slot) slot = pool[(Math.random() * CAP) | 0];
    slot.x = x; slot.y = y; slot.k = k; slot.r = r || 8;
    slot.rot = Math.random() * U.TAU; slot.a = 0.32 + Math.random() * 0.28;
    slot.col = col || '#888';
    slot.label = extra && extra.label ? extra.label : null;
    slot.life = k === 'puddle' ? 9999 : 99999;
  }

  function seedWorld(world) {
    const TILE = world.TILE;
    const seed = world.seed | 0;
    let n = 0;
    for (let r = world.border; r < world.rows - world.border && n < CAP * 0.85; r++) {
      for (let c = world.border; c < world.cols - world.border && n < CAP * 0.85; c++) {
        const t = world.tile[world.idx(c, r)];
        const hs = hash2(c, r, seed, 71);
        const cx = (c + 0.5) * TILE, cy = (r + 0.5) * TILE;
        if (t === T.ROAD) {
          if (hs < 0.04) { spawn(cx, cy, 'manhole', 7); n++; }
          else if (hs > 0.96) { spawn(cx, cy, 'tire', 10); n++; }
          else if (hs > 0.92 && hs < 0.94) { spawn(cx, cy, 'crack', 9); n++; }
        } else if (t === T.SIDEWALK) {
          const dist = world.districtAt(cx, cy);
          const did = dist ? dist.id : 'downtown';
          const wt = VAMP.DistrictArt && VAMP.DistrictArt.decalWeight ? VAMP.DistrictArt.decalWeight(did) : 1;
          if (hs < 0.025 * wt) { spawn(cx, cy, 'litter', 5); n++; }
          else if (hs > 1 - 0.03 * wt) {
            const col = VAMP.DistrictArt ? VAMP.DistrictArt.kitAccent(did) : '#a06090';
            spawn(cx, cy, 'graffiti', 12, col, {
              label: VAMP.PropVariants ? VAMP.PropVariants.graffitiTag(c, r, seed) : 'TAG',
            });
            n++;
          }
          else if (hs > 0.88 && hs < 0.9) { spawn(cx, cy, 'crack', 7); n++; }
          else if (did === 'industrial' && hs > 0.85 && hs < 0.87) { spawn(cx, cy, 'stain', 9); n++; }
          else if (did === 'redlight' && hs > 0.82 && hs < 0.84) { spawn(cx, cy, 'tire', 8); n++; }
        } else if ((t === T.DIRT || t === T.CONCRETE) && hs < 0.03) {
          spawn(cx, cy, 'stain', 8); n++;
        }
      }
    }
  }

  function tickRain(game) {
    if (!game.weather || game.weather.kind !== 'rain') return;
    const p = game.player;
    const px = p.inVehicle ? p.inVehicle.x : p.x;
    const py = p.inVehicle ? p.inVehicle.y : p.y;
    if (Math.random() > 0.035) return;
    const a = Math.random() * U.TAU, d = U.range(40, 220);
    const x = px + Math.cos(a) * d, y = py + Math.sin(a) * d;
    if (game.world.isRoad(x, y) || game.world.tileAt(x, y) === T.SIDEWALK) spawn(x, y, 'puddle', U.range(10, 22));
  }

  function drawDecal(ctx, d) {
    if (d.k === 'puddle' && VAMP.Assets.has('puddle_decal')) {
      VAMP.Assets.drawKey(ctx, 'puddle_decal', 0, 0, { w: d.r * 2, h: d.r * 1.4, ax: 0.5, ay: 0.5 });
    } else if (d.k === 'puddle') {
      ctx.fillStyle = 'rgba(100,140,200,0.18)';
      ctx.beginPath(); ctx.ellipse(0, 0, d.r, d.r * 0.7, 0, 0, U.TAU); ctx.fill();
    } else if (d.k === 'manhole') {
      ctx.fillStyle = '#0c0d11';
      ctx.beginPath(); ctx.ellipse(0, 0, 7, 5, 0, 0, U.TAU); ctx.fill();
      ctx.strokeStyle = 'rgba(80,80,90,0.5)'; ctx.lineWidth = 1; ctx.stroke();
    } else if (d.k === 'crack') {
      ctx.strokeStyle = 'rgba(30,28,26,0.55)'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(-d.r, 0); ctx.lineTo(d.r, d.r * 0.3); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(0, -d.r * 0.5); ctx.lineTo(d.r * 0.4, d.r); ctx.stroke();
    } else if (d.k === 'litter') {
      ctx.fillStyle = 'rgba(60,58,52,0.55)'; ctx.fillRect(-3, -2, 6, 4);
      ctx.fillStyle = 'rgba(90,70,50,0.45)'; ctx.fillRect(1, 0, 4, 3);
    } else if (d.k === 'graffiti') {
      const label = d.label || 'TAG';
      ctx.fillStyle = 'rgba(10,8,14,0.35)';
      ctx.fillRect(-d.r * 0.6, -d.r * 0.35, d.r * 1.2, d.r * 0.7);
      ctx.fillStyle = d.col || '#a06090';
      ctx.globalAlpha *= 0.72;
      ctx.font = 'bold ' + Math.max(6, Math.min(8, d.r * 0.55)) + 'px monospace';
      ctx.textAlign = 'center';
      ctx.fillText(label, 0, 3);
      ctx.textAlign = 'left';
    } else if (d.k === 'tire') {
      ctx.strokeStyle = 'rgba(20,20,24,0.45)'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(-d.r, 0); ctx.quadraticCurveTo(0, d.r * 0.4, d.r, 0); ctx.stroke();
    } else if (d.k === 'stain') {
      ctx.fillStyle = 'rgba(50,48,44,0.35)';
      ctx.beginPath(); ctx.ellipse(0, 0, d.r, d.r * 0.6, 0, 0, U.TAU); ctx.fill();
    }
  }

  function render(ctx, cam, game) {
    tickRain(game);
    const wet = game.weather && game.weather.kind === 'rain' ? 1.12 : 1;
    for (const d of pool) {
      if (!d.life || d.life <= 0) continue;
      if (!cam.inView(d.x, d.y, d.r + 8)) continue;
      ctx.save();
      ctx.translate(d.x, d.y);
      ctx.rotate(d.rot);
      ctx.globalAlpha = d.a * (d.k === 'puddle' ? wet : 1);
      drawDecal(ctx, d);
      ctx.restore();
    }
    ctx.globalAlpha = 1;
  }

  VAMP.Decals = { spawn, seedWorld, render, pool };
})();