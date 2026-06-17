/* =========================================================================
 * VAMPIRE CITY — ui/hud.js  (VAMP.UI)
 * On-screen HUD: vitals, hunger, humanity, ability hotbar, minimap radar,
 * heat stars, clock/district, mission tracker, prompts, toasts & banners.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  const UI = {
    notifications: [],
    bannerObj: null,
    minimap: null, mmScale: 1,
    prompt_: '',
    flashLowT: 0,
    tweens: U.Tweener(),      // #2 — animated values (money roll-up, banners)
    displayMoney: 0,          // #2 — tweened money for a satisfying roll-up

    notify(text, color) {
      // dedupe: a repeat refreshes its timer and bumps a ×N counter instead of stacking
      const ex = this.notifications.find((n) => n.text === text);
      if (ex) { ex.t = ex.max; ex.count = (ex.count || 1) + 1; ex.color = color || ex.color; return; }
      this.notifications.unshift({ text, color: color || '#ccd', t: 4.0, max: 4.0, count: 1 });
      if (this.notifications.length > 5) this.notifications.pop();
    },
    banner(title, sub, color) { this.bannerObj = { title, sub: sub || '', color: color || '#c79bff', t: 4, max: 4 }; },

    buildMinimap(world) {
      const scale = 300 / world.w; // full-city minimap ~300px
      this.mmScale = scale;
      const c = VAMP.Assets.makeCanvas(world.w * scale, world.h * scale);
      const g = c.getContext('2d');
      const T = VAMP.World.T;
      g.fillStyle = '#0a0a10'; g.fillRect(0, 0, c.width, c.height);
      const canvases = VAMP.Assets.patterns && VAMP.Assets.patterns._canvas;
      const useArt = VAMP.ArtFlags && VAMP.ArtFlags.useBitmapGround && VAMP.Assets.ready && canvases;
      const step = useArt ? 1 : 2;
      for (let r = 0; r < world.rows; r += step) {
        for (let cx = 0; cx < world.cols; cx += step) {
          const t = world.tile[world.idx(cx, r)];
          const px = cx * world.TILE * scale;
          const py = r * world.TILE * scale;
          const pw = world.TILE * scale * step + 1;
          const ph = world.TILE * scale * step + 1;
          if (useArt && (t === T.ROAD || t === T.SIDEWALK) && canvases[t === T.ROAD ? 'asphalt' : 'sidewalk']) {
            const tile = canvases[t === T.ROAD ? 'asphalt' : 'sidewalk'];
            g.drawImage(tile, 0, 0, tile.width, tile.height, px, py, pw, ph);
          } else {
            let col = null;
            if (t === T.ROAD) col = '#2a2a34';
            else if (t === T.SIDEWALK) col = '#34343f';
            else if (t === T.WATER) col = '#10283f';
            else if (t === T.GRASS) col = '#16321f';
            else col = '#1b1b22';
            g.fillStyle = col;
            g.fillRect(px, py, pw, ph);
          }
        }
      }
      g.fillStyle = '#34343f';
      for (const b of world.buildings) g.fillRect(b.x * scale, b.y * scale, Math.max(1, b.w * scale), Math.max(1, b.h * scale));
      this.minimap = c;
    },

    update(dt) {
      for (let i = this.notifications.length - 1; i >= 0; i--) { this.notifications[i].t -= dt; if (this.notifications[i].t <= 0) this.notifications.splice(i, 1); }
      if (this.bannerObj) { this.bannerObj.t -= dt; if (this.bannerObj.t <= 0) this.bannerObj = null; }
    },

    render(ctx, game, w, h) {
      const p = game.player;
      ctx.save();
      ctx.textBaseline = 'alphabetic';

      // ---- low-health vignette ----
      if (p.hp / p.derived.maxHP < 0.3) {
        const a = (1 - p.hp / p.derived.maxHP / 0.3) * 0.35 * (0.6 + 0.4 * Math.sin(game.time * 6));
        ctx.fillStyle = `rgba(120,0,0,${a})`;
        ctx.fillRect(0, 0, w, h);
      }
      if (p.bloodState.frenzied) { ctx.fillStyle = `rgba(110,0,16,${0.12 + 0.06 * Math.sin(game.time * 8)})`; ctx.fillRect(0, 0, w, h); }
      if (p.feeding) { const fi = U.clamp(p.feeding.drained / (p.feeding.vt.yield * 1.55), 0, 1); ctx.fillStyle = `rgba(120,0,22,${0.10 + fi * 0.16 + 0.03 * Math.sin(game.time * 10)})`; ctx.fillRect(0, 0, w, h); }

      this.drawVitals(ctx, game, p);
      this.drawBuffs(ctx, game, p);                       // #4 — buff/debuff icon bar with timers
      this.drawHotbar(ctx, game, p, w, h);
      this.drawMinimap(ctx, game, p, w);
      this.drawTopRight(ctx, game, w);
      if (game.timeOfDay && game.timeOfDay.day) this.drawSun(ctx, game, w, h);
      this.drawBossBar(ctx, game, w, h);                 // #13 — phased boss health bar
      this.drawMission(ctx, game, w, h);
      this.drawContextTip(ctx, game, w, h);              // #15 — dismissible first-use tips
      this.drawRecap(ctx, game, w, h);                   // #25 — dawn/death session recap
      this.computePrompt(ctx, game, p, w, h);
      this.drawDamageDir(ctx, game, w, h);               // #16 — direction of incoming hits
      this.drawToasts(ctx, w, h);
      this.drawBanner(ctx, w, h);
      this.drawHudTip(ctx, game, w, h);                  // #4 — buff hover tip

      ctx.restore();
    },

    // #16 — red arcs at the screen edge pointing toward where damage came from
    drawDamageDir(ctx, game, w, h) {
      const dirs = game._dmgDirs;
      if (!dirs || !dirs.length) return;
      const cx = w / 2, cy = h / 2, rad = Math.min(w, h) * 0.32;
      for (let i = dirs.length - 1; i >= 0; i--) {
        const d = dirs[i];
        d.t -= 0.016; // approx per-frame; HUD updates every frame anyway
        if (d.t <= 0) { dirs.splice(i, 1); continue; }
        const a = U.clamp(d.t / d.max, 0, 1);
        const ex = cx + Math.cos(d.ang) * rad, ey = cy + Math.sin(d.ang) * rad;
        ctx.save();
        ctx.globalAlpha = a * 0.85;
        ctx.strokeStyle = '#ff3030'; ctx.lineWidth = 6;
        ctx.lineCap = 'round';
        ctx.beginPath(); ctx.arc(cx, cy, rad, d.ang - 0.22, d.ang + 0.22); ctx.stroke();
        ctx.fillStyle = '#ff5050';
        ctx.beginPath(); ctx.moveTo(ex + Math.cos(d.ang) * 8, ey + Math.sin(d.ang) * 8); ctx.lineTo(ex + Math.cos(d.ang + 2.4) * 14, ey + Math.sin(d.ang + 2.4) * 14); ctx.lineTo(ex + Math.cos(d.ang - 2.4) * 14, ey + Math.sin(d.ang - 2.4) * 14); ctx.closePath(); ctx.fill();
        ctx.restore();
      }
    },

    // #25 — a centered session recap card (dawn/death summary)
    drawRecap(ctx, game, w, h) {
      const r = game._recap; if (!r || game._recapT <= 0) return;
      const a = U.clamp(Math.min(game._recapT, 0.6) * 1.7, 0, 1);
      ctx.save(); ctx.globalAlpha = a;
      const lines = r.lines || [];
      ctx.font = 'bold 22px Georgia, serif'; const titleW = ctx.measureText(r.title).width;
      ctx.font = '13px Verdana'; let maxW = titleW; for (const l of lines) maxW = Math.max(maxW, ctx.measureText(l).width);
      const bw = maxW + 48, bh = 50 + lines.length * 20; const bx = (w - bw) / 2, by = h * 0.30;
      ctx.fillStyle = 'rgba(10,7,14,0.96)'; this.rr(ctx, bx, by, bw, bh, 8); ctx.fill();
      ctx.strokeStyle = r.color || '#ffd24a'; ctx.lineWidth = 2; this.rr(ctx, bx + 0.5, by + 0.5, bw - 1, bh - 1, 8); ctx.stroke();
      ctx.fillStyle = r.color || '#ffd24a'; ctx.font = 'bold 22px Georgia, serif'; ctx.textAlign = 'center';
      ctx.fillText(r.title, w / 2, by + 32);
      ctx.fillStyle = '#e8e0e8'; ctx.font = '13px Verdana';
      let ly = by + 56; for (const l of lines) { ctx.fillText(l, w / 2, ly); ly += 20; }
      ctx.textAlign = 'left';
      ctx.restore();
    },

    // #15 — a dismissible contextual tip panel
    drawContextTip(ctx, game, w, h) {
      if (!game._tipText || game._tipT <= 0) return;
      const a = U.clamp(Math.min(game._tipT, 0.5) * 2, 0, 1);
      ctx.save(); ctx.globalAlpha = a;
      ctx.font = '12px Verdana';
      const tw = ctx.measureText(game._tipText).width;
      const bw = tw + 40, bh = 44; const bx = (w - bw) / 2, by = h - 150;
      ctx.fillStyle = 'rgba(14,10,18,0.95)'; this.rr(ctx, bx, by, bw, bh, 6); ctx.fill();
      ctx.strokeStyle = '#ffd24a'; ctx.lineWidth = 1.5; this.rr(ctx, bx + 0.5, by + 0.5, bw - 1, bh - 1, 6); ctx.stroke();
      ctx.fillStyle = '#ffd24a'; ctx.font = 'bold 10px Verdana'; ctx.textAlign = 'left'; ctx.fillText('TIP', bx + 12, by + 16);
      ctx.fillStyle = '#e8e0e8'; ctx.font = '12px Verdana'; ctx.fillText(game._tipText, bx + 12, by + 32);
      ctx.fillStyle = 'rgba(255,255,255,0.4)'; ctx.font = '9px Verdana'; ctx.textAlign = 'right';
      ctx.fillText('any key to dismiss', bx + bw - 10, by + 16); ctx.textAlign = 'left';
      ctx.restore();
    },

    // Hover tooltip card. Producers (drawHotbar/drawBuffs) stash a single tip on
    // game._hudTip during their pass; we render it LAST so it's always on top.
    // Tip shape: { title, color, sub, lines:[…], desc }  (all but title optional)
    drawHudTip(ctx, game, w, h) {
      if (!game._hudTip || !game._hudTip.length) return;
      const t = game._hudTip[0];
      game._hudTip = null;
      const m = VAMP.Input.mouse;
      ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic';

      const padX = 10, padTop = 8, padBot = 9;
      const titleFont = 'bold 12px Verdana';
      const subFont = '10px Verdana';
      const lineFont = '10px Verdana';
      const descFont = 'italic 10px Verdana';
      const maxTextW = 230;
      const lines = t.lines || [];

      // measure → card size
      ctx.font = titleFont; let cw = ctx.measureText(t.title).width;
      if (t.sub) { ctx.font = subFont; cw = Math.max(cw, ctx.measureText(t.sub).width); }
      ctx.font = lineFont; for (const l of lines) cw = Math.max(cw, ctx.measureText(l).width);
      // wrap the description to the card width
      let descLines = [];
      if (t.desc) { ctx.font = descFont; descLines = wrapLines(ctx, t.desc, Math.min(maxTextW, Math.max(cw, 150))); for (const l of descLines) cw = Math.max(cw, ctx.measureText(l).width); }
      cw = Math.min(cw, maxTextW);

      let ch = padTop + 13;                       // title row
      if (t.sub) ch += 13;
      ch += lines.length * 14;
      if (descLines.length) ch += 4 + descLines.length * 13;
      ch += padBot;
      const bw = cw + padX * 2, bh = ch;

      // position near cursor, then clamp to all four edges (flip above if no room below)
      let bx = m.x + 16, by = m.y + 16;
      if (bx + bw > w - 4) bx = m.x - bw - 12;
      if (bx < 4) bx = 4;
      if (bx + bw > w - 4) bx = w - bw - 4;
      if (by + bh > h - 4) by = m.y - bh - 12;
      if (by < 4) by = 4;
      if (by + bh > h - 4) by = h - bh - 4;

      const col = t.color || '#ddd';
      ctx.fillStyle = 'rgba(8,6,12,0.96)'; this.rr(ctx, bx, by, bw, bh, 5); ctx.fill();
      ctx.strokeStyle = col; ctx.lineWidth = 1.2; this.rr(ctx, bx + 0.6, by + 0.6, bw - 1.2, bh - 1.2, 5); ctx.stroke();

      let ty = by + padTop + 11;
      ctx.fillStyle = col; ctx.font = titleFont; ctx.fillText(t.title, bx + padX, ty); ty += 13;
      if (t.sub) { ctx.fillStyle = 'rgba(220,220,228,0.7)'; ctx.font = subFont; ctx.fillText(t.sub, bx + padX, ty); ty += 13; }
      ctx.font = lineFont;
      for (const l of lines) { ctx.fillStyle = '#dfe2e8'; ctx.fillText(l, bx + padX, ty); ty += 14; }
      if (descLines.length) {
        ty += 4; ctx.font = descFont; ctx.fillStyle = 'rgba(200,200,210,0.62)';
        for (const l of descLines) { ctx.fillText(l, bx + padX, ty); ty += 13; }
      }
    },

    drawBar(ctx, x, y, w, h, frac, color, bg, label, value) {
      // delegate to the shared Theme bar (#21) — gradient fill + sheen + hairline
      VAMP.Theme.bar(ctx, x, y, w, h, frac, color, { label, value });
    },

    // #4 — buff/debuff + active status icon bar with radial countdown pies.
    // Buffs come from p.buffs; detrimental statuses on p.status are shown red.
    drawBuffs(ctx, game, p) {
      const items = [];
      for (const b of (p.buffs || [])) {
        if (b.id === 'dawn_streak') continue; // passive, shown elsewhere
        items.push({ name: b.name, color: b.color || '#9affd0', dur: b.dur, max: b._max || b.dur, good: true, mod: b.mods });
      }
      const ST = VAMP.Combat.STATUS_COLOR;
      if (p.status) for (const k in p.status) {
        const st = p.status[k]; if (!st || st.t <= 0) continue;
        if (k === 'mark') continue;                  // mark is offensive, not on player normally
        items.push({ name: k, color: ST[k] || '#ff5a5a', dur: st.t, max: st.max || st.t || 1, good: false, key: k });
      }
      if (!items.length) return;
      const x0 = 14, y0 = 110, sz = 26, gap = 5;
      for (let i = 0; i < items.length; i++) {
        const it = items[i];
        const x = x0 + i * (sz + gap), y = y0;
        const infinite = !isFinite(it.dur);
        const frac = infinite ? 1 : U.clamp(it.dur / Math.max(0.001, it.max), 0, 1);
        // box
        ctx.fillStyle = 'rgba(8,8,14,0.8)'; this.rr(ctx, x, y, sz, sz, 5); ctx.fill();
        ctx.strokeStyle = it.good ? it.color : '#ff5a5a'; ctx.lineWidth = 1.4; this.rr(ctx, x + 0.5, y + 0.5, sz - 1, sz - 1, 5); ctx.stroke();
        // first-letter glyph (drawn icon, no font glyphs that clash)
        ctx.fillStyle = it.color; ctx.font = 'bold 13px Verdana'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        const glyph = it.name.length ? it.name[0].toUpperCase() : '?';
        ctx.fillText(glyph, x + sz / 2, y + sz / 2 + 1);
        ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic';
        // radial countdown pie (sweeps clockwise from top)
        if (!infinite) {
          ctx.fillStyle = 'rgba(0,0,0,0.55)';
          ctx.beginPath(); ctx.moveTo(x + sz / 2, y + sz / 2);
          ctx.arc(x + sz / 2, y + sz / 2, sz / 2, -Math.PI / 2, -Math.PI / 2 + (1 - frac) * U.TAU); ctx.closePath(); ctx.fill();
        }
        // tick label (whole seconds) for short buffs
        if (!infinite && it.dur < 10) { ctx.fillStyle = '#fff'; ctx.font = 'bold 9px Verdana'; ctx.textAlign = 'right'; ctx.fillText(Math.ceil(it.dur) + '', x + sz - 2, y + 10); ctx.textAlign = 'left'; }
        // hover tip
        const m = VAMP.Input.mouse;
        if (m.x >= x && m.x <= x + sz && m.y >= y && m.y <= y + sz) {
          const lines = [];
          lines.push(it.good ? 'Buff' + (infinite ? '' : ' · ' + Math.ceil(it.dur) + 's left') : 'Status' + (infinite ? '' : ' · ' + Math.ceil(it.dur) + 's left'));
          for (const ph of modPhrases(it.mod)) lines.push(ph);
          game._hudTip = game._hudTip || [];
          game._hudTip.push({ title: it.name, color: it.color, lines });
        }
      }
    },

    drawVitals(ctx, game, p) {
      const x = 14, y = 14, w = 230;
      this.drawBar(ctx, x, y, w, 16, p.hp / p.derived.maxHP, '#d8324a', null, 'HEALTH', Math.round(p.hp) + '/' + Math.round(p.derived.maxHP));
      this.drawBar(ctx, x, y + 20, w, 16, p.blood / p.derived.maxBlood, '#ff2f6e', null, 'VITAE', Math.round(p.blood));
      if (p.ward > 0) { ctx.fillStyle = 'rgba(122,208,255,0.7)'; ctx.font = '10px Verdana'; ctx.fillText('⛨ ' + Math.round(p.ward), x + w + 6, y + 32); }
      // XP (or Elder Vitae progress at the cap)
      const maxed = p.level >= VAMP.Stats.MAX_LEVEL;
      const need = VAMP.Stats.xpToNext(p.level);
      const efrac = maxed ? U.clamp((p.bloodState.elderProgress || 0) / VAMP.Stats.ELDER_XP, 0, 1) : p.xp / need;
      this.drawBar(ctx, x, y + 40, w, 12, efrac, maxed ? '#ff7a30' : '#b07bff', null, null, null);
      ctx.font = 'bold 10px Verdana'; ctx.fillStyle = maxed ? '#ffd9a8' : '#e8def8';
      ctx.fillText(maxed ? ('LVL 60 · ELDER VITAE ' + (p.bloodState.elderVitae || 0)) : ('LVL ' + p.level), x + 6, y + 49);
      ctx.textAlign = 'right'; ctx.fillStyle = 'rgba(255,255,255,0.6)';
      ctx.fillText('Gen ' + p.derived.generation + '  BP ' + p.derived.bloodPotency, x + w - 5, y + 49); ctx.textAlign = 'left';

      // hunger pips
      const hx = x, hy = y + 58;
      ctx.font = '9px Verdana'; ctx.fillStyle = '#bbb'; ctx.fillText('HUNGER', hx, hy + 8);
      for (let i = 0; i < 5; i++) {
        const filled = p.bloodState.hunger > i;
        ctx.fillStyle = filled ? (i >= 4 ? '#ff3a3a' : '#e07020') : 'rgba(255,255,255,0.12)';
        ctx.beginPath(); ctx.arc(hx + 58 + i * 14, hy + 4, 5, 0, U.TAU); ctx.fill();
      }
      // humanity
      const um = p.bloodState.humanity;
      ctx.fillStyle = '#bbb'; ctx.fillText('HUMANITY', hx + 138, hy + 8);
      ctx.fillStyle = um <= 3 ? '#ff5a5a' : um >= 8 ? '#9ad0ff' : '#cdd';
      ctx.font = 'bold 11px Verdana'; ctx.fillText(um.toFixed(1), hx + 200, hy + 8);

      // money (#2 — animated roll-up via the global tweener)
      if (this.displayMoney == null || this._moneySeeded !== p) { this.displayMoney = p.money; this._moneySeeded = p; }  // seed to real value (no roll-up-from-0 on load)
      if (Math.abs(this.displayMoney - p.money) > 0.5) this.tweens.to(this, 'displayMoney', p.money, 0.4, U.ease.outCubic);
      ctx.font = 'bold 14px Verdana'; ctx.fillStyle = '#ffd24a';
      ctx.fillText('$ ' + U.fmt(Math.round(this.displayMoney)), x + 6, hy + 30);
      // Influence — the social-verb resource (only shown once you have any capacity)
      if (p.influence != null && VAMP.Reputation && VAMP.Reputation.influenceMax(p) > 0) {
        ctx.font = 'bold 11px Verdana'; ctx.fillStyle = '#ff9ecf';
        ctx.fillText('✦ ' + Math.floor(p.influence) + '/' + VAMP.Reputation.influenceMax(p), x + 6, hy + 44);
      }
      // points to spend
      if ((p.attrPoints || 0) > 0 || (p.skillPoints || 0) > 0) {
        ctx.font = 'bold 11px Verdana'; ctx.fillStyle = '#9affd0';
        let s = '';
        if (p.attrPoints) s += '● ' + p.attrPoints + ' attr  ';
        if (p.skillPoints) s += '◆ ' + p.skillPoints + ' skill';
        ctx.fillText(s + '  [C]', x + 70, hy + 30);
      }
    },

    drawHotbar(ctx, game, p, w, h) {
      const slots = p.slots; const n = slots.length;
      const sw = 46, gap = 6;
      const total = n * sw + (n - 1) * gap;
      let x = (w - total) / 2, y = h - sw - 14;
      ctx.font = 'bold 9px Verdana';
      for (let i = 0; i < n; i++) {
        const id = slots[i];
        const def = id ? VAMP.Data.POWERS[id] : null;
        const disc = def ? VAMP.Data.DISCIPLINES[def.disc] : null;
        // slot box
        ctx.fillStyle = 'rgba(8,8,14,0.7)'; this.rr(ctx, x, y, sw, sw, 6); ctx.fill();
        ctx.strokeStyle = def ? (disc ? disc.color : '#888') : 'rgba(255,255,255,0.1)';
        ctx.lineWidth = (def && p.toggles[id]) ? 3 : 1.5;
        this.rr(ctx, x + 0.5, y + 0.5, sw - 1, sw - 1, 6); ctx.stroke();
        // key number
        ctx.fillStyle = 'rgba(255,255,255,0.6)'; ctx.fillText('' + (i + 1), x + 4, y + 11);
        if (def) {
          const iconKey = (VAMP.powerIconKey && VAMP.powerIconKey(id))
            || (function () {
              const iconPath = VAMP.PowerIconPaths && VAMP.PowerIconPaths[id];
              return iconPath && VAMP.ArtPaths && Object.keys(VAMP.ArtPaths).find((k) => VAMP.ArtPaths[k] === iconPath);
            })();
          if (VAMP.ArtFlags && VAMP.ArtFlags.useBitmapUI && iconKey && VAMP.Assets.ready && VAMP.Assets.has(iconKey)) {
            VAMP.Assets.drawKey(ctx, iconKey, x + sw / 2, y + sw / 2, { w: 30, h: 30, ax: 0.5, ay: 0.5 });
          } else {
            ctx.fillStyle = disc ? disc.color : '#ccc';
            ctx.font = 'bold 22px Verdana, sans-serif'; ctx.textAlign = 'center';
            ctx.fillText(def.glyph || '?', x + sw / 2, y + sw / 2 + 8);
            ctx.textAlign = 'left'; ctx.font = 'bold 9px Verdana';
          }
          // cost (show the discounted value actually paid) + ready/affordability (#8)
          if (def.cost) {
            const shown = Math.round(VAMP.Disc.effectiveCost(p, def));
            const canAfford = p.blood >= shown;
            const cd = p.cooldowns[id] || 0;
            const ready = cd <= 0;
            ctx.fillStyle = !canAfford ? '#ff5a5a' : (ready ? '#7effa0' : '#ff7ea0');
            ctx.fillText(shown + '', x + sw - 16, y + sw - 4);
            // dim the whole slot if unusable
            if (!canAfford || !ready) { ctx.fillStyle = 'rgba(0,0,0,0.28)'; this.rr(ctx, x, y, sw, sw, 6); ctx.fill(); }
          }
          // cooldown overlay
          const cd = p.cooldowns[id] || 0;
          if (cd > 0) {
            const full = VAMP.Disc.effectiveCooldown(p, def) || 1;
            const frac = U.clamp(cd / full, 0, 1);
            ctx.fillStyle = 'rgba(0,0,0,0.6)';
            ctx.beginPath(); ctx.moveTo(x + sw / 2, y + sw / 2);
            ctx.arc(x + sw / 2, y + sw / 2, sw / 2, -Math.PI / 2, -Math.PI / 2 + frac * U.TAU); ctx.closePath(); ctx.fill();
            ctx.fillStyle = '#fff'; ctx.font = 'bold 12px Verdana'; ctx.textAlign = 'center';
            ctx.fillText(cd.toFixed(1), x + sw / 2, y + sw / 2 + 4); ctx.textAlign = 'left'; ctx.font = 'bold 9px Verdana';
          }
          // toggle on indicator
          if (p.toggles[id]) { ctx.fillStyle = disc ? disc.color : '#fff'; ctx.fillRect(x + 4, y + sw - 7, sw - 8, 3); }
          // hover tip card (hover-only; never consumes the click)
          const m = VAMP.Input.mouse;
          if (m.x >= x && m.x <= x + sw && m.y >= y && m.y <= y + sw) {
            const lines = [];
            const cost = Math.round(VAMP.Disc.effectiveCost(p, def));
            const cdFull = Math.round(VAMP.Disc.effectiveCooldown(p, def) * 10) / 10;
            const cdLeft = p.cooldowns[id] || 0;
            const bits = [];
            if (def.type === 'toggle') bits.push(def.upkeep ? cost + ' vitae +' + def.upkeep + '/s' : 'Toggle');
            else bits.push(cost > 0 ? cost + ' vitae' : 'Free');
            if (cdFull > 0) bits.push(cdFull + 's cd');
            lines.push(bits.join(' · '));
            if (cdLeft > 0.05) lines.push('On cooldown: ' + cdLeft.toFixed(1) + 's');
            else if (p.blood < cost) lines.push('Not enough vitae');
            if (def.type === 'toggle' && p.toggles[id]) lines.push('● Active');
            game._hudTip = game._hudTip || [];
            game._hudTip.push({ title: def.name, color: disc ? disc.color : '#ccc', sub: disc ? disc.name : '', lines, desc: def.desc });
          }
        }
        x += sw + gap;
      }
      // controls hint
      ctx.fillStyle = 'rgba(255,255,255,0.4)'; ctx.font = '10px Verdana'; ctx.textAlign = 'center';
      ctx.fillText('SPACE attack · RMB free-aim · F feed/takedown · E interact/carry · T intimidate · Shift sprint · X sneak · Ctrl pounce · 1-8 powers · C character · M map', w / 2, h - 4);
      ctx.textAlign = 'left';
    },

    drawMinimap(ctx, game, p, w) {
      // lazy-build if the base canvas isn't ready yet (keeps it cached after)
      if (!this.minimap && game.world) this.buildMinimap(game.world);
      if (!this.minimap) return;
      const size = 168, pad = 14;
      // sit below the top-right HUD block (stars/WANTED/clock/district/legend) so they never overlap
      const mx = w - size - pad, my = pad + 96;
      // header label above the radar
      ctx.font = 'bold 9px Verdana'; ctx.textAlign = 'right'; ctx.fillStyle = 'rgba(210,200,170,0.7)';
      ctx.fillText('RADAR', mx + size, my - 4); ctx.textAlign = 'left';
      // frame
      ctx.fillStyle = 'rgba(0,0,0,0.62)'; this.rr(ctx, mx - 2, my - 2, size + 4, size + 4, 6); ctx.fill();
      ctx.save();
      this.rr(ctx, mx, my, size, size, 5); ctx.clip();
      ctx.fillStyle = '#06060a'; ctx.fillRect(mx, my, size, size);
      // draw region of minimap centered on player
      const zoom = 3.2; // radar zoom
      const srcW = size / zoom / this.mmScale; // world px shown
      const px = p.inVehicle ? p.inVehicle.x : p.x, py = p.inVehicle ? p.inVehicle.y : p.y;
      const sx = px * this.mmScale - (size / zoom) / 2;
      const sy = py * this.mmScale - (size / zoom) / 2;
      ctx.imageSmoothingEnabled = false;
      ctx.drawImage(this.minimap, sx, sy, size / zoom, size / zoom, mx, my, size, size);
      ctx.imageSmoothingEnabled = true;

      const toRadar = (wx, wy) => ({ x: mx + (wx - px) * this.mmScale * zoom + size / 2, y: my + (wy - py) * this.mmScale * zoom + size / 2 });

      // POIs
      for (const poi of game.world.pois) {
        const r = toRadar(poi.x, poi.y);
        if (r.x < mx || r.x > mx + size || r.y < my || r.y > my + size) continue;
        ctx.fillStyle = poi.color; ctx.beginPath(); ctx.arc(r.x, r.y, 3, 0, U.TAU); ctx.fill();
      }
      // npc blips
      for (const nn of game.npcs) {
        if (nn.dead) continue;
        const r = toRadar(nn.x, nn.y);
        if (r.x < mx || r.x > mx + size || r.y < my || r.y > my + size) continue;
        let col = null;
        if (nn.ally) col = '#5aff8c';
        else if (nn.faction === 'police' || nn.faction === 'inquis') col = '#ff4040';
        else if (nn.faction === 'gang' && nn.aggro) col = '#ff9030';
        else if (nn.vip) col = '#ffd24a';
        if (col) { ctx.fillStyle = col; ctx.fillRect(r.x - 1.5, r.y - 1.5, 3, 3); }
      }
      // dynamic blips
      for (const bl of (game.blips || [])) {
        const bx = bl.ref ? bl.ref.x : bl.x, by = bl.ref ? bl.ref.y : bl.y;
        if (bl.ref && bl.ref.dead) continue;
        const r = toRadar(bx, by);
        ctx.fillStyle = bl.color; ctx.beginPath(); ctx.arc(r.x, r.y, 3, 0, U.TAU); ctx.fill();
      }
      // mission markers
      if (game.activeMission) for (const mk of game.activeMission.markers) {
        const tx = mk.ref ? mk.ref.x : mk.x, ty = mk.ref ? mk.ref.y : mk.y;
        if (tx == null) continue;
        const r = toRadar(tx, ty);
        const cr = { x: U.clamp(r.x, mx + 5, mx + size - 5), y: U.clamp(r.y, my + 5, my + size - 5) };
        ctx.fillStyle = mk.color; ctx.beginPath(); ctx.arc(cr.x, cr.y, 4, 0, U.TAU); ctx.fill();
        ctx.strokeStyle = '#fff'; ctx.lineWidth = 1; ctx.stroke();
      }
      // player heading arrow — bigger, dark-outlined so it reads on any tile
      const pc = { x: mx + size / 2, y: my + size / 2 };
      ctx.save(); ctx.translate(pc.x, pc.y); ctx.rotate(p.inVehicle ? p.inVehicle.angle : p.facing);
      ctx.beginPath(); ctx.moveTo(9, 0); ctx.lineTo(-6, -6); ctx.lineTo(-3, 0); ctx.lineTo(-6, 6); ctx.closePath();
      ctx.fillStyle = '#fff'; ctx.fill();
      ctx.strokeStyle = 'rgba(0,0,0,0.85)'; ctx.lineWidth = 1.2; ctx.stroke();
      ctx.restore();
      ctx.restore();
      // frame border + north tick ('N' at the top edge — the radar is north-up)
      ctx.strokeStyle = 'rgba(210,190,150,0.55)'; ctx.lineWidth = 1.5; this.rr(ctx, mx, my, size, size, 5); ctx.stroke();
      ctx.fillStyle = 'rgba(0,0,0,0.55)'; ctx.fillRect(mx + size / 2 - 7, my + 1, 14, 12);
      ctx.fillStyle = 'rgba(235,235,240,0.85)'; ctx.font = 'bold 9px Verdana'; ctx.textAlign = 'center';
      ctx.fillText('N', mx + size / 2, my + 10); ctx.textAlign = 'left';
      // #8 — compact legend under the radar
      const lgY = my + size + 4;
      ctx.font = '9px Verdana'; ctx.textAlign = 'left';
      const legend = [['#5a9cff', 'Haven'], ['#ffd24a', 'Market'], ['#c79bff', 'Board'], ['#ff5a7a', 'Blood'], ['#5aff8c', 'Ally'], ['#ff4040', 'Police']];
      let lx = mx;
      for (const [c, lbl] of legend) {
        ctx.fillStyle = c; ctx.beginPath(); ctx.arc(lx + 3, lgY + 3, 2.5, 0, U.TAU); ctx.fill();
        ctx.fillStyle = 'rgba(220,220,225,0.75)'; ctx.fillText(lbl, lx + 8, lgY + 6);
        lx += ctx.measureText(lbl).width + 20;
      }
    },

    drawTopRight(ctx, game, w) {
      const M = game.masquerade;
      const s = M.stars;
      const sx = w - 14;
      let sy = 28;
      ctx.textAlign = 'right';
      ctx.font = 'bold 15px Verdana';
      let str = '';
      for (let i = 0; i < 6; i++) str += i < s ? '★' : '☆';
      ctx.fillStyle = s > 0 ? '#ff4040' : 'rgba(255,255,255,0.3)';
      ctx.fillText(str, sx, sy);
      // WANTED / EVADING — GTA-style escape feedback so it's clear HOW to get back to peace
      if (s > 0) {
        sy += 15;
        const pulse = 0.55 + 0.45 * Math.abs(Math.sin(game.time * 5));
        ctx.font = 'bold 10px Verdana';
        if (M.evading) { ctx.fillStyle = 'rgba(120,230,150,' + pulse + ')'; ctx.fillText('▼ EVADING — stay out of sight', sx, sy); }
        else { ctx.fillStyle = 'rgba(255,90,90,' + pulse + ')'; ctx.fillText('● WANTED — break their line of sight', sx, sy); }
      }
      // clock + district
      const t = game.clock;
      const hh = Math.floor(t) % 24, mm = Math.floor((t % 1) * 60);
      ctx.font = '11px Verdana'; ctx.fillStyle = game.timeOfDay.night ? '#9ab' : '#ffd';
      ctx.fillText('Night ' + game.day + '  ' + U.pad2(hh) + ':' + U.pad2(mm) + (game.timeOfDay.night ? ' ☾' : ' ☀'), sx, sy + 18);
      const dist = game.world.districtAt(game.player.x, game.player.y);
      if (dist) {
        const owned = VAMP.Domains && VAMP.Domains.isOwned(game, dist.id);
        ctx.fillStyle = dist.accent; ctx.font = 'bold 12px Verdana'; ctx.fillText((owned ? '✦ ' : '') + dist.name, sx, sy + 34);
      }
      if (VAMP.Legend && (!VAMP.Progress || VAMP.Progress.hudFeature(game, 'legend'))) { const lt = VAMP.Legend.title(game.player); ctx.fillStyle = '#c79bff'; ctx.font = '11px Verdana'; ctx.fillText(lt.name + (VAMP.Domains ? '  ·  ' + VAMP.Domains.ownedCount(game) + ' domains' : ''), sx, sy + 50); }
      ctx.textAlign = 'left';
    },

    // #13 — top-of-screen boss bar for the active boss/Baron/nemesis
    drawBossBar(ctx, game, w, h) {
      // find the nearest engaged boss-type NPC on screen
      const p = game.player;
      let boss = null, bd = Infinity;
      for (const n of game.npcs) {
        if (n.dead || !(n.boss || (n.nemesis && n.threat >= 3) || n.baronOf)) continue;
        if (!n.aggro && !game.cam.inView(n.x, n.y, 60)) continue;
        const d = U.dist2(p.x, p.y, n.x, n.y);
        if (d < bd) { bd = d; boss = n; }
      }
      if (!boss) return;
      const bw = Math.min(560, w - 80), bx = (w - bw) / 2, by = 14;
      ctx.font = 'bold 12px Verdana'; ctx.textAlign = 'center';
      ctx.fillStyle = 'rgba(0,0,0,0.6)'; this.rr(ctx, bx - 2, by - 2, bw + 4, 26, 5); ctx.fill();
      // name
      ctx.fillStyle = '#ffd24a'; ctx.fillText((boss.name || (boss.baronOf ? 'Baron of ' + (game.world.districts[boss.baronOf] ? game.world.districts[boss.baronOf].name : 'the District') : 'ELDER')) , w / 2, by + 12);
      ctx.textAlign = 'left';
      // bar
      VAMP.Theme.bar(ctx, bx, by + 14, bw, 8, boss.hp / boss.maxHp, '#ff3030', {});
      // phase pips (placeholder for phased fights #22): show 3 segments
      ctx.strokeStyle = 'rgba(0,0,0,0.5)'; ctx.lineWidth = 1;
      for (let i = 1; i < 3; i++) { const sx = bx + (bw / 3) * i; ctx.beginPath(); ctx.moveTo(sx, by + 14); ctx.lineTo(sx, by + 22); ctx.stroke(); }
    },

    drawSun(ctx, game, w, h) {
      const p = game.player;
      const sheltered = game.sheltered, burn = game.sunBurn || 0;
      const cx = w / 2, y = 58;
      ctx.textAlign = 'center'; ctx.font = 'bold 13px Verdana';
      const label = sheltered ? '☂ SHELTERED' : '☀ EXPOSED — reach shade or a haven (✚)';
      const pulse = 0.55 + 0.45 * Math.sin(game.time * 8);
      const col = sheltered ? '#7ee0a0' : `rgba(255,${Math.round(110 - burn * 70)},60,${pulse})`;
      const tw = ctx.measureText(label).width;
      ctx.fillStyle = 'rgba(0,0,0,0.55)'; this.rr(ctx, cx - tw / 2 - 12, y - 14, tw + 24, 20, 5); ctx.fill();
      ctx.fillStyle = col; ctx.fillText(label, cx, y);
      if (!sheltered && burn > 0.01) {
        const bw = 170; ctx.fillStyle = 'rgba(0,0,0,0.5)'; ctx.fillRect(cx - bw / 2, y + 7, bw, 6);
        ctx.fillStyle = '#ff5a30'; ctx.fillRect(cx - bw / 2, y + 7, bw * burn, 6);
        const hv = game.nearestHaven(p.x, p.y, false); const a = U.angleTo(p.x, p.y, hv.x, hv.y);
        ctx.save(); ctx.translate(cx, y + 32); ctx.rotate(a); ctx.fillStyle = '#5a9cff';
        ctx.beginPath(); ctx.moveTo(12, 0); ctx.lineTo(-6, -6); ctx.lineTo(-6, 6); ctx.closePath(); ctx.fill(); ctx.restore();
      }
      ctx.textAlign = 'left';
    },

    drawMission(ctx, game, w, h) {
      const m = game.activeMission;
      const y0 = 150;
      ctx.textAlign = 'left';
      if (!m) {
        const obj = VAMP.Progress ? VAMP.Progress.nextObjective(game) : null;
        const goal = game.tutorialGoal || (obj && obj.text);   // tutorial wins the first beats, then Progress
        if (goal) {
          const first = !!game.tutorialGoal;
          ctx.fillStyle = 'rgba(0,0,0,0.5)'; this.rr(ctx, 12, y0, 250, 52, 5); ctx.fill();
          ctx.fillStyle = '#ff9ecf'; ctx.font = 'bold 12px Verdana'; ctx.fillText(first ? '✦ FIRST NIGHT' : '✦ NEXT', 20, y0 + 16);
          ctx.fillStyle = '#cdd'; ctx.font = '10px Verdana';
          wrapText(ctx, goal, 20, y0 + 31, 234, 12);
        }
      }
      if (m) {
        ctx.fillStyle = 'rgba(0,0,0,0.5)'; this.rr(ctx, 12, y0, 250, 56, 5); ctx.fill();
        ctx.fillStyle = m.color; ctx.font = 'bold 12px Verdana';
        ctx.fillText(m.icon + ' ' + m.name, 20, y0 + 18);
        // approach-modifier tag (e.g. NO-KILL / STEALTH / HEAVY) — struck through once forfeited
        if (m.modifier && m.modifier.tag) {
          ctx.font = 'bold 9px Verdana'; ctx.textAlign = 'right';
          ctx.fillStyle = m._violated ? '#777' : m.modifier.color;
          ctx.fillText((m._violated ? '✗ ' : '★ ') + m.modifier.tag, 256, y0 + 33); ctx.textAlign = 'left';
        }
        ctx.fillStyle = '#cdd'; ctx.font = '10px Verdana';
        wrapText(ctx, m.desc, 20, y0 + 33, 200, 12);
        // progress
        let prog = '';
        if (m.type === 'feed' || m.type === 'collect') prog = m.progress + '/' + m.need;
        else if (m.type === 'cleanse') prog = (m.need - m.spawned.filter(s => !s.dead).length) + '/' + m.need + ' cleared';
        else if (m.type === 'survive') prog = 'Wave ' + (m.data.wave || 0) + '/' + m.need;
        else if (m.timeLimit) prog = Math.ceil(m.timer) + 's left';
        if (prog) { ctx.fillStyle = '#fff'; ctx.font = 'bold 10px Verdana'; ctx.textAlign = 'right'; ctx.fillText(prog, 256, y0 + 18); ctx.textAlign = 'left'; }
        // #8 — distance/ETA to the nearest objective marker
        const p = game.player;
        let near = null, nd = Infinity;
        for (const mk of m.markers) { const tx = mk.ref ? mk.ref.x : mk.x, ty = mk.ref ? mk.ref.y : mk.y; if (tx == null) continue; const d = U.dist(p.x, p.y, tx, ty); if (d < nd) { nd = d; near = { x: tx, y: ty }; } }
        if (near) { ctx.fillStyle = m.color; ctx.font = '10px Verdana'; ctx.fillText(Math.round(nd) + 'm', 20, y0 + 50); }
      }
      // heist crack progress bar
      if (game.crackProgress > 0) {
        const bw = 200; const bx = (w - bw) / 2, by = h * 0.4;
        ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(bx, by, bw, 14);
        ctx.fillStyle = '#30c060'; ctx.fillRect(bx, by, bw * game.crackProgress, 14);
        ctx.fillStyle = '#fff'; ctx.font = '10px Verdana'; ctx.textAlign = 'center'; ctx.fillText('CRACKING VAULT', w / 2, by + 11); ctx.textAlign = 'left';
      }
    },

    computePrompt(ctx, game, p, w, h) {
      let prompt = '';
      if (p.feeding) { prompt = 'Hold F drain · release to spare · CLICK the gold zone for a Perfect Gulp'; if (VAMP.Coterie && VAMP.Coterie.canEmbrace(game, p.feeding.npc)) prompt += ' · [G] Embrace'; }
      else if (p.carrying) {
        const dump = VAMP.Stealth ? VAMP.Stealth.nearestDumpSpot(game.world, p.x, p.y, 52) : null;
        prompt = dump ? ('E: Dump body in the ' + dump.kind) : 'E: Drop body  (in shadow to hide it)';
      }
      else if (!p.inVehicle) {
        // a body to drag off, or a behind-the-back silent takedown — these read first
        const body = VAMP.Stealth ? VAMP.Stealth.nearestBody(game, p.x, p.y, 42) : null;
        const st = VAMP.Stealth ? VAMP.Stealth.findStealthTarget(p, game) : null;
        // nearest interactable
        const poi = game.nearestPOI ? game.nearestPOI(p.x, p.y, 60) : null;
        let v = null, vd = 46;
        for (const veh of game.vehicles) { if (veh.dead || veh.burning) continue; const d = U.dist(p.x, p.y, veh.x, veh.y); if (d < vd) { vd = d; v = veh; } }
        if (body) prompt = 'E: Carry the body away';
        else if (poi && (!v || U.dist(p.x, p.y, poi.x, poi.y) < vd)) prompt = 'E: ' + poi.label;
        else if (v) prompt = 'E: ' + (v.driver && v.driver !== 'player' ? 'Hijack ' : 'Enter ') + v.type;
        else if (st) prompt = 'F: ☠ SILENT TAKEDOWN  (' + (VAMP.Blood.VICTIM_TYPES[st.victimType] ? VAMP.Blood.VICTIM_TYPES[st.victimType].name : 'foe') + ')';
        else {
          // execution-eligible target reads as a red skull; else the normal feed prompt
          const ex = (p.finisherUnlocked && VAMP.Player.findExecuteTarget) ? VAMP.Player.findExecuteTarget(p, game) : null;
          if (ex) prompt = 'F: ☠ EXECUTE ' + (VAMP.Blood.VICTIM_TYPES[ex.victimType] ? VAMP.Blood.VICTIM_TYPES[ex.victimType].name : 'foe');
          else { const ft = VAMP.Player.findFeedTarget(p, game); if (ft) prompt = 'F: Feed on ' + (VAMP.Blood.VICTIM_TYPES[ft.victimType] ? VAMP.Blood.VICTIM_TYPES[ft.victimType].name : 'mortal'); }
        }
      } else prompt = 'E: Exit vehicle';
      if (prompt) {
        ctx.font = 'bold 13px Verdana'; ctx.textAlign = 'center';
        const tw = ctx.measureText(prompt).width;
        ctx.fillStyle = 'rgba(0,0,0,0.6)'; this.rr(ctx, w / 2 - tw / 2 - 10, h - 96, tw + 20, 22, 5); ctx.fill();
        ctx.fillStyle = '#ffe9a8'; ctx.fillText(prompt, w / 2, h - 81);
        ctx.textAlign = 'left';
      }
    },

    // toasts live in a tidy bottom-left stack — never over the middle of the screen
    drawToasts(ctx, w, h) {
      let y = h - 120;
      ctx.textAlign = 'left';
      for (const n of this.notifications) {
        const a = U.clamp(n.t / n.max * 2, 0, 1);
        ctx.globalAlpha = a; ctx.font = 'bold 12px Verdana';
        const label = n.text + (n.count > 1 ? '  ×' + n.count : '');
        const tw = ctx.measureText(label).width;
        ctx.fillStyle = 'rgba(0,0,0,0.62)'; this.rr(ctx, 14, y - 14, tw + 16, 20, 4); ctx.fill();
        ctx.fillStyle = n.color; ctx.fillText(label, 22, y);
        y -= 24;
      }
      ctx.globalAlpha = 1;
    },

    drawBanner(ctx, w, h) {
      const b = this.bannerObj; if (!b) return;
      const a = U.clamp(Math.min(b.t, b.max - b.t) * 2, 0, 1);
      ctx.globalAlpha = a;
      ctx.textAlign = 'center';
      ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(0, h * 0.28, w, 70);
      ctx.fillStyle = b.color; ctx.fillRect(0, h * 0.28, w, 3); ctx.fillRect(0, h * 0.28 + 67, w, 3);
      ctx.font = 'bold 30px Georgia, serif'; ctx.fillStyle = b.color;
      ctx.fillText(b.title, w / 2, h * 0.28 + 36);
      ctx.font = '14px Verdana'; ctx.fillStyle = '#e8e8f0';
      ctx.fillText(b.sub, w / 2, h * 0.28 + 58);
      ctx.globalAlpha = 1; ctx.textAlign = 'left';
    },

    rr(ctx, x, y, w, h, r) {
      r = Math.max(0, Math.min(r, w / 2, h / 2));
      ctx.beginPath();
      ctx.moveTo(x + r, y);
      ctx.arcTo(x + w, y, x + w, y + h, r);
      ctx.arcTo(x + w, y + h, x, y + h, r);
      ctx.arcTo(x, y + h, x, y, r);
      ctx.arcTo(x, y, x + w, y, r);
      ctx.closePath();
    },
  };

  function wrapText(ctx, text, x, y, maxW, lh) {
    const words = ('' + text).split(' '); let line = ''; let yy = y;
    for (const wd of words) {
      const test = line + wd + ' ';
      if (ctx.measureText(test).width > maxW && line) { ctx.fillText(line, x, yy); line = wd + ' '; yy += lh; }
      else line = test;
    }
    ctx.fillText(line, x, yy);
  }

  // measure-only word wrap → array of lines (caller sets the font first)
  function wrapLines(ctx, text, maxW) {
    const words = ('' + text).split(' '); const out = []; let line = '';
    for (const wd of words) {
      const test = line ? line + ' ' + wd : wd;
      if (ctx.measureText(test).width > maxW && line) { out.push(line); line = wd; }
      else line = test;
    }
    if (line) out.push(line);
    return out;
  }

  // turn a mods object ({pct:{moveSpeed:-0.12}, add:{influence:2}}) into short phrases
  const MOD_NAMES = {
    moveSpeed: 'move', attackSpeed: 'atk speed', meleeDmg: 'melee', spellPower: 'spell power',
    maxHP: 'max HP', maxBlood: 'max vitae', armor: 'armor', dodge: 'dodge', critChance: 'crit',
    critMult: 'crit dmg', lifesteal: 'lifesteal', feedYield: 'feed yield', feedSpeed: 'feed speed',
    cdr: 'cooldown', cooldownMult: 'cooldown', xpMult: 'XP', sunResist: 'sun resist',
    frenzyResist: 'frenzy resist', hpRegen: 'HP regen', discount: 'vitae cost',
  };
  function modPhrases(mods) {
    if (!mods) return [];
    const out = [];
    if (mods.pct) for (const k in mods.pct) {
      const v = mods.pct[k]; if (!v) continue;
      out.push((v > 0 ? '+' : '') + Math.round(v * 100) + '% ' + (MOD_NAMES[k] || k));
    }
    if (mods.add) for (const k in mods.add) {
      const v = mods.add[k]; if (!v) continue;
      out.push((v > 0 ? '+' : '') + v + ' ' + (MOD_NAMES[k] || k));
    }
    return out;
  }

  VAMP.UI = UI;
})();
