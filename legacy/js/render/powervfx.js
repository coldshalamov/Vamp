/* =========================================================================
 * VAMPIRE CITY — render/powervfx.js
 * Discipline-specific visual flourishes (all gamedata fx names registered).
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const FX = () => VAMP.FX;
  const Dec = () => VAMP.Decals;

  const hooks = {};
  function register(fxName, fn) { hooks[fxName] = fn; }
  function play(fxName, p, game, def) {
    const fn = hooks[fxName];
    if (fn) fn(p, game, def || {});
  }

  function ring(p, col, r) { if (FX()) FX().ring(p.x, p.y, r || 80, col); }
  function sparks(p, col, n) { if (FX()) FX().spark(p.x, p.y, col || '#fb3', n || 6); }
  function flash(col, d) { if (FX()) FX().flash(col, d || 0.15); }

  register('celDash', (p) => { if (FX()) { FX().dashTrail(p.x, p.y, p.facing); flash('rgba(120,200,255,0.12)', 0.12); } });
  register('celHaste', (p) => { if (FX()) FX().afterimage(p.x, p.y, p.facing); });
  register('celFlurry', (p) => { flash('rgba(180,220,255,0.18)', 0.2); sparks(p, '#aaf', 10); });
  register('celBullet', (p) => { flash('rgba(200,210,255,0.35)', 0.45); if (FX()) FX().ring(p.x, p.y, 200, 'rgba(180,200,255,0.4)'); });

  register('potSlam', (p, g, def) => {
    if (FX()) FX().spriteRing(p.x, p.y, (def.radius || 110) * 2, 'rune_shockwave', 0.75);
    if (Dec()) for (let i = 0; i < 3; i++) Dec().spawn(p.x + (Math.random() - 0.5) * 40, p.y + (Math.random() - 0.5) * 40, 'crack', 6);
    sparks(p, '#e0b050', 8);
  });
  register('potCharge', (p) => { if (FX()) { FX().dashTrail(p.x, p.y, p.facing); FX().ring(p.x, p.y, 60, '#e0b050'); } });
  register('potQuake', (p, g, def) => {
    if (FX()) { FX().spriteRing(p.x, p.y, (def.radius || 180) * 2.2, 'rune_shockwave', 0.85); FX().ring(p.x, p.y, def.radius || 180, '#e0b050'); }
    if (Dec()) for (let i = 0; i < 6; i++) Dec().spawn(p.x + (Math.random() - 0.5) * (def.radius || 180), p.y + (Math.random() - 0.5) * (def.radius || 180), 'crack', 8);
  });

  register('forMend', (p) => { if (FX()) FX().heal(p.x, p.y); flash('rgba(120,200,160,0.15)', 0.18); });
  register('forStone', (p) => { ring(p, 'rgba(160,170,190,0.55)', 50); flash('rgba(140,150,170,0.12)', 0.15); });
  register('forUnkill', (p) => { ring(p, 'rgba(220,220,240,0.7)', 70); flash('rgba(255,255,255,0.2)', 0.25); });

  register('obfCloak', (p) => { if (FX()) FX().cloak(p.x, p.y); });
  register('obfVanish', (p) => { if (FX()) { FX().cloak(p.x, p.y); FX().shadow(p.x, p.y, 90); } });
  register('obfMask', (p) => { flash('rgba(180,160,220,0.2)', 0.3); sparks(p, '#c9b0ff', 12); });

  register('ausSenses', (p) => { ring(p, 'rgba(120,200,255,0.35)', 55); });
  register('ausPremon', (p) => { ring(p, 'rgba(100,180,255,0.5)', 65); flash('rgba(80,140,255,0.1)', 0.2); });
  register('ausMark', (p) => { if (FX()) FX().ring(p.x + Math.cos(p.facing) * 40, p.y + Math.sin(p.facing) * 40, 40, '#ff6060'); });

  register('domMesmerize', (p, g, def) => { if (FX()) FX().ring(p.x + Math.cos(p.facing) * 60, p.y + Math.sin(p.facing) * 60, def.radius || 130, '#b98cff'); });
  register('domCommand', (p) => { if (FX()) FX().beam(p.x, p.y, p.x + Math.cos(p.facing) * 120, p.y + Math.sin(p.facing) * 120, '#b98cff'); });
  register('domForget', (p) => { flash('rgba(200,180,255,0.18)', 0.25); if (FX()) FX().shadow(p.x, p.y, 100); });
  register('domThrall', (p) => { ring(p, '#9060e0', 45); sparks(p, '#c090ff', 8); });

  register('preDread', (p, g, def) => { if (FX()) FX().shadow(p.x, p.y, def.radius || 165); flash('rgba(80,0,20,0.15)', 0.2); });
  register('preMajesty', (p) => { ring(p, 'rgba(255,220,160,0.6)', 80); flash('rgba(255,240,200,0.12)', 0.2); });
  register('preEntrance', (p, g, def) => {
    if (FX()) FX().ring(p.x, p.y, def.radius || 185, '#ff80b0');
    for (let i = 0; i < 6; i++) if (FX()) FX().spark(p.x + (Math.random() - 0.5) * 80, p.y + (Math.random() - 0.5) * 80, '#ff90c0', 2);
  });

  register('proClaws', (p) => { if (FX()) FX().slash(p.x, p.y, p.facing, 40); });
  register('proMist', (p) => { if (FX()) FX().cloak(p.x, p.y); flash('rgba(180,190,220,0.15)', 0.2); });
  register('proBeast', (p, game) => { flash('rgba(180,40,40,0.2)', 0.25); ring(p, '#a03030', 55); if (game && game.cam) game.cam.punch(0.1); });

  register('bsBolt', (p) => { if (FX()) FX().beam(p.x, p.y, p.x + Math.cos(p.facing) * 80, p.y + Math.sin(p.facing) * 80, '#d11838'); });
  register('bsCauldron', (p) => { if (FX()) FX().bloodPool(p.x + Math.cos(p.facing) * 50, p.y + Math.sin(p.facing) * 50, 2); sparks(p, '#a00020', 10); });
  register('bsWard', (p) => { ring(p, 'rgba(200,40,60,0.55)', 50); });
  register('bsTheft', (p) => { if (FX()) FX().beam(p.x, p.y, p.x + Math.cos(p.facing) * 100, p.y + Math.sin(p.facing) * 100, '#ff3060'); });
  register('bsStorm', (p, g, def) => {
    const n = def.bolts || 14;
    for (let i = 0; i < n; i++) {
      const a = (i / n) * VAMP.Util.TAU;
      if (FX()) FX().beam(p.x, p.y, p.x + Math.cos(a) * 90, p.y + Math.sin(a) * 90, '#c02040');
    }
    if (FX()) FX().ring(p.x, p.y, 120, '#ff2040');
  });

  register('shdTendrils', (p, g, def) => { if (FX()) FX().shadow(p.x + Math.cos(p.facing) * 40, p.y + Math.sin(p.facing) * 40, def.radius || 95); });
  register('shdArms', (p) => { if (FX()) FX().beam(p.x, p.y, p.x + Math.cos(p.facing) * 140, p.y + Math.sin(p.facing) * 140, '#402070'); });
  register('demConfuse', (p, g, def) => { flash('rgba(180,60,255,0.22)', 0.3); if (FX()) FX().ring(p.x, p.y, def.radius || 190, '#a040d0'); });
  register('vicHorrid', (p, game) => { flash('rgba(60,0,30,0.28)', 0.35); ring(p, '#600020', 70); if (game && game.cam) game.cam.shake(8, 0.3); });

  VAMP.PowerVFX = { register, play, hooks };
})();