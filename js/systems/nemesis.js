/* =========================================================================
 * VAMPIRE CITY — systems/nemesis.js  (#14 Persistent Nemesis Hunters)
 * A Second-Inquisition hunter who would die while you're weak instead ESCAPES,
 * remembers the scar you gave it, grows in rank, and returns later as a named
 * ambush. A personal foe with continuity — the strongest anti-staleness hook.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  const NAMES = ['Sir Crawford', 'Agent Vane', 'Father Holloway', 'Inquisitor Pike', 'Huntress Cole', 'Brother Ash', 'Marshal Quinn'];

  function ensure(p) { if (!p.nemeses) p.nemeses = []; return p.nemeses; }

  // hunter at 0 hp -> chance to flee and become a remembered nemesis
  function tryFlee(game, npc) {
    if (npc.faction !== 'inquis' || npc._fledOnce || npc.nemesis) return false;
    if (npc.dead) return false;
    if (Math.random() > 0.4) return false;
    npc._fledOnce = true; npc.hp = npc.maxHp * 0.3;
    npc.state = 'flee'; npc.fleeT = 10; npc.aggro = false; npc._fledAway = true;
    ensure(game.player);
    const name = NAMES[(Math.random() * NAMES.length) | 0];
    // it remembers HOW you hurt it — and returns hardened against your go-to method
    game.player.nemeses.push({ name, rank: 1, scar: ['Celerity', 'Potence', 'Sorcery', 'Obfuscate'][(Math.random() * 4) | 0], resistType: game.player._lastDmgType || null });
    VAMP.UI.banner('A HUNTER ESCAPES', name + ' flees, scarred — and will return for you.', '#ff5a5a');
    if (VAMP.Progress) VAMP.Progress.reveal(game, 'nemesis');
    return true;
  }

  // re-inject a saved nemesis as a buffed ambush
  function maybeInject(game) {
    const p = game.player; if (!p.nemeses || !p.nemeses.length) return false;
    const rec = p.nemeses[(Math.random() * p.nemeses.length) | 0];
    let pos = null;
    for (let i = 0; i < 30; i++) { const a = Math.random() * 6.28, d = 380 + Math.random() * 300; const x = (p.x) + Math.cos(a) * d, y = (p.y) + Math.sin(a) * d; if (game.world.isWalkable(x, y)) { pos = { x, y }; break; } }
    if (!pos) return false;
    const n = VAMP.Npc.create(game.world, 'hunter', pos.x, pos.y, { hp: 220 + rec.rank * 60 + p.level * 8, name: rec.name });
    n.nemesis = true; n.nemesisName = rec.name; n.aggro = true; n.state = 'chase'; n.vip = true; n.hostileToPlayer = true;
    n.armor = (n.armor || 0) + 0.15 + rec.rank * 0.05; n.dmgMul = 1.3 + rec.rank * 0.15; n.speed *= 1.1;
    // ADAPTED: hardened against the damage type you used to scar it (50% resist). Vary your attack.
    if (rec.resistType) { n.resist = Object.assign(n.resist || {}, { [rec.resistType]: 0.5 }); n.wardedMind = true; }
    game.addNPC(n); game.addBlip({ ref: n, color: '#ff3030', kind: 'event' });
    VAMP.UI.banner('NEMESIS RETURNS', rec.name + ' (rank ' + rec.rank + ') has found you — and learned your tricks.', '#ff3030');
    if (VAMP.Audio) VAMP.Audio.play('frenzy');
    rec.rank++;
    return true;
  }

  function onNemesisDead(p, npc) {
    if (!p.nemeses) return;
    const i = p.nemeses.findIndex((r) => r.name === npc.nemesisName);
    if (i >= 0) { p.nemeses.splice(i, 1); if (VAMP.UI) VAMP.UI.notify('You have ended ' + npc.nemesisName + '. Vengeance is yours.', '#ffd24a'); }
  }

  VAMP.Nemesis = { ensure, tryFlee, maybeInject, onNemesisDead };
})();
