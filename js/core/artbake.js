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
    return c;
  }

  function resizeTile(src, size) {
    const c = VAMP.Assets.makeCanvas(size, size);
    const g = c.getContext('2d');
    g.imageSmoothingEnabled = true;
    g.drawImage(src, 0, 0, size, size);
    return c;
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
    return c;
  }

  VAMP.ArtBake = { removeChromaKey, resizeTile, enhanceTile, bakeProceduralTile };
})();