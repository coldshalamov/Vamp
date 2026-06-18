/* =========================================================================
 * VAMPIRE CITY — systems/powers.js
 * Effect functions for every active/toggle Discipline power (VAMP.PowerFX).
 * Each fn(p, game, def) performs the effect; return false to abort (no cost).
 * Tunables (dmg/radius/dur/heal) are read from the power's data def.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  const C = () => VAMP.Combat;

  const sp = (p) => p.derived.spellPower;           // spell power multiplier
  function enemiesIn(game, x, y, r, includeNeutral) {
    const out = [];
    for (const n of game.npcs) {
      if (n.dead || n.ally) continue;
      if (!includeNeutral && (n.faction === 'civ' || n.faction === 'animal')) continue;
      if (U.dist2(x, y, n.x, n.y) < r * r) out.push(n);
    }
    return out;
  }
  function anyNpcIn(game, x, y, r) {
    const out = [];
    for (const n of game.npcs) { if (n.dead || n.ally) continue; if (U.dist2(x, y, n.x, n.y) < r * r) out.push(n); }
    return out;
  }
  function nearestEnemy(game, p, maxR) {
    return game.nearestNPC(p.x, p.y, (n) => !n.dead && !n.ally && n.faction !== 'civ' && n.faction !== 'animal', maxR);
  }
  function nearestAny(game, p, maxR) {
    return game.nearestNPC(p.x, p.y, (n) => !n.dead && !n.ally, maxR);
  }
  function aimAngle(p) { return p.facing; }

  const FX = {
    // ============ CELERITY ============
    celDash(p, game, def) {
      const a = aimAngle(p);
      const dist = def.dist || 190;
      const steps = 14; let nx = p.x, ny = p.y;
      for (let i = 1; i <= steps; i++) {
        const tx = p.x + Math.cos(a) * dist * (i / steps);
        const ty = p.y + Math.sin(a) * dist * (i / steps);
        if (game.world.pointBlocked(tx, ty, p.r)) break;
        nx = tx; ny = ty;
        if (VAMP.FX) VAMP.FX.afterimage(tx, ty, a);
      }
      p.x = nx; p.y = ny;
      p.invuln = Math.max(p.invuln, def.iframes || 0.35);
      if (VAMP.PowerVFX) VAMP.PowerVFX.play('celDash', p, game, def);
      if (VAMP.FX) { VAMP.FX.dashTrail(p.x, p.y, a); VAMP.FX.flash('rgba(120,200,255,0.08)', 0.1); }
      if (game.cam) game.cam.shake(2, 0.07);
      return true;
    },
    celHaste(p, game, def) {
      p.addBuff({ id: 'cel_haste', name: 'Celerity', dur: Infinity, color: '#7ad0ff',
        mods: { pct: { moveSpeed: 0.4, attackSpeed: 0.5, dodge: 0.1 } } });
      if (VAMP.FX) VAMP.FX.ring(p.x, p.y, p.r * 3, '#7ad0ff');
      return true;
    },
    celHasteOff(p) { p.buffs = p.buffs.filter(b => b.id !== 'cel_haste'); VAMP.Stats.recompute(p); },
    celBullet(p, game, def) {
      game.setSlowmo(def.dur || 4, 0.32);
      p.addBuff({ id: 'cel_bullet', name: 'Quicksilver', dur: def.dur || 4, color: '#bfe9ff', mods: { pct: { attackSpeed: 0.3 } } });
      if (VAMP.FX) VAMP.FX.flash('rgba(120,200,255,0.15)', 0.3);
      return true;
    },
    celFlurry(p, game, def) {
      p.addBuff({ id: 'cel_flurry', name: 'Blood Flurry', dur: def.dur || 3.5, color: '#9ff', mods: { pct: { attackSpeed: 1.4, meleeDmg: 0.25 } } });
      return true;
    },

    // ============ POTENCE ============
    potSlam(p, game, def) {
      const r = def.radius || 110;
      if (VAMP.PowerVFX) VAMP.PowerVFX.play('potSlam', p, game, def);
      if (VAMP.FX) { VAMP.FX.ring(p.x, p.y, r, '#d2a04a'); VAMP.FX.shock(p.x, p.y, r); }
      if (game.cam) game.cam.shake(7, 0.3);
      for (const n of enemiesIn(game, p.x, p.y, r, true)) {
        C().damageNPC(game, n, (def.dmg || 22) * sp(p), { knockback: def.knockback || 240, angle: U.angleTo(p.x, p.y, n.x, n.y), color: '#d2a04a', dmgType: 'phys' });
        C().applyStatus(n, 'stun', { dur: def.stun || 1.2 });
      }
      if (VAMP.Audio) VAMP.Audio.play('explode');
      return true;
    },
    potCharge(p, game, def) {
      const a = aimAngle(p), dist = def.dist || 200;
      let nx = p.x, ny = p.y;
      const hitSet = new Set();
      const steps = 16;
      for (let i = 1; i <= steps; i++) {
        const tx = p.x + Math.cos(a) * dist * (i / steps), ty = p.y + Math.sin(a) * dist * (i / steps);
        if (game.world.pointBlocked(tx, ty, p.r)) break;
        nx = tx; ny = ty;
        for (const n of anyNpcIn(game, tx, ty, 30)) {
          if (hitSet.has(n)) continue; hitSet.add(n);
          C().damageNPC(game, n, (def.dmg || 26) * sp(p), { knockback: 200, angle: a, color: '#d2a04a', dmgType: 'phys' });
          C().applyStatus(n, 'stun', { dur: 0.6 });
        }
      }
      p.x = nx; p.y = ny; p.invuln = Math.max(p.invuln, 0.3);
      if (VAMP.FX) VAMP.FX.dashTrail(p.x, p.y, a);
      return true;
    },
    potQuake(p, game, def) {
      const r = def.radius || 180;
      if (VAMP.PowerVFX) VAMP.PowerVFX.play('potQuake', p, game, def);
      if (VAMP.FX) { VAMP.FX.ring(p.x, p.y, r, '#e0b050'); VAMP.FX.shock(p.x, p.y, r); }
      if (game.cam) game.cam.shake(12, 0.5);
      for (const n of enemiesIn(game, p.x, p.y, r, true)) {
        const d = U.dist(p.x, p.y, n.x, n.y);
        C().damageNPC(game, n, (def.dmg || 40) * sp(p) * (1 - d / r * 0.4), { knockback: 320, angle: U.angleTo(p.x, p.y, n.x, n.y), color: '#e0b050', dmgType: 'phys' });
        C().applyStatus(n, 'stun', { dur: 1.6 });
      }
      if (VAMP.Audio) VAMP.Audio.play('explode');
      return true;
    },

    // ============ FORTITUDE ============
    forMend(p, game, def) {
      if (p.hp >= p.derived.maxHP) { if (VAMP.UI) VAMP.UI.notify('Already at full health', '#a88'); return false; }
      const heal = (def.heal || 45) * (1 + sp(p) * 0.5);
      p.hp = Math.min(p.derived.maxHP, p.hp + heal);
      if (VAMP.FX) { VAMP.FX.number(p.x, p.y - 24, '+' + Math.round(heal), '#5aff8c'); VAMP.FX.heal(p.x, p.y); }
      return true;
    },
    forStone(p, game, def) {
      p.addBuff({ id: 'for_stone', name: 'Stone Skin', dur: def.dur || 8, color: '#9a9a9a', mods: { pct: { armor: def.armor || 0.4 } } });
      if (VAMP.FX) VAMP.FX.ring(p.x, p.y, p.r * 3, '#9a9a9a');
      return true;
    },
    forUnkill(p, game, def) {
      p.invuln = Math.max(p.invuln, def.dur || 2.6);
      p.addBuff({ id: 'for_unkill', name: 'Unkillable', dur: def.dur || 2.6, color: '#ffd24a', mods: {} });
      if (VAMP.FX) VAMP.FX.flash('rgba(255,210,80,0.18)', 0.3);
      return true;
    },

    // ============ OBFUSCATE ============
    obfCloak(p, game, def) { p.cloaked = true; if (VAMP.FX) VAMP.FX.cloak(p.x, p.y); return true; },
    obfCloakOff(p) { p.cloaked = false; },
    obfCloakTick(p, game, def, dt) { /* break cloak if attacking handled by lastAttackT */
      if (game.time - (p.lastAttackT || -99) < 0.2) {
        // obf_key One With Shadow: kills from cloak open a 2s window where cloak doesn't break
        if (p.treeNodes && p.treeNodes['obf_key'] && (game.time - (p._stealthKillT || -99)) < 2) return;
        p.toggles['obf_cloak'] = false; p.cloaked = false;
      }
    },
    obfVanish(p, game, def) {
      p.cloaked = true;
      for (const n of anyNpcIn(game, p.x, p.y, def.radius || 240)) { n.aggro = false; if (n.state === 'chase' || n.state === 'attack') { n.state = 'wander'; n.path = null; } }
      setTimeout(() => { /* noop */ }, 0);
      game.masquerade.reduceHeat(def.heat || 0.5);
      if (VAMP.FX) VAMP.FX.cloak(p.x, p.y);
      // cloak lingers briefly
      p.addBuff({ id: 'obf_vanish', name: 'Unseen', dur: def.dur || 3, color: '#88a', mods: {}, onExpire: (pp) => { if (!pp.toggles['obf_cloak']) pp.cloaked = false; } });
      return true;
    },
    obfMask(p, game, def) {
      const before = game.masquerade.stars;
      game.masquerade.clearStars(def.stars || 2);
      if (VAMP.FX) VAMP.FX.cloak(p.x, p.y);
      if (VAMP.UI) VAMP.UI.notify('Mask of a Thousand Faces — heat reduced', '#9bf');
      return true;
    },

    // ============ AUSPEX ============
    ausSenses(p, game, def) { p.senses = true; p.addBuff({ id: 'aus_senses', name: 'Heightened Senses', dur: Infinity, color: '#aef', mods: { pct: { critChance: 0.1 }, add: { detectRange: 140 } } }); if (VAMP.FX) VAMP.FX.ring(p.x, p.y, p.r * 3, '#aef'); return true; },
    ausSensesOff(p) { p.senses = false; p.buffs = p.buffs.filter(b => b.id !== 'aus_senses'); VAMP.Stats.recompute(p); },
    ausPremon(p, game, def) {
      p.addBuff({ id: 'aus_premon', name: 'Premonition', dur: def.dur || 6, color: '#cdf', mods: { pct: { dodge: def.dodge || 0.4 } } });
      return true;
    },
    ausMark(p, game, def) {
      const t = nearestEnemy(game, p, def.range || 360) || nearestAny(game, p, def.range || 360);
      if (!t) { if (VAMP.UI) VAMP.UI.notify('No target to mark', '#a88'); return false; }
      C().applyStatus(t, 'mark', { dur: def.dur || 10, amount: def.amount || 0.35 });
      t.revealed = true;
      if (VAMP.FX) VAMP.FX.number(t.x, t.y - 18, 'MARKED', '#ff4f8b', { small: true });
      return true;
    },

    // ============ DOMINATE ============
    domMesmerize(p, game, def) {
      const r = def.radius || 120, ang = def.arc || 1.4;
      let any = false;
      for (const n of game.npcs) {
        if (n.dead || n.ally) continue;
        if (U.dist(p.x, p.y, n.x, n.y) > r) continue;
        const a = U.angleTo(p.x, p.y, n.x, n.y);
        if (Math.abs(U.wrapAngle(a - p.facing)) > ang) continue;
        n.mesmerizedT = Math.max(n.mesmerizedT || 0, def.dur || 5);
        n.path = null; any = true;
        if (VAMP.FX) VAMP.FX.number(n.x, n.y - 16, '◉', '#c9f', { small: true });
      }
      if (!any) { if (VAMP.UI) VAMP.UI.notify('No one to mesmerize', '#a88'); return false; }
      return true;
    },
    domCommand(p, game, def) {
      const t = nearestAny(game, p, def.range || 200);
      if (!t) return false;
      // command to flee
      C().applyStatus(t, 'fear', { dur: def.dur || 5 });
      if (VAMP.FX) VAMP.FX.number(t.x, t.y - 16, 'FLEE!', '#c7f', { small: true });
      return true;
    },
    domForget(p, game, def) {
      game.masquerade.clearWitnesses();
      game.masquerade.reduceHeat(def.heat || 1);
      if (VAMP.FX) VAMP.FX.flash('rgba(150,120,255,0.12)', 0.3);
      if (VAMP.UI) VAMP.UI.notify('Forgetful Mind — witnesses erased', '#9bf');
      return true;
    },
    domThrall(p, game, def) {
      const t = game.nearestNPC(p.x, p.y, (n) => !n.dead && !n.ally && (n.mesmerizedT > 0 || n.hp < n.maxHp * 0.5 || n.faction === 'civ'), def.range || 80);
      if (!t) { if (VAMP.UI) VAMP.UI.notify('Mesmerize or weaken someone first', '#a88'); return false; }
      game.convertThrall(t);
      if (VAMP.FX) VAMP.FX.heal(t.x, t.y);
      if (VAMP.UI) VAMP.UI.notify('Bound a Thrall to your will', '#5aff8c');
      return true;
    },

    // ============ PRESENCE ============
    preDread(p, game, def) {
      const r = def.radius || 160;
      if (VAMP.FX) VAMP.FX.ring(p.x, p.y, r, '#c77dff');
      for (const n of anyNpcIn(game, p.x, p.y, r)) C().applyStatus(n, 'fear', { dur: def.dur || 5 });
      return true;
    },
    preMajesty(p, game, def) {
      p.addBuff({ id: 'pre_majesty', name: 'Majesty', dur: def.dur || 6, color: '#ffd24a', mods: {}, onApply: () => {}, });
      p.majestyT = def.dur || 6;
      if (VAMP.FX) VAMP.FX.ring(p.x, p.y, 60, '#ffd24a');
      return true;
    },
    preEntrance(p, game, def) {
      const r = def.radius || 180;
      let any = false;
      for (const n of game.npcs) {
        if (n.dead || n.ally) continue;
        if (n.faction !== 'civ') continue;
        if (U.dist(p.x, p.y, n.x, n.y) > r) continue;
        n.mesmerizedT = Math.max(n.mesmerizedT || 0, def.dur || 8);
        any = true;
      }
      if (any && VAMP.FX) VAMP.FX.ring(p.x, p.y, r, '#ff9ecf');
      return any;
    },

    // ============ PROTEAN ============
    proClaws(p, game, def) { p.addBuff({ id: 'pro_claws', name: 'Feral Claws', dur: Infinity, color: '#c33', mods: { pct: { meleeDmg: def.dmg || 0.5, lifesteal: def.lifesteal || 0.08 } } }); if (VAMP.FX) VAMP.FX.ring(p.x, p.y, p.r * 3, '#c33'); return true; },
    proClawsOff(p) { p.buffs = p.buffs.filter(b => b.id !== 'pro_claws'); VAMP.Stats.recompute(p); },
    proMist(p, game, def) {
      p.addBuff({ id: 'pro_mist', name: 'Mist Form', dur: def.dur || 3, color: '#cde',
        mods: { pct: { moveSpeed: 0.3 } }, onApply: (pp) => { pp.mistForm = true; pp.invuln = Math.max(pp.invuln, def.dur || 3); },
        onExpire: (pp) => { pp.mistForm = false; } });
      if (VAMP.FX) VAMP.FX.cloak(p.x, p.y);
      return true;
    },
    proBeast(p, game, def) {
      p.addBuff({ id: 'pro_beast', name: 'Beast Form', dur: def.dur || 10, color: '#a52',
        mods: { pct: { meleeDmg: 0.6, moveSpeed: 0.35, maxHP: 0.3, attackSpeed: 0.2 } },
        onApply: (pp) => { pp.beastForm = true; VAMP.Stats.recompute(pp); pp.hp = Math.min(pp.derived.maxHP, pp.hp + pp.derived.maxHP * 0.3); },
        onExpire: (pp) => { pp.beastForm = false; VAMP.Stats.recompute(pp); pp.hp = Math.min(pp.hp, pp.derived.maxHP); } });
      if (VAMP.FX) VAMP.FX.ring(p.x, p.y, 50, '#a52');
      if (VAMP.Audio) VAMP.Audio.play('frenzy');
      return true;
    },

    // ============ BLOOD SORCERY (Thaumaturgy) ============
    bsBolt(p, game, def) {
      const a = aimAngle(p);
      game.spawnProjectile({
        x: p.x + Math.cos(a) * (p.r + 8), y: p.y + Math.sin(a) * (p.r + 8),
        vx: Math.cos(a) * (def.speed || 520), vy: Math.sin(a) * (def.speed || 520),
        owner: 'player', dmg: (def.dmg || 24) * sp(p), r: 6, color: '#d11838', glow: true,
        life: 1.6, kind: 'blood', knockback: 60, pierce: def.pierce || 0,
        dmgType: 'blood',
        status: def.bleed ? { kind: 'bleed', dur: 3, dps: (def.dmg || 24) * 0.25 * sp(p), dmgType: 'blood' } : null,
      });
      if (VAMP.FX) VAMP.FX.ring(p.x + Math.cos(a) * 14, p.y + Math.sin(a) * 14, 13, '#e0203f');
      return true;
    },
    bsCauldron(p, game, def) {
      const t = nearestAny(game, p, def.range || 300);
      if (!t) return false;
      C().applyStatus(t, 'bleed', { dur: def.dur || 5, dps: (def.dps || 16) * sp(p), dmgType: 'blood' });
      // spread to nearby
      for (const n of anyNpcIn(game, t.x, t.y, def.splash || 70)) C().applyStatus(n, 'bleed', { dur: (def.dur || 5) * 0.6, dps: (def.dps || 16) * 0.6 * sp(p), dmgType: 'blood' });
      if (VAMP.FX) VAMP.FX.blood(t.x, t.y, 8);
      return true;
    },
    bsWard(p, game, def) {
      p.ward = (def.shield || 60) * (1 + sp(p) * 0.5);
      p.addBuff({ id: 'blood_ward', name: 'Blood Ward', dur: def.dur || 12, color: '#7ad0ff', mods: {}, onExpire: (pp) => { pp.ward = 0; } });
      if (VAMP.FX) VAMP.FX.ring(p.x, p.y, p.r * 3, '#7ad0ff');
      return true;
    },
    bsTheft(p, game, def) {
      const t = nearestAny(game, p, def.range || 280);
      if (!t) return false;
      const dmg = (def.dmg || 18) * sp(p);
      C().damageNPC(game, t, dmg, { color: '#d11838', type: 'blood', dmgType: 'blood' });
      const gain = dmg * (def.steal || 0.6);
      p.blood = Math.min(p.derived.maxBlood, p.blood + gain);
      if (VAMP.FX) { VAMP.FX.beam(p.x, p.y, t.x, t.y, '#d11838'); VAMP.FX.number(p.x, p.y - 26, '+' + Math.round(gain) + ' vitae', '#d11838', { small: true }); }
      return true;
    },
    bsStorm(p, game, def) {
      const n = def.bolts || 12;
      for (let i = 0; i < n; i++) {
        const a = (i / n) * U.TAU;
        game.spawnProjectile({
          x: p.x + Math.cos(a) * (p.r + 6), y: p.y + Math.sin(a) * (p.r + 6),
          vx: Math.cos(a) * (def.speed || 360), vy: Math.sin(a) * (def.speed || 360),
          owner: 'player', dmg: (def.dmg || 16) * sp(p), r: 5, color: '#e0203f', glow: true, life: 1.2, kind: 'blood', knockback: 80, dmgType: 'blood',
        });
      }
      if (VAMP.FX) { VAMP.FX.ring(p.x, p.y, 60, '#e0203f'); VAMP.FX.flash('rgba(180,0,30,0.12)', 0.2); }
      if (game.cam) game.cam.shake(6, 0.3);
      return true;
    },

    // ============ OBTENEBRATION (Shadow) ============
    shdTendrils(p, game, def) {
      const t = nearestAny(game, p, def.range || 260) || p;
      const cx = t === p ? p.x + Math.cos(p.facing) * 120 : t.x;
      const cy = t === p ? p.y + Math.sin(p.facing) * 120 : t.y;
      const r = def.radius || 90;
      for (const n of anyNpcIn(game, cx, cy, r)) { C().applyStatus(n, 'root', { dur: def.dur || 3 }); C().damageNPC(game, n, (def.dmg || 8) * sp(p), { color: '#3a1a5a', dmgType: 'shadow' }); }
      if (VAMP.FX) VAMP.FX.shadow(cx, cy, r);
      return true;
    },
    shdArms(p, game, def) {
      const t = nearestAny(game, p, def.range || 320);
      if (!t) return false;
      C().damageNPC(game, t, (def.dmg || 14) * sp(p), { color: '#3a1a5a', dmgType: 'shadow' });
      // pull toward player
      const a = U.angleTo(t.x, t.y, p.x, p.y);
      t.x += Math.cos(a) * (def.pull || 120); t.y += Math.sin(a) * (def.pull || 120);
      game.world.collideCircle(t, t.r);
      C().applyStatus(t, 'root', { dur: 1 });
      if (VAMP.FX) VAMP.FX.beam(p.x, p.y, t.x, t.y, '#3a1a5a');
      return true;
    },

    // ============ DEMENTATION ============
    demConfuse(p, game, def) {
      const r = def.radius || 180;
      let any = false;
      for (const n of enemiesIn(game, p.x, p.y, r, true)) { n.berserkT = def.dur || 6; n.aggro = true; any = true; if (VAMP.FX) VAMP.FX.number(n.x, n.y - 16, '?!', '#c77dff', { small: true }); }
      if (any && VAMP.FX) VAMP.FX.ring(p.x, p.y, r, '#9a4bff');
      return any;
    },

    // ============ VICISSITUDE ============
    vicHorrid(p, game, def) {
      p.addBuff({ id: 'vic_horrid', name: 'Horrid Form', dur: def.dur || 12, color: '#6a8',
        mods: { pct: { maxHP: 0.6, armor: 0.3, meleeDmg: 0.5, moveSpeed: -0.15 } },
        onApply: (pp) => { pp.horrid = true; VAMP.Stats.recompute(pp); pp.hp = Math.min(pp.derived.maxHP, pp.hp + pp.derived.maxHP * 0.4); },
        onExpire: (pp) => { pp.horrid = false; VAMP.Stats.recompute(pp); pp.hp = Math.min(pp.hp, pp.derived.maxHP); } });
      if (VAMP.FX) VAMP.FX.ring(p.x, p.y, 50, '#6a8');
      return true;
    },
  };

  VAMP.PowerFX = FX;
})();
