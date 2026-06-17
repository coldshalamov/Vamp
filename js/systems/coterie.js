/* =========================================================================
 * VAMPIRE CITY — systems/coterie.js  (#7 Coterie Roster + #13 Job Board)
 * Bound thralls become a PERSISTENT, named, leveling roster stored as plain
 * data. Summon them to fight, or assign idle members to standing jobs that
 * pay out at dawn. Cap gated by Haven barracks + Legend title.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});
  let CID = 1;

  const JOBS = {
    none: { name: 'Idle (follows/fights)', cash: 0, vitae: 0 },
    herd: { name: 'Herd — gather vitae', cash: 0, vitae: 10 },
    fence: { name: 'Fence — launder cash', cash: 30, vitae: 0 },
    spy: { name: 'Spy — scout bounties', cash: 12, vitae: 0 },
    guard: { name: 'Guard — protect tithe', cash: 8, vitae: 4 },
  };

  function ensure(p) {
    if (!p.coterie) p.coterie = [];
    if (p.coterie.length) CID = Math.max(CID, 1 + p.coterie.reduce((mx, m) => Math.max(mx, m.id || 0), 0)); // reseed after load so new ids never collide
    return p.coterie;
  }
  function cap(game) {
    const base = VAMP.Haven ? VAMP.Haven.thrallCap(game.player) : 3;
    return base + (VAMP.Legend ? VAMP.Legend.coterieBonus(game.player) : 0);
  }
  function aliveMembers(game) { return game.npcs.filter((n) => n.ally && !n.dead && n.coterieId); }
  function activeCount(p) { return p.coterie.filter((m) => m.assignment === 'none' || !m.assignment).length; }

  // bind a victim NPC into the roster (called from convertThrall)
  function attach(game, npc) {
    const p = game.player; ensure(p);
    if (p.coterie.length >= 12) {
      // evict the lowest-value NON-childe (never silently drop a sired childe)
      const evictable = p.coterie.filter((m) => !m.isChilde).sort((a, b) => (a.level + a.loyalty * 0.01) - (b.level + b.loyalty * 0.01));
      if (!evictable.length) { if (VAMP.UI) VAMP.UI.notify('Coterie is full of childer — dismiss one first.', '#a66'); return null; }
      const lost = evictable[0];
      p.coterie.splice(p.coterie.indexOf(lost), 1);
      for (const n of game.npcs) if (n.coterieId === lost.id) { n.coterieId = null; n.ally = false; n.dead = true; }
      if (VAMP.UI) VAMP.UI.notify(lost.name + ' was released from your coterie.', '#a88');
    }
    const F = VAMP.Data.FIRST, L = VAMP.Data.LAST;
    const member = {
      id: CID++, name: F[(Math.random() * F.length) | 0] + ' ' + L[(Math.random() * L.length) | 0],
      archetype: npc.victimType || 'thrall', level: 1, xp: 0, loyalty: 50, assignment: 'none', isChilde: false,
    };
    p.coterie.push(member);
    npc.coterieId = member.id; npc.name = member.name;
    if (VAMP.UI) VAMP.UI.notify('Bound ' + member.name + ' to your coterie', '#5aff8c');
    return member;
  }

  function memberById(p, id) { return p.coterie.find((m) => m.id === id); }

  // a coterie member's ally NPC scored a kill nearby -> grant member XP
  function onAllyKill(game, npc) {
    const m = memberById(game.player, npc.coterieId); if (!m) return;
    m.xp += 8;
    const need = m.level * 40;
    if (m.xp >= need) { m.xp -= need; m.level++; m.loyalty = Math.min(100, m.loyalty + 5); if (VAMP.UI) VAMP.UI.notify(m.name + ' reached level ' + m.level, '#9affd0'); }
  }

  // summon an idle member as a live ally at the player
  function summon(game, member) {
    if (member.assignment && member.assignment !== 'none') { if (VAMP.UI) VAMP.UI.notify(member.name + ' is away on a job', '#a88'); return false; }
    if (game.npcs.some((n) => n.coterieId === member.id && !n.dead)) { if (VAMP.UI) VAMP.UI.notify(member.name + ' is already at your side', '#a88'); return false; }
    if (aliveMembers(game).length >= cap(game)) { if (VAMP.UI) VAMP.UI.notify('Too many followers at once (barracks/Legend limit)', '#a66'); return false; }
    const p = game.player;
    const n = VAMP.Npc.create(game.world, 'thrall', p.x + 20, p.y, { hp: 70 + member.level * 18, name: member.name });
    n.ally = true; n.faction = 'player'; n.state = 'follow'; n.coterieId = member.id; n.thrallBornT = game.time;
    n.maxHp = 70 + member.level * 18; n.hp = n.maxHp; n.dmgMul = 1 + member.level * 0.08;
    if (member.isChilde) { n.maxHp *= 1.6; n.hp = n.maxHp; n.dmgMul += 0.4; n.weapon = 'rifle'; }
    game.addNPC(n);
    return true;
  }

  // #19 Childer: Embrace a high-quality victim into a permanent, powerful childe
  function canEmbrace(game, npc) {
    const p = game.player;
    const legendOk = !VAMP.Legend || VAMP.Legend.get(p) >= 260; // Baron+
    const quality = npc && (npc.victimType === 'noble' || npc.victimType === 'athlete' || npc.victimType === 'hunter' || npc.victimType === 'cop');
    return legendOk && quality && p.blood >= 60;
  }
  function embrace(game, npc) {
    const p = game.player;
    if (!canEmbrace(game, npc)) {
      if (VAMP.Legend && VAMP.Legend.get(p) < 260) VAMP.UI.notify('You must be a Baron to sire childer.', '#a66');
      else if (p.blood < 60) VAMP.UI.notify('Not enough vitae to Embrace (need 60).', '#a66');
      else VAMP.UI.notify('This mortal is not worthy of the Embrace.', '#a66');
      return false;
    }
    ensure(p);
    p.blood -= 60;
    const F = VAMP.Data.FIRST, L = VAMP.Data.LAST;
    const m = { id: CID++, name: F[(Math.random() * F.length) | 0] + ' ' + L[(Math.random() * L.length) | 0], archetype: 'childe', level: 3, xp: 0, loyalty: 80, assignment: 'none', isChilde: true };
    p.coterie.push(m);
    npc.dead = true;
    p.childeCount = (p.childeCount || 0) + 1;
    if (game.masquerade) game.masquerade.add(1);
    VAMP.UI.banner('THE EMBRACE', 'You have sired ' + m.name + ' — your childe. Summon them from your Coterie.', '#c79bff');
    if (VAMP.Audio) VAMP.Audio.play('win');
    if (VAMP.Legend) VAMP.Legend.add(game, 15);
    if (VAMP.Progress) VAMP.Progress.reveal(game, 'childer');
    return true;
  }

  function assign(game, member, job) {
    member.assignment = job;
    // recall the live ally if sent to work
    if (job !== 'none') for (const n of game.npcs) if (n.coterieId === member.id) n.dead = true;
    if (VAMP.UI) VAMP.UI.notify(member.name + ': ' + (JOBS[job] ? JOBS[job].name : job), '#cdd');
  }

  // dawn payout from assigned jobs
  function collectJobs(game) {
    const p = game.player; let cash = 0, vitae = 0; let spyHit = false;
    if (!p.coterie) return { cash, vitae };
    for (const m of p.coterie) {
      const j = JOBS[m.assignment]; if (!j) continue;
      const mult = 1 + m.level * 0.15 + m.loyalty * 0.004;
      cash += Math.round(j.cash * mult); vitae += Math.round(j.vitae * mult);
      if (m.assignment === 'spy') spyHit = true;
    }
    if (spyHit && VAMP.Quests && VAMP.Quests.create) { /* spy intel handled by quests director bias (light) */ }
    return { cash, vitae };
  }

  // nightly wages: bound thralls and childer need vitae to sustain their bond
  function wagesUpkeep(game) {
    const p = game.player; let vitae = 0;
    if (!p.coterie) return { vitae: 0, cash: 0 };
    for (const m of p.coterie) {
      vitae += m.isChilde ? 14 : 6;   // childer cost more — they are true vampires
    }
    return { vitae, cash: 0 };
  }

  VAMP.Coterie = { JOBS, ensure, cap, attach, memberById, onAllyKill, summon, assign, collectJobs, wagesUpkeep, aliveMembers, canEmbrace, embrace };
})();
