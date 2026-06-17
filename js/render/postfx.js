/* =========================================================================
 * VAMPIRE CITY — render/postfx.js
 * District color grade, film grain, heat edge pulse, feeding frame.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  let grainCanvas = null;

  function ensureGrain(w, h) {
    if (grainCanvas && grainCanvas.width === w && grainCanvas.height === h) return grainCanvas;
    grainCanvas = VAMP.Assets.makeCanvas(w, h);
    const g = grainCanvas.getContext('2d');
    const d = g.createImageData(w, h);
    const rng = U.makeRNG(4242);
    for (let i = 0; i < d.data.length; i += 4) {
      const v = (rng() * 255) | 0;
      d.data[i] = d.data[i + 1] = d.data[i + 2] = v;
      d.data[i + 3] = 18;
    }
    g.putImageData(d, 0, 0);
    return grainCanvas;
  }

  function districtGrade(ctx, game, w, h) {
    if (!VAMP.ArtFlags || !VAMP.ArtFlags.usePostFX || game.mode !== 'play' || !game.player) return;
    const dist = game.world && game.world.districtAt(game.player.x, game.player.y);
    if (!dist || !VAMP.DistrictGrade) return;
    const g = VAMP.DistrictGrade[dist.id];
    if (!g) return;
    ctx.save();
    ctx.globalCompositeOperation = 'multiply';
    ctx.globalAlpha = g.alpha;
    ctx.fillStyle = g.color;
    ctx.fillRect(0, 0, w, h);
    ctx.restore();
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }

  function filmGrain(ctx, w, h, strength) {
    if (!VAMP.ArtFlags || !VAMP.ArtFlags.usePostFX || gameQualityLow()) return;
    const gc = ensureGrain(w, h);
    ctx.save();
    ctx.globalAlpha = strength || 0.035;
    ctx.globalCompositeOperation = 'overlay';
    ctx.drawImage(gc, 0, 0);
    ctx.restore();
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }

  function gameQualityLow() {
    const g = VAMP.Game;
    return g && g.quality === 'low';
  }

  function heatPulse(ctx, game, w, h) {
    const m = game.masquerade;
    if (!m || m.stars < 2) return;
    const a = 0.06 + m.stars * 0.025 + 0.02 * Math.sin(game.time * 6);
    const grad = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.35, w / 2, h / 2, Math.max(w, h) * 0.72);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(1, `rgba(120,0,20,${a})`);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);
    if (m.stars >= 4) {
      ctx.save();
      ctx.globalAlpha = 0.12 + 0.08 * Math.abs(Math.sin(game.time * 10));
      ctx.fillStyle = Math.sin(game.time * 8) > 0 ? 'rgba(60,100,255,0.5)' : 'rgba(255,60,60,0.5)';
      ctx.fillRect(0, 0, w, 6);
      ctx.fillRect(0, h - 6, w, 6);
      ctx.restore();
    }
  }

  function feedingFrame(ctx, game, w, h) {
    const p = game.player;
    if (!p || !p.feeding) return;
    const fi = U.clamp(p.feeding.drained / (p.feeding.vt.yield * 1.55), 0, 1);
    ctx.save();
    ctx.strokeStyle = `rgba(180,0,40,${0.25 + fi * 0.35})`;
    ctx.lineWidth = 3;
    ctx.strokeRect(12, 12, w - 24, h - 24);
    ctx.restore();
  }

  VAMP.PostFX = { districtGrade, filmGrain, heatPulse, feedingFrame };
})();