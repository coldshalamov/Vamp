/* =========================================================================
 * VAMPIRE CITY — assets.js
 * Procedural textures + bitmap asset loader (file:// compatible).
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const Bake = () => VAMP.ArtBake;

  function makeCanvas(w, h) {
    const c = document.createElement('canvas');
    c.width = Math.max(1, Math.ceil(w)); c.height = Math.max(1, Math.ceil(h));
    return c;
  }

  function noiseTile(size, base, contrast, density, rng) {
    const c = makeCanvas(size, size);
    const g = c.getContext('2d');
    g.fillStyle = base; g.fillRect(0, 0, size, size);
    const n = Math.floor(size * size * density);
    for (let i = 0; i < n; i++) {
      const x = Math.floor(rng() * size), y = Math.floor(rng() * size);
      const d = (rng() * 2 - 1) * contrast;
      g.fillStyle = d >= 0 ? `rgba(255,255,255,${d})` : `rgba(0,0,0,${-d})`;
      const s = rng() < 0.85 ? 1 : 2;
      g.fillRect(x, y, s, s);
    }
    return c;
  }

  const patterns = {};
  const bitmaps = {};
  const processed = {};
  let built = false;
  let ready = false;
  let loadProgress = 0;
  let loadTotal = 0;

  function build(ctx) {
    if (built) return patterns;
    const rng = U.makeRNG(1337);
    const ts = 64;
    const kinds = ['asphalt', 'sidewalk', 'grass', 'water', 'dirt', 'concrete', 'plaza', 'roof1', 'roof2', 'roof3', 'roof4'];
    const defs = {};
    if (processed.asphalt_wet_tile) defs.asphalt = processed.asphalt_wet_tile;
    if (processed.sidewalk_tile) defs.sidewalk = processed.sidewalk_tile;
    if (processed.ground_grass_tile) defs.grass = processed.ground_grass_tile;
    if (processed.ground_concrete_tile) defs.concrete = processed.ground_concrete_tile;
    if (processed.ground_dirt_tile) defs.dirt = processed.ground_dirt_tile;
    if (processed.ground_plaza_tile) defs.plaza = processed.ground_plaza_tile;
    for (const k of kinds) {
      if (defs[k]) continue;
      if (processed[k + '_tile']) defs[k] = processed[k + '_tile'];
      else defs[k] = noiseTile(ts, patternBase(k), 0.12, 0.45, rng);
    }
    for (const k in defs) patterns[k] = ctx.createPattern(defs[k], 'repeat');
    patterns._canvas = defs;
    built = true;
    return patterns;
  }

  function patternBase(k) {
    const m = { asphalt: '#1b1b22', sidewalk: '#34343f', grass: '#16321f', water: '#0c1e33', dirt: '#2a2118', concrete: '#2b2730', plaza: '#2b2730', roof1: '#23232c', roof2: '#2c2330', roof3: '#1f2a2a', roof4: '#2a2422' };
    return m[k] || '#222';
  }

  function rebuildPatterns(ctx) {
    built = false;
    for (const k in patterns) delete patterns[k];
    build(ctx);
  }

  function loadImage(url) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => reject(new Error('Failed: ' + url));
      img.src = url;
    });
  }

  function bakePuddleDecal() {
    const c = makeCanvas(32, 24);
    const g = c.getContext('2d');
    const grd = g.createRadialGradient(16, 12, 2, 16, 12, 14);
    grd.addColorStop(0, 'rgba(140,180,220,0.35)');
    grd.addColorStop(0.6, 'rgba(80,120,180,0.15)');
    grd.addColorStop(1, 'rgba(60,100,160,0)');
    g.fillStyle = grd;
    g.beginPath(); g.ellipse(16, 12, 14, 9, 0, 0, U.TAU); g.fill();
    processed.puddle_decal = c;
    bitmaps.puddle_decal = c;
  }

  function bakeRune() {
    const c = makeCanvas(128, 128);
    const g = c.getContext('2d');
    g.strokeStyle = 'rgba(224,176,80,0.85)'; g.lineWidth = 2;
    g.beginPath(); g.arc(64, 64, 48, 0, U.TAU); g.stroke();
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * U.TAU;
      g.beginPath(); g.moveTo(64 + Math.cos(a) * 20, 64 + Math.sin(a) * 20);
      g.lineTo(64 + Math.cos(a) * 52, 64 + Math.sin(a) * 52); g.stroke();
    }
    processed.rune_shockwave = c;
    bitmaps.rune_shockwave = c;
  }

  function sliceHorizontalSheet(src, count, keys) {
    const fw = Math.max(1, Math.floor(src.width / count));
    const fh = src.height;
    for (let i = 0; i < count && i < keys.length; i++) {
      const c = makeCanvas(fw, fh);
      const g = c.getContext('2d');
      g.drawImage(src, i * fw, 0, fw, fh, 0, 0, fw, fh);
      bitmaps[keys[i]] = c;
    }
  }

  function processLoaded(key, img, opts) {
    opts = opts || {};
    let canvas = img;
    if (opts.chroma && Bake()) canvas = Bake().removeChromaKey(img, opts.chroma);
    if (opts.sharpen && Bake() && Bake().sharpen) canvas = Bake().sharpen(canvas, opts.sharpen);
    if (opts.sheet) {
      sliceHorizontalSheet(canvas, opts.sheetCount, opts.sheetKeys || []);
      bitmaps[key] = canvas;
      return canvas;
    }
    if (opts.tile) {
      const t = Bake().resizeTile(canvas, opts.tileSize || 128);
      if (Bake()) Bake().enhanceTile(t, null, key.length * 31);
      processed[key + '_tile'] = t;
      bitmaps[key] = t;
      return t;
    }
    bitmaps[key] = canvas;
    return canvas;
  }

  function loadImageWithFallback(stem) {
    const exts = VAMP.AssetManifest ? VAMP.AssetManifest.tryExtensions(stem) : [stem + '.jpg'];
    let i = 0;
    function tryNext() {
      if (i >= exts.length) return Promise.reject(new Error('Failed: ' + stem));
      const url = (VAMP.AssetManifest ? VAMP.AssetManifest.BASE : 'assets/images/') + exts[i++];
      return loadImage(url).catch(tryNext);
    }
    return tryNext();
  }

  function loadAll(onProgress) {
    const paths = (VAMP.AssetManifest && VAMP.AssetManifest.pathsForLoader)
      ? Object.assign({}, VAMP.ArtPaths || {}, VAMP.AssetManifest.pathsForLoader())
      : (VAMP.ArtPaths || {});
    const entries = Object.keys(paths);
    loadTotal = entries.length;
    loadProgress = 0;
    const jobs = entries.map((key) => {
      const opts = (VAMP.AssetManifest && VAMP.AssetManifest.getLoadOpts)
        ? VAMP.AssetManifest.getLoadOpts(key)
        : { chroma: null, tile: false };
      if (!opts.chroma && !opts.tile) {
        if (key === 'asphalt_wet' || key === 'sidewalk') { opts.tile = true; opts.tileSize = 512; }
        const chromaKeys = ['player_vampire', 'prop_lamp', 'prop_lamp_alt', 'prop_tree', 'prop_tree_alt1', 'prop_tree_alt2',
          'vehicle_sedan', 'vehicle_sport', 'vehicle_van', 'vehicle_hearse', 'vehicle_police',
          'npc_civilian', 'projectile_blood', 'discipline_icons', 'clan_emblems'];
        if (chromaKeys.indexOf(key) >= 0) opts.chroma = (VAMP.ArtFlags && VAMP.ArtFlags.chromaKey) || '#ff00ff';
        if (opts.chroma && (key.indexOf('prop_') === 0 || key.indexOf('vehicle_') === 0)) opts.sharpen = 0.28;
        if (key === 'discipline_icons') {
          opts.sheet = true;
          opts.sheetCount = (VAMP.DisciplineIconKeys && VAMP.DisciplineIconKeys.length) || 10;
          opts.sheetKeys = VAMP.DisciplineIconKeys;
        }
        if (key === 'clan_emblems') {
          opts.sheet = true;
          opts.sheetCount = (VAMP.ClanEmblemKeys && VAMP.ClanEmblemKeys.length) || 7;
          opts.sheetKeys = VAMP.ClanEmblemKeys;
        }
      }
      const stem = (VAMP.AssetManifest && VAMP.AssetManifest.getEntry(key))
        ? VAMP.AssetManifest.getEntry(key).path
        : null;
      const loader = stem ? () => loadImageWithFallback(stem) : () => loadImage(paths[key]);
      return loader().then((img) => {
        processLoaded(key, img, opts);
        loadProgress++;
        if (onProgress) onProgress(loadProgress, loadTotal, key);
      }).catch(() => {
        loadProgress++;
        if (onProgress) onProgress(loadProgress, loadTotal, key + ' (fallback)');
      });
    });
    bakePuddleDecal();
    bakeRune();
    return Promise.all(jobs).then(() => {
      bakeProceduralSprites();
      bakeManifestProcedural();
      if (VAMP.LightWorker && VAMP.LightWorker.init) VAMP.LightWorker.init();
      ready = true;
      const canvas = document.getElementById('game');
      if (canvas) {
        const ctx = canvas.getContext('2d');
        if (ctx) rebuildPatterns(ctx);
      }
    });
  }

  function bakeProceduralSprites() {
    const Bake = VAMP.ArtBake;
    if (!Bake) return;
    const vTypes = ['sedan', 'sport', 'van', 'police', 'hearse'];
    for (let i = 0; i < vTypes.length; i++) {
      const t = vTypes[i];
      const key = 'vehicle_' + t;
      bitmaps[key + '_topdown'] = Bake.bakeVehicleTopDown(t, (i + 1) * 9973);
    }
    bitmaps.prop_lamp_baked0 = Bake.bakePropLamp(11);
    bitmaps.prop_lamp_baked1 = Bake.bakePropLamp(29);
    bitmaps.prop_lamp_baked2 = Bake.bakePropLamp(47);
    bitmaps.prop_tree_baked0 = Bake.bakePropTree(13);
    bitmaps.prop_tree_baked1 = Bake.bakePropTree(31);
    bitmaps.prop_tree_baked2 = Bake.bakePropTree(59);
  }

  function bakeManifestProcedural() {
    const Bake = VAMP.ArtBake;
    const Spr = VAMP.Spriter;
    if (!Bake) return;
    const walkKinds = ['player_walk', 'npc_civilian_walk', 'npc_gang', 'npc_cop', 'npc_hunter', 'npc_thrall', 'rat'];
    for (let i = 0; i < walkKinds.length; i++) {
      const k = walkKinds[i];
      const sheet = Bake.bakeWalkSheet(k, (i + 1) * 7919);
      bitmaps[k] = sheet;
      if (Spr) {
        const spec = k === 'player_walk' ? { cols: 4, rows: 8, dirs: 8 }
          : k === 'rat' ? { cols: 1, rows: 4, dirs: 4 }
          : { cols: 2, rows: 4, dirs: 4 };
        Spr.register(k, sheet, spec);
      }
    }
    const auto = Bake.bakeAutotileAtlas();
    processed.autotile_16_tile = auto;
    bitmaps.autotile_16 = auto;
    const grounds = ['grass', 'concrete', 'dirt', 'plaza'];
    for (const gk of grounds) {
      const t = Bake.bakeProceduralTile(gk, 64);
      Bake.enhanceTile(t, null, gk.length * 53);
      processed['ground_' + gk + '_tile'] = t;
      bitmaps['ground_' + gk] = t;
    }
    if (VAMP.DistrictArt && VAMP.DistrictArt.KITS) {
      for (const id in VAMP.DistrictArt.KITS) {
        bitmaps['roof_' + id] = Bake.bakeDistrictModule('roof', id);
        bitmaps['wall_' + id] = Bake.bakeDistrictModule('wall', id);
      }
    }
    const pois = ['haven', 'bloodbank', 'club', 'board', 'market'];
    for (const pt of pois) bitmaps['poi_' + pt] = Bake.bakePOIFacade(pt);
    bitmaps.menu_bg_board = Bake.bakeMenuBackdrop('board');
    bitmaps.menu_bg_map = Bake.bakeMenuBackdrop('map');
  }

  function has(key) { return !!bitmaps[key] || !!bitmaps[key + '_topdown'] || !!processed[key + '_tile']; }

  function get(key) {
    if (bitmaps[key + '_topdown']) return bitmaps[key + '_topdown'];
    return bitmaps[key] || processed[key + '_tile'] || null;
  }

  function getBaked(key, variant) {
    const v = variant == null ? 0 : variant % 3;
    const bk = key + '_baked' + v;
    if (bitmaps[bk]) return bitmaps[bk];
    return get(key);
  }

  function drawKey(ctx, key, x, y, opts) {
    const src = get(key);
    if (!src || !ctx) return false;
    opts = opts || {};
    const sw = src.width || src.naturalWidth;
    const sh = src.height || src.naturalHeight;
    const dw = opts.w != null ? opts.w : sw;
    const dh = opts.h != null ? opts.h : sh;
    const ax = opts.ax != null ? opts.ax : 0.5;
    const ay = opts.ay != null ? opts.ay : 0.5;
    ctx.save();
    if (opts.alpha != null) ctx.globalAlpha = opts.alpha;
    ctx.imageSmoothingEnabled = opts.smooth !== false;
    const img = opts.tint ? tintCanvas(src, opts.tint) : src;
    if (opts.rotate) { ctx.translate(x, y); ctx.rotate(opts.rotate); ctx.drawImage(img, -dw * ax, -dh * ay, dw, dh); }
    else ctx.drawImage(img, x - dw * ax, y - dh * ay, dw, dh);
    ctx.restore();
    return true;
  }

  const tintCache = {};
  function tintCanvas(src, color) {
    const k = (src.src || 'c') + color;
    if (tintCache[k]) return tintCache[k];
    const w = src.width || src.naturalWidth;
    const h = src.height || src.naturalHeight;
    const c = makeCanvas(w, h);
    const g = c.getContext('2d');
    g.drawImage(src, 0, 0);
    g.globalCompositeOperation = 'multiply';
    g.fillStyle = color; g.fillRect(0, 0, w, h);
    g.globalCompositeOperation = 'destination-in';
    g.drawImage(src, 0, 0);
    tintCache[k] = c;
    return c;
  }

  let vignetteCache = null;
  function vignette(w, h, strength) {
    if (vignetteCache && vignetteCache.w === w && vignetteCache.h === h && vignetteCache.s === strength) return vignetteCache.c;
    const c = makeCanvas(w, h);
    const g = c.getContext('2d');
    const grad = g.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.35, w / 2, h / 2, Math.max(w, h) * 0.72);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(1, `rgba(0,0,0,${strength})`);
    g.fillStyle = grad; g.fillRect(0, 0, w, h);
    vignetteCache = { w, h, s: strength, c };
    return c;
  }

  function starfield(w, h, count) {
    const c = makeCanvas(w, h);
    const g = c.getContext('2d');
    const rng = U.makeRNG(7);
    g.fillStyle = '#05060c'; g.fillRect(0, 0, w, h);
    for (let i = 0; i < count; i++) {
      const x = rng() * w, y = rng() * h, r = rng() * 1.3 + 0.2;
      g.fillStyle = `rgba(255,255,255,${0.2 + rng() * 0.7})`;
      g.beginPath(); g.arc(x, y, r, 0, U.TAU); g.fill();
    }
    return c;
  }

  let glowSprite = null;
  function glow() {
    if (glowSprite) return glowSprite;
    const s = 128, c = makeCanvas(s, s), g = c.getContext('2d');
    const grad = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
    grad.addColorStop(0, 'rgba(255,255,255,1)');
    grad.addColorStop(0.45, 'rgba(255,255,255,0.42)');
    grad.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = grad; g.fillRect(0, 0, s, s);
    glowSprite = c; return c;
  }
  const glowTintCache = {};
  function glowTinted(color) {
    if (glowTintCache[color]) return glowTintCache[color];
    const base = glow(), s = base.width, c = makeCanvas(s, s), g = c.getContext('2d');
    g.drawImage(base, 0, 0);
    g.globalCompositeOperation = 'source-in';
    g.fillStyle = color; g.fillRect(0, 0, s, s);
    glowTintCache[color] = c; return c;
  }
  let blobSprite = null;
  function softBlob() {
    if (blobSprite) return blobSprite;
    const s = 96, c = makeCanvas(s, s), g = c.getContext('2d');
    const grad = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
    grad.addColorStop(0, 'rgba(190,195,215,0.55)');
    grad.addColorStop(0.6, 'rgba(170,175,200,0.22)');
    grad.addColorStop(1, 'rgba(160,165,190,0)');
    g.fillStyle = grad; g.fillRect(0, 0, s, s);
    blobSprite = c; return c;
  }

  let bloomBuf = null;
  let bloomTmp = null;

  function separableBlur(g, src, w, h, radius) {
    radius = Math.max(1, radius | 0);
    if (!bloomTmp || bloomTmp.width !== w) bloomTmp = makeCanvas(w, h);
    const tg = bloomTmp.getContext('2d');
    tg.filter = 'blur(' + radius + 'px)';
    tg.drawImage(src, 0, 0);
    g.filter = 'blur(' + radius + 'px)';
    g.drawImage(bloomTmp, 0, 0);
    g.filter = 'none';
  }

  function bloom(ctx, canvas, w, h, strength) {
    if (!strength) return;
    const scale = 0.25;
    const bw = Math.max(1, Math.round(w * scale)), bh = Math.max(1, Math.round(h * scale));
    if (!bloomBuf || bloomBuf.width !== bw || bloomBuf.height !== bh) bloomBuf = makeCanvas(bw, bh);
    const bg = bloomBuf.getContext('2d');
    bg.globalCompositeOperation = 'source-over';
    bg.clearRect(0, 0, bw, bh);
    bg.drawImage(canvas, 0, 0, canvas.width, canvas.height, 0, 0, bw, bh);
    // highlight extraction: multiply the frame by itself so only the bright lights
    // (lamps, neon, fire, lit windows) survive while shadows are crushed toward black.
    // keeps bloom a glow ON the lights rather than a full-frame haze that washes the night.
    bg.globalCompositeOperation = 'multiply';
    bg.drawImage(bloomBuf, 0, 0);
    bg.globalCompositeOperation = 'source-over';
    separableBlur(bg, bloomBuf, bw, bh, 3);
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalCompositeOperation = 'lighter';
    ctx.globalAlpha = strength;
    ctx.imageSmoothingEnabled = true;
    ctx.drawImage(bloomBuf, 0, 0, bw, bh, 0, 0, canvas.width, canvas.height);
    ctx.restore();
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }

  function facingToOctant(angle) {
    const a = ((angle % U.TAU) + U.TAU) % U.TAU;
    return Math.round(a / (U.TAU / 8)) % 8;
  }

  VAMP.Assets = {
    makeCanvas, noiseTile, build, rebuildPatterns, vignette, starfield, patterns,
    bloom, glow, glowTinted, softBlob,
    loadAll, has, get, getBaked, drawKey, facingToOctant,
    get ready() { return ready; },
    get loadProgress() { return loadProgress; },
    get loadTotal() { return loadTotal; },
  };
})();