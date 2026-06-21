/* =========================================================================
 * VAMPIRE CITY — loop.js
 * Fixed-timestep update with accumulator + variable render.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  function Loop(opts) {
    const maxStep = opts.maxStep || 0.04;  // clamp dt so physics stays stable (>=25 sim fps)
    const maxFrame = opts.maxFrame || 0.25;
    const update = opts.update;            // (dt)
    const render = opts.render;            // (alpha, frameDt)
    let last = 0, running = false, raf = 0;
    let fps = 60, fpsAcc = 0, fpsCount = 0, fpsTimer = 0;
    // DPR (HiDPI) handling (#1): back the canvas with device pixels and scale the
    // 2d context once per frame so all draws (HUD text, world) stay crisp. The
    // rest of the code keeps working in CSS pixels — they never see the scaling.
    let dpr = 1;
    function applyDPR(canvas) {
      if (!canvas) return;
      dpr = Math.max(1, Math.min(3, window.devicePixelRatio || 1));
      const w = Math.round((window.innerWidth || 1280));
      const h = Math.round((window.innerHeight || 720));
      if (canvas.width !== w * dpr || canvas.height !== h * dpr) { canvas.width = w * dpr; canvas.height = h * dpr; }
      canvas.style.width = w + 'px'; canvas.style.height = h + 'px';
    }

    function frame(t) {
      if (!running) return;
      raf = requestAnimationFrame(frame);
      if (!last) last = t;
      let dt = (t - last) / 1000;
      last = t;
      if (dt > maxFrame) dt = maxFrame; // clamp after tab unfocus
      // single update per rendered frame -> input edges consumed exactly once
      update(Math.min(dt, maxStep));

      // DPR: set backing store + context scale so render() draws crisp in CSS px
      const canvas = opts.canvas;
      applyDPR(canvas);
      const ctx = canvas && canvas.getContext('2d');
      if (ctx) {
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        // inform the game of the current CSS-pixel viewport (it reads w/h from itself,
        // but render() receives a fresh clearRect baseline here)
      }
      render(1, dt);

      // fps meter
      fpsTimer += dt; fpsAcc += 1 / Math.max(dt, 1e-4); fpsCount++;
      if (fpsTimer >= 0.5) { fps = Math.round(fpsAcc / fpsCount); fpsTimer = 0; fpsAcc = 0; fpsCount = 0; }
    }

    return {
      start() { if (running) return; running = true; last = 0; raf = requestAnimationFrame(frame); },
      stop() { running = false; cancelAnimationFrame(raf); },
      get fps() { return fps; },
      get running() { return running; },
    };
  }

  VAMP.Loop = Loop;
})();
