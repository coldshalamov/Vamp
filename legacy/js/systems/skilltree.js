/* =========================================================================
 * VAMPIRE CITY — systems/skilltree.js
 * Branching passive + power tree. One currency: Skill Points. Nodes gate on
 * points-in-branch thresholds. Power nodes teach Disciplines; passive nodes
 * fold into derived stats via aggregateMods().
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  const S = VAMP.Stats;

  // points needed in a branch to unlock a node of the given tier
  const TIER_REQ = [0, 1, 3, 6, 10, 15];

  function nodeById(id) { return VAMP.Data.TREE_INDEX[id]; }

  function branchPoints(p, branch) {
    let t = 0;
    for (const id in p.treeNodes) {
      const n = nodeById(id);
      if (n && n.branch === branch) t += p.treeNodes[id];
    }
    return t;
  }

  function rank(p, id) { return p.treeNodes[id] || 0; }
  function maxRank(n) { return n.maxRank || 1; }

  function canAllocate(p, id) {
    const n = nodeById(id);
    if (!n) return { ok: false, why: 'no node' };
    if ((p.skillPoints || 0) <= 0) return { ok: false, why: 'no skill points' };
    if (rank(p, id) >= maxRank(n)) return { ok: false, why: 'maxed' };
    // tier threshold
    const need = TIER_REQ[n.tier] || 0;
    if (branchPoints(p, n.branch) < need) return { ok: false, why: `needs ${need} pts in ${n.branch}` };
    // explicit prereqs
    if (n.needs) for (const pre of n.needs) if (!rank(p, pre)) return { ok: false, why: 'locked' };
    // keystone conflicts — build identity gating (mutual exclusion)
    if (n.conflicts) {
      for (const cid of n.conflicts) {
        if (rank(p, cid)) {
          const cn = nodeById(cid);
          return { ok: false, why: 'Conflicts: ' + (cn ? cn.name : cid) };
        }
      }
    }
    return { ok: true };
  }

  function allocate(p, id) {
    const c = canAllocate(p, id);
    if (!c.ok) { if (VAMP.UI && c.why) VAMP.UI.notify(c.why, '#a66'); return false; }
    const n = nodeById(id);
    const wasZero = !p.treeNodes[id];
    p.treeNodes[id] = (p.treeNodes[id] || 0) + 1;
    p.skillPoints--;
    if (n.type === 'power' && wasZero && n.power) VAMP.Disc.learn(p, n.power);
    S.recompute(p);
    if (VAMP.Audio) VAMP.Audio.play('skill');
    VAMP.bus && VAMP.bus.emit('tree', id);
    return true;
  }

  // sum passive mods from allocated nodes
  function aggregateMods(p) {
    const out = S.blankMods();
    for (const id in p.treeNodes) {
      const n = nodeById(id);
      if (!n || !n.mods) continue;
      const r = p.treeNodes[id];
      if (n.mods.add) for (const k in n.mods.add) out.add[k] = (out.add[k] || 0) + n.mods.add[k] * r;
      if (n.mods.pct) for (const k in n.mods.pct) out.pct[k] = (out.pct[k] || 0) + n.mods.pct[k] * r;
    }
    return out;
  }

  // full respec (used by haven service) — refund all points
  function respec(p) {
    // Blood Rage (pot_key) frenzy must end before wiping the keystone — without the node,
    // the B-key toggle gate never fires and the player would have no way to end it manually.
    if (p.bloodState && p.bloodState.frenzied && VAMP.Blood) VAMP.Blood.endFrenzy(p);
    let refund = 0;
    for (const id in p.treeNodes) refund += p.treeNodes[id];
    p.treeNodes = {};
    p.skillPoints += refund;
    // relearn nothing; clear powers gained from tree, keep innate
    p.powers = {};
    p.slots = p.slots.map(() => null);
    p.toggles = {};
    S.recompute(p);
    return refund;
  }

  VAMP.SkillTree = { canAllocate, allocate, aggregateMods, branchPoints, rank, respec, TIER_REQ, nodeById };
})();
