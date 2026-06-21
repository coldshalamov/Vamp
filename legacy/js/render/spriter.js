/* =========================================================================
 * VAMPIRE CITY — render/spriter.js
 * Sheet-based sprite animation: dir × frame slicing with drawKey fallback.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  const sheets = {};
  const meta = {};
  const tintCache = {};

  function register(key, canvas, opts) {
    if (!canvas) return;
    opts = opts || {};
    const cols = opts.cols || 1;
    const rows = opts.rows || 1;
    const fw = Math.max(1, Math.floor(canvas.width / cols));
    const fh = Math.max(1, Math.floor(canvas.height / rows));
    const frames = [];
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const fc = VAMP.Assets.makeCanvas(fw, fh);
        const g = fc.getContext('2d');
        g.drawImage(canvas, c * fw, r * fh, fw, fh, 0, 0, fw, fh);
        frames.push(fc);
      }
    }
    sheets[key] = { frames, fw, fh, cols, rows, dirs: opts.dirs || cols };
    meta[key] = opts;
  }

  function has(key) { return !!sheets[key]; }

  function frameIndex(key, dir, frame) {
    const s = sheets[key];
    if (!s) return 0;
    const d = ((dir % s.dirs) + s.dirs) % s.dirs;
    const f = Math.max(0, frame | 0) % Math.max(1, Math.floor(s.frames.length / s.dirs));
    return d * Math.floor(s.frames.length / s.dirs) + f;
  }

  function getFrame(key, dir, frame) {
    const s = sheets[key];
    if (!s) return null;
    return s.frames[frameIndex(key, dir, frame)] || s.frames[0];
  }

  function draw(ctx, key, x, y, opts) {
    opts = opts || {};
    const fr = getFrame(key, opts.dir || 0, opts.frame || 0);
    if (!fr || !ctx) {
      if (opts.fallbackKey && VAMP.Assets) return VAMP.Assets.drawKey(ctx, opts.fallbackKey, x, y, opts);
      return false;
    }
    const s = sheets[key];
    const scale = opts.scale != null ? opts.scale : 1;
    const dw = (opts.w != null ? opts.w : s.fw * scale);
    const dh = (opts.h != null ? opts.h : s.fh * scale);
    const ax = opts.ax != null ? opts.ax : 0.5;
    const ay = opts.ay != null ? opts.ay : 0.5;
    ctx.save();
    if (opts.alpha != null) ctx.globalAlpha = opts.alpha;
    ctx.imageSmoothingEnabled = opts.smooth === true;
    let img = fr;
    if (opts.tint) {
      const tk = key + ':' + opts.dir + ':' + opts.frame + ':' + opts.tint;
      if (tintCache[tk]) img = tintCache[tk];
      else {
        const w = fr.width, h = fr.height;
        const c = VAMP.Assets.makeCanvas(w, h);
        const g = c.getContext('2d');
        g.drawImage(fr, 0, 0);
        g.globalCompositeOperation = 'multiply';
        g.fillStyle = opts.tint; g.fillRect(0, 0, w, h);
        g.globalCompositeOperation = 'destination-in';
        g.drawImage(fr, 0, 0);
        tintCache[tk] = c;
        img = c;
      }
    }
    if (opts.rotate) {
      ctx.translate(x, y); ctx.rotate(opts.rotate);
      ctx.drawImage(img, -dw * ax, -dh * ay, dw, dh);
    } else {
      ctx.drawImage(img, x - dw * ax, y - dh * ay, dw, dh);
    }
    ctx.restore();
    return true;
  }

  function walkFrame(time, speed, frames) {
    frames = frames || 4;
    return Math.floor((time * speed) % frames);
  }

  function dirFromAngle(angle) {
    return VAMP.Assets ? VAMP.Assets.facingToOctant(angle) : Math.round(((angle % U.TAU) + U.TAU) % U.TAU / (U.TAU / 8)) % 8;
  }

  VAMP.Spriter = { register, has, getFrame, draw, walkFrame, dirFromAngle, sheets };
})();