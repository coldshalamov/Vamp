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
 * Load order: after assets.js, before npc.js.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const TAU = Math.PI * 2;
  const cache = {};
  const PAD = 7;

  function get(type, faction, skin, shirt, r) {
    const key = type + '|' + faction + '|' + skin + '|' + shirt + '|' + r;
    return cache[key] || build(key, type, faction, skin, shirt, r);
  }

  function build(key, type, faction, skin, shirt, r) {
    const S = Math.ceil((r + PAD) * 2);
    const c = VAMP.Assets.makeCanvas(S, S);
    const g = c.getContext('2d');
    g.translate(S / 2, S / 2);
    g.lineJoin = 'round';
    drawSilhouette(g, type, faction, skin, shirt, r);
    const o = { canvas: c, cx: S / 2, cy: S / 2, r };
    cache[key] = o; return o;
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
        body(g, r * 0.82, r * 0.98, shirt);
        g.fillStyle = 'rgba(12,12,16,0.85)';  // vest band across chest
        g.beginPath(); g.moveTo(-r * 0.1, -r * 0.62); g.lineTo(r * 0.25, -r * 0.3); g.lineTo(r * 0.25, r * 0.3); g.lineTo(-r * 0.1, r * 0.62); g.closePath(); g.fill();
        head(g, r * 0.42, r, skin);
        break;
      }
      case 'police': {                        // boxy body + shoulder yoke + cap brim
        const swat = type === 'swat';
        const col = swat ? U.shade(shirt, -0.3) : shirt;
        roundBody(g, r * (swat ? 0.92 : 0.82), r * (swat ? 0.9 : 0.82), col);
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
        ell(g, -r * 0.8, 0, r * 0.5, r * 0.16, shirt);  // tail
        body(g, r * 1.05, r * 0.5, shirt);
        ell(g, r * 0.7, -r * 0.2, r * 0.14, r * 0.16, U.shade(skin, -0.2)); // ear
        ell(g, r * 0.7, r * 0.2, r * 0.14, r * 0.16, U.shade(skin, -0.2));
        ell(g, r * 0.85, 0, r * 0.22, r * 0.18, skin); // snout
        break;
      }
      case 'player': {                        // thrall — desaturated, green rim marker
        body(g, r * 0.78, r * 0.74, shirt || '#3a2a55');
        head(g, r * 0.42, r, skin);
        outline(g, 0, 0, r * 0.86, r * 0.82, 'rgba(90,255,140,0.5)', 1.4);
        break;
      }
      default: {                              // civ — soft round, harmless
        body(g, r * 0.8, r * 0.72, shirt);
        head(g, r * 0.42, r, skin);
        if (type === 'rat') break;
      }
    }
  }

  function roundBody(g, rx, ry, col) {
    g.fillStyle = col;
    rr(g, -rx, -ry, rx * 2, ry * 2, Math.min(rx, ry) * 0.4); g.fill();
    g.fillStyle = U.shade(col, 0.14); rr(g, -rx, -ry, rx * 2, ry * 0.9, Math.min(rx, ry) * 0.35); g.fill();
    g.strokeStyle = 'rgba(0,0,0,0.45)'; g.lineWidth = 1; rr(g, -rx, -ry, rx * 2, ry * 2, Math.min(rx, ry) * 0.4); g.stroke();
  }
  function rr(g, x, y, w, h, r) {
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    g.beginPath(); g.moveTo(x + r, y);
    g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r);
    g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath();
  }

  VAMP.Sprites = { get, build, clear() { for (const k in cache) delete cache[k]; } };
})();
