/* =========================================================================
 * VAMPIRE CITY — world/propvariants.js
 * Deterministic prop variant selection from world seed (no per-frame alloc).
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  function hash2(c, r, seed, salt) {
    let h = (c * 374761393 + r * 668265263 + (seed | 0) * 0x9E3779B1 + (salt | 0) * 1013) | 0;
    h = Math.imul(h ^ (h >>> 13), 1274126177);
    return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
  }

  const LAMP_KEYS = ['prop_lamp', 'prop_lamp_alt'];
  const TREE_KEYS = ['prop_tree', 'prop_tree_alt1', 'prop_tree_alt2'];
  const VEHICLE_KEYS = { sedan: 'vehicle_sedan', sport: 'vehicle_sport', van: 'vehicle_van', hearse: 'vehicle_hearse', police: 'vehicle_police' };
  const SIGN_LABELS = ['BAR', 'INN', 'CLUB', 'PAWN', 'OPEN', 'HOTEL', 'CAFE', 'GUNS', 'TAXI', 'SOUL', 'NOIR', 'BITE', 'LIVE', 'EXIT', 'PAWN', 'VICE'];
  const GRAFFITI_TAGS = ['XIII', '666', 'RIOT', 'HATE', 'LOST', 'VOID', 'SIN', 'WOLF', 'BITE', 'NOIR', 'DEAD', 'RUN', 'FEAR', 'BLOOD'];
  const MISC_COLORS = ['#7a2630', '#26407a', '#2a5a3a', '#5a4a2a', '#4a2a4a', '#3a4a5a'];

  function lampKey(c, r, seed) {
    const i = (hash2(c, r, seed, 11) * LAMP_KEYS.length) | 0;
    return LAMP_KEYS[Math.min(i, LAMP_KEYS.length - 1)];
  }

  function treeKey(c, r, seed) {
    const i = (hash2(c, r, seed, 23) * TREE_KEYS.length) | 0;
    return TREE_KEYS[Math.min(i, TREE_KEYS.length - 1)];
  }

  function treeTint(c, r, seed) {
    const h = hash2(c, r, seed, 37);
    const hues = ['#1a3824', '#243a28', '#2e4a30', '#1e3020', '#3a4a2a', '#2a4230', '#1c3426'];
    return hues[(h * hues.length) | 0];
  }

  function miscType(c, r, seed) {
    const h = hash2(c, r, seed, 53);
    if (h < 0.18) return 6;
    if (h < 0.32) return 7;
    if (h < 0.46) return 8;
    if (h < 0.62) return 4;
    if (h < 0.78) return 5;
    return 2;
  }

  function miscColor(c, r, seed) {
    const h = hash2(c, r, seed, 61);
    return MISC_COLORS[(h * MISC_COLORS.length) | 0];
  }

  function signLabel(x, y) {
    const i = (((x * 0.17 + y * 0.23) | 0) % SIGN_LABELS.length + SIGN_LABELS.length) % SIGN_LABELS.length;
    return SIGN_LABELS[i];
  }

  function vehicleKey(type) {
    return VEHICLE_KEYS[type] || 'vehicle_sedan';
  }

  function graffitiTag(c, r, seed) {
    const h = hash2(c, r, seed, 89);
    return GRAFFITI_TAGS[(h * GRAFFITI_TAGS.length) | 0];
  }

  function buildingSignText(seed, districtId) {
    const pool = districtId === 'redlight'
      ? ['LUST', 'SIN', 'VICE', 'NOIR', 'BITE', 'CLUB']
      : districtId === 'downtown'
        ? ['BANK', 'TOWER', 'LUX', 'APEX', 'TRADE']
        : districtId === 'docks'
          ? ['WHARF', 'CARGO', 'DOCK', 'SALT', 'TIDE']
          : districtId === 'cemetery'
            ? ['REST', 'TOMB', 'ASHES', 'CRYPT']
            : SIGN_LABELS;
    return pool[seed % pool.length];
  }

  VAMP.PropVariants = {
    hash2, lampKey, treeKey, treeTint, miscType, miscColor, signLabel, graffitiTag,
    vehicleKey, buildingSignText, LAMP_KEYS, TREE_KEYS,
  };
})();