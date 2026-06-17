/* =========================================================================
 * VAMPIRE CITY — world.js
 * Procedural top-down city: districts, roads, blocks, buildings, water,
 * collision + passability grids, POIs, spawn helpers, rendering.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  const TILE = 32;
  // tile ground codes
  const T = { ROAD: 0, SIDEWALK: 1, CONCRETE: 2, GRASS: 3, WATER: 4, DIRT: 5 };

  const DISTRICTS = [
    { id: 'downtown', name: 'Downtown', ground: T.CONCRETE, palette: ['#2a2a36', '#33323f', '#3a2f42', '#262633'], roof: 'roof1', danger: 0.5, minH: 24, maxH: 60, build: 0.9, accent: '#6c7bd6' },
    { id: 'oldtown', name: 'Old Town', ground: T.SIDEWALK, palette: ['#3a2f2a', '#42352b', '#39302c', '#2f2823'], roof: 'roof4', danger: 0.4, minH: 14, maxH: 30, build: 0.85, accent: '#caa46a' },
    { id: 'docks', name: 'The Docks', ground: T.DIRT, palette: ['#26302f', '#2b3633', '#22302c', '#1f2926'], roof: 'roof3', danger: 0.7, minH: 10, maxH: 26, build: 0.7, accent: '#5fb3a1' },
    { id: 'redlight', name: 'Red Light', ground: T.SIDEWALK, palette: ['#3a2230', '#46263a', '#3c2030', '#311b28'], roof: 'roof2', danger: 0.85, minH: 12, maxH: 30, build: 0.85, accent: '#e0457b' },
    { id: 'residential', name: 'Residential', ground: T.SIDEWALK, palette: ['#2c3340', '#333a47', '#2a3744', '#283038'], roof: 'roof1', danger: 0.3, minH: 12, maxH: 24, build: 0.8, accent: '#7fa8c9' },
    { id: 'cemetery', name: 'The Necropolis', ground: T.GRASS, palette: ['#272b2a', '#2d322f', '#23302a'], roof: 'roof3', danger: 0.6, minH: 8, maxH: 18, build: 0.35, accent: '#9a86c4' },
    { id: 'industrial', name: 'Industrial', ground: T.DIRT, palette: ['#33302a', '#3a352c', '#2e2b25', '#403a30'], roof: 'roof4', danger: 0.65, minH: 14, maxH: 34, build: 0.75, accent: '#d6953f' },
  ];

  function generate(seed) {
    const rng = U.makeRNG(seed >>> 0 || 12345);
    const cols = 200, rows = 200;
    const w = cols * TILE, h = rows * TILE;
    const tile = new Uint8Array(cols * rows);
    const district = new Int8Array(cols * rows).fill(-1);
    const idx = (c, r) => r * cols + c;

    // --- water border (sea) ---
    const border = 5;

    // --- district seeds (Voronoi over interior) ---
    const seeds = [];
    const usable = DISTRICTS.length;
    for (let i = 0; i < usable; i++) {
      seeds.push({
        c: rng.int(border + 12, cols - border - 12),
        r: rng.int(border + 12, rows - border - 12),
        d: i,
      });
    }
    function nearestDistrict(c, r) {
      let best = 0, bd = Infinity;
      for (const s of seeds) {
        const dd = (c - s.c) * (c - s.c) + (r - s.r) * (r - s.r);
        if (dd < bd) { bd = dd; best = s.d; }
      }
      return best;
    }

    // --- road network: arterial lines with jitter ---
    const roadXs = []; // {pos,width}
    const roadYs = [];
    let x = border + rng.int(6, 10);
    while (x < cols - border - 4) {
      const wgt = rng.chance(0.25) ? 4 : 3; // avenues vs streets
      roadXs.push({ pos: x, width: wgt });
      x += rng.int(13, 22);
    }
    let y = border + rng.int(6, 10);
    while (y < rows - border - 4) {
      const wgt = rng.chance(0.25) ? 4 : 3;
      roadYs.push({ pos: y, width: wgt });
      y += rng.int(13, 22);
    }
    const isRoadCol = new Uint8Array(cols);
    const isRoadRow = new Uint8Array(rows);
    for (const rx of roadXs) for (let i = 0; i < rx.width; i++) if (rx.pos + i < cols) isRoadCol[rx.pos + i] = 1;
    for (const ry of roadYs) for (let i = 0; i < ry.width; i++) if (ry.pos + i < rows) isRoadRow[ry.pos + i] = 1;

    // --- base ground fill ---
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        if (c < border || r < border || c >= cols - border || r >= rows - border) {
          tile[idx(c, r)] = T.WATER; continue;
        }
        const d = nearestDistrict(c, r);
        district[idx(c, r)] = d;
        if (isRoadCol[c] || isRoadRow[r]) tile[idx(c, r)] = T.ROAD;
        else tile[idx(c, r)] = DISTRICTS[d].ground;
      }
    }

    // sidewalk ring: non-road interior tile adjacent to a road becomes sidewalk
    const tile2 = tile.slice();
    for (let r = border; r < rows - border; r++) {
      for (let c = border; c < cols - border; c++) {
        const t = tile[idx(c, r)];
        if (t === T.ROAD || t === T.WATER) continue;
        let nearRoad = false;
        for (let dy = -1; dy <= 1 && !nearRoad; dy++)
          for (let dx = -1; dx <= 1; dx++) {
            if (tile[idx(c + dx, r + dy)] === T.ROAD) { nearRoad = true; break; }
          }
        if (nearRoad) tile2[idx(c, r)] = T.SIDEWALK;
      }
    }
    for (let i = 0; i < tile.length; i++) tile[i] = tile2[i];

    // --- parks / lakes in a couple of blocks of low-build districts ---
    // (cosmetic water handled below as buildings are skipped on water)

    // --- buildings: scan block interiors and place lots ---
    const buildings = [];
    const blockCellsVisited = new Uint8Array(cols * rows);

    // Identify block rectangles between roads
    const xEdges = [border];
    for (const rx of roadXs) { xEdges.push(rx.pos); xEdges.push(rx.pos + rx.width); }
    xEdges.push(cols - border);
    const yEdges = [border];
    for (const ry of roadYs) { yEdges.push(ry.pos); yEdges.push(ry.pos + ry.width); }
    yEdges.push(rows - border);
    // unique sorted
    const ux = [...new Set(xEdges)].sort((a, b) => a - b);
    const uy = [...new Set(yEdges)].sort((a, b) => a - b);

    const blocks = [];
    for (let i = 0; i < ux.length - 1; i++) {
      for (let j = 0; j < uy.length - 1; j++) {
        const c0 = ux[i], c1 = ux[i + 1], r0 = uy[j], r1 = uy[j + 1];
        // skip if this strip is a road strip (width small & marked road)
        const midc = (c0 + c1) >> 1, midr = (r0 + r1) >> 1;
        if (midc < border || midr < border || midc >= cols - border || midr >= rows - border) continue;
        if (isRoadCol[midc] || isRoadRow[midr]) continue;
        if (c1 - c0 < 4 || r1 - r0 < 4) continue;
        blocks.push({ c0, c1, r0, r1, d: district[idx(midc, midr)] });
      }
    }

    // place buildings inside each block, leaving 1-tile sidewalk margin
    for (const b of blocks) {
      const dist = DISTRICTS[b.d] || DISTRICTS[0];
      const ic0 = b.c0 + 1, ic1 = b.c1 - 1, ir0 = b.r0 + 1, ir1 = b.r1 - 1;
      const bw = ic1 - ic0, bh = ir1 - ir0;
      if (bw < 2 || bh < 2) continue;

      // park / plaza chance for low-build districts
      if (rng.chance(1 - dist.build)) {
        // leave as open ground (park/plaza); optionally a lake or fountain
        if (dist.id === 'cemetery') {
          // graves: many tiny buildings (headstones) handled as decals later via pois
        }
        continue;
      }

      // subdivide block into a small grid of lots
      const lotsX = Math.max(1, Math.round(bw / rng.int(6, 9)));
      const lotsY = Math.max(1, Math.round(bh / rng.int(6, 9)));
      for (let lx = 0; lx < lotsX; lx++) {
        for (let ly = 0; ly < lotsY; ly++) {
          if (!rng.chance(dist.build)) continue;
          const lc0 = Math.round(ic0 + (bw * lx) / lotsX);
          const lc1 = Math.round(ic0 + (bw * (lx + 1)) / lotsX);
          const lr0 = Math.round(ir0 + (bh * ly) / lotsY);
          const lr1 = Math.round(ir0 + (bh * (ly + 1)) / lotsY);
          // inset margin
          const m = 0.18;
          const px = (lc0 + (lc1 - lc0) * m) * TILE;
          const py = (lr0 + (lr1 - lr0) * m) * TILE;
          const pw = (lc1 - lc0) * (1 - 2 * m) * TILE;
          const ph = (lr1 - lr0) * (1 - 2 * m) * TILE;
          if (pw < TILE * 1.2 || ph < TILE * 1.2) continue;
          const hgt = rng.range(dist.minH, dist.maxH);
          buildings.push({
            x: px, y: py, w: pw, h: ph,
            color: rng.pick(dist.palette),
            roof: dist.roof,
            height: hgt,
            d: b.d,
            accent: dist.accent,
            lit: rng.range(0.2, 0.8), // window-lit ratio
            seed: rng.int(0, 1e9),
          });
        }
      }
    }

    // --- passability + building occupancy grids ---
    const pass = new Uint8Array(cols * rows); // 1 = walkable
    for (let i = 0; i < tile.length; i++) {
      const t = tile[i];
      pass[i] = (t === T.WATER) ? 0 : 1;
    }
    // spatial hash for buildings
    const HASH = 128; // px cell
    const hashW = Math.ceil(w / HASH), hashH = Math.ceil(h / HASH);
    const hash = [];
    for (let i = 0; i < hashW * hashH; i++) hash.push([]);
    function hashRect(bx, by, bw2, bh2, payloadIndex) {
      const c0 = Math.floor(bx / HASH), c1 = Math.floor((bx + bw2) / HASH);
      const r0 = Math.floor(by / HASH), r1 = Math.floor((by + bh2) / HASH);
      for (let r = r0; r <= r1; r++) for (let c = c0; c <= c1; c++) {
        if (c >= 0 && r >= 0 && c < hashW && r < hashH) hash[r * hashW + c].push(payloadIndex);
      }
    }
    buildings.forEach((bld, i) => {
      hashRect(bld.x, bld.y, bld.w, bld.h, i);
      // mark footprint tiles non-walkable
      const c0 = Math.floor(bld.x / TILE), c1 = Math.floor((bld.x + bld.w) / TILE);
      const r0 = Math.floor(bld.y / TILE), r1 = Math.floor((bld.y + bld.h) / TILE);
      for (let r = r0; r <= r1; r++) for (let c = c0; c <= c1; c++)
        if (c >= 0 && r >= 0 && c < cols && r < rows) pass[idx(c, r)] = 0;
    });

    // --- neon sign / beacon emitters (seed-derived → no save needed) ---
    // Signs are BOTH a drawn quad (render.js) and a colored light (gatherLights)
    // from the SAME record. Denser in red-light / downtown.
    const emitters = [];
    for (let bi = 0; bi < buildings.length; bi++) {
      const b = buildings[bi];
      const dist = DISTRICTS[b.d] || DISTRICTS[0];
      const sp = dist.id === 'redlight' ? 0.5 : dist.id === 'downtown' ? 0.42 : dist.id === 'cemetery' ? 0.06 : 0.2;
      if (b.w > 48 && ((b.seed % 100) / 100) < sp) {
        emitters.push({
          kind: 'sign', bi,
          x: b.x + b.w * 0.5, y: b.y - 1,
          w: Math.min(b.w * 0.62, 64), h: 5,
          color: dist.accent, flick: (b.seed % 17) / 17, broken: (b.seed % 23) === 0, r: 78,
        });
        b._sign = emitters[emitters.length - 1];
      }
      // tall Downtown high-rises get a blinking red aviation beacon on the roof
      if (b.d === 0 && b.height > 44 && (b.seed % 5) === 0) {
        emitters.push({ kind: 'beacon', bi, x: b.x + b.w * 0.5, y: b.y - b.height * 0.42, color: '#ff3030', r: 40, blink: (b.seed % 7) / 7 });
      }
    }
    // coarse grid (reuse HASH cell size) so gather is O(visible), not O(all)
    const emHash = [];
    for (let i = 0; i < hashW * hashH; i++) emHash.push(null);
    for (let ei = 0; ei < emitters.length; ei++) {
      const e = emitters[ei];
      const gc = Math.floor(e.x / HASH), gr = Math.floor(e.y / HASH);
      if (gc < 0 || gr < 0 || gc >= hashW || gr >= hashH) continue;
      const cell = gr * hashW + gc;
      (emHash[cell] || (emHash[cell] = [])).push(ei);
    }

    // scratch for buildingsNear() — reused each call to avoid per-frame allocation
    // (collideCircle runs it for the player + every moving NPC + every vehicle each frame)
    const _nearOut = [];
    const _nearStamp = new Int32Array(buildings.length);
    let _nearGen = 0;

    const world = {
      seed: seed >>> 0 || 12345,
      cols, rows, TILE, w, h, tile, district, pass, buildings,
      hash, hashW, hashH, HASH, border,
      emitters, emHash,
      districts: DISTRICTS,
      pois: [],
      idx,
      // --- queries ---
      tileAt(wx, wy) {
        const c = Math.floor(wx / TILE), r = Math.floor(wy / TILE);
        if (c < 0 || r < 0 || c >= cols || r >= rows) return T.WATER;
        return tile[idx(c, r)];
      },
      districtAt(wx, wy) {
        const c = Math.floor(wx / TILE), r = Math.floor(wy / TILE);
        if (c < 0 || r < 0 || c >= cols || r >= rows) return null;
        const d = district[idx(c, r)];
        return d >= 0 ? DISTRICTS[d] : null;
      },
      isRoad(wx, wy) { return this.tileAt(wx, wy) === T.ROAD; },
      isWalkable(wx, wy) {
        const c = Math.floor(wx / TILE), r = Math.floor(wy / TILE);
        if (c < 0 || r < 0 || c >= cols || r >= rows) return false;
        return pass[idx(c, r)] === 1;
      },
      tileWalkable(c, r) {
        if (c < 0 || r < 0 || c >= cols || r >= rows) return false;
        return pass[idx(c, r)] === 1;
      },
      // buildings near a point (for collision)
      buildingsNear(wx, wy, rad) {
        const c0 = Math.floor((wx - rad) / HASH), c1 = Math.floor((wx + rad) / HASH);
        const r0 = Math.floor((wy - rad) / HASH), r1 = Math.floor((wy + rad) / HASH);
        const out = _nearOut; out.length = 0;
        const gen = ++_nearGen;   // generation stamp replaces the per-call Set dedupe
        for (let r = r0; r <= r1; r++) for (let c = c0; c <= c1; c++) {
          if (c < 0 || r < 0 || c >= hashW || r >= hashH) continue;
          const cell = hash[r * hashW + c];
          for (let k = 0; k < cell.length; k++) { const bi = cell[k]; if (_nearStamp[bi] !== gen) { _nearStamp[bi] = gen; out.push(buildings[bi]); } }
        }
        return out;
      },
      // resolve a circle out of nearby buildings; returns true if moved
      collideCircle(p, rad) {
        let moved = false;
        const near = this.buildingsNear(p.x, p.y, rad + 4);
        for (const b of near) {
          const push = U.resolveCircleRect(p.x, p.y, rad, b.x, b.y, b.w, b.h);
          if (push) { p.x += push.x; p.y += push.y; moved = true; }
        }
        // water collision (treat water tiles as solid via tile sampling)
        if (this.tileAt(p.x, p.y) === T.WATER) {
          // push back toward last walkable — handled by caller via revert; mark
          moved = true; p._inWater = true;
        } else p._inWater = false;
        return moved;
      },
      pointBlocked(wx, wy, rad) {
        if (this.tileAt(wx, wy) === T.WATER) return true;
        const near = this.buildingsNear(wx, wy, rad + 2);
        for (const b of near) if (U.circleRect(wx, wy, rad, b.x, b.y, b.w, b.h)) return true;
        return false;
      },
      // --- spawn helpers ---
      randomWalkPos(rng2) {
        rng2 = rng2 || Math.random;
        for (let i = 0; i < 200; i++) {
          const c = border + Math.floor(rng2() * (cols - border * 2));
          const r = border + Math.floor(rng2() * (rows - border * 2));
          if (pass[idx(c, r)] === 1 && tile[idx(c, r)] !== T.WATER) {
            const t = tile[idx(c, r)];
            if (t === T.SIDEWALK || t === T.GRASS || t === T.CONCRETE)
              return { x: (c + 0.5) * TILE, y: (r + 0.5) * TILE };
          }
        }
        return { x: cols * TILE / 2, y: rows * TILE / 2 };
      },
      randomRoadPos(rng2) {
        rng2 = rng2 || Math.random;
        for (let i = 0; i < 300; i++) {
          const c = border + Math.floor(rng2() * (cols - border * 2));
          const r = border + Math.floor(rng2() * (rows - border * 2));
          if (tile[idx(c, r)] === T.ROAD) return { x: (c + 0.5) * TILE, y: (r + 0.5) * TILE };
        }
        return { x: cols * TILE / 2, y: rows * TILE / 2 };
      },
      randomBuilding(rng2) {
        rng2 = rng2 || Math.random;
        return buildings[Math.floor(rng2() * buildings.length)];
      },
    };

    return world;
  }

  VAMP.World = { generate, TILE, T, DISTRICTS };
})();
