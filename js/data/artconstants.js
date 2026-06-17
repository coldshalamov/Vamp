/* =========================================================================
 * VAMPIRE CITY — artconstants.js
 * Art revamp flags, paths, district grade tints. Loaded before assets.js.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  const BASE = 'assets/images/';

  VAMP.ArtFlags = {
    useBitmapGround: true,
    useBitmapProps: true,
    useBitmapPlayer: true,
    useBitmapVehicles: true,
    useBitmapBuildings: true,
    useBitmapFX: true,
    useBitmapUI: true,
    useTitleArt: true,
    usePostFX: true,
    vectorFallback: true,
    chromaKey: '#ff00ff',
  };

  VAMP.ArtPaths = {
    asphalt_wet: BASE + 'asphalt_wet.jpg',
    sidewalk: BASE + 'sidewalk.jpg',
    player_vampire: BASE + 'player_vampire.jpg',
    prop_lamp: BASE + 'prop_lamp.jpg',
    prop_tree: BASE + 'prop_tree.jpg',
    vehicle_sedan: BASE + 'vehicle_sedan.jpg',
    neon_sign: BASE + 'neon_sign.jpg',
    windows_sheet: BASE + 'windows_sheet.jpg',
    title_bg: BASE + 'title_bg.jpg',
    icon_celerity: BASE + 'icon_celerity.jpg',
  };

  // District accent multiply grades (from world.js DISTRICTS)
  VAMP.DistrictGrade = {
    downtown: { color: '#6c7bd6', alpha: 0.07 },
    oldtown: { color: '#caa46a', alpha: 0.08 },
    docks: { color: '#5fb3a1', alpha: 0.09 },
    redlight: { color: '#e0457b', alpha: 0.10 },
    residential: { color: '#7fa8c9', alpha: 0.06 },
    cemetery: { color: '#9a86c4', alpha: 0.09 },
    industrial: { color: '#d6953f', alpha: 0.08 },
  };

  // Power id → optional bitmap icon (expand over time)
  VAMP.PowerIconPaths = {
    cel_dash: BASE + 'icon_celerity.jpg',
    cel_haste: BASE + 'icon_celerity.jpg',
    cel_flurry: BASE + 'icon_celerity.jpg',
    cel_bullet: BASE + 'icon_celerity.jpg',
  };
})();