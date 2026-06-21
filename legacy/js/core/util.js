/* =========================================================================
 * VAMPIRE CITY — util.js
 * Foundational math, RNG, geometry, color and helper utilities.
 * Pure, dependency-free. Attaches to window.VAMP.Util.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  const TAU = Math.PI * 2;

  // ---- Seeded RNG (mulberry32) — deterministic, savable ----
  function makeRNG(seed) {
    let a = (seed >>> 0) || 1;
    const rng = function () {
      a |= 0; a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
    rng.seed = function (s) { a = (s >>> 0) || 1; };
    rng.int = function (min, max) { return Math.floor(rng() * (max - min + 1)) + min; };
    rng.range = function (min, max) { return rng() * (max - min) + min; };
    rng.pick = function (arr) { return arr[Math.floor(rng() * arr.length)]; };
    rng.chance = function (p) { return rng() < p; };
    rng.sign = function () { return rng() < 0.5 ? -1 : 1; };
    rng.shuffle = function (arr) {
      for (let i = arr.length - 1; i > 0; i--) {
        const j = Math.floor(rng() * (i + 1));
        const tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp;
      }
      return arr;
    };
    return rng;
  }

  // ---- Scalar math ----
  const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);
  const range = (min, max) => Math.random() * (max - min) + min;
  const randInt = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
  const pick = (arr) => arr[(Math.random() * arr.length) | 0];
  const lerp = (a, b, t) => a + (b - a) * t;
  const invLerp = (a, b, v) => (b === a ? 0 : (v - a) / (b - a));
  const smoothstep = (t) => { t = clamp(t, 0, 1); return t * t * (3 - 2 * t); };
  const approach = (cur, target, step) => {
    if (cur < target) return Math.min(cur + step, target);
    if (cur > target) return Math.max(cur - step, target);
    return cur;
  };
  const sign = (x) => (x > 0 ? 1 : x < 0 ? -1 : 0);
  const round2 = (x) => Math.round(x * 100) / 100;

  // ---- Angles ----
  const wrapAngle = (a) => {
    a = a % TAU;
    if (a < -Math.PI) a += TAU;
    else if (a > Math.PI) a -= TAU;
    return a;
  };
  const angleLerp = (a, b, t) => a + wrapAngle(b - a) * t;
  const angleTo = (x1, y1, x2, y2) => Math.atan2(y2 - y1, x2 - x1);

  // ---- Vector helpers (plain {x,y}) ----
  const dist = (ax, ay, bx, by) => Math.hypot(ax - bx, ay - by);
  const dist2 = (ax, ay, bx, by) => { const dx = ax - bx, dy = ay - by; return dx * dx + dy * dy; };
  const len = (x, y) => Math.hypot(x, y);
  function norm(x, y) {
    const l = Math.hypot(x, y) || 1;
    return { x: x / l, y: y / l };
  }
  const dot = (ax, ay, bx, by) => ax * bx + ay * by;

  // ---- AABB / collision ----
  function aabb(ax, ay, aw, ah, bx, by, bw, bh) {
    return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
  }
  function circleRect(cx, cy, r, rx, ry, rw, rh) {
    const nx = clamp(cx, rx, rx + rw);
    const ny = clamp(cy, ry, ry + rh);
    return dist2(cx, cy, nx, ny) < r * r;
  }
  // Resolve circle out of rect, returns push vector or null
  function resolveCircleRect(cx, cy, r, rx, ry, rw, rh) {
    const nx = clamp(cx, rx, rx + rw);
    const ny = clamp(cy, ry, ry + rh);
    let dx = cx - nx, dy = cy - ny;
    const d2 = dx * dx + dy * dy;
    if (d2 >= r * r) return null;
    if (d2 > 0.0001) {
      const d = Math.sqrt(d2);
      const push = r - d;
      return { x: (dx / d) * push, y: (dy / d) * push };
    }
    // center inside rect: push out along smallest penetration axis
    const left = cx - rx, right = rx + rw - cx, top = cy - ry, bottom = ry + rh - cy;
    const m = Math.min(left, right, top, bottom);
    if (m === left) return { x: -(left + r), y: 0 };
    if (m === right) return { x: right + r, y: 0 };
    if (m === top) return { x: 0, y: -(top + r) };
    return { x: 0, y: bottom + r };
  }
  // Segment vs circle (for bullets / line of sight)
  function segCircle(x1, y1, x2, y2, cx, cy, r) {
    const dx = x2 - x1, dy = y2 - y1;
    const fx = x1 - cx, fy = y1 - cy;
    const a = dx * dx + dy * dy;
    const b = 2 * (fx * dx + fy * dy);
    const c = fx * fx + fy * fy - r * r;
    let disc = b * b - 4 * a * c;
    if (disc < 0) return false;
    disc = Math.sqrt(disc);
    const t1 = (-b - disc) / (2 * a);
    const t2 = (-b + disc) / (2 * a);
    return (t1 >= 0 && t1 <= 1) || (t2 >= 0 && t2 <= 1);
  }

  // ---- Easing ----
  const ease = {
    inQuad: (t) => t * t,
    outQuad: (t) => t * (2 - t),
    inOutQuad: (t) => (t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t),
    inCubic: (t) => t * t * t,
    outCubic: (t) => 1 - Math.pow(1 - t, 3),
    inOutCubic: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
    outQuart: (t) => 1 - Math.pow(1 - t, 4),
    outExpo: (t) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t)),
    outBack: (t) => { const c = 1.70158; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); },
    outElastic: (t) => {
      if (t === 0 || t === 1) return t;
      const p = 0.3;
      return Math.pow(2, -10 * t) * Math.sin(((t - p / 4) * TAU) / p) + 1;
    },
  };

  // ---- Tween manager (#2) ----
  // Frame-rate-independent scalar tweens used by the HUD (money/XP roll-up),
  // banners, floating numbers, and UI element entries. update(dt) each frame.
  function Tweener() {
    const list = [];
    return {
      list,
      // to(obj,'prop', endVal, dur, easeFn, onDone) — animates obj.prop toward endVal
      to(obj, prop, end, dur, easeFn, onDone) {
        const t = { obj, prop, from: obj[prop], end, dur: Math.max(0.001, dur), t: 0, ease: easeFn || ease.outCubic, done: onDone || null };
        list.push(t); return t;
      },
      // set(obj, val) — kill any tween on obj.prop and snap it
      set(obj, prop, val) {
        for (let i = list.length - 1; i >= 0; i--) if (list[i].obj === obj && list[i].prop === prop) list.splice(i, 1);
        obj[prop] = val;
      },
      update(dt) {
        for (let i = list.length - 1; i >= 0; i--) {
          const t = list[i];
          t.t += dt;
          const k = t.t >= t.dur ? 1 : t.ease(t.t / t.dur);
          t.obj[t.prop] = t.from + (t.end - t.from) * k;
          if (k >= 1) { if (t.done) t.done(); list.splice(i, 1); }
        }
      },
      clear() { list.length = 0; },
    };
  }

  // ---- Color helpers ----
  function hsl(h, s, l, a) {
    return a === undefined ? `hsl(${h},${s}%,${l}%)` : `hsla(${h},${s}%,${l}%,${a})`;
  }
  function rgba(r, g, b, a) { return `rgba(${r | 0},${g | 0},${b | 0},${a === undefined ? 1 : a})`; }
  function lerpColor(c1, c2, t) {
    return {
      r: Math.round(lerp(c1.r, c2.r, t)),
      g: Math.round(lerp(c1.g, c2.g, t)),
      b: Math.round(lerp(c1.b, c2.b, t)),
    };
  }
  function shade(hex, amt) {
    // hex like #rrggbb, amt -1..1
    const n = parseInt(hex.slice(1), 16);
    let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
    if (amt >= 0) { r = lerp(r, 255, amt); g = lerp(g, 255, amt); b = lerp(b, 255, amt); }
    else { const a = -amt; r = lerp(r, 0, a); g = lerp(g, 0, a); b = lerp(b, 0, a); }
    return rgba(r, g, b, 1);
  }

  // ---- Misc ----
  const now = () => performance.now();
  function fmt(n) {
    n = Math.round(n);
    if (n >= 1e6) return (n / 1e6).toFixed(1) + 'M';
    if (n >= 1e4) return (n / 1e3).toFixed(1) + 'k';
    return '' + n;
  }
  function pad2(n) { return n < 10 ? '0' + n : '' + n; }
  function deepCopy(o) { return JSON.parse(JSON.stringify(o)); }
  function uid() { return (uid._n = (uid._n || 0) + 1); }

  // simple event emitter
  function Emitter() {
    const map = {};
    return {
      on(ev, fn) { (map[ev] = map[ev] || []).push(fn); return () => this.off(ev, fn); },
      off(ev, fn) { if (map[ev]) map[ev] = map[ev].filter((f) => f !== fn); },
      emit(ev, a, b, c) { if (map[ev]) map[ev].slice().forEach((f) => f(a, b, c)); },
    };
  }

  VAMP.Util = {
    TAU, makeRNG, clamp, range, randInt, pick, lerp, invLerp, smoothstep, approach, sign, round2,
    wrapAngle, angleLerp, angleTo, dist, dist2, len, norm, dot,
    aabb, circleRect, resolveCircleRect, segCircle,
    ease, Tweener, hsl, rgba, lerpColor, shade, now, fmt, pad2, deepCopy, uid, Emitter,
  };
})();
