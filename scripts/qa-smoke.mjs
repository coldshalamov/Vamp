/**
 * VAMP comprehensive smoke QA — Playwright headless
 * Run: node scripts/qa-smoke.mjs
 */
import { chromium } from 'playwright';

const BASE = process.env.VAMP_URL || 'http://localhost:3456';
const errors = [];
const warnings = [];

async function main() {
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
  await page.waitForFunction(() => window.VAMP && VAMP.Assets && VAMP.Assets.ready, { timeout: 45000 });

  const loadReport = await page.evaluate(() => {
    const A = VAMP.Assets;
    const M = VAMP.AssetManifest;
    const Spr = VAMP.Spriter;
    const PV = VAMP.PowerVFX;
    const powers = VAMP.Data && VAMP.Data.POWERS ? Object.values(VAMP.Data.POWERS) : [];
    const fxNames = powers.map((p) => p.fx).filter(Boolean);
    const missingFx = fxNames.filter((fx) => !PV || !PV.hooks[fx]);
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

  const report = { loadReport, gameReport, menuStates, failedAssets, errors, warnings };
  console.log(JSON.stringify(report, null, 2));

  let fail = false;
  if (errors.length) { console.error('CONSOLE ERRORS:', errors); fail = true; }
  if (failedAssets.length) { console.error('FAILED ASSETS:', failedAssets); fail = true; }
  if (loadReport.missingFx && loadReport.missingFx.length) { console.error('MISSING FX:', loadReport.missingFx); fail = true; }
  if (gameReport.error) { console.error('GAME ERROR:', gameReport.error); fail = true; }
  if (loadReport.powervfxHooks !== 35) { console.error('Expected 35 powervfx hooks, got', loadReport.powervfxHooks); fail = true; }
  const cp = loadReport.concretePixel.split(',').map(Number);
  if (cp[0] < 64) { console.error('ground_concrete too dark (wrong #222 fallback):', loadReport.concretePixel); fail = true; }

  process.exit(fail ? 1 : 0);
}

main().catch((e) => { console.error(e); process.exit(1); });