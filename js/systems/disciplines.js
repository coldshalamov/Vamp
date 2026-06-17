/* =========================================================================
 * VAMPIRE CITY — systems/disciplines.js
 * Active / toggle power manager: known powers, hotbar slots, cooldowns,
 * blood costs, casting. Power DATA lives in gamedata.js; power EFFECT
 * functions live in systems/powers.js (VAMP.PowerFX).
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  function powerDef(id) { return VAMP.Data.POWERS[id]; }

  function known(p, id) { return p.powers && p.powers[id]; }

  function effectiveCost(p, def) {
    let c = def.cost || 0;
    const eff = (p.derived && p.derived.bloodEff) || 0;
    return Math.max(0, c * (1 - eff));
  }
  function effectiveCooldown(p, def) {
    return (def.cooldown || 0) * (p.derived ? p.derived.cooldownMult : 1);
  }

  function canCast(p, id) {
    const def = powerDef(id);
    if (!def) return { ok: false, why: 'unknown' };
    if (!known(p, id)) return { ok: false, why: 'not learned' };
    if (def.type === 'toggle' && p.toggles[id]) return { ok: true, toggleOff: true };   // turning a toggle OFF is never blocked by its own activation cooldown
    if ((p.cooldowns[id] || 0) > 0) return { ok: false, why: 'cooling down' };
    if (p.blood < effectiveCost(p, def)) return { ok: false, why: 'not enough vitae' };
    return { ok: true };
  }

  function cast(p, game, id) {
    const def = powerDef(id);
    if (!def) return false;
    const c = canCast(p, id);
    if (!c.ok && !c.toggleOff) {
      if (c.why && VAMP.UI) VAMP.UI.notify(def.name + ': ' + c.why, '#a66');
      if (VAMP.Audio) VAMP.Audio.play('ui');
      return false;
    }
    // toggle off
    if (def.type === 'toggle' && p.toggles[id]) {
      p.toggles[id] = false;
      const fx = VAMP.PowerFX[def.fx + 'Off'] || (def.offFx && VAMP.PowerFX[def.offFx]);
      if (fx) fx(p, game, def);
      VAMP.bus && VAMP.bus.emit('toggle', id, false);
      return true;
    }
    // invoke effect
    const fn = VAMP.PowerFX[def.fx];
    if (!fn) { if (VAMP.UI) VAMP.UI.notify(def.name + ' (not implemented)', '#a66'); return false; }
    const ok = fn(p, game, def);
    if (ok === false) return false; // effect aborted, no cost
    // pay cost
    p.blood = Math.max(0, p.blood - effectiveCost(p, def));
    if (def.type === 'toggle') { p.toggles[id] = true; VAMP.bus && VAMP.bus.emit('toggle', id, true); }
    p.cooldowns[id] = effectiveCooldown(p, def);
    if (def.sound && VAMP.Audio) VAMP.Audio.play(def.sound);
    else if (VAMP.Audio) VAMP.Audio.play(def.type === 'active' ? 'spell' : 'skill');
    p.stats && (p.stats.castsTotal = (p.stats.castsTotal || 0) + 1);
    if (VAMP.Mastery && def.type === 'active') VAMP.Mastery.gain(p, (def.disc === 'sorcery' || def.disc === 'dark') ? 'sorcery' : 'nightstalker', 2);
    return true;
  }

  function castSlot(p, game, slotIndex) {
    const id = p.slots[slotIndex];
    if (!id) return false;
    return cast(p, game, id);
  }

  // assign power to a hotbar slot (0..7)
  function assignSlot(p, slotIndex, id) {
    if (id && !known(p, id)) return false;
    // prevent duplicates: clear other slot holding this id
    if (id) for (let i = 0; i < p.slots.length; i++) if (p.slots[i] === id) p.slots[i] = null;
    p.slots[slotIndex] = id || null;
    return true;
  }

  // auto-place a newly learned active power in the first empty slot
  function autoSlot(p, id) {
    const def = powerDef(id);
    if (!def || def.type === 'passive') return;
    for (let i = 0; i < p.slots.length; i++) if (!p.slots[i]) { p.slots[i] = id; return; }
  }

  function update(p, game, dt) {
    for (const id in p.cooldowns) {
      if (p.cooldowns[id] > 0) { p.cooldowns[id] = Math.max(0, p.cooldowns[id] - dt); }
    }
    // toggle upkeep (drain blood; auto-off if empty)
    for (const id in p.toggles) {
      if (!p.toggles[id]) continue;
      const def = powerDef(id);
      if (!def) continue;
      if (def.upkeep) {
        p.blood -= def.upkeep * dt;
        if (p.blood <= 0) {
          p.blood = 0;
          const offFx = VAMP.PowerFX[def.fx + 'Off'] || (def.offFx && VAMP.PowerFX[def.offFx]);
          if (offFx) offFx(p, game, def);
          p.toggles[id] = false;
          VAMP.bus && VAMP.bus.emit('toggle', id, false);
          if (VAMP.UI) VAMP.UI.notify(def.name + ' faded — out of vitae', '#a66');
          continue; // don't also run the Tick for a power that just turned off
        }
      }
      // per-frame toggle effect
      const tickFn = VAMP.PowerFX[def.fx + 'Tick'];
      if (tickFn) tickFn(p, game, def, dt);
    }
    // active power timed states handled via buffs; nothing else here
  }

  // learn / unlock a power (called by skill tree)
  function learn(p, id) {
    if (!p.powers) p.powers = {};
    if (p.powers[id]) return false;
    p.powers[id] = true;
    autoSlot(p, id);
    const def = powerDef(id);
    if (def && VAMP.UI) VAMP.UI.notify('Learned: ' + def.name, def.disc ? '#c79bff' : '#9bf');
    if (VAMP.Codex) VAMP.Codex.checkComplete(p);
    return true;
  }

  VAMP.Disc = { cast, castSlot, assignSlot, update, learn, canCast, effectiveCost, effectiveCooldown, powerDef, autoSlot };
})();
