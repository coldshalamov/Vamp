/* =========================================================================
 * VAMPIRE CITY — input.js
 * Keyboard + mouse input. Edge detection (pressed/released this frame).
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  const down = {};        // currently held
  const pressed = {};     // went down this frame
  const released = {};    // went up this frame
  const mouse = { x: 0, y: 0, wx: 0, wy: 0, down: false, pressed: false, released: false, rdown: false, rpressed: false, wheel: 0 };

  let canvas = null;
  let anyKeyEdge = false;

  function key(e) { return (e.code || e.key || '').toLowerCase(); }

  function onKeyDown(e) {
    const k = key(e);
    // prevent scroll / browser defaults for game keys
    if (['arrowup', 'arrowdown', 'arrowleft', 'arrowright', 'space', 'tab'].includes(k)) e.preventDefault();
    if (!down[k]) { pressed[k] = true; anyKeyEdge = true; }
    down[k] = true;
  }
  function onKeyUp(e) {
    const k = key(e);
    down[k] = false;
    released[k] = true;
  }
  function onBlur() {
    for (const k in down) down[k] = false;
    mouse.down = false; mouse.rdown = false;
  }

  function updateMousePos(e) {
    if (!canvas) return;
    const r = canvas.getBoundingClientRect();
    // The UI, HUD and camera all work in the game's LOGICAL pixel space (game.w × game.h =
    // CSS pixels). Map the cursor into THAT space — not the device-pixel backing store — so
    // it isn't multiplied by devicePixelRatio (the bug that made menus/aim hypersensitive).
    const G = VAMP.Game;
    const logW = (G && G.w) ? G.w : (canvas.width / (window.devicePixelRatio || 1));
    const logH = (G && G.h) ? G.h : (canvas.height / (window.devicePixelRatio || 1));
    mouse.x = (e.clientX - r.left) * (logW / (r.width || logW));
    mouse.y = (e.clientY - r.top) * (logH / (r.height || logH));
  }

  function init(cnv) {
    canvas = cnv;
    window.addEventListener('keydown', onKeyDown, { passive: false });
    window.addEventListener('keyup', onKeyUp);
    window.addEventListener('blur', onBlur);
    canvas.addEventListener('mousemove', updateMousePos);
    canvas.addEventListener('mousedown', (e) => {
      updateMousePos(e);
      if (e.button === 0) { if (!mouse.down) mouse.pressed = true; mouse.down = true; }
      if (e.button === 2) { if (!mouse.rdown) mouse.rpressed = true; mouse.rdown = true; }
    });
    window.addEventListener('mouseup', (e) => {
      if (e.button === 0) { mouse.down = false; mouse.released = true; }
      if (e.button === 2) { mouse.rdown = false; }
    });
    canvas.addEventListener('contextmenu', (e) => e.preventDefault());
    canvas.addEventListener('wheel', (e) => { mouse.wheel += Math.sign(e.deltaY); e.preventDefault(); }, { passive: false });
  }

  // Map physical keys to logical actions (queried by gameplay code)
  const isDown = (k) => !!down[k];
  const wasPressed = (k) => !!pressed[k];
  const wasReleased = (k) => !!released[k];

  // axis helpers
  function axis(negKeys, posKeys) {
    let v = 0;
    for (const k of negKeys) if (down[k]) { v -= 1; break; }
    for (const k of posKeys) if (down[k]) { v += 1; break; }
    return v;
  }
  function moveX() { return axis(['keya', 'arrowleft'], ['keyd', 'arrowright']); }
  function moveY() { return axis(['keyw', 'arrowup'], ['keys', 'arrowdown']); }

  // call at end of each frame
  function endFrame() {
    for (const k in pressed) pressed[k] = false;
    for (const k in released) released[k] = false;
    mouse.pressed = false; mouse.released = false; mouse.rpressed = false; mouse.wheel = 0;
    anyKeyEdge = false;
  }
  function anyPressed() { return anyKeyEdge || mouse.pressed; }

  VAMP.Input = {
    init, isDown, wasPressed, wasReleased, moveX, moveY, mouse, endFrame, anyPressed,
  };
})();
