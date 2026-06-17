/* =========================================================================
 * VAMPIRE CITY — entities/vehicleroad.js
 * Axis-aligned road following for grid traffic (no diagonal zig-zag).
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const U = VAMP.Util;

  const EAST = 0;
  const SOUTH = 1;
  const WEST = 2;
  const NORTH = 3;
  const AXIS = [0, Math.PI * 0.5, Math.PI, -Math.PI * 0.5];

  function axisFromAngle(a) {
    a = ((a % U.TAU) + U.TAU) % U.TAU;
    if (a < Math.PI * 0.25 || a >= Math.PI * 1.75) return EAST;
    if (a < Math.PI * 0.75) return SOUTH;
    if (a < Math.PI * 1.25) return WEST;
    return NORTH;
  }

  function angleForAxis(axis, dir) {
    const base = AXIS[axis];
    return dir < 0 ? ((base + Math.PI) % U.TAU) : base;
  }

  function roadAxisAt(world, x, y) {
    const step = 40;
    const east = world.isRoad(x + step, y);
    const west = world.isRoad(x - step, y);
    const south = world.isRoad(x, y + step);
    const north = world.isRoad(x, y - step);
    if ((east || west) && !(south || north)) return EAST;
    if ((south || north) && !(east || west)) return SOUTH;
    if ((east || west) && (south || north)) return Math.random() < 0.5 ? EAST : SOUTH;
    return axisFromAngle(Math.random() * U.TAU);
  }

  function roadAngleAt(world, x, y) {
    const ax = roadAxisAt(world, x, y);
    return angleForAxis(ax, Math.random() < 0.5 ? 1 : -1);
  }

  function probe(world, x, y, axis, dir, dist) {
    const a = angleForAxis(axis, dir);
    return world.isRoad(x + Math.cos(a) * dist, y + Math.sin(a) * dist);
  }

  function pickAxis(v, world) {
    const cur = v.roadAxis != null ? v.roadAxis : axisFromAngle(v.angle);
    const dir = v.roadDir != null ? v.roadDir : 1;
    const ahead = probe(world, v.x, v.y, cur, dir, 56);
    const further = probe(world, v.x, v.y, cur, dir, 104);
    if (ahead && further) return { axis: cur, dir };
    const left = (cur + 3) % 4;
    const right = (cur + 1) % 4;
    const back = (cur + 2) % 4;
    const opts = [
      { axis: cur, dir, score: ahead ? 3 : 0 },
      { axis: left, dir, score: probe(world, v.x, v.y, left, dir, 56) ? 2 : 0 },
      { axis: right, dir, score: probe(world, v.x, v.y, right, dir, 56) ? 2 : 0 },
      { axis: cur, dir: -dir, score: probe(world, v.x, v.y, cur, -dir, 56) ? 1 : 0 },
      { axis: back, dir, score: probe(world, v.x, v.y, back, dir, 56) ? 0.5 : 0 },
    ];
    let best = opts[0];
    for (let i = 1; i < opts.length; i++) if (opts[i].score > best.score) best = opts[i];
    return { axis: best.axis, dir: best.dir };
  }

  function integrateAxis(v, dt) {
    const axis = v.roadAxis != null ? v.roadAxis : axisFromAngle(v.angle);
    const dir = v.roadDir != null ? v.roadDir : 1;
    const spd = v.speed * dir;
    if (axis === EAST) v.x += spd * dt;
    else if (axis === SOUTH) v.y += spd * dt;
    else if (axis === WEST) v.x -= spd * dt;
    else v.y -= spd * dt;
    v.angle = angleForAxis(axis, dir);
    v.vx = axis === EAST ? spd : axis === WEST ? -spd : 0;
    v.vy = axis === SOUTH ? spd : axis === NORTH ? -spd : 0;
  }

  function nearestCardinal(angle) { return angleForAxis(axisFromAngle(angle), 1); }

  function angleDiff(a, b) {
    let d = ((b - a) % U.TAU + U.TAU) % U.TAU;
    if (d > Math.PI) d -= U.TAU;
    return d;
  }

  function isRoadAhead(world, x, y, angle, dist) {
    return world.isRoad(x + Math.cos(angle) * dist, y + Math.sin(angle) * dist);
  }

  function pickHeading(v, world) {
    const p = pickAxis(v, world);
    return angleForAxis(p.axis, p.dir);
  }

  VAMP.VehicleRoad = {
    EAST, SOUTH, WEST, NORTH, axisFromAngle, angleForAxis, roadAxisAt, roadAngleAt,
    pickAxis, integrateAxis, probe, nearestCardinal, angleDiff, isRoadAhead, pickHeading,
  };
})();