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
    useBitmapNPCs: true,
    useTitleArt: true,
    useHavenArt: true,
    usePostFX: true,
    useAutotile: true,
    useSpriter: true,
    useLightWorker: false,
    useIndexedDBCache: false,
    vectorFallback: true,
    chromaKey: '#ff00ff',
  };

  VAMP.AssetDisplay = {
    player_vampire: { smooth: false, displayScale: 3.6, sharpen: 0.32 },
    npc_civilian:   { smooth: false, displayScale: 2.4, sharpen: 0.28 },
    prop_lamp:      { smooth: true, displayScale: 1, sharpen: 0.28 },
    prop_tree:      { smooth: true, displayScale: 1, sharpen: 0.28 },
    vehicle_sedan:  { smooth: true, displayScale: 1.45, sharpen: 0.28 },
  };

  VAMP.ArtPaths = {
    asphalt_wet: BASE + 'asphalt_wet.jpg',
    sidewalk: BASE + 'sidewalk.jpg',
    player_vampire: BASE + 'player_vampire.jpg',
    prop_lamp: BASE + 'prop_lamp.jpg',
    prop_lamp_alt: BASE + 'prop_lamp_alt.jpg',
    prop_tree: BASE + 'prop_tree.jpg',
    prop_tree_alt1: BASE + 'prop_tree_alt1.jpg',
    prop_tree_alt2: BASE + 'prop_tree_alt2.jpg',
    vehicle_sedan: BASE + 'vehicle_sedan.jpg',
    vehicle_sport: BASE + 'vehicle_sport.jpg',
    vehicle_van: BASE + 'vehicle_van.jpg',
    vehicle_hearse: BASE + 'vehicle_hearse.jpg',
    vehicle_police: BASE + 'vehicle_police.jpg',
    neon_sign: BASE + 'neon_sign.jpg',
    windows_sheet: BASE + 'windows_sheet.jpg',
    title_bg: BASE + 'title_bg.jpg',
    icon_celerity: BASE + 'icon_celerity.jpg',
    discipline_icons: BASE + 'discipline_icons.jpg',
    haven_bg: BASE + 'haven_bg.jpg',
    npc_civilian: BASE + 'npc_civilian.jpg',
    projectile_blood: BASE + 'projectile_blood.jpg',
    clan_emblems: BASE + 'clan_emblems.jpg',
  };

  // Sliced from discipline_icons.jpg (horizontal strip, 10 frames)
  VAMP.DisciplineIconKeys = [
    'icon_disc_celerity', 'icon_disc_potence', 'icon_disc_fortitude',
    'icon_disc_obfuscate', 'icon_disc_auspex', 'icon_disc_dominate',
    'icon_disc_presence', 'icon_disc_protean', 'icon_disc_sorcery', 'icon_disc_dark',
  ];

  // Sliced from clan_emblems.jpg (7 frames)
  VAMP.ClanEmblemKeys = [
    'emblem_brujah', 'emblem_gangrel', 'emblem_tremere', 'emblem_ventrue',
    'emblem_toreador', 'emblem_nosferatu', 'emblem_malkavian',
  ];

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

  // Resolve power id → sliced discipline icon key (all 36 powers covered)
  VAMP.powerIconKey = function (powerId) {
    const def = VAMP.Data && VAMP.Data.POWERS && VAMP.Data.POWERS[powerId];
    return def ? 'icon_disc_' + def.disc : null;
  };

  VAMP.clanEmblemKey = function (clan) {
    return clan ? 'emblem_' + clan : null;
  };

  // Legacy explicit paths (celerity sheet kept for fallback)
  VAMP.PowerIconPaths = {
    cel_dash: BASE + 'icon_celerity.jpg',
    cel_haste: BASE + 'icon_celerity.jpg',
    cel_flurry: BASE + 'icon_celerity.jpg',
    cel_bullet: BASE + 'icon_celerity.jpg',
  };
})();