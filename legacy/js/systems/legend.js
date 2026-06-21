/* =========================================================================
 * VAMPIRE CITY — systems/legend.js  (#11 Legend & Titles)
 * A persistent Legend meter (separate from XP) grown by notable deeds; tiers
 * grant Kindred Titles worn in the HUD that GATE other systems (domain cap,
 * coterie cap). A slow legacy horizon that outlives the level cap.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  const TITLES = [
    { name: 'Fledgling', min: 0, domainCap: 1, coterie: 0 },
    { name: 'Neonate', min: 30, domainCap: 2, coterie: 0 },
    { name: 'Anarch', min: 75, domainCap: 3, coterie: 1 },
    { name: 'Ancilla', min: 150, domainCap: 4, coterie: 1 },
    { name: 'Baron', min: 260, domainCap: 5, coterie: 2 },
    { name: 'Elder', min: 420, domainCap: 6, coterie: 3 },
    { name: 'Prince of the City', min: 650, domainCap: 7, coterie: 4 },
  ];

  function get(p) { return p.legend || 0; }
  function titleFor(legend) { let t = TITLES[0]; for (const x of TITLES) if (legend >= x.min) t = x; return t; }
  function title(p) { return titleFor(get(p)); }

  function add(game, amount) {
    const p = game.player;
    const before = title(p).name;
    p.legend = (p.legend || 0) + amount;
    const now = title(p);
    if (now.name !== before) {
      VAMP.UI.banner('YOU ARE NOW: ' + now.name.toUpperCase(), 'Your Legend grows. New capacities unlocked.', '#c79bff');
      if (VAMP.Audio) VAMP.Audio.play('win');
      if (game.achievements) game.achievements.checkTimer = 0;
      if (VAMP.Progress) VAMP.Progress.reveal(game, 'legend');   // unlock Holdings tab (banner already shown)
    }
  }
  function domainCap(p) { return title(p).domainCap; }
  function coterieBonus(p) { return title(p).coterie; }
  function nextTitle(p) { const l = get(p); for (const x of TITLES) if (l < x.min) return x; return null; }

  VAMP.Legend = { TITLES, get, title, titleFor, add, domainCap, coterieBonus, nextTitle };
})();
