/* =========================================================================
 * VAMPIRE CITY — world/decals.js
 * Ground decals: cracks, puddles, manholes. View-culled pool.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const CAP = 180;
  const pool = [];
  for (let i = 0; i < CAP; i++) pool.push({ x: 0, y: 0, k: 0, r: 8, rot: 0, a: 0.5 });

  function spawn(x, y, k, r) {
    let slot = null;
    for (const d of pool) { if (d.life === 0 || d.life == null) { slot = d; break; } }
    if (!slot) slot = pool[(Math.random() * CAP) | 0];
    slot.x = x; slot.y = y; slot.k = k; slot.r = r || 8;
    slot.rot = Math.random() * U.TAU; slot.a = 0.35 + Math.random() * 0.25;
    slot.life = k === 'puddle' ? 9999 : 0;
  }

  function tickRain(game) {
    if (!game.weather || game.weather.kind !== 'rain') return;
    const p = game.player;
    const px = p.inVehicle ? p.inVehicle.x : p.x;
    const py = p.inVehicle ? p.inVehicle.y : p.y;
    if (Math.random() > 0.04) return;
    const a = Math.random() * U.TAU, d = U.range(40, 220);
    const x = px + Math.cos(a) * d, y = py + Math.sin(a) * d;
    if (game.world.isRoad(x, y) || game.world.tileAt(x, y) === VAMP.World.T.SIDEWALK) spawn(x, y, 'puddle', U.range(10, 22));
  }

  function render(ctx, cam, game) {
    tickRain(game);
    for (const d of pool) {
      if (!cam.inView(d.x, d.y, d.r)) continue;
      ctx.save();
      ctx.translate(d.x, d.y);
      ctx.rotate(d.rot);
      ctx.globalAlpha = d.a;
      if (d.k === 'puddle' && VAMP.Assets.has('puddle_decal')) {
        VAMP.Assets.drawKey(ctx, 'puddle_decal', 0, 0, { w: d.r * 2, h: d.r * 1.4, ax: 0.5, ay: 0.5 });
      } else if (d.k === 'puddle') {
        ctx.fillStyle = 'rgba(100,140,200,0.18)';
        ctx.beginPath(); ctx.ellipse(0, 0, d.r, d.r * 0.7, 0, 0, U.TAU); ctx.fill();
      } else if (d.k === 'manhole') {
        ctx.fillStyle = '#0c0d11';
        ctx.beginPath(); ctx.ellipse(0, 0, 7, 5, 0, 0, U.TAU); ctx.fill();
      } else if (d.k === 'crack') {
        ctx.strokeStyle = 'rgba(30,28,26,0.55)'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(-d.r, 0); ctx.lineTo(d.r, d.r * 0.3); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(0, -d.r * 0.5); ctx.lineTo(d.r * 0.4, d.r); ctx.stroke();
      }
      ctx.restore();
    }
    ctx.globalAlpha = 1;
  }

  VAMP.Decals = { spawn, render, pool };
})();