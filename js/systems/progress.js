/* =========================================================================
 * VAMPIRE CITY — systems/progress.js  (VAMP.Progress)
 * The progression-reveal backbone. Every meta-system already exists from
 * minute one; this module owns WHAT is surfaced, WHEN, and HOW the player
 * learns it — so the game stays simple early and complexifies intuitively,
 * each higher layer revealed by having just used the one beneath it.
 *
 * It does not delete or pause any system — it only gates their *surface*
 * (HUD prompts, menu tabs, blips, banners). Deep sim keeps running.
 * Load order: after legend.js, before domains.js.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  // helpers for triggers (all read real, already-serialized fields)
  function powerCount(p) { return p.powers ? Object.keys(p.powers).length : 0; }
  function anyMasteryRank(p) {
    if (!p.mastery) return false;
    for (const k in p.mastery) if (p.mastery[k] && (p.mastery[k].rank || 0) >= 1) return true;
    return false;
  }
  function anyRepCrossed(p) {
    if (!p.reputation) return false;
    for (const k in p.reputation) if (Math.abs(p.reputation[k] || 0) >= 1) return true;
    return false;
  }
  function ownedDomains(game) { return (VAMP.Domains && VAMP.Domains.ownedCount) ? VAMP.Domains.ownedCount(game) : 0; }
  function havenRooms(p) { return (p.haven && p.haven.rooms) ? p.haven.rooms : null; }
  function builtAnyRoom(p) { const r = havenRooms(p); if (!r) return false; for (const k in r) if ((r[k] || 0) > 0) return true; return false; }

  // ---- the ORDERED unlock table (order = nextObjective priority) ----
  // Each: key, trigger(game)->bool, bf(p)->bool (pure backfill), objective(game)->str|null,
  //       reveal(game) (the diegetic moment), tab?, hud?, prereq?, silent?
  const UNLOCKS = [
    { key: 'move', trigger: () => true, bf: () => true, hud: 'move' },
    { key: 'feed', prereq: 'move',
      trigger: (g) => (g.player.stats.distance || 0) > 180,
      bf: (p) => (p.bloodState && p.bloodState.fedCount > 0) || (p.stats && p.stats.distance > 180), hud: 'feed' },
    { key: 'powers', prereq: 'feed',
      trigger: (g) => g.player.skillPoints > 0 && powerCount(g.player) >= 1,
      bf: (p) => powerCount(p) >= 1, tab: 'skills' },
    { key: 'attributes', prereq: 'feed',
      trigger: (g) => g.player.attrPoints > 0, bf: (p) => p.attrPoints > 0 || p.level >= 2 },
    { key: 'pounce', prereq: 'feed', trigger: (g) => g.player.level >= 2, bf: (p) => p.level >= 2,
      reveal: (g) => { g.player.pounceUnlocked = true; if (VAMP.UI) VAMP.UI.notify('SHADOW-POUNCE — tap SPACE to leap onto distant prey (costs vitae, like sprint).', '#b07bff'); } },
    { key: 'finisher', prereq: 'feed', trigger: (g) => g.player.level >= 3, bf: (p) => p.level >= 3,
      reveal: (g) => { g.player.finisherUnlocked = true; if (VAMP.UI) VAMP.UI.notify('EXECUTE — press F on a helpless or near-dead foe for a brutal killing blow.', '#ff5a5a'); } },
    { key: 'missions', prereq: 'feed',
      trigger: (g) => (g.player.bloodState.fedCount >= 2) || g.player.level >= 2,
      bf: (p) => (p.bloodState && p.bloodState.fedCount >= 2) || p.level >= 2,
      objective: () => 'A contract waits on a Board (#) — accept it for XP and coin.',
      reveal: (g) => {
        VAMP.UI.banner('CONTRACTS', 'The Anarchs leave work on boards (#). One waits nearby.', '#c79bff');
        const board = g.findPOI && g.findPOI('board');
        if (board) g.addBlip({ x: board.x, y: board.y, color: '#c79bff', kind: 'guide', ttl: g.time + 240 });
      } },
    { key: 'vehicles', prereq: 'feed',
      trigger: (g) => (g.player.stats.distance || 0) > 900, bf: (p) => (p.stats && p.stats.distance > 900) || p.level >= 3,
      objective: () => 'Press E by a car to drive — fast travel, and shelter at dawn.',
      reveal: (g) => g.showTip && g.showTip('E by a parked car to drive — speed across the city, and a moving shelter when dawn comes.') },
    { key: 'havenUpgrade', prereq: 'feed', trigger: () => false, bf: (p) => builtAnyRoom(p) || p.level >= 5,
      objective: (g) => builtAnyRoom(g.player) ? null : 'Spend coin at your Haven — build a room to grow permanently.',
      reveal: (g) => { VAMP.UI.banner('YOUR HAVEN', 'Rest, bank the night, and build it room by room.', '#9affd0'); }, hud: 'haven' },
    { key: 'mastery', prereq: 'feed',
      trigger: (g) => g.player.level >= 3 && anyMasteryRank(g.player), bf: (p) => p.level >= 4 || (p.level >= 3 && anyMasteryRank(p)),
      reveal: (g) => g.showTip && g.showTip('MASTERY — you grow stronger just by DOING. It is permanent and survives death. See C → Mastery.'),
      tab: 'mastery' },
    { key: 'reputation', prereq: 'feed',
      trigger: (g) => g.player.level >= 4 && anyRepCrossed(g.player), bf: (p) => p.level >= 5 || (p.level >= 4 && anyRepCrossed(p)),
      reveal: (g) => { VAMP.UI.banner('THE WORD SPREADS', 'The factions of the night remember you now.', '#ff9ecf'); }, hud: 'rep' },
    { key: 'thralls', prereq: 'feed', trigger: () => false,
      bf: (p) => (p.powers && p.powers.dom_thrall) || (p.coterie && p.coterie.length > 0) || p.level >= 6,
      reveal: (g) => { VAMP.UI.banner('THE BLOOD BOND', 'Bound mortals serve. Build a Coterie of the night.', '#5aff8c'); }, tab: 'coterie' },
    { key: 'legend', prereq: 'feed', trigger: (g) => (g.player.legend || 0) >= 30, bf: (p) => (p.legend || 0) >= 30,
      tab: 'holdings', hud: 'legend', silent: true },   // banner already fires in legend.js
    { key: 'domains', prereq: 'legend', trigger: (g) => g.player.level >= 6 && (g.player.legend || 0) >= 30,
      bf: (p) => p.level >= 6 && (p.legend || 0) >= 30,
      objective: () => 'Claim a district — slay its Baron (Holdings tab) for a nightly tithe.',
      reveal: (g) => { VAMP.UI.banner('TERRITORY', 'Slay a district\'s Baron to claim it. It pays a nightly tithe.', '#d6953f'); } },
    { key: 'businesses', prereq: 'domains', trigger: (g) => ownedDomains(g) >= 1, bf: (p) => p.businesses && Object.keys(p.businesses).length > 0,
      reveal: (g) => { VAMP.UI.banner('FRONTS', 'A district you hold can hide a business that pays every dawn.', '#30c060'); } },
    { key: 'coterieJobs', prereq: 'thralls', trigger: (g) => (g.player.coterie && g.player.coterie.length >= 1) && (g.player.bloodState.dawnStreak >= 1),
      bf: (p) => p.coterie && p.coterie.length >= 1,
      reveal: (g) => g.showTip && g.showTip('Assign idle coterie to JOBS — they earn while you hunt, banked at dawn.') },
    { key: 'codex', prereq: 'feed', trigger: (g) => g.player.level >= 7, bf: (p) => p.level >= 7,
      reveal: (g) => g.showTip && g.showTip('CODEX — the night is yours to catalogue. Complete a set for a permanent bonus. See C → Codex.'),
      tab: 'codex' },
    { key: 'nemesis', prereq: 'feed', trigger: () => false, bf: (p) => p.nemeses && p.nemeses.length > 0, silent: true },
    { key: 'childer', prereq: 'thralls', trigger: (g) => (g.player.legend || 0) >= 260, bf: (p) => (p.legend || 0) >= 260 || (p.childeCount || 0) > 0, silent: true },
    { key: 'elder', prereq: 'feed', trigger: (g) => g.player.level >= (VAMP.Stats ? VAMP.Stats.MAX_LEVEL : 60) || (g.player.bloodState.elderVitae || 0) >= 1,
      bf: (p) => p.level >= 60 || (p.bloodState && p.bloodState.elderVitae > 0), tab: 'elder', silent: true },
    { key: 'prestige', prereq: 'legend', trigger: (g) => VAMP.Legacy && VAMP.Legacy.canTorpor && VAMP.Legacy.canTorpor(g.player),
      bf: (p) => VAMP.Legacy && VAMP.Legacy.canTorpor && VAMP.Legacy.canTorpor(p),
      reveal: (g) => { VAMP.UI.banner('TORPOR', 'Sleep the long sleep, and rise reborn — a stronger bloodline.', '#c79bff'); } },
    { key: 'alchemy', prereq: 'havenUpgrade', trigger: (g) => (VAMP.Haven && VAMP.Haven.hasWorkshop && VAMP.Haven.hasWorkshop(g.player)) || (g.player.reagents && Object.keys(g.player.reagents).length > 0),
      bf: (p) => (p.reagents && Object.keys(p.reagents).length > 0) || (VAMP.Haven && VAMP.Haven.hasWorkshop && VAMP.Haven.hasWorkshop(p)),
      reveal: (g) => g.showTip && g.showTip('Your Workshop lets you brew elixirs from reagents — open it from your Haven.') },
  ];
  const BY_KEY = {};
  for (const u of UNLOCKS) BY_KEY[u.key] = u;

  // tabs always reachable from minute one (the core); everything else is gated
  const TAB_GATE = { holdings: 'legend', coterie: 'thralls', mastery: 'mastery', codex: 'codex', elder: 'elder' };

  function ensure(p) {
    if (!p.progress) p.progress = { revealed: {}, seen: {}, objIdx: 0 };
    if (!p.progress.revealed) p.progress.revealed = {};
    if (!p.progress.seen) p.progress.seen = {};
    backfill(p);
    return p.progress;
  }
  // grant silently any unlock whose state is already satisfied (old/mid-game saves)
  function backfill(p) {
    for (const u of UNLOCKS) {
      if (p.progress.revealed[u.key]) continue;
      let ok = false;
      try { ok = u.bf ? u.bf(p) : false; } catch (e) {}
      if (ok) p.progress.revealed[u.key] = 1;   // silent — no reveal() side effects on load
    }
  }

  function isRevealed(p, key) { return !!(p && p.progress && p.progress.revealed && p.progress.revealed[key]); }
  function markSeen(p, key) { ensure(p); p.progress.seen[key + ':done'] = 1; }

  function reveal(game, key) {
    game = game || VAMP.Game;
    const p = game.player; if (!p) return false;
    ensure(p);
    if (p.progress.revealed[key]) return false;   // idempotent
    p.progress.revealed[key] = 1;
    const u = BY_KEY[key];
    if (u && u.reveal && !u.silent) { try { u.reveal(game); } catch (e) {} }
    return true;
  }

  function check(game) {
    const p = game.player; if (!p) return;
    ensure(p);
    for (const u of UNLOCKS) {
      if (p.progress.revealed[u.key]) continue;
      if (u.prereq && !p.progress.revealed[u.prereq]) continue;   // teach-order
      let ok = false; try { ok = u.trigger(game); } catch (e) {}
      if (ok) reveal(game, u.key);
    }
  }

  const _objOut = { key: '', text: '' };
  function nextObjective(game) {
    const p = game.player; if (!p) return null;
    ensure(p);
    for (const u of UNLOCKS) {
      if (!u.objective) continue;
      if (!p.progress.revealed[u.key]) continue;     // not unlocked -> don't tease
      if (p.progress.seen[u.key + ':done']) continue; // already acted -> retire it
      let text = ''; try { text = u.objective(game); } catch (e) { continue; }
      if (!text) continue;
      _objOut.key = u.key; _objOut.text = text; return _objOut;
    }
    return null;
  }

  function tabVisible(game, id) {
    const gate = TAB_GATE[id];
    if (!gate) return true;          // skills / inventory / map / stats — always
    return isRevealed(game.player, gate);
  }
  function hudFeature(game, key) { return isRevealed(game.player, key); }

  function serialize(p) { ensure(p); return { revealed: p.progress.revealed, seen: p.progress.seen, objIdx: p.progress.objIdx || 0 }; }
  function restore(p, data) { p.progress = data || { revealed: {}, seen: {}, objIdx: 0 }; ensure(p); }

  VAMP.Progress = { ensure, isRevealed, reveal, check, nextObjective, tabVisible, hudFeature, markSeen, serialize, restore, UNLOCKS };
})();
