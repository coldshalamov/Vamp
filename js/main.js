/* =========================================================================
 * VAMPIRE CITY — main.js
 * Bootstrap: init game, start the loop, wire autosave & audio resume.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = window.VAMP;

  function boot() {
    const canvas = document.getElementById('game');
    if (!canvas) { console.error('no canvas'); return; }
    try {
      VAMP.Game.init(canvas);
    } catch (e) {
      document.body.innerHTML = '<pre style="color:#f88;padding:20px;font:14px monospace">Failed to start: ' + (e && e.stack || e) + '</pre>';
      return;
    }
    VAMP.Game.mode = 'title';

    const loop = VAMP.Loop({
      canvas,
      maxStep: 0.04,
      update: (dt) => {
        try { VAMP.Game.update(dt); VAMP.UI && VAMP.UI.tweens && VAMP.UI.tweens.update(dt); }
        catch (e) { console.error('update error', e); VAMP.UI && VAMP.UI.notify('Error: ' + e.message, '#f55'); }
      },
      render: () => {
        try { VAMP.Game.render(1); }
        catch (e) { console.error('render error', e); }
      },
    });
    loop.start();
    window.VAMP_LOOP = loop;

    // autosave every 90s while playing
    setInterval(() => { if (VAMP.Game.mode === 'play') VAMP.Save.save(VAMP.Game); }, 90000);

    // persist on unload
    window.addEventListener('beforeunload', () => {
      try { VAMP.Save.saveSettings(VAMP.Game.vol); if (VAMP.Game.mode === 'play') VAMP.Save.save(VAMP.Game); } catch (e) {}
    });

    // #24 — auto-pause + save when the tab is hidden (prevents death-by-afk at dawn)
    document.addEventListener('visibilitychange', () => {
      if (document.hidden && VAMP.Game.mode === 'play') {
        try { VAMP.Save.save(VAMP.Game); } catch (e) {}
        if (!VAMP.Menus.isOpen()) VAMP.Menus.openScreen('pause');
      }
    });

    // resume audio on first gesture
    const resume = () => { try { VAMP.Audio.resume(); } catch (e) {} };
    window.addEventListener('pointerdown', resume);
    window.addEventListener('keydown', resume);

    // hide splash once bitmap assets finish (or after timeout)
    const splash = document.getElementById('splash');
    const hideSplash = () => { if (splash) splash.style.display = 'none'; };
    if (VAMP.Assets && VAMP.Assets.ready) hideSplash();
    else setTimeout(hideSplash, VAMP.Assets && VAMP.Assets.loadTotal ? 8000 : 1200);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
