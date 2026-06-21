/* =========================================================================
 * VAMPIRE CITY — game.js  (VAMP.Game)
 * The orchestrator: world + player + camera + day/night + lighting + POIs +
 * spawning director + all the API methods every system calls.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;
  // money label helper (kept separate so formatters never see '+$' literals)
  function cash(n){ return '$' + Math.round(n); }
  const byY = (a, b) => a.y - b.y;   // hoisted draw-order comparator (no per-frame closure alloc)
  // #11 — per-clan palette used to tint the player sprite (cape + collar + eyes)
  const CLAN_COLORS = {
    brujah: { cape: '#1a0a14', cape2: '#3a1024', collar: '#7a1530', eye: '#ff4040', aura: '#ff5050' },
    gangrel: { cape: '#1a1408', cape2: '#3a2a14', collar: '#5a4020', eye: '#c08020', aura: '#a07030' },
    tremere: { cape: '#0c0a1a', cape2: '#1a1438', collar: '#5a30a0', eye: '#c060ff', aura: '#9040ff' },
    ventrue: { cape: '#0a0e1a', cape2: '#1a2438', collar: '#3040a0', eye: '#80a0ff', aura: '#5070ff' },
    toreador: { cape: '#1a0814', cape2: '#3a1430', collar: '#a03070', eye: '#ff60a0', aura: '#ff4080' },
    nosferatu: { cape: '#0e140e', cape2: '#1c2a1c', collar: '#3a5a3a', eye: '#80ff80', aura: '#60c060' },
    malkavian: { cape: '#140a14', cape2: '#2c1830', collar: '#7030a0', eye: '#ffd040', aura: '#c0a0ff' },
  };
  // ----------------------------------------------------------------
  // drawClanCard — gothic portrait card, all canvas primitives
  //
  // (ctx, x, y, w, h, clanId, name, desc, selected, over, time) → boolean clicked
  //
  // Coordinate system: x,y is top-left of the card rectangle.
  // All art stays inside that box. The clan silhouette is drawn in
  // a local reference frame via ctx.save/translate/restore so the
  // per-clan paths never need to know the absolute position.
  // ----------------------------------------------------------------
  function drawClanCard(ctx, cx, cy, cw, ch, clanId, clanName, clanDesc, selected, over, time) {
    const pal  = CLAN_COLORS[clanId] || CLAN_COLORS.brujah;
    const eye  = pal.eye;
    const aura = pal.aura;
    const cape = pal.cape  || '#111';
    const cape2= pal.cape2 || '#222';
    const col  = pal.collar;
    const m    = VAMP.Input.mouse;
    const clicked = over && m.pressed;

    ctx.save();

    // ---- glow halo behind card (selected or hover) ----------------
    if (selected || over) {
      const glowR = selected ? 28 : 16;
      const grd = ctx.createRadialGradient(cx + cw / 2, cy + ch * 0.38, 4, cx + cw / 2, cy + ch * 0.38, glowR + ch * 0.4);
      grd.addColorStop(0, aura + (selected ? '88' : '44'));
      grd.addColorStop(1, 'transparent');
      ctx.fillStyle = grd;
      ctx.fillRect(cx - 8, cy - 8, cw + 16, ch + 16);
    }

    // ---- gothic pointed-arch card body ----------------------------
    // Path: bottom-left corner clockwise, top forms a pointed arch.
    // Peak is INSIDE the box (ay + cw*0.08) so no art bleeds above cy —
    // layout math stays honest and the spire never stabs the header label.
    const ax = cx, ay = cy;          // anchor top-left
    const midX = ax + cw / 2;
    const archPeakY = ay + cw * 0.08; // tip of pointed arch — well inside the rect
    const sideH = ch * 0.72;          // where the arch shoulders meet the sides

    ctx.beginPath();
    ctx.moveTo(ax, ay + ch);                     // bottom-left
    ctx.lineTo(ax + cw, ay + ch);                // bottom-right
    ctx.lineTo(ax + cw, ay + sideH);             // right shoulder
    // right side of arch: two bezier segments up to peak
    ctx.bezierCurveTo(ax + cw, ay + sideH * 0.3, midX + cw * 0.30, archPeakY + cw * 0.18, midX, archPeakY);
    // left side of arch: mirror
    ctx.bezierCurveTo(midX - cw * 0.30, archPeakY + cw * 0.18, ax, ay + sideH * 0.3, ax, ay + sideH);
    ctx.closePath();

    // card fill — dark gradient, cape colour at base
    const bgGrd = ctx.createLinearGradient(cx, cy, cx, cy + ch);
    bgGrd.addColorStop(0, '#09060f');
    bgGrd.addColorStop(0.55, cape);
    bgGrd.addColorStop(1, cape2);
    ctx.fillStyle = bgGrd;
    ctx.fill();

    // inner highlight edge (very subtle bevel)
    ctx.strokeStyle = 'rgba(255,220,255,0.06)';
    ctx.lineWidth = 1;
    ctx.stroke();

    // ---- border / frame --------------------------------------------
    ctx.lineWidth = selected ? 2.2 : (over ? 1.6 : 1.1);
    ctx.strokeStyle = selected ? aura : (over ? col : 'rgba(160,120,150,0.4)');
    ctx.stroke();   // re-stroke the arch path already in effect

    // thin inner frame inset by 3px (gothic double-line look)
    if (selected || over) {
      ctx.beginPath();
      const fi = 3;
      const iax = ax + fi, iay = ay, imidX = iax + (cw - fi * 2) / 2;
      const isideH = sideH - fi * 0.4;
      const iarchPeakY = archPeakY + fi * 0.5;
      ctx.moveTo(iax, ay + ch - fi);
      ctx.lineTo(iax + (cw - fi * 2), ay + ch - fi);
      ctx.lineTo(iax + (cw - fi * 2), iay + isideH);
      ctx.bezierCurveTo(iax + (cw - fi * 2), iay + isideH * 0.3, imidX + (cw - fi * 2) * 0.30, iarchPeakY + (cw - fi * 2) * 0.18, imidX, iarchPeakY);
      ctx.bezierCurveTo(imidX - (cw - fi * 2) * 0.30, iarchPeakY + (cw - fi * 2) * 0.18, iax, iay + isideH * 0.3, iax, iay + isideH);
      ctx.closePath();
      ctx.strokeStyle = eye + (selected ? '55' : '28');
      ctx.lineWidth = 0.7;
      ctx.stroke();
    }

    // ---- clip to card shape so silhouette can't bleed out ---------
    // Re-draw the arch path then clip
    ctx.beginPath();
    ctx.moveTo(ax, ay + ch);
    ctx.lineTo(ax + cw, ay + ch);
    ctx.lineTo(ax + cw, ay + sideH);
    ctx.bezierCurveTo(ax + cw, ay + sideH * 0.3, midX + cw * 0.30, archPeakY + cw * 0.18, midX, archPeakY);
    ctx.bezierCurveTo(midX - cw * 0.30, archPeakY + cw * 0.18, ax, ay + sideH * 0.3, ax, ay + sideH);
    ctx.closePath();
    ctx.clip();

    // ---- figure baseline + centre --------------------------------
    // All silhouettes are drawn in a local box centred at (cx+cw/2).
    // Baseline is at cy + ch*0.82. Head/body are above that.
    // R is "reference unit" ≈ half card width for scaling poses.
    const fx = cx + cw / 2;   // figure horizontal centre
    const fb = cy + ch * 0.82; // figure bottom / feet
    const R  = cw * 0.38;      // reference unit

    // --- helper: filled bezier shape using arrays of cubic segments ---
    function body(segs, fill, stroke, sw) {
      ctx.beginPath();
      ctx.moveTo(segs[0][0], segs[0][1]);
      for (let s = 1; s < segs.length; s++) {
        const sg = segs[s];
        if (sg.length === 2) ctx.lineTo(sg[0], sg[1]);
        else ctx.bezierCurveTo(sg[0], sg[1], sg[2], sg[3], sg[4], sg[5]);
      }
      ctx.closePath();
      if (fill) { ctx.fillStyle = fill; ctx.fill(); }
      if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = sw || 1; ctx.stroke(); }
    }
    // helper: glowing circle (eye / orb)
    function glowDot(gx, gy, r, clr) {
      const grd = ctx.createRadialGradient(gx, gy, 0, gx, gy, r * 2.2);
      grd.addColorStop(0, '#fff');
      grd.addColorStop(0.25, clr);
      grd.addColorStop(1, 'transparent');
      ctx.fillStyle = grd;
      ctx.beginPath();
      ctx.arc(gx, gy, r * 2.2, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = clr;
      ctx.beginPath();
      ctx.arc(gx, gy, r, 0, Math.PI * 2);
      ctx.fill();
    }

    // ====================== PER-CLAN SILHOUETTES ====================
    // idle sway: subtle figure animation driven by time
    const sway = Math.sin(time * 1.2 + clanId.charCodeAt(0) * 0.7) * 1.8;
    const breathe = Math.sin(time * 0.9 + clanId.charCodeAt(0) * 0.4) * 0.8;
    ctx.save();
    ctx.translate(sway, breathe);

    if (clanId === 'brujah') {
      // Muscular punk brawler — wide stance, one fist raised, spiked collar
      // body: wide torso, thick legs
      const hy = fb - R * 2.1; // head centre y
      // cape/cloak behind
      body([
        [fx - R * 0.55, fb],
        [fx - R * 0.65, hy + R * 0.3],
        [fx - R * 0.6, hy, fx, hy - R * 0.15, fx + R * 0.6, hy],
        [fx + R * 0.65, hy + R * 0.3],
        [fx + R * 0.55, fb],
      ], cape, null);
      // torso — wide, aggressive
      body([
        [fx - R * 0.42, fb - R * 0.05],
        [fx - R * 0.46, fb - R * 1.0],
        [fx - R * 0.38, fb - R * 1.6],
        [fx,            fb - R * 1.7],
        [fx + R * 0.38, fb - R * 1.6],
        [fx + R * 0.46, fb - R * 1.0],
        [fx + R * 0.42, fb - R * 0.05],
      ], col, null);
      // raised fist (right arm punching upward)
      body([
        [fx + R * 0.46, fb - R * 1.3],
        [fx + R * 0.66, fb - R * 1.6],
        [fx + R * 0.78, fb - R * 1.4, fx + R * 0.88, fb - R * 1.65, fx + R * 0.82, fb - R * 1.82],
        [fx + R * 0.70, fb - R * 1.78, fx + R * 0.60, fb - R * 1.65, fx + R * 0.58, fb - R * 1.55],
      ], eye + 'cc', null);
      // head — angular jaw
      body([
        [fx - R * 0.22, hy + R * 0.24],
        [fx - R * 0.26, hy - R * 0.10],
        [fx - R * 0.18, hy - R * 0.32, fx, hy - R * 0.38, fx + R * 0.18, hy - R * 0.32],
        [fx + R * 0.26, hy - R * 0.10],
        [fx + R * 0.22, hy + R * 0.24],
        [fx + R * 0.12, hy + R * 0.30, fx - R * 0.12, hy + R * 0.30],
      ], '#c8b4a0', null);
      glowDot(fx - R * 0.08, hy - R * 0.06, R * 0.055, eye);
      glowDot(fx + R * 0.08, hy - R * 0.06, R * 0.055, eye);
      // spiked collar studs
      for (let s = -2; s <= 2; s++) {
        const sx2 = fx + s * R * 0.11, sy2 = fb - R * 1.62;
        ctx.fillStyle = '#ddd';
        ctx.beginPath();
        ctx.moveTo(sx2 - R * 0.04, sy2);
        ctx.lineTo(sx2, sy2 - R * 0.1);
        ctx.lineTo(sx2 + R * 0.04, sy2);
        ctx.fill();
      }

    } else if (clanId === 'gangrel') {
      // Hunched feral creature — crouching, arms dangling, huge claw hands
      const hy = fb - R * 1.5;
      // cape shreds trailing behind
      body([
        [fx - R * 0.3, fb],
        [fx - R * 0.55, hy + R * 0.6],
        [fx - R * 0.72, hy + R * 0.2, fx - R * 0.6, hy, fx - R * 0.45, hy - R * 0.1],
        [fx,            hy - R * 0.2],
        [fx + R * 0.45, hy - R * 0.1],
        [fx + R * 0.72, hy, fx + R * 0.55, hy + R * 0.6],
        [fx + R * 0.3, fb],
      ], cape, null);
      // crouched body — hunched over, asymmetric
      body([
        [fx - R * 0.35, fb],
        [fx - R * 0.50, fb - R * 0.9],
        [fx - R * 0.60, fb - R * 1.3, fx - R * 0.40, fb - R * 1.55, fx - R * 0.05, fb - R * 1.5],
        [fx + R * 0.35, fb - R * 1.48],
        [fx + R * 0.48, fb - R * 1.0],
        [fx + R * 0.35, fb],
      ], col, null);
      // left claw arm hanging low (knuckles near ground)
      body([
        [fx - R * 0.50, fb - R * 0.9],
        [fx - R * 0.75, fb - R * 0.3],
        [fx - R * 0.72, fb + R * 0.04],
      ], cape2, col, 1.4);
      // claw tips on left hand
      for (let c2 = 0; c2 < 4; c2++) {
        const cx2 = fx - R * 0.78 + c2 * R * 0.08;
        const cy2 = fb + R * 0.04 - c2 * R * 0.03;
        ctx.beginPath();
        ctx.moveTo(cx2, cy2);
        ctx.lineTo(cx2 - R * 0.035, cy2 + R * 0.18);
        ctx.lineTo(cx2 + R * 0.015, cy2 + R * 0.16);
        ctx.strokeStyle = eye; ctx.lineWidth = 1.5; ctx.stroke();
      }
      // right claw raised slightly
      body([
        [fx + R * 0.48, fb - R * 1.0],
        [fx + R * 0.70, fb - R * 0.50],
        [fx + R * 0.68, fb - R * 0.14],
      ], cape2, col, 1.4);
      for (let c2 = 0; c2 < 4; c2++) {
        const cx2 = fx + R * 0.62 + c2 * R * 0.07;
        const cy2 = fb - R * 0.14 + c2 * R * 0.02;
        ctx.beginPath();
        ctx.moveTo(cx2, cy2);
        ctx.lineTo(cx2 + R * 0.03, cy2 + R * 0.18);
        ctx.lineTo(cx2 + R * 0.07, cy2 + R * 0.16);
        ctx.strokeStyle = eye; ctx.lineWidth = 1.5; ctx.stroke();
      }
      // feral head — pushed forward / down
      body([
        [fx - R * 0.22, hy + R * 0.18],
        [fx - R * 0.28, hy - R * 0.15, fx - R * 0.15, hy - R * 0.35, fx, hy - R * 0.36],
        [fx + R * 0.15, hy - R * 0.35, fx + R * 0.28, hy - R * 0.15, fx + R * 0.22, hy + R * 0.18],
        [fx + R * 0.1, hy + R * 0.28, fx - R * 0.1, hy + R * 0.28],
      ], '#8a6a4a', null);
      // muzzle protrusion
      body([[fx - R * 0.1, hy + R * 0.1], [fx + R * 0.1, hy + R * 0.1], [fx + R * 0.12, hy + R * 0.28], [fx, hy + R * 0.35], [fx - R * 0.12, hy + R * 0.28]], '#6a4a2a', null);
      glowDot(fx - R * 0.09, hy - R * 0.04, R * 0.06, eye);
      glowDot(fx + R * 0.09, hy - R * 0.04, R * 0.06, eye);

    } else if (clanId === 'tremere') {
      // Robed sorcerer — tall narrow figure, one arm extended with arcane gesture
      const hy = fb - R * 2.2;
      // wide robe base sweeps the floor
      body([
        [fx - R * 0.55, fb],
        [fx - R * 0.42, fb - R * 1.1],
        [fx - R * 0.30, fb - R * 1.9],
        [fx - R * 0.20, hy + R * 0.2],
        [fx,            hy - R * 0.35],
        [fx + R * 0.20, hy + R * 0.2],
        [fx + R * 0.30, fb - R * 1.9],
        [fx + R * 0.42, fb - R * 1.1],
        [fx + R * 0.55, fb],
      ], cape, null);
      // inner robe — crimson lining visible
      body([
        [fx - R * 0.28, fb],
        [fx - R * 0.18, fb - R * 1.0],
        [fx - R * 0.12, hy + R * 0.4],
        [fx,            hy + R * 0.1],
        [fx + R * 0.12, hy + R * 0.4],
        [fx + R * 0.18, fb - R * 1.0],
        [fx + R * 0.28, fb],
      ], cape2, null);
      // left arm straight down / tucked
      body([
        [fx - R * 0.20, hy + R * 0.30],
        [fx - R * 0.28, fb - R * 1.2],
        [fx - R * 0.22, fb - R * 1.0],
      ], col, null);
      // right arm extended outward, fingers splayed (arcane gesture)
      body([
        [fx + R * 0.22, hy + R * 0.28],
        [fx + R * 0.68, hy + R * 0.44],
        [fx + R * 0.72, hy + R * 0.60],
        [fx + R * 0.44, hy + R * 0.56],
      ], col, null);
      // splayed fingers
      const fBase = [fx + R * 0.70, hy + R * 0.48];
      const fingerAngles = [-0.6, -0.25, 0.05, 0.3, 0.55];
      fingerAngles.forEach((a, fi2) => {
        const fl = R * (fi2 === 2 ? 0.22 : 0.18);
        ctx.beginPath();
        ctx.moveTo(fBase[0], fBase[1]);
        ctx.lineTo(fBase[0] + Math.cos(a) * fl, fBase[1] + Math.sin(a) * fl);
        ctx.strokeStyle = '#b8a090'; ctx.lineWidth = 1.4; ctx.stroke();
      });
      // arcane orb glowing at fingertips
      glowDot(fBase[0] + R * 0.04, fBase[1] - R * 0.08, R * 0.10, aura);
      // head — slightly pointed hood cowl
      body([
        [fx - R * 0.20, hy + R * 0.22],
        [fx - R * 0.24, hy + R * 0.04],
        [fx - R * 0.14, hy - R * 0.30, fx, hy - R * 0.45, fx + R * 0.14, hy - R * 0.30],
        [fx + R * 0.24, hy + R * 0.04],
        [fx + R * 0.20, hy + R * 0.22],
      ], '#261830', null);
      // face in shadow — just eyes
      glowDot(fx - R * 0.07, hy - R * 0.08, R * 0.055, eye);
      glowDot(fx + R * 0.07, hy - R * 0.08, R * 0.055, eye);
      // arcane rune ring — 5 sigil ticks around the collar
      const runeR = R * 0.28;  // radius of rune ring
      const runeX = fx, runeY = fb - R * 2.7;
      for (let ri = 0; ri < 5; ri++) {
        const angle = (ri / 5) * Math.PI * 2 - Math.PI / 2 + time * 0.3;
        const innerR = runeR * 0.78, outerR = runeR * (ri % 2 === 0 ? 1.0 : 0.88);
        ctx.beginPath();
        ctx.moveTo(runeX + Math.cos(angle) * innerR, runeY + Math.sin(angle) * innerR);
        ctx.lineTo(runeX + Math.cos(angle) * outerR, runeY + Math.sin(angle) * outerR);
        ctx.strokeStyle = eye + 'cc';
        ctx.lineWidth = 1.5;
        ctx.stroke();
      }
      // glowing orb center
      glowDot(runeX, runeY, R * 0.08, eye);

    } else if (clanId === 'ventrue') {
      // Aristocratic lord — ramrod straight, cape swept back, formal high collar
      const hy = fb - R * 2.3;
      // swept cape — billows to one side
      body([
        [fx - R * 0.02, fb],
        [fx - R * 0.02, fb - R * 1.8],
        [fx - R * 0.12, hy + R * 0.3],
        [fx,            hy - R * 0.2],
        [fx + R * 0.18, hy + R * 0.1],
        [fx + R * 0.58, fb - R * 1.2],
        [fx + R * 0.72, fb - R * 0.4, fx + R * 0.82, fb, fx + R * 0.55, fb],
      ], cape, null);
      // suit / body — narrow and upright
      body([
        [fx - R * 0.24, fb],
        [fx - R * 0.26, fb - R * 1.6],
        [fx - R * 0.18, hy + R * 0.25],
        [fx,            hy + R * 0.1],
        [fx + R * 0.18, hy + R * 0.25],
        [fx + R * 0.26, fb - R * 1.6],
        [fx + R * 0.24, fb],
      ], '#1a1f2e', null);
      // white shirt / cravat
      body([
        [fx - R * 0.08, fb - R * 1.5],
        [fx - R * 0.06, hy + R * 0.3],
        [fx,            hy + R * 0.15],
        [fx + R * 0.06, hy + R * 0.3],
        [fx + R * 0.08, fb - R * 1.5],
      ], '#e8e4f0', null);
      // left arm straight down
      body([
        [fx - R * 0.26, fb - R * 1.6],
        [fx - R * 0.32, fb - R * 0.8],
        [fx - R * 0.26, fb - R * 0.7],
      ], '#1a1f2e', null);
      // right arm angled out — one hand raised
      body([
        [fx + R * 0.26, fb - R * 1.6],
        [fx + R * 0.42, fb - R * 1.15],
        [fx + R * 0.38, fb - R * 0.98],
      ], '#1a1f2e', null);
      // high collar framing head
      body([
        [fx - R * 0.22, hy + R * 0.30],
        [fx - R * 0.26, hy + R * 0.04],
        [fx - R * 0.24, hy - R * 0.05],
        [fx + R * 0.24, hy - R * 0.05],
        [fx + R * 0.26, hy + R * 0.04],
        [fx + R * 0.22, hy + R * 0.30],
      ], col, null);
      // head — noble jaw, high forehead
      body([
        [fx - R * 0.18, hy + R * 0.15],
        [fx - R * 0.20, hy - R * 0.04],
        [fx - R * 0.12, hy - R * 0.32, fx, hy - R * 0.40, fx + R * 0.12, hy - R * 0.32],
        [fx + R * 0.20, hy - R * 0.04],
        [fx + R * 0.18, hy + R * 0.15],
        [fx + R * 0.08, hy + R * 0.22, fx - R * 0.08, hy + R * 0.22],
      ], '#c0b0a4', null);
      glowDot(fx - R * 0.065, hy - R * 0.08, R * 0.05, eye);
      glowDot(fx + R * 0.065, hy - R * 0.08, R * 0.05, eye);
      // crown / signet ring glint
      ctx.fillStyle = eye + 'bb';
      ctx.beginPath(); ctx.arc(fx, hy - R * 0.38, R * 0.04, 0, Math.PI * 2); ctx.fill();

    } else if (clanId === 'toreador') {
      // Elegant dancer — hip canted, one arm arched over head, flowing garment
      const hy = fb - R * 2.2;
      // flowing skirt / garment
      body([
        [fx - R * 0.45, fb],
        [fx - R * 0.30, fb - R * 1.05],
        [fx - R * 0.14, fb - R * 1.65],
        [fx,            fb - R * 1.80],
        [fx + R * 0.14, fb - R * 1.65],
        [fx + R * 0.25, fb - R * 1.10],
        [fx + R * 0.38, fb],
      ], cape, null);
      // inner dress — deep rose
      body([
        [fx - R * 0.22, fb],
        [fx - R * 0.18, fb - R * 1.0],
        [fx - R * 0.10, fb - R * 1.65],
        [fx,            fb - R * 1.78],
        [fx + R * 0.10, fb - R * 1.65],
        [fx + R * 0.18, fb - R * 1.0],
        [fx + R * 0.22, fb],
      ], col, null);
      // canted hip — slight rightward lean: body offset
      // left arm curving gracefully downward
      body([
        [fx - R * 0.14, fb - R * 1.68],
        [fx - R * 0.40, fb - R * 1.30],
        [fx - R * 0.44, fb - R * 1.05],
      ], '#b87890', null);
      // right arm arched overhead (arabesque)
      body([
        [fx + R * 0.14, fb - R * 1.68],
        [fx + R * 0.42, fb - R * 1.95],
        [fx + R * 0.32, hy - R * 0.10],
      ], '#b87890', null);
      // graceful hand at top of arc
      ctx.beginPath();
      ctx.arc(fx + R * 0.30, hy - R * 0.12, R * 0.06, 0, Math.PI * 2);
      ctx.fillStyle = '#e0c0c8'; ctx.fill();
      // head — oval, tilted
      body([
        [fx - R * 0.14, hy + R * 0.18],
        [fx - R * 0.17, hy - R * 0.06, fx - R * 0.12, hy - R * 0.32, fx + R * 0.01, hy - R * 0.36],
        [fx + R * 0.16, hy - R * 0.30, fx + R * 0.20, hy - R * 0.04, fx + R * 0.17, hy + R * 0.18],
        [fx + R * 0.08, hy + R * 0.26, fx - R * 0.06, hy + R * 0.26],
      ], '#d8b4a8', null);
      glowDot(fx - R * 0.05, hy - R * 0.06, R * 0.05, eye);
      glowDot(fx + R * 0.08, hy - R * 0.08, R * 0.05, eye);
      // rose adornment at collar
      const roseX = fx - R * 0.02, roseY = fb - R * 1.84;
      for (let p2 = 0; p2 < 5; p2++) {
        const pa = (p2 / 5) * Math.PI * 2;
        ctx.beginPath();
        ctx.arc(roseX + Math.cos(pa) * R * 0.05, roseY + Math.sin(pa) * R * 0.05, R * 0.04, 0, Math.PI * 2);
        ctx.fillStyle = aura; ctx.fill();
      }
      ctx.beginPath(); ctx.arc(roseX, roseY, R * 0.035, 0, Math.PI * 2); ctx.fillStyle = eye; ctx.fill();

    } else if (clanId === 'nosferatu') {
      // Crouching horror — low, wide, enormous claw hands, bat ears, hump
      const hy = fb - R * 1.42;
      // hunched mass — asymmetric, very wide at shoulder hump
      body([
        [fx - R * 0.50, fb],
        [fx - R * 0.70, fb - R * 0.80],
        [fx - R * 0.80, fb - R * 1.15, fx - R * 0.60, hy - R * 0.05, fx - R * 0.30, hy - R * 0.15],
        [fx,            hy - R * 0.20],
        [fx + R * 0.30, hy - R * 0.15],
        [fx + R * 0.60, hy - R * 0.05, fx + R * 0.80, fb - R * 1.15, fx + R * 0.70, fb - R * 0.80],
        [fx + R * 0.50, fb],
      ], cape, null);
      // neck / collar hump
      body([
        [fx - R * 0.25, fb - R * 0.85],
        [fx - R * 0.30, hy + R * 0.18],
        [fx,            hy + R * 0.06],
        [fx + R * 0.30, hy + R * 0.18],
        [fx + R * 0.25, fb - R * 0.85],
      ], col, null);
      // left massive claw arm — sprawling to the side
      body([
        [fx - R * 0.68, fb - R * 0.82],
        [fx - R * 0.92, fb - R * 0.30],
        [fx - R * 0.88, fb + R * 0.02],
      ], cape2, cape, 1.5);
      const lClawBase = [fx - R * 0.90, fb];
      for (let c2 = 0; c2 < 5; c2++) {
        const ca = Math.PI * (0.55 + c2 * 0.12);
        ctx.beginPath();
        ctx.moveTo(lClawBase[0], lClawBase[1]);
        ctx.lineTo(lClawBase[0] + Math.cos(ca) * R * 0.30, lClawBase[1] + Math.sin(ca) * R * 0.28);
        ctx.strokeStyle = eye; ctx.lineWidth = 1.8; ctx.stroke();
      }
      // right claw arm — reaching forward
      body([
        [fx + R * 0.68, fb - R * 0.82],
        [fx + R * 0.86, fb - R * 0.38],
        [fx + R * 0.82, fb - R * 0.04],
      ], cape2, cape, 1.5);
      const rClawBase = [fx + R * 0.84, fb - R * 0.06];
      for (let c2 = 0; c2 < 5; c2++) {
        const ca = Math.PI * (-0.10 + c2 * 0.12);
        ctx.beginPath();
        ctx.moveTo(rClawBase[0], rClawBase[1]);
        ctx.lineTo(rClawBase[0] + Math.cos(ca) * R * 0.28, rClawBase[1] + Math.sin(ca) * R * 0.26);
        ctx.strokeStyle = eye; ctx.lineWidth = 1.8; ctx.stroke();
      }
      // head — monstrous: oversized, bat-like ear spikes
      body([
        [fx - R * 0.24, hy + R * 0.10],
        [fx - R * 0.30, hy - R * 0.18, fx - R * 0.20, hy - R * 0.40, fx, hy - R * 0.42],
        [fx + R * 0.20, hy - R * 0.40, fx + R * 0.30, hy - R * 0.18, fx + R * 0.24, hy + R * 0.10],
        [fx + R * 0.10, hy + R * 0.20, fx - R * 0.10, hy + R * 0.20],
      ], '#6a4a38', null);
      // left ear spike
      body([[fx - R * 0.22, hy - R * 0.26], [fx - R * 0.36, hy - R * 0.60], [fx - R * 0.18, hy - R * 0.36]], cape2, null);
      // right ear spike
      body([[fx + R * 0.22, hy - R * 0.26], [fx + R * 0.36, hy - R * 0.60], [fx + R * 0.18, hy - R * 0.36]], cape2, null);
      // wide-set glowing eyes
      glowDot(fx - R * 0.12, hy - R * 0.10, R * 0.07, eye);
      glowDot(fx + R * 0.12, hy - R * 0.10, R * 0.07, eye);
      // exposed fang
      ctx.fillStyle = '#f0f0f0';
      ctx.beginPath();
      ctx.moveTo(fx - R * 0.04, hy + R * 0.09);
      ctx.lineTo(fx - R * 0.01, hy + R * 0.22);
      ctx.lineTo(fx + R * 0.03, hy + R * 0.09);
      ctx.fill();
      // blood drip from exposed fang
      const dripT = (time * 0.4) % 1;  // 0→1 cycle every 2.5 seconds
      const dripY = fb - R * 0.24 + dripT * R * 0.8;  // falls from fang tip
      const dripAlpha = dripT < 0.7 ? 1 : (1 - (dripT - 0.7) / 0.3);
      ctx.fillStyle = 'rgba(180,0,20,' + dripAlpha + ')';
      ctx.beginPath();
      ctx.ellipse(fx - R * 0.01, dripY, R * 0.025, R * 0.045, 0, 0, Math.PI * 2);
      ctx.fill();

    } else if (clanId === 'malkavian') {
      // Fragmented seer — body partially dissolving, one eye huge, mirror-shards floating
      const hy = fb - R * 2.15;
      // main body — thin, slightly off-centre
      body([
        [fx - R * 0.28, fb],
        [fx - R * 0.32, fb - R * 1.5],
        [fx - R * 0.20, hy + R * 0.20],
        [fx + R * 0.04, hy + R * 0.05],
        [fx + R * 0.28, hy + R * 0.22],
        [fx + R * 0.30, fb - R * 1.5],
        [fx + R * 0.24, fb],
      ], cape, null);
      // tattered overlay — ghost fragments breaking off
      body([
        [fx - R * 0.16, fb - R * 0.6],
        [fx - R * 0.30, fb - R * 1.1],
        [fx - R * 0.42, fb - R * 0.95, fx - R * 0.50, fb - R * 0.72, fx - R * 0.38, fb - R * 0.62],
      ], aura + '55', null);
      body([
        [fx + R * 0.16, fb - R * 0.8],
        [fx + R * 0.34, fb - R * 1.3],
        [fx + R * 0.46, fb - R * 1.14, fx + R * 0.52, fb - R * 0.90, fx + R * 0.38, fb - R * 0.78],
      ], eye + '44', null);
      // left arm extended — clutching at something unseen
      body([
        [fx - R * 0.30, fb - R * 1.50],
        [fx - R * 0.54, fb - R * 1.20],
        [fx - R * 0.58, fb - R * 1.00],
      ], col, null);
      // right arm bent inward oddly
      body([
        [fx + R * 0.30, fb - R * 1.50],
        [fx + R * 0.38, fb - R * 1.78],
        [fx + R * 0.28, fb - R * 1.90],
      ], col, null);
      // head — slight tilt, disturbing
      body([
        [fx - R * 0.17, hy + R * 0.18],
        [fx - R * 0.22, hy - R * 0.08, fx - R * 0.14, hy - R * 0.34, fx + R * 0.02, hy - R * 0.38],
        [fx + R * 0.20, hy - R * 0.32, fx + R * 0.25, hy - R * 0.06, fx + R * 0.20, hy + R * 0.18],
        [fx + R * 0.08, hy + R * 0.27, fx - R * 0.06, hy + R * 0.27],
      ], '#bca8c8', null);
      // one huge eye (dominant / unseeing)
      glowDot(fx - R * 0.04, hy - R * 0.06, R * 0.11, eye);
      // one tiny eye (the other)
      glowDot(fx + R * 0.10, hy - R * 0.08, R * 0.04, aura);
      // floating mirror-shard fragments around the figure
      const shardData = [
        [fx - R * 0.62, fb - R * 1.38, -0.4],
        [fx - R * 0.48, fb - R * 1.72, 0.8],
        [fx + R * 0.60, fb - R * 1.55, -0.6],
        [fx + R * 0.50, fb - R * 0.90, 1.1],
      ];
      shardData.forEach(([sx2, sy2, angle], si) => {
        ctx.save();
        ctx.translate(sx2, sy2);
        ctx.rotate(angle + time * (0.18 + si * 0.09));
        ctx.fillStyle = aura + '60';
        ctx.beginPath();
        ctx.moveTo(0, -R * 0.08);
        ctx.lineTo(R * 0.06, R * 0.04);
        ctx.lineTo(-R * 0.04, R * 0.07);
        ctx.closePath();
        ctx.fill();
        ctx.strokeStyle = eye + '99';
        ctx.lineWidth = 0.8;
        ctx.stroke();
        ctx.restore();
      });
    }

    // ---- end sway transform (must happen before clip restore) ------
    ctx.restore();

    // ---- restore before drawing text (text must not be clipped) ---
    ctx.restore();
    ctx.save();

    // ---- clan name label below the arch body ----------------------
    // Name sits at the very bottom of the bounding rect (below foot y=cy+ch)
    const nameY = cy + ch + 13;
    ctx.font = selected ? 'bold 9px Georgia, serif' : 'bold 8px Georgia, serif';
    ctx.textAlign = 'center';
    ctx.fillStyle = selected ? eye : (over ? '#e8d8e8' : '#a898a8');
    ctx.fillText(clanName.toUpperCase(), cx + cw / 2, nameY);

    // desc shown only when selected — tiny line below name
    if (selected) {
      ctx.font = 'italic 7px Verdana';
      ctx.fillStyle = '#9a8';
      ctx.fillText(clanDesc, cx + cw / 2, nameY + 11);
    }

    ctx.restore();
    return clicked;
  }
  // ---- end drawClanCard (module scope) ---------------------------

  const Game = {
    canvas: null, ctx: null, w: 0, h: 0,
    world: null, player: null, cam: null,
    npcs: [], vehicles: [], projectiles: [], pickups: [], blips: [],
    masquerade: null, quests: null, achievements: null,
    activeMission: null, missionsDone: 0,
    time: 0, clock: 21, day: 1, timeOfDay: { night: true, t: 0 },
    enemyTimeScale: 1, slowmoT: 0, slowScale: 0.32, crackProgress: 0,
    hitStopT: 0,                       // #7 — brief sim freeze on heavy impacts
    inHaven: false, mode: 'title',
    vol: { master: 0.8, music: 0.5, sfx: 0.9, amb: 0.6 },
    quality: 'high', reducedMotion: false,   // #17/#24/#94 — gfx + motion options
    weather: { kind: 'clear', t: 0, rain: [], fog: 0, motes: [] },  // #17 — dynamic weather + atmosphere
    spawnTimer: 0, trafficTimer: 0,
    lightCanvas: null, lightCtx: null,
    deathT: 0,
    _clearedFive: false,
    init(canvas) {
      this.canvas = canvas; this.ctx = canvas.getContext('2d');
      VAMP.bus = VAMP.bus || U.Emitter();
      VAMP.Input.init(canvas);
      this.resize();
      window.addEventListener('resize', () => this.resize());
      VAMP.Assets.build(this.ctx);
      if (VAMP.Assets.loadAll) {
        VAMP.Assets.loadAll((n, tot, key) => {
          const splash = document.getElementById('splash');
          if (splash) {
            const p = splash.querySelector('p');
            if (p) p.textContent = 'summoning the night… ' + n + '/' + tot;
            const pct = tot > 0 ? Math.round((n / tot) * 100) : 0;
            splash.style.setProperty('--load-pct', pct + '%');
            const fill = splash.querySelector('.splash-progress-fill');
            if (fill) fill.style.width = pct + '%';
          }
        }).then(() => {
          if (this.ctx) VAMP.Assets.rebuildPatterns(this.ctx);
          if (this.world && VAMP.UI && VAMP.UI.buildMinimap) VAMP.UI.buildMinimap(this.world);
          const splash = document.getElementById('splash');
          if (splash && this.mode === 'title') splash.style.display = 'none';
        }).catch(() => {});
      }
      const s = VAMP.Save.loadSettings();
      if (s) { this.vol = Object.assign({ master: 0.8, music: 0.5, sfx: 0.9, amb: 0.6, gamma: 1 }, s); }   // default amb/gamma for old settings
      if (this.vol && this.vol.gamma == null) this.vol.gamma = 1;
      this.applyQualityTier();
    },
    applyQualityTier() {
      if (!VAMP.ArtFlags) return;
      const low = this.quality === 'low';
      const med = this.quality === 'medium';
      VAMP.ArtFlags.useBitmapNPCs = !low;
      VAMP.ArtFlags.useAutotile = !low;
      VAMP.ArtFlags.usePostFX = !low;
      VAMP.ArtFlags.useSpriter = !low;
      VAMP.ArtFlags.useLightWorker = false;
      if (low) {
        VAMP.ArtFlags.useBitmapBuildings = false;
        VAMP.ArtFlags.useBitmapFX = false;
        VAMP.ArtFlags.useBitmapGround = false;
      } else if (med) {
        VAMP.ArtFlags.useBitmapBuildings = true;
        VAMP.ArtFlags.useBitmapFX = true;
        VAMP.ArtFlags.useBitmapGround = true;
      }
    },
    updateCursor() {
      const el = document.getElementById('game');
      if (!el || this.mode !== 'play' || !this.player) { if (el) el.className = ''; return; }
      const p = this.player;
      let cls = '';
      if (p.feeding || (p.holdingFeed && p._feedTarget)) cls = 'feed-mode';
      else if (p.sprinting) cls = 'sprint-mode';
      else if (p.freeAiming) cls = 'aim-mode';
      el.className = cls;
    },
    resize() {
      // DPR (#1): the loop owns the backing-store size + ctx scale; here we
      // only record the CSS-pixel viewport everything draws in.
      this.w = window.innerWidth || 1280; this.h = window.innerHeight || 720;
      if (this.cam) this.cam.resize(this.w, this.h);
      this.lightCanvas = VAMP.Assets.makeCanvas(this.w, this.h);
      this.lightCtx = this.lightCanvas.getContext('2d');
    },
    // ---------------------------------------------------------------- start
    newGame(seed, clan, slot, difficulty) {
      this._saveSlot = slot != null ? slot : (this._saveSlot || 0);
      this.difficulty = difficulty || 'normal';
      seed = seed >>> 0 || ((Math.random() * 1e9) >>> 0);
      this.time = 0; this.clock = 21; this.day = 1;
      this.safeUntil = 55;
      this.buildWorld(seed);
      const haven = this.world.pois.find((p) => p.type === 'haven') || { x: this.world.w / 2, y: this.world.h / 2 };
      const spawn = this.walkableNear(haven.x, haven.y + 40);
      this.player = VAMP.Player.newPlayer(this.world, spawn);
      this.applyClan(clan);
      this.afterPlayer();
      const startDist = this.world.districtAt(this.player.x, this.player.y);
      this._lastDistrict = startDist ? startDist.id : null;
      if (startDist) {
        this.districtCard = {
          name: startDist.name, id: startDist.id,
          accent: VAMP.DistrictArt ? VAMP.DistrictArt.kitAccent(startDist.id) : startDist.accent,
          t: 3.2, max: 3.2,
        };
      }
      VAMP.UI.notify('You awaken in ' + (startDist || { name: 'the city' }).name + '. The Hunger calls...', '#e0a0b8');
      VAMP.UI.banner('VAMPIRE CITY', 'Feed. Grow. Rule the night.', '#c0303a');
      this.tutorialStage = 'move';
      this.tutorialGoal = 'MOVE: WASD / arrow keys. You face the way you move — SPACE attacks that way. Hold RIGHT-MOUSE to free-aim. Explore — the night is yours.';
      this.tips = { moved: false, fed: false, power: false, usedC: false, body: false, dash: false };  // #15
      this.night = { kills: 0, feeds: 0, money: 0 };                         // #25
      // board blip is revealed by VAMP.Progress when 'missions' unlocks (not at start)
      const hv = this.world.pois.find((p) => p.type === 'haven'); if (hv) this.addBlip({ x: hv.x, y: hv.y, color: '#5a9cff', kind: 'guide' });
      if (VAMP.Legacy) VAMP.Legacy.applyNewGame(this);
      this.mode = 'play';
    },
    loadGame(data, slot) {
      this._saveSlot = slot != null ? slot : (this._saveSlot || 0);
      if (!data || !data.player || data.seed == null) {
        VAMP.UI.notify('Save was corrupt — starting fresh.', '#a66');
        this.mode = 'title'; return;
      }
      const run = VAMP.Save.sanitizeRun ? VAMP.Save.sanitizeRun(data) : data;
      this.buildWorld(run.seed);
      this.player = VAMP.Player.newPlayer(this.world, { x: run.player.x, y: run.player.y });
      VAMP.Save.applyToPlayer(this.player, run.player);
      this.applyClan(this.player.clan || run.player.clan || 'brujah', true);
      const worldState = VAMP.Save.sanitizeWorldState ? VAMP.Save.sanitizeWorldState(run, this.world) : { domains: run.domains || {}, districtState: run.districtState || {} };
      this.domains = worldState.domains; this.districtState = worldState.districtState;
      this.clock = run.clock; this.day = run.day; this.time = run.time;
      this.missionsDone = run.missionsDone;
      this.difficulty = run.difficulty || 'normal';
      this.night = { kills: 0, feeds: 0, money: 0 };
      this.afterPlayer();
      if (VAMP.Legacy) VAMP.Legacy.applyNewGame(this);
      this.masquerade.heat = run.heat;
      this.achievements = VAMP.Achievements.create(this, run.achievements || {});
      if (VAMP.Missions && VAMP.Missions.restore) VAMP.Missions.restore(this, run.activeMission);
      VAMP.UI.notify('Welcome back to the long night.', '#e0a0b8');
      this.mode = 'play';
    },
    buildWorld(seed) {
      this.world = VAMP.World.generate(seed);
      this.placePOIs();
      if (VAMP.Decals && VAMP.Decals.seedWorld) VAMP.Decals.seedWorld(this.world);
      VAMP.UI.buildMinimap(this.world);
      this.cam = VAMP.Camera(this.w, this.h);
      this.cam.bounds = { w: this.world.w, h: this.world.h };
      this.cam.targetZoom = 1.15;
      this.npcs = []; this.vehicles = []; this.projectiles = []; this.pickups = []; this.blips = [];
      this.activeMission = null;
      VAMP.FX.clear();
    },
    afterPlayer() {
      this._dmgDirs = [];   // #16 — transient incoming-damage direction arcs (not serialized)
      this.cam.snap(this.player.x, this.player.y);
      if (VAMP.Haven) VAMP.Haven.ensure(this.player);
      if (VAMP.Mastery) VAMP.Mastery.ensure(this.player);
      if (VAMP.Codex) VAMP.Codex.ensure(this.player);
      if (VAMP.Reputation && VAMP.Reputation.ensure) VAMP.Reputation.ensure(this.player);
      if (VAMP.Business) VAMP.Business.ensure(this.player);
      if (VAMP.Coterie) VAMP.Coterie.ensure(this.player);
      if (VAMP.Nemesis) VAMP.Nemesis.ensure(this.player);
      if (VAMP.Domains) VAMP.Domains.ensure(this);
      if (VAMP.Progress) VAMP.Progress.ensure(this.player);
      VAMP.Stats.recompute(this.player);
      this.masquerade = VAMP.Masquerade.create(this);
      this.quests = VAMP.Quests.create(this);
      if (VAMP.Events) this.events = VAMP.Events.create(this);   // #23
      if (!this.achievements) this.achievements = VAMP.Achievements.create(this, {});
      for (let i = 0; i < 40; i++) this.spawnAmbient(true);
      for (let i = 0; i < 12; i++) this.spawnTraffic(true);
      VAMP.Audio.setVolume('master', this.vol.master);
      VAMP.Audio.setVolume('music', this.vol.music);
      VAMP.Audio.setVolume('sfx', this.vol.sfx);
      VAMP.Audio.setVolume('amb', this.vol.amb != null ? this.vol.amb : 0.6);
    },
    // four readable tension bands: explore / hunt / combat / frenzy
    computeTension(p) {
      const stars = this.masquerade ? this.masquerade.stars : 0;
      const hunting = (this.time - (p.lastAttackT || -99) < 4) || (this.time - (p.lastHurtT || -99) < 4);
      return Math.min(1, stars / 4 + (hunting ? 0.3 : 0) + (p.bloodState.frenzied ? 0.5 : 0));
    },
    applyClan(clan, isLoad) {
      const map = {
        brujah: { power: 'pot_charge', node: 'pot_n1', msg: 'Brujah: rebels of Potence & Celerity.', baneName: 'The Beast (frenzy comes easy)' },
        gangrel: { power: 'pro_claws', node: 'pro_n1', msg: 'Gangrel: feral masters of Protean.', baneName: 'Feral (poor at dealing)' },
        tremere: { power: 'bs_bolt', node: 'bs_n1', msg: 'Tremere: blood sorcerers.', baneName: 'Frail flesh' },
        ventrue: { power: 'dom_mesmer', node: 'dom_n1', msg: 'Ventrue: lords of Dominate.', baneName: 'Refined palate' },
        toreador: { power: 'cel_dash', node: 'cel_n1', msg: 'Toreador: swift and beguiling.', baneName: 'Aesthete (fragile)' },
        nosferatu: { power: 'obf_cloak', node: 'obf_n1', msg: 'Nosferatu: unseen lurkers.', baneName: 'Hideous (shunned by vendors)' },
        malkavian: { power: 'aus_mark', node: 'aus_n1', msg: 'Malkavian: cursed with sight.', baneName: 'Madness (thinner vitae)' },
      };
      const c = map[clan] || map.brujah;
      this.player.clan = clan || 'brujah';
      this.player.clanBaneName = c.baneName;
      this.player.clanColor = CLAN_COLORS[this.player.clan] || CLAN_COLORS.brujah;   // #11
      if (!isLoad) {
        this.player.treeNodes[c.node] = 1;
        VAMP.Disc.learn(this.player, c.power);
        VAMP.UI.notify(c.msg + ' Bane: ' + c.baneName, '#c79bff');
        // the vampire identity must land in minute one: the clan power is already bound to slot 1,
        // but nothing told the player it exists. Name it and the key (decoupled from the skill-point gate).
        const pwr = VAMP.Data && VAMP.Data.POWERS && VAMP.Data.POWERS[c.power];
        const pname = (pwr && pwr.name) ? pwr.name : 'your clan Discipline';
        VAMP.UI.notify('⚡ ' + pname.toUpperCase() + ' — your clan Discipline is ready. Press 1 to unleash it.', '#b07bff');
        this._pulseSlot1Until = this.time + 30;   // hint: pulse hotbar slot 1 until first cast or 30s
      }
      VAMP.Stats.recompute(this.player);
    },
    placePOIs() {
      const w = this.world;
      w.pois = [];
      const types = [
        { type: 'haven', glyph: '+', color: '#5a9cff', label: 'Haven', count: 4 },
        { type: 'market', glyph: '$', color: '#ffd24a', label: 'Black Market', count: 3 },
        { type: 'board', glyph: '#', color: '#c79bff', label: 'Contract Board', count: 3 },
        { type: 'bloodbank', glyph: 'h', color: '#ff5a7a', label: 'Blood Bank', count: 2 },
        { type: 'power', glyph: '*', color: '#ffd24a', label: 'Place of Power', count: 5 },
        { type: 'crypt', glyph: '+', color: '#9a86c4', label: 'Elder Crypt', count: 4 },
      ];
      const used = new Set();
      const pickBuilding = () => {
        for (let i = 0; i < 200; i++) {
          const b = w.buildings[(Math.random() * w.buildings.length) | 0];
          if (!b || used.has(b) || b.w < 60 || b.h < 60) continue;
          used.add(b); return b;
        }
        return w.buildings[0];
      };
      const safest = w.districts.map((d, i) => ({ i, danger: d.danger })).sort((a, b) => a.danger - b.danger)[0].i;
      const pickInDistrict = (di) => { for (let i = 0; i < 400; i++) { const b = w.buildings[(Math.random() * w.buildings.length) | 0]; if (!b || used.has(b) || b.w < 60 || b.h < 60 || b.d !== di) continue; used.add(b); return b; } return null; };
      let firstHaven = true;
      for (const t of types) {
        for (let i = 0; i < t.count; i++) {
          let b = (t.type === 'haven' && firstHaven) ? (pickInDistrict(safest) || pickBuilding()) : pickBuilding();
          if (t.type === 'haven' && firstHaven) firstHaven = false;
          if (!b) continue;
          const poi = { x: b.x + b.w / 2, y: b.y + b.h / 2, type: t.type, glyph: t.glyph, color: t.color, label: t.label, discovered: false, building: b, id: t.type + '_' + Math.round(b.x) + '_' + Math.round(b.y) };
          b.poi = { glyph: t.glyph, color: t.color, type: t.type };
          w.pois.push(poi);
        }
      }
      if (w.pois.length) w.pois[0].discovered = true;
    },
    // ---------------------------------------------------------------- update
    toggleFullscreen() {
      if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().catch(() => {});
      } else {
        document.exitFullscreen().catch(() => {});
      }
    },
    update(dt) {
      if (VAMP.Input.wasPressed('f11')) this.toggleFullscreen();
      if (this.mode === 'title') { VAMP.UI.update(dt); return; }
      if (this.mode === 'dead') { this.deathT += dt; VAMP.FX.update(dt); VAMP.UI.update(dt); return; }
      this.updateCursor();
      VAMP.Menus.handleKeys(this);
      if (VAMP.Input.anyPressed()) { if (this._tipT > 0) this._tipT = 0; if (this._recapT > 0) this._recapT = 0; }  // #15/#25 dismiss
      if (VAMP.Menus.pausesSim()) { VAMP.UI.update(dt); return; }
      this.time += dt;
      const hourRate = this.timeOfDay.night ? (1 / 60) : (1 / 11);
      this.clock += dt * hourRate;
      if (this.clock >= 24) { this.clock -= 24; this.day++; }
      this.updateDayNight();
      this.tickWeather(dt);   // #17
      if (this._wasNight === undefined) this._wasNight = this.timeOfDay.night;
      if (this._wasNight && !this.timeOfDay.night) this.onDawn();
      this._wasNight = this.timeOfDay.night;
      if (this.slowmoT > 0) { this.slowmoT -= dt; this.enemyTimeScale = this.slowScale; } else this.enemyTimeScale = 1;
      let simDt = dt;
      if (this.hitStopT > 0) { this.hitStopT -= dt; simDt = dt * (this.reducedMotion ? 0.6 : 0.12); }  // #7
      const edt = simDt * this.enemyTimeScale;
      this._shootersThisTick = 0;
      const p = this.player;
      VAMP.Player.update(p, simDt, this);
      if (p.dead) return;
      const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
      const curDist = this.world.districtAt(px, py);
      if (curDist && curDist.id !== this._lastDistrict) {
        this._lastDistrict = curDist.id;
        this.districtCard = {
          name: curDist.name, id: curDist.id, tag: curDist.accent ? '' : '',
          accent: VAMP.DistrictArt ? VAMP.DistrictArt.kitAccent(curDist.id) : curDist.accent,
          t: 2.8, max: 2.8,
        };
      }
      if (this.districtCard) { this.districtCard.t -= dt; if (this.districtCard.t <= 0) this.districtCard = null; }
      this._feedTarget = (!p.inVehicle && !p.feeding) ? VAMP.Player.findFeedTarget(p, this) : null;
      for (const n of this.npcs) VAMP.Npc.update(n, edt, this);
      for (const v of this.vehicles) if (!(p.inVehicle === v)) VAMP.Vehicle.update(v, v.ai ? edt : dt, this);
      for (let i = this.projectiles.length - 1; i >= 0; i--) { const pr = this.projectiles[i]; VAMP.Projectile.update(pr, pr.owner === 'player' ? dt : edt, this); if (pr.dead) this.projectiles.splice(i, 1); }
      this.updatePickups(dt);
      this.masquerade.update(dt, this);
      if (VAMP.Stealth) VAMP.Stealth.update(dt, this);
      if (VAMP.Reputation && VAMP.Reputation.regenInfluence) VAMP.Reputation.regenInfluence(p, dt);
      this.quests.update(dt);
      if (this.events) this.events.update(dt, this);   // #23
      if (this.achievements) this.achievements.update(dt);
      VAMP.Missions.update(this, dt);
      VAMP.FX.update(dt);
      VAMP.UI.update(dt);
      this.updateSun(dt, p);
      if (this.tutorialStage === 'move' && p.stats.distance > 180) {
        this.tutorialStage = 'feed';
        this.tutorialGoal = 'FEED: get close to a civilian (a heart marks prey) and HOLD F to drain. It fuels your powers and grants XP.';
      }
      if (this.tips) {   // #15 first-use tips
        if (!this.tips.moved && p.stats.distance > 60) { this.tips.moved = true; this.showTip('Tip: SPACE strikes where you face · hold RIGHT-MOUSE to aim freely (shoot while fleeing) · hold Shift to sprint.'); }
        if (!this.tips.fed && p.feeding) { this.tips.fed = true; this.showTip('Feeding! CLICK in the GOLD ring for a Perfect Gulp (bonus vitae + slow-mo). HOLD F to drain to death · RELEASE to spare (leaves a body). Press G to Embrace a thrall.'); }
        if (!this.tips.power && Object.values(p.powers || {}).length >= 1 && p.skillPoints > 0) { this.tips.power = true; this.showTip('Tip: press C -> Skills to spend points, then bind a power to a hotbar slot (1-8).'); }
        if (!this.tips.usedC && p.attrPoints > 0) { this.tips.usedC = true; this.showTip('Tip: you have Attribute points to spend — press C to open your character sheet.'); }
        if (!this.tips.body && this.npcs.some((n) => (n.downed || (n.dead && !n._disposed)) && !n.ally && U.dist(p.x, p.y, n.x, n.y) < 220)) { this.tips.body = true; this.showTip('Tip: a spared victim is left UNCONSCIOUS — a body. If a mortal finds one it raises the alarm. Press E to carry it to a dumpster/manhole (or drop it in shadow). Sneak with X; F behind an unaware foe is a silent takedown.'); }
        if (!this.tips.dash && this.npcs.some((n) => n.hostileToPlayer && !n.dead && U.dist(p.x, p.y, n.x, n.y) < 240)) { this.tips.dash = true; this.showTip('Tip: DOUBLE-TAP a direction to DASH — you\'re briefly invulnerable. Watch for the red attack telegraph and dash THROUGH it, then strike back.'); }
      }
      if (this._tipT > 0) this._tipT -= dt;
      if (this._recapT > 0) this._recapT -= dt;
      this.directorTick(dt);
      // --- camera: look-ahead + speed-zoom (set targetZoom BEFORE follow) ---
      const ent = p.inVehicle || p;
      const tx = ent.x, ty = ent.y;
      if (this._lastFx === undefined) { this._lastFx = tx; this._lastFy = ty; }
      const evx = (tx - this._lastFx) / Math.max(0.001, simDt);   // player/vehicle integrate position directly
      const evy = (ty - this._lastFy) / Math.max(0.001, simDt);
      this._lastFx = tx; this._lastFy = ty;
      const baseZoom = p.feeding ? 1.4 : (p.inVehicle ? 1.0 : 1.18);
      const spdN = U.clamp(Math.hypot(evx, evy) / 300, 0, 1);
      const zoomPull = p.inVehicle ? 0.12 : 0.08;
      this.cam.targetZoom = p.feeding ? baseZoom : (baseZoom - zoomPull * spdN * (this.reducedMotion ? 0 : 1));
      let leadX = 0, leadY = 0;
      if (!this.reducedMotion && !p.feeding) {
        if (p.inVehicle) { leadX = U.clamp(evx * 0.22, -120, 120); leadY = U.clamp(evy * 0.22, -120, 120); }
        else { leadX = U.clamp(evx * 0.16 + Math.cos(p.facing) * 23, -90, 90); leadY = U.clamp(evy * 0.16 + Math.sin(p.facing) * 23, -90, 90); }
      }
      this._camLeadX = U.lerp(this._camLeadX || 0, leadX, 1 - Math.pow(0.02, simDt));
      this._camLeadY = U.lerp(this._camLeadY || 0, leadY, 1 - Math.pow(0.02, simDt));
      this.cam.follow(tx + this._camLeadX, ty + this._camLeadY, dt, 0);
      VAMP.Audio.setTension(this.computeTension(p));
      if (VAMP.Audio.update) VAMP.Audio.update(simDt, this);   // heartbeat / ambience / footsteps / ducking
      if (!VAMP.Menus.isOpen()) this.inHaven = false;
    },
    updateSun(dt, p) {
      if (this.timeOfDay.night) { this.sunExposure = Math.max(0, (this.sunExposure || 0) - dt * 3); this.sunWarned = false; this.sheltered = true; this.sunBurn = U.clamp((this.sunExposure || 0) / 9, 0, 1); return; }
      const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
      const sheltered = p.inVehicle || this.inHaven || p.mistForm || p.cloaked || this.nearShade(px, py);
      this.sheltered = sheltered;
      if (sheltered) { this.sunExposure = Math.max(0, (this.sunExposure || 0) - dt * 2); this.sunBurn = U.clamp((this.sunExposure || 0) / 9, 0, 1); return; }
      this.sunExposure = (this.sunExposure || 0) + dt;
      this.sunBurn = U.clamp(this.sunExposure / 9, 0, 1);
      if (!this.sunWarned) { this.sunWarned = true; VAMP.UI.notify('Dawn burns! Find shade — hug a building, take a car, or reach a haven.', '#ff8030'); }
      const ramp = U.clamp((this.sunExposure - 2.5) / 7, 0, 1);
      const dmg = (1 - p.derived.sunResist) * (1.2 + ramp * 2.8) * dt;
      if (dmg > 0) VAMP.Combat.damagePlayer(this, dmg, { dot: true, unavoidable: true });
    },
    nearShade(x, y) {
      const near = this.world.buildingsNear(x, y, 80);
      for (const b of near) if (U.circleRect(x, y, 68, b.x - 14, b.y - 14, b.w + 28, b.h + 28)) return true;
      for (const poi of this.world.pois) if (poi.type === 'haven' && U.dist(x, y, poi.x, poi.y) < 150) return true;
      return false;
    },
    updateDayNight() {
      const c = this.clock;
      const night = (c >= 19 || c < 6);
      this.timeOfDay.night = night;
      this.timeOfDay.day = !night;
      let dk;
      if (c >= 19) dk = U.smoothstep((c - 19) / 3);
      else if (c < 4) dk = 1;
      else if (c < 6) dk = U.smoothstep((6 - c) / 2);
      else if (c < 8) dk = U.smoothstep((8 - c) / 2) * 0.4;
      else if (c < 17) dk = 0;
      else dk = U.smoothstep((c - 17) / 2);
      this.darkness = U.clamp(dk, 0, 1);
    },
    // #17 — dynamic weather
    tickWeather(dt) {
      const w = this.weather;
      w.t -= dt;
      if (w.t <= 0) {
        w.t = U.range(80, 160);
        const roll = Math.random();
        if (roll < 0.5) w.kind = 'clear';
        else if (roll < 0.8) w.kind = 'fog';
        else w.kind = 'rain';
        w.targetFog = w.kind === 'fog' ? 0.35 : (w.kind === 'rain' ? 0.15 : 0);
        if (w.kind === 'rain' && this.quality !== 'low' && !this.reducedMotion && w.rain.length === 0) {
          for (let i = 0; i < 220; i++) w.rain.push({ x: Math.random() * this.w, y: Math.random() * this.h, len: U.range(8, 16), sp: U.range(900, 1300) });
        } else if (w.kind !== 'rain') w.rain.length = 0;
      }
      w.fog = U.approach(w.fog, w.targetFog || 0, dt * 0.15);
      if (w.rain.length) {
        const wind = 220;
        for (const d of w.rain) { d.x += wind * dt; d.y += d.sp * dt; if (d.y > this.h) { d.y = -d.len; d.x = Math.random() * this.w; } if (d.x > this.w) d.x = 0; }
      }
      // night embers / dust motes (fixed pool, allocated once)
      if (this.darkness > 0.2 && w.motes.length === 0 && this.quality !== 'low' && !this.reducedMotion) {
        for (let i = 0; i < 70; i++) w.motes.push({ x: Math.random() * this.w, y: Math.random() * this.h, vx: U.range(-6, 6), vy: U.range(-12, -2), r: U.range(0.6, 1.8), warm: Math.random() < 0.25 });
      }
      if (w.motes.length) {
        for (const m of w.motes) { m.x += m.vx * dt; m.y += m.vy * dt; if (m.y < -4) { m.y = this.h + 4; m.x = Math.random() * this.w; } if (m.x < -4) m.x = this.w; else if (m.x > this.w) m.x = 0; }
      }
    },
    renderWeather(ctx, w, h) {
      const W = this.weather;
      const dk = this.darkness || 0;
      // moon (screen-space, slight parallax) at night
      if (dk > 0.25 && this.quality !== 'low') {
        const mx = w * 0.82 - (this.cam ? this.cam.x * 0.01 : 0), my = h * 0.16 - (this.cam ? this.cam.y * 0.01 : 0);
        ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = dk * 0.5;
        ctx.drawImage(VAMP.Assets.glowTinted('#cfd8ff'), mx - 70, my - 70, 140, 140);
        ctx.restore();
        ctx.fillStyle = 'rgba(232,228,210,' + (dk * 0.9) + ')'; ctx.beginPath(); ctx.arc(mx, my, 22, 0, U.TAU); ctx.fill();
        ctx.fillStyle = 'rgba(8,9,16,' + (dk * 0.9) + ')'; ctx.beginPath(); ctx.arc(mx + 8 - (this.day % 5) * 3, my - 2, 20, 0, U.TAU); ctx.fill();   // phase from day
      }
      if (W.fog > 0.01) {
        const fg = ctx.createLinearGradient(0, 0, 0, h);
        fg.addColorStop(0, 'rgba(100,105,130,' + (W.fog * 0.22) + ')');
        fg.addColorStop(0.55, 'rgba(120,120,150,' + (W.fog * 0.38) + ')');
        fg.addColorStop(1, 'rgba(80,85,110,' + (W.fog * 0.55) + ')');
        ctx.fillStyle = fg; ctx.fillRect(0, 0, w, h);
      }
      // drifting embers / motes (additive, faded by darkness)
      if (W.motes.length && dk > 0.15) {
        ctx.save(); ctx.globalCompositeOperation = 'lighter';
        for (const m of W.motes) { ctx.globalAlpha = dk * (m.warm ? 0.5 : 0.32); ctx.fillStyle = m.warm ? '#ff9a50' : '#9fb6d8'; ctx.beginPath(); ctx.arc(m.x, m.y, m.r, 0, U.TAU); ctx.fill(); }
        ctx.restore(); ctx.globalAlpha = 1;
      }
      if (W.rain.length) {
        ctx.save(); ctx.lineCap = 'round';
        ctx.strokeStyle = 'rgba(120,150,190,0.08)'; ctx.lineWidth = 1.2; ctx.beginPath();
        for (let i = 0; i < W.rain.length; i += 3) {
          const d = W.rain[i];
          ctx.moveTo(d.x, d.y); ctx.lineTo(d.x - d.len * 0.12, d.y + d.len);
        }
        ctx.stroke();
        ctx.strokeStyle = 'rgba(180,210,240,0.12)'; ctx.lineWidth = 0.8; ctx.beginPath();
        for (const d of W.rain) { ctx.moveTo(d.x, d.y); ctx.lineTo(d.x - d.len * 0.1, d.y + d.len * 0.9); }
        ctx.stroke();
        ctx.globalAlpha = 0.025; ctx.fillStyle = '#8090b0'; ctx.fillRect(0, 0, w, h);
        ctx.restore(); ctx.globalAlpha = 1;
      }
    },
    directorTick(dt) {
      const p = this.player;
      const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
      for (let i = this.npcs.length - 1; i >= 0; i--) {
        const n = this.npcs[i];
        // keep a corpse around a little longer (and never cull one you're carrying) so there's time
        // to drag & dump it — the stealth/disposal loop needs the body to persist.
        if (n.dead && n !== p.carrying && this.time - (n.deathT || 0) > 18) { this.npcs.splice(i, 1); continue; }
        if (!n.dead && n !== p.carrying && !n.downed && !n.responder && !n.mission && !n.ally && !n.bloodDoll && !n.bounty && !n.baronOf && !n.boss && !n.nemesis && U.dist(px, py, n.x, n.y) > 2200) this.npcs.splice(i, 1);
      }
      for (let i = this.vehicles.length - 1; i >= 0; i--) {
        const v = this.vehicles[i];
        if (p.inVehicle === v) continue;
        if (v.exploded || (v.dead && this.time - (v.deathT || this.time) > 8) || U.dist(px, py, v.x, v.y) > 2500) this.vehicles.splice(i, 1);
      }
      this.spawnTimer -= dt;
      const ambientTarget = this.timeOfDay.night ? 34 : 18;
      const ambientCount = this.npcs.filter((n) => !n.responder && !n.mission && !n.ally && !n.dead).length;
      if (this.spawnTimer <= 0 && ambientCount < ambientTarget) { this.spawnAmbient(false); this.spawnTimer = 0.5; }
      this.trafficTimer -= dt;
      const traffic = this.vehicles.filter((v) => !v.dead).length;
      if (this.trafficTimer <= 0 && traffic < 22) { this.spawnTraffic(false); this.trafficTimer = 1.1; }
      for (const poi of this.world.pois) {
        if (!poi.discovered && U.dist(px, py, poi.x, poi.y) < 150) {
          poi.discovered = true; VAMP.UI.notify('Discovered: ' + poi.label, poi.color); if (VAMP.Audio) VAMP.Audio.play('pickup'); this.onDiscoverPOI(poi);
        }
      }
      if (VAMP.Codex) { const dist = this.world.districtAt(px, py); if (dist) VAMP.Codex.mark(this.player, 'districts', dist.id); }
      // progression-reveal: evaluate locked unlocks once per second
      this._progT = (this._progT || 0) - dt;
      if (this._progT <= 0) { this._progT = 1.0; if (VAMP.Progress) VAMP.Progress.check(this); }
      this.blips = this.blips.filter((b) => (!b.ref || !b.ref.dead) && (!b.ttl || this.time < b.ttl));
    },
    spawnAmbient(initial) {
      const p = this.player;
      const px = p ? (p.inVehicle ? p.inVehicle.x : p.x) : this.world.w / 2;
      const py = p ? (p.inVehicle ? p.inVehicle.y : p.y) : this.world.h / 2;
      let pos = null;
      for (let i = 0; i < 30; i++) {
        const a = Math.random() * U.TAU, d = initial ? U.range(520, 1600) : U.range(700, 1100);
        const x = px + Math.cos(a) * d, y = py + Math.sin(a) * d;
        if (x < 80 || y < 80 || x > this.world.w - 80 || y > this.world.h - 80) continue;
        const t = this.world.tileAt(x, y);
        if (this.world.isWalkable(x, y) && t !== VAMP.World.T.WATER && t !== VAMP.World.T.ROAD) { pos = { x, y }; break; }
      }
      if (!pos) pos = this.world.randomWalkPos(Math.random);
      const dist = this.world.districtAt(pos.x, pos.y);
      const danger = dist ? dist.danger : 0.3;
      let type = 'ped';
      const roll = Math.random();
      const grace = this.time < (this.safeUntil || 0);
      const nearHaven = this.world.pois.some((q) => q.type === 'haven' && U.dist(pos.x, pos.y, q.x, q.y) < 460);
      if (!grace && !nearHaven && roll < danger * 0.16) type = Math.random() < 0.5 ? 'thug' : 'gunner';
      else if (roll < 0.04) type = 'rat';
      const n = VAMP.Npc.create(this.world, type, pos.x, pos.y, {});
      const combat = (type === 'thug' || type === 'gunner');
      if (combat) {
        const sc = 1 + this.player.level * 0.06 + danger * 0.25;
        n.maxHp = Math.round(n.maxHp * sc); n.hp = n.maxHp;
        if (Math.random() < (danger * 0.10 + (this.masquerade ? this.masquerade.stars * 0.03 : 0) + Math.min(0.18, this.player.level * 0.004))) VAMP.Npc.makeElite(n);
        n.dmgMul = (n.dmgMul || 1) * (1 + this.player.level * 0.025);
      }
      this.addNPC(n);
    },
    spawnTraffic(initial) {
      const p = this.player;
      const px = p ? (p.inVehicle ? p.inVehicle.x : p.x) : this.world.w / 2;
      const py = p ? (p.inVehicle ? p.inVehicle.y : p.y) : this.world.h / 2;
      let pos = null;
      for (let i = 0; i < 30; i++) {
        const a = Math.random() * U.TAU, d = initial ? U.range(120, 1200) : U.range(600, 1000);
        const x = px + Math.cos(a) * d, y = py + Math.sin(a) * d;
        if (this.world.isRoad(x, y)) { pos = { x, y }; break; }
      }
      if (!pos) pos = this.world.randomRoadPos(Math.random);
      const types = ['sedan', 'sedan', 'sedan', 'sport', 'sport', 'van', 'hearse', 'police'];
      const vtype = types[(Math.random() * types.length) | 0];
      const v = VAMP.Vehicle.create(this.world, vtype, pos.x, pos.y, {});
      if (vtype !== 'police') v.color = VAMP.Vehicle.TYPES[vtype].colors[(Math.random() * VAMP.Vehicle.TYPES[vtype].colors.length) | 0];
      if (Math.random() < 0.6) { v.driver = VAMP.Npc.create(this.world, 'ped', pos.x, pos.y, {}); v.ai = true; }
      this.addVehicle(v);
    },
    // ---------------------------------------------------------------- render
    render(alpha) {
      const ctx = this.ctx, w = this.w, h = this.h;
      ctx.save();
      const dpr = Math.max(1, Math.min(3, window.devicePixelRatio || 1));   // match loop.js backing-store clamp
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.fillStyle = '#05060a'; ctx.fillRect(0, 0, w, h);
      if (this.mode === 'title') { this.renderTitle(ctx, w, h); VAMP.Input.endFrame(); ctx.restore(); return; }
      this.cam.apply(ctx);
      VAMP.WorldRender.renderGround(ctx, this.cam, this.world, this.time * 1000);
      if (VAMP.DistrictArt) VAMP.DistrictArt.renderParallax(ctx, this.cam, this.world, this);
      if (VAMP.Decals) VAMP.Decals.render(ctx, this.cam, this);
      VAMP.FX.renderBloodPools(ctx, this.cam);
      VAMP.FX.renderDecals(ctx, this.cam);
      if (VAMP.Props) VAMP.Props.renderFlat(ctx, this.cam, this.world, this.time * 1000);
      this.renderPickups(ctx);
      VAMP.WorldRender.renderBuildings(ctx, this.cam, this.world, this.time * 1000);
      // cache player pos once/frame for NPC LOD distance checks
      const _pc = this.player; this._pcx = _pc.inVehicle ? _pc.inVehicle.x : _pc.x; this._pcy = _pc.inVehicle ? _pc.inVehicle.y : _pc.y;
      const drawList = this._drawList || (this._drawList = []);   // reused each frame — no per-frame array alloc
      drawList.length = 0;
      for (const v of this.vehicles) if (this.cam.inView(v.x, v.y, 60)) drawList.push(v);
      for (const n of this.npcs) if (this.cam.inView(n.x, n.y, 40)) drawList.push(n);
      if (VAMP.Props) { const sp = VAMP.Props.standing(); for (let i = 0; i < sp.n; i++) drawList.push(sp.arr[i]); }
      if (!this.player.inVehicle) drawList.push(this.player);
      drawList.sort(byY);
      for (const e of drawList) {
        if (e === this.player) VAMP.Player.render(e, ctx, this);
        else if (e.prop) VAMP.Props.drawStanding(e, ctx, this);
        else if (e.maxSpeed !== undefined) VAMP.Vehicle.render(e, ctx);
        else VAMP.Npc.render(e, ctx, this);
      }
      for (const pr of this.projectiles) if (this.cam.inView(pr.x, pr.y, 30)) VAMP.Projectile.render(pr, ctx);
      VAMP.FX.renderWorld(ctx, this.cam);
      if (VAMP.Stealth) VAMP.Stealth.render(ctx, this);   // crime-scene / investigation rings (world-space)
      this.renderWorldMarkers(ctx);
      this.cam.restore(ctx);
      this.renderLighting(ctx, w, h);
      if (VAMP.PostFX) {
        VAMP.PostFX.districtGrade(ctx, this, w, h);
        VAMP.PostFX.districtLUT(ctx, this, w, h);
        VAMP.PostFX.dawnGrade(ctx, this, w, h);
        VAMP.PostFX.fogGround(ctx, this, w, h);
        VAMP.PostFX.rainWetGround(ctx, this, w, h);
        VAMP.PostFX.frenzyPulse(ctx, this, w, h);
        VAMP.PostFX.feedingFrame(ctx, this, w, h);
        VAMP.PostFX.feedingLetterbox(ctx, this, w, h);
        VAMP.PostFX.heatPulse(ctx, this, w, h);
        VAMP.PostFX.deathDesaturate(ctx, this, w, h);
        VAMP.PostFX.eliteIntro(ctx, this, w, h);
      }
      ctx.drawImage(VAMP.Assets.vignette(w, h, 0.42), 0, 0);
      VAMP.FX.renderScreen(ctx, w, h);
      if (this.quality !== 'low') VAMP.Assets.bloom(ctx, this.canvas, w, h, this.quality === 'medium' ? 0.28 : 0.40);  // #5
      this.renderWeather(ctx, w, h);  // #17
      if (VAMP.PostFX) VAMP.PostFX.filmGrain(ctx, w, h, this.quality === 'high' ? 0.04 : 0.025);
      if (this.mode === 'play') VAMP.UI.render(ctx, this, w, h);
      if (VAMP.Menus.isOpen()) VAMP.Menus.render(ctx, this, w, h);
      if (this.mode === 'dead') this.renderDeath(ctx, w, h);
      VAMP.Input.endFrame();
      ctx.restore();   // matches the DPR-scale save at top of render()
    },
    renderLighting(ctx, w, h) {
      const dk = this.darkness || 0;
      if (dk < 0.02) return;
      const lc = this.lightCtx, cam = this.cam;
      const glow = VAMP.Assets.glow();
      lc.setTransform(1, 0, 0, 1, 0, 0);
      lc.clearRect(0, 0, w, h);
      // player brightness (pause menu): scales the darkness mask so the night reads on any monitor.
      const gm = (this.vol && this.vol.gamma) || 1;
      const darkMul = U.clamp(2 - gm, 0.4, 1.5);   // gamma 1 = unchanged; >1 lifts the mask, <1 deepens it
      lc.fillStyle = 'rgba(7,9,22,' + (0.76 * dk * darkMul) + ')';
      lc.fillRect(0, 0, w, h);
      // carve darkness holes with the baked glow sprite (no per-frame gradients)
      lc.globalCompositeOperation = 'destination-out';
      const count = VAMP.WorldRender.gatherLights(cam, this.world, this.time * 1000);
      const pool = VAMP.WorldRender.lightPool;
      for (let i = 0; i < count; i++) {
        const L = pool[i]; const s = cam.worldToScreen(L.x, L.y); const r = L.r * cam.zoom;
        lc.globalAlpha = 0.95; lc.drawImage(glow, s.x - r, s.y - r, r * 2, r * 2);
      }
      // player vision bubble: a big soft falloff + a tighter near-full carve so the
      // ground you're standing on always reads clearly (chiaroscuro: bright pool, dark beyond).
      const p = this.player; const ps = cam.worldToScreen(p.inVehicle ? p.inVehicle.x : p.x, p.inVehicle ? p.inVehicle.y : p.y);
      const pr = (p.inVehicle ? 260 : 205) * cam.zoom;
      lc.globalAlpha = 0.9; lc.drawImage(glow, ps.x - pr, ps.y - pr, pr * 2, pr * 2);
      const pr2 = pr * 0.52;
      lc.globalAlpha = 0.92; lc.drawImage(glow, ps.x - pr2, ps.y - pr2, pr2 * 2, pr2 * 2);
      for (const proj of this.projectiles) {
        if (!proj.glow) continue;
        const s = cam.worldToScreen(proj.x, proj.y); const r = 60 * cam.zoom;
        lc.globalAlpha = 0.7; lc.drawImage(glow, s.x - r, s.y - r, r * 2, r * 2);
      }
      lc.globalAlpha = 1;
      lc.globalCompositeOperation = 'source-over';
      ctx.drawImage(this.lightCanvas, 0, 0);
      // additive colored NEON pass (signs/beacons/POI/emergency) — bloom (line ~412) catches it
      if (this.quality !== 'low') {
        ctx.save();
        ctx.globalCompositeOperation = 'lighter';
        for (let i = 0; i < count; i++) {
          const L = pool[i]; if (L.addA <= 0.03) continue;
          const s = cam.worldToScreen(L.x, L.y); const r = L.r * cam.zoom * 1.28;
          ctx.globalAlpha = Math.min(0.92, L.addA * 0.6) * dk;
          ctx.drawImage(VAMP.Assets.glowTinted(L.color), s.x - r, s.y - r, r * 2, r * 2);
        }
        for (const proj of this.projectiles) {
          if (!proj.glow) continue;
          const s = cam.worldToScreen(proj.x, proj.y); const r = 46 * cam.zoom;
          ctx.globalAlpha = 0.5 * dk; ctx.drawImage(VAMP.Assets.glowTinted(proj.color || '#ffd24a'), s.x - r, s.y - r, r * 2, r * 2);
        }
        ctx.globalAlpha = 1; ctx.restore();
      }
    },
    renderWorldMarkers(ctx) {
      const m = this.activeMission; if (!m) return;
      const p = this.player; const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
      for (const mk of m.markers) {
        const tx = mk.ref ? mk.ref.x : mk.x, ty = mk.ref ? mk.ref.y : mk.y; if (tx == null) continue;
        ctx.save();
        ctx.globalAlpha = 0.25; ctx.fillStyle = mk.color;
        ctx.beginPath(); ctx.arc(tx, ty, 16, 0, U.TAU); ctx.fill();
        ctx.globalAlpha = 0.5 + 0.3 * Math.sin(this.time * 4);
        ctx.strokeStyle = mk.color; ctx.lineWidth = 3;
        ctx.beginPath(); ctx.arc(tx, ty, 14 + 4 * Math.sin(this.time * 4), 0, U.TAU); ctx.stroke();
        ctx.restore();
        if (!this.cam.inView(tx, ty, 40)) {
          const a = U.angleTo(px, py, tx, ty);
          const sx = px + Math.cos(a) * 180, sy = py + Math.sin(a) * 180;
          ctx.save(); ctx.translate(sx, sy); ctx.rotate(a);
          ctx.fillStyle = mk.color; ctx.beginPath(); ctx.moveTo(14, 0); ctx.lineTo(-6, -8); ctx.lineTo(-6, 8); ctx.closePath(); ctx.fill();
          ctx.restore();
        }
      }
    },
    renderPickups(ctx) {
      for (const pk of this.pickups) {
        const bob = Math.sin(this.time * 4 + pk.x) * 3;
        ctx.save(); ctx.translate(pk.x, pk.y + bob);
        ctx.globalAlpha = 0.5; ctx.fillStyle = pk.color; ctx.beginPath(); ctx.arc(0, -bob, 10, 0, U.TAU); ctx.fill();
        ctx.globalAlpha = 1; ctx.fillStyle = pk.color;
        ctx.font = 'bold 14px Verdana'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillText(pk.glyph, 0, 0); ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic';
        ctx.restore();
      }
    },
    updatePickups(dt) {
      const p = this.player; const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
      for (let i = this.pickups.length - 1; i >= 0; i--) {
        const pk = this.pickups[i];
        if (U.dist(px, py, pk.x, pk.y) < 28) { this.collectPickup(pk); this.pickups.splice(i, 1); }
      }
    },
    collectPickup(pk) {
      const p = this.player;
      if (pk.kind === 'money') { this.addMoney(pk.amount, pk.x, pk.y); }
      else if (pk.kind === 'item') { VAMP.Inventory.addItem(p, pk.item); VAMP.UI.notify('Found ' + pk.item.name, pk.item.color); if (VAMP.Audio) VAMP.Audio.play('pickup'); if (pk.item.relic && VAMP.Codex) VAMP.Codex.mark(p, 'relicsSeen', pk.item.baseName); }
      else if (pk.kind === 'blood') { p.blood = Math.min(p.derived.maxBlood, p.blood + (pk.amount || 25)); VAMP.UI.notify('+vitae', '#ff2f6e'); if (VAMP.Audio) VAMP.Audio.play('drain'); }
      else if (pk.kind === 'relic') { VAMP.Missions.onEvent(this, 'pickup', { mission: pk.mission, pickup: pk }); if (VAMP.Audio) VAMP.Audio.play('pickup'); }
      else { if (VAMP.Audio) VAMP.Audio.play('pickup'); }
    },
    // ---------------------------------------------------------------- API
    spawnProjectile(opts) { this.projectiles.push(VAMP.Projectile.make(opts)); },
    setSlowmo(dur, scale) { this.slowmoT = Math.max(this.slowmoT, dur); this.slowScale = scale != null ? scale : 0.32; },
    hitStop(dur) { if (!this.reducedMotion) this.hitStopT = Math.max(this.hitStopT, dur || 0.06); },  // #7
    addNPC(n) {
      this.npcs.push(n);
      if (n && (n.boss || n.nemesis || n.elite) && VAMP.PostFX) {
        this._eliteFlash = { t: 1.2, max: 1.2 };
      }
      return n;
    },
    addVehicle(v) { this.vehicles.push(v); return v; },
    addPickup(o) { o.kind = o.kind || 'item'; this.pickups.push(o); return o; },
    addBlip(b) { this.blips.push(b); },
    showTip(text) { this._tipText = text; this._tipT = 9; if (VAMP.Audio) VAMP.Audio.play('uiBig'); },        // #15
    showRecap(r) { this._recap = r; this._recapT = 7; if (VAMP.Audio) VAMP.Audio.play('win'); },              // #25
    addMoney(amount, x, y) {
      amount = Math.round(amount);
      this.player.money += amount;
      if (this.night && amount > 0) this.night.money += amount;   // #25
      if (x != null && VAMP.FX) VAMP.FX.number(x, y - 18, cash(amount), '#ffd24a', { small: true });
    },
    nearestNPC(x, y, filter, maxR) {
      let best = null, bd = (maxR || Infinity) * (maxR || Infinity);
      for (const n of this.npcs) {
        if (filter && !filter(n)) continue;
        const d = U.dist2(x, y, n.x, n.y);
        if (d < bd) { bd = d; best = n; }
      }
      return best;
    },
    nearestPOI(x, y, maxR) {
      let best = null, bd = (maxR || 60);
      for (const poi of this.world.pois) { const d = U.dist(x, y, poi.x, poi.y); if (d < bd) { bd = d; best = poi; } }
      return best;
    },
    findPOI(type) { return this.world.pois.find((p) => p.type === type); },
    nearestHaven(x, y, far) {
      const havens = this.world.pois.filter((p) => p.type === 'haven');
      if (!havens.length) return this.walkableNear(this.world.w / 2, this.world.h / 2);
      havens.sort((a, b) => U.dist2(x, y, a.x, a.y) - U.dist2(x, y, b.x, b.y));
      const h = far ? havens[havens.length - 1] : havens[0];
      return this.walkableNear(h.x, h.y + 40);
    },
    walkableNear(x, y) {
      const T = this.world.TILE;
      const c = Math.floor(x / T), r = Math.floor(y / T);
      if (this.world.tileWalkable(c, r)) return { x, y };
      const w = VAMP.Path.nearestWalkable(this.world, c, r, 8);
      if (w) return { x: (w.c + 0.5) * T, y: (w.r + 0.5) * T };
      return { x, y };
    },
    onDiscoverPOI(poi) {
      const p = this.player;
      if (!p.blessings) p.blessings = {};
      if (poi.type === 'power' && !p.blessings[poi.id]) {
        p.blessings[poi.id] = true;
        const pool = [{ pct: { maxHP: 0.05 } }, { pct: { maxBlood: 0.05 } }, { pct: { meleeDmg: 0.05 } }, { pct: { spellPower: 0.05 } }, { add: { critChance: 3 } }, { pct: { moveSpeed: 0.04 } }, { pct: { sunResist: 0.08 } }, { pct: { feedYield: 0.06 } }];
        let hsh = 0; for (let i = 0; i < poi.id.length; i++) hsh = (hsh * 31 + poi.id.charCodeAt(i)) | 0;
        const m = pool[Math.abs(hsh) % pool.length];
        if (!p.blessingMods) p.blessingMods = { add: {}, pct: {} };
        if (m.add) for (const a in m.add) p.blessingMods.add[a] = (p.blessingMods.add[a] || 0) + m.add[a];
        if (m.pct) for (const c2 in m.pct) p.blessingMods.pct[c2] = (p.blessingMods.pct[c2] || 0) + m.pct[c2];
        VAMP.Stats.recompute(p);
        VAMP.UI.banner('PLACE OF POWER', 'A permanent blessing flows into your blood.', '#ffd24a');
        if (VAMP.Audio) VAMP.Audio.play('levelup');
      } else if (poi.type === 'crypt' && !p.blessings[poi.id]) {
        p.blessings[poi.id] = true;
        const rel = VAMP.Inventory.generateRelic(this.player.level);
        this.addPickup({ x: poi.x, y: poi.y + 30, kind: 'item', item: rel, color: rel.color, glyph: rel.glyph });
        const grd = VAMP.Npc.create(this.world, 'hunter', poi.x + 20, poi.y + 20, { hp: 180 + this.player.level * 8 });
        grd.aggro = true; grd.state = 'chase'; grd.hostileToPlayer = true; this.addNPC(grd);
        VAMP.UI.banner('ELDER CRYPT', 'A relic lies within — but its guardian stirs.', '#9a86c4');
      }
    },
    usePOI(poi) {
      poi.discovered = true;
      VAMP.Audio.resume();
      if (poi.type === 'haven' || poi.type === 'bloodbank') { this.inHaven = true; if (VAMP.Progress) VAMP.Progress.reveal(this, 'havenUpgrade'); VAMP.Menus.poi = poi; VAMP.Menus.openScreen('haven'); }
      else if (poi.type === 'market') { VAMP.Menus.poi = poi; if (poi._stockDay !== this.day) { poi._stockDay = this.day; poi._stock = VAMP.Economy.generateStock(this.player.level, 8); } VAMP.Menus.shopStock = poi._stock; VAMP.Menus.shopMode = 'buy'; VAMP.Menus.openScreen('shop'); }
      else if (poi.type === 'board') { if (VAMP.Progress) VAMP.Progress.markSeen(this.player, 'missions'); VAMP.Menus.offers = VAMP.Missions.offers(this); VAMP.Menus.openScreen('board'); }
    },
    fastTravel(poi) {
      if (this.player.inVehicle) VAMP.Vehicle.exit(this.player, this);
      const s = this.walkableNear(poi.x, poi.y + 40);
      this.player.x = s.x; this.player.y = s.y;
      this.cam.snap(this.player.x, this.player.y);
      this._lastFx = undefined;   // re-init camera velocity tracker (avoid a teleport jolt)
      VAMP.UI.notify('Travelled to ' + poi.label, '#9bf');
    },
    convertThrall(npc) {
      const p = this.player;
      const thralls = this.npcs.filter((n) => n.ally && !n.dead);
      // dom_key Iron Will: thralls are permanent — cap = max(normalCap, floor(Influence))
      const ironWill = p.treeNodes && p.treeNodes['dom_key'];
      const normalCap = VAMP.Haven ? VAMP.Haven.thrallCap(p) : (3 + (p.attributes.presence > 6 ? 1 : 0));
      const cap = ironWill
        ? Math.max(normalCap, Math.floor((p.derived && p.derived.influence != null) ? p.derived.influence : 0))
        : normalCap;
      if (thralls.length >= cap) {
        if (ironWill) { if (VAMP.UI) VAMP.UI.notify('Iron Will: cap reached — invest in Presence', '#a88'); return; }
        const oldest = thralls.slice().sort((a, b) => (a.thrallBornT || 0) - (b.thrallBornT || 0))[0];
        if (oldest) { oldest.dead = true; if (VAMP.FX) VAMP.FX.spark(oldest.x, oldest.y, '#5aff8c', 6); }
      }
      npc.ally = true; npc.faction = 'player'; npc.state = 'follow'; npc.aggro = false;
      npc.hp = npc.maxHp; npc.mesmerizedT = 0; npc.innocent = false; npc.thrallBornT = this.time;
      if (!npc.weapon) npc.weapon = 'pistol';
      p.stats.thralls = (p.stats.thralls || 0) + 1;
      if (VAMP.Coterie) VAMP.Coterie.attach(this, npc);
      if (VAMP.Progress) VAMP.Progress.reveal(this, 'thralls');
    },
    onKill(npc, cause) {
      if (cause === 'thrall' && this.player.bloodState) this.player.bloodState.kills++;   // ambient crossfire is NOT the player's kill
      if (this.night && !npc.ally) this.night.kills++;     // #25
      if (this.night && cause === 'feed') this.night.feeds++;
      if (cause === 'thrall' && VAMP.Coterie) { const a = this.nearestNPC(npc.x, npc.y, (n) => n.ally && n.coterieId && !n.dead, 300); if (a) VAMP.Coterie.onAllyKill(this, a); }
      if (cause !== 'feed' && cause !== 'crossfire' && !npc.ally && (npc.faction === 'gang' || npc.faction === 'police' || npc.faction === 'inquis')) {
        const xp = (4 + (npc.threat || 1) * 6) * (1 + this.player.level * 0.08) * (npc.elite ? 1.6 : 1) * (npc.boss ? 3 : 1);
        const res = VAMP.Stats.gainXP(this.player, xp);
        if (res.ups) for (const u of res.ups) this.onLevelUp(u);
      }
      if (npc.bounty) { this.addMoney(npc.bounty, npc.x, npc.y); VAMP.UI.notify('Bounty claimed: ' + cash(npc.bounty), '#ffd24a'); }
      if (npc.baronOf && VAMP.Domains) VAMP.Domains.onBaronDead(this, npc);
      if (!npc.ally) {
        // ambient crossfire (one NPC killing another) is NOT the player's kill — it must not credit
        // Mastery/Codex/Reputation/Legend/Trophies, mirroring the XP guard above. Otherwise a passive
        // player near an auto-spawned gang war silently bleeds faction standing & farms progression.
        if (cause !== 'crossfire') {
          if (VAMP.Mastery) VAMP.Mastery.gain(this.player, (this.player.cloaked || cause === 'feed') ? 'nightstalker' : 'brawn', 3 + (npc.threat || 0));
          if (VAMP.Codex) VAMP.Codex.mark(this.player, 'killedKinds', npc.faction);
          if (VAMP.Reputation) VAMP.Reputation.onKill(this.player, npc, cause);
          if (VAMP.Legend && (npc.boss || npc.elite || npc.faction === 'inquis')) VAMP.Legend.add(this, npc.boss ? 8 : 3);
          if (VAMP.Trophies) VAMP.Trophies.award(this, npc);
        }
        if (VAMP.Nemesis && npc.nemesis) VAMP.Nemesis.onNemesisDead(this.player, npc);   // state cleanup regardless of cause
      }
      this.dropLoot(npc, cause);
      VAMP.Missions.onEvent(this, 'kill', { npc, cause });
      if (npc.ally) VAMP.Missions.onEvent(this, 'npcDead', { npc });
      if (npc.scripted) VAMP.Missions.onEvent(this, 'npcDead', { npc });
    },
    dropLoot(npc, cause) {
      if (npc.animal) return;
      const threat = (npc.threat || 0);
      if (Math.random() < 0.5 + threat * 0.1) {
        const amt = Math.round((6 + threat * 8) * (1 + this.player.level * 0.1) * (0.6 + Math.random()));
        this.addPickup({ x: npc.x + (Math.random() - 0.5) * 14, y: npc.y + (Math.random() - 0.5) * 14, kind: 'money', amount: amt, color: '#ffd24a', glyph: '$' });
      }
      const relicChance = (npc.boss ? 0.5 : 0) + (npc.elite ? 0.06 : 0) + (npc.faction === 'inquis' ? 0.04 : 0);
      if (relicChance > 0 && Math.random() < relicChance) {
        const rel = VAMP.Inventory.generateRelic(this.player.level);
        this.addPickup({ x: npc.x, y: npc.y, kind: 'item', item: rel, color: rel.color, glyph: rel.glyph });
        VAMP.UI.notify('A Relic glimmers in the gore...', '#ff7a30');
      }
      const itemChance = 0.06 + threat * 0.05 + (npc.vip ? 0.4 : 0) + (npc.boss ? 0.9 : 0) + (npc.elite ? 0.5 : 0);
      if (Math.random() < itemChance) {
        const it = VAMP.Inventory.generate(this.player.level + (npc.boss ? 3 : 0), VAMP.Inventory.rollRarity(this.player.level, threat * 0.04 + (npc.boss ? 0.4 : 0) + (npc.elite ? 0.25 : 0)));
        this.addPickup({ x: npc.x, y: npc.y, kind: 'item', item: it, color: it.color, glyph: it.glyph });
      }
      if ((npc.faction === 'inquis') && Math.random() < 0.5) this.addPickup({ x: npc.x + 10, y: npc.y, kind: 'blood', amount: 30, color: '#ff2f6e', glyph: 'h' });
    },
    feedEvent(info) {
      if (this.player.bloodState.fedCount >= 1) this.tutorialGoal = null;
      VAMP.Missions.onEvent(this, 'feed', { lethal: info.lethal });
      if (info.ups && info.ups.length) for (const u of info.ups) this.onLevelUp(u);
      // feeding on faction members frays those relationships (you're taking their people)
      if (VAMP.Reputation && info.npc) {
        const f = info.npc.faction;
        if (f === 'police') VAMP.Reputation.change(this.player, 'police', -1);
        else if (f === 'gang') VAMP.Reputation.change(this.player, 'gang', -0.5);
      }
    },
    onLevelUp(u) {
      VAMP.UI.banner('LEVEL ' + u.level, '+' + u.attrPoints + ' attribute pts, +' + u.skillPoints + ' skill pt' + (u.skillPoints > 1 ? 's' : ''), '#b07bff');
      if (VAMP.Audio) VAMP.Audio.play('levelup');
      if (this.cam) { this.cam.shake(3, 0.3); this.cam.punch(0.06); }   // #19
      VAMP.FX.ring(this.player.x, this.player.y, 70, '#b07bff');
      // Guarantee: by level 8 the player has a named nemesis — if none yet, spawn a herald hunter who will definitely flee
      if (u.level === 8 && VAMP.Nemesis && (!this.player.nemeses || !this.player.nemeses.length)) {
        const p = this.player, ox = p.x, oy = p.y;
        let pos = null;
        for (let i = 0; i < 40; i++) { const a = Math.random() * 6.283, d = 420 + Math.random() * 260; const x = ox + Math.cos(a) * d, y = oy + Math.sin(a) * d; if (this.world.isWalkable(x, y)) { pos = { x, y }; break; } }
        if (pos) {
          const h = VAMP.Npc.create(this.world, 'hunter', pos.x, pos.y, { hp: 160 + p.level * 6 });
          h.aggro = true; h.state = 'chase'; h.hostileToPlayer = true; h._guaranteedNemesis = true;
          this.addNPC(h); this.addBlip({ ref: h, color: '#ff5a5a', kind: 'event' });
          setTimeout(() => { if (VAMP.UI) VAMP.UI.banner('A HUNTER WATCHES YOU', 'Someone has been tracking you. End this before it becomes personal.', '#ff5a5a'); }, 2400);
        }
      }
    },
    onHijack(v) { VAMP.UI.notify('Hijacked a ' + v.type + '!', '#9bf'); if (v.driver && v.driver.dead === false) { v.driver.dead = true; } if (VAMP.Mastery) VAMP.Mastery.gain(this.player, 'driving', 4); },
    onDawn() {
      const p = this.player; if (!p || p.dead) return;
      const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
      const safe = this.inHaven || p.inVehicle || this.nearShade(px, py);
      if (safe) {
        const bs = p.bloodState;
        bs.dawnStreak = (bs.dawnStreak || 0) + 1;
        // capture income per source for the dawn ledger
        const _z = { cash: 0, vitae: 0 };
        const titheR = (VAMP.Domains && VAMP.Domains.collectTithe) ? VAMP.Domains.collectTithe(this) : _z;
        const bizR   = (VAMP.Business && VAMP.Business.collect)    ? VAMP.Business.collect(this)    : _z;
        const jobsR  = (VAMP.Coterie  && VAMP.Coterie.collectJobs) ? VAMP.Coterie.collectJobs(this) : _z;
        let cashN = titheR.cash + bizR.cash + jobsR.cash;
        let vitae = titheR.vitae + bizR.vitae + jobsR.vitae;
        if (cashN) this.addMoney(cashN, px, py);
        if (vitae && VAMP.Haven) VAMP.Haven.depositVitae(p, vitae);
        // upkeep: domains cost bribes; thralls cost vitae — the empire has a price
        let upkeepCash = 0, upkeepVitae = 0;
        if (VAMP.Domains && VAMP.Domains.domainUpkeep) { const r = VAMP.Domains.domainUpkeep(this); upkeepCash += r.cash; }
        if (VAMP.Coterie && VAMP.Coterie.wagesUpkeep) { const r = VAMP.Coterie.wagesUpkeep(this); upkeepVitae += r.vitae; }
        if (upkeepCash > 0) {
          p.money = Math.max(0, p.money - upkeepCash);
          if (VAMP.FX && upkeepCash > 20) VAMP.FX.number(px, py - 30, '-$' + upkeepCash + ' upkeep', '#a88', { small: true });
        }
        if (upkeepVitae > 0 && VAMP.Haven) {
          const cellar = (p.haven && p.haven.cellarVitae) || 0;
          const paidFromCellar = Math.min(cellar, upkeepVitae);
          VAMP.Haven.depositVitae(p, -paidFromCellar);
          const deficit = upkeepVitae - paidFromCellar;
          if (deficit > 0) {
            // can't pay — loyalty bleeds for all members
            if (p.coterie) for (const m of p.coterie) { m.loyalty = Math.max(0, m.loyalty - 8); }
            if (VAMP.UI) VAMP.UI.notify('Not enough vitae — coterie loyalty suffers (−8)', '#a66');
          }
        }
        // terror decays each dawn — the night's violence fades from collective memory
        if (this.districtState) for (const id in this.districtState) { const ds = this.districtState[id]; if (ds.terror > 0) ds.terror = Math.max(0, ds.terror - 0.12); }
        const sb = Math.min(0.3, bs.dawnStreak * 0.03);
        p.buffs = p.buffs.filter((b) => b.id !== 'dawn_streak');
        p.addBuff({ id: 'dawn_streak', name: 'Survived the Dawn', dur: 9999, color: '#ffd24a', mods: { pct: { xpMult: sb, feedYield: sb } } });
        // per-source ledger for the recap card
        const lootC = (this.night && this.night.money) || 0;
        const netC = cashN + lootC - upkeepCash;
        const netV = Math.round(vitae) - upkeepVitae;
        const incParts = [titheR.cash && 'Tithe ' + cash(titheR.cash), bizR.cash && 'Fronts ' + cash(bizR.cash), jobsR.cash && 'Jobs ' + cash(jobsR.cash), lootC && 'Loot ' + cash(lootC)].filter(Boolean);
        const expParts = [upkeepCash && '-' + cash(upkeepCash) + ' upkeep', upkeepVitae && '-' + upkeepVitae + ' vitae wages'].filter(Boolean);
        this.showRecap({   // #25
          title: 'NIGHT ' + (this.day - 1) + ' BANKED',
          lines: [
            'Streak: ' + bs.dawnStreak + '   Kills: ' + (this.night && this.night.kills || 0) + '   Feeds: ' + (this.night && this.night.feeds || 0),
            incParts.length ? 'Income: ' + incParts.join('  ') : null,
            expParts.length ? 'Expenses: ' + expParts.join('  ') : null,
            'Net: ' + cash(netC) + (netV > 0 ? '   +' + netV + ' vitae' : '') + '   Level ' + p.level + '   ' + (VAMP.Domains ? VAMP.Domains.ownedCount(this) : 0) + ' domains',
          ].filter(Boolean),
          color: '#ffd24a',
        });
        VAMP.UI.banner('NIGHT ' + (this.day - 1) + ' BANKED', 'Streak ' + bs.dawnStreak + (netC ? '  Net ' + cash(netC) : '') + (netV > 0 ? '  +' + netV + ' vitae' : '') + '. Rest until dusk.', '#ffd24a');
        this.night = { kills: 0, feeds: 0, money: 0 };
      } else if (p.bloodState.dawnStreak) {
        p.bloodState.dawnStreak = 0;
        p.buffs = p.buffs.filter((b) => b.id !== 'dawn_streak'); VAMP.Stats.recompute(p);
        VAMP.UI.notify('Caught in the open at dawn — streak lost! Seek shade.', '#ff6a6a');
      }
    },
    onPlayerDeath(opts) {
      if (this.mode === 'dead') return;
      this.mode = 'dead'; this.deathT = 0;
      this.player.dead = true;
      if (this.difficulty === 'hard') {
        // Bloodhunt: death costs 1 permanent Humanity (irrecoverable)
        VAMP.Blood.adjustHumanity(this.player, -1, 'death on The Bloodhunt — the soul frays');
      }
      if (VAMP.Audio) { VAMP.Audio.play('death'); if (VAMP.Audio.unduck) VAMP.Audio.unduck(); }
      VAMP.FX.flash('rgba(120,0,0,0.5)', 1);
    },
    respawn() {
      const p = this.player;
      const hv = this.nearestHaven(p.x, p.y, true);   // rise ELSEWHERE — away from whatever killed you
      p.dead = false;
      p.bloodState.frenzied = false; p.bloodState.frenzy = 0; p.bloodState.hunger = 2;
      p.x = hv.x; p.y = hv.y; p.inVehicle = null; p.feeding = null;
      p.buffs = []; p.toggles = {}; p.cloaked = false; p.status = {};
      p.finisher = null; p.pounce = null; this._lastFx = undefined;
      VAMP.Stats.recompute(p);
      p.hp = p.derived.maxHP; p.blood = p.derived.maxBlood * (VAMP.Haven ? VAMP.Haven.respawnBlood(p) : 0.5);
      p.invuln = 3;                                   // brief shield so you can get your bearings
      this.masquerade.clearAll();                     // wanted level fully cleared (GTA-style)
      // call off the hunt: despawn responders, drop everyone else's aggro
      for (const n of this.npcs) {
        if (n.responder) { n.dead = true; continue; }
        if (!n.ally && (n.state === 'chase' || n.state === 'attack')) { n.aggro = false; n.hostileToPlayer = false; n.state = 'wander'; n.path = null; }
      }
      this.safeUntil = this.time + 25;                // grace before any new responders
      const lost = Math.round(p.money * (VAMP.Haven ? VAMP.Haven.deathPenalty(p) : 0.2)); p.money -= lost;
      this.cam.snap(p.x, p.y);
      this.mode = 'play';
      VAMP.UI.notify('You rise at a distant haven — the hunt thrown off. Lost ' + cash(lost) + '.', '#e0a0b8');
      if (this.activeMission) VAMP.Missions.abandon(this);
    },
    toTitle() { this.mode = 'title'; VAMP.Menus.close(); },
    // ---------------------------------------------------------------- screens
    renderTitle(ctx, w, h) {
      if (VAMP.ArtFlags && VAMP.ArtFlags.useTitleArt && VAMP.Assets.ready && VAMP.Assets.has('title_bg')) {
        ctx.drawImage(VAMP.Assets.get('title_bg'), 0, 0, w, h);
        ctx.fillStyle = 'rgba(5,6,10,0.45)'; ctx.fillRect(0, 0, w, h);
      } else {
        ctx.drawImage(VAMP.Assets.starfield(w, h, 220), 0, 0);
        ctx.fillStyle = '#0a0810';
        const rng = U.makeRNG(99);
        let x = 0; while (x < w) { const bw = rng.int(30, 80), bh = rng.int(60, 240); ctx.fillRect(x, h - bh, bw, bh); x += bw + 4; }
        ctx.fillStyle = '#e8e0d0'; ctx.beginPath(); ctx.arc(w * 0.78, h * 0.24, 60, 0, U.TAU); ctx.fill();
        ctx.fillStyle = '#05060a'; ctx.beginPath(); ctx.arc(w * 0.80, h * 0.22, 56, 0, U.TAU); ctx.fill();
      }
      ctx.textAlign = 'center';
      ctx.fillStyle = '#c0303a'; ctx.font = 'bold 76px Georgia, serif';
      ctx.fillText('VAMPIRE CITY', w / 2, h * 0.34);
      ctx.fillStyle = '#9a8'; ctx.font = 'italic 18px Georgia, serif';
      ctx.fillText('Feed on the night. Grow in power. Rule the Damned.', w / 2, h * 0.40);
      ctx.textAlign = 'left';
      if (!this._clan) this._clan = 'brujah';
      const clans = [
        ['brujah',   'Brujah',   'Rebels — Potence & Celerity'],
        ['gangrel',  'Gangrel',  'Feral — Protean & claws'],
        ['tremere',  'Tremere',  'Blood Sorcerers — spells'],
        ['ventrue',  'Ventrue',  'Lords — Dominate'],
        ['toreador', 'Toreador', 'Swift, beguiling — Celerity'],
        ['nosferatu','Nosferatu','Hidden — Obfuscate stealth'],
        ['malkavian','Malkavian','Seers — Auspex & madness'],
      ];


      // ---- Layout: single row if wide (≥900px), 4+3 stacked if narrow ----------
      // Wide:   7 cards × 92px + gaps.  Narrow: 4+3 rows × 80px cards.
      // Card heights are tuned so the downstream chain (diffY→slotY→byy→action btns)
      // always fits inside the viewport:
      //   bottom = startY + totalH + 176  (diffY+10, slotY+48, byy+58, btns+46+14)
      //   => startY = h - totalH - 176 - 18  (18px bottom gutter) at the tightest.
      // Wide cards: 92w × 122h + 26 nameZone → totalH=148, startY≥0.43h OK at any h≥600
      // Narrow cards: 80w × 108h + 24 nameZone → totalH=272+8=280, startY≥h-474 OK at h≥720
      const useWideRow = (w >= 900);
      const cw = useWideRow ? 92 : 80;
      const ch = useWideRow ? 122 : 108;
      const cgap = 8;
      const nameZone = useWideRow ? 26 : 24;
      const rows3 = useWideRow ? 1 : 2;
      const totalH = rows3 * (ch + nameZone) + (rows3 > 1 ? cgap : 0);
      // Place startY so the full stack fits; never push above the subtitle (h*0.42)
      // downstream chain: diffY = startY+totalH+10, slotY=diffY+48, byy=slotY+58, bottom=byy+46+14
      // => bottom = startY + totalH + 176
      let startY = h * 0.43;
      const projectedBottom = startY + totalH + 176;
      if (projectedBottom > h - 18) {
        startY -= (projectedBottom - (h - 18));
        // floor: don't go so high that 'CHOOSE YOUR CLAN' overlaps the subtitle,
        // but only if there's actually room — prefer buttons on-screen over label separation
        if (startY < h * 0.40 + 8 && (h - totalH - 176 - 18) >= h * 0.40 + 8) startY = h * 0.40 + 8;
      }

      ctx.font = 'bold 11px Georgia, serif'; ctx.textAlign = 'center'; ctx.fillStyle = '#b8a8c0';
      ctx.fillText('CHOOSE YOUR CLAN', w / 2, startY - 8);

      const mcc = VAMP.Input.mouse;
      for (let i = 0; i < clans.length; i++) {
        // 4+3 layout: row 0 = 4 cards, row 1 = 3 cards, each row centred independently
        const row3 = useWideRow ? 0 : ((i < 4) ? 0 : 1);
        const rowCount = useWideRow ? 7 : (row3 === 0 ? 4 : 3);
        const posInRow = useWideRow ? i : (row3 === 0 ? i : i - 4);
        const rowTotalW = rowCount * cw + (rowCount - 1) * cgap;
        const bx = w / 2 - rowTotalW / 2 + posInRow * (cw + cgap);
        const by = startY + row3 * (ch + nameZone + cgap);
        const sel = this._clan === clans[i][0];
        const over = (mcc.x >= bx && mcc.x <= bx + cw && mcc.y >= by && mcc.y <= by + ch + nameZone);
        const clicked = drawClanCard(ctx, bx, by, cw, ch, clans[i][0], clans[i][1], clans[i][2], sel, over, this.time);
        if (clicked) { this._clan = clans[i][0]; if (VAMP.Audio) VAMP.Audio.play('ui'); }
      }
      if (!this._difficulty) this._difficulty = 'normal';
      if (!this._saveSlot) this._saveSlot = 0;
      // ---- difficulty selector
      const diffY = startY + totalH + 10;
      ctx.fillStyle = '#cdd'; ctx.font = 'bold 11px Verdana'; ctx.textAlign = 'center';
      ctx.fillText('DIFFICULTY', w / 2, diffY - 2);
      const diffs = [['normal', 'Danse Macabre (Normal)'], ['easy', 'The Masquerade (Easy)'], ['hard', 'The Bloodhunt (Hard)']];
      const dw = 188, dg = 6;
      const totalDW = diffs.length * dw + (diffs.length - 1) * dg;
      for (let di = 0; di < diffs.length; di++) {
        const dx = w / 2 - totalDW / 2 + di * (dw + dg);
        const dsel = this._difficulty === diffs[di][0];
        if (VAMP.Menus.btn(ctx, dx, diffY + 6, dw, 28, diffs[di][1], { color: dsel ? 'rgba(120,40,70,0.95)' : 'rgba(20,14,24,0.8)', accent: dsel ? '#ff7a9a' : null, font: 'bold 11px' })) this._difficulty = diffs[di][0];
      }
      // ---- save slot selector
      const slotY = diffY + 48;
      ctx.fillStyle = '#cdd'; ctx.font = 'bold 11px Verdana'; ctx.textAlign = 'center';
      ctx.fillText('SAVE SLOT', w / 2, slotY - 2);
      const sw2 = 120, sg2 = 8, totalSW = 3 * sw2 + 2 * sg2;
      const m2 = VAMP.Input.mouse;
      for (let si = 0; si < 3; si++) {
        const sx = w / 2 - totalSW / 2 + si * (sw2 + sg2), sy = slotY + 6, sh2 = 38;
        const summary = VAMP.Save.getSlotSummary ? VAMP.Save.getSlotSummary(si) : null;
        const ssel = this._saveSlot === si;
        ctx.fillStyle = ssel ? 'rgba(140,40,70,0.9)' : (summary ? 'rgba(24,16,28,0.9)' : 'rgba(12,8,16,0.7)');
        ctx.fillRect(sx, sy, sw2, sh2);
        ctx.strokeStyle = ssel ? '#c0506a' : 'rgba(160,120,140,0.3)'; ctx.lineWidth = 1.2; ctx.strokeRect(sx + 0.5, sy + 0.5, sw2 - 1, sh2 - 1);
        ctx.textAlign = 'center';
        ctx.fillStyle = '#aaa'; ctx.font = '9px Verdana'; ctx.fillText('SLOT ' + (si + 1), sx + sw2 / 2, sy + 12);
        if (summary) {
          ctx.fillStyle = '#f0e0ec'; ctx.font = 'bold 10px Verdana';
          ctx.fillText(summary.clan[0].toUpperCase() + summary.clan.slice(1) + ' L' + summary.level, sx + sw2 / 2, sy + 25);
          ctx.fillStyle = '#998'; ctx.font = '9px Verdana';
          ctx.fillText('Night ' + summary.day, sx + sw2 / 2, sy + 36);
        } else {
          ctx.fillStyle = '#554'; ctx.font = '10px Verdana'; ctx.fillText('— empty —', sx + sw2 / 2, sy + 27);
        }
        if (m2.x >= sx && m2.x <= sx + sw2 && m2.y >= sy && m2.y <= sy + sh2 && m2.pressed) { this._saveSlot = si; if (VAMP.Audio) VAMP.Audio.play('ui'); }
      }
      // ---- action buttons
      const byy = slotY + 58;
      const slotSummary = VAMP.Save.getSlotSummary ? VAMP.Save.getSlotSummary(this._saveSlot) : null;
      if (VAMP.Menus.btn(ctx, w / 2 - 160, byy, 150, 46, 'NEW NIGHT', { color: 'rgba(120,20,40,0.95)', font: 'bold 16px' })) { VAMP.Save.migrateLegacy && VAMP.Save.migrateLegacy(); this.newGame(0, this._clan, this._saveSlot, this._difficulty); }
      const canContinue = !!(VAMP.Save.hasSaveSlot ? VAMP.Save.hasSaveSlot(this._saveSlot) : VAMP.Save.hasSave());
      if (VAMP.Menus.btn(ctx, w / 2 + 10, byy, 150, 46, 'CONTINUE', { disabled: !canContinue, font: 'bold 16px' })) { const d = VAMP.Save.loadSlot ? VAMP.Save.loadSlot(this._saveSlot) : VAMP.Save.load(); if (d) this.loadGame(d, this._saveSlot); }
      ctx.textAlign = 'right'; ctx.fillStyle = 'rgba(255,255,255,0.28)'; ctx.font = '10px Verdana';
      ctx.fillText('v' + GAME_VERSION, w - 8, h - 8);
      ctx.textAlign = 'center'; ctx.fillStyle = 'rgba(255,255,255,0.4)'; ctx.font = '11px Verdana';
      ctx.fillText('WASD / arrows move · SPACE attack · DBL-TAP direction to DASH · RMB free-aim · F feed · E interact · Shift sprint · X sneak · Ctrl pounce · 1-8 powers · C char · M map · F11 fullscreen', w / 2, h - 10);
      ctx.textAlign = 'left';
      if (VAMP.Input.mouse.pressed) VAMP.Audio.resume();
    },
    renderDeath(ctx, w, h) {
      ctx.fillStyle = 'rgba(20,0,4,' + Math.min(0.7, this.deathT) + ')'; ctx.fillRect(0, 0, w, h);
      ctx.textAlign = 'center';
      ctx.fillStyle = '#c0303a'; ctx.font = 'bold 56px Georgia, serif';
      ctx.fillText('YOU FALL', w / 2, h * 0.26);
      const p = this.player;
      const humanity = p ? p.bloodState.humanity : 5;
      const night = this.night || { kills: 0, feeds: 0, money: 0 };
      const legendTitle = p && VAMP.Legend && VAMP.Legend.titleFor ? VAMP.Legend.titleFor(p.legend) : 'Fledgling';
      const epitaphs = [
        'There is only the Beast. And now, the Beast has fallen.', // H 0
        'You had already lost yourself. This was just the end.',   // H 1
        'The darkness you fed grew hungry. Tonight it fed on you.',// H 2
        'The Beast took its due. It always does.',                 // H 3-4
        'You walked the edge of the Abyss. Tonight it claimed you.', // H 5-6
        'The city does not forget its predators. It only waits.',  // H 7-8
        'Even the mighty fall. The night is patient.',             // H 9-10
      ];
      const epitaphIdx = Math.min(6, Math.max(0, humanity <= 0 ? 0 : humanity <= 2 ? 1 : humanity <= 3 ? 2 : humanity <= 4 ? 3 : humanity <= 6 ? 4 : humanity <= 8 ? 5 : 6));
      ctx.fillStyle = '#9a8'; ctx.font = 'italic 14px Georgia, serif';
      ctx.fillText(epitaphs[epitaphIdx], w / 2, h * 0.33);
      if (this.deathT > 0.7) {
        const sw = 380, sh = 108, sx = w / 2 - sw / 2, sy = h * 0.38;
        ctx.fillStyle = 'rgba(12,8,16,0.88)'; ctx.fillRect(sx, sy, sw, sh);
        ctx.strokeStyle = 'rgba(192,48,58,0.45)'; ctx.lineWidth = 1; ctx.strokeRect(sx + 0.5, sy + 0.5, sw - 1, sh - 1);
        const rows = [
          ['NIGHT', this.day || 1, 'LEGEND', legendTitle],
          ['KILLS', night.kills || 0, 'FEEDS', night.feeds || 0],
          ['MISSIONS', this.missionsDone || 0, 'HUMANITY', humanity + ' / 10'],
        ];
        for (let r = 0; r < rows.length; r++) {
          for (let c = 0; c < 2; c++) {
            const lx = sx + 20 + c * (sw / 2), ly = sy + 22 + r * 30;
            ctx.fillStyle = '#776'; ctx.font = '9px Verdana'; ctx.textAlign = 'left'; ctx.fillText(String(rows[r][c * 2]).toUpperCase(), lx, ly);
            ctx.fillStyle = '#f0e6ee'; ctx.font = 'bold 13px Verdana'; ctx.fillText(String(rows[r][c * 2 + 1]), lx, ly + 14);
          }
        }
        if (p && p.nemeses && p.nemeses.length) {
          ctx.fillStyle = '#c79bff'; ctx.font = 'italic 10px Verdana'; ctx.textAlign = 'center';
          ctx.fillText(p.nemeses[0].name + ' watches from the shadows.', w / 2, sy + sh - 10);
        }
      }
      if (this.deathT > 1.2) {
        const pct = Math.round((VAMP.Haven ? VAMP.Haven.deathPenalty(this.player) : 0.2) * 100);
        const bw = 320, bx = w / 2 - bw / 2;
        if (VAMP.Menus.btn(ctx, bx, h * 0.68, bw, 48, 'RISE AGAIN  ·  lose ' + pct + '% money', { color: 'rgba(120,20,40,0.95)', font: 'bold 15px' })) this.respawn();
        if (VAMP.Menus.btn(ctx, bx, h * 0.68 + 56, bw, 40, 'Quit to Title (saves)')) { VAMP.Save.save(this); this.toTitle(); }
        ctx.fillStyle = 'rgba(255,255,255,0.4)'; ctx.font = '11px Verdana'; ctx.textAlign = 'center';
        ctx.fillText('You will rise at a distant haven, your wanted level cleared.', w / 2, h * 0.68 + 112);
      }
      ctx.textAlign = 'left';
      VAMP.Input.endFrame();
    },
  };
  Game.VERSION = GAME_VERSION;
  VAMP.Game = Game;
})();
