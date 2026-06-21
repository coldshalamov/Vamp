/**
 * VAMP comprehensive smoke QA — Playwright headless
 * Run: node scripts/qa-smoke.mjs
 */
import { chromium } from 'playwright';

const BASE = (process.env.VAMP_URL || 'http://localhost:5599').replace(/\/+$/, '');
const errors = [];
const warnings = [];

async function main() {
  const staticGuardReport = [];
  const blockedPaths = [
    '/.git/config',
    '/.serena/project.yml',
    '/server.js',
    '/scripts/qa-smoke.mjs',
    '/Play.bat',
    '/js/../server.js',
    '/assets/../.git/config',
    '/%2e%2e/server.js',
    '/js/%2e%2e/server.js',
    '/assets/%2e%2e/.git/config',
    '/js/%5c..%5cserver.js',
  ];
  for (const path of blockedPaths) {
    const res = await fetch(new URL(path, BASE));
    staticGuardReport.push({ path, status: res.status });
  }

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  page.on('console', (msg) => {
    const t = msg.type();
    const text = msg.text();
    if (t === 'error') errors.push(text);
    else if (t === 'warning' && !text.includes('DevTools')) warnings.push(text);
  });
  page.on('pageerror', (e) => errors.push('PAGEERROR: ' + e.message));

  const failedAssets = [];
  page.on('response', (res) => {
    const url = res.url();
    if (url.includes('/js/') || url.includes('/assets/') || url.includes('/css/')) {
      if (res.status() >= 400) failedAssets.push(`${res.status()} ${url}`);
    }
  });

  await page.goto(BASE + '/', { waitUntil: 'networkidle', timeout: 60000 });

  // Wait for splash / load
  await page.waitForFunction(() => window.VAMP && VAMP.Assets && VAMP.Assets.ready, undefined, { timeout: 45000 });

  const loadReport = await page.evaluate(() => {
    const A = VAMP.Assets;
    const M = VAMP.AssetManifest;
    const Spr = VAMP.Spriter;
    const PV = VAMP.PowerVFX;
    const powers = VAMP.Data && VAMP.Data.POWERS ? Object.values(VAMP.Data.POWERS) : [];
    const fxNames = powers.map((p) => p.fx).filter(Boolean);
    const missingFx = fxNames.filter((fx) => !PV || !PV.hooks[fx]);
    const manifestImageKeys = M && M.ENTRIES
      ? Object.keys(M.ENTRIES).filter((key) => M.ENTRIES[key].path && !M.ENTRIES[key].deprecated)
      : [];
    const missingManifestImages = manifestImageKeys.filter((key) => !A.has(key));
    const concrete = A.get('ground_concrete');
    const plaza = A.get('ground_plaza');
    let concreteBase = null;
    if (concrete) {
      const g = concrete.getContext('2d');
      concreteBase = g.getImageData(32, 32, 1, 1).data.join(',');
    }
    return {
      ready: A.ready,
      bitmapCount: Object.keys(A.bitmaps || {}).length,
      manifestImages: manifestImageKeys.length,
      loadedManifestImages: manifestImageKeys.length - missingManifestImages.length,
      missingManifestImages,
      spriterSheets: Spr ? Object.keys(Spr.sheets || {}).length : 0,
      autotile: !!A.get('autotile_16'),
      groundConcrete: !!concrete,
      groundPlaza: !!plaza,
      concretePixel: concreteBase,
      plazaPixel: plaza ? plaza.getContext('2d').getImageData(32, 32, 1, 1).data.join(',') : null,
      powervfxHooks: PV ? Object.keys(PV.hooks).length : 0,
      missingFx,
      menuBoard: !!A.get('menu_bg_board'),
      menuMap: !!A.get('menu_bg_map'),
    };
  });

  const corruptSaveReport = await page.evaluate(() => {
    const key = 'vampcity_save_v1_0';
    const previous = localStorage.getItem(key);
    const previousMode = VAMP.Game && VAMP.Game.mode;
    localStorage.setItem(key, '{not-json');
    const report = {
      hasSaveSlot: VAMP.Save.hasSaveSlot(0),
      loadSlotNull: VAMP.Save.loadSlot(0) === null,
      summaryNull: VAMP.Save.getSlotSummary(0) === null,
    };
    localStorage.setItem(key, JSON.stringify({
      seed: 1,
      day: 'bad-day',
      player: { clan: { bad: true }, level: 'bad', bloodState: { humanity: 'bad' } },
    }));
    report.malformedSummary = VAMP.Save.getSlotSummary(0);
    report.malformedRenderError = null;
    try {
      VAMP.Game.mode = 'title';
      VAMP.Game.render(1);
    } catch (e) {
      report.malformedRenderError = e.message;
    }
    report.malformedLoad = null;
    try {
      const loaded = VAMP.Save.loadSlot(0);
      VAMP.Game.loadGame(loaded, 0);
      report.malformedLoad = {
        mode: VAMP.Game.mode,
        clan: VAMP.Game.player && VAMP.Game.player.clan,
        clanType: typeof (VAMP.Game.player && VAMP.Game.player.clan),
        clanBaneName: VAMP.Game.player && VAMP.Game.player.clanBaneName,
        renderError: null,
      };
      try {
        VAMP.Game.render(1);
      } catch (e) {
        report.malformedLoad.renderError = e.message;
      }
    } catch (e) {
      report.malformedLoad = { error: e.message };
    }
    report.malformedCodexLoad = null;
    try {
      VAMP.Game.loadGame({
        seed: 2,
        day: 1,
        player: { clan: 'brujah', codex: 'bad' },
      }, 0);
      report.malformedCodexLoad = {
        mode: VAMP.Game.mode,
        codexType: typeof (VAMP.Game.player && VAMP.Game.player.codex),
        codexCompleteType: typeof (VAMP.Game.player && VAMP.Game.player.codex && VAMP.Game.player.codex.complete),
        renderError: null,
      };
      try {
        VAMP.Menus.openScreen('char', { tab: 'codex' });
        VAMP.Game.render(1);
      } catch (e) {
        report.malformedCodexLoad.renderError = e.message;
      } finally {
        VAMP.Menus.close();
      }
    } catch (e) {
      report.malformedCodexLoad = { error: e.message };
    }
    report.malformedProgressLoad = null;
    try {
      VAMP.Game.loadGame({
        seed: 3,
        day: 1,
        player: {
          clan: 'brujah',
          level: 1,
          codex: 'bad',
          mastery: 'bad',
          reagents: null,
          nemeses: [],
          legend: 0,
          progress: {
            revealed: { codex: 'bad', mastery: 'bad', elder: 'bad', alchemy: 'bad', nemesis: 'bad' },
            seen: { 'codex:done': 'bad', 'move:done': 1 },
            objIdx: 'bad',
          },
        },
      }, 0);
      report.malformedProgressLoad = {
        mode: VAMP.Game.mode,
        revealed: Object.assign({}, VAMP.Game.player.progress && VAMP.Game.player.progress.revealed),
        seen: Object.assign({}, VAMP.Game.player.progress && VAMP.Game.player.progress.seen),
        masteryVisible: VAMP.Progress.tabVisible(VAMP.Game, 'mastery'),
        codexVisible: VAMP.Progress.tabVisible(VAMP.Game, 'codex'),
        elderVisible: VAMP.Progress.tabVisible(VAMP.Game, 'elder'),
        alchemyFeature: VAMP.Progress.hudFeature(VAMP.Game, 'alchemy'),
        nemesisFeature: VAMP.Progress.hudFeature(VAMP.Game, 'nemesis'),
        forcedTabAfterRender: null,
        renderError: null,
      };
      try {
        VAMP.Menus.openScreen('char', { tab: 'codex' });
        VAMP.Game.render(1);
        report.malformedProgressLoad.forcedTabAfterRender = VAMP.Menus.tab;
      } catch (e) {
        report.malformedProgressLoad.renderError = e.message;
      } finally {
        VAMP.Menus.close();
      }
    } catch (e) {
      report.malformedProgressLoad = { error: e.message };
    }
    if (previousMode) VAMP.Game.mode = previousMode;
    if (previous == null) localStorage.removeItem(key);
    else localStorage.setItem(key, previous);
    return report;
  });

  // Start game
  await page.evaluate(() => {
    VAMP.Game.newGame(42);
    VAMP.Game.mode = 'play';
  });
  await page.waitForTimeout(800);

  // Simulate frames + movement
  for (let i = 0; i < 30; i++) {
    await page.evaluate((frame) => {
      const g = VAMP.Game;
      if (!g) return;
      g.keys = g.keys || {};
      g.keys['KeyW'] = frame % 4 < 2;
      g.keys['KeyD'] = frame % 4 >= 2;
      if (g.tick) g.tick(1 / 60);
      if (g.render) g.render();
    }, i);
    await page.waitForTimeout(16);
  }

  const gameReport = await page.evaluate(() => {
    const g = VAMP.Game;
    if (!g) return { error: 'no game' };
    const w = g.world;
    VAMP.Props.gather(g.cam, w, performance.now());
    const st = VAMP.Props.standing();
    const ptypes = {};
    for (let i = 0; i < st.n; i++) {
      const pt = st.arr[i].ptype;
      ptypes[pt] = (ptypes[pt] || 0) + 1;
    }
    let graffiti = 0, graffitiLabeled = 0;
    for (const d of VAMP.Decals.pool) {
      if (!d.life || d.life <= 0) continue;
      if (d.k === 'graffiti') { graffiti++; if (d.label) graffitiLabeled++; }
      if (d.k !== 'graffiti' && d.label) return { error: 'stale decal label on ' + d.k };
    }
    return {
      state: g.state,
      props: st.n,
      ptypes,
      decals: VAMP.Decals.pool.filter((d) => d.life > 0).length,
      graffiti,
      graffitiLabeled,
      npcs: g.npcs ? g.npcs.length : 0,
      player: g.player ? { x: g.player.x, y: g.player.y } : null,
      weather: g.weather ? g.weather.kind : null,
    };
  });

  const canvasReport = await page.evaluate(() => {
    VAMP.Game.render(1);
    const canvas = document.getElementById('game');
    const ctx = canvas && canvas.getContext('2d');
    if (!canvas || !ctx || !canvas.width || !canvas.height) return { error: 'missing canvas backing store' };
    const frame = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
    let nonBlank = false;
    for (let i = 0; i < frame.length; i += 4) {
      if (frame[i + 3] > 0 && (frame[i] || frame[i + 1] || frame[i + 2])) { nonBlank = true; break; }
    }
    const mid = ((Math.floor(canvas.height / 2) * canvas.width) + Math.floor(canvas.width / 2)) * 4;
    return { width: canvas.width, height: canvas.height, centerPixel: Array.from(frame.slice(mid, mid + 4)), nonBlank };
  });

  // Open menus via real API + render each
  const menuStates = [];
  for (const [key, tab] of [['pause', null], ['board', null], ['char', 'map'], ['char', 'skills']]) {
    await page.evaluate(([k, t]) => {
      if (t) VAMP.Menus.openScreen(k, { tab: t });
      else VAMP.Menus.openScreen(k);
      VAMP.Game.render(1);
    }, [key, tab]);
    await page.waitForTimeout(100);
    menuStates.push(key + (tab ? ':' + tab : ''));
  }

  await page.evaluate(() => {
    VAMP.Menus.close();
    VAMP.Game.weather.kind = 'rain';
    VAMP.Game.weather.targetFog = 0.2;
    VAMP.Game.render(1);
    VAMP.Game.weather.kind = 'fog';
    VAMP.Game.weather.targetFog = 0.4;
    VAMP.Game.render(1);
  });
  await page.waitForTimeout(200);

  await browser.close();

  const report = { loadReport, corruptSaveReport, gameReport, canvasReport, menuStates, staticGuardReport, failedAssets, errors, warnings };
  console.log(JSON.stringify(report, null, 2));

  let fail = false;
  if (errors.length) { console.error('CONSOLE ERRORS:', errors); fail = true; }
  if (failedAssets.length) { console.error('FAILED ASSETS:', failedAssets); fail = true; }
  const exposedInternal = staticGuardReport.filter((entry) => entry.status < 400);
  if (exposedInternal.length) { console.error('EXPOSED INTERNAL PATHS:', exposedInternal); fail = true; }
  if (loadReport.missingManifestImages && loadReport.missingManifestImages.length) { console.error('MISSING MANIFEST IMAGES:', loadReport.missingManifestImages); fail = true; }
  if (loadReport.missingFx && loadReport.missingFx.length) { console.error('MISSING FX:', loadReport.missingFx); fail = true; }
  if (corruptSaveReport.hasSaveSlot || !corruptSaveReport.loadSlotNull || !corruptSaveReport.summaryNull) { console.error('CORRUPT SAVE SLOT ACCEPTED:', corruptSaveReport); fail = true; }
  if (corruptSaveReport.malformedRenderError) { console.error('MALFORMED SAVE BROKE TITLE RENDER:', corruptSaveReport); fail = true; }
  if (!corruptSaveReport.malformedSummary || corruptSaveReport.malformedSummary.clan !== 'brujah' || corruptSaveReport.malformedSummary.level !== 1 || corruptSaveReport.malformedSummary.day !== 1 || corruptSaveReport.malformedSummary.humanity !== 5) {
    console.error('MALFORMED SAVE SUMMARY NOT SANITIZED:', corruptSaveReport);
    fail = true;
  }
  if (!corruptSaveReport.malformedLoad || corruptSaveReport.malformedLoad.error || corruptSaveReport.malformedLoad.renderError || corruptSaveReport.malformedLoad.mode !== 'play' || corruptSaveReport.malformedLoad.clan !== 'brujah' || corruptSaveReport.malformedLoad.clanType !== 'string') {
    console.error('MALFORMED SAVE LOAD NOT SANITIZED:', corruptSaveReport);
    fail = true;
  }
  if (!corruptSaveReport.malformedCodexLoad || corruptSaveReport.malformedCodexLoad.error || corruptSaveReport.malformedCodexLoad.renderError || corruptSaveReport.malformedCodexLoad.mode !== 'play' || corruptSaveReport.malformedCodexLoad.codexType !== 'object' || corruptSaveReport.malformedCodexLoad.codexCompleteType !== 'object') {
    console.error('MALFORMED CODEX SAVE LOAD NOT SANITIZED:', corruptSaveReport);
    fail = true;
  }
  const mp = corruptSaveReport.malformedProgressLoad;
  const badRevealed = mp && mp.revealed && (mp.revealed.codex || mp.revealed.mastery || mp.revealed.elder || mp.revealed.alchemy || mp.revealed.nemesis);
  const badSeen = mp && mp.seen && (mp.seen['codex:done'] || mp.seen['move:done'] !== 1);
  if (!mp || mp.error || mp.renderError || mp.mode !== 'play' || mp.masteryVisible || mp.codexVisible || mp.elderVisible || mp.alchemyFeature || mp.nemesisFeature || mp.forcedTabAfterRender !== 'skills' || badRevealed || badSeen) {
    console.error('MALFORMED PROGRESS SAVE LOAD NOT SANITIZED:', corruptSaveReport);
    fail = true;
  }
  if (gameReport.error) { console.error('GAME ERROR:', gameReport.error); fail = true; }
  if (canvasReport.error || !canvasReport.nonBlank) { console.error('CANVAS RENDER FAILED:', canvasReport); fail = true; }
  if (loadReport.powervfxHooks !== 35) { console.error('Expected 35 powervfx hooks, got', loadReport.powervfxHooks); fail = true; }
  const cp = loadReport.concretePixel.split(',').map(Number);
  if (cp[0] < 64) { console.error('ground_concrete too dark (wrong #222 fallback):', loadReport.concretePixel); fail = true; }

  process.exit(fail ? 1 : 0);
}

main().catch((e) => { console.error(e); process.exit(1); });
