/* =========================================================================
 * VAMPIRE CITY — world/pathfinding.js
 * Grid A* over the passability grid (capped), plus light steering helpers.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  // Binary heap (min) for A*
  function Heap() {
    const a = [];
    return {
      get size() { return a.length; },
      push(node, pri) {
        a.push({ node, pri });
        let i = a.length - 1;
        while (i > 0) { const p = (i - 1) >> 1; if (a[p].pri <= a[i].pri) break; [a[p], a[i]] = [a[i], a[p]]; i = p; }
      },
      pop() {
        const top = a[0]; const last = a.pop();
        if (a.length) { a[0] = last; let i = 0; const n = a.length;
          for (;;) { let l = i * 2 + 1, r = l + 1, s = i;
            if (l < n && a[l].pri < a[s].pri) s = l;
            if (r < n && a[r].pri < a[s].pri) s = r;
            if (s === i) break; [a[s], a[i]] = [a[i], a[s]]; i = s; } }
        return top;
      },
    };
  }

  // hoisted A* buffers — reused across calls (per-search generation stamp avoids the
  // ~360KB allocate + 80k-cell fill that the old per-call typed arrays paid every repath)
  let _pfN = 0, _pfGen = 0, _came, _gscore, _closed, _seen;
  function _pfEnsure(n) {
    if (n !== _pfN) { _pfN = n; _came = new Int32Array(n); _gscore = new Float32Array(n); _closed = new Uint8Array(n); _seen = new Uint32Array(n); _pfGen = 0; }
  }

  // A* from (sx,sy) world -> (tx,ty) world. Returns array of {x,y} waypoints (world centers) or null.
  function findPath(world, sx, sy, tx, ty, maxExpand) {
    maxExpand = maxExpand || 2500;
    const TILE = world.TILE, cols = world.cols, rows = world.rows;
    const sc = Math.floor(sx / TILE), sr = Math.floor(sy / TILE);
    let tc = Math.floor(tx / TILE), tr = Math.floor(ty / TILE);
    if (!world.tileWalkable(sc, sr)) return null;
    if (!world.tileWalkable(tc, tr)) {
      // snap target to nearest walkable neighbor
      const cand = nearestWalkable(world, tc, tr, 4);
      if (!cand) return null; tc = cand.c; tr = cand.r;
    }
    const idx = (c, r) => r * cols + c;
    _pfEnsure(cols * rows);
    if (_pfGen >= 0xfffffffe) { _seen.fill(0); _pfGen = 0; }   // (practically unreachable) generation wrap
    const gen = ++_pfGen, came = _came, gscore = _gscore, closed = _closed, seen = _seen;
    const touch = (i) => { if (seen[i] !== gen) { seen[i] = gen; came[i] = -1; gscore[i] = Infinity; closed[i] = 0; } };
    const open = Heap();
    const start = idx(sc, sr), goal = idx(tc, tr);
    touch(start); gscore[start] = 0;
    open.push(start, 0);
    // octile distance — admissible/consistent for 8-way movement with 1 / 1.414 step costs
    const h = (c, r) => { const dx = Math.abs(c - tc), dy = Math.abs(r - tr); return (dx + dy) + (1.414 - 2) * Math.min(dx, dy); };
    let expand = 0;
    const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]];
    while (open.size && expand < maxExpand) {
      const cur = open.pop().node;
      if (cur === goal) return reconstruct(came, cur, cols, TILE);
      touch(cur); if (closed[cur]) continue;
      closed[cur] = 1; expand++;
      const cc = cur % cols, cr = (cur / cols) | 0;
      for (const d of dirs) {
        const nc = cc + d[0], nr = cr + d[1];
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        if (!world.tileWalkable(nc, nr)) continue;
        // prevent diagonal corner cutting
        if (d[0] !== 0 && d[1] !== 0) {
          if (!world.tileWalkable(cc + d[0], cr) || !world.tileWalkable(cc, cr + d[1])) continue;
        }
        const ni = idx(nc, nr);
        touch(ni); if (closed[ni]) continue;
        const step = (d[0] !== 0 && d[1] !== 0) ? 1.414 : 1;
        const ng = gscore[cur] + step;
        if (ng < gscore[ni]) {
          gscore[ni] = ng; came[ni] = cur;
          open.push(ni, ng + h(nc, nr));
        }
      }
    }
    return null;
  }

  function reconstruct(came, cur, cols, TILE) {
    const path = [];
    while (cur !== -1) {
      const c = cur % cols, r = (cur / cols) | 0;
      path.push({ x: (c + 0.5) * TILE, y: (r + 0.5) * TILE });
      cur = came[cur];
    }
    path.reverse();
    return simplify(path);
  }

  // string-pull-ish: drop colinear points
  function simplify(path) {
    if (path.length <= 2) return path;
    const out = [path[0]];
    for (let i = 1; i < path.length - 1; i++) {
      const a = out[out.length - 1], b = path[i], c = path[i + 1];
      const dx1 = b.x - a.x, dy1 = b.y - a.y, dx2 = c.x - b.x, dy2 = c.y - b.y;
      if (dx1 * dy2 - dy1 * dx2 !== 0) out.push(b);
    }
    out.push(path[path.length - 1]);
    return out;
  }

  function nearestWalkable(world, c, r, rad) {
    for (let d = 1; d <= rad; d++) {
      for (let dy = -d; dy <= d; dy++) for (let dx = -d; dx <= d; dx++) {
        if (Math.abs(dx) !== d && Math.abs(dy) !== d) continue;
        if (world.tileWalkable(c + dx, r + dy)) return { c: c + dx, r: r + dy };
      }
    }
    return null;
  }

  VAMP.Path = { findPath, nearestWalkable };
})();
