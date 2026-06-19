/* =========================================================================
 * VAMPIRE CITY — render/nocturne.js
 *
 * A production-safe visual-direction layer for the existing Canvas 2D engine.
 * It does not replace gameplay or the renderer. Instead it teaches the current
 * renderer one coherent material, lighting, and interface grammar:
 *
 *   darkness carries composition; emissive colour is scarce and motivated;
 *   wet surfaces respond to nearby light; UI edges share a gothic lineage;
 *   legibility survives every effect.
 *
 * The module is deliberately dependency-free and preserves file:// startup.
 * It wraps public render hooks only, can be disabled at runtime, respects
 * quality/reduced-motion settings, and contains no save-state changes.
 * ========================================================================= */
(function () {
  'use strict';

  const VAMP = (window.VAMP = window.VAMP || {});
  if (!VAMP.Util || !VAMP.WorldRender || !VAMP.PostFX || !VAMP.Theme || !VAMP.UI || !VAMP.Menus) return;

  const U = VAMP.Util;
  const TAU = Math.PI * 2;
  const N = {
    enabled: true,
    intensity: 1,
    version: 1,
    TOKENS: {
      void: '#050408', coal: '#0a0810', ink: '#e7dfe2', dim: '#9a8990',
      blood: '#b4213b', arterial: '#ff426d', bone: '#d8c4ad', brass: '#bd9462',
      sodium: '#ffd79a', cyan: '#62d8d0', violet: '#9168d8', rain: '#9db8c4',
    },
    setEnabled(value) { this.enabled = !!value; },
    setIntensity(value) { this.intensity = U.clamp(+value || 0, 0, 1.5); },
  };
  VAMP.Nocturne = N;
  if (VAMP.ArtFlags) VAMP.ArtFlags.useNocturne = true;

  const C = N.TOKENS;
  const hash = (x, y, seed) => {
    let n = (Math.imul(x | 0, 374761393) + Math.imul(y | 0, 668265263) + Math.imul(seed | 0, 1442695041)) | 0;
    n = Math.imul(n ^ (n >>> 13), 1274126177); return ((n ^ (n >>> 16)) >>> 0);
  };
  const rgba = (hex, a) => {
    let s = String(hex || '#000').replace('#', '');
    if (s.length === 3) s = s[0] + s[0] + s[1] + s[1] + s[2] + s[2];
    const n = parseInt(s, 16) || 0;
    return 'rgba(' + (n >>> 16) + ',' + ((n >>> 8) & 255) + ',' + (n & 255) + ',' + a + ')';
  };
  const active = () => N.enabled && (!VAMP.ArtFlags || VAMP.ArtFlags.useNocturne !== false);
  const game = () => VAMP.Game;
  const high = () => { const g = game(); return !g || g.quality !== 'low'; };
  const full = () => { const g = game(); return !g || g.quality === 'high'; };
  const motion = () => { const g = game(); return !(g && g.reducedMotion); };

  function gothicPath(ctx, x, y, w, h, cut, spire) {
    cut = Math.max(2, Math.min(cut || 8, Math.min(w, h) * 0.24)); spire = spire || 0;
    ctx.beginPath(); ctx.moveTo(x + cut, y);
    if (spire > 0 && w > spire * 5) {
      ctx.lineTo(x + w * 0.5 - spire, y); ctx.lineTo(x + w * 0.5, y - spire); ctx.lineTo(x + w * 0.5 + spire, y);
    }
    ctx.lineTo(x + w - cut, y); ctx.lineTo(x + w, y + cut); ctx.lineTo(x + w, y + h - cut);
    ctx.lineTo(x + w - cut, y + h); ctx.lineTo(x + cut, y + h); ctx.lineTo(x, y + h - cut);
    ctx.lineTo(x, y + cut); ctx.closePath();
  }

  function corners(ctx, x, y, w, h, color, alpha, size) {
    size = size || 14; ctx.save(); ctx.strokeStyle = rgba(color, alpha); ctx.lineWidth = 1;
    const pts = [[x, y, 1, 1], [x + w, y, -1, 1], [x, y + h, 1, -1], [x + w, y + h, -1, -1]];
    for (let i = 0; i < pts.length; i++) {
      const p = pts[i], px = p[0], py = p[1], sx = p[2], sy = p[3];
      ctx.beginPath(); ctx.moveTo(px + sx * 3, py + sy * size); ctx.lineTo(px + sx * 3, py + sy * 3); ctx.lineTo(px + sx * size, py + sy * 3); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(px + sx * 7, py + sy * size); ctx.quadraticCurveTo(px + sx * 7, py + sy * 7, px + sx * size, py + sy * 7); ctx.stroke();
    }
    ctx.restore();
  }

  // ---------------------------------------------------------------- world material response
  function wetMaterialPass(ctx, cam, world, time) {
    if (!active() || !world || !cam || !world.tile || !VAMP.World || !VAMP.World.T) return;
    const T = VAMP.World.T, TILE = world.TILE || 32, vr = cam.viewRect(TILE * 2);
    const c0 = Math.max(0, Math.floor(vr.x / TILE)), r0 = Math.max(0, Math.floor(vr.y / TILE));
    const c1 = Math.min(world.cols - 1, Math.ceil((vr.x + vr.w) / TILE)), r1 = Math.min(world.rows - 1, Math.ceil((vr.y + vr.h) / TILE));
    const strength = N.intensity * (high() ? 1 : 0.56);

    ctx.save(); ctx.globalCompositeOperation = 'screen'; ctx.lineCap = 'round';
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        const t = world.tile[world.idx(c, r)], h = hash(c, r, 73), x = c * TILE, y = r * TILE;
        if (t === T.ROAD) {
          // A restrained rain sheen: sparse vertical hairlines and irregular puddle lips.
          if ((h & 7) === 0) {
            const px = x + 5 + ((h >>> 7) % Math.max(5, TILE - 10));
            const len = TILE * (0.24 + ((h >>> 13) & 7) * 0.045);
            ctx.strokeStyle = 'rgba(125,166,178,' + (0.035 * strength) + ')'; ctx.lineWidth = 0.7;
            ctx.beginPath(); ctx.moveTo(px, y + TILE * 0.18); ctx.lineTo(px + 1.2, y + TILE * 0.18 + len); ctx.stroke();
          }
          if (high() && h % 29 === 0) {
            const px = x + TILE * (0.24 + ((h >>> 5) & 15) / 32), py = y + TILE * (0.34 + ((h >>> 11) & 7) / 24);
            const rw = TILE * (0.16 + ((h >>> 16) & 7) / 80), rh = Math.max(1.2, rw * 0.18);
            ctx.strokeStyle = (h & 1) ? rgba(C.arterial, 0.055 * strength) : rgba(C.cyan, 0.05 * strength); ctx.lineWidth = 0.75;
            ctx.beginPath(); ctx.moveTo(px - rw, py); ctx.bezierCurveTo(px - rw * 0.45, py - rh, px + rw * 0.45, py - rh * 0.6, px + rw, py); ctx.stroke();
          }
        } else if (t === T.SIDEWALK && h % 17 === 0 && cam.zoom > 0.62) {
          ctx.fillStyle = 'rgba(210,218,220,' + (0.026 * strength) + ')';
          ctx.fillRect(x + 3 + (h % Math.max(3, TILE - 8)), y + 4 + ((h >>> 8) % Math.max(3, TILE - 8)), 1.2, 3.5);
        }
      }
    }
    ctx.restore();
  }

  function roofNarrativePass(ctx, cam, world) {
    if (!active() || !high() || !world || !world.buildings || !cam || cam.zoom < 0.54) return;
    const vr = cam.viewRect(96), list = world.buildings, max = Math.min(list.length, 900);
    ctx.save(); ctx.lineCap = 'round';
    let drawn = 0;
    for (let i = 0; i < max && drawn < 95; i++) {
      const b = list[i];
      if (!b || b.x + b.w < vr.x || b.x > vr.x + vr.w || b.y + b.h < vr.y || b.y > vr.y + vr.h) continue;
      const ext = Math.min(b.height * 0.45, b.d === 0 ? 40 : 24), rx = b.x - ext * 0.25, ry = b.y - ext, h = hash(b.seed || i, b.d || 0, 191);
      // Selective roof rim: only the moon-facing edges catch, preserving a black floor.
      ctx.strokeStyle = 'rgba(196,202,215,' + (0.045 * N.intensity) + ')'; ctx.lineWidth = 0.8;
      ctx.beginPath(); ctx.moveTo(rx + 2, ry + b.h - 2); ctx.lineTo(rx + 2, ry + 2); ctx.lineTo(rx + Math.min(b.w * 0.42, 42), ry + 2); ctx.stroke();
      if (full() && h % 11 === 0 && b.w > 32) {
        const ax = rx + 9 + ((h >>> 8) % Math.max(10, (b.w - 18) | 0)), ay = ry + 9 + ((h >>> 15) % Math.max(8, (b.h - 18) | 0));
        ctx.strokeStyle = 'rgba(15,13,18,0.86)'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(ax, ay - 13 - (h & 7)); ctx.lineTo(ax + 5, ay - 9); ctx.stroke();
      }
      if (full() && h % 37 === 0 && b.w > 62) {
        const x1 = rx + 8, x2 = rx + b.w - 8, cy = ry + 12 + (h % Math.max(8, (b.h * 0.25) | 0));
        ctx.strokeStyle = 'rgba(3,3,5,0.52)'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(x1, cy); ctx.bezierCurveTo(x1 + b.w * 0.3, cy + 8, x2 - b.w * 0.3, cy - 4, x2, cy + 3); ctx.stroke();
      }
      drawn++;
    }
    ctx.restore();
  }

  const originalGround = VAMP.WorldRender.renderGround;
  VAMP.WorldRender.renderGround = function (ctx, cam, world, time) {
    originalGround.call(this, ctx, cam, world, time); wetMaterialPass(ctx, cam, world, time || 0);
  };
  const originalBuildings = VAMP.WorldRender.renderBuildings;
  VAMP.WorldRender.renderBuildings = function (ctx, cam, world, time) {
    originalBuildings.call(this, ctx, cam, world, time); roofNarrativePass(ctx, cam, world);
  };

  // ---------------------------------------------------------------- screen grade
  const gradeCache = new Map();
  function gradeCanvas(w, h) {
    const key = w + 'x' + h;
    let c = gradeCache.get(key); if (c) return c;
    c = document.createElement('canvas'); c.width = w; c.height = h; const g = c.getContext('2d');
    const cool = g.createRadialGradient(w * 0.13, h * 0.04, 0, w * 0.13, h * 0.04, Math.max(w, h) * 0.8);
    cool.addColorStop(0, 'rgba(67,88,132,0.16)'); cool.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = cool; g.fillRect(0, 0, w, h);
    const warm = g.createRadialGradient(w * 0.88, h * 0.92, 0, w * 0.88, h * 0.92, Math.max(w, h) * 0.72);
    warm.addColorStop(0, 'rgba(112,12,40,0.13)'); warm.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = warm; g.fillRect(0, 0, w, h);
    const floor = g.createLinearGradient(0, 0, 0, h); floor.addColorStop(0, 'rgba(2,3,8,0.02)'); floor.addColorStop(0.58, 'rgba(0,0,0,0)'); floor.addColorStop(1, 'rgba(0,0,0,0.14)'); g.fillStyle = floor; g.fillRect(0, 0, w, h);
    gradeCache.set(key, c); if (gradeCache.size > 5) gradeCache.delete(gradeCache.keys().next().value); return c;
  }
  function cinematicGrade(ctx, g, w, h) {
    if (!active() || !g || g.mode !== 'play') return;
    ctx.save(); ctx.globalCompositeOperation = 'soft-light'; ctx.globalAlpha = 0.32 * N.intensity; ctx.drawImage(gradeCanvas(w, h), 0, 0); ctx.restore();
  }
  const originalDistrictLUT = VAMP.PostFX.districtLUT;
  VAMP.PostFX.districtLUT = function (ctx, g, w, h) {
    originalDistrictLUT.call(this, ctx, g, w, h); cinematicGrade(ctx, g, w, h);
  };

  // ---------------------------------------------------------------- interface lineage
  function ornamentPanel(ctx, x, y, w, h, edge) {
    if (!active() || w < 54 || h < 30) return;
    ctx.save(); ctx.strokeStyle = rgba(edge || C.blood, 0.23 * N.intensity); ctx.lineWidth = 0.7;
    gothicPath(ctx, x + 4.5, y + 4.5, w - 9, h - 9, Math.min(7, h * 0.18), 0); ctx.stroke();
    if (w > 120 && h > 52) corners(ctx, x + 2, y + 2, w - 4, h - 4, C.brass, 0.22 * N.intensity, 13);
    ctx.restore();
  }
  const oldPanel = VAMP.Theme.panel;
  VAMP.Theme.panel = function (ctx, x, y, w, h, opts) {
    oldPanel.call(this, ctx, x, y, w, h, opts); ornamentPanel(ctx, x, y, w, h, opts && (opts.edge || opts.titleColor));
  };
  const oldDrawPanel = VAMP.Theme.drawPanel;
  VAMP.Theme.drawPanel = function (ctx, x, y, w, h, opts) {
    oldDrawPanel.call(this, ctx, x, y, w, h, opts); ornamentPanel(ctx, x, y, w, h, opts && (opts.edge || opts.titleColor));
  };
  const oldSlot = VAMP.Theme.drawSlot;
  VAMP.Theme.drawSlot = function (ctx, x, y, size, opts) {
    oldSlot.call(this, ctx, x, y, size, opts);
    if (!active() || size < 26) return;
    const color = opts && (opts.edge || opts.color) || C.blood;
    ctx.save(); ctx.strokeStyle = rgba(color, opts && opts.active ? 0.72 : 0.26); ctx.lineWidth = 0.8;
    ctx.beginPath(); ctx.moveTo(x + size * 0.35, y + 1); ctx.lineTo(x + size * 0.5, y - Math.min(5, size * 0.1)); ctx.lineTo(x + size * 0.65, y + 1); ctx.stroke(); ctx.restore();
  };

  function focusReticle(ctx, g) {
    if (!active() || !g || g.mode !== 'play' || !g.player || !g.cam || !high()) return;
    const p = g.player.inVehicle || g.player, s = g.cam.worldToScreen(p.x, p.y), pulse = motion() ? Math.sin((g.time || 0) * 2.1) * 1.5 : 0;
    ctx.save(); ctx.strokeStyle = rgba(C.arterial, 0.17 * N.intensity); ctx.lineWidth = 1;
    ctx.beginPath(); ctx.arc(s.x, s.y, 24 + pulse, 0.12, Math.PI * 0.82); ctx.stroke();
    ctx.beginPath(); ctx.arc(s.x, s.y, 24 + pulse, Math.PI + 0.12, Math.PI * 1.82); ctx.stroke(); ctx.restore();
  }
  function screenFrame(ctx, w, h, menu) {
    if (!active() || w < 600 || h < 400) return;
    ctx.save(); ctx.strokeStyle = rgba(menu ? C.blood : C.brass, menu ? 0.18 : 0.09); ctx.lineWidth = 1; ctx.strokeRect(12.5, 12.5, w - 25, h - 25);
    corners(ctx, 12, 12, w - 24, h - 24, menu ? C.arterial : C.blood, menu ? 0.23 : 0.12, 17); ctx.restore();
  }
  const oldUIRender = VAMP.UI.render;
  VAMP.UI.render = function (ctx, g, w, h) {
    focusReticle(ctx, g); oldUIRender.call(this, ctx, g, w, h); screenFrame(ctx, w, h, false);
  };

  function menuAtmosphere(ctx, g, w, h) {
    if (!active()) return;
    ctx.save();
    const v = ctx.createRadialGradient(w * 0.5, h * 0.34, 0, w * 0.5, h * 0.34, Math.max(w, h) * 0.68);
    v.addColorStop(0, 'rgba(74,13,34,0.08)'); v.addColorStop(0.58, 'rgba(4,3,7,0.18)'); v.addColorStop(1, 'rgba(2,2,4,0.68)'); ctx.fillStyle = v; ctx.fillRect(0, 0, w, h);
    if (high()) {
      // Architectural silhouette, intentionally almost subliminal behind readable menus.
      ctx.fillStyle = 'rgba(2,2,4,0.17)'; const cx = w * 0.5, top = h * 0.08, base = h * 0.92;
      ctx.beginPath(); ctx.moveTo(cx - w * 0.21, base); ctx.lineTo(cx - w * 0.21, top + h * 0.19); ctx.lineTo(cx, top); ctx.lineTo(cx + w * 0.21, top + h * 0.19); ctx.lineTo(cx + w * 0.21, base); ctx.closePath(); ctx.fill();
    }
    ctx.restore();
  }
  const oldMenuRender = VAMP.Menus.render;
  VAMP.Menus.render = function (ctx, g, w, h) {
    menuAtmosphere(ctx, g, w, h); oldMenuRender.call(this, ctx, g, w, h); screenFrame(ctx, w, h, true);
  };
})();
