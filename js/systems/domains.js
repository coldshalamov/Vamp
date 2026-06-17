/* =========================================================================
 * VAMPIRE CITY — systems/domains.js  (#2 Territory Control + #9 World Reactivity)
 * Claim each district by slaying its Baron; held turf flies your sigil, lowers
 * heat-gain, biases prey spawns, and pays a nightly tithe (collected at dawn).
 * Shares the per-district state layer (terror/prosperity) with reactivity.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  function ensure(game) {
    if (!game.domains) game.domains = {};
    if (!game.districtState) game.districtState = {};
    for (const d of game.world.districts) {
      if (!game.domains[d.id]) game.domains[d.id] = { owner: null, contesting: false };
      if (!game.districtState[d.id]) game.districtState[d.id] = { terror: 0, prosperity: 0 };
    }
  }
  function distName(game, id) { const d = game.world.districts.find((x) => x.id === id); return d ? d.name : id; }
  function ownedCount(game) { ensure(game); let n = 0; for (const k in game.domains) if (game.domains[k].owner === 'player') n++; return n; }

  function districtSpot(game, id) {
    const idx = game.world.districts.findIndex((x) => x.id === id);
    const cands = game.world.buildings.filter((b) => b.d === idx);
    if (cands.length) { const b = cands[(Math.random() * cands.length) | 0]; return game.walkableNear(b.x + b.w / 2, b.y + b.h + 20); }
    return game.walkableNear(game.player.x + 200, game.player.y);
  }

  function contest(game, id) {
    ensure(game);
    const dm = game.domains[id];
    if (dm.owner === 'player') { VAMP.UI.notify('You already hold ' + distName(game, id) + '.', '#a88'); return; }
    const baronAlive = game.npcs.some((n) => n.baronOf === id && !n.dead);
    if (baronAlive) { VAMP.UI.notify('Already contesting — slay the Baron.', '#a88'); return; }
    if (dm.contesting && !baronAlive) dm.contesting = false; // self-heal a stale contest (baron lost/culled)
    const cap = VAMP.Legend ? VAMP.Legend.domainCap(game.player) : 3;
    if (ownedCount(game) >= cap) { VAMP.UI.notify('Your Legend is too small to hold more domains.', '#a66'); return; }
    dm.contesting = true;
    const pos = districtSpot(game, id);
    const baron = VAMP.Npc.create(game.world, 'elder', pos.x, pos.y, { hp: 380 + game.player.level * 18, name: 'Baron of ' + distName(game, id) });
    baron.baronOf = id; baron.faction = 'gang'; baron.aggro = true; baron.vip = true; baron.boss = true; baron.hostileToPlayer = true;
    baron.speed = 110; baron.phase = 1;   // #22 — phased fight state
    // #22 — phase transitions: at 66% and 33% HP the Baron enrages + summons adds.
    // Hooked through onDamaged so it works with any damage source.
    baron.onDamaged = function (dmg, o, g) {
      const prev = baron.hp + dmg;          // hp before this hit
      const frac = baron.hp / baron.maxHp;
      const crossed = (thr) => prev / baron.maxHp > thr && frac <= thr;
      if (crossed(0.66) && baron.phase < 2) {
        baron.phase = 2; baron.speed *= 1.25; baron.dmgMul = (baron.dmgMul || 1) * 1.2;
        if (VAMP.UI) VAMP.UI.notify('The Baron enrages! ("Phase 2")', '#ff5a30');
        if (VAMP.FX) { VAMP.FX.ring(baron.x, baron.y, 80, '#ff5a30'); VAMP.FX.flash('rgba(255,60,30,0.25)', 0.3); }
        if (g.cam) g.cam.shake(5, 0.3);
      } else if (crossed(0.33) && baron.phase < 3) {
        baron.phase = 3; baron.speed *= 1.2; baron.dmgMul = (baron.dmgMul || 1) * 1.3; baron.armor = (baron.armor || 0) + 0.1;
        if (VAMP.UI) VAMP.UI.notify('The Baron calls for aid! ("Phase 3")', '#ff3030');
        if (VAMP.FX) { VAMP.FX.ring(baron.x, baron.y, 100, '#ff3030'); VAMP.FX.flash('rgba(255,40,20,0.3)', 0.35); }
        // summon 2 fresh lieutenants
        for (let k = 0; k < 2; k++) { const g2 = VAMP.Npc.create(g.world, 'gunner', baron.x + (Math.random() - 0.5) * 80, baron.y + (Math.random() - 0.5) * 80, {}); g2.faction = 'gang'; g2.aggro = true; g2.hostileToPlayer = true; g2.baronGuard = id; g.addNPC(g2); }
        if (g.cam) g.cam.shake(6, 0.35);
      }
    };
    // a couple of lieutenants
    for (let i = 0; i < 3; i++) { const g2 = VAMP.Npc.create(game.world, 'gunner', pos.x + (Math.random() - 0.5) * 80, pos.y + (Math.random() - 0.5) * 80, {}); g2.faction = 'gang'; g2.aggro = true; g2.hostileToPlayer = true; g2.baronGuard = id; game.addNPC(g2); }
    game.addNPC(baron);
    game.addBlip({ ref: baron, color: '#d6953f', kind: 'event' });
    VAMP.UI.banner('CONTEST: ' + distName(game, id), 'Slay the Baron to claim this district.', '#d6953f');
  }

  function onBaronDead(game, baron) {
    ensure(game);
    const id = baron.baronOf; const dm = game.domains[id]; if (!dm) return;
    dm.owner = 'player'; dm.contesting = false;
    game.districtState[id].prosperity = 1; game.districtState[id].terror = 0;
    // clean up guards
    for (const n of game.npcs) if (n.baronGuard === id) n.dead = true;
    VAMP.UI.banner('DISTRICT CLAIMED', distName(game, id) + ' flies your sigil — it now pays a nightly tithe.', '#ffd24a');
    if (VAMP.Audio) VAMP.Audio.play('win');
    if (VAMP.Legend) VAMP.Legend.add(game, 12);
    if (VAMP.Reputation) VAMP.Reputation.change(game.player, 'anarch', 8);
    if (VAMP.Progress) { VAMP.Progress.markSeen(game.player, 'domains'); VAMP.Progress.reveal(game, 'businesses'); }
  }

  // dawn payout
  function collectTithe(game) {
    ensure(game);
    let cash = 0, vitae = 0;
    for (const d of game.world.districts) {
      if (game.domains[d.id].owner === 'player') {
        const mult = (1 + d.danger) * (1 + game.districtState[d.id].prosperity);
        cash += Math.round(45 * mult);
        vitae += Math.round(8 * mult);
      }
    }
    return { cash, vitae };
  }

  function heatMult(game, x, y) {
    ensure(game);
    const d = game.world.districtAt(x, y);
    if (d && game.domains[d.id] && game.domains[d.id].owner === 'player') return 0.4;
    return 1;
  }
  function isOwned(game, id) { ensure(game); return game.domains[id] && game.domains[id].owner === 'player'; }
  function raiseTerror(game, x, y, amt) {
    ensure(game); const d = game.world.districtAt(x, y);
    if (d) game.districtState[d.id].terror = U.clamp((game.districtState[d.id].terror || 0) + amt, 0, 1);
  }
  function stateAt(game, x, y) { ensure(game); const d = game.world.districtAt(x, y); return d ? game.districtState[d.id] : null; }

  VAMP.Domains = { ensure, contest, onBaronDead, collectTithe, heatMult, ownedCount, isOwned, raiseTerror, stateAt, distName };
})();
