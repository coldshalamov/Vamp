/* =========================================================================
 * VAMPIRE CITY — world/districtart.js
 * Procedural district skyline parallax + identity tints (no external assets).
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  const KITS = {
    downtown:    { sky: '#12141e', bld: '#2a2c3a', lit: '#ffd080', accent: '#6c7bd6', h: 1.0 },
    oldtown:     { sky: '#14100c', bld: '#3a3028', lit: '#e8c070', accent: '#caa46a', h: 0.75 },
    docks:       { sky: '#0c1418', bld: '#243028', lit: '#90c8b0', accent: '#5fb3a1', h: 0.55 },
    redlight:    { sky: '#140810', bld: '#3a2030', lit: '#ff60a0', accent: '#e0457b', h: 0.65 },
    residential: { sky: '#10141c', bld: '#2a3440', lit: '#a8c8e8', accent: '#7fa8c9', h: 0.5 },
    cemetery:    { sky: '#0a100c', bld: '#1e2824', lit: '#9a86c4', accent: '#9a86c4', h: 0.4 },
    industrial:  { sky: '#12100c', bld: '#343028', lit: '#d0a060', accent: '#d6953f', h: 0.7 },
  };

  const baked = {};

  function bakeSkyline(id, kit) {
    const w = 512, h = 180;
    const c = VAMP.Assets.makeCanvas(w, h);
    const g = c.getContext('2d');
    const rng = U.makeRNG((id.length * 997) | 0);
    const grad = g.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, kit.sky);
    grad.addColorStop(1, 'rgba(5,6,10,0)');
    g.fillStyle = grad;
    g.fillRect(0, 0, w, h);
    let x = 0;
    while (x < w) {
      const bw = 18 + (rng() * 42) | 0;
      const bh = (40 + rng() * 120 * kit.h) | 0;
      const by = h - bh;
      g.fillStyle = U.shade(kit.bld, (rng() - 0.5) * 0.12);
      g.fillRect(x, by, bw, bh);
      if (rng() > 0.35) {
        g.fillStyle = kit.lit;
        const rows = 2 + ((rng() * 4) | 0), cols = 1 + ((rng() * 3) | 0);
        for (let r = 0; r < rows; r++) for (let col = 0; col < cols; col++) {
          if (rng() > 0.55) g.fillRect(x + 4 + col * 6, by + 6 + r * 8, 3, 4);
        }
      }
      if (rng() > 0.82 && kit.h > 0.6) {
        g.fillStyle = kit.accent;
        g.globalAlpha = 0.45;
        g.fillRect(x + 2, by + 4, bw - 4, 3);
        g.globalAlpha = 1;
      }
      x += bw + 2 + ((rng() * 8) | 0);
    }
    return c;
  }

  function ensureBaked() {
    for (const id in KITS) {
      if (!baked[id]) baked[id] = { back: bakeSkyline(id, KITS[id]), front: bakeSkyline(id + 'f', KITS[id]) };
    }
  }

  function renderParallax(ctx, cam, world, game) {
    if (!VAMP.ArtFlags || VAMP.ArtFlags.usePostFX === false) return;
    if (game.quality === 'low') return;
    const p = game.player;
    if (!p || !world) return;
    const dist = world.districtAt(p.inVehicle ? p.inVehicle.x : p.x, p.inVehicle ? p.inVehicle.y : p.y);
    if (!dist) return;
    ensureBaked();
    const kit = baked[dist.id] || baked.downtown;
    const vr = cam.viewRect(0);
    const vw = vr.w, vh = vr.h;
    const layers = [
      { img: kit.back, par: 0.22, y: 0.08, alpha: 0.55, scale: 1.6 },
      { img: kit.front, par: 0.42, y: 0.14, alpha: 0.72, scale: 1.35 },
    ];
    for (const L of layers) {
      const ox = -(cam.x * L.par) % (L.img.width * L.scale);
      const sy = vr.y + vh * L.y;
      ctx.save();
      ctx.globalAlpha = L.alpha;
      for (let tx = ox - L.img.width * L.scale; tx < vw + L.img.width * L.scale; tx += L.img.width * L.scale * 0.85) {
        ctx.drawImage(L.img, vr.x + tx, sy, L.img.width * L.scale, L.img.height * L.scale * 0.55);
      }
      ctx.restore();
    }
    ctx.globalAlpha = 1;
  }

  function kitAccent(id) {
    const k = KITS[id];
    return k ? k.accent : '#888';
  }

  const DECAL_WEIGHT = {
    downtown: 1.0, oldtown: 0.9, docks: 1.1, redlight: 1.35,
    residential: 0.75, cemetery: 0.85, industrial: 1.25,
  };

  function decalWeight(id) { return DECAL_WEIGHT[id] || 1; }

  function drawRoofStamp(ctx, districtId, x, y, w, h) {
    const key = 'roof_' + districtId;
    if (!VAMP.Assets || !VAMP.Assets.has(key)) return;
    const mod = VAMP.Assets.get(key);
    if (!mod) return;
    const tw = Math.min(w * 0.4, 48), th = tw * 0.5;
    ctx.drawImage(mod, x, y, tw, th);
  }

  function drawWallStamp(ctx, districtId, x, y, h) {
    const key = 'wall_' + districtId;
    if (!VAMP.Assets || !VAMP.Assets.has(key)) return;
    const mod = VAMP.Assets.get(key);
    if (!mod) return;
    const tw = 24;
    ctx.drawImage(mod, x, y, tw, Math.min(h, 40));
  }

  VAMP.DistrictArt = { renderParallax, kitAccent, decalWeight, drawRoofStamp, drawWallStamp, KITS, DECAL_WEIGHT };
})();