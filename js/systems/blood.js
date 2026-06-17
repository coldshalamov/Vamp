/* =========================================================================
 * VAMPIRE CITY — systems/blood.js
 * The Vitae economy: blood pool, Hunger, Frenzy/the Beast, Humanity,
 * and the feeding loop (grab -> drain -> reward). Core vampire fantasy.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  // Victim archetypes: different blood quality / yield / XP / risk
  const VICTIM_TYPES = {
    civilian: { name: 'Civilian', yield: 22, xp: 14, quality: 1.0, color: '#c98', resist: 0 },
    junkie:   { name: 'Junkie',   yield: 18, xp: 10, quality: 0.7, color: '#9a7', resist: 0, tainted: true },
    addict:   { name: 'Reveler',  yield: 24, xp: 12, quality: 1.1, color: '#b9c', resist: 0 },
    athlete:  { name: 'Athlete',  yield: 30, xp: 20, quality: 1.4, color: '#caa', resist: 0.1 },
    noble:    { name: 'Aristocrat', yield: 34, xp: 28, quality: 1.7, color: '#cc9', resist: 0.05, rich: true },
    thug:     { name: 'Gangster', yield: 26, xp: 22, quality: 1.2, color: '#a88', resist: 0.25 },
    cop:      { name: 'Officer',  yield: 28, xp: 30, quality: 1.3, color: '#88a', resist: 0.4, heat: true },
    hunter:   { name: 'Hunter',   yield: 32, xp: 45, quality: 1.6, color: '#c66', resist: 0.6, heat: true, potent: true },
    rat:      { name: 'Rat',      yield: 8,  xp: 3,  quality: 0.4, color: '#765', resist: 0, animal: true },
  };

  function newBloodState() {
    return {
      hunger: 1,         // 0..5 (V5 style). starts at 1
      humanity: 7,       // 0..10
      stains: 0,         // pending humanity loss
      frenzy: 0,         // 0..1 active frenzy meter (when frenzied)
      frenzied: false,
      frenzyCooldown: 0,
      kills: 0,          // total kills (lifetime stat)
      innocentKills: 0,
      fedCount: 0,
      elderVitae: 0, elderSpent: {}, elderProgress: 0,  // Paragon (post-L60 infinite progression)
      dawnStreak: 0,                                      // consecutive safe dawns (night-shift loop)
    };
  }

  // hunger rises as blood depletes
  function updateHunger(p, dt) {
    const b = p.bloodState;
    const ratio = p.blood / Math.max(1, p.derived.maxBlood);
    // target hunger from blood ratio
    let target;
    if (ratio > 0.8) target = 0;
    else if (ratio > 0.6) target = 1;
    else if (ratio > 0.4) target = 2;
    else if (ratio > 0.2) target = 3;
    else if (ratio > 0.05) target = 4;
    else target = 5;
    b.hunger = U.approach(b.hunger, target, dt * 0.8);

    // gentle Hunger drain over time (unlife is hungry) — outpaced by vitae regen when idle, so a
    // resting vampire recovers, but active play (sprint/pounce/spells) still depletes you toward a feed.
    p.blood = Math.max(0, p.blood - dt * 0.12);
    // (vitae REGEN is in passiveRegen — always-on now, so spells are never permanently dead)

    // frenzy risk when hunger maxed
    if (b.frenzyCooldown > 0) b.frenzyCooldown -= dt;
    if (!b.frenzied && b.hunger >= 5 && b.frenzyCooldown <= 0) {
      // chance to lose control scales with how long starving
      const resist = p.derived.frenzyResist;
      if (Math.random() < (1 - resist) * dt * 0.15) startFrenzy(p);
    }
    if (b.frenzied) {
      b.frenzy -= dt * 0.06; // frenzy burns out over ~16s unless fed
      if (b.frenzy <= 0) endFrenzy(p);
    }
  }

  function startFrenzy(p) {
    const b = p.bloodState;
    b.frenzied = true; b.frenzy = 1;
    if (VAMP.Audio) VAMP.Audio.play('frenzy');
    if (VAMP.FX) VAMP.FX.flash('#7a0010', 0.5);
    VAMP.bus && VAMP.bus.emit('frenzy', true);
  }
  function endFrenzy(p) {
    const b = p.bloodState;
    b.frenzied = false; b.frenzy = 0; b.frenzyCooldown = 8;
    VAMP.bus && VAMP.bus.emit('frenzy', false);
  }

  // Apply a Humanity change. Negative for sins.
  function adjustHumanity(p, delta, reason) {
    const b = p.bloodState;
    b.humanity = U.clamp(b.humanity + delta, 0, 10);
    if (delta < 0 && VAMP.UI) VAMP.UI.notify(`Humanity ${delta.toFixed(1)} — ${reason}`, '#b5485f');
    VAMP.bus && VAMP.bus.emit('humanity', b.humanity);
  }

  // ---- feeding ----
  // begin draining a victim NPC. The act is metered; call tick each frame.
  function startFeeding(p, npc) {
    if (!npc || npc.dead) return false;
    const vt = VICTIM_TYPES[npc.victimType] || VICTIM_TYPES.civilian;
    p.feeding = {
      npc, vt,
      progress: 0,
      drained: 0,
      lethal: false,
    };
    if (VAMP.Audio) VAMP.Audio.play('bite');
    return true;
  }

  // returns 'continue' | 'done' | 'interrupted'
  function tickFeeding(p, dt, game) {
    const f = p.feeding;
    if (!f) return 'idle';
    const npc = f.npc;
    if (!npc || npc.dead || npc.fledFar) { stopFeeding(p, game); return 'interrupted'; }
    const d = U.dist(p.x, p.y, npc.x, npc.y);
    if (d > 46) { stopFeeding(p, game); return 'interrupted'; }

    const speed = p.derived.feedSpeed * (1 + (p.bloodState.hunger * 0.1));
    f.progress += dt * speed;
    // transfer blood
    const rate = f.vt.yield * 0.55 * p.derived.feedYield;
    const gain = rate * dt * speed;
    f.drained += gain;
    p.blood = Math.min(p.derived.maxBlood, p.blood + gain);
    npc.bloodLeft = (npc.bloodLeft === undefined ? f.vt.yield * 1.6 : npc.bloodLeft) - gain;

    // feeding rhythm mini-game: a marker sweeps; click in the sweet zone for a Perfect Gulp
    f.beat = ((f.beat || 0) + dt * 1.4) % 1;
    // visual + sound: steady "gulp" cadence so feeding feels visceral
    f.gulpT = (f.gulpT || 0) - dt;
    if (f.gulpT <= 0) {
      f.gulpT = 0.5;
      if (VAMP.Audio) VAMP.Audio.play('gulp');
      if (VAMP.FX) VAMP.FX.blood(npc.x, npc.y, 3);
    }
    if (VAMP.FX && Math.random() < 0.35) VAMP.FX.spark(npc.x + (Math.random() - 0.5) * 12, npc.y + (Math.random() - 0.5) * 6, '#a00010', 1);

    // hunger relief
    p.bloodState.hunger = Math.max(0, p.bloodState.hunger - dt * speed * 0.5);
    if (p.bloodState.frenzied) { p.bloodState.frenzy = Math.min(1, p.bloodState.frenzy + dt * 0.3); }

    // Killing is a CHOICE: only a HELD feed (or a lethal execution) drains to death.
    // A released/normal feed always leaves the victim alive — even on a re-feed where their
    // persistent bloodLeft is already low (previously that silently killed a spared victim,
    // costing Humanity and spawning a corpse the player never meant to make).
    const tapped = npc.bloodLeft <= 0;
    if (p.holdingFeed && (f.drained >= f.vt.yield * 1.55 || tapped)) {
      finishFeeding(p, game, true);
      return 'done';
    }
    if (!p.holdingFeed && (f.drained >= f.vt.yield || tapped)) {
      finishFeeding(p, game, false);
      return 'done';
    }
    return 'continue';
  }

  function finishFeeding(p, game, lethal) {
    const f = p.feeding;
    if (!f) return;
    const vt = f.vt;
    const npc = f.npc;
    const b = p.bloodState;
    b.fedCount++;

    // XP reward (scaled by potency + presence)
    let xp = vt.xp * (1 + p.derived.bloodPotency * 0.15) * p.derived.feedYield;
    if (lethal) xp *= 1.3;
    if (f.execution) {                       // executions are skillful kills
      xp *= 1.3;
      p.addBuff && p.addBuff({ id: 'visceral', name: 'Visceral Kill', dur: 6, color: '#ff5a5a', mods: { pct: { critChance: 0.1, meleeDmg: 0.1 } } });
    }
    const res = VAMP.Stats.gainXP(p, xp);

    // continuing-value hooks: mastery, codex, haven cellar overflow, reagents
    if (VAMP.Mastery) VAMP.Mastery.gain(p, 'predation', 6 + vt.xp * 0.3);
    if (VAMP.Codex) VAMP.Codex.mark(p, 'fedTypes', npc.victimType);
    if (VAMP.Haven && VAMP.Haven.level(p, 'cellar') > 0) VAMP.Haven.depositVitae(p, f.drained * 0.25);
    if (VAMP.Alchemy && VAMP.Alchemy.bankReagent) VAMP.Alchemy.bankReagent(p, npc.victimType);

    // tainted blood penalty
    if (vt.tainted && Math.random() < 0.5) {
      p.addBuff && p.addBuff({ id: 'tainted', name: 'Tainted Blood', dur: 8, mods: { pct: { moveSpeed: -0.12 } }, color: '#7a8' });
    }
    if (vt.potent) {
      p.addBuff && p.addBuff({ id: 'potent', name: 'Potent Vitae', dur: 20, mods: { pct: { spellPower: 0.2, meleeDmg: 0.15 } }, color: '#c33' });
    }
    if (vt.rich && game) { const cash = 40 + Math.floor(Math.random() * 80); game.addMoney(cash, npc.x, npc.y); }

    if (lethal) {
      npc.dead = true; npc.diedFeeding = true; npc.playerBody = true;   // a drained corpse is your evidence
      b.kills++;
      if (!vt.heat && !vt.animal) { b.innocentKills++; adjustHumanity(p, f.execution ? -0.5 : -0.4, 'killed an innocent'); }   // a brutal execution costs a little more
      if (game) game.onKill(npc, 'feed');
      if (VAMP.FX) VAMP.FX.blood(npc.x, npc.y, 14);
      // killing in view raises masquerade — but a silent behind-the-back takedown is witness-gated
      // (no scream/struggle), so an unseen kill in a dark alley draws no Heat. The body still remains.
      if (game) game.masquerade.witnessedAct(npc.x, npc.y, (f && f.stealth) ? 'feed' : 'kill', 1.5);
    } else {
      // left alive: they collapse UNCONSCIOUS — an inert body that can be found, dragged off, dumped,
      // or fed on again. (VtM: a spared vessel doesn't just wander off; they're out cold.)
      if (VAMP.Stealth) VAMP.Stealth.knockOut(npc, game);
      else npc.mesmerizedT = Math.max(npc.mesmerizedT || 0, 2.5);
      if (game && !(f && f.stealth)) game.masquerade.witnessedAct(npc.x, npc.y, 'feed', 1);
      adjustHumanity(p, 0.03, ''); // mercy preserves your Humanity (silent positive)
    }

    // payoff juice — a distinct climax for a lethal drain vs a clean release
    const gained = Math.round(f.drained);
    if (VAMP.FX) {
      VAMP.FX.number(p.x, p.y - 30, '+' + gained + ' vitae', '#ff2f6e', {});
      if (lethal) { VAMP.FX.flash('rgba(120,0,20,0.30)', 0.25); VAMP.FX.ring(npc.x, npc.y, 40, '#c01028'); VAMP.FX.number(npc.x, npc.y - 44, 'DRAINED', '#c01028', { crit: true }); }
    }
    if (lethal && game && game.cam) game.cam.shake(3, 0.2);

    if (game) game.feedEvent({ vt, lethal, xp, ups: res.ups });
    p.feeding = null;
    return res;
  }

  function stopFeeding(p, game) { p.feeding = null; }

  // feeding mini-game: click during the sweet window (beat 0.42..0.62) for a Perfect Gulp
  function gulpHit(p, game) {
    const f = p.feeding; if (!f) return;
    const beat = f.beat || 0;
    if (beat >= 0.42 && beat <= 0.62) {
      f.perfect = (f.perfect || 0) + 1;
      const bonus = 6 * p.derived.feedYield;
      p.blood = Math.min(p.derived.maxBlood, p.blood + bonus);
      f.drained += bonus * 0.5;
      if (VAMP.FX) { VAMP.FX.number(p.x, p.y - 34, 'PERFECT', '#ffd24a', { crit: true }); VAMP.FX.ring(p.x, p.y, 30, '#ffd24a'); }
      if (VAMP.Audio) VAMP.Audio.play('perfectGulp');
      // #7 — a perfect gulp gets a satisfying micro-slowmo
      if (game && game.setSlowmo) game.setSlowmo(0.35, 0.45);
      f.beat = 0; // reset so you must time the next
    } else {
      f.miss = (f.miss || 0) + 1;
      if (game) game.masquerade.add(0.04); // sloppy feeding draws a little attention
      if (VAMP.FX) VAMP.FX.number(p.x, p.y - 30, 'miss', '#a88', { small: true });
    }
  }

  // emergency: vampires can burn vitae to heal (Mend handled in disciplines, but base regen here)
  function passiveRegen(p, dt, resting) {
    const d = p.derived;
    // HP regen always slow; faster when not in combat
    const mult = resting ? 2.2 : 1;
    if (p.hp < d.maxHP) p.hp = Math.min(d.maxHP, p.hp + d.hpRegen * dt * mult);
    // VITAE regenerates over time like mana, so a cast spell is never permanently dead — the meter
    // trickles back (faster when resting / out of combat). Feeding is still the FAST refill and the
    // only thing that relieves Hunger + grants XP, so it stays central. Speed scales with Bloodcraft
    // / bloodRegen (trainable); max scales with level (see Stats.recompute).
    if (p.blood < d.maxBlood) p.blood = Math.min(d.maxBlood, p.blood + d.bloodRegen * dt * (resting ? 2.2 : 0.9));
  }

  VAMP.Blood = {
    VICTIM_TYPES, newBloodState, updateHunger, adjustHumanity,
    startFeeding, tickFeeding, finishFeeding, stopFeeding, passiveRegen,
    startFrenzy, endFrenzy, gulpHit,
  };
})();
