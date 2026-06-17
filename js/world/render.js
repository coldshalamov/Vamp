/* =========================================================================
 * VAMPIRE CITY — world/render.js
 * Draws ground tiles (pattern-batched), water shimmer, and extruded
 * buildings with lit windows. Visible-only culling.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const T = VAMP.World.T;

  const GROUND_COLOR = {
    [T.ROAD]: '#1b1b22',
    [T.SIDEWALK]: '#34343f',
    [T.CONCRETE]: '#2b2730',
    [T.GRASS]: '#16321f',
    [T.WATER]: '#0c1e33',
    [T.DIRT]: '#2a2118',
  };
  const GROUND_PATTERN = {
    [T.ROAD]: 'asphalt',
    [T.SIDEWALK]: 'sidewalk',
    [T.CONCRETE]: 'concrete',
    [T.GRASS]: 'grass',
    [T.WATER]: 'water',
    [T.DIRT]: 'dirt',
  };

  function renderGround(ctx, cam, world, time) {
    const TILE = world.TILE;
    const vr = cam.viewRect(TILE * 2);
    const c0 = Math.max(0, Math.floor(vr.x / TILE));
    const r0 = Math.max(0, Math.floor(vr.y / TILE));
    const c1 = Math.min(world.cols - 1, Math.ceil((vr.x + vr.w) / TILE));
    const r1 = Math.min(world.rows - 1, Math.ceil((vr.y + vr.h) / TILE));
    const pats = VAMP.Assets.patterns;

    // group rects by ground type into paths, fill once per type
    const paths = {};
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        const t = world.tile[world.idx(c, r)];
        let p = paths[t];
        if (!p) p = paths[t] = new Path2D();
        p.rect(c * TILE, r * TILE, TILE + 0.5, TILE + 0.5);
      }
    }
    for (const t in paths) {
      const pat = pats[GROUND_PATTERN[t]];
      ctx.fillStyle = pat || GROUND_COLOR[t] || '#222';
      ctx.fill(paths[t]);
    }

    // road lane markings (dashed) for road tiles — drawn along arterials
    ctx.strokeStyle = 'rgba(200,190,120,0.20)';
    ctx.lineWidth = 1.5;
    ctx.setLineDash([10, 14]);
    ctx.lineDashOffset = 0;
    // skip detailed lane markings when zoomed far out
    if (cam.zoom > 0.55) {
      ctx.beginPath();
      for (let r = r0; r <= r1; r++) {
        for (let c = c0; c <= c1; c++) {
          if (world.tile[world.idx(c, r)] !== T.ROAD) continue;
          // centerline if neighbors are road horizontally
          const left = world.tile[world.idx(Math.max(0, c - 1), r)] === T.ROAD;
          const right = world.tile[world.idx(Math.min(world.cols - 1, c + 1), r)] === T.ROAD;
          const up = world.tile[world.idx(c, Math.max(0, r - 1))] === T.ROAD;
          const dn = world.tile[world.idx(c, Math.min(world.rows - 1, r + 1))] === T.ROAD;
          if (left && right && !(up && dn)) { ctx.moveTo(c * TILE, r * TILE + TILE / 2); ctx.lineTo(c * TILE + TILE, r * TILE + TILE / 2); }
        }
      }
      ctx.stroke();
    }
    ctx.setLineDash([]);

    if (VAMP.ArtFlags && VAMP.ArtFlags.useAutotile) renderGroundEdges(ctx, world, c0, r0, c1, r1, TILE);

    const shimmer = (Math.sin(time * 0.001) + 1) * 0.5;   // 0..1 slow pulse, reused below

    // #18 — animated water: layered sine bands + moving glints give the sea
    // life; a brightened shoreline reads as foam where water meets land.
    const wp = paths[T.WATER];
    if (wp) {
      ctx.save();
      // clip to water so we don't tint the whole map
      ctx.beginPath();
      const vr2 = cam.viewRect(TILE * 2);
      // approximate clip with the water path itself (already built above)
      // base wash
      ctx.fillStyle = '#0c1e33';
      ctx.fill(wp);
      // two offset sine band layers — cheap parallax ripples
      const ph = time * 0.0009;
      ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = `rgba(40,90,140,${0.10 + shimmer * 0.05})`;
      for (let band = 0; band < 2; band++) {
        const off = ph + band * 1.7;
        ctx.save();
        ctx.translate(0, Math.sin(off) * 2);
        ctx.fill(wp);
        ctx.restore();
      }
      // glints: a few drifting specks of moonlight (deterministic per tile)
      const TILE2 = world.TILE;
      const c0g = Math.max(0, Math.floor(vr2.x / TILE2)), c1g = Math.min(world.cols - 1, Math.ceil((vr2.x + vr2.w) / TILE2));
      const r0g = Math.max(0, Math.floor(vr2.y / TILE2)), r1g = Math.min(world.rows - 1, Math.ceil((vr2.y + vr2.h) / TILE2));
      ctx.fillStyle = `rgba(150,200,240,${0.10 + shimmer * 0.18})`;
      for (let r = r0g; r <= r1g; r++) {
        for (let c = c0g; c <= c1g; c++) {
          if (world.tile[world.idx(c, r)] !== T.WATER) continue;
          const s = (c * 13 + r * 7) % 5;
          if (s !== 0) continue;               // sparse
          const gx = (c + 0.5) * TILE2 + Math.sin(ph * 3 + c) * 6;
          const gy = (r + 0.5) * TILE2 + Math.cos(ph * 2.4 + r) * 4;
          const sz = 1 + (Math.sin(ph * 5 + c + r) + 1);
          ctx.fillRect(gx - sz / 2, gy - sz / 2, sz, sz);
        }
      }
      ctx.restore();
    }
  }

  // reused scratch + per-building generation stamp — avoids a fresh array + Set every frame
  // (same allocation-free dedupe pattern as world.buildingsNear).
  const _visBuf = [];
  let _visStamp = 0;
  function renderBuildings(ctx, cam, world, time) {
    const vr = cam.viewRect(96);
    const near = world.buildings;
    // gather visible buildings via hash for speed (dedupe by generation stamp, not a Set)
    const visible = _visBuf; visible.length = 0;
    const stamp = ++_visStamp;
    const c0 = Math.floor(vr.x / world.HASH), c1 = Math.floor((vr.x + vr.w) / world.HASH);
    const r0 = Math.floor(vr.y / world.HASH), r1 = Math.floor((vr.y + vr.h) / world.HASH);
    for (let r = r0; r <= r1; r++) for (let c = c0; c <= c1; c++) {
      if (c < 0 || r < 0 || c >= world.hashW || r >= world.hashH) continue;
      for (const bi of world.hash[r * world.hashW + c]) {
        const b = near[bi];
        if (b._visGen === stamp) continue; b._visGen = stamp;
        if (b.x + b.w > vr.x && b.x < vr.x + vr.w && b.y + b.h > vr.y && b.y < vr.y + vr.h) visible.push(b);
      }
    }
    const pats = VAMP.Assets.patterns;
    const detail = cam.zoom > 0.5;

    // sort by y for consistent extrusion overlap
    visible.sort((a, b) => (a.y + a.h) - (b.y + b.h));

    for (const b of visible) {
      const ext = Math.min(b.height * 0.45, b.d === 0 ? 40 : 24);
      const varShift = ((b.seed % 13) - 6) * 0.028;
      const hueShift = ((b.seed % 7) - 3) * 0.04;
      const baseCol = U.shade(b.color, hueShift);
      const wallBase = U.shade(baseCol, varShift - 0.32);
      const wallSide = U.shade(baseCol, varShift - 0.48);
      const wallRight = U.shade(baseCol, varShift - 0.55);
      ctx.fillStyle = 'rgba(0,0,0,0.38)';
      ctx.fillRect(b.x + 5, b.y + 7, b.w, b.h);

      ctx.fillStyle = wallBase;
      ctx.fillRect(b.x, b.y, b.w, b.h);

      // roof, offset up-left to simulate height
      const rx = b.x - ext * 0.25, ry = b.y - ext;
      // walls connecting base to roof
      ctx.fillStyle = wallSide;
      ctx.beginPath();
      ctx.moveTo(b.x, b.y); ctx.lineTo(rx, ry);
      ctx.lineTo(rx + b.w, ry); ctx.lineTo(b.x + b.w, b.y);
      ctx.closePath(); ctx.fill();
      ctx.fillStyle = wallRight;
      ctx.beginPath();
      ctx.moveTo(b.x + b.w, b.y); ctx.lineTo(rx + b.w, ry);
      ctx.lineTo(rx + b.w, ry + b.h); ctx.lineTo(b.x + b.w, b.y + b.h);
      ctx.closePath(); ctx.fill();
      if (detail && VAMP.DistrictArt && b.d != null) {
        const dist = VAMP.World.DISTRICTS[b.d];
        if (dist) VAMP.DistrictArt.drawWallStamp(ctx, dist.id, b.x + 2, b.y - ext * 0.3, ext);
      }

      // roof top
      const pat = pats[b.roof];
      ctx.fillStyle = pat || b.color;
      ctx.fillRect(rx, ry, b.w, b.h);
      ctx.fillStyle = U.shade(b.color, 0.05);
      ctx.fillRect(rx, ry, b.w, b.h);
      // roof outline
      ctx.strokeStyle = 'rgba(0,0,0,0.5)';
      ctx.lineWidth = 1;
      ctx.strokeRect(rx + 0.5, ry + 0.5, b.w - 1, b.h - 1);

      // parapet: bright inner rim + far-edge shadow reads the roof as a real ledge
      if (detail) {
        ctx.strokeStyle = 'rgba(255,255,255,0.06)'; ctx.lineWidth = 1;
        ctx.strokeRect(rx + 1.5, ry + 1.5, b.w - 3, b.h - 3);
        ctx.fillStyle = 'rgba(0,0,0,0.25)'; ctx.fillRect(rx, ry + b.h - 3, b.w, 3);
        if (b.w * b.h > 2600) drawRoofDetail(ctx, b, rx, ry);
        if (VAMP.DistrictArt && b.d != null) {
          const dist = VAMP.World.DISTRICTS[b.d];
          if (dist) VAMP.DistrictArt.drawRoofStamp(ctx, dist.id, rx + b.w * 0.1, ry + 4, b.w, b.h);
        }
      }

      // lit windows on the up and left faces (batched)
      if (detail) {
        drawWindows(ctx, b, rx, ry, ext, time);
      }

      // neon sign on the roof front edge — the SOURCE the bloom catches; its
      // colored light comes from the same emitter record (gatherLights).
      if (b._sign && detail) {
        const e = b._sign;
        const fl = e.broken ? (Math.sin(time * 0.02 + e.flick * 99) > 0.3 ? 1 : 0.18) : (0.6 + 0.4 * Math.sin(time * 0.004 + e.flick * 99));
        const dist = VAMP.World && VAMP.World.DISTRICTS && VAMP.World.DISTRICTS[b.d];
        const label = VAMP.PropVariants
          ? VAMP.PropVariants.buildingSignText(b.seed, dist ? dist.id : 'downtown')
          : 'OPEN';
        const sw = Math.min(b.w * 0.55, 48);
        const sx = rx + (b.w - sw) / 2, sy = ry + b.h - 6;
        ctx.save();
        ctx.globalCompositeOperation = 'lighter';
        ctx.globalAlpha = 0.35 + fl * 0.5;
        ctx.fillStyle = 'rgba(20,18,28,0.75)';
        ctx.fillRect(sx - 2, sy - 9, sw + 4, 11);
        ctx.strokeStyle = U.shade(e.color, 0.15);
        ctx.lineWidth = 1;
        ctx.strokeRect(sx - 1.5, sy - 8.5, sw + 3, 10);
        ctx.shadowColor = e.color;
        ctx.shadowBlur = 8 + fl * 6;
        ctx.fillStyle = e.color;
        ctx.font = 'bold ' + Math.max(6, Math.min(9, sw / label.length * 1.4)) + 'px monospace';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(label, rx + b.w / 2, sy - 3);
        ctx.shadowBlur = 0;
        ctx.restore();
      }
      if (detail && VAMP.ArtFlags && VAMP.ArtFlags.useBitmapBuildings && VAMP.Assets.has('windows_sheet') && b.w * b.h > 1200) {
        const ws = VAMP.Assets.get('windows_sheet');
        const fw = Math.max(1, Math.floor((ws.width || 126) / 3));
        const fh = Math.max(1, Math.floor((ws.height || 80) / 2));
        const flick = (Math.sin(time * 0.002 + b.seed) + 1) * 0.5;
        ctx.save();
        ctx.globalAlpha = 0.55 + flick * 0.2;
        const wx = rx + 4, wy = ry + 4, ww = b.w - 8, wh = Math.min(b.h - 8, 48);
        ctx.drawImage(ws, (b.seed % 3) * fw, (b.seed % 2) * fh, fw, fh, wx, wy, ww, wh);
        ctx.restore();
      }

      // POI marker / façade stamp
      if (b.poi) {
        const cxp = rx + b.w / 2, cyp = ry + b.h / 2;
        const poiKey = 'poi_' + b.poi.type;
        if (detail && VAMP.Assets && VAMP.Assets.has(poiKey)) {
          const fac = VAMP.Assets.get(poiKey);
          ctx.drawImage(fac, cxp - 24, cyp - 20, 48, 40);
        } else {
          ctx.fillStyle = b.poi.color;
          ctx.globalAlpha = 0.9;
          ctx.beginPath(); ctx.arc(cxp, cyp, 7, 0, U.TAU); ctx.fill();
          ctx.globalAlpha = 1;
          ctx.fillStyle = '#000';
          ctx.font = 'bold 9px monospace'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
          ctx.fillText(b.poi.glyph, cxp, cyp + 0.5);
        }
      }
    }
    ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic';
  }

  function drawWindows(ctx, b, rx, ry, ext, time) {
    // window geometry is seed-static (rx/ry/cols/rows/b.lit never change) — bake the
    // 3 Path2D buckets (warm/cool/dark) ONCE per building, then only re-fill each frame.
    if (!b._winWarm) {
      let a = (b.seed >>> 0) || 1;
      const rand = () => { a |= 0; a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
      const cols = Math.max(1, Math.floor(b.w / 10));
      const rows = Math.max(1, Math.floor(b.h / 10));
      const lit = b.lit;
      const warm = new Path2D(), cool = new Path2D(), dark = new Path2D();
      for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
          const wx = rx + 4 + (c / cols) * (b.w - 8);
          const wy = ry + 4 + (r / rows) * (b.h - 8);
          if (rand() < lit) { (rand() < 0.7 ? warm : cool).rect(wx, wy, 3, 3); }
          else dark.rect(wx, wy, 3, 3);
        }
      }
      b._winWarm = warm; b._winCool = cool; b._winDark = dark;
    }
    const flicker = (Math.sin(time * 0.002 + b.seed) + 1) * 0.5;
    ctx.fillStyle = 'rgba(10,12,20,0.6)'; ctx.fill(b._winDark);
    ctx.fillStyle = `rgba(255,200,110,${0.46 + flicker * 0.32})`; ctx.fill(b._winWarm);
    ctx.fillStyle = `rgba(150,190,255,${0.46 + flicker * 0.32})`; ctx.fill(b._winCool);
  }

  // rooftop props (AC units, tanks, vents) — deterministic, allocation-free
  function drawRoofDetail(ctx, b, rx, ry) {
    let a = (b.seed ^ 0x5bd1e995) >>> 0;
    const rnd = () => { a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
    const count = Math.min(4, (b.w * b.h / 2600) | 0);
    for (let i = 0; i < count; i++) {
      const px = rx + 6 + rnd() * (b.w - 18);
      const py = ry + 6 + rnd() * (b.h - 18);
      const k = rnd();
      if (k < 0.45) {                         // AC unit
        ctx.fillStyle = 'rgba(20,22,28,0.9)'; ctx.fillRect(px, py, 10, 8);
        ctx.fillStyle = U.shade(b.color, 0.14); ctx.fillRect(px, py - 2, 10, 3);
      } else if (k < 0.75) {                  // water tank (cylinder)
        ctx.fillStyle = U.shade(b.color, -0.22); ctx.fillRect(px, py - 4, 9, 9);
        ctx.fillStyle = U.shade(b.color, 0.18);
        ctx.beginPath(); ctx.ellipse(px + 4.5, py - 4, 4.5, 2.2, 0, 0, U.TAU); ctx.fill();
      } else {                                // stairwell / vent box with cast shadow
        ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.fillRect(px + 2, py + 2, 8, 7);
        ctx.fillStyle = U.shade(b.color, 0.2); ctx.fillRect(px, py, 8, 7);
      }
    }
  }

  function neighborTile(world, c, r, dc, dr) {
    const nc = c + dc, nr = r + dr;
    if (nc < 0 || nr < 0 || nc >= world.cols || nr >= world.rows) return -1;
    return world.tile[world.idx(nc, nr)];
  }

  // Bitmask of sides where a *different* ground type touches this tile.
  function transitionMask(world, c, r, t) {
    let mask = 0;
    if (neighborTile(world, c, r, 0, -1) !== t) mask |= 1;
    if (neighborTile(world, c, r, 0, 1) !== t) mask |= 2;
    if (neighborTile(world, c, r, -1, 0) !== t) mask |= 4;
    if (neighborTile(world, c, r, 1, 0) !== t) mask |= 8;
    return mask;
  }

  function renderAutotileOverlay(ctx, world, c0, r0, c1, r1, TILE) {
    const atlas = VAMP.Assets.get('autotile_16');
    if (!atlas) return;
    const ts = 32;
    const blendTypes = [T.ROAD, T.SIDEWALK, T.GRASS, T.WATER, T.CONCRETE, T.DIRT];
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        const t = world.tile[world.idx(c, r)];
        if (blendTypes.indexOf(t) < 0) continue;
        const mask = transitionMask(world, c, r, t);
        if (!mask) continue;
        const mx = (mask % 4) * ts, my = ((mask / 4) | 0) * ts;
        ctx.globalAlpha = 0.42;
        ctx.drawImage(atlas, mx, my, ts, ts, c * TILE, r * TILE, TILE, TILE);
      }
    }
    ctx.globalAlpha = 1;
  }

  // Soft edge blends where ground types meet + autotile corner stamps
  function renderGroundEdges(ctx, world, c0, r0, c1, r1, TILE) {
    const edgeW = 5;
    const blends = {
      [T.ROAD + '-' + T.SIDEWALK]: 'rgba(40,38,48,0.35)',
      [T.SIDEWALK + '-' + T.ROAD]: 'rgba(20,20,26,0.28)',
      [T.ROAD + '-' + T.GRASS]: 'rgba(18,28,18,0.32)',
      [T.GRASS + '-' + T.ROAD]: 'rgba(30,30,36,0.28)',
      [T.SIDEWALK + '-' + T.GRASS]: 'rgba(22,32,22,0.25)',
      [T.GRASS + '-' + T.SIDEWALK]: 'rgba(36,36,44,0.22)',
      [T.ROAD + '-' + T.WATER]: 'rgba(12,28,48,0.38)',
      [T.WATER + '-' + T.ROAD]: 'rgba(24,24,30,0.30)',
    };
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        const t = world.tile[world.idx(c, r)];
        const x = c * TILE, y = r * TILE;
        const n = [
          [0, -1, x, y, x + TILE, y, x, y + edgeW, x + TILE, y + edgeW],
          [0, 1, x, y + TILE - edgeW, x + TILE, y + TILE, x, y + TILE - edgeW, x + TILE, y + TILE],
          [-1, 0, x, y, x + edgeW, y + TILE, x, y, x + edgeW, y],
          [1, 0, x + TILE - edgeW, y, x + TILE, y + TILE, x + TILE - edgeW, y, x + TILE, y + TILE],
        ];
        for (const nb of n) {
          const nc = c + nb[0], nr = r + nb[1];
          if (nc < 0 || nr < 0 || nc >= world.cols || nr >= world.rows) continue;
          const nt = world.tile[world.idx(nc, nr)];
          if (nt === t) continue;
          const col = blends[t + '-' + nt] || 'rgba(0,0,0,0.18)';
          ctx.fillStyle = col;
          ctx.beginPath();
          ctx.moveTo(nb[2], nb[3]); ctx.lineTo(nb[4], nb[5]);
          ctx.lineTo(nb[7], nb[8]); ctx.lineTo(nb[6], nb[9]);
          ctx.closePath(); ctx.fill();
        }
      }
    }
    if (VAMP.Assets && VAMP.Assets.has('autotile_16')) renderAutotileOverlay(ctx, world, c0, r0, c1, r1, TILE);
  }

  // ---- lighting: a fixed pool filled each frame (no per-frame allocation) ----
  // Each light: {x,y,r,color,addA}. addA = additive (colored-neon) intensity;
  // ALL lights also carve the darkness mask. Lamp positions match props.js posts.
  const _lightPool = [];
  for (let i = 0; i < 256; i++) _lightPool.push({ x: 0, y: 0, r: 0, color: '#fff', addA: 0 });
  const _transient = [];   // emergency/muzzle, pushed per-frame, drained in gather
  function addTransient(x, y, r, color, addA) { if (_transient.length < 48) _transient.push({ x, y, r, color, addA: addA == null ? 1 : addA }); }
  function lampHere(c, r) { return (c * 7 + r * 13) % 11 === 0; }

  function gatherLights(cam, world, time) {
    let n = 0;
    const vr = cam.viewRect(80);
    const TILE = world.TILE;
    const c0 = Math.max(0, Math.floor(vr.x / TILE)), c1 = Math.min(world.cols - 1, Math.ceil((vr.x + vr.w) / TILE));
    const r0 = Math.max(0, Math.floor(vr.y / TILE)), r1 = Math.min(world.rows - 1, Math.ceil((vr.y + vr.h) / TILE));
    for (let r = r0; r <= r1 && n < 256; r++) {
      for (let c = c0; c <= c1 && n < 256; c++) {
        if (world.tile[world.idx(c, r)] !== T.SIDEWALK || !lampHere(c, r)) continue;
        const L = _lightPool[n++]; L.x = (c + 0.5) * TILE; L.y = (r + 0.5) * TILE; L.r = 108; L.color = '#ffd9a0'; L.addA = 0.5;
      }
    }
    // signs / beacons via emitter grid
    if (world.emHash) {
      const gc0 = Math.max(0, Math.floor(vr.x / world.HASH)), gc1 = Math.min(world.hashW - 1, Math.floor((vr.x + vr.w) / world.HASH));
      const gr0 = Math.max(0, Math.floor(vr.y / world.HASH)), gr1 = Math.min(world.hashH - 1, Math.floor((vr.y + vr.h) / world.HASH));
      for (let gr = gr0; gr <= gr1 && n < 256; gr++) {
        for (let gc = gc0; gc <= gc1 && n < 256; gc++) {
          const cell = world.emHash[gr * world.hashW + gc]; if (!cell) continue;
          for (let k = 0; k < cell.length && n < 256; k++) {
            const e = world.emitters[cell[k]];
            const L = _lightPool[n++]; L.x = e.x; L.y = e.y; L.r = e.r; L.color = e.color;
            if (e.kind === 'sign') L.addA = (e.broken ? (Math.sin(time * 0.02 + e.flick * 99) > 0.3 ? 0.9 : 0.12) : (0.6 + 0.34 * Math.sin(time * 0.004 + e.flick * 99)));
            else L.addA = (Math.sin(time * 0.006 + e.blink * 99) > 0.4 ? 1 : 0.05);   // beacon blink
          }
        }
      }
    }
    // discovered POIs glow in their colour (small fixed count)
    for (let i = 0; i < world.pois.length && n < 256; i++) {
      const poi = world.pois[i]; if (!poi.discovered || !cam.inView(poi.x, poi.y, 40)) continue;
      const L = _lightPool[n++]; L.x = poi.x; L.y = poi.y; L.r = 68; L.color = poi.color; L.addA = 0.55 + 0.22 * Math.sin(time * 0.005 + i);
    }
    // transient (emergency, muzzle)
    for (let i = 0; i < _transient.length && n < 256; i++) {
      const e = _transient[i]; const L = _lightPool[n++]; L.x = e.x; L.y = e.y; L.r = e.r; L.color = e.color; L.addA = e.addA;
    }
    _transient.length = 0;
    return n;
  }

  VAMP.WorldRender = { renderGround, renderBuildings, gatherLights, lightPool: _lightPool, addTransient, lampHere };
})();
