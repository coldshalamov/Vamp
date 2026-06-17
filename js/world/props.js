/* =========================================================================
 * VAMPIRE CITY — world/props.js  (VAMP.Props)
 * Deterministic street set-dressing from the world seed: lamps (whose glow is
 * the same emitter the lighting pass reads), parked-prop silhouettes, trees,
 * hydrants, dumpsters, manholes, litter. Two fixed pools, view-culled, no
 * per-frame allocation. Flat props draw under buildings; standing props join
 * the entity y-sort so a lamp post correctly overlaps NPCs.
 * Load order: after world.js, before render.js.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const T = VAMP.World.T;

  const FLAT_CAP = 90, STAND_CAP = 70;
  const flat = []; for (let i = 0; i < FLAT_CAP; i++) flat.push({ x: 0, y: 0, k: 0 });
  const stand = []; for (let i = 0; i < STAND_CAP; i++) stand.push({ x: 0, y: 0, ptype: 0, col: '#333', prop: true });
  let flatN = 0, standN = 0, gatheredAt = -1;

  function hash2(c, r, seed) { let h = (c * 374761393 + r * 668265263 + (seed | 0) * 0x9E3779B1) | 0; h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; }

  // gather once per frame (renderFlat calls it; standing() reuses the result)
  function gather(cam, world, time) {
    if (gatheredAt === time) return;
    gatheredAt = time;
    flatN = 0; standN = 0;
    const TILE = world.TILE, vr = cam.viewRect(48);
    const lampFn = VAMP.WorldRender && VAMP.WorldRender.lampHere;
    const c0 = Math.max(world.border, Math.floor(vr.x / TILE)), c1 = Math.min(world.cols - world.border - 1, Math.ceil((vr.x + vr.w) / TILE));
    const r0 = Math.max(world.border, Math.floor(vr.y / TILE)), r1 = Math.min(world.rows - world.border - 1, Math.ceil((vr.y + vr.h) / TILE));
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        const t = world.tile[world.idx(c, r)];
        const cx = (c + 0.5) * TILE, cy = (r + 0.5) * TILE;
        if (t === T.SIDEWALK && lampFn && lampFn(c, r)) { if (standN < STAND_CAP) { const s = stand[standN++]; s.x = cx; s.y = cy; s.ptype = 0; } continue; }
        const hs = hash2(c, r, world.seed);
        if (t === T.SIDEWALK) {
          if (hs < 0.05) { if (standN < STAND_CAP) { const s = stand[standN++]; s.x = cx; s.y = cy; s.ptype = hs < 0.025 ? 3 : 4; s.col = s.ptype === 3 ? '#1d3020' : '#7a2630'; } }
          else if (hs > 0.93) { if (flatN < FLAT_CAP) { const f = flat[flatN++]; f.x = cx; f.y = cy; f.k = 0; } }
        } else if (t === T.ROAD) {
          if (hs < 0.03) { if (flatN < FLAT_CAP) { const f = flat[flatN++]; f.x = cx; f.y = cy; f.k = 1; } }
        } else if (t === T.DIRT || t === T.CONCRETE) {
          if (hs < 0.04) { if (standN < STAND_CAP) { const s = stand[standN++]; s.x = cx; s.y = cy; s.ptype = 2; s.col = '#23252b'; } }
        }
      }
    }
  }

  function renderFlat(ctx, cam, world, time) {
    gather(cam, world, time);
    for (let i = 0; i < flatN; i++) {
      const f = flat[i];
      if (f.k === 1) {   // manhole
        ctx.fillStyle = '#0c0d11'; ctx.beginPath(); ctx.ellipse(f.x, f.y, 7, 5, 0, 0, U.TAU); ctx.fill();
        ctx.strokeStyle = 'rgba(70,70,80,0.4)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.ellipse(f.x, f.y, 7, 5, 0, 0, U.TAU); ctx.stroke();
      } else {           // litter
        ctx.fillStyle = 'rgba(74,70,58,0.5)'; ctx.fillRect(f.x - 2, f.y - 1, 3, 2); ctx.fillRect(f.x + 1, f.y + 1, 2, 2);
      }
    }
  }

  function standing() { return { arr: stand, n: standN }; }

  function drawStanding(e, ctx, game) {
    const x = e.x, y = e.y;
    if (e.ptype === 0) {        // street lamp (its glow is the emitter at this same tile)
      ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.beginPath(); ctx.ellipse(x, y, 4, 2, 0, 0, U.TAU); ctx.fill();
      if (VAMP.ArtFlags && VAMP.ArtFlags.useBitmapProps && VAMP.Assets.has('prop_lamp')) {
        VAMP.Assets.drawKey(ctx, 'prop_lamp', x, y, { w: 22, h: 44, ax: 0.5, ay: 1 });
      } else {
        ctx.fillStyle = '#15161c'; ctx.fillRect(x - 1.5, y - 22, 3, 22);
        ctx.fillStyle = '#23252e'; ctx.fillRect(x - 5, y - 25, 10, 4);
        ctx.fillStyle = 'rgba(255,220,150,0.5)'; ctx.fillRect(x - 4, y - 24, 8, 2);
      }
    } else if (e.ptype === 2) { // dumpster
      ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.fillRect(x - 9, y - 1, 20, 5);
      ctx.fillStyle = e.col; ctx.beginPath(); ctx.moveTo(x - 9, y); ctx.lineTo(x - 7, y - 9); ctx.lineTo(x + 9, y - 9); ctx.lineTo(x + 11, y); ctx.closePath(); ctx.fill();
      ctx.fillStyle = U.shade(e.col, 0.18); ctx.fillRect(x - 8, y - 11, 17, 2);
    } else if (e.ptype === 3) { // tree
      ctx.fillStyle = 'rgba(0,0,0,0.25)'; ctx.beginPath(); ctx.ellipse(x, y, 8, 3, 0, 0, U.TAU); ctx.fill();
      if (VAMP.ArtFlags && VAMP.ArtFlags.useBitmapProps && VAMP.Assets.has('prop_tree')) {
        VAMP.Assets.drawKey(ctx, 'prop_tree', x, y, { w: 36, h: 44, ax: 0.5, ay: 1 });
      } else {
        ctx.fillStyle = '#3a2a1a'; ctx.fillRect(x - 2, y - 7, 4, 8);
        ctx.fillStyle = '#16281c'; ctx.beginPath(); ctx.ellipse(x - 4, y - 12, 7, 8, 0, 0, U.TAU); ctx.fill();
        ctx.fillStyle = '#1d3424'; ctx.beginPath(); ctx.ellipse(x + 4, y - 11, 7, 7, 0, 0, U.TAU); ctx.fill();
        ctx.fillStyle = '#24402a'; ctx.beginPath(); ctx.ellipse(x, y - 16, 6, 6, 0, 0, U.TAU); ctx.fill();
      }
    } else if (e.ptype === 4) { // fire hydrant
      ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.beginPath(); ctx.ellipse(x, y, 3, 1.6, 0, 0, U.TAU); ctx.fill();
      ctx.fillStyle = e.col; ctx.fillRect(x - 2, y - 7, 4, 7);
      ctx.beginPath(); ctx.arc(x, y - 7, 2.6, Math.PI, 0); ctx.fill();
      ctx.fillStyle = U.shade(e.col, 0.2); ctx.fillRect(x - 3.5, y - 4, 7, 2);
    }
  }

  VAMP.Props = { gather, renderFlat, standing, drawStanding };
})();
