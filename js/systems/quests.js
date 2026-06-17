/* =========================================================================
 * VAMPIRE CITY — systems/quests.js
 * Radiant/emergent world events that keep the sandbox alive: blood dolls,
 * gang wars, bounties, hunter ambushes. Light-weight director.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  function create(game) {
    return {
      timer: 45,
      active: [],
      update(dt) {
        this.timer -= dt;
        if (this.timer <= 0) {
          this.timer = U.lerp(50, 95, Math.random());
          this.trigger(game);
        }
        // prune resolved
        this.active = this.active.filter((e) => game.time - e.t < 90 && (!e.ref || !e.ref.dead));
      },
      trigger(game) {
        const hum = game.player.bloodState.humanity;
        const stars = game.masquerade ? game.masquerade.stars : 0;
        // "notorious" = YOU drew the eye of the Inquisition through your own deeds (open violence
        // or a sunk soul). Hunters/nemeses only stalk a notorious vampire — a calm, careful player
        // is left to explore. This is the core "chaos is opt-in" rule for the radiant director.
        const notorious = stars >= 3 || hum <= 3;
        const roll = Math.random();
        if (notorious) {
          // a remembered nemesis picks up your trail of blood
          if (VAMP.Nemesis && game.player.nemeses && game.player.nemeses.length && Math.random() < 0.4) { if (VAMP.Nemesis.maybeInject(game)) return; }
          if (roll < 0.45) this.hunterAmbush(game);
          else if (roll < 0.7) this.gangWar(game);
          else if (roll < 0.88) this.bounty(game);
          else this.bloodDoll(game);
        } else {
          // calm baseline: only opportunities + ambient feuds that ignore a careful player
          if (roll < 0.45) this.bloodDoll(game);
          else if (roll < 0.78) this.gangWar(game);   // rival gangs feud each other — harmless unless you wade in
          else this.bounty(game);                      // a neutral marked target you MAY choose to hunt
        }
      },
      spot(game, minD, maxD) {
        const p = game.player; const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
        for (let i = 0; i < 60; i++) {
          const a = Math.random() * U.TAU, d = U.lerp(minD, maxD, Math.random());
          const x = px + Math.cos(a) * d, y = py + Math.sin(a) * d;
          if (x < 60 || y < 60 || x > game.world.w - 60 || y > game.world.h - 60) continue;
          if (game.world.isWalkable(x, y)) return { x, y };
        }
        return null;
      },
      bloodDoll(game) {
        const pos = this.spot(game, 150, 420); if (!pos) return;
        const n = VAMP.Npc.create(game.world, 'ped', pos.x, pos.y, { victimType: 'noble' });
        n.vip = true; n.bloodDoll = true; n.skin = '#f0d8e8';
        game.addNPC(n);
        this.active.push({ type: 'bloodDoll', ref: n, t: game.time });
        if (VAMP.UI) VAMP.UI.notify('A blood doll wanders nearby — potent vitae', '#ff9ecf');
        game.addBlip({ ref: n, color: '#ff9ecf', kind: 'event' });
      },
      gangWar(game) {
        const pos = this.spot(game, 260, 600); if (!pos) return;
        const a = [], bgrp = [];
        for (let i = 0; i < 3; i++) {
          const e1 = VAMP.Npc.create(game.world, Math.random() < 0.5 ? 'gunner' : 'thug', pos.x + (Math.random() - 0.5) * 60, pos.y + (Math.random() - 0.5) * 60, {});
          e1.shirt = '#6a1f2a'; a.push(e1); game.addNPC(e1);
          const e2 = VAMP.Npc.create(game.world, Math.random() < 0.5 ? 'gunner' : 'thug', pos.x + 90 + (Math.random() - 0.5) * 60, pos.y + (Math.random() - 0.5) * 60, {});
          e2.shirt = '#2a1f6a'; bgrp.push(e2); game.addNPC(e2);
        }
        // make them fight each other
        a.forEach((e, i) => { e.aggro = true; e.retaliateAgainst = bgrp[i % bgrp.length]; e.retaliateT = 30; e.state = 'chase'; });
        bgrp.forEach((e, i) => { e.aggro = true; e.retaliateAgainst = a[i % a.length]; e.retaliateT = 30; e.state = 'chase'; });
        if (VAMP.UI) VAMP.UI.notify('A gang war erupts nearby', '#e0a040');
        game.addBlip({ x: pos.x, y: pos.y, color: '#e0a040', kind: 'event', ttl: game.time + 60 });
      },
      bounty(game) {
        const pos = this.spot(game, 300, 700); if (!pos) return;
        const n = VAMP.Npc.create(game.world, 'gunner', pos.x, pos.y, { hp: 90 + game.player.level * 6 });
        n.faction = 'gang'; n.vip = true; n.bounty = 150 + game.player.level * 25;
        n.weapon = 'magnum' in {} ? 'pistol' : 'pistol';
        game.addNPC(n);
        this.active.push({ type: 'bounty', ref: n, t: game.time });
        if (VAMP.UI) VAMP.UI.notify('Bounty: a marked killer roams — $' + n.bounty, '#ffd24a');
        game.addBlip({ ref: n, color: '#ffd24a', kind: 'event' });
      },
      hunterAmbush(game) {
        const count = 2 + (game.player.level / 12 | 0);
        for (let i = 0; i < count; i++) {
          const pos = this.spot(game, 380, 640); if (!pos) continue;
          const n = VAMP.Npc.create(game.world, 'hunter', pos.x, pos.y, { hp: VAMP.Npc.PRESETS.hunter.hp * (1 + game.player.level * 0.05) });
          n.aggro = true; n.state = 'chase'; n.hostileToPlayer = true;
          if (Math.random() < 0.3) n.sniper = true;
          game.addNPC(n);
        }
        if (VAMP.UI) VAMP.UI.notify('The Second Inquisition has found you!', '#ff5a5a');
        if (VAMP.Audio) VAMP.Audio.play('frenzy');
      },
    };
  }

  VAMP.Quests = { create };
})();
