/* =========================================================================
 * VAMPIRE CITY — render/powervfx.js
 * Discipline-specific visual flourishes (hooks from powers.js).
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  const hooks = {};

  function register(fxName, fn) { hooks[fxName] = fn; }

  function play(fxName, p, game, def) {
    const fn = hooks[fxName];
    if (fn) fn(p, game, def);
  }

  register('potSlam', (p, game, def) => {
    if (VAMP.FX) VAMP.FX.spriteRing(p.x, p.y, (def.radius || 110) * 2, 'rune_shockwave', 0.75);
    if (VAMP.Decals) for (let i = 0; i < 3; i++) VAMP.Decals.spawn(p.x + (Math.random() - 0.5) * 40, p.y + (Math.random() - 0.5) * 40, 'crack', 6);
  });

  register('potQuake', (p, game, def) => {
    if (VAMP.FX) {
      VAMP.FX.spriteRing(p.x, p.y, (def.radius || 180) * 2.2, 'rune_shockwave', 0.85);
      VAMP.FX.ring(p.x, p.y, def.radius || 180, '#e0b050');
    }
    if (VAMP.Decals) for (let i = 0; i < 6; i++) VAMP.Decals.spawn(p.x + (Math.random() - 0.5) * (def.radius || 180), p.y + (Math.random() - 0.5) * (def.radius || 180), 'crack', 8);
  });

  register('celDash', (p, game) => {
    if (VAMP.FX) { VAMP.FX.dashTrail(p.x, p.y, p.facing); VAMP.FX.flash('rgba(120,200,255,0.12)', 0.12); }
  });

  register('bsBolt', (p, game, def) => {
    if (VAMP.FX) VAMP.FX.beam(p.x, p.y, p.x + Math.cos(p.facing) * 80, p.y + Math.sin(p.facing) * 80, '#d11838');
  });

  register('domMesmerize', (p, game, def) => {
    if (VAMP.FX) VAMP.FX.ring(p.x + Math.cos(p.facing) * 60, p.y + Math.sin(p.facing) * 60, def.radius || 130, '#b98cff');
  });

  VAMP.PowerVFX = { register, play, hooks };
})();