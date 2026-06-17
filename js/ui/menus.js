/* =========================================================================
 * VAMPIRE CITY — ui/menus.js  (VAMP.Menus)
 * Immediate-mode overlay screens: Character (attributes + skill tree +
 * loadout), Inventory, Map, Shop, Mission Board, Haven services, Pause.
 * Pauses the sim while open. Mouse-driven.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  const MZ = {
    open: null,           // null | 'char' | 'pause' | 'shop' | 'board' | 'haven'
    tab: 'skills',        // within char: skills | inventory | map | stats
    scroll: 0,
    scrollX: 0,           // horizontal pan (skill tree only — see drawTree)
    poi: null, shopStock: [], offers: [], shopMode: 'buy',
    selectedPower: null,
    hot: [],              // hit rects for this frame
    tip: null,
    game: null,

    isOpen() { return !!this.open; },
    pausesSim() { return !!this.open; },

    openScreen(name, ctx) {
      this.open = name; this.scroll = 0; this.scrollX = 0; this.maxScroll = 0; this.maxScrollX = 0; this.tip = null; this.selectedPower = null;
      if (name === 'char') this.tab = ctx && ctx.tab ? ctx.tab : 'skills';
      if (VAMP.Audio) { VAMP.Audio.resume(); VAMP.Audio.play('uiBig'); }
    },
    close() { this.open = null; this.tip = null; if (VAMP.Audio) VAMP.Audio.play('ui'); },
    toggle(name) { if (this.open === name) this.close(); else this.openScreen(name); },

    // #20 — cycle through the (currently visible) character-screen tabs
    _cycleTab(dir) {
      const tabs = (this._visibleTabs && this._visibleTabs.length) ? this._visibleTabs : ['skills', 'inventory', 'map', 'stats'];
      const i = Math.max(0, tabs.indexOf(this.tab || 'skills'));
      const next = tabs[(i + dir + tabs.length) % tabs.length];
      this.tab = next; this.scroll = 0; this.scrollX = 0; if (VAMP.Audio) VAMP.Audio.play('ui');
    },

    handleKeys(game) {
      const In = VAMP.Input;
      if (In.wasPressed('escape')) { if (this.open) { this.close(); return; } else { this.openScreen('pause'); return; } }
      if (this.open) {
        if (this.open === 'char') {
          if (In.wasPressed('keyc') || In.wasPressed('tab')) this.close();
          if (In.wasPressed('keyi')) this.tab = 'inventory';
          if (In.wasPressed('keym')) this.tab = 'map';
          // #20 — keyboard tab cycling: [ and ] move through character tabs
          if (In.wasPressed('bracketleft') || In.wasPressed('pageup')) { this._cycleTab(-1); }
          if (In.wasPressed('bracketright') || In.wasPressed('pagedown')) { this._cycleTab(1); }
        } else {
          if (In.wasPressed('tab') || In.wasPressed('keye')) this.close();
        }
        // P6c — skill tree is wider than its viewport: pan horizontally.
        // Shift+wheel pans the tree sideways; arrow keys pan it continuously.
        const onTree = this.open === 'char' && this.tab === 'skills';
        const shift = In.isDown('shiftleft') || In.isDown('shiftright');
        if (onTree && (shift && In.mouse.wheel)) {
          this.scrollX = U.clamp(this.scrollX + In.mouse.wheel * 60, 0, this.maxScrollX || 0);
        } else if (In.mouse.wheel) {
          this.scroll = U.clamp(this.scroll + In.mouse.wheel * 40, 0, this.maxScroll != null ? this.maxScroll : 2000);
        }
        if (onTree) {
          const pan = (In.isDown('arrowleft') ? -1 : 0) + (In.isDown('arrowright') ? 1 : 0);
          if (pan) this.scrollX = U.clamp(this.scrollX + pan * 14, 0, this.maxScrollX || 0);
        }
        return;
      }
      if (In.wasPressed('keyc')) this.openScreen('char', { tab: 'skills' });
      else if (In.wasPressed('keyi') || In.wasPressed('keyb')) this.openScreen('char', { tab: 'inventory' });
      else if (In.wasPressed('keym')) this.openScreen('char', { tab: 'map' });
    },

    drawMenuBackdrop(ctx, w, h, key) {
      if (VAMP.Assets && VAMP.Assets.ready && VAMP.Assets.has(key)) {
        const bg = VAMP.Assets.get(key);
        ctx.drawImage(bg, 0, 0, w, h);
        ctx.fillStyle = 'rgba(4,3,8,0.72)'; ctx.fillRect(0, 0, w, h);
      } else {
        ctx.fillStyle = 'rgba(4,3,8,0.82)'; ctx.fillRect(0, 0, w, h);
      }
    },

    render(ctx, game, w, h) {
      this.game = game; this.hot = []; this.tip = null;
      const bgKey = this.open === 'board' ? 'menu_bg_board' : (this.open === 'char' && this.tab === 'map' ? 'menu_bg_map' : null);
      if (bgKey) this.drawMenuBackdrop(ctx, w, h, bgKey);
      else { ctx.fillStyle = 'rgba(4,3,8,0.82)'; ctx.fillRect(0, 0, w, h); }
      ctx.textBaseline = 'alphabetic';
      switch (this.open) {
        case 'char': this.renderChar(ctx, game, w, h); break;
        case 'pause': this.renderPause(ctx, game, w, h); break;
        case 'shop': this.renderShop(ctx, game, w, h); break;
        case 'board': this.renderBoard(ctx, game, w, h); break;
        case 'haven': this.renderHaven(ctx, game, w, h); break;
        case 'credits': this.renderCredits(ctx, game, w, h); break;
      }
      if (this.tip) this.drawTip(ctx, this.tip, w, h);
    },

    // ----- shared widgets -----
    btn(ctx, x, y, w, h, label, opts) {
      opts = opts || {};
      const m = VAMP.Input.mouse;
      const over = m.x >= x && m.x <= x + w && m.y >= y && m.y <= y + h;
      const clicked = over && m.pressed && !opts.disabled;
      ctx.fillStyle = opts.disabled ? 'rgba(40,40,50,0.5)' : over ? (opts.color2 || 'rgba(90,40,60,0.95)') : (opts.color || 'rgba(40,24,36,0.9)');
      rr(ctx, x, y, w, h, 5); ctx.fill();
      ctx.strokeStyle = opts.disabled ? 'rgba(80,80,90,0.4)' : over ? (opts.accent || '#c0506a') : 'rgba(180,140,160,0.35)';
      ctx.lineWidth = 1.4; rr(ctx, x + 0.5, y + 0.5, w - 1, h - 1, 5); ctx.stroke();
      ctx.fillStyle = opts.disabled ? '#777' : '#f0e6ee';
      ctx.font = (opts.font || 'bold 13px') + ' Verdana'; ctx.textAlign = opts.align || 'center';
      ctx.fillText(label, opts.align === 'left' ? x + 10 : x + w / 2, y + h / 2 + 4);
      ctx.textAlign = 'left';
      if (clicked && VAMP.Audio) VAMP.Audio.play('ui');
      return clicked;
    },
    panel(ctx, x, y, w, h, title) {
      ctx.fillStyle = 'rgba(14,10,18,0.95)'; rr(ctx, x, y, w, h, 8); ctx.fill();
      ctx.strokeStyle = 'rgba(150,40,70,0.5)'; ctx.lineWidth = 1.5; rr(ctx, x + 0.5, y + 0.5, w - 1, h - 1, 8); ctx.stroke();
      if (title) { ctx.fillStyle = '#e0a0b8'; ctx.font = 'bold 18px Georgia, serif'; ctx.textAlign = 'left'; ctx.fillText(title, x + 16, y + 26); }
    },

    // ----- CHARACTER -----
    renderChar(ctx, game, w, h) {
      const x = 24, y = 20, pw = w - 48, ph = h - 40;
      this.maxScroll = 0;
      this.panel(ctx, x, y, pw, ph, null);
      // header tabs — gated by VAMP.Progress so the deep-end stays hidden until earned
      const ALL = [['skills', 'SKILLS'], ['inventory', 'INVENTORY'], ['holdings', 'HOLDINGS'], ['coterie', 'COTERIE'], ['mastery', 'MASTERY'], ['codex', 'CODEX'], ['elder', 'ELDER'], ['map', 'MAP'], ['stats', 'STATS']];
      const tabs = VAMP.Progress ? ALL.filter(([id]) => VAMP.Progress.tabVisible(game, id)) : ALL;
      this._visibleTabs = tabs.map((t) => t[0]);
      if (!this._visibleTabs.indexOf || this._visibleTabs.indexOf(this.tab) < 0) this.tab = 'skills';   // never render a hidden tab
      // tabs — adaptively sized so the whole row always fits (no collision with the close ✕),
      // however many tabs are unlocked or however narrow the window is.
      const tabsX0 = x + 16, tabsRight = x + pw - 42;   // the ✕ lives to the right of this
      const avail = tabsRight - tabsX0;
      let fontPx = 13, pad = 24, gap = 8;
      const measureRow = (fp) => { ctx.font = 'bold ' + fp + 'px Verdana'; let tot = 0; for (const t of tabs) tot += ctx.measureText(t[1]).width; return tot; };
      for (let guard = 0; guard < 10; guard++) {
        const total = measureRow(fontPx) + tabs.length * pad + (tabs.length - 1) * gap;
        if (total <= avail) break;
        if (pad > 12) pad -= 4; else if (gap > 4) gap -= 2; else if (fontPx > 9) fontPx -= 1; else break;
      }
      let tx = tabsX0;
      ctx.font = 'bold ' + fontPx + 'px Verdana';
      for (const [id, label] of tabs) {
        const tw = ctx.measureText(label).width + pad;
        if (this.btn(ctx, tx, y + 12, tw, 28, label, { font: 'bold ' + fontPx + 'px', color: this.tab === id ? 'rgba(150,40,70,0.9)' : 'rgba(40,24,36,0.8)' })) { this.tab = id; this.scroll = 0; this.scrollX = 0; }
        tx += tw + gap;
      }
      // close — compact corner ✕, out of the tab flow so the row never collides with it
      if (this.btn(ctx, x + pw - 36, y + 12, 26, 28, '✕', { font: 'bold 15px' })) this.close();
      const cx = x + 16, cy = y + 54, cw = pw - 32, ch = ph - 70;
      if (this.tab === 'skills') this.renderSkills(ctx, game, cx, cy, cw, ch);
      else if (this.tab === 'inventory') this.renderInventory(ctx, game, cx, cy, cw, ch);
      else if (this.tab === 'holdings') this.renderHoldings(ctx, game, cx, cy, cw, ch);
      else if (this.tab === 'coterie') this.renderCoterie(ctx, game, cx, cy, cw, ch);
      else if (this.tab === 'mastery') this.renderMastery(ctx, game, cx, cy, cw, ch);
      else if (this.tab === 'codex') this.renderCodex(ctx, game, cx, cy, cw, ch);
      else if (this.tab === 'elder') this.renderElder(ctx, game, cx, cy, cw, ch);
      else if (this.tab === 'map') this.renderMapPanel(ctx, game, cx, cy, cw, ch);
      else if (this.tab === 'stats') this.renderStats(ctx, game, cx, cy, cw, ch);
    },

    renderCoterie(ctx, game, x, y, w, h) {
      const p = game.player; VAMP.Coterie.ensure(p);
      const jobIds = Object.keys(VAMP.Coterie.JOBS);
      ctx.textAlign = 'left'; ctx.fillStyle = '#5aff8c'; ctx.font = 'bold 13px Verdana';
      ctx.fillText('COTERIE — ' + VAMP.Coterie.aliveMembers(game).length + ' afield · ' + p.coterie.length + ' bound · cap ' + VAMP.Coterie.cap(game), x, y + 6);
      ctx.fillStyle = '#9a8'; ctx.font = '10px Verdana';
      ctx.fillText('Bind followers via Dominate → Bind Thrall (mesmerize/weaken a victim first). Assign jobs for nightly income.', x, y + 22);
      if (!p.coterie.length) { ctx.fillStyle = '#777'; ctx.font = '12px Verdana'; ctx.fillText('No followers yet. The night is lonely.', x, y + 48); return; }
      let ay = y + 34;
      this.maxScroll = Math.max(0, p.coterie.length * 50 - (h - 40));
      ay -= this.scroll;
      ctx.save(); rr(ctx, x, y + 28, w, h - 30, 5); ctx.clip();
      for (const m of p.coterie) {
        if (ay > y + h || ay < y - 50) { ay += 50; continue; }
        ctx.fillStyle = 'rgba(24,30,24,0.85)'; rr(ctx, x, ay, w, 46, 5); ctx.fill();
        ctx.fillStyle = m.isChilde ? '#ffd24a' : '#9affd0'; ctx.font = 'bold 12px Verdana';
        ctx.fillText((m.isChilde ? '★ ' : '') + m.name, x + 10, ay + 16);
        ctx.fillStyle = '#9a8'; ctx.font = '10px Verdana';
        ctx.fillText('Lv ' + m.level + ' ' + (m.archetype || 'thrall') + ' · loyalty ' + Math.round(m.loyalty), x + 10, ay + 32);
        const job = VAMP.Coterie.JOBS[m.assignment] || VAMP.Coterie.JOBS.none;
        if (this.btn(ctx, x + w - 250, ay + 10, 120, 26, 'Job: ' + job.name.split('—')[0].trim(), { font: 'bold 10px' })) { const i = jobIds.indexOf(m.assignment); VAMP.Coterie.assign(game, m, jobIds[(i + 1) % jobIds.length]); }
        if (this.btn(ctx, x + w - 122, ay + 10, 110, 26, 'Summon', { disabled: m.assignment && m.assignment !== 'none', font: 'bold 10px' })) VAMP.Coterie.summon(game, m);
        ay += 50;
      }
      ctx.restore();
      this.drawScrollbar(ctx, x, y + 28, w, h - 30);   // #20 — visible scrollbar
    },

    renderHoldings(ctx, game, x, y, w, h) {
      const p = game.player;
      VAMP.Domains.ensure(game); VAMP.Business.ensure(p);
      const title = VAMP.Legend ? VAMP.Legend.title(p) : { name: 'Fledgling', domainCap: 1 };
      ctx.textAlign = 'left'; ctx.fillStyle = '#c79bff'; ctx.font = 'bold 14px Verdana';
      ctx.fillText('Title: ' + title.name + '   ·   Legend ' + Math.round(VAMP.Legend ? VAMP.Legend.get(p) : 0) + '   ·   Domains ' + VAMP.Domains.ownedCount(game) + '/' + title.domainCap, x, y + 6);
      ctx.fillStyle = '#ffd24a'; ctx.font = 'bold 12px Verdana'; ctx.textAlign = 'right'; ctx.fillText('$ ' + U.fmt(p.money), x + w, y + 6); ctx.textAlign = 'left';
      const colW = (w - 24) / 2;
      // LEFT: districts / domains
      ctx.fillStyle = '#d6953f'; ctx.font = 'bold 13px Verdana'; ctx.fillText('DOMAINS — claim each district by slaying its Baron', x, y + 28);
      let ay = y + 38;
      for (const d of game.world.districts) {
        const dm = game.domains[d.id]; const owned = dm.owner === 'player';
        const contesting = dm.contesting || game.npcs.some((n) => n.baronOf === d.id && !n.dead);
        ctx.fillStyle = 'rgba(28,22,20,0.85)'; rr(ctx, x, ay, colW, 30, 4); ctx.fill();
        if (owned) { ctx.fillStyle = d.accent; ctx.fillRect(x, ay, 4, 30); }
        ctx.fillStyle = owned ? '#9affd0' : '#cdd'; ctx.font = 'bold 11px Verdana';
        ctx.fillText((owned ? '✦ ' : '') + d.name, x + 10, ay + 19);
        if (owned) { ctx.fillStyle = '#7c7'; ctx.font = '9px Verdana'; ctx.textAlign = 'right'; ctx.fillText('held', x + colW - 10, ay + 19); ctx.textAlign = 'left'; }
        else if (this.btn(ctx, x + colW - 96, ay + 3, 88, 24, contesting ? 'fighting…' : 'CONTEST', { disabled: contesting, font: 'bold 10px' })) { VAMP.Domains.contest(game, d.id); this.close(); }
        ay += 34;
      }
      // RIGHT: businesses
      const bx = x + colW + 24;
      ctx.fillStyle = '#30c060'; ctx.font = 'bold 13px Verdana'; ctx.fillText('BUSINESSES — passive income, banked each dawn', bx, y + 28);
      let by = y + 38;
      for (const biz of VAMP.Business.list()) {
        const own = VAMP.Business.owned(p, biz.id), tier = VAMP.Business.tier(p, biz.id);
        const cost = own ? VAMP.Business.upgradeCost(p, biz.id) : biz.cost;
        const maxed = own && tier >= VAMP.Business.MAXTIER;
        ctx.fillStyle = 'rgba(20,28,22,0.85)'; rr(ctx, bx, by, colW, 40, 4); ctx.fill();
        ctx.fillStyle = own ? '#9affd0' : '#cde'; ctx.font = 'bold 11px Verdana';
        ctx.fillText(biz.glyph + ' ' + biz.name + (own ? '  [T' + tier + ']' : ''), bx + 8, by + 15);
        ctx.fillStyle = '#9a8'; ctx.font = '9px Verdana'; ctx.fillText('$' + biz.cash + (biz.vitae ? ' +' + biz.vitae + 'v' : '') + '/night each tier', bx + 8, by + 29);
        if (this.btn(ctx, bx + colW - 92, by + 8, 84, 24, maxed ? 'MAX' : (own ? 'Upgrade $' + cost : 'Buy $' + biz.cost), { disabled: maxed || p.money < cost, font: 'bold 10px' })) VAMP.Business.buy(game, biz.id);
        by += 44;
      }
    },

    renderMastery(ctx, game, x, y, w, h) {
      const p = game.player; VAMP.Mastery.ensure(p);
      ctx.fillStyle = '#cdb'; ctx.font = 'bold 13px Verdana'; ctx.textAlign = 'left';
      ctx.fillText('MASTERY — you improve by DOING. These bonuses are permanent and survive death.', x, y + 4);
      let ay = y + 20;
      for (const id in VAMP.Mastery.TRACKS) {
        const tr = p.mastery[id], def = VAMP.Mastery.TRACKS[id];
        const need = 28 * (tr.rank + 1) * (tr.rank + 1);
        const frac = U.clamp(tr.xp / need, 0, 1);
        ctx.fillStyle = 'rgba(28,20,30,0.8)'; rr(ctx, x, ay, w, 40, 5); ctx.fill();
        ctx.fillStyle = '#9affd0'; ctx.font = 'bold 13px Verdana'; ctx.fillText(def.name + '  —  rank ' + tr.rank + '/' + VAMP.Mastery.CAP, x + 10, ay + 16);
        ctx.fillStyle = '#9a8'; ctx.font = '10px Verdana'; ctx.fillText('from ' + def.desc, x + 10, ay + 31);
        ctx.fillStyle = 'rgba(0,0,0,0.5)'; ctx.fillRect(x + w - 220, ay + 24, 200, 6);
        ctx.fillStyle = '#9affd0'; ctx.fillRect(x + w - 220, ay + 24, 200 * frac, 6);
        ay += 46;
      }
    },

    renderCodex(ctx, game, x, y, w, h) {
      const p = game.player; VAMP.Codex.ensure(p);
      ctx.fillStyle = '#cdb'; ctx.font = 'bold 13px Verdana'; ctx.textAlign = 'left';
      ctx.fillText('CODEX — complete a collection for a PERMANENT bonus. The night is yours to catalogue.', x, y + 4);
      const cats = VAMP.Codex.CATS(); let ay = y + 20;
      for (const id in cats) {
        const c = cats[id];
        const have = id === 'powers' ? Object.keys(p.powers || {}).length : VAMP.Codex.countOf(p, id);
        const done = p.codex.complete[id];
        ctx.fillStyle = 'rgba(28,20,30,0.8)'; rr(ctx, x, ay, w, 38, 5); ctx.fill();
        if (done) { ctx.fillStyle = '#ffd24a'; ctx.fillRect(x, ay, 4, 38); }
        ctx.fillStyle = done ? '#ffd24a' : '#cdd'; ctx.font = 'bold 12px Verdana';
        ctx.fillText((done ? '★ ' : '') + c.label, x + 12, ay + 16);
        ctx.fillStyle = '#9a8'; ctx.font = '10px Verdana';
        ctx.fillText(Math.min(have, c.total) + ' / ' + c.total + (done ? '  — COMPLETE (bonus active)' : ''), x + 12, ay + 30);
        ay += 44;
      }
    },

    renderElder(ctx, game, x, y, w, h) {
      const p = game.player; const bs = p.bloodState;
      ctx.fillStyle = '#ff7a30'; ctx.font = 'bold 15px Georgia, serif'; ctx.textAlign = 'left';
      ctx.fillText('ELDER VITAE — the centuries of the Blood', x, y + 6);
      ctx.fillStyle = '#cdd'; ctx.font = '11px Verdana';
      ctx.fillText('Overflow XP past level ' + VAMP.Stats.MAX_LEVEL + ' becomes Elder Vitae. Spend it on permanent, never-ending power.', x, y + 24);
      ctx.fillStyle = '#ffd24a'; ctx.font = 'bold 16px Verdana';
      ctx.fillText('Elder Vitae available: ' + (bs.elderVitae || 0), x, y + 48);
      ctx.fillStyle = '#9a8'; ctx.font = '10px Verdana';
      const need = VAMP.Stats.ELDER_XP; ctx.fillText('Next point: ' + Math.round(bs.elderProgress || 0) + ' / ' + need + ' XP', x, y + 62);
      let ay = y + 76;
      for (const key in VAMP.Stats.ELDER_KEYS) {
        const def = VAMP.Stats.ELDER_KEYS[key];
        const owned = (bs.elderSpent && bs.elderSpent[key]) || 0;
        ctx.fillStyle = 'rgba(40,24,18,0.8)'; rr(ctx, x, ay, w - 120, 28, 4); ctx.fill();
        ctx.fillStyle = '#ffd9a8'; ctx.font = '12px Verdana'; ctx.fillText(def.name + '   (owned: ' + owned + ')', x + 10, ay + 18);
        if (this.btn(ctx, x + w - 110, ay + 1, 100, 26, 'Invest ▸', { disabled: (bs.elderVitae || 0) < 1 })) VAMP.Stats.spendElder(p, key);
        ay += 32;
      }
    },

    renderSkills(ctx, game, x, y, w, h) {
      const p = game.player;
      // left column: attributes
      const colW = 240;
      ctx.fillStyle = '#cdb'; ctx.font = 'bold 13px Verdana';
      ctx.fillText('ATTRIBUTES   (◆ ' + (p.attrPoints || 0) + ' pts)', x, y + 4);
      let ay = y + 18;
      for (const a of VAMP.Stats.ATTRS) {
        ctx.fillStyle = 'rgba(30,20,30,0.8)'; rr(ctx, x, ay, colW, 30, 4); ctx.fill();
        ctx.fillStyle = '#e8dde8'; ctx.font = 'bold 12px Verdana'; ctx.textAlign = 'left';
        ctx.fillText(a.name, x + 8, ay + 14);
        ctx.fillStyle = '#9a8'; ctx.font = '9px Verdana'; ctx.fillText(a.desc, x + 8, ay + 25);
        ctx.fillStyle = '#ffd24a'; ctx.font = 'bold 14px Verdana'; ctx.textAlign = 'right';
        ctx.fillText('' + p.attributes[a.id], x + colW - 36, ay + 19);
        ctx.textAlign = 'left';
        if (this.btn(ctx, x + colW - 28, ay + 4, 22, 22, '+', { disabled: (p.attrPoints || 0) <= 0 || p.attributes[a.id] >= 50, font: 'bold 14px' })) VAMP.Stats.spendAttribute(p, a.id);
        ay += 34;
      }
      // loadout
      ay += 6;
      ctx.fillStyle = '#cdb'; ctx.font = 'bold 13px Verdana'; ctx.fillText('HOTBAR LOADOUT', x, ay); ay += 8;
      for (let i = 0; i < 8; i++) {
        const sx = x + (i % 4) * 58, sy = ay + ((i / 4) | 0) * 50;
        const id = p.slots[i];
        const def = id ? VAMP.Data.POWERS[id] : null;
        const disc = def ? VAMP.Data.DISCIPLINES[def.disc] : null;
        ctx.fillStyle = 'rgba(8,8,14,0.8)'; rr(ctx, sx, sy, 50, 44, 5); ctx.fill();
        ctx.strokeStyle = disc ? disc.color : 'rgba(255,255,255,0.15)'; ctx.lineWidth = 1.3; rr(ctx, sx + 0.5, sy + 0.5, 49, 43, 5); ctx.stroke();
        ctx.fillStyle = 'rgba(255,255,255,0.5)'; ctx.font = '9px Verdana'; ctx.fillText('' + (i + 1), sx + 4, sy + 11);
        if (def) { ctx.fillStyle = disc ? disc.color : '#ccc'; ctx.font = 'bold 18px Verdana'; ctx.textAlign = 'center'; ctx.fillText(def.glyph, sx + 25, sy + 30); ctx.textAlign = 'left'; }
        const m = VAMP.Input.mouse, over = m.x >= sx && m.x <= sx + 50 && m.y >= sy && m.y <= sy + 44;
        if (over && def) this.tip = { title: def.name, lines: [VAMP.Data.DISCIPLINES[def.disc].name, def.desc] };
        if (over && m.pressed) {
          if (this.selectedPower) { VAMP.Disc.assignSlot(p, i, this.selectedPower); this.selectedPower = null; if (VAMP.Audio) VAMP.Audio.play('ui'); }
          else { VAMP.Disc.assignSlot(p, i, null); }
        }
      }

      // skill tree on the right
      const treeX = x + colW + 16, treeY = y, treeW = w - colW - 16, treeH = h;
      // scroll bound: tallest branch column
      let maxNodes = 0; for (const br of VAMP.Data.TREE) maxNodes = Math.max(maxNodes, br.nodes.length);
      this.maxScroll = Math.max(0, 50 + maxNodes * 46 + 30 - (treeH - 12));
      // P6c — enforce a minimum readable column width; the resulting content is wider than
      // the viewport, so clamp scrollX here (draw-time, ordering-independent — same as maxScroll).
      const branchCount = VAMP.Data.TREE.length;
      const treeColW = Math.max(82, treeW / branchCount);
      const contentW = treeColW * branchCount;
      this.maxScrollX = Math.max(0, contentW - treeW);
      this.scrollX = U.clamp(this.scrollX || 0, 0, this.maxScrollX);
      ctx.fillStyle = '#cdb'; ctx.font = 'bold 13px Verdana';
      ctx.fillText('THE PATH   (◆ ' + (p.skillPoints || 0) + ' skill pts)   — click node to learn; click a power then a hotbar slot to bind', treeX, treeY + 4);
      ctx.save();
      rr(ctx, treeX, treeY + 12, treeW, treeH - 12, 6); ctx.clip();
      ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.fillRect(treeX, treeY + 12, treeW, treeH - 12);
      // fold BOTH scroll axes into the origin so drawing AND hit-testing shift identically.
      // clip() hides off-viewport drawing but NOT the dist() hit-test, so gate clicks on the
      // mouse being inside the tree viewport — otherwise panned-out nodes (slid behind the
      // attributes column) would still be clickable and steal clicks from the "+" buttons.
      const m = VAMP.Input.mouse;
      const mIn = m.x >= treeX && m.x <= treeX + treeW && m.y >= treeY + 12 && m.y <= treeY + treeH;
      this.drawTree(ctx, game, treeX - this.scrollX, treeY + 12 - this.scroll, treeW, treeH, treeColW, mIn);
      ctx.restore();
      // scroll hint
      ctx.fillStyle = 'rgba(255,255,255,0.3)'; ctx.font = '10px Verdana'; ctx.textAlign = 'right';
      const panHint = this.maxScrollX > 0 ? '◄ ► pan (Shift+wheel / arrows)   ·   ' : '';
      ctx.fillText(panHint + 'scroll to pan ▼', treeX + treeW - 8, treeY + treeH - 4); ctx.textAlign = 'left';
    },

    drawTree(ctx, game, ox, oy, w, h, colW, mIn) {
      const p = game.player;
      const branches = VAMP.Data.TREE;
      if (colW == null) colW = w / branches.length;
      if (mIn == null) mIn = true;
      const m = VAMP.Input.mouse;
      for (let bi = 0; bi < branches.length; bi++) {
        const br = branches[bi];
        const bx = ox + bi * colW + colW / 2;
        // header — ellipsize names too wide for the column (e.g. "Blood Sorcery")
        ctx.fillStyle = br.color; ctx.font = 'bold 11px Verdana'; ctx.textAlign = 'center';
        ctx.fillText(ellip(ctx, br.name, colW - 6), bx, oy + 16);
        const pts = VAMP.SkillTree.branchPoints(p, br.id);
        ctx.fillStyle = 'rgba(255,255,255,0.5)'; ctx.font = '9px Verdana'; ctx.fillText(pts + ' pts', bx, oy + 28);
        // nodes by order
        let ny = oy + 50;
        let prevByTier = {};
        for (let ni = 0; ni < br.nodes.length; ni++) {
          const node = br.nodes[ni];
          const rank = VAMP.SkillTree.rank(p, node.id);
          const can = VAMP.SkillTree.canAllocate(p, node.id).ok;
          const owned = rank > 0;
          const r = node.type === 'keystone' ? 16 : 13;
          // connector to previous node in column
          if (ni > 0) { ctx.strokeStyle = owned ? br.color : 'rgba(255,255,255,0.12)'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(bx, ny - 24 + r); ctx.lineTo(bx, ny - r); ctx.stroke(); }
          // node circle
          ctx.beginPath(); ctx.arc(bx, ny, r, 0, U.TAU);
          ctx.fillStyle = owned ? br.color : (can ? 'rgba(60,40,55,0.95)' : 'rgba(28,24,30,0.9)');
          ctx.fill();
          ctx.lineWidth = node.type === 'keystone' ? 3 : 1.6;
          ctx.strokeStyle = owned ? '#fff' : can ? br.color : 'rgba(120,120,130,0.5)';
          ctx.stroke();
          // glyph / icon
          ctx.fillStyle = owned ? '#1a1018' : (can ? '#ddd' : '#888');
          if (node.type === 'power') { ctx.font = 'bold 14px Verdana'; ctx.textAlign = 'center'; ctx.fillText(node.glyph || '★', bx, ny + 5); }
          else if (node.type === 'keystone') { ctx.font = 'bold 13px Verdana'; ctx.textAlign = 'center'; ctx.fillText('◆', bx, ny + 5); }
          else { ctx.font = 'bold 11px Verdana'; ctx.textAlign = 'center'; ctx.fillText(node.maxRank > 1 ? (rank + '/' + node.maxRank) : '+', bx, ny + 4); }
          ctx.textAlign = 'left';
          // hover/click — only when the cursor is inside the (clipped) tree viewport,
          // so panned/scrolled-out nodes can't be clicked through other UI
          const over = mIn && U.dist(m.x, m.y, bx, ny) < r + 2;
          if (over) {
            const reqInfo = VAMP.SkillTree.canAllocate(p, node.id);
            this.tip = { title: node.name + (node.maxRank > 1 ? ('  (' + rank + '/' + node.maxRank + ')') : ''), lines: [node.desc, node.type === 'power' ? 'Unlocks a power' : '', reqInfo.ok ? 'Click to learn (1 pt)' : (reqInfo.why || '')], color: br.color };
            if (m.pressed) { VAMP.SkillTree.allocate(p, node.id); }
            // power nodes: select for binding
            if (m.rpressed && node.type === 'power' && owned) this.selectedPower = node.power;
          }
          ny += 46;
        }
        // track max height for scroll bound
        this._treeBottom = Math.max(this._treeBottom || 0, ny);
      }
      // selected power chip
      if (this.selectedPower) {
        const def = VAMP.Data.POWERS[this.selectedPower];
        ctx.fillStyle = 'rgba(0,0,0,0.7)'; rr(ctx, m.x + 12, m.y + 12, 150, 24, 4); ctx.fill();
        ctx.fillStyle = '#9ff'; ctx.font = '11px Verdana'; ctx.fillText('Bind: ' + def.name + ' → slot', m.x + 18, m.y + 28);
      }
    },

    renderStats(ctx, game, x, y, w, h) {
      const p = game.player, d = p.derived;
      const rows = [
        ['Max Health', Math.round(d.maxHP)], ['Max Vitae', Math.round(d.maxBlood)],
        ['Move Speed', Math.round(d.moveSpeed)], ['Attack Speed', d.attackSpeed.toFixed(2) + 'x'],
        ['Melee Damage', Math.round(d.meleeDmg)], ['Spell Power', d.spellPower.toFixed(2) + 'x'],
        ['Crit Chance', Math.round(d.critChance * 100) + '%'], ['Crit Multiplier', d.critMult.toFixed(2) + 'x'],
        ['Cooldown Reduction', Math.round((1 - d.cooldownMult) * 100) + '%'], ['Armor (DR)', Math.round(d.armor * 100) + '%'],
        ['Dodge', Math.round(d.dodge * 100) + '%'], ['Lifesteal', Math.round(d.lifesteal * 100) + '%'],
        ['HP Regen', d.hpRegen.toFixed(1) + '/s'], ['Vitae Regen', d.bloodRegen.toFixed(1) + '/s'],
        ['XP Multiplier', Math.round(d.xpMult * 100) + '%'], ['Feed Yield', Math.round(d.feedYield * 100) + '%'],
        ['Feed Speed', Math.round(d.feedSpeed * 100) + '%'], ['Price Multiplier', Math.round(d.priceMult * 100) + '%'],
        ['Vitae Cost Reduction', Math.round(d.bloodEff * 100) + '%'], ['Frenzy Resist', Math.round(d.frenzyResist * 100) + '%'],
        ['Blood Potency', d.bloodPotency], ['Generation', d.generation + 'th'],
        ['Powers Learned', Object.keys(p.powers).length], ['Total XP', U.fmt(p.xpTotal || 0)],
      ];
      ctx.font = '12px Verdana';
      const colW = w / 2 - 20;
      for (let i = 0; i < rows.length; i++) {
        const col = (i % 2), rrow = (i / 2) | 0;
        const rx = x + col * (colW + 20), ry = y + 10 + rrow * 26;
        ctx.fillStyle = 'rgba(30,20,30,0.6)'; rr(ctx, rx, ry, colW, 22, 3); ctx.fill();
        ctx.fillStyle = '#cdd'; ctx.textAlign = 'left'; ctx.fillText(rows[i][0], rx + 8, ry + 15);
        ctx.fillStyle = '#ffd24a'; ctx.textAlign = 'right'; ctx.fillText('' + rows[i][1], rx + colW - 8, ry + 15);
      }
      ctx.textAlign = 'left';
      // achievements summary
      const ay = y + 10 + (((rows.length + 1) / 2) | 0) * 26 + 16;
      ctx.fillStyle = '#cdb'; ctx.font = 'bold 13px Verdana'; ctx.fillText('ACHIEVEMENTS (' + (game.achievements ? game.achievements.count() : 0) + '/' + VAMP.Data.ACHIEVEMENTS.length + ')', x, ay);
      let axx = x, ayy = ay + 16; ctx.font = '10px Verdana';
      for (const a of VAMP.Data.ACHIEVEMENTS) {
        const got = game.achievements && game.achievements.unlocked[a.id];
        ctx.fillStyle = got ? '#9affd0' : 'rgba(255,255,255,0.25)';
        ctx.fillText((got ? '★ ' : '☆ ') + a.name, axx, ayy);
        ayy += 14; if (ayy > y + h - 6) { ayy = ay + 16; axx += 180; }
      }
    },

    renderInventory(ctx, game, x, y, w, h) {
      const p = game.player;
      // equipment column
      const colW = 260;
      ctx.fillStyle = '#cdb'; ctx.font = 'bold 13px Verdana'; ctx.fillText('EQUIPPED', x, y + 4);
      const eq = [['Weapon', p.equipment.weapon], ['Attire', p.equipment.attire], ['Charm 1', p.equipment.charm1], ['Charm 2', p.equipment.charm2]];
      let ey = y + 16;
      for (const [slot, it] of eq) {
        ctx.fillStyle = 'rgba(30,20,30,0.7)'; rr(ctx, x, ey, colW, 44, 4); ctx.fill();
        ctx.fillStyle = '#998'; ctx.font = '9px Verdana'; ctx.fillText(slot, x + 8, ey + 12);
        if (it) {
          const realItem = it.item || it; // weapon slot stores a derived obj; .item is the source
          ctx.fillStyle = it.color || '#ccc'; ctx.font = 'bold 12px Verdana'; ctx.fillText(it.name || it.kind, x + 8, ey + 27);
          ctx.fillStyle = '#9a8'; ctx.font = '9px Verdana';
          const sub = it.weaponStats ? ('dmg ' + it.weaponStats.dmg) : (it.affixes ? it.affixes.slice(0, 2).join(', ') : '');
          ctx.fillText(('' + sub).slice(0, 46), x + 8, ey + 39);
          // rarity strip if we have the source item
          if (realItem && realItem.color) { ctx.fillStyle = realItem.color; ctx.fillRect(x, ey, 4, 44); }
        } else { ctx.fillStyle = '#555'; ctx.font = '11px Verdana'; ctx.fillText('— empty —', x + 8, ey + 27); }
        ey += 50;
      }
      // money + sell-all junk
      ctx.fillStyle = '#ffd24a'; ctx.font = 'bold 13px Verdana'; ctx.fillText('$ ' + U.fmt(p.money), x, ey + 16);

      // bag — grid with drawn rarity icons (#12) instead of a flat text list
      const bx = x + colW + 20, bw = w - colW - 20;
      ctx.fillStyle = '#cdb'; ctx.font = 'bold 13px Verdana'; ctx.fillText('BAG (' + p.inventory.length + ')', bx, y + 4);
      // #12 — rarity legend strip
      const order = ['common', 'uncommon', 'rare', 'epic', 'legendary', 'relic'];
      let lx = bx + 96;
      ctx.font = '9px Verdana';
      for (const rk of order) { const rr0 = VAMP.Data.RARITY[rk]; ctx.fillStyle = rr0.color; ctx.beginPath(); ctx.arc(lx + 4, y + 1, 3.5, 0, U.TAU); ctx.fill(); ctx.fillStyle = 'rgba(220,220,225,0.7)'; ctx.fillText(rr0.name[0], lx + 10, y + 4); lx += ctx.measureText(rr0.name[0]).width + 26; }

      const items = p.inventory;
      const cellW = 150, cellH = 40, cols = Math.max(1, Math.floor(bw / (cellW + 8)));
      this.maxScroll = Math.max(0, Math.ceil(items.length / cols) * (cellH + 8) - (h - 40));
      let row = -1, col = 0;
      ctx.save(); rr(ctx, bx, y + 10, bw, h - 14, 5); ctx.clip();
      const m = VAMP.Input.mouse;
      for (let i = 0; i < items.length; i++) {
        const it = items[i];
        if (col === 0) row++;
        const ix = bx + 8 + col * (cellW + 8);
        const iy = y + 18 + row * (cellH + 8) - this.scroll;
        if (iy > y + h || iy < y - cellH) { col = (col + 1) % cols; continue; }
        // card
        ctx.fillStyle = 'rgba(24,18,26,0.9)'; rr(ctx, ix, iy, cellW, cellH, 4); ctx.fill();
        ctx.fillStyle = it.color; ctx.fillRect(ix, iy, 4, cellH);
        // #12 — drawn rarity icon (a bordered gem) instead of a glyph
        this.drawRarityIcon(ctx, ix + 18, iy + cellH / 2, it.rarity, it.color);
        ctx.fillStyle = it.color; ctx.font = 'bold 11px Verdana'; ctx.textAlign = 'left';
        ctx.fillText((it.relic ? '✦ ' : '') + it.name, ix + 34, iy + 15);
        ctx.fillStyle = '#9a8'; ctx.font = '8px Verdana';
        const desc = it.weaponStats ? ('dmg ' + it.weaponStats.dmg) : (it.affixes || []).slice(0, 2).join(', ');
        ctx.fillText(('' + desc).slice(0, 28), ix + 34, iy + 28);
        // buttons
        if (this.btn(ctx, ix + cellW - 128, iy + 8, 54, 24, 'EQUIP', { font: 'bold 9px' })) VAMP.Inventory.equip(p, it);
        if (this.btn(ctx, ix + cellW - 70, iy + 8, 62, 24, '$' + VAMP.Inventory.sellValue(it), { font: 'bold 9px' })) VAMP.Economy.sell(game, it);
        if (m.x >= ix && m.x <= ix + cellW && m.y >= iy && m.y <= iy + cellH) {
          const delta = VAMP.Inventory.compareItem(p, it);
          const lines = [it.relic ? 'RELIC' : (VAMP.Data.RARITY[it.rarity] ? VAMP.Data.RARITY[it.rarity].name : it.rarity), (it.affixes || []).join(', ')];
          for (const d of delta) lines.push((d.better ? '▲ ' : '▼ ') + d.label + ' ' + d.val);
          this.tip = { title: it.name, lines, color: it.color };
        }
        col = (col + 1) % cols;
      }
      ctx.restore();
      this.drawScrollbar(ctx, bx, y + 10, bw, h - 14);
      if (items.length === 0) { ctx.fillStyle = '#777'; ctx.font = '12px Verdana'; ctx.fillText('Your bag is empty. Slay foes and complete contracts for loot.', bx + 10, y + 40); }
    },

    drawRarityIcon(ctx, cx, cy, rarity, color) {
      const r = 7; ctx.save(); ctx.translate(cx, cy);
      ctx.fillStyle = color;
      ctx.beginPath(); ctx.moveTo(0, -r); ctx.lineTo(r * 0.9, 0); ctx.lineTo(0, r); ctx.lineTo(-r * 0.9, 0); ctx.closePath(); ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,0.4)'; ctx.beginPath(); ctx.moveTo(0, -r); ctx.lineTo(r * 0.9, 0); ctx.lineTo(0, 0); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = 'rgba(0,0,0,0.5)'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(0, -r); ctx.lineTo(r * 0.9, 0); ctx.lineTo(0, r); ctx.lineTo(-r * 0.9, 0); ctx.closePath(); ctx.stroke();
      ctx.restore();
    },
    drawScrollbar(ctx, x, y, w, h) {
      if (this.maxScroll <= 0) return;
      const trackH = h - 4;
      const thumbH = Math.max(24, trackH * (h / (this.maxScroll + h)));
      const thumbY = y + 2 + (trackH - thumbH) * U.clamp(this.scroll / this.maxScroll, 0, 1);
      ctx.fillStyle = 'rgba(255,255,255,0.06)'; rr(ctx, x + w - 7, y + 2, 5, trackH, 3); ctx.fill();
      ctx.fillStyle = 'rgba(200,160,180,0.6)'; rr(ctx, x + w - 7, thumbY, 5, thumbH, 3); ctx.fill();
    },

    renderMapPanel(ctx, game, x, y, w, h) {
      if (!VAMP.UI.minimap) return;
      const mm = VAMP.UI.minimap;
      const scale = Math.min((w) / mm.width, (h - 20) / mm.height);
      const dw = mm.width * scale, dh = mm.height * scale; const mx = x + (w - dw) / 2, my = y + 6;
      ctx.fillStyle = '#06060a'; rr(ctx, mx, my, dw, dh, 4); ctx.fill();
      ctx.drawImage(mm, mx, my, dw, dh);
      const ws = VAMP.UI.mmScale * scale; const toMap = (wx, wy) => ({ x: mx + wx * ws, y: my + wy * ws });
      for (const poi of game.world.pois) {
        const r = toMap(poi.x, poi.y);
        ctx.fillStyle = poi.color; ctx.beginPath(); ctx.arc(r.x, r.y, 4, 0, U.TAU); ctx.fill();
        ctx.fillStyle = '#000'; ctx.font = 'bold 7px monospace'; ctx.textAlign = 'center'; ctx.fillText(poi.glyph, r.x, r.y + 2.5); ctx.textAlign = 'left';
        const m2 = VAMP.Input.mouse;
        if (poi.type === 'haven' && poi.discovered && U.dist(m2.x, m2.y, r.x, r.y) < 8) {
          this.tip = { title: 'Haven — click to fast-travel', lines: [poi.label] };
          if (m2.pressed) { game.fastTravel(poi); this.close(); }
        }
      }
      if (game.activeMission) for (const mk of game.activeMission.markers) {
        const tx = mk.ref ? mk.ref.x : mk.x, ty = mk.ref ? mk.ref.y : mk.y; if (tx == null) continue;
        const r = toMap(tx, ty); ctx.fillStyle = mk.color; ctx.beginPath(); ctx.arc(r.x, r.y, 5, 0, U.TAU); ctx.fill(); ctx.strokeStyle = '#fff'; ctx.stroke();
      }
      const pr = toMap(game.player.x, game.player.y);
      ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(pr.x, pr.y, 4, 0, U.TAU); ctx.fill();
      ctx.strokeStyle = '#000'; ctx.stroke();
      ctx.fillStyle = '#cdd'; ctx.font = '11px Verdana'; ctx.fillText('Click a discovered Haven (blue ✚) to fast-travel.', x, y + h - 2);
    },

    // ----- PAUSE -----
    renderPause(ctx, game, w, h) {
      const canTorpor = VAMP.Legacy && VAMP.Legacy.canTorpor(game.player) && (!VAMP.Progress || VAMP.Progress.isRevealed(game.player, 'prestige'));
      const pw = 320, ph = canTorpor ? 538 : 490, x = (w - pw) / 2, y = (h - ph) / 2;
      this.panel(ctx, x, y, pw, ph, 'PAUSED');
      let by = y + 50;
      if (this.btn(ctx, x + 30, by, pw - 60, 36, 'Resume')) this.close(); by += 44;
      if (this.btn(ctx, x + 30, by, pw - 60, 36, 'Save Game')) { if (VAMP.Save.save(game)) VAMP.UI.notify('Game saved', '#7c7'); } by += 44;
      // audio toggles
      const audOn = VAMP.Audio.isEnabled();
      if (this.btn(ctx, x + 30, by, pw - 60, 36, 'Sound: ' + (audOn ? 'ON' : 'OFF'))) VAMP.Audio.toggle(); by += 44;
      if (this.btn(ctx, x + 30, by, (pw - 70) / 2, 32, 'Music -')) VAMP.Audio.setVolume('music', Math.max(0, (game.vol.music -= 0.1)));
      if (this.btn(ctx, x + 40 + (pw - 70) / 2, by, (pw - 70) / 2, 32, 'Music +')) VAMP.Audio.setVolume('music', Math.min(1, (game.vol.music += 0.1)));
      by += 40;
      if (this.btn(ctx, x + 30, by, (pw - 70) / 2, 32, 'SFX -')) VAMP.Audio.setVolume('sfx', Math.max(0, (game.vol.sfx -= 0.1)));
      if (this.btn(ctx, x + 40 + (pw - 70) / 2, by, (pw - 70) / 2, 32, 'SFX +')) VAMP.Audio.setVolume('sfx', Math.min(1, (game.vol.sfx += 0.1)));
      by += 40;
      if (this.btn(ctx, x + 30, by, (pw - 70) / 2, 32, 'Ambience -')) VAMP.Audio.setVolume('amb', Math.max(0, (game.vol.amb = (game.vol.amb || 0.6) - 0.1)));
      if (this.btn(ctx, x + 40 + (pw - 70) / 2, by, (pw - 70) / 2, 32, 'Ambience +')) VAMP.Audio.setVolume('amb', Math.min(1, (game.vol.amb = (game.vol.amb || 0.6) + 0.1)));
      by += 40;
      const gm = (game.vol.gamma == null ? 1 : game.vol.gamma);
      if (this.btn(ctx, x + 30, by, (pw - 70) / 2, 32, 'Brightness -')) { game.vol.gamma = Math.max(0.6, +(gm - 0.1).toFixed(2)); VAMP.Save.saveSettings(game.vol); }
      if (this.btn(ctx, x + 40 + (pw - 70) / 2, by, (pw - 70) / 2, 32, 'Brightness + (' + Math.round(gm * 100) + '%)')) { game.vol.gamma = Math.min(1.6, +(gm + 0.1).toFixed(2)); VAMP.Save.saveSettings(game.vol); }
      by += 40;
      // fullscreen + credits row
      if (this.btn(ctx, x + 30, by, (pw - 70) / 2, 30, document.fullscreenElement ? 'Exit Fullscreen' : 'Fullscreen [F11]')) { if (game.toggleFullscreen) game.toggleFullscreen(); }
      if (this.btn(ctx, x + 40 + (pw - 70) / 2, by, (pw - 70) / 2, 30, 'Credits')) this.openScreen('credits');
      by += 38;
      if (this.btn(ctx, x + 30, by, pw - 60, 36, 'Quit to Title (saves)', { color: 'rgba(80,20,30,0.9)' })) { VAMP.Save.save(game); game.toTitle(); }
      by += 44;
      if (canTorpor) {
        if (this.btn(ctx, x + 30, by, pw - 60, 36, 'Enter Torpor (Prestige ▸)', { color: 'rgba(80,40,120,0.95)', accent: '#c79bff' })) { if (VAMP.Legacy.enterTorpor(game)) { this.close(); game.toTitle(); } }
      }
      ctx.fillStyle = '#776'; ctx.font = '9px Verdana'; ctx.textAlign = 'center';
      ctx.fillText('v' + (VAMP.Game && VAMP.Game.VERSION || '0.1.0') + '  ·  ESC to resume', x + pw / 2, y + ph - 12); ctx.textAlign = 'left';
    },

    // ----- CREDITS -----
    renderCredits(ctx, game, w, h) {
      const pw = 500, ph = Math.min(520, h - 80), x = (w - pw) / 2, y = (h - ph) / 2;
      this.panel(ctx, x, y, pw, ph, 'CREDITS');
      if (this.btn(ctx, x + pw - 92, y + 14, 78, 28, 'CLOSE [E]')) this.close();
      const ver = VAMP.Game && VAMP.Game.VERSION ? VAMP.Game.VERSION : '0.1.0';
      const lines = [
        { text: 'VAMPIRE CITY  v' + ver, style: 'bold 18px Georgia, serif', color: '#c0303a' },
        { text: 'A top-down open-world vampire RPG', style: 'italic 13px Georgia, serif', color: '#9a8' },
        { text: '', style: '12px Verdana', color: '#cdd' },
        { text: 'DESIGN & CODE', style: 'bold 11px Verdana', color: '#998' },
        { text: 'coldshalamov', style: 'bold 14px Verdana', color: '#f0e6ee' },
        { text: '', style: '12px Verdana', color: '#cdd' },
        { text: 'INSPIRATIONS', style: 'bold 11px Verdana', color: '#998' },
        { text: 'Vampire: The Masquerade — Bloodlines', style: '13px Verdana', color: '#cdd' },
        { text: 'Grand Theft Auto (1997, 1999)', style: '13px Verdana', color: '#cdd' },
        { text: 'Hotline Miami', style: '13px Verdana', color: '#cdd' },
        { text: 'Hades', style: '13px Verdana', color: '#cdd' },
        { text: '', style: '12px Verdana', color: '#cdd' },
        { text: 'TOOLS', style: 'bold 11px Verdana', color: '#998' },
        { text: 'Vanilla JavaScript + HTML5 Canvas', style: '13px Verdana', color: '#cdd' },
        { text: 'Web Audio API (all sound procedural)', style: '13px Verdana', color: '#cdd' },
        { text: 'No external frameworks or assets', style: '13px Verdana', color: '#cdd' },
        { text: '', style: '12px Verdana', color: '#cdd' },
        { text: 'Thank you for playing.', style: 'italic 14px Georgia, serif', color: '#e0a0b8' },
        { text: 'The night is yours.', style: 'italic 13px Georgia, serif', color: '#9a8' },
      ];
      let ly = y + 56 - this.scroll;
      ctx.save();
      ctx.rect(x + 16, y + 50, pw - 32, ph - 66); ctx.clip();
      for (const line of lines) {
        if (ly > y + ph) break;
        if (ly > y + 40) {
          ctx.fillStyle = line.color; ctx.font = line.style; ctx.textAlign = 'center';
          ctx.fillText(line.text, x + pw / 2, ly);
        }
        ly += line.text ? 24 : 10;
      }
      ctx.restore();
      this.maxScroll = Math.max(0, ly - (y + ph) + 60);
      ctx.fillStyle = '#776'; ctx.font = '9px Verdana'; ctx.textAlign = 'center';
      ctx.fillText('Scroll to read · ESC to close', x + pw / 2, y + ph - 10); ctx.textAlign = 'left';
    },

    // ----- SHOP (vendor POI) -----
    renderShop(ctx, game, w, h) {
      const pw = w - 120, ph = h - 80, x = 60, y = 40;
      this.panel(ctx, x, y, pw, ph, (this.poi ? this.poi.label : 'Black Market'));
      if (this.btn(ctx, x + pw - 92, y + 14, 78, 28, 'LEAVE [E]')) this.close();
      // mode tabs
      if (this.btn(ctx, x + 16, y + 44, 90, 26, 'BUY', { color: this.shopMode === 'buy' ? 'rgba(150,40,70,0.9)' : null })) this.shopMode = 'buy';
      if (this.btn(ctx, x + 112, y + 44, 90, 26, 'SELL', { color: this.shopMode === 'sell' ? 'rgba(150,40,70,0.9)' : null })) this.shopMode = 'sell';
      ctx.fillStyle = '#ffd24a'; ctx.font = 'bold 14px Verdana'; ctx.textAlign = 'right'; ctx.fillText('$ ' + U.fmt(game.player.money), x + pw - 110, y + 62); ctx.textAlign = 'left';
      const list = this.shopMode === 'buy' ? this.shopStock : game.player.inventory;
      const lx = x + 16, ly = y + 80, lw = pw - 32;
      this.maxScroll = Math.max(0, list.length * 46 - (ph - 100));
      let iy = ly - this.scroll;
      ctx.save(); rr(ctx, lx, ly - 4, lw, ph - 92, 5); ctx.clip();
      for (const it of list) {
        if (iy < ly - 50 || iy > y + ph) { iy += 46; continue; }
        ctx.fillStyle = 'rgba(24,18,26,0.85)'; rr(ctx, lx, iy, lw, 42, 4); ctx.fill();
        ctx.fillStyle = it.color; ctx.fillRect(lx, iy, 4, 42);
        ctx.fillStyle = it.color; ctx.font = 'bold 13px Verdana'; ctx.fillText((it.relic ? '✦ ' : '') + it.name + '  (i' + it.level + ')', lx + 12, iy + 17);
        ctx.fillStyle = '#9a8'; ctx.font = '9px Verdana';
        const desc = it.weaponStats ? ('dmg ' + it.weaponStats.dmg + '  ' + (it.affixes || []).join(', ')) : (it.affixes || []).join(', ');
        ctx.fillText(('' + desc).slice(0, 80), lx + 12, iy + 32);
        if (this.shopMode === 'buy') {
          const cost = Math.round(VAMP.Economy.price(it) * game.player.derived.priceMult);
          if (this.btn(ctx, lx + lw - 110, iy + 8, 100, 26, 'BUY $' + cost, { disabled: game.player.money < cost })) { if (VAMP.Economy.buy(game, it)) this.shopStock.splice(this.shopStock.indexOf(it), 1); }
        } else {
          if (this.btn(ctx, lx + lw - 110, iy + 8, 100, 26, 'SELL $' + VAMP.Inventory.sellValue(it))) VAMP.Economy.sell(game, it);
        }
        iy += 46;
      }
      ctx.restore();
      if (list.length === 0) { ctx.fillStyle = '#777'; ctx.font = '12px Verdana'; ctx.fillText(this.shopMode === 'buy' ? 'Sold out — come back tomorrow night.' : 'Nothing to sell.', lx + 8, ly + 30); }
    },

    // ----- MISSION BOARD -----
    renderBoard(ctx, game, w, h) {
      const pw = 640, ph = 420, x = (w - pw) / 2, y = (h - ph) / 2;
      this.panel(ctx, x, y, pw, ph, 'CONTRACTS');
      if (this.btn(ctx, x + pw - 92, y + 14, 78, 28, 'LEAVE [E]')) this.close();
      // legend-title context: flavor text that reacts to the player's standing
      if (VAMP.Legend) {
        const BOARD_FLAVOR = {
          'Fledgling':          'A local runner slides an envelope across the bar. "New blood? We got work."',
          'Neonate':            'The broker nods — you\'re no longer a stranger. Word travels fast.',
          'Anarch':             'Your name moves through the underground. These contacts came to YOU.',
          'Ancilla':            'Three factions sent runners tonight. Your reputation holds doors open.',
          'Baron':              'The city watches you. Even rivals offer you first refusal on these contracts.',
          'Elder':              'They wait for YOUR approval. The contracts on this board are yours by right.',
          'Prince of the City': 'There is no one above you. These are not contracts — they are demands you choose to honor.',
        };
        const titleName = VAMP.Legend.title(game.player).name;
        const flavor = BOARD_FLAVOR[titleName] || '';
        if (flavor) { ctx.fillStyle = '#7a6888'; ctx.font = 'italic 10px Verdana'; ctx.fillText(flavor, x + 16, y + 43); }
      }
      let cy = y + 55;
      if (game.activeMission) {
        ctx.fillStyle = '#e0a0b8'; ctx.font = '12px Verdana'; ctx.fillText('You already have an active contract: ' + game.activeMission.name, x + 16, cy + 4);
        if (this.btn(ctx, x + 16, cy + 14, 200, 28, 'Abandon current contract', { color: 'rgba(80,20,30,0.9)' })) VAMP.Missions.abandon(game);
        cy += 56;
      }
      for (const m of this.offers) {
        if (m.state !== 'available') continue;
        ctx.fillStyle = 'rgba(24,18,26,0.85)'; rr(ctx, x + 16, cy, pw - 32, 84, 5); ctx.fill();
        ctx.fillStyle = m.color; ctx.fillRect(x + 16, cy, 5, 84);
        ctx.fillStyle = m.color; ctx.font = 'bold 15px Verdana'; ctx.fillText(m.icon + '  ' + m.name, x + 30, cy + 22);
        let _descY = cy + 40;
        if (m.isStory && VAMP.Missions.CHAINS && VAMP.Missions.CHAINS[m.chain]) {
          const _ch = VAMP.Missions.CHAINS[m.chain];
          ctx.fillStyle = m.climax ? '#ffd24a' : '#caa6e0'; ctx.font = 'bold 9px Verdana';
          ctx.fillText((m.climax ? '★ CLIMAX' : '★ STORYLINE') + ' · ' + _ch.name + ' · step ' + (m.chainStep + 1) + '/' + _ch.steps.length, x + 30, cy + 36);
          _descY = cy + 50;
        }
        ctx.fillStyle = '#cdd'; ctx.font = '11px Verdana';
        wrap(ctx, m.desc, x + 30, _descY, pw - 200, 14);
        ctx.fillStyle = '#ffd24a'; ctx.font = 'bold 11px Verdana';
        ctx.fillText('Reward: ' + m.reward.xp + ' XP, $' + m.reward.money + (m.reward.itemChance ? ' + loot' : ''), x + 30, cy + 74);
        if (this.btn(ctx, x + pw - 150, cy + 28, 120, 32, 'ACCEPT', { disabled: !!game.activeMission })) { if (VAMP.Missions.accept(game, m)) this.close(); }
        cy += 92;
      }
      if (!this.offers.length) { ctx.fillStyle = '#777'; ctx.font = '12px Verdana'; ctx.fillText('No contracts tonight.', x + 24, cy + 10); }
    },

    // ----- HAVEN (services + base-building) -----
    renderHaven(ctx, game, w, h) {
      const p = game.player;
      if (VAMP.ArtFlags && VAMP.ArtFlags.useHavenArt && VAMP.Assets.ready && VAMP.Assets.has('haven_bg')) {
        ctx.drawImage(VAMP.Assets.get('haven_bg'), 0, 0, w, h);
        ctx.fillStyle = 'rgba(5,6,12,0.55)'; ctx.fillRect(0, 0, w, h);
      }
      const pw = Math.min(760, w - 80), ph = Math.min(520, h - 60), x = (w - pw) / 2, y = (h - ph) / 2;
      this.panel(ctx, x, y, pw, ph, this.poi ? this.poi.label : 'Your Haven');
      if (this.btn(ctx, x + pw - 92, y + 14, 78, 28, 'LEAVE [E]')) this.close();
      ctx.fillStyle = '#ffd24a'; ctx.font = 'bold 14px Verdana'; ctx.textAlign = 'right'; ctx.fillText('$ ' + U.fmt(p.money), x + pw - 110, y + 30); ctx.textAlign = 'left';

      // LEFT: services
      const lx = x + 16, colW = (pw - 48) / 2;
      ctx.fillStyle = '#e0a0b8'; ctx.font = 'bold 13px Verdana'; ctx.fillText('SERVICES', lx, y + 54);
      let by = y + 64;
      const svc = VAMP.Economy.SERVICES;
      for (const key of ['heal', 'refillBlood', 'clearHeat', 'bribe', 'respecTree']) {
        const s = svc[key];
        const cost = VAMP.Economy.serviceCost ? VAMP.Economy.serviceCost(game, key) : Math.round(s.cost * (key === 'respecTree' ? 1 : p.derived.priceMult));
        if (this.btn(ctx, lx, by, colW, 30, s.name.split('(')[0] + ' ($' + cost + ')', { align: 'left', disabled: p.money < cost, font: 'bold 11px' })) VAMP.Economy.useService(game, key);
        by += 34;
      }
      // cellar
      VAMP.Haven.ensure(p);
      const cv = Math.floor(p.haven.cellarVitae || 0);
      if (this.btn(ctx, lx, by, colW, 30, 'Draw Cellar Vitae (' + cv + ')', { align: 'left', disabled: cv <= 0, color: 'rgba(120,20,40,0.9)' })) VAMP.Haven.collectVitae(game);
      by += 36;
      if (this.btn(ctx, lx, by, colW, 30, 'Save Game', { color: 'rgba(40,60,80,0.9)' })) { if (VAMP.Save.save(game)) VAMP.UI.notify('Game saved', '#7c7'); }
      by += 36;
      ctx.fillStyle = '#998'; ctx.font = '10px Verdana'; wrap(ctx, 'Heat fades fast here. Reach a haven before dawn to bank the night.', lx, by + 12, colW, 13);

      // RIGHT: haven upgrades (base-building)
      const rx = x + 24 + colW;
      ctx.fillStyle = '#9affd0'; ctx.font = 'bold 13px Verdana'; ctx.fillText('UPGRADE YOUR HAVEN', rx, y + 54);
      let ry = y + 64;
      for (const room of VAMP.Haven.rooms()) {
        const lv = VAMP.Haven.level(p, room.id), cost = VAMP.Haven.cost(p, room.id), maxed = lv >= room.max;
        ctx.fillStyle = 'rgba(24,26,30,0.85)'; rr(ctx, rx, ry, colW, 46, 5); ctx.fill();
        ctx.fillStyle = '#cfe'; ctx.font = 'bold 12px Verdana'; ctx.fillText(room.glyph + ' ' + room.name + '  [' + lv + '/' + room.max + ']', rx + 8, ry + 15);
        ctx.fillStyle = '#9a8'; ctx.font = '9px Verdana'; wrap(ctx, room.desc, rx + 8, ry + 28, colW - 90, 10);
        if (this.btn(ctx, rx + colW - 78, ry + 10, 70, 26, maxed ? 'MAX' : '$' + cost, { disabled: maxed || p.money < cost, font: 'bold 10px' })) VAMP.Haven.upgrade(game, room.id);
        ry += 50;
      }
    },

    drawTip(ctx, tip, w, h) {
      const m = VAMP.Input.mouse;
      ctx.font = '11px Verdana';
      let maxw = ctx.measureText(tip.title).width;
      const lines = (tip.lines || []).filter(Boolean);
      for (const l of lines) maxw = Math.max(maxw, ctx.measureText(l).width);
      const bw = maxw + 20, bh = 22 + lines.length * 15;
      let bx = m.x + 16, by = m.y + 16;
      if (bx + bw > w) bx = w - bw - 6; if (by + bh > h) by = h - bh - 6;
      ctx.fillStyle = 'rgba(8,6,12,0.96)'; rr(ctx, bx, by, bw, bh, 5); ctx.fill();
      ctx.strokeStyle = tip.color || 'rgba(180,140,160,0.6)'; ctx.lineWidth = 1; rr(ctx, bx + 0.5, by + 0.5, bw - 1, bh - 1, 5); ctx.stroke();
      ctx.fillStyle = tip.color || '#e0a0b8'; ctx.font = 'bold 12px Verdana'; ctx.fillText(tip.title, bx + 10, by + 16);
      ctx.fillStyle = '#cdd'; ctx.font = '10px Verdana';
      let ly = by + 32; for (const l of lines) { ctx.fillText(l, bx + 10, ly); ly += 15; }
    },
  };

  function rr(ctx, x, y, w, h, r) {
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    ctx.beginPath(); ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
  }
  // truncate a string with an ellipsis so it fits within maxW at the current ctx.font
  function ellip(ctx, text, maxW) {
    text = '' + text;
    if (ctx.measureText(text).width <= maxW) return text;
    let s = text;
    while (s.length > 1 && ctx.measureText(s + '…').width > maxW) s = s.slice(0, -1);
    return s + '…';
  }
  function wrap(ctx, text, x, y, maxW, lh) {
    const words = ('' + text).split(' '); let line = '', yy = y;
    for (const wd of words) { const t = line + wd + ' '; if (ctx.measureText(t).width > maxW && line) { ctx.fillText(line, x, yy); line = wd + ' '; yy += lh; } else line = t; }
    ctx.fillText(line, x, yy);
  }

  VAMP.Menus = MZ;
})();
