/* =========================================================================
 * VAMPIRE CITY — systems/combat.js
 * Damage resolution (crit, armor, marks), status effects (burn/bleed/
 * poison/shock/stun/root/fear/slow/weaken), knockback, lifesteal.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  const STATUS_COLOR = {
    burn: '#ff7a2a', bleed: '#d23a3a', poison: '#6fbf3a', shock: '#7ad0ff',
    stun: '#ffd24a', root: '#9a6cff', fear: '#c77dff', slow: '#79b8ff', weaken: '#b0b0b0', mark: '#ff4f8b',
  };

  function ensureStatus(e) { return e.status || (e.status = {}); }

  function applyStatus(e, kind, opts) {
    if (e.dead) return;
    // WARDED MIND: bosses & 'warded' elites shrug off mind-affecting will (fear). A pure crowd-control
    // build must improvise against them — being well-rounded pays off.
    if (e.wardedMind && kind === 'fear') { if (VAMP.FX) VAMP.FX.number(e.x, e.y - 14, 'WARDED', '#9aa0ff', { small: true }); return; }
    const s = ensureStatus(e);
    opts = opts || {};
    const cur = s[kind];
    const dur = opts.dur || 3;
    if (cur) {
      cur.t = Math.max(cur.t, dur);
      cur.max = Math.max(cur.max || 0, dur);   // original duration for the HUD countdown pie
      if (opts.dps) cur.dps = Math.max(cur.dps, opts.dps);
      if (opts.factor) cur.factor = Math.min(cur.factor || 1, opts.factor);
      if (opts.amount) cur.amount = Math.max(cur.amount || 0, opts.amount);
    } else {
      s[kind] = { t: dur, max: dur, dps: opts.dps || 0, factor: opts.factor, amount: opts.amount, src: opts.src };
    }
    if (VAMP.FX && opts.popup !== false) VAMP.FX.number(e.x, e.y - 14, kind.toUpperCase(), STATUS_COLOR[kind] || '#fff', { small: true });
  }

  function hasStatus(e, kind) { return e.status && e.status[kind] && e.status[kind].t > 0; }

  // tick statuses for an NPC or player; returns total DoT applied
  function updateStatuses(e, dt, game, isPlayer) {
    if (!e.status) return;
    const s = e.status;
    for (const k in s) {
      const st = s[k];
      if (!st) continue;
      st.t -= dt;
      if (st.t <= 0) { delete s[k]; continue; }
      if ((k === 'burn' || k === 'bleed' || k === 'poison') && st.dps) {
        const dmg = st.dps * dt;
        if (isPlayer) damagePlayer(game, dmg, { type: k, silent: true, dot: true });
        else damageNPC(game, e, dmg, { type: k, noCrit: true, silent: true, dot: true, src: st.src });
      }
    }
  }

  function speedFactor(e) {
    let f = 1;
    if (hasStatus(e, 'slow')) f *= (e.status.slow.factor || 0.6);
    if (hasStatus(e, 'shock')) f *= 0.8;
    return f;
  }
  function isDisabled(e) { return hasStatus(e, 'stun'); }
  function isRooted(e) { return hasStatus(e, 'root') || hasStatus(e, 'stun'); }
  function isFeared(e) { return hasStatus(e, 'fear'); }

  // ---- damage an NPC ----
  function damageNPC(game, npc, amount, opts) {
    if (!npc || npc.dead) return 0;
    opts = opts || {};
    // damageNPC is the player-offense path (claws, player projectiles, run-over, power AoE);
    // never let it harm the player's own thralls.
    if (npc.ally && !opts.hitAllies) return 0;
    const p = game.player;
    let dmg = amount;
    let crit = false;
    if (!opts.noCrit && p && p.derived) {
      if (Math.random() < (opts.critChance != null ? opts.critChance : p.derived.critChance)) {
        crit = true; dmg *= p.derived.critMult;
      }
    }
    // mark amplifies
    if (hasStatus(npc, 'mark')) dmg *= (1 + (npc.status.mark.amount || 0.25));
    // shock amplifies
    if (hasStatus(npc, 'shock')) dmg *= 1.15;
    // armor — shredded by 'weaken' (the deliberate answer to Warded / Juggernaut elites)
    let armor = npc.armor || 0;
    if (hasStatus(npc, 'weaken')) armor = Math.max(0, armor - (npc.status.weaken.amount || 0.2));
    dmg *= (1 - armor);
    // FRONT-ARMOR (riot shields): blocks most damage from the front — the answer is to flank or DASH
    // behind them for full damage. Makes shielded foes a "get around them" puzzle, not a damage sponge.
    if (npc.frontArmor && opts.angle != null && !opts.dot) {
      let da = (opts.angle + Math.PI - (npc.angle || 0)) % (Math.PI * 2);
      if (da > Math.PI) da -= Math.PI * 2; else if (da < -Math.PI) da += Math.PI * 2;
      if (Math.abs(da) < 1.15) { dmg *= (1 - npc.frontArmor); if (VAMP.FX) VAMP.FX.spark(npc.x, npc.y, '#9ad0ff', 3); }
    }
    // damage-TYPE resistance (phys / blood / shadow): a nemesis adapts to the method you lean on,
    // so a one-note build gets countered while a varied one keeps landing.
    if (npc.resist && opts.dmgType && npc.resist[opts.dmgType]) dmg *= (1 - npc.resist[opts.dmgType]);
    if (opts.dmgType && p) p._lastDmgType = opts.dmgType;
    dmg = opts.dot ? Math.max(0, dmg) : Math.max(1, dmg); // don't floor DoT residue to 1/frame

    npc.hp -= dmg;
    npc.lastHitT = game.time;
    npc.aggro = true;
    npc.hostileToPlayer = true;   // the player just struck it — provoked, so it may now hunt you
    if (npc.onDamaged) npc.onDamaged(dmg, opts, game);

    // floating number + fx
    if (!opts.silent && VAMP.FX) {
      VAMP.FX.number(npc.x, npc.y - npc.r - 6, Math.round(dmg), crit ? '#ffd24a' : (opts.type && STATUS_COLOR[opts.type]) || '#fff', { crit });
    }
    if (crit && !opts.dot && !opts.silent) { // crit punch
      if (game.cam) game.cam.shake(4, 0.12);
      if (VAMP.FX) VAMP.FX.ring(npc.x, npc.y, 26, '#ffd24a');
      if (VAMP.Audio) VAMP.Audio.play('uiBig');
      if (game.hitStop) game.hitStop(0.05);   // #7 — micro-freeze on a crit
    }
    if (!opts.dot && VAMP.FX) VAMP.FX.hit(npc.x, npc.y, opts.color || '#d33');
    if (!opts.dot && VAMP.Audio) VAMP.Audio.play('hit');   // every connecting blow cracks — limp 50%-of-the-time audio made hits feel soft

    // knockback
    if (opts.knockback && p) {
      const a = opts.angle != null ? opts.angle : U.angleTo(p.x, p.y, npc.x, npc.y);
      npc.vx = (npc.vx || 0) + Math.cos(a) * opts.knockback;
      npc.vy = (npc.vy || 0) + Math.sin(a) * opts.knockback;
    }
    // lifesteal -> blood
    if (p && p.derived && p.derived.lifesteal > 0 && !opts.dot) {
      p.blood = Math.min(p.derived.maxBlood, p.blood + dmg * p.derived.lifesteal);
    }

    if (npc.hp <= 0) {
      if (VAMP.Nemesis && VAMP.Nemesis.tryFlee(game, npc)) return dmg; // a hunter escapes to return as a nemesis
      // #7 — a kill lands with weight: hit-stop + brief slowmo on elites/bosses
      if (game.hitStop) game.hitStop(npc.boss ? 0.16 : (npc.elite ? 0.10 : 0.04));
      if ((npc.boss || npc.elite) && game.setSlowmo) game.setSlowmo(npc.boss ? 1.1 : 0.55, 0.30);
      if (game.cam && (npc.boss || npc.elite)) game.cam.punch(npc.boss ? 0.12 : 0.07); // #19 punch-zoom
      killNPC(game, npc, opts);
    }
    return dmg;
  }

  function killNPC(game, npc, opts) {
    if (npc.dead) return;
    npc.dead = true;
    npc.deathT = game.time;
    npc.playerBody = true;   // killNPC is the player-offense kill path — this corpse is your evidence
    const p = game.player;
    if (p && p.bloodState) {
      p.bloodState.kills++;
      if (npc.innocent && !(opts && opts.justified)) {
        p.bloodState.innocentKills++;
        VAMP.Blood.adjustHumanity(p, -0.25, 'killed an innocent');
      }
    }
    if (VAMP.FX) VAMP.FX.blood(npc.x, npc.y, 16);
    if (VAMP.Audio) VAMP.Audio.play('death');
    game.onKill(npc, (opts && opts.cause) || 'combat');
  }

  // ---- NPC vs NPC (thralls, confused, gang wars) ----
  function damageNpcByNpc(game, attacker, target, amount, opts) {
    if (!target || target.dead) return 0;
    opts = opts || {};
    let dmg = Math.max(1, amount * (1 - (target.armor || 0)));
    if (hasStatus(target, 'mark')) dmg *= (1 + (target.status.mark.amount || 0.25));
    target.hp -= dmg;
    target.aggro = true;
    target.lastHitT = game.time;
    // retaliation: become hostile toward attacker
    if (!target.ally && !target.berserkT) { target.retaliateAgainst = attacker; target.retaliateT = 6; }
    if (!opts.silent && VAMP.FX) VAMP.FX.number(target.x, target.y - target.r - 6, Math.round(dmg), '#ffcaca', { small: true });
    if (opts.knockback) {
      const a = opts.angle != null ? opts.angle : U.angleTo(attacker.x, attacker.y, target.x, target.y);
      target.vx = (target.vx || 0) + Math.cos(a) * opts.knockback;
      target.vy = (target.vy || 0) + Math.sin(a) * opts.knockback;
    }
    if (target.hp <= 0) {
      target.dead = true; target.deathT = game.time;
      if (VAMP.FX) VAMP.FX.blood(target.x, target.y, 12);
      // credit kills by allies to the player for missions, but no humanity/feeding
      game.onKill(target, attacker.ally ? 'thrall' : 'crossfire');
    }
    return dmg;
  }

  // ---- damage the player ----
  function damagePlayer(game, amount, opts) {
    opts = opts || {};
    const p = game.player;
    if (!p || p.dead) return 0;
    if (p.invuln > 0 && !opts.dot) { if (VAMP.FX) VAMP.FX.number(p.x, p.y - 20, 'BLOCK', '#9df', { small: true }); return 0; }
    // dodge
    if (!opts.dot && !opts.unavoidable && Math.random() < p.derived.dodge) {
      if (VAMP.FX) VAMP.FX.number(p.x, p.y - 20, 'DODGE', '#9df', { small: true });
      return 0;
    }
    let dmg = amount * (1 - p.derived.armor);
    // ward buff
    if (p.ward && p.ward > 0) {
      const absorbed = Math.min(p.ward, dmg);
      p.ward -= absorbed; dmg -= absorbed;
      if (VAMP.FX) VAMP.FX.number(p.x, p.y - 24, 'WARD', '#7ad0ff', { small: true });
    }
    dmg = Math.max(0, dmg);
    p.hp -= dmg;
    p.lastHurtT = game.time;
    if (dmg > 0 && VAMP.FX) {
      VAMP.FX.number(p.x, p.y - 22, Math.round(dmg), '#ff5a5a');
      VAMP.FX.flash('rgba(150,0,0,0.28)', 0.18);
      // #19 — directional shake pushes the camera away from the hit
      if (game.cam) {
        const ang = opts.angle != null ? opts.angle : (opts.src && opts.src.x != null ? U.angleTo(opts.src.x, opts.src.y, p.x, p.y) : null);
        game.cam.shake(Math.min(8, dmg * 0.3), 0.25, ang);
      }
      // #16 — damage-direction indicator: a red arc on the side the hit came from
      if (game._dmgDirs) game._dmgDirs.push({ ang: opts.angle != null ? opts.angle : (opts.src && opts.src.x != null ? U.angleTo(p.x, p.y, opts.src.x, opts.src.y) : 0), t: 1.0, max: 1.0 });
    }
    if (dmg > 0 && VAMP.Audio && !opts.dot) VAMP.Audio.play('hurt');
    if (dmg > 0 && VAMP.Mastery && !opts.dot) VAMP.Mastery.gain(p, 'survival', dmg * 0.25);
    if (p.hp <= 0) { p.hp = 0; game.onPlayerDeath(opts); }
    return dmg;
  }

  VAMP.Combat = {
    applyStatus, hasStatus, updateStatuses, damageNPC, damagePlayer, killNPC, damageNpcByNpc,
    speedFactor, isDisabled, isRooted, isFeared, STATUS_COLOR,
  };
})();
