/**
 * Wave 9 gameplay/save regression probe.
 * Run with a local server:
 *   VAMP_URL=http://localhost:5599 node scripts/wave9-gameplay-probe.mjs
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

    g.newGame(9009, 'brujah', 0, 'normal');
    const d = g.world.districts[0];
    VAMP.Domains.ensure(g);
    g.domains[d.id].contesting = true;
    const savedContest = VAMP.Save.serialize(g);
    g.loadGame(savedContest, 0);
    const baronAlive = g.npcs.some((n) => n.baronOf === d.id && !n.dead);
    out.domainRestore = {
      district: d.id,
      savedContesting: savedContest.domains[d.id].contesting,
      restoredContesting: !!g.domains[d.id].contesting,
      baronAlive,
      uiDisabled: !!g.domains[d.id].contesting || baronAlive,
    };

    g.newGame(9010, 'brujah', 0, 'normal');
    const corruptCollect = {
      state: 'active',
      type: 'collect',
      id: 123,
      name: 'Corrupt Collect',
      icon: '#',
      color: '#fff',
      desc: '',
      level: 1,
      need: 'bad',
      progress: 999,
      reward: { xp: 1, money: 1, itemChance: 0 },
      targetName: 'Target',
      modifier: { id: 'none', bonus: 0 },
      timeLimit: 0,
      timer: 0,
      phase: 0,
      data: {},
    };
    const restored = VAMP.Missions.restore(g, corruptCollect);
    out.missionProgressRestore = {
      restored,
      need: g.activeMission && g.activeMission.need,
      progress: g.activeMission && g.activeMission.progress,
      missionPickups: g.pickups.filter((p) => p.mission === 123).length,
    };

    g.newGame(9011, 'brujah', 0, 'normal');
    const collect = {
      state: 'active',
      type: 'collect',
      id: 124,
      name: 'Partial Collect',
      icon: '#',
      color: '#fff',
      desc: '',
      level: 1,
      need: 3,
      progress: 2,
      reward: { xp: 1, money: 1, itemChance: 0 },
      targetName: 'Target',
      modifier: { id: 'none', bonus: 0 },
      timeLimit: 0,
      timer: 0,
      phase: 0,
      data: {},
    };
    VAMP.Missions.restore(g, collect);
    out.partialCollectRestore = {
      need: g.activeMission && g.activeMission.need,
      progress: g.activeMission && g.activeMission.progress,
      missionPickups: g.pickups.filter((p) => p.mission === 124).length,
    };

    g.newGame(9012, 'brujah', 0, 'normal');
    const dest = g.world.randomWalkPos(Math.random);
    const timedCourier = {
      state: 'active',
      type: 'courier',
      id: 125,
      name: 'Timed Courier',
      icon: '#',
      color: '#fff',
      desc: '',
      level: 1,
      need: 1,
      progress: 0,
      reward: { xp: 1, money: 1, itemChance: 0 },
      targetName: 'Target',
      modifier: { id: 'none', bonus: 0 },
      timeLimit: 42,
      timer: 7,
      phase: 0,
      data: { dest },
    };
    VAMP.Missions.restore(g, timedCourier);
    out.timedCourierRestore = {
      timeLimit: g.activeMission && g.activeMission.timeLimit,
      timer: g.activeMission && g.activeMission.timer,
    };

    return out;
  });

  await browser.close();

  assert(report.domainRestore.savedContesting === true, 'Probe did not construct a contested save', report.domainRestore);
  assert(report.domainRestore.restoredContesting === false, 'Stale domain contesting flag survived load', report.domainRestore);
  assert(report.domainRestore.uiDisabled === false, 'Holdings contest button would remain disabled after load', report.domainRestore);

  assert(report.missionProgressRestore.restored === true, 'Corrupt mission did not restore for sanitation probe', report.missionProgressRestore);
  assert(report.missionProgressRestore.need === 1, 'Corrupt mission need was not sanitized to a playable value', report.missionProgressRestore);
  assert(report.missionProgressRestore.progress === 0, 'Corrupt mission progress was not clamped below sanitized need', report.missionProgressRestore);
  assert(report.missionProgressRestore.missionPickups === 1, 'Corrupt collect mission did not spawn the remaining relic', report.missionProgressRestore);

  assert(report.partialCollectRestore.need === 3, 'Partial collect need changed unexpectedly', report.partialCollectRestore);
  assert(report.partialCollectRestore.progress === 2, 'Partial collect progress changed unexpectedly', report.partialCollectRestore);
  assert(report.partialCollectRestore.missionPickups === 1, 'Partial collect did not spawn exactly the remaining relic', report.partialCollectRestore);
  assert(report.timedCourierRestore.timeLimit === 42, 'Timed courier time limit was not restored', report.timedCourierRestore);
  assert(report.timedCourierRestore.timer === 7, 'Timed courier timer was reset during restore', report.timedCourierRestore);

  console.log(JSON.stringify(report, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
