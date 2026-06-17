/* =========================================================================
 * VAMPIRE CITY — ui/fx.js
 * Particles, floating combat text, rings, beams, after-images, blood decals,
 * and full-screen flashes. World-space and screen-space passes.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  const particles = [];
  const numbers = [];
  const rings = [];
  const beams = [];
  const afters = [];
  const decals = [];
  const pools = [];                 // persistent blood POOLS (grow, stain, capped) — separate from transient decals
  const POOL_CAP = 120;
  let flash = null;
  const MAXP = 700;

  function push(arr, o) { if (arr.length < MAXP) arr.push(o); }

  const FX = {
    clear() { particles.length = 0; numbers.length = 0; rings.length = 0; beams.length = 0; afters.length = 0; decals.length = 0; pools.length = 0; flash = null; },

    number(x, y, text, color, opts) {
      opts = opts || {};
      push(numbers, { x: x + (Math.random() - 0.5) * 8, y, vy: -38, life: opts.small ? 0.6 : 0.9, max: opts.small ? 0.6 : 0.9, text: '' + text, color: color || '#fff', crit: opts.crit, small: opts.small });
    },
    blood(x, y, count) {
      count = count || 8;
      for (let i = 0; i < count; i++) {
        const a = Math.random() * U.TAU, s = Math.random() * 80 + 20;
        // #3 — gravity + size variance so blood arcs and pools naturally
        push(particles, { x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: 0.5 + Math.random() * 0.4, max: 0.9, color: Math.random() < 0.7 ? '#a00010' : '#6a0010', size: 1.5 + Math.random() * 2.5, drag: 0.86, gravity: 60, blend: 'normal' });
      }
      if (count >= 10 && decals.length < 200) decals.push({ x, y, r: 6 + Math.random() * 8, life: 18, max: 18, color: 'rgba(70,0,8,0.5)', splat: (Math.random() * 3) | 0 });
    },
    spark(x, y, color, count) {
      count = count || 5;
      for (let i = 0; i < count; i++) {
        const a = Math.random() * U.TAU, s = Math.random() * 120 + 40;
        // #3 — sparks are additive (glowy), with size variance + slight gravity
        push(particles, { x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: 0.3 + Math.random() * 0.3, max: 0.6, color: color || '#fb3', size: 1 + Math.random() * 2, drag: 0.8, gravity: 30, blend: 'add' });
      }
    },
    hit(x, y, color) {
      this.spark(x, y, color || '#d33', 5);
    },
    heal(x, y) {
      for (let i = 0; i < 10; i++) push(particles, { x: x + (Math.random() - 0.5) * 20, y: y + 10, vx: (Math.random() - 0.5) * 20, vy: -40 - Math.random() * 30, life: 0.6 + Math.random() * 0.4, max: 1, color: '#5aff8c', size: 2, drag: 0.95, blend: 'add' });
    },
    // a persistent, growing, staining blood POOL. Nearby blood MERGES into an
    // existing pool (so we honour the cap and it reads as spreading), grows
    // toward maxR, and slowly dries (#3 environmental storytelling).
    bloodPool(x, y, amount) {
      amount = amount || 1;
      for (const p of pools) {
        const dx = p.x - x, dy = p.y - y;
        if (dx * dx + dy * dy < p.r * p.r) { p.maxR = Math.min(46, p.maxR + amount * 0.5); p.grow = Math.max(p.grow, 0.8); p.stain = Math.min(1, p.stain + 0.04); return; }
      }
      if (pools.length >= POOL_CAP) pools.shift();   // evict oldest (FIFO)
      pools.push({ x, y, r: 3 + amount * 0.4, maxR: 9 + amount * 1.6, stain: 0, grow: 1.1 });
      this.blood(x, y, 8);   // a burst of arcing droplets to sell the spray
    },
    ring(x, y, r, color) { push(rings, { x, y, r: 4, maxR: r, life: 0.4, max: 0.4, color: color || '#fff', width: 4 }); },
    shock(x, y, r) { push(rings, { x, y, r: 4, maxR: r, life: 0.5, max: 0.5, color: 'rgba(255,255,255,0.5)', width: 6 }); },
    beam(x1, y1, x2, y2, color) { push(beams, { x1, y1, x2, y2, life: 0.18, max: 0.18, color: color || '#fff' }); },
    slash(x, y, angle, reach) {
      push(rings, { x: x + Math.cos(angle) * reach * 0.4, y: y + Math.sin(angle) * reach * 0.4, r: reach * 0.3, maxR: reach * 0.7, life: 0.2, max: 0.2, color: 'rgba(255,255,255,0.5)', width: 3, arc: angle });
      this.spark(x + Math.cos(angle) * reach * 0.6, y + Math.sin(angle) * reach * 0.6, '#fff', 3);
    },
    afterimage(x, y, angle) { push(afters, { x, y, angle, life: 0.3, max: 0.3, color: 'rgba(122,75,255,0.5)' }); },
    dashTrail(x, y, angle) { for (let i = 0; i < 4; i++) push(afters, { x: x - Math.cos(angle) * i * 14, y: y - Math.sin(angle) * i * 14, angle, life: 0.3, max: 0.3, color: 'rgba(122,200,255,0.45)' }); },
    skid(x, y) { if (decals.length < 220) decals.push({ x, y, r: 3, life: 6, max: 6, color: 'rgba(20,20,20,0.4)' }); },
    cloak(x, y) { for (let i = 0; i < 14; i++) { const a = Math.random() * U.TAU; push(particles, { x, y, vx: Math.cos(a) * 60, vy: Math.sin(a) * 60, life: 0.5, max: 0.5, color: 'rgba(140,140,180,0.6)', size: 2, drag: 0.85, blend: 'add' }); } },
    shadow(x, y, r) { push(rings, { x, y, r: 4, maxR: r, life: 0.6, max: 0.6, color: 'rgba(80,40,140,0.6)', width: 8 }); for (let i = 0; i < 12; i++) { const a = Math.random() * U.TAU; push(particles, { x, y, vx: Math.cos(a) * 40, vy: Math.sin(a) * 40, life: 0.6, max: 0.6, color: 'rgba(60,20,110,0.7)', size: 3, drag: 0.9, blend: 'add' }); } },
    explosion(x, y) {
      this.ring(x, y, 90, '#ff7a2a');
      for (let i = 0; i < 24; i++) { const a = Math.random() * U.TAU, s = Math.random() * 200 + 60; push(particles, { x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: 0.5 + Math.random() * 0.4, max: 0.9, color: Math.random() < 0.5 ? '#ff7a2a' : '#ffd24a', size: 2 + Math.random() * 3, drag: 0.85, gravity: 40, blend: 'add' }); }
      this.flash('rgba(255,140,40,0.25)', 0.2);
    },
    flash(color, dur) { flash = { color, t: dur, dur }; },

    update(dt) {
      for (let i = particles.length - 1; i >= 0; i--) {
        const p = particles[i];
        p.life -= dt;
        if (p.life <= 0) { particles.splice(i, 1); continue; }
        p.x += p.vx * dt; p.y += p.vy * dt;
        if (p.gravity) p.vy += p.gravity * dt;   // #3 — arcs for blood/sparks
        if (p.drag) { p.vx *= p.drag; p.vy *= p.drag; }
      }
      for (let i = numbers.length - 1; i >= 0; i--) { const n = numbers[i]; n.life -= dt; n.y += n.vy * dt; n.vy *= 0.92; if (n.life <= 0) numbers.splice(i, 1); }
      for (let i = rings.length - 1; i >= 0; i--) { const r = rings[i]; r.life -= dt; r.r = U.lerp(r.maxR, r.r, 0); if (r.life <= 0) rings.splice(i, 1); }
      for (let i = beams.length - 1; i >= 0; i--) { beams[i].life -= dt; if (beams[i].life <= 0) beams.splice(i, 1); }
      for (let i = afters.length - 1; i >= 0; i--) { afters[i].life -= dt; if (afters[i].life <= 0) afters.splice(i, 1); }
      for (let i = decals.length - 1; i >= 0; i--) { decals[i].life -= dt; if (decals[i].life <= 0) decals.splice(i, 1); }
      // blood pools: grow toward maxR then hold; slowly dry (stain rises over ~90s)
      for (const p of pools) {
        if (p.grow > 0) { p.grow -= dt; p.r = U.lerp(p.maxR, p.r, Math.pow(0.02, dt)); }
        if (p.stain < 1) p.stain = Math.min(1, p.stain + dt * 0.011);
      }
      if (flash) { flash.t -= dt; if (flash.t <= 0) flash = null; }
    },

    renderDecals(ctx, cam) {
      for (const d of decals) {
        if (cam && !cam.inView(d.x, d.y, d.r)) continue;
        ctx.save();
        ctx.translate(d.x, d.y);
        ctx.globalAlpha = U.clamp(d.life / d.max, 0, 1) * 0.65;
        if (d.splat != null) {
          ctx.fillStyle = d.color;
          ctx.rotate(d.splat * 1.2);
          ctx.beginPath(); ctx.ellipse(0, 0, d.r, d.r * 0.72, 0, 0, U.TAU); ctx.fill();
          ctx.beginPath(); ctx.ellipse(d.r * 0.35, -d.r * 0.2, d.r * 0.45, d.r * 0.35, 0, 0, U.TAU); ctx.fill();
        } else {
          ctx.fillStyle = d.color;
          ctx.beginPath(); ctx.arc(0, 0, d.r, 0, U.TAU); ctx.fill();
        }
        ctx.restore();
      }
      ctx.globalAlpha = 1;
    },

    // persistent blood pools — irregular (2 ellipses), view-culled, capped
    renderBloodPools(ctx, cam) {
      for (const p of pools) {
        if (cam && !cam.inView(p.x, p.y, p.r)) continue;
        const a = 0.52 - p.stain * 0.24;
        const red = (40 + (1 - p.stain) * 34) | 0;
        ctx.fillStyle = 'rgba(' + red + ',0,8,' + a + ')';
        ctx.beginPath(); ctx.ellipse(p.x, p.y, p.r, p.r * 0.76, 0, 0, U.TAU); ctx.fill();
        ctx.beginPath(); ctx.ellipse(p.x + p.r * 0.4, p.y - p.r * 0.18, p.r * 0.46, p.r * 0.38, 0, 0, U.TAU); ctx.fill();
      }
      ctx.globalAlpha = 1;
    },

    renderWorld(ctx, cam) {
      // afterimages
      for (const a of afters) {
        const al = a.life / a.max;
        ctx.globalAlpha = al * 0.5;
        ctx.fillStyle = a.color;
        ctx.beginPath(); ctx.arc(a.x, a.y, 10, 0, U.TAU); ctx.fill();
      }
      ctx.globalAlpha = 1;
      // rings
      for (const r of rings) {
        const t = r.life / r.max;
        const rr = U.lerp(r.maxR, r.r0 || r.r, t);
        ctx.globalAlpha = t;
        ctx.strokeStyle = r.color; ctx.lineWidth = r.width;
        ctx.beginPath();
        if (r.arc != null) ctx.arc(r.x, r.y, r.maxR * (1 - t * 0.4), r.arc - 0.9, r.arc + 0.9);
        else ctx.arc(r.x, r.y, r.maxR * (1 - t), 0, U.TAU);
        ctx.stroke();
      }
      ctx.globalAlpha = 1;
      // beams
      for (const bm of beams) {
        ctx.globalAlpha = bm.life / bm.max;
        ctx.strokeStyle = bm.color; ctx.lineWidth = 3;
        ctx.beginPath(); ctx.moveTo(bm.x1, bm.y1); ctx.lineTo(bm.x2, bm.y2); ctx.stroke();
      }
      ctx.globalAlpha = 1;
      // #3 — particles: separate additive (glow) and normal (smoke/blood) passes
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';   // additive: sparks, magic, blood-mist glow
      for (const p of particles) {
        if (p.blend === 'normal') continue;
        ctx.globalAlpha = U.clamp(p.life / p.max, 0, 1);
        ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.size, 0, U.TAU); ctx.fill();
      }
      ctx.restore();
      ctx.save();
      ctx.globalCompositeOperation = 'source-over'; // normal: blood, smoke, dust
      for (const p of particles) {
        if (p.blend === 'add') continue;
        ctx.globalAlpha = U.clamp(p.life / p.max, 0, 1);
        ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.size, 0, U.TAU); ctx.fill();
      }
      ctx.restore();
      ctx.globalAlpha = 1;
      // numbers (world space)
      ctx.textAlign = 'center';
      for (const n of numbers) {
        ctx.globalAlpha = U.clamp(n.life / n.max, 0, 1);
        const sz = n.crit ? 18 : n.small ? 10 : 13;
        ctx.font = `bold ${sz}px ${'Verdana, sans-serif'}`;
        ctx.fillStyle = '#000'; ctx.fillText(n.text, n.x + 1, n.y + 1);
        ctx.fillStyle = n.color; ctx.fillText(n.text, n.x, n.y);
      }
      ctx.globalAlpha = 1; ctx.textAlign = 'left';
    },

    renderScreen(ctx, w, h) {
      if (flash) {
        ctx.globalAlpha = U.clamp(flash.t / flash.dur, 0, 1);
        ctx.fillStyle = flash.color;
        ctx.fillRect(0, 0, w, h);
        ctx.globalAlpha = 1;
      }
    },
    count() { return particles.length; },
    poolCount() { return pools.length; },
  };

  VAMP.FX = FX;
})();
