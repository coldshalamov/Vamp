/* =========================================================================
 * VAMPIRE CITY — theme.js  (VAMP.Theme)
 * Single source of truth for the look: a centralized palette + typography
 * + shared panel/bar drawing widgets. Replaces the scattered magic-string
 * colors across the HUD/menus so the whole UI reads as one coherent product.
 * Loaded BEFORE systems/ui so VAMP.Theme exists by the time menus render.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  // ---- color tokens (hex; rgba() derived on demand via Util.shade) ----
  // Names are semantic so re-skinning is a one-file edit.
  const COLORS = {
    // surfaces
    bg:        '#05060a',     // page / canvas void
    night:     '#080a18',     // darkness overlay tint
    panel:     '#0e0a12',     // menu panel body
    panel2:    '#161019',     // panel row / card
    panelEdge: '#7a2040',     // panel + accent border (crimson)
    ink:       '#e8e0e8',     // primary text
    inkDim:    '#9a8a9c',     // secondary text
    inkFaint:  '#5a4f5e',     // tertiary / hints

    // vampire brand
    blood:     '#c0303a',     // primary brand crimson
    bloodDeep: '#7a1530',     // collar / accent
    bloodGlow: '#ff2f6e',     // vitae
    gold:      '#ffd24a',     // money / reward / keystone
    goldDeep:  '#c89020',
    arcane:    '#b07bff',     // xp / elder / discipline
    arcaneDeep:'#7a4bff',

    // vitals
    health:    '#d8324a',
    vitae:     '#ff2f6e',
    hunger:    '#e07020',
    humanity:  '#9ad0ff',

    // factions / states
    ally:      '#5aff8c',
    hostile:   '#ff5a5a',
    warning:   '#ff8030',
    calm:      '#7ee0a0',
    info:      '#7ad0ff',
    shield:    '#7ad0ff',

    // rarity (kept in sync with Data.RARITY so a single legend matches)
    rarity: {
      common: '#b8b8c0', uncommon: '#5ad06a', rare: '#5a9cff',
      epic: '#c060ff', legendary: '#ff9a30', relic: '#ff7a30', innate: '#cccccc',
    },
  };

  // ---- typography ----
  // Refined system-font stack (no external deps; keeps the file:// property).
  // Display = elegant serif (thematically apt for a Vampire RPG); UI = clean sans.
  const FONT = {
    display: "'Iowan Old Style','Palatino Linotype',Palatino,'Book Antiqua',Constantia,Georgia,serif",
    ui:      "system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Verdana,Arial,sans-serif",
    mono:    "'SF Mono',Consolas,'Courier New',monospace",
    // size presets (px) — a real type scale, not ad-hoc magic numbers
    size: { xs: 10, sm: 11, md: 13, lg: 15, xl: 18, xxl: 22, huge: 30, mega: 60 },
    weight: { reg: 400, med: 500, bold: 700 },
  };

  // set the canvas/CSS font once; returns a short css font string for ctx.font
  function css(size, family, weight) {
    const fam = family || FONT.ui;
    const w = weight || FONT.weight.bold;
    let sz = size;
    if (typeof size === 'string') sz = size; // allow "bold 14px" passthrough
    else sz = w + ' ' + size + 'px';
    return sz + ' ' + fam;
  }

  // ---- shared rounded-rect path (every module had its own copy) ----
  function rr(ctx, x, y, w, h, r) {
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  // glassy panel with a subtle top sheen + accent edge. title is optional.
  function panel(ctx, x, y, w, h, opts) {
    opts = opts || {};
    const edge = opts.edge || COLORS.panelEdge;
    ctx.save();
    // body
    ctx.fillStyle = opts.bg || 'rgba(14,10,18,0.95)';
    rr(ctx, x, y, w, h, opts.r != null ? opts.r : 8); ctx.fill();
    // top sheen (subtle highlight band)
    const sh = ctx.createLinearGradient(0, y, 0, y + Math.min(40, h));
    sh.addColorStop(0, 'rgba(255,255,255,0.06)');
    sh.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = sh; rr(ctx, x, y, w, h, opts.r != null ? opts.r : 8); ctx.fill();
    // accent border
    ctx.strokeStyle = edge; ctx.lineWidth = opts.lw || 1.5;
    rr(ctx, x + 0.5, y + 0.5, w - 1, h - 1, opts.r != null ? opts.r : 8); ctx.stroke();
    // title bar
    if (opts.title) {
      ctx.fillStyle = opts.titleColor || COLORS.blood;
      ctx.font = css(FONT.size.xl, FONT.display);
      ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic';
      ctx.fillText(opts.title, x + 18, y + 28);
    }
    ctx.restore();
  }

  // a richer health/bar: beveled bg, gradient fill, sheen, optional label/value.
  function bar(ctx, x, y, w, h, frac, color, opts) {
    opts = opts || {};
    const f = Math.max(0, Math.min(1, frac));
    ctx.save();
    // recessed track
    ctx.fillStyle = 'rgba(0,0,0,0.55)';
    rr(ctx, x, y, w, h, 3); ctx.fill();
    // fill with a vertical gradient (lighter on top)
    if (f > 0) {
      const fw = Math.max(0, f) * (w - 2);
      const g = ctx.createLinearGradient(0, y, 0, y + h);
      g.addColorStop(0, VAMP.Util.shade(color, 0.22));
      g.addColorStop(1, VAMP.Util.shade(color, -0.15));
      ctx.fillStyle = g;
      rr(ctx, x + 1, y + 1, fw, h - 2, 2); ctx.fill();
      // top sheen line
      ctx.fillStyle = 'rgba(255,255,255,0.18)';
      rr(ctx, x + 1, y + 1, fw, Math.max(1, h * 0.35), 2); ctx.fill();
    }
    // hairline outline
    ctx.strokeStyle = 'rgba(255,255,255,0.14)'; ctx.lineWidth = 1;
    rr(ctx, x + 0.5, y + 0.5, w - 1, h - 1, 3); ctx.stroke();
    // labels
    if (opts.label) {
      ctx.font = css(FONT.size.xs); ctx.fillStyle = 'rgba(255,255,255,0.82)';
      ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic';
      ctx.fillText(opts.label, x + 6, y + h - 4);
    }
    if (opts.value) {
      ctx.font = css(FONT.size.xs); ctx.fillStyle = 'rgba(255,255,255,0.78)';
      ctx.textAlign = 'right';
      ctx.fillText(opts.value, x + w - 5, y + h - 4); ctx.textAlign = 'left';
    }
    ctx.restore();
  }

  VAMP.Theme = { COLORS, FONT, css, rr, panel, bar };
})();
