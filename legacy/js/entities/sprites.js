/* =========================================================================
 * VAMPIRE CITY — entities/sprites.js  (VAMP.Sprites)
 * Baked, faction-distinct NPC silhouettes. The "little sprite" complaint is
 * mostly silhouette SAMENESS — every NPC was an ellipse+circle in a different
 * shirt. Here each faction reads as a distinct SHAPE (gang = wide trapezoid,
 * cop = boxy + cap, hunter = hooded teardrop, animal = low + tail) that the
 * eye parses at 12-18px before color, and survives night desaturation.
 *
 * Each silhouette is drawn ONCE to an offscreen canvas facing +X and blitted
 * with a single drawImage per NPC (the render layer rotates/animates it).
 * Load order: util.js → assets.js → sprites.js → npc.js.
 * (VAMP.Util is captured at module load; util.js must precede this file.)
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const TAU = Math.PI * 2;
  const cache = {};
  const cacheKeys = []; // FIFO eviction order
  const MAX_CACHE = 256;
  // Canvas padding: proportional floor ensures room as r grows.
  // Worst-case overshoot: animal tail at -1.3r. PAD_FACTOR=0.35 covers 0.3r + 5% margin.
  // MIN_PAD=7 is the absolute floor for small sprites (outline strokes, r<20).
  // Current max animal r: rat(5) × juggernaut(1.4) → Math.round(7) = 7 → pad = max(7,3) = 7. Safe by floor.
  const MIN_PAD = 7;
  const PAD_FACTOR = 0.35;

  function get(type, faction, skin, shirt, r) {
    r = r | 0; // quantize to integer — prevents float-r cache thrash
    const key = type + '|' + faction + '|' + skin + '|' + shirt + '|' + r;
    return cache[key] || build(key, type, faction, skin, shirt, r);
  }

  function build(key, type, faction, skin, shirt, r) {
    if (cacheKeys.length >= MAX_CACHE) delete cache[cacheKeys.shift()]; // FIFO evict oldest
    const pad = Math.max(MIN_PAD, Math.ceil(r * PAD_FACTOR));
    const S = Math.ceil((r + pad) * 2);
    const c = VAMP.Assets.makeCanvas(S, S);
    const g = c.getContext('2d');
    g.translate(S / 2, S / 2);
    g.lineJoin = 'round';
    drawSilhouette(g, type, faction, skin, shirt, r);
    const o = { canvas: c, cx: S / 2, cy: S / 2, r };
    cache[key] = o; cacheKeys.push(key); return o;
  }

  // ---- shape primitives (all facing +X, origin centred) ----
  function ell(g, x, y, rx, ry, col) { g.fillStyle = col; g.beginPath(); g.ellipse(x, y, rx, ry, 0, 0, TAU); g.fill(); }
  function outline(g, x, y, rx, ry, col, lw) { g.strokeStyle = col; g.lineWidth = lw || 1; g.beginPath(); g.ellipse(x, y, rx, ry, 0, 0, TAU); g.stroke(); }

  function body(g, rx, ry, col) {
    ell(g, 0, 0, rx, ry, col);
    ell(g, -rx * 0.08, -ry * 0.28, rx * 0.7, ry * 0.48, U.shade(col, 0.14)); // top sheen
    ell(g, rx * 0.05, ry * 0.45, rx * 0.78, ry * 0.4, U.shade(col, -0.35));  // ground-contact shade
    outline(g, 0, 0, rx, ry, 'rgba(0,0,0,0.45)', 1);
  }
  function head(g, hx, r, skin) {
    ell(g, hx, 0, r * 0.46, r * 0.46, skin);
    ell(g, hx - r * 0.16, -r * 0.05, r * 0.42, r * 0.42, U.shade(skin, -0.22)); // hair/back of head
  }

  function drawSilhouette(g, type, faction, skin, shirt, r) {
    switch (faction) {
      case 'gang': {                          // wide-shouldered trapezoid + dark vest band
        // true trapezoid: wide ±0.92r at rear shoulders, tapering to ±0.50r at the forward chest
        g.fillStyle = shirt;
        g.beginPath();
        g.moveTo(-r * 0.48, -r * 0.92);       // rear-top shoulder
        g.lineTo( r * 0.30, -r * 0.50);       // front-top chest
        g.lineTo( r * 0.30,  r * 0.50);       // front-bottom chest
        g.lineTo(-r * 0.48,  r * 0.92);       // rear-bottom shoulder
        g.closePath(); g.fill();
        // silhouette outline — matches other factions' edge definition at night
        g.save(); g.strokeStyle = 'rgba(0,0,0,0.40)'; g.lineWidth = 1; g.stroke(); g.restore();
        // sheen — upper-forward quadrant
        g.fillStyle = U.shade(shirt, 0.16);
        g.beginPath(); g.ellipse(r * 0.08, -r * 0.28, r * 0.18, r * 0.36, 0, 0, TAU); g.fill();
        // back-half shade — rear of trapezoid darker
        g.fillStyle = U.shade(shirt, -0.38);
        g.beginPath();
        g.moveTo(-r * 0.48, -r * 0.92);
        g.lineTo(-r * 0.06, -r * 0.46);
        g.lineTo(-r * 0.06,  r * 0.46);
        g.lineTo(-r * 0.48,  r * 0.92);
        g.closePath(); g.fill();
        // dark vest band across mid-chest
        g.fillStyle = 'rgba(12,12,16,0.85)';
        g.beginPath(); g.moveTo(-r * 0.1, -r * 0.62); g.lineTo(r * 0.25, -r * 0.3); g.lineTo(r * 0.25, r * 0.3); g.lineTo(-r * 0.1, r * 0.62); g.closePath(); g.fill();
        head(g, r * 0.42, r, skin);
        break;
      }
      case 'police': {                        // boxy body + shoulder yoke + cap brim
        const swat = type === 'swat';
        const col = swat ? U.shade(shirt, -0.3) : shirt;
        roundBody(g, r * (swat ? 0.92 : 0.82), r * (swat ? 0.9 : 0.82), col, 0.15);
        g.fillStyle = swat ? '#0a0e1c' : U.shade(col, 0.18);          // yoke / vest plate
        g.fillRect(-r * 0.35, -r * 0.72, r * 0.5, r * 1.44);
        head(g, r * 0.42, r, skin);
        g.fillStyle = swat ? '#11151f' : '#0c1838';                    // cap / helmet brim
        g.beginPath(); g.arc(r * 0.42, 0, r * 0.52, -1.2, 1.2); g.fill();
        if (swat) { g.fillStyle = '#2a3140'; g.fillRect(r * 0.2, -r * 0.5, r * 0.5, r * 1.0); } // chest plate
        break;
      }
      case 'inquis': {                        // tall hooded teardrop, hard point forward
        const elder = type === 'elder';
        const hood = elder ? '#241c2a' : '#222228';
        g.fillStyle = hood;                   // teardrop: round back, pointed front
        g.beginPath();
        g.moveTo(r * 1.05, 0);                // front point
        g.quadraticCurveTo(r * 0.2, -r * 0.95, -r * 0.65, -r * 0.55);
        g.quadraticCurveTo(-r * 1.0, 0, -r * 0.65, r * 0.55);
        g.quadraticCurveTo(r * 0.2, r * 0.95, r * 1.05, 0);
        g.closePath(); g.fill();
        outline(g, -r * 0.1, 0, r * 0.85, r * 0.8, 'rgba(0,0,0,0.5)', 1);
        ell(g, r * 0.35, 0, r * 0.3, r * 0.3, U.shade(skin, -0.5)); // shadowed face in the hood
        g.fillStyle = elder ? 'rgba(255,210,90,0.55)' : 'rgba(200,210,230,0.3)'; // hood-edge glint / cross
        g.fillRect(r * 0.1, -1, r * 0.3, 2); g.fillRect(r * 0.22, -r * 0.18, 2, r * 0.36);
        break;
      }
      case 'animal': {                        // low long body + tail + ears
        if (type === 'rat') { body(g, r * 0.8, r * 0.72, shirt); break; } // rats: simple blob, no head
        ell(g, -r * 0.8, 0, r * 0.5, r * 0.16, shirt);  // tail; leftmost extent −1.3r — keep PAD_FACTOR ≥ 0.32 if adjusting
        body(g, r * 1.05, r * 0.5, shirt);
        ell(g, r * 0.7, -r * 0.2, r * 0.14, r * 0.16, U.shade(skin, -0.2)); // ear
        ell(g, r * 0.7, r * 0.2, r * 0.14, r * 0.16, U.shade(skin, -0.2));
        ell(g, r * 0.85, 0, r * 0.22, r * 0.18, skin); // snout
        break;
      }
      case 'player': {                        // thrall — servant silhouette (narrow facing axis), bright purple rim
        body(g, r * 0.52, r * 1.08, shirt || '#3a2a55');
        head(g, r * 0.42, r, skin);
        outline(g, 0, 0, r * 0.60, r * 1.16, 'rgba(140,80,200,0.70)', 1.6);
        break;
      }
      default: {                              // civ — lean angular gothic figure
        // 1. torso — 7-point angular polygon (V silhouette, wider shoulders than waist)
        g.fillStyle = shirt;
        g.beginPath();
        g.moveTo(-r * 0.50, -r * 0.68);     // rear-right shoulder
        g.lineTo( r * 0.08, -r * 0.48);     // front-right armpit
        g.lineTo( r * 0.16, -r * 0.18);     // front-right waist
        g.lineTo( r * 0.22,  0);             // front chest point
        g.lineTo( r * 0.16,  r * 0.18);     // front-left waist
        g.lineTo( r * 0.08,  r * 0.48);     // front-left armpit
        g.lineTo(-r * 0.50,  r * 0.68);     // rear-left shoulder
        g.lineTo(-r * 0.22,  r * 0.24);     // close back — lower
        g.lineTo(-r * 0.22, -r * 0.24);     // close back — upper
        g.closePath();
        g.fill();
        // top sheen — forward-upper quad (proportional to body() helper for night legibility)
        g.fillStyle = U.shade(shirt, 0.14);
        g.beginPath(); g.ellipse(r * 0.05, -r * 0.20, r * 0.25, r * 0.38, 0, 0, TAU); g.fill();
        // back-half shade: dark triangle on the rear side
        g.fillStyle = U.shade(shirt, -0.40);
        g.beginPath();
        g.moveTo(-r * 0.50, -r * 0.68);
        g.lineTo(-r * 0.22, -r * 0.24);
        g.lineTo(-r * 0.22,  r * 0.24);
        g.lineTo(-r * 0.50,  r * 0.68);
        g.closePath();
        g.fill();
        // 2. collar V-line (cheap "clothes" read)
        g.save();
        g.strokeStyle = U.shade(shirt, -0.40);
        g.lineWidth = 1;
        g.beginPath();
        g.moveTo( r * 0.06, -r * 0.20);
        g.lineTo( r * 0.20,  0);
        g.lineTo( r * 0.06,  r * 0.20);
        g.stroke();
        g.restore();
        // 3. head — narrow gothic oval + rear hair/shadow
        const hx = r * 0.42;
        ell(g, hx, 0, r * 0.28, r * 0.38, skin);
        g.fillStyle = U.shade(skin, -0.40);
        g.beginPath();
        g.ellipse(hx, 0, r * 0.28, r * 0.38, 0, Math.PI * 0.5, Math.PI * 1.5, false); // left half = rear shadow
        g.fill();
      }
    }
  }

  function roundBody(g, rx, ry, col, cr) {
    cr = cr !== undefined ? cr : 0.4;
    g.fillStyle = col;
    rr(g, -rx, -ry, rx * 2, ry * 2, Math.min(rx, ry) * cr); g.fill();
    g.fillStyle = 'rgba(255,255,255,0.18)'; rr(g, -rx, -ry, rx * 2, ry * 0.9, Math.min(rx, ry) * cr * 0.875); g.fill();
    g.strokeStyle = 'rgba(0,0,0,0.45)'; g.lineWidth = 1; rr(g, -rx, -ry, rx * 2, ry * 2, Math.min(rx, ry) * cr); g.stroke();
  }
  function rr(g, x, y, w, h, r) {
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    g.beginPath(); g.moveTo(x + r, y);
    g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r);
    g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath();
  }

  VAMP.Sprites = { get, clear() { for (const k in cache) delete cache[k]; cacheKeys.length = 0; } };
})();
