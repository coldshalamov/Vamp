/**
 * Wave 13 gameplay systems regression probe.
 * Run with a local server:
 *   VAMP_URL=http://localhost:5599 node scripts/wave13-gameplay-systems-probe.mjs
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
    const out = {};
    const g = VAMP.Game;

    g.newGame(13001, 'brujah', 0, 'normal');
    const p = g.player;
    p.blood = p.derived.maxBlood;
    const bloodTarget = VAMP.Npc.create(g.world, 'gunner', p.x + 60, p.y, { hp: 100 });
    bloodTarget.armor = 0;
    bloodTarget.resist = { blood: 0.5 };
    g.addNPC(bloodTarget);
    const beforeTheft = bloodTarget.hp;
    const ok = VAMP.PowerFX.bsTheft(p, g, { range: 120, dmg: 20, steal: 0.01 });
    out.bloodPowerResistance = {
      ok,
      damage: beforeTheft - bloodTarget.hp,
      lastDmgType: p._lastDmgType || null,
    };

    p._lastDmgType = null;
    const dotTarget = VAMP.Npc.create(g.world, 'gunner', p.x + 80, p.y, { hp: 100 });
    dotTarget.armor = 0;
    dotTarget.resist = { blood: 0.5 };
    g.addNPC(dotTarget);
    VAMP.Combat.applyStatus(dotTarget, 'bleed', { dur: 5, dps: 20, dmgType: 'blood', popup: false });
    const beforeDot = dotTarget.hp;
    VAMP.Combat.updateStatuses(dotTarget, 1, g, false);
    out.bloodDotResistance = {
      damage: beforeDot - dotTarget.hp,
      lastDmgType: p._lastDmgType || null,
    };

    return out;
  });

  await browser.close();

  assert(report.bloodPowerResistance.ok === true, 'Blood power did not execute', report.bloodPowerResistance);
  assert(Math.abs(report.bloodPowerResistance.damage - 10) < 0.001, 'Blood power ignored blood resistance', report.bloodPowerResistance);
  assert(report.bloodPowerResistance.lastDmgType === 'blood', 'Blood power did not record damage type', report.bloodPowerResistance);
  assert(Math.abs(report.bloodDotResistance.damage - 10) < 0.001, 'Blood DoT ignored blood resistance', report.bloodDotResistance);
  assert(report.bloodDotResistance.lastDmgType === 'blood', 'Blood DoT did not record damage type', report.bloodDotResistance);

  console.log(JSON.stringify(report, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
