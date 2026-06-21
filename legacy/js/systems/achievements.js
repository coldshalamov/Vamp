/* =========================================================================
 * VAMPIRE CITY — systems/achievements.js
 * Tracks achievement unlocks and fires celebratory notifications.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  function create(game, savedUnlocked) {
    return {
      unlocked: savedUnlocked || {},
      checkTimer: 0,
      update(dt) {
        this.checkTimer -= dt;
        if (this.checkTimer > 0) return;
        this.checkTimer = 1;
        for (const a of VAMP.Data.ACHIEVEMENTS) {
          if (this.unlocked[a.id]) continue;
          let ok = false;
          try { ok = a.check(game); } catch (e) { ok = false; }
          if (ok) this.unlock(a);
        }
      },
      unlock(a) {
        if (this.unlocked[a.id]) return;
        this.unlocked[a.id] = 1;
        game.player.skillPoints = (game.player.skillPoints || 0) + 1; // reward
        if (VAMP.UI) VAMP.UI.banner('ACHIEVEMENT', a.name + ' — ' + a.desc + '  (+1 Skill Point)', '#ffd24a');
        if (VAMP.Audio) VAMP.Audio.play('win');
      },
      count() { return Object.keys(this.unlocked).length; },
    };
  }

  VAMP.Achievements = { create };
})();
