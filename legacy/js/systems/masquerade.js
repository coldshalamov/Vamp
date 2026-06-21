/* =========================================================================
 * VAMPIRE CITY — systems/masquerade.js
 * The Masquerade / Heat system (GTA-style wanted stars). Witnessed crimes
 * raise Heat; escalating responders (police -> SWAT -> Second Inquisition)
 * hunt the player. Heat decays out of sight / in a haven / via powers.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  function create(game) {
    const M = {
      heat: 0,            // 0..6
      get stars() { return Math.min(6, Math.floor(this.heat)); },
      lastCrimeT: -99,
      lastProvokeT: -99,  // when the PLAYER last provoked the law (NOT the law's return fire) — drives dispatch
      spawnTimer: 0,
      witnesses: [],

      witnessedAct(x, y, type, amount) {
        // count nearby mortal witnesses
        let w = 0;
        for (const n of game.npcs) {
          if (n.dead || n.ally) continue;
          if (n.faction !== 'civ' && n.faction !== 'gang' && n.faction !== 'police' && n.faction !== 'inquis') continue;
          if (U.dist(x, y, n.x, n.y) < 260 && !game.player.cloaked) w++;
        }
        // some acts always generate heat (gunfire, explosions); feeding only if witnessed
        const always = type === 'kill' || type === 'explosion' || type === 'body';
        if (w <= 0 && !always) return;
        // gentle escalation: a single crime in a crowd tops out around ~1.5 heat (2 stars), not 5
        let gain = Math.min(1.5, amount * (0.3 + Math.min(0.7, w * 0.12)));
        if (VAMP.Domains) gain *= VAMP.Domains.heatMult(game, x, y);   // your turf shields you
        this.add(gain);
        if (VAMP.Domains && (type === 'kill' || type === 'panic')) VAMP.Domains.raiseTerror(game, x, y, 0.04);
        this.lastCrimeT = game.time; this.lastProvokeT = game.time;
        this.lastSeenX = x; this.lastSeenY = y;   // the law knows WHERE the crime happened — they search here
      },
      // Only the PLAYER's gunshots raise the PLAYER's wanted level. The law shooting back at you is
      // NOT your crime — counting it kept heat pinned at max and the dispatch alive forever (you could
      // never escape). NPC/gang gunfire is ambient and draws no Heat onto you.
      gunfire(x, y, byPlayer) {
        if (!byPlayer) return;
        let w = 0;
        for (const n of game.npcs) { if (!n.dead && (n.faction === 'civ' || n.faction === 'police') && U.dist(x, y, n.x, n.y) < 320) w++; }
        if (w > 0) { this.add(0.12); this.lastCrimeT = game.time; this.lastProvokeT = game.time; this.lastSeenX = x; this.lastSeenY = y; }
      },
      combatNear(x, y) { this.witnessedAct(x, y, 'combat', 0.5); },

      add(v) {
        const before = this.stars;
        this.heat = U.clamp(this.heat + v, 0, 6.0);
        if (this.stars > before) {
          if (VAMP.UI) VAMP.UI.notify('Heat rises to ' + this.stars + (this.stars >= 5 ? ' — the Inquisition comes!' : ' stars'), '#ff6a6a');
          if (VAMP.Audio) VAMP.Audio.play(this.stars >= 5 ? 'frenzy' : 'siren');
        }
        VAMP.bus && VAMP.bus.emit('heat', this.stars);
      },
      reduceHeat(v) {
        const before = this.stars;
        this.heat = U.clamp(this.heat - v, 0, 6);
        if (this.stars < before) VAMP.bus && VAMP.bus.emit('heat', this.stars);
      },
      clearStars(n) {
        if (this.stars >= 5) game._clearedFive = true;
        this.heat = Math.max(0, this.heat - n);
        VAMP.bus && VAMP.bus.emit('heat', this.stars);
      },
      clearAll() { this.heat = 0; this.clearWitnesses(); VAMP.bus && VAMP.bus.emit('heat', 0); },
      clearWitnesses() {
        for (const n of game.npcs) {
          if (!n.dead && (n.faction === 'civ') && (n.state === 'flee')) { n.state = 'wander'; n.panicReported = false; n.fleeT = 0; }
        }
      },

      update(dt, game) {
        const p = game.player;
        const sinceCrime = game.time - this.lastCrimeT;
        // GTA-style WANTED loop: the law is on you while any hunter is NEAR (the search party) and
        // freezes the heat while they can SEE you. You shed heat by leaving the search area AND
        // staying out of sight — duck behind a building, take an alley, hop a car, or cloak.
        let seen = false, nearHunter = false;
        for (const n of game.npcs) {
          if (n.dead || n.ally || !n.hostileToPlayer) continue;
          if (!(n.responder || n.faction === 'police' || n.faction === 'inquis')) continue;
          const dd = U.dist(n.x, n.y, p.x, p.y);
          if (dd < 720) nearHunter = true;
          if (dd < 360 && VAMP.Npc.canSee(n, p, game)) { seen = true; break; }   // (close enough that LOS matters)
        }
        if (seen) { this.lastSeenT = game.time; this.lastSeenX = p.x; this.lastSeenY = p.y; }
        const sinceProvoke = game.time - this.lastProvokeT;
        // you're truly escaping only once you've STOPPED provoking, no hunter is near, and none can see you
        this.evading = this.heat > 0 && !seen && !nearHunter && sinceProvoke >= 6;

        if (this.heat > 0) {
          let decay;
          if (seen) decay = 0;                                              // in their sight: heat holds
          else if (nearHunter) decay = 0.05;                                // still searching nearby: barely cools
          else if (sinceProvoke < 6) decay = 0;                             // just provoked — the law is en route, heat holds
          else decay = 0.30 + Math.min(0.9, (sinceProvoke - 6) * 0.12);     // shaken them: cools fast, faster the longer you stay clear
          if (p.cloaked) decay += 0.20;
          if (p.blood > p.derived.maxBlood * 0.8) decay += 0.04;            // Sated Calm
          if (game.inHaven) decay += 0.8 + (VAMP.Haven ? VAMP.Haven.level(p, 'sanctum') * 0.2 : 0);
          this.reduceHeat(decay * dt);
        }

        // stars cleared -> the manhunt is CALLED OFF: every responder gives up and disperses, so you
        // return to peace instead of being a fugitive forever.
        if (this.stars === 0 && this._wasWanted) {
          this._wasWanted = false;
          let any = false;
          for (const n of game.npcs) {
            if (n.dead || n.ally) continue;
            if (n.responder || ((n.faction === 'police' || n.faction === 'inquis') && n.hostileToPlayer)) {
              n.responder = false; n.hostileToPlayer = false; n.aggro = false; n.state = 'wander'; n.path = null; n.windupT = 0; n._telegraph = null; any = true;
            }
          }
          if (any && VAMP.UI) VAMP.UI.notify("You've lost them — the heat is off.", '#7c9');
        }
        if (this.stars > 0) this._wasWanted = true;

        // dispatch responders: right after a crime, or while they can still see you. If you've broken
        // away (no crime for a bit AND unseen), the hunt stops reinforcing and the heat bleeds out.
        this.spawnTimer -= dt;
        const desired = this.desiredResponders();
        const current = game.npcs.filter((n) => n.responder && !n.dead).length;
        const dispatching = seen || (game.time - this.lastProvokeT < 10);
        if (this.spawnTimer <= 0 && current < desired && this.stars > 0 && dispatching && game.time > (game.safeUntil || 0)) {
          this.spawnResponder(game);
          this.spawnTimer = Math.max(0.8, 2.6 - this.stars * 0.25);
        }
      },
      desiredResponders() {
        const s = this.stars;        // gentler early escalation so low-star play isn't a crossfire wall
        if (s <= 0) return 0;
        if (s === 1) return 1;
        if (s === 2) return 3;
        if (s === 3) return 5;
        if (s === 4) return 7;
        if (s === 5) return 9;
        return 12;
      },
      spawnResponder(game) {
        const s = this.stars;
        let type = 'cop';
        if (s >= 6 && !game.npcs.some((n) => n.type === 'elder' && !n.dead) && Math.random() < 0.5) type = 'elder';
        else if (s >= 5) type = Math.random() < 0.6 ? 'hunter' : 'swat';
        else if (s >= 3) type = Math.random() < 0.5 ? 'swat' : 'cop';
        else type = 'cop';
        // the search centers on your LAST-KNOWN position (crime scene / last sighting), NOT your live
        // position — so once you flee and break sight, reinforcements arrive where you WERE and search
        // there, letting you slip away GTA-style instead of having cops teleport onto you forever.
        const p = game.player;
        const cx = (this.lastSeenX != null) ? this.lastSeenX : (p.inVehicle ? p.inVehicle.x : p.x);
        const cy = (this.lastSeenY != null) ? this.lastSeenY : (p.inVehicle ? p.inVehicle.y : p.y);
        const pos = roadNear(game, cx, cy, 120, 520);
        if (!pos) return;
        const lvl = game.player.level;
        const base = VAMP.Npc.PRESETS[type];
        const hp = Math.round(base.hp * (1 + lvl * 0.05));
        const n = VAMP.Npc.create(game.world, type, pos.x, pos.y, { hp });
        n.responder = true; n.aggro = true; n.state = 'chase'; n.hostileToPlayer = true;
        n.lastSeenX = cx; n.lastSeenY = cy; n.seePlayerT = game.time - 5;   // head to the search area & look, not psychic-track
        if ((type === 'hunter' || type === 'swat') && Math.random() < 0.3) n.sniper = true;   // a long-range marksman among them
        game.addNPC(n);
        // sometimes arrive by car
        if (Math.random() < 0.4 && (type === 'cop' || type === 'swat')) {
          const v = VAMP.Vehicle.create(game.world, 'police', pos.x, pos.y, { siren: true });
          game.addVehicle(v);
        }
      },
    };
    return M;
  }

  function roadNear(game, px, py, minD, maxD) {
    for (let i = 0; i < 60; i++) {
      const a = Math.random() * U.TAU;
      const d = U.lerp(minD, maxD, Math.random());
      const x = px + Math.cos(a) * d, y = py + Math.sin(a) * d;
      if (x < 0 || y < 0 || x > game.world.w || y > game.world.h) continue;
      if (game.world.isRoad(x, y)) return { x, y };
      if (game.world.isWalkable(x, y)) return { x, y };
    }
    return null;
  }

  VAMP.Masquerade = { create };
})();
