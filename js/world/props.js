/* =========================================================================
 * VAMPIRE CITY — world/props.js  (VAMP.Props)
 * Street set-dressing with camera-distance priority (no south-edge pop-out).
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const T = VAMP.World.T;
  const PV = () => VAMP.PropVariants;

  const FLAT_CAP = 180;
  const LAMP_CAP = 180, TREE_CAP = 140, MISC_CAP = 100;
  const CAND_CAP = 320;
  const flat = []; for (let i = 0; i < FLAT_CAP; i++) flat.push({ x: 0, y: 0, k: 0 });
  const lamps = []; for (let i = 0; i < LAMP_CAP; i++) lamps.push({ x: 0, y: 0, ptype: 0, variant: 0, assetKey: 'prop_lamp', prop: true });
  const trees = []; for (let i = 0; i < TREE_CAP; i++) trees.push({ x: 0, y: 0, ptype: 3, variant: 0, assetKey: 'prop_tree', tint: '#24402a', scale: 1, prop: true });
  const misc = []; for (let i = 0; i < MISC_CAP; i++) misc.push({ x: 0, y: 0, ptype: 4, variant: 0, col: '#7a2630', scale: 1, prop: true });
  const standOut = new Array(LAMP_CAP + TREE_CAP + MISC_CAP);
  const candidates = new Array(CAND_CAP);
  let flatN = 0, lampN = 0, treeN = 0, miscN = 0, standN = 0, candN = 0, gatheredAt = -1;

  function hash2(c, r, seed) {
    return PV() ? PV().hash2(c, r, seed, 0) : 0;
  }

  function pushCand(x, y, ptype, extra) {
    if (candN >= CAND_CAP) return;
    const cam = extra.cam;
    const dx = x - cam.x, dy = y - cam.y;
    const d2 = dx * dx + dy * dy;
    candidates[candN++] = { x, y, ptype, d2, extra };
  }

  function fillPool(pool, cap, sortKey, start) {
    start = start || 0;
    let n = start;
    if (candN === 0) return 0;
    for (let i = 0; i < candN && n < cap; i++) {
      const c = candidates[i];
      if (c.ptype !== sortKey) continue;
      const s = pool[n++];
      s.x = c.x; s.y = c.y; s.ptype = c.ptype;
      const ex = c.extra;
      if (sortKey === 0) {
        s.variant = ex.variant;
        s.assetKey = ex.assetKey;
        s.scale = ex.scale || 1;
      } else if (sortKey === 3) {
        s.variant = ex.variant;
        s.assetKey = ex.assetKey;
        s.tint = ex.tint;
        s.scale = ex.scale || 1;
      } else {
        s.variant = ex.variant;
        s.col = ex.col;
        s.scale = ex.scale || 1;
      }
    }
    return n - start;
  }

  function gather(cam, world, time) {
    if (gatheredAt === time) return;
    gatheredAt = time;
    flatN = 0; lampN = 0; treeN = 0; miscN = 0; standN = 0; candN = 0;
    const TILE = world.TILE;
    const margin = Math.max(220, cam.viewH / cam.zoom * 0.28);
    const vr = cam.viewRect(margin);
    const lampFn = VAMP.WorldRender && VAMP.WorldRender.lampHere;
    const c0 = Math.max(world.border, Math.floor(vr.x / TILE)), c1 = Math.min(world.cols - world.border - 1, Math.ceil((vr.x + vr.w) / TILE));
    const r0 = Math.max(world.border, Math.floor(vr.y / TILE)), r1 = Math.min(world.rows - world.border - 1, Math.ceil((vr.y + vr.h) / TILE));
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        const t = world.tile[world.idx(c, r)];
        const cx = (c + 0.5) * TILE, cy = (r + 0.5) * TILE;
        const hs = hash2(c, r, world.seed);
        if (t === T.SIDEWALK && lampFn && lampFn(c, r)) {
          pushCand(cx, cy, 0, {
            cam, variant: (hs * 3) | 0,
            assetKey: PV() ? PV().lampKey(c, r, world.seed) : 'prop_lamp',
            scale: 0.92 + hs * 0.18,
          });
          continue;
        }
        if (t === T.SIDEWALK) {
          if (hs < 0.072) {
            pushCand(cx, cy, 3, {
              cam, variant: (hs * 5) | 0,
              assetKey: PV() ? PV().treeKey(c, r, world.seed) : 'prop_tree',
              tint: PV() ? PV().treeTint(c, r, world.seed) : '#24402a',
              scale: 0.82 + hs * 0.42,
            });
          } else if (hs > 0.93 && flatN < FLAT_CAP) {
            const f = flat[flatN++]; f.x = cx; f.y = cy; f.k = 0;
          } else if (hs > 0.86 && hs < 0.9) {
            pushCand(cx, cy, PV() ? PV().miscType(c, r, world.seed) : 4, {
              cam, variant: (hs * 7) | 0,
              col: PV() ? PV().miscColor(c, r, world.seed) : '#7a2630',
              scale: 0.9 + hs * 0.2,
            });
          } else if (hs > 0.82 && hs < 0.84) {
            pushCand(cx, cy, 5, { cam, variant: 0, col: '#5a5a68', scale: 1 });
          }
        } else if (t === T.ROAD) {
          if (hs < 0.03 && flatN < FLAT_CAP) { const f = flat[flatN++]; f.x = cx; f.y = cy; f.k = 1; }
        } else if (t === T.DIRT || t === T.CONCRETE) {
          if (hs < 0.04) {
            pushCand(cx, cy, 2, { cam, variant: 0, col: '#23252b', scale: 1 });
          } else if (hs > 0.95) {
            pushCand(cx, cy, 3, {
              cam, variant: (hs * 4) | 0,
              assetKey: PV() ? PV().treeKey(c, r, world.seed) : 'prop_tree',
              tint: PV() ? PV().treeTint(c, r, world.seed) : '#1e3822',
              scale: 0.88 + hs * 0.3,
            });
          }
        } else if (t === T.GRASS && hs < 0.04) {
          pushCand(cx, cy, 3, {
            cam, variant: (hs * 6) | 0,
            assetKey: PV() ? PV().treeKey(c, r, world.seed) : 'prop_tree',
            tint: PV() ? PV().treeTint(c, r, world.seed) : '#1a3220',
            scale: 0.72 + hs * 0.45,
          });
        }
      }
    }
    candidates.sort((a, b) => a.d2 - b.d2);
    lampN = fillPool(lamps, LAMP_CAP, 0);
    treeN = fillPool(trees, TREE_CAP, 3);
    miscN = 0;
    miscN += fillPool(misc, MISC_CAP, 2, miscN);
    miscN += fillPool(misc, MISC_CAP, 4, miscN);
    miscN += fillPool(misc, MISC_CAP, 5, miscN);
    miscN += fillPool(misc, MISC_CAP, 6, miscN);
    miscN += fillPool(misc, MISC_CAP, 7, miscN);
    miscN += fillPool(misc, MISC_CAP, 8, miscN);

    standN = 0;
    for (let i = 0; i < lampN && standN < standOut.length; i++) standOut[standN++] = lamps[i];
    for (let i = 0; i < treeN && standN < standOut.length; i++) standOut[standN++] = trees[i];
    for (let i = 0; i < miscN && standN < standOut.length; i++) standOut[standN++] = misc[i];
  }

  function renderFlat(ctx, cam, world, time) {
    gather(cam, world, time);
    for (let i = 0; i < flatN; i++) {
      const f = flat[i];
      if (f.k === 1) {
        ctx.fillStyle = '#0c0d11'; ctx.beginPath(); ctx.ellipse(f.x, f.y, 8, 5.5, 0, 0, U.TAU); ctx.fill();
        ctx.strokeStyle = 'rgba(90,90,100,0.45)'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.ellipse(f.x, f.y, 8, 5.5, 0, 0, U.TAU); ctx.stroke();
        ctx.strokeStyle = 'rgba(60,60,70,0.3)'; ctx.beginPath();
        ctx.moveTo(f.x - 5, f.y); ctx.lineTo(f.x + 5, f.y); ctx.moveTo(f.x, f.y - 3); ctx.lineTo(f.x, f.y + 3); ctx.stroke();
      } else {
        ctx.fillStyle = 'rgba(74,70,58,0.55)'; ctx.fillRect(f.x - 2, f.y - 1, 4, 2);
        ctx.fillStyle = 'rgba(50,48,42,0.4)'; ctx.fillRect(f.x + 2, f.y + 1, 3, 2);
        ctx.fillStyle = 'rgba(40,38,34,0.35)'; ctx.fillRect(f.x - 1, f.y + 2, 2, 2);
      }
    }
  }

  function standing() {
    return { arr: standOut, n: standN };
  }

  function drawStanding(e, ctx, game) {
    const x = e.x, y = e.y;
    if (e.ptype === 0) {
      ctx.fillStyle = 'rgba(0,0,0,0.35)'; ctx.beginPath(); ctx.ellipse(x, y, 6, 3, 0, 0, U.TAU); ctx.fill();
      const variant = (e.variant || 0) % 3;
      const sc = e.scale || 1;
      const lampH = 58 * sc, lampW = 28 * sc;
      const baked = VAMP.Assets.getBaked('prop_lamp', variant);
      if (baked) {
        ctx.drawImage(baked, x - lampW * 0.5, y - lampH, lampW, lampH);
      } else if (VAMP.ArtFlags && VAMP.ArtFlags.useBitmapProps && VAMP.Assets.has(e.assetKey || 'prop_lamp')) {
        VAMP.Assets.drawKey(ctx, e.assetKey || 'prop_lamp', x, y, { w: lampW, h: lampH, ax: 0.5, ay: 1, smooth: true });
      } else {
        ctx.fillStyle = '#1a1b22'; ctx.fillRect(x - 2, y - 28 * sc, 4, 28 * sc);
        ctx.fillStyle = '#2a2c36'; ctx.fillRect(x - 7, y - 31 * sc, 14, 5);
        const g = ctx.createRadialGradient(x, y - 30 * sc, 0, x, y - 30 * sc, 16 * sc);
        g.addColorStop(0, 'rgba(255,220,160,0.85)'); g.addColorStop(1, 'rgba(255,200,120,0)');
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y - 30 * sc, 16 * sc, 0, U.TAU); ctx.fill();
      }
    } else if (e.ptype === 2) {
      ctx.fillStyle = 'rgba(0,0,0,0.35)'; ctx.fillRect(x - 12, y - 1, 26, 7);
      ctx.fillStyle = e.col; ctx.beginPath(); ctx.moveTo(x - 12, y); ctx.lineTo(x - 9, y - 14); ctx.lineTo(x + 12, y - 14); ctx.lineTo(x + 14, y); ctx.closePath(); ctx.fill();
      ctx.fillStyle = U.shade(e.col, 0.22); ctx.fillRect(x - 11, y - 16, 22, 3);
      ctx.fillStyle = 'rgba(20,22,28,0.5)'; ctx.fillRect(x - 4, y - 8, 8, 5);
    } else if (e.ptype === 3) {
      const sc = e.scale || 1;
      ctx.fillStyle = 'rgba(0,0,0,0.28)'; ctx.beginPath(); ctx.ellipse(x, y, 12 * sc, 4, 0, 0, U.TAU); ctx.fill();
      const variant = (e.variant || 0) % 3;
      const th = 54 * sc, tw = 44 * sc;
      const baked = VAMP.Assets.getBaked('prop_tree', variant);
      if (baked) {
        ctx.drawImage(baked, x - tw * 0.5, y - th, tw, th);
      } else if (VAMP.ArtFlags && VAMP.ArtFlags.useBitmapProps && VAMP.Assets.has(e.assetKey || 'prop_tree')) {
        VAMP.Assets.drawKey(ctx, e.assetKey || 'prop_tree', x, y, { w: tw, h: th, ax: 0.5, ay: 1, tint: e.tint, smooth: true });
      } else {
        ctx.fillStyle = '#3a2a1a'; ctx.fillRect(x - 2, y - 9 * sc, 4, 10 * sc);
        ctx.fillStyle = e.tint || '#1d3424'; ctx.beginPath(); ctx.ellipse(x, y - 16 * sc, 11 * sc, 13 * sc, 0, 0, U.TAU); ctx.fill();
      }
    } else if (e.ptype === 4) {
      const sc = e.scale || 1;
      const v = e.variant || 0;
      ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.beginPath(); ctx.ellipse(x, y, 4 * sc, 2.5, 0, 0, U.TAU); ctx.fill();
      if (v % 3 === 0) {
        ctx.fillStyle = e.col; ctx.fillRect(x - 3 * sc, y - 11 * sc, 6 * sc, 11 * sc);
        ctx.beginPath(); ctx.arc(x, y - 11 * sc, 3.5 * sc, Math.PI, 0); ctx.fill();
        ctx.fillStyle = U.shade(e.col, 0.25); ctx.fillRect(x - 5 * sc, y - 6 * sc, 10 * sc, 3);
      } else if (v % 3 === 1) {
        ctx.fillStyle = '#4a4a58'; ctx.fillRect(x - 8 * sc, y - 3 * sc, 16 * sc, 3 * sc);
        ctx.fillStyle = '#3a3a48'; ctx.fillRect(x - 7 * sc, y - 12 * sc, 3 * sc, 10 * sc);
        ctx.fillRect(x + 4 * sc, y - 12 * sc, 3 * sc, 10 * sc);
        ctx.fillStyle = '#5a5a68'; ctx.fillRect(x - 7 * sc, y - 13 * sc, 14 * sc, 2 * sc);
      } else {
        ctx.fillStyle = '#2a2a32'; ctx.fillRect(x - 5 * sc, y - 14 * sc, 10 * sc, 14 * sc);
        ctx.fillStyle = '#3a3a44'; ctx.fillRect(x - 4 * sc, y - 13 * sc, 8 * sc, 3 * sc);
        ctx.fillStyle = '#8a8a98'; ctx.fillRect(x - 1, y - 10 * sc, 2, 8 * sc);
      }
    } else if (e.ptype === 5) {
      ctx.fillStyle = 'rgba(0,0,0,0.32)'; ctx.fillRect(x - 1, y - 1, 3, 14);
      ctx.fillStyle = e.col || '#5a5a68';
      ctx.fillRect(x - 9, y - 22, 18, 10);
      ctx.strokeStyle = 'rgba(200,200,210,0.35)'; ctx.lineWidth = 1;
      ctx.strokeRect(x - 8.5, y - 21.5, 17, 9);
      const label = PV() ? PV().signLabel(e.x, e.y) : 'ST';
      ctx.fillStyle = 'rgba(220,220,230,0.85)'; ctx.font = 'bold 6px monospace';
      ctx.textAlign = 'center'; ctx.fillText(label, x, y - 15);
      ctx.textAlign = 'left';
    } else if (e.ptype === 6) {
      const sc = e.scale || 1;
      ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.beginPath(); ctx.ellipse(x, y, 5 * sc, 2.5, 0, 0, U.TAU); ctx.fill();
      ctx.fillStyle = '#8a2028'; ctx.fillRect(x - 3 * sc, y - 10 * sc, 6 * sc, 10 * sc);
      ctx.fillStyle = '#c0c4cc'; ctx.beginPath(); ctx.arc(x, y - 10 * sc, 3.5 * sc, Math.PI, 0); ctx.fill();
      ctx.fillStyle = '#e8ecf0'; ctx.fillRect(x - 1.5 * sc, y - 12 * sc, 3 * sc, 3 * sc);
    } else if (e.ptype === 7) {
      const sc = e.scale || 1;
      ctx.fillStyle = 'rgba(0,0,0,0.28)'; ctx.fillRect(x - 14 * sc, y - 1, 28 * sc, 3);
      ctx.fillStyle = '#3a3238'; ctx.fillRect(x - 12 * sc, y - 5 * sc, 24 * sc, 4 * sc);
      ctx.fillStyle = '#2a2428'; ctx.fillRect(x - 11 * sc, y - 4 * sc, 3 * sc, 4 * sc);
      ctx.fillRect(x + 8 * sc, y - 4 * sc, 3 * sc, 4 * sc);
      ctx.fillStyle = '#4a4048'; ctx.fillRect(x - 10 * sc, y - 9 * sc, 20 * sc, 2 * sc);
    } else if (e.ptype === 8) {
      const sc = e.scale || 1;
      ctx.fillStyle = 'rgba(0,0,0,0.25)'; ctx.fillRect(x - 1, y - 1, 2, 12 * sc);
      ctx.fillStyle = e.col || '#3a3a44';
      ctx.fillRect(x - 10 * sc, y - 16 * sc, 20 * sc, 14 * sc);
      ctx.strokeStyle = 'rgba(0,0,0,0.35)'; ctx.lineWidth = 1;
      for (let i = 0; i < 4; i++) {
        ctx.beginPath(); ctx.moveTo(x - 9 * sc + i * 5 * sc, y - 15 * sc);
        ctx.lineTo(x - 9 * sc + i * 5 * sc, y - 3 * sc); ctx.stroke();
      }
    }
  }

  VAMP.Props = { gather, renderFlat, standing, drawStanding };
})();