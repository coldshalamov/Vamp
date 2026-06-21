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
    p.derived.critChance = 0;
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

    p._lastDmgType = null;
    const aoeTarget = VAMP.Npc.create(g.world, 'gunner', p.x + 24, p.y, { hp: 100 });
    aoeTarget.armor = 0;
    aoeTarget.resist = { blood: 0.5 };
    g.addNPC(aoeTarget);
    const aoeProjectile = VAMP.Projectile.make({
      x: p.x,
      y: p.y,
      owner: 'player',
      dmg: 20,
      aoe: 80,
      aoeDmg: 20,
      color: '#e0203f',
      dmgType: 'blood',
      kind: 'blood',
      life: 0.001,
    });
    const beforeAoe = aoeTarget.hp;
    VAMP.Projectile.update(aoeProjectile, 0.01, g);
    out.bloodProjectileAoeResistance = {
      damage: beforeAoe - aoeTarget.hp,
      lastDmgType: p._lastDmgType || null,
    };

    p._lastDmgType = null;
    const v = VAMP.Vehicle.create(g.world, 'sedan', p.x, p.y, {});
    v.driver = 'player';
    v.ai = false;
    v.speed = 200;
    v.angle = 0;
    p.inVehicle = v;
    g.addVehicle(v);
    const vehicleTarget = VAMP.Npc.create(g.world, 'gunner', v.x + 5, v.y, { hp: 100 });
    vehicleTarget.armor = 0;
    vehicleTarget.resist = { phys: 0.5 };
    g.addNPC(vehicleTarget);
    const beforeVehicle = vehicleTarget.hp;
    VAMP.Vehicle.update(v, 0.001, g);
    out.vehicleRunoverResistance = {
      damage: beforeVehicle - vehicleTarget.hp,
      expected: Math.abs(v.speed) * 0.12 * 0.5,
      lastDmgType: p._lastDmgType || null,
    };

    g.newGame(13002, 'brujah', 0, 'normal');
    const badReagentSave = VAMP.Save.serialize(g);
    badReagentSave.player.reagents = 'not-a-reagent-map';
    badReagentSave.player.progress = { revealed: { feed: 1, havenUpgrade: 1 }, seen: {}, objIdx: 0 };
    g.loadGame(badReagentSave, 0);
    VAMP.Progress.check(g);
    out.reagentSaveSanitation = {
      reagents: g.player.reagents,
      alchemyRevealed: !!(g.player.progress && g.player.progress.revealed && g.player.progress.revealed.alchemy),
    };

    g.newGame(13003, 'brujah', 0, 'normal');
    const badUnlockSave = VAMP.Save.serialize(g);
    badUnlockSave.player.level = 1;
    badUnlockSave.player.pounceUnlocked = 'yes';
    badUnlockSave.player.finisherUnlocked = { bad: true };
    badUnlockSave.player.progress = { revealed: { move: 1, feed: 1 }, seen: {}, objIdx: 0 };
    g.loadGame(badUnlockSave, 0);
    out.signatureUnlockSaveSanitation = {
      level: g.player.level,
      pounceUnlocked: g.player.pounceUnlocked,
      finisherUnlocked: g.player.finisherUnlocked,
      pounceRevealed: !!(g.player.progress && g.player.progress.revealed && g.player.progress.revealed.pounce),
      finisherRevealed: !!(g.player.progress && g.player.progress.revealed && g.player.progress.revealed.finisher),
    };

    return out;
  });

  await browser.close();

  assert(report.bloodPowerResistance.ok === true, 'Blood power did not execute', report.bloodPowerResistance);
  assert(Math.abs(report.bloodPowerResistance.damage - 10) < 0.001, 'Blood power ignored blood resistance', report.bloodPowerResistance);
  assert(report.bloodPowerResistance.lastDmgType === 'blood', 'Blood power did not record damage type', report.bloodPowerResistance);
  assert(Math.abs(report.bloodDotResistance.damage - 10) < 0.001, 'Blood DoT ignored blood resistance', report.bloodDotResistance);
  assert(report.bloodDotResistance.lastDmgType === 'blood', 'Blood DoT did not record damage type', report.bloodDotResistance);
  assert(Math.abs(report.bloodProjectileAoeResistance.damage - 10) < 0.001, 'Blood projectile AoE ignored blood resistance', report.bloodProjectileAoeResistance);
  assert(report.bloodProjectileAoeResistance.lastDmgType === 'blood', 'Blood projectile AoE did not record damage type', report.bloodProjectileAoeResistance);
  assert(Math.abs(report.vehicleRunoverResistance.damage - report.vehicleRunoverResistance.expected) < 0.001, 'Vehicle run-over ignored physical resistance', report.vehicleRunoverResistance);
  assert(report.vehicleRunoverResistance.lastDmgType === 'phys', 'Vehicle run-over did not record physical damage type', report.vehicleRunoverResistance);
  assert(report.reagentSaveSanitation.reagents === null, 'Malformed reagent save data was not sanitized', report.reagentSaveSanitation);
  assert(report.reagentSaveSanitation.alchemyRevealed === false, 'Malformed reagent save data falsely unlocked alchemy', report.reagentSaveSanitation);
  assert(report.signatureUnlockSaveSanitation.pounceUnlocked === false, 'Malformed save data falsely unlocked pounce', report.signatureUnlockSaveSanitation);
  assert(report.signatureUnlockSaveSanitation.finisherUnlocked === false, 'Malformed save data falsely unlocked finisher', report.signatureUnlockSaveSanitation);
  assert(report.signatureUnlockSaveSanitation.pounceRevealed === false, 'Malformed save data falsely revealed pounce', report.signatureUnlockSaveSanitation);
  assert(report.signatureUnlockSaveSanitation.finisherRevealed === false, 'Malformed save data falsely revealed finisher', report.signatureUnlockSaveSanitation);

  console.log(JSON.stringify(report, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
