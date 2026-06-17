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
    if (!m || m.stars < 1) return;
    const s = m.stars;
    const a = 0.04 + s * 0.028 + 0.02 * Math.sin(game.time * (4 + s));
    const grad = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.35, w / 2, h / 2, Math.max(w, h) * 0.72);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(1, `rgba(120,0,20,${a})`);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);
    if (s >= 2) {
      ctx.save();
      ctx.globalAlpha = 0.06 + s * 0.02;
      ctx.fillStyle = 'rgba(180,20,40,0.35)';   // was strokeStyle — fillRect below ignored it and reused the radial grad
      for (let y = 0; y < h; y += 4) {
        if ((y + ((game.time * 80) | 0)) % 8 < 2) ctx.fillRect(0, y, w, 1);
      }
      ctx.restore();
    }
    if (s >= 3) {
      const sweep = (game.time * 0.4) % 1;
      const sx = sweep * (w + 120) - 60;
      ctx.save();
      ctx.globalAlpha = 0.18;
      const lg = ctx.createLinearGradient(sx, 0, sx + 80, 0);
      lg.addColorStop(0, 'rgba(255,255,255,0)');
      lg.addColorStop(0.5, 'rgba(255,240,200,0.5)');
      lg.addColorStop(1, 'rgba(255,255,255,0)');
      ctx.fillStyle = lg;
      ctx.fillRect(sx, 0, 80, h);
      ctx.restore();
    }
    if (s >= 4) {
      ctx.save();
      ctx.globalAlpha = 0.12 + 0.08 * Math.abs(Math.sin(game.time * 10));
      ctx.fillStyle = Math.sin(game.time * 8) > 0 ? 'rgba(60,100,255,0.5)' : 'rgba(255,60,60,0.5)';
      ctx.fillRect(0, 0, w, 6);
      ctx.fillRect(0, h - 6, w, 6);
      ctx.restore();
    }
    if (s >= 5) {
      ctx.save();
      ctx.globalAlpha = 0.08 + 0.06 * Math.abs(Math.sin(game.time * 14));
      if (Math.sin(game.time * 12) > 0) ctx.fillStyle = 'rgba(255,255,255,0.15)';
      else ctx.fillStyle = 'rgba(0,0,0,0.2)';
      ctx.fillRect(0, 0, w, h);
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
    const drift = fi * 0.5;
    ctx.globalAlpha = 0.15 + drift * 0.2;
    ctx.fillStyle = '#ff2f6e';
    for (let i = 0; i < 3; i++) {
      const px = w - 80 + Math.sin(game.time * 3 + i) * 20;
      const py = 60 + i * 18 + Math.cos(game.time * 2 + i) * 8;
      ctx.beginPath(); ctx.arc(px, py, 2 + drift * 2, 0, U.TAU); ctx.fill();
    }
    ctx.restore();
  }

  function feedingLetterbox(ctx, game, w, h) {
    const p = game.player;
    if (!p || !p.feeding) return;
    const fi = U.clamp(p.feeding.drained / (p.feeding.vt.yield * 1.55), 0, 1);
    const bar = 28 + fi * 18;
    ctx.save();
    ctx.fillStyle = 'rgba(4,2,6,0.82)';
    ctx.fillRect(0, 0, w, bar);
    ctx.fillRect(0, h - bar, w, bar);
    ctx.restore();
  }

  function deathDesaturate(ctx, game, w, h) {
    if (game.mode !== 'dead') return;
    const t = U.clamp(game.deathT || 0, 0, 2);
    ctx.save();
    ctx.globalAlpha = U.clamp(t * 0.45, 0, 0.55);
    ctx.fillStyle = '#888';
    ctx.globalCompositeOperation = 'saturation';
    ctx.fillRect(0, 0, w, h);
    ctx.globalCompositeOperation = 'source-over';
    if (t > 0.5) {
      ctx.strokeStyle = 'rgba(60,20,30,0.5)';
      ctx.lineWidth = 4;
      ctx.strokeRect(24, 24, w - 48, h - 48);
    }
    ctx.restore();
  }

  function eliteIntro(ctx, game, w, h) {
    if (!game._eliteFlash || game._eliteFlash.t <= 0) return;
    game._eliteFlash.t -= 0.016;
    const t = U.clamp(game._eliteFlash.t / game._eliteFlash.max, 0, 1);
    ctx.save();
    ctx.globalAlpha = t * 0.35;
    const grad = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, Math.max(w, h) * 0.5);
    grad.addColorStop(0, 'rgba(255,180,60,0.4)');
    grad.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);
    ctx.restore();
  }

  const LUT_CACHE = {};
  function districtLUT(ctx, game, w, h) {
    if (!VAMP.ArtFlags || !VAMP.ArtFlags.usePostFX || game.mode !== 'play' || !game.player) return;
    const dist = game.world && game.world.districtAt(game.player.x, game.player.y);
    if (!dist) return;
    const key = dist.id + '_' + w;
    if (!LUT_CACHE[key]) {
      const c = VAMP.Assets.makeCanvas(w, 1);
      const g = c.getContext('2d');
      const accent = VAMP.DistrictArt ? VAMP.DistrictArt.kitAccent(dist.id) : '#888';
      const grad = g.createLinearGradient(0, 0, w, 0);
      grad.addColorStop(0, 'rgba(255,255,255,0)');
      grad.addColorStop(0.35, accent);
      grad.addColorStop(0.65, '#ffffff');
      grad.addColorStop(1, 'rgba(200,200,210,0.9)');
      g.fillStyle = grad;
      g.fillRect(0, 0, w, 1);
      LUT_CACHE[key] = c;
    }
    ctx.save();
    ctx.globalAlpha = 0.04;
    ctx.globalCompositeOperation = 'overlay';
    for (let y = 0; y < h; y += 2) ctx.drawImage(LUT_CACHE[key], 0, y);
    ctx.restore();
    ctx.globalCompositeOperation = 'source-over';
    ctx.globalAlpha = 1;
  }

  function fogGround(ctx, game, w, h) {
    if (!game.weather || game.weather.kind !== 'fog') return;
    ctx.save();
    ctx.globalAlpha = 0.08;
    ctx.fillStyle = '#8090a0';
    ctx.globalCompositeOperation = 'saturation';
    ctx.fillRect(0, h * 0.55, w, h * 0.45);
    ctx.restore();
    ctx.globalCompositeOperation = 'source-over';
    ctx.globalAlpha = 1;
  }

  function dawnGrade(ctx, game, w, h) {
    if (!game.player || game.mode !== 'play') return;
    const clock = game.clock || 21;
    if (clock < 4 || clock > 6.5) return;
    const t = clock < 5 ? (clock - 4) : (6.5 - clock) / 1.5;
    const a = U.clamp(t, 0, 1) * 0.22;
    ctx.save();
    ctx.globalCompositeOperation = 'multiply';
    ctx.fillStyle = `rgba(255,180,120,${a})`;
    ctx.fillRect(0, 0, w, h);
    ctx.restore();
    ctx.globalCompositeOperation = 'source-over';
  }

  function frenzyPulse(ctx, game, w, h) {
    const p = game.player;
    if (!p || !p.bloodState || !p.bloodState.frenzied) return;
    const a = 0.08 + 0.06 * Math.sin(game.time * 8);
    const grad = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.2, w / 2, h / 2, Math.max(w, h) * 0.75);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(1, `rgba(120,0,20,${a})`);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);
  }

  function rainWetGround(ctx, game, w, h) {
    if (!game.weather || game.weather.kind !== 'rain') return;
    ctx.save();
    ctx.globalCompositeOperation = 'multiply';
    ctx.globalAlpha = 0.06;
    ctx.fillStyle = '#304060';
    ctx.fillRect(0, 0, w, h);
    ctx.restore();
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }

  VAMP.PostFX = {
    districtGrade, districtLUT, filmGrain, heatPulse, feedingFrame, feedingLetterbox,
    dawnGrade, frenzyPulse, rainWetGround, fogGround, deathDesaturate, eliteIntro,
  };
})();