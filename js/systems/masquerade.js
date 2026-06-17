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
        const always = type === 'kill' || type === 'explosion';
        if (w <= 0 && !always) return;
        // gentle escalation: a single crime in a crowd tops out around ~1.5 heat (2 stars), not 5
        let gain = Math.min(1.5, amount * (0.3 + Math.min(0.7, w * 0.12)));
        if (VAMP.Domains) gain *= VAMP.Domains.heatMult(game, x, y);   // your turf shields you
        this.add(gain);
        if (VAMP.Domains && (type === 'kill' || type === 'panic')) VAMP.Domains.raiseTerror(game, x, y, 0.04);
        this.lastCrimeT = game.time;
      },
      gunfire(x, y) {
        // heard by nearby; small heat
        let w = 0;
        for (const n of game.npcs) { if (!n.dead && (n.faction === 'civ' || n.faction === 'police') && U.dist(x, y, n.x, n.y) < 320) w++; }
        if (w > 0) { this.add(0.12); this.lastCrimeT = game.time; }
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
        // decay
        const sinceCrime = game.time - this.lastCrimeT;
        if (this.heat > 0) {
          let decay = 0;
          if (sinceCrime > 6) decay = 0.06;
          if (game.player.cloaked) decay += 0.10;
          if (game.inHaven) decay += 0.6 + (VAMP.Haven ? VAMP.Haven.level(game.player, 'sanctum') * 0.2 : 0);
          // no police alive & not seen accelerates
          if (sinceCrime > 12) decay += 0.05;
          this.reduceHeat(decay * dt);
        }
        // spawn responders to match stars (after the opening grace window)
        this.spawnTimer -= dt;
        const desired = this.desiredResponders();
        const current = game.npcs.filter((n) => n.responder && !n.dead).length;
        if (this.spawnTimer <= 0 && current < desired && this.stars > 0 && game.time > (game.safeUntil || 0)) {
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
        const pos = roadNearPlayer(game, 640, 1000);
        if (!pos) return;
        const lvl = game.player.level;
        const base = VAMP.Npc.PRESETS[type];
        const hp = Math.round(base.hp * (1 + lvl * 0.05));
        const n = VAMP.Npc.create(game.world, type, pos.x, pos.y, { hp });
        n.responder = true; n.aggro = true; n.state = 'chase'; n.hostileToPlayer = true;
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

  function roadNearPlayer(game, minD, maxD) {
    const p = game.player;
    const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
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
