/* =========================================================================
 * VAMPIRE CITY — assetmanifest.js
 * Single registry: path, chroma, sheet slices, smooth, displayScale, sharpen.
 * Loaded before assets.js; ArtPaths kept for backward compat.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const BASE = 'assets/images/';

  const ENTRIES = {
    asphalt_wet:      { path: 'asphalt_wet', tile: true, tileSize: 512, smooth: true },
    sidewalk:         { path: 'sidewalk', tile: true, tileSize: 512, smooth: true },
    player_vampire:   { path: 'player_vampire', chroma: true, smooth: false, displayScale: 3.6, sharpen: 0.32 },
    player_walk:      { procedural: 'player_walk', sheet: { cols: 4, rows: 8, dirs: 8 }, smooth: false, displayScale: 3.6 },
    npc_civilian:     { path: 'npc_civilian', chroma: true, smooth: false, displayScale: 2.4, sharpen: 0.28 },
    npc_civilian_walk:{ procedural: 'npc_civilian_walk', sheet: { cols: 4, rows: 2 }, smooth: false, displayScale: 2.4 },
    npc_gang:         { procedural: 'npc_gang', sheet: { cols: 4, rows: 2 }, smooth: false, displayScale: 2.4 },
    npc_cop:          { procedural: 'npc_cop', sheet: { cols: 4, rows: 2 }, smooth: false, displayScale: 2.4 },
    npc_hunter:       { procedural: 'npc_hunter', sheet: { cols: 4, rows: 2 }, smooth: false, displayScale: 2.4 },
    npc_thrall:       { procedural: 'npc_thrall', sheet: { cols: 4, rows: 2 }, smooth: false, displayScale: 2.4 },
    rat:              { procedural: 'rat', sheet: { cols: 4, rows: 1 }, smooth: false, displayScale: 1.8 },
    prop_lamp:        { path: 'prop_lamp', chroma: true, smooth: true, displayScale: 1, sharpen: 0.28 },
    prop_lamp_alt:    { path: 'prop_lamp_alt', chroma: true, smooth: true, sharpen: 0.28 },
    prop_tree:        { path: 'prop_tree', chroma: true, smooth: true, sharpen: 0.28 },
    prop_tree_alt1:   { path: 'prop_tree_alt1', chroma: true, smooth: true, sharpen: 0.28 },
    prop_tree_alt2:   { path: 'prop_tree_alt2', chroma: true, smooth: true, sharpen: 0.28 },
    vehicle_sedan:    { path: 'vehicle_sedan', chroma: true, smooth: true, displayScale: 1.45, sharpen: 0.28 },
    vehicle_sport:    { path: 'vehicle_sport', chroma: true, smooth: true, displayScale: 1.45, sharpen: 0.28 },
    vehicle_van:      { path: 'vehicle_van', chroma: true, smooth: true, displayScale: 1.45, sharpen: 0.28 },
    vehicle_hearse:   { path: 'vehicle_hearse', chroma: true, smooth: true, displayScale: 1.45, sharpen: 0.28 },
    vehicle_police:   { path: 'vehicle_police', chroma: true, smooth: true, displayScale: 1.45, sharpen: 0.28 },
    neon_sign:        { path: 'neon_sign', smooth: true },
    windows_sheet:    { path: 'windows_sheet', smooth: true },
    title_bg:         { path: 'title_bg', smooth: true },
    icon_celerity:    { path: 'icon_celerity', chroma: true, smooth: true, deprecated: true },
    discipline_icons: { path: 'discipline_icons', chroma: true, sheet: { count: 10, keys: 'DisciplineIconKeys' }, smooth: true },
    haven_bg:         { path: 'haven_bg', smooth: true },
    projectile_blood: { path: 'projectile_blood', chroma: true, smooth: false, sharpen: 0.2 },
    clan_emblems:     { path: 'clan_emblems', chroma: true, sheet: { count: 7, keys: 'ClanEmblemKeys' }, smooth: true },
    autotile_16:      { procedural: 'autotile_16', tile: true, tileSize: 64, smooth: true },
    ground_grass:     { procedural: 'grass', tile: true, tileSize: 64, smooth: true },
    ground_concrete:  { procedural: 'concrete', tile: true, tileSize: 64, smooth: true },
    ground_dirt:      { procedural: 'dirt', tile: true, tileSize: 64, smooth: true },
    ground_plaza:     { procedural: 'plaza', tile: true, tileSize: 64, smooth: true },
  };

  function resolveUrl(stem) {
    return BASE + stem;
  }

  function tryExtensions(stem) {
    return [stem + '.jpg', stem + '.png'];
  }

  function getEntry(key) {
    return ENTRIES[key] || null;
  }

  function getLoadOpts(key) {
    const e = ENTRIES[key];
    if (!e) return { chroma: null, tile: false };
    const opts = { chroma: null, tile: false, sharpen: e.sharpen, smooth: e.smooth };
    if (e.chroma) opts.chroma = (VAMP.ArtFlags && VAMP.ArtFlags.chromaKey) || '#ff00ff';
    if (e.tile) { opts.tile = true; opts.tileSize = e.tileSize || 128; }
    if (e.sheet) {
      opts.sheet = true;
      if (e.sheet.count) {
        opts.sheetCount = e.sheet.count;
        opts.sheetKeys = VAMP[e.sheet.keys] || [];
      }
    }
    return opts;
  }

  function getDisplayScale(key) {
    const e = ENTRIES[key];
    return e && e.displayScale != null ? e.displayScale : 1;
  }

  function isProcedural(key) {
    const e = ENTRIES[key];
    return !!(e && e.procedural);
  }

  function pathsForLoader() {
    const out = {};
    for (const key in ENTRIES) {
      const e = ENTRIES[key];
      if (e.procedural || e.deprecated) continue;
      out[key] = resolveUrl(e.path) + '.jpg';
    }
    return out;
  }

  VAMP.AssetManifest = {
    ENTRIES, BASE, getEntry, getLoadOpts, getDisplayScale, isProcedural,
    resolveUrl, tryExtensions, pathsForLoader,
  };
})();