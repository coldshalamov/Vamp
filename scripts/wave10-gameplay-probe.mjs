/**
 * Wave 10 gameplay/domain placement regression probe.
 * Run with a local server:
 *   VAMP_URL=http://localhost:5599 node scripts/wave10-gameplay-probe.mjs
 */
import { chromium } from 'playwright';

const BASE = (process.env.VAMP_URL || 'http://localhost:5599').replace(/\/+$/, '');

function assert(ok, message, detail) {
  if (!ok) {
    const extra = detail == null ? '' : '\n' + JSON.stringify(detail, null, 2);
    throw new Error(message + extra);
  }
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto(BASE + '/', { waitUntil: 'networkidle', timeout: 60000 });
  await page.waitForFunction(() => window.VAMP && VAMP.Assets && VAMP.Assets.ready, undefined, { timeout: 45000 });

  const report = await page.evaluate(() => {
    function makeRng(seed) {
      let s = seed >>> 0;
      return function () {
        s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
        return s / 0x100000000;
      };
    }
    function hashId(id) {
      let h = 2166136261 >>> 0;
      for (let i = 0; i < id.length; i++) {
        h ^= id.charCodeAt(i);
        h = Math.imul(h, 16777619) >>> 0;
      }
      return h >>> 0;
    }

    const out = { domainContestPlacement: [] };
    const g = VAMP.Game;
    const originalRandom = Math.random;

    try {
      for (let seed = 1000; seed < 1016; seed++) {
        g.newGame(seed, 'brujah', 0, 'normal');
        const districtIds = g.world.districts.map((d) => d.id);
        for (const id of districtIds) {
          Math.random = makeRng((Math.imul(seed, 2654435761) ^ hashId(id)) >>> 0);
          g.newGame(seed, 'brujah', 0, 'normal');
          VAMP.Domains.ensure(g);
          const before = g.npcs.length;
          VAMP.Domains.contest(g, id);
          const spawned = g.npcs.slice(before).filter((n) => n.baronOf === id || n.baronGuard === id);
          const bad = spawned
            .filter((n) => !g.world.isWalkable(n.x, n.y))
            .map((n) => ({
              kind: n.baronOf ? 'baron' : 'guard',
              x: Math.round(n.x),
              y: Math.round(n.y),
              tile: g.world.tileAt(n.x, n.y),
            }));
          if (spawned.length !== 4 || bad.length) {
            out.domainContestPlacement.push({ seed, district: id, spawned: spawned.length, bad });
          }
        }
      }
    } finally {
      Math.random = originalRandom;
    }

    return out;
  });

  await browser.close();

  assert(
    report.domainContestPlacement.length === 0,
    'Domain contest spawned an invalid Baron encounter placement',
    report.domainContestPlacement.slice(0, 8),
  );

  console.log(JSON.stringify(report, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
