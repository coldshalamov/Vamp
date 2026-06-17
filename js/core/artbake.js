/* =========================================================================
 * VAMPIRE CITY — artbake.js
 * Runtime image processing: chroma key, tile resize, enhanced procedural tiles.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  function removeChromaKey(img, keyHex, tolerance) {
    tolerance = tolerance == null ? 0.42 : tolerance;
    const c = VAMP.Assets.makeCanvas(img.width, img.height);
    const g = c.getContext('2d');
    g.drawImage(img, 0, 0);
    const d = g.getImageData(0, 0, c.width, c.height);
    const data = d.data;
    const kr = parseInt(keyHex.slice(1, 3), 16);
    const kg = parseInt(keyHex.slice(3, 5), 16);
    const kb = parseInt(keyHex.slice(5, 7), 16);
    const tol = tolerance * 255;
    for (let i = 0; i < data.length; i += 4) {
      const dr = Math.abs(data[i] - kr);
      const dg = Math.abs(data[i + 1] - kg);
      const db = Math.abs(data[i + 2] - kb);
      if (dr + dg + db < tol * 1.8) data[i + 3] = 0;
      else if (dr + dg + db < tol * 2.8) data[i + 3] = Math.min(data[i + 3], 120);
    }
    g.putImageData(d, 0, 0);
    return despillMagenta(c, kr, kg, kb);
  }

  // Kill pink/magenta halos on thin vertical props (lamps, poles).
  function despillMagenta(canvas, kr, kg, kb) {
    kr = kr == null ? 255 : kr; kg = kg == null ? 0 : kg; kb = kb == null ? 255 : kb;
    const g = canvas.getContext('2d');
    const d = g.getImageData(0, 0, canvas.width, canvas.height);
    const data = d.data;
    for (let i = 0; i < data.length; i += 4) {
      if (data[i + 3] < 8) continue;
      const spill = Math.max(0, data[i] - data[i + 1] * 0.85, data[i + 2] - data[i + 1] * 0.85);
      if (spill > 28 && data[i] > data[i + 1] + 18 && data[i + 2] > data[i + 1] + 18) {
        const k = Math.min(1, spill / 90);
        data[i] = data[i] * (1 - k * 0.55) + kr * k * 0.1;
        data[i + 2] = data[i + 2] * (1 - k * 0.55) + kb * k * 0.1;
      }
    }
    g.putImageData(d, 0, 0);
    return canvas;
  }

  function resizeTile(src, size) {
    const c = VAMP.Assets.makeCanvas(size, size);
    const g = c.getContext('2d');
    g.imageSmoothingEnabled = true;
    g.drawImage(src, 0, 0, size, size);
    return c;
  }

  function sharpen(canvas, amount) {
    amount = amount == null ? 0.35 : amount;
    const w = canvas.width, h = canvas.height;
    const g = canvas.getContext('2d');
    const d = g.getImageData(0, 0, w, h);
    const src = new Uint8ClampedArray(d.data);
    const out = d.data;
    for (let y = 1; y < h - 1; y++) {
      for (let x = 1; x < w - 1; x++) {
        const i = (y * w + x) * 4;
        for (let c = 0; c < 3; c++) {
          const val = src[i + c] * (1 + amount * 4)
            - (src[i + c - 4] + src[i + c + 4] + src[i + c - w * 4] + src[i + c + w * 4]) * amount;
          out[i + c] = Math.max(0, Math.min(255, val));
        }
      }
    }
    g.putImageData(d, 0, 0);
    return canvas;
  }

  // Blend authored tile with subtle noise for organic variation
  function enhanceTile(canvas, baseHex, rngSeed) {
    const g = canvas.getContext('2d');
    const rng = U.makeRNG(rngSeed || 42);
    const w = canvas.width, h = canvas.height;
    const n = Math.floor(w * h * 0.08);
    for (let i = 0; i < n; i++) {
      const x = Math.floor(rng() * w), y = Math.floor(rng() * h);
      const a = rng() * 0.12;
      g.fillStyle = rng() < 0.5 ? `rgba(255,255,255,${a})` : `rgba(0,0,0,${a})`;
      g.fillRect(x, y, 1 + (rng() < 0.3 ? 1 : 0), 1);
    }
    return canvas;
  }

  // Procedural high-quality tiles when bitmaps fail to load
  function bakeProceduralTile(kind, size) {
    const rng = U.makeRNG(kind.length * 997);
    const bases = {
      asphalt: '#1b1b22', sidewalk: '#34343f', grass: '#16321f',
      water: '#0c1e33', dirt: '#2a2118', plaza: '#2b2730',
      concrete: '#2b2730',
    };
    const c = VAMP.Assets.noiseTile(size, bases[kind] || '#222', 0.14, 0.45, rng);
    if (kind === 'asphalt') {
      const g = c.getContext('2d');
      g.strokeStyle = 'rgba(80,75,70,0.15)'; g.lineWidth = 1;
      for (let i = 0; i < 6; i++) {
        const y = rng() * size;
        g.beginPath(); g.moveTo(0, y); g.lineTo(size, y + rng() * 4 - 2); g.stroke();
      }
    }
    if (kind === 'water') {
      const g = c.getContext('2d');
      g.strokeStyle = 'rgba(60,120,180,0.12)'; g.lineWidth = 1;
      for (let i = 0; i < 4; i++) {
        const y = rng() * size;
        g.beginPath();
        for (let x = 0; x <= size; x += 4) g.lineTo(x, y + Math.sin(x * 0.15 + i) * 3);
        g.stroke();
      }
    }
    if (kind === 'concrete' || kind === 'plaza') {
      const g = c.getContext('2d');
      g.strokeStyle = 'rgba(90,88,100,0.08)'; g.lineWidth = 1;
      const step = 16;
      for (let x = 0; x <= size; x += step) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, size); g.stroke(); }
      for (let y = 0; y <= size; y += step) { g.beginPath(); g.moveTo(0, y); g.lineTo(size, y); g.stroke(); }
    }
    return c;
  }

  // Painted top-down vehicle — consistent orientation (front = +X), no mixed side-view assets.
  function bakeVehicleTopDown(type, seed) {
    seed = (seed >>> 0) || 1;
    const rng = U.makeRNG(seed);
    const specs = {
      sedan:  { w: 96, h: 44, wb: 0.58, cabin: 0.42, sport: false },
      sport:  { w: 92, h: 40, wb: 0.54, cabin: 0.36, sport: true },
      van:    { w: 108, h: 50, wb: 0.62, cabin: 0.55, sport: false },
      police: { w: 98, h: 44, wb: 0.58, cabin: 0.44, sport: false, police: true },
      hearse: { w: 112, h: 46, wb: 0.6, cabin: 0.48, sport: false, hearse: true },
    };
    const sp = specs[type] || specs.sedan;
    const c = VAMP.Assets.makeCanvas(sp.w + 8, sp.h + 8);
    const g = c.getContext('2d');
    const ox = 4, oy = 4, w = sp.w, h = sp.h;
    const body = type === 'police' ? '#1a2848' : type === 'hearse' ? '#121218' : '#3a2e32';
    const accent = type === 'sport' ? '#8a1828' : type === 'police' ? '#d8dce8' : U.shade(body, 0.12);
    g.fillStyle = 'rgba(0,0,0,0.28)';
    g.beginPath(); g.ellipse(ox + w * 0.5, oy + h * 0.62, w * 0.46, h * 0.22, 0, 0, U.TAU); g.fill();
    const grd = g.createLinearGradient(ox, oy, ox, oy + h);
    grd.addColorStop(0, U.shade(body, 0.22)); grd.addColorStop(0.45, body); grd.addColorStop(1, U.shade(body, -0.28));
    g.fillStyle = grd;
    g.beginPath();
    g.moveTo(ox + w * 0.08, oy + h * 0.18);
    g.lineTo(ox + w * 0.88, oy + h * 0.14);
    g.lineTo(ox + w * 0.96, oy + h * 0.5);
    g.lineTo(ox + w * 0.9, oy + h * 0.86);
    g.lineTo(ox + w * 0.1, oy + h * 0.9);
    g.lineTo(ox + w * 0.02, oy + h * 0.5);
    g.closePath(); g.fill();
    g.strokeStyle = 'rgba(0,0,0,0.45)'; g.lineWidth = 1.2; g.stroke();
    if (sp.sport) {
      g.fillStyle = accent;
      g.fillRect(ox + w * 0.12, oy + h * 0.22, w * 0.76, h * 0.1);
      g.fillRect(ox + w * 0.12, oy + h * 0.68, w * 0.76, h * 0.1);
    }
    const wx = ox + w * (1 - sp.cabin) * 0.35, wy = oy + h * 0.2, ww = w * sp.cabin * 0.9, wh = h * 0.6;
    g.fillStyle = 'rgba(70,110,150,0.55)'; g.fillRect(wx, wy, ww, wh);
    g.strokeStyle = 'rgba(20,30,45,0.7)'; g.strokeRect(wx + 0.5, wy + 0.5, ww - 1, wh - 1);
    g.fillStyle = 'rgba(100,140,180,0.35)'; g.fillRect(wx + ww * 0.08, wy + wh * 0.12, ww * 0.35, wh * 0.76);
    if (sp.police) {
      g.fillStyle = '#e8ecf4'; g.fillRect(ox + w * 0.28, oy + h * 0.34, w * 0.44, h * 0.32);
      g.fillStyle = '#ff3030'; g.fillRect(ox + w * 0.3, oy + h * 0.02, w * 0.16, h * 0.08);
      g.fillStyle = '#3060ff'; g.fillRect(ox + w * 0.54, oy + h * 0.02, w * 0.16, h * 0.08);
    }
    if (sp.hearse) {
      g.fillStyle = 'rgba(180,180,200,0.25)'; g.fillRect(ox + w * 0.55, oy + h * 0.18, w * 0.34, h * 0.64);
      g.strokeStyle = 'rgba(220,220,240,0.35)'; g.strokeRect(ox + w * 0.55, oy + h * 0.18, w * 0.34, h * 0.64);
    }
    const wheelY = [0.22, 0.78], wheelX = [0.18, 0.78];
    for (const fy of wheelY) for (const fx of wheelX) {
      const cx = ox + w * fx, cy = oy + h * fy, rw = w * 0.11, rh = h * 0.2;
      g.fillStyle = '#0a0a0e'; g.beginPath(); g.ellipse(cx, cy, rw, rh, 0, 0, U.TAU); g.fill();
      g.fillStyle = '#2a2a32'; g.beginPath(); g.ellipse(cx, cy, rw * 0.55, rh * 0.55, 0, 0, U.TAU); g.fill();
    }
    g.fillStyle = 'rgba(255,230,170,0.9)';
    g.fillRect(ox + w * 0.92, oy + h * 0.28, w * 0.05, h * 0.12);
    g.fillRect(ox + w * 0.92, oy + h * 0.6, w * 0.05, h * 0.12);
    g.fillStyle = 'rgba(220,50,40,0.85)';
    g.fillRect(ox + w * 0.02, oy + h * 0.3, w * 0.04, h * 0.1);
    g.fillRect(ox + w * 0.02, oy + h * 0.6, w * 0.04, h * 0.1);
    if (rng() > 0.5) {
      g.fillStyle = 'rgba(255,255,255,0.08)';
      g.fillRect(ox + w * 0.2, oy + h * 0.16, w * 0.5, 2);
    }
    return c;
  }

  function bakePropLamp(seed) {
    seed = (seed >>> 0) || 1;
    const c = VAMP.Assets.makeCanvas(48, 112);
    const g = c.getContext('2d');
    const variant = seed % 3;
    g.fillStyle = 'rgba(0,0,0,0.3)'; g.beginPath(); g.ellipse(24, 108, 10, 3, 0, 0, U.TAU); g.fill();
    const pole = variant === 0 ? '#1c1e26' : variant === 1 ? '#242630' : '#181a22';
    const trim = variant === 2 ? '#8a7040' : '#6a5a38';
    g.fillStyle = pole; g.fillRect(22, 28, 4, 80);
    g.fillStyle = trim; g.fillRect(20, 26, 8, 4); g.fillRect(21, 52, 6, 3);
    g.fillStyle = '#2a2c36'; g.fillRect(14, 8, 20, 18);
    g.fillStyle = '#3a3c48'; g.fillRect(16, 10, 16, 14);
    const lg = g.createRadialGradient(24, 14, 0, 24, 14, 18);
    lg.addColorStop(0, 'rgba(255,220,150,0.95)'); lg.addColorStop(0.35, 'rgba(255,190,100,0.45)'); lg.addColorStop(1, 'rgba(255,160,60,0)');
    g.fillStyle = lg; g.beginPath(); g.arc(24, 14, 18, 0, U.TAU); g.fill();
    g.fillStyle = 'rgba(255,240,200,0.9)'; g.fillRect(20, 12, 8, 6);
    return c;
  }

  function bakePropTree(seed) {
    seed = (seed >>> 0) || 1;
    const rng = U.makeRNG(seed);
    const variant = seed % 3;
    const c = VAMP.Assets.makeCanvas(64, 80);
    const g = c.getContext('2d');
    const hues = ['#1a3824', '#243a2a', '#2e4a32', '#1e3220'];
    const leaf = hues[variant];
    const sc = 0.85 + rng() * 0.3;
    g.fillStyle = 'rgba(0,0,0,0.25)'; g.beginPath(); g.ellipse(32, 74, 14 * sc, 4, 0, 0, U.TAU); g.fill();
    g.fillStyle = '#3a2a1a'; g.fillRect(29, 48, 6, 22 * sc);
    g.fillStyle = U.shade(leaf, 0.08);
    g.beginPath(); g.ellipse(32, 32 * sc, 22 * sc, 26 * sc, 0, 0, U.TAU); g.fill();
    g.fillStyle = U.shade(leaf, -0.12);
    g.beginPath(); g.ellipse(26, 38 * sc, 14 * sc, 16 * sc, 0, 0, U.TAU); g.fill();
    g.beginPath(); g.ellipse(40, 36 * sc, 12 * sc, 14 * sc, 0, 0, U.TAU); g.fill();
    if (variant === 1) { g.fillStyle = U.shade(leaf, 0.18); g.beginPath(); g.ellipse(32, 22 * sc, 10 * sc, 12 * sc, 0, 0, U.TAU); g.fill(); }
    return c;
  }

  function bakeWalkSheet(kind, seed) {
    seed = (seed >>> 0) || 1;
    const rng = U.makeRNG(seed);
    const specs = {
      player_walk:       { fw: 32, fh: 48, dirs: 8, frames: 4, body: '#2a1a30', cape: '#160814', accent: '#7a1530' },
      npc_civilian_walk: { fw: 24, fh: 32, dirs: 4, frames: 2, body: '#4a5a68', cape: null, accent: '#8899aa' },
      npc_gang:          { fw: 24, fh: 32, dirs: 4, frames: 2, body: '#3a2830', cape: null, accent: '#c04050' },
      npc_cop:           { fw: 24, fh: 32, dirs: 4, frames: 2, body: '#2a3448', cape: null, accent: '#5080c0' },
      npc_hunter:        { fw: 24, fh: 32, dirs: 4, frames: 2, body: '#3a3828', cape: null, accent: '#a08040' },
      npc_thrall:        { fw: 24, fh: 32, dirs: 4, frames: 2, body: '#2a3a2a', cape: null, accent: '#5a9a6a' },
      rat:               { fw: 16, fh: 12, dirs: 4, frames: 1, body: '#4a3a32', cape: null, accent: '#6a5a48' },
    };
    const sp = specs[kind] || specs.npc_civilian_walk;
    const c = VAMP.Assets.makeCanvas(sp.fw * sp.frames, sp.fh * sp.dirs);
    const g = c.getContext('2d');
    for (let d = 0; d < sp.dirs; d++) {
      const ang = (d / sp.dirs) * U.TAU;
      for (let f = 0; f < sp.frames; f++) {
        const ox = f * sp.fw, oy = d * sp.fh;
        const step = Math.sin((f / sp.frames) * U.TAU) * 2;
        g.fillStyle = 'rgba(0,0,0,0.25)';
        g.beginPath(); g.ellipse(ox + sp.fw / 2, oy + sp.fh * 0.88, sp.fw * 0.35, sp.fh * 0.08, 0, 0, U.TAU); g.fill();
        if (sp.cape) {
          g.fillStyle = sp.cape;
          g.beginPath();
          g.moveTo(ox + sp.fw * 0.38, oy + sp.fh * 0.32);
          g.quadraticCurveTo(ox + sp.fw * 0.06, oy + sp.fh * 0.48, ox + sp.fw * 0.12, oy + sp.fh * 0.78);
          g.quadraticCurveTo(ox + sp.fw * 0.22, oy + sp.fh * 0.82, ox + sp.fw * 0.58, oy + sp.fh * 0.74);
          g.quadraticCurveTo(ox + sp.fw * 0.62, oy + sp.fh * 0.5, ox + sp.fw * 0.48, oy + sp.fh * 0.34);
          g.closePath(); g.fill();
          g.fillStyle = U.shade(sp.accent, -0.15);
          g.fillRect(ox + sp.fw * 0.4, oy + sp.fh * 0.36, sp.fw * 0.18, sp.fh * 0.14);
        }
        g.fillStyle = sp.body;
        g.beginPath(); g.ellipse(ox + sp.fw / 2, oy + sp.fh * 0.52, sp.fw * 0.3, sp.fh * 0.27, 0, 0, U.TAU); g.fill();
        if (kind === 'player_walk') {
          g.fillStyle = '#1a1018';
          g.beginPath(); g.arc(ox + sp.fw * 0.5, oy + sp.fh * 0.28, sp.fw * 0.14, 0, U.TAU); g.fill();
          g.fillStyle = '#d83040';
          g.fillRect(ox + sp.fw * 0.44, oy + sp.fh * 0.27, 2, 2);
          g.fillRect(ox + sp.fw * 0.52, oy + sp.fh * 0.27, 2, 2);
        } else {
          g.fillStyle = sp.accent;
          g.fillRect(ox + sp.fw * 0.38, oy + sp.fh * 0.38, sp.fw * 0.24, sp.fh * 0.16);
        }
        const lx = ox + sp.fw / 2 + Math.cos(ang + Math.PI / 2) * step * 0.3;
        const ly = oy + sp.fh * 0.72 + step;
        g.fillStyle = '#121018';
        g.beginPath(); g.ellipse(lx - 4, ly, 3, 5, 0, 0, U.TAU); g.fill();
        g.beginPath(); g.ellipse(lx + 4, ly, 3, 5, 0, 0, U.TAU); g.fill();
        if (kind === 'rat') {
          g.fillStyle = sp.body;
          g.beginPath(); g.ellipse(ox + sp.fw / 2, oy + sp.fh / 2, sp.fw * 0.4, sp.fh * 0.35, ang, 0, U.TAU); g.fill();
          g.fillStyle = '#2a1a18';
          g.beginPath(); g.arc(ox + sp.fw * 0.7, oy + sp.fh * 0.35, 2, 0, U.TAU); g.fill();
        }
        if (rng() > 0.97) {
          g.fillStyle = 'rgba(255,255,255,0.06)';
          g.fillRect(ox + 2, oy + 2, sp.fw - 4, 1);
        }
      }
    }
    return c;
  }

  function bakeAutotileAtlas() {
    const ts = 32, cols = 4, rows = 4;
    const c = VAMP.Assets.makeCanvas(ts * cols, ts * rows);
    const g = c.getContext('2d');
    const kinds = ['road', 'side', 'grass', 'water'];
    const cols4 = { road: '#1b1b22', side: '#34343f', grass: '#16321f', water: '#0c1e33' };
    for (let mask = 0; mask < 16; mask++) {
      const mx = (mask % 4) * ts, my = ((mask / 4) | 0) * ts;
      const n = [(mask & 1), (mask & 2) >> 1, (mask & 4) >> 2, (mask & 8) >> 3];
      const base = n[0] && n[1] ? cols4.side : n[2] ? cols4.grass : cols4.road;
      g.fillStyle = base;
      g.fillRect(mx, my, ts, ts);
      for (let i = 0; i < 4; i++) {
        if (!n[i]) continue;
        const blend = [cols4.grass, cols4.water, cols4.side, cols4.road][i % 4];
        g.fillStyle = blend;
        if (i === 0) g.fillRect(mx, my, ts, ts * 0.35);
        else if (i === 1) g.fillRect(mx, my + ts * 0.65, ts, ts * 0.35);
        else if (i === 2) g.fillRect(mx, my, ts * 0.35, ts);
        else g.fillRect(mx + ts * 0.65, my, ts * 0.35, ts);
      }
      g.strokeStyle = 'rgba(0,0,0,0.12)'; g.strokeRect(mx + 0.5, my + 0.5, ts - 1, ts - 1);
      if (mask > 0 && mask < 15) {
        g.fillStyle = 'rgba(255,255,255,0.03)';
        if (mask & 1) g.fillRect(mx + 2, my + 2, ts - 4, 4);
        if (mask & 2) g.fillRect(mx + 2, my + ts - 6, ts - 4, 4);
        if (mask & 4) g.fillRect(mx + 2, my + 2, 4, ts - 4);
        if (mask & 8) g.fillRect(mx + ts - 6, my + 2, 4, ts - 4);
      }
    }
    return c;
  }

  function bakeDistrictModule(kind, districtId) {
    const kits = VAMP.DistrictArt && VAMP.DistrictArt.KITS;
    const kit = kits && kits[districtId] ? kits[districtId] : { bld: '#2a2c3a', accent: '#6c7bd6' };
    const w = kind === 'roof' ? 64 : 32;
    const h = kind === 'roof' ? 32 : 48;
    const c = VAMP.Assets.makeCanvas(w, h);
    const g = c.getContext('2d');
    const rng = U.makeRNG((districtId.length * 131 + (kind === 'roof' ? 7 : 3)) | 0);
    if (kind === 'roof') {
      g.fillStyle = U.shade(kit.bld, 0.1);
      g.fillRect(0, 0, w, h);
      for (let i = 0; i < 3; i++) {
        g.fillStyle = U.shade(kit.bld, (rng() - 0.5) * 0.15);
        g.fillRect(rng() * (w - 12), rng() * (h - 8), 10 + rng() * 8, 6 + rng() * 4);
      }
      g.fillStyle = kit.accent; g.globalAlpha = 0.35;
      g.fillRect(0, h - 3, w, 3); g.globalAlpha = 1;
    } else {
      g.fillStyle = U.shade(kit.bld, -0.2);
      g.fillRect(0, 0, w, h);
      for (let r = 0; r < 4; r++) for (let col = 0; col < 2; col++) {
        if (rng() > kit.h * 0.5 + 0.2) continue;
        g.fillStyle = rng() < 0.7 ? 'rgba(255,200,110,0.5)' : 'rgba(150,190,255,0.45)';
        g.fillRect(4 + col * 12, 6 + r * 10, 5, 5);
      }
    }
    return c;
  }

  function bakeMenuBackdrop(kind) {
    const specs = {
      board: { bg: '#120c10', accent: '#ffd24a', motif: 'contracts' },
      map:   { bg: '#0a1018', accent: '#5a9cff', motif: 'map' },
    };
    const sp = specs[kind] || specs.board;
    const c = VAMP.Assets.makeCanvas(640, 420);
    const g = c.getContext('2d');
    const rng = U.makeRNG(kind.length * 313);
    const grad = g.createRadialGradient(320, 180, 40, 320, 210, 420);
    grad.addColorStop(0, U.shade(sp.bg, 0.15));
    grad.addColorStop(1, sp.bg);
    g.fillStyle = grad;
    g.fillRect(0, 0, c.width, c.height);
    g.strokeStyle = sp.accent;
    g.globalAlpha = 0.12;
    for (let i = 0; i < 12; i++) {
      const x = rng() * c.width, y = rng() * c.height;
      g.beginPath(); g.arc(x, y, 20 + rng() * 40, 0, U.TAU); g.stroke();
    }
    g.globalAlpha = 0.25;
    g.fillStyle = sp.accent;
    if (sp.motif === 'contracts') {
      for (let i = 0; i < 6; i++) {
        const x = 40 + i * 95, y = 60 + (i % 2) * 30;
        g.fillRect(x, y, 70, 90);
        g.strokeRect(x + 4, y + 8, 62, 74);
      }
    } else {
      g.strokeStyle = sp.accent;
      for (let r = 0; r < 5; r++) for (let col = 0; col < 8; col++) {
        if (rng() > 0.35) g.strokeRect(30 + col * 72, 40 + r * 72, 64, 64);
      }
    }
    g.globalAlpha = 1;
    return c;
  }

  function bakePOIFacade(poiType) {
    const specs = {
      haven:     { bg: '#1a1428', accent: '#5a9cff', glyph: '+' },
      bloodbank: { bg: '#281018', accent: '#ff2f6e', glyph: '♥' },
      club:      { bg: '#201028', accent: '#e0457b', glyph: '♪' },
      board:     { bg: '#181820', accent: '#ffd24a', glyph: '!' },
      market:    { bg: '#1a2018', accent: '#5ad06a', glyph: '$' },
    };
    const sp = specs[poiType] || specs.market;
    const c = VAMP.Assets.makeCanvas(48, 40);
    const g = c.getContext('2d');
    g.fillStyle = sp.bg; g.fillRect(0, 0, 48, 40);
    g.strokeStyle = sp.accent; g.lineWidth = 2; g.strokeRect(2, 2, 44, 36);
    g.fillStyle = sp.accent;
    g.font = 'bold 18px monospace'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(sp.glyph, 24, 20);
    g.textAlign = 'left'; g.textBaseline = 'alphabetic';
    return c;
  }

  VAMP.ArtBake = {
    removeChromaKey, despillMagenta, resizeTile, enhanceTile, sharpen,
    bakeProceduralTile, bakeVehicleTopDown, bakePropLamp, bakePropTree,
    bakeWalkSheet, bakeAutotileAtlas, bakeDistrictModule, bakePOIFacade, bakeMenuBackdrop,
  };
})();