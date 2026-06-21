/* =========================================================================
 * VAMPIRE CITY — camera.js
 * Follows a target in world space, handles zoom, shake, world<->screen.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  function Camera(viewW, viewH) {
    return {
      x: 0, y: 0,          // world coords at center of view
      zoom: 1,
      targetZoom: 1,
      viewW, viewH,
      shakeMag: 0, shakeT: 0, shakeDur: 0,
      ox: 0, oy: 0,        // shake offset
      dx: 0, dy: 0,        // #19 — last hit direction for directional shake
      punchT: 0, punchAmt: 0,  // #19 — brief zoom-out/in punch
      bounds: null,        // {w,h} world size to clamp inside

      resize(w, h) { this.viewW = w; this.viewH = h; },

      follow(tx, ty, dt, lead) {
        lead = lead || 0;
        const k = 1 - Math.pow(0.001, dt); // smooth follow
        this.x = U.lerp(this.x, tx, k);
        this.y = U.lerp(this.y, ty, k);
        // zoom: target + active punch (punch eases out, additive to target)
        let zoomTarget = this.targetZoom;
        if (this.punchT > 0) {
          this.punchT -= dt;
          const ph = U.clamp(this.punchT / 0.18, 0, 1); // 1 -> 0
          // quick out then settle: zoom dips then recovers
          zoomTarget = this.targetZoom * (1 - this.punchAmt * (1 - U.ease.outCubic(1 - ph)));
        }
        this.zoom = U.lerp(this.zoom, zoomTarget, 1 - Math.pow(0.01, dt));
        // clamp to world bounds
        if (this.bounds) {
          const hw = this.viewW / 2 / this.zoom;
          const hh = this.viewH / 2 / this.zoom;
          if (this.bounds.w > hw * 2) this.x = U.clamp(this.x, hw, this.bounds.w - hw);
          else this.x = this.bounds.w / 2;
          if (this.bounds.h > hh * 2) this.y = U.clamp(this.y, hh, this.bounds.h - hh);
          else this.y = this.bounds.h / 2;
        }
        // #19 — shake decay with a directional bias: offset leans toward the hit
        if (this.shakeT > 0) {
          this.shakeT -= dt;
          const f = Math.max(0, this.shakeT / this.shakeDur);
          const m = this.shakeMag * f * f;
          this.ox = (this.dx * 0.4 + (Math.random() * 2 - 1) * 0.6) * m;
          this.oy = (this.dy * 0.4 + (Math.random() * 2 - 1) * 0.6) * m;
          this.dx *= 0.85; this.dy *= 0.85;   // bias fades so shake randomizes over time
        } else { this.ox = 0; this.oy = 0; }
      },

      snap(tx, ty) { this.x = tx; this.y = ty; },

      // #19 — directional shake: angle biases the jitter toward the impact.
      shake(mag, dur, angle) {
        if (mag > this.shakeMag || this.shakeT <= 0) { this.shakeMag = mag; }
        else this.shakeMag = Math.max(this.shakeMag, mag);
        this.shakeDur = dur; this.shakeT = dur;
        if (angle != null) { this.dx = Math.cos(angle); this.dy = Math.sin(angle); }
      },

      // #19 — punch-zoom: a quick zoom-out/in "thump" for kills, level-ups, etc.
      punch(amt) { this.punchT = 0.18; this.punchAmt = amt || 0.08; },

      // apply transform to a context so subsequent draws are in world space
      apply(ctx) {
        ctx.save();
        ctx.translate(this.viewW / 2, this.viewH / 2);
        ctx.scale(this.zoom, this.zoom);
        ctx.translate(-(this.x + this.ox), -(this.y + this.oy));
      },
      restore(ctx) { ctx.restore(); },

      worldToScreen(wx, wy) {
        return {
          x: (wx - (this.x + this.ox)) * this.zoom + this.viewW / 2,
          y: (wy - (this.y + this.oy)) * this.zoom + this.viewH / 2,
        };
      },
      screenToWorld(sx, sy) {
        return {
          x: (sx - this.viewW / 2) / this.zoom + (this.x + this.ox),
          y: (sy - this.viewH / 2) / this.zoom + (this.y + this.oy),
        };
      },
      // visible world rect (with margin)
      viewRect(margin) {
        margin = margin || 0;
        const hw = this.viewW / 2 / this.zoom + margin;
        const hh = this.viewH / 2 / this.zoom + margin;
        return { x: this.x - hw, y: this.y - hh, w: hw * 2, h: hh * 2 };
      },
      inView(wx, wy, r) {
        const vr = this.viewRect(64);
        return wx + r > vr.x && wx - r < vr.x + vr.w && wy + r > vr.y && wy - r < vr.y + vr.h;
      },
    };
  }

  VAMP.Camera = Camera;
})();
