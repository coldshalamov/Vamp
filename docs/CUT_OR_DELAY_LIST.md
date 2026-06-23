# CUT_OR_DELAY_LIST.md — the convergence contract

> The single most important discipline doc. The repo's risk is **not** missing systems — it's ~25
> tested backend systems competing for finite polish attention. This list says what we **refuse to
> touch** until *The First Hunt* is fun. "DELAY" = keep the code, quarantine from the slice UX.
> "CUT" = remove/abandon. "FORBID" = do not start until the gate opens.
>
> **The gate:** a blind playtester finishes The First Hunt with zero console errors and *wants to play
> it again.* Until then, no item below gets build time.

## DELAY to Phase 2 (code stays; hidden from the slice)

These are **fully or mostly ported and tested** — that's exactly why they're tempting and exactly why
they must wait. They add breadth, not slice quality.

| System | Status in code | Why delay | Action now |
|---|---|---|---|
| Domains / territory (claim/contest/tithe/raid) | ported, tested | living-city depth; invisible to a 15-min night | leave in `SimMeta`; no UI; don't trigger in slice |
| Businesses / idle income | ported, tested | economic flywheel is a Phase-2 fantasy | no UI; no dawn payout surfacing in slice |
| Coterie / Embrace / childer | ported, tested | companion depth; solo night first | no summon UI in slice |
| Haven upgrades / cellar / sanctum | ported, tested | base-building is Phase-2 | one haven exists as a *dawn-safe room*; no upgrade screen |
| Alchemy (refine/extract) | ported, tested | crafting depth | hide workshop |
| Full skill-tree (74 nodes) UI | data ported; UI intent-only | the slice uses a fixed hotbar | hide `SkillTreeScreen`; pre-bind the slice hotbar |
| Inventory / Shop / loot affixes | ported, tested; UI hardcoded | itemization endgame is Phase-3 | hide `Inventory`/`Shop`; no drops in slice |
| Reputation / legend / titles | ported, tested | faction meta is Phase-2 | track silently; don't surface |
| Mastery / codex / trophies / achievements | ported/partial | meta-progression | track silently |
| Emergent event director (gangwar/crackdown/bloodhunt/vip/bounty/domainraid) | ported, tested | radiant city is Phase-2; the slice authors its *one* hunter beat by hand | don't fire in slice except the herald |
| Vehicles (drive/AI/hijack) | ported | they render but aren't a slice verb; tuning is a rabbit hole | spawn as set-dressing only; no drive-by/hijack tutorialization |
| Mission contract-chains (anarch/camarilla/inquis) | legacy-only, not in Godot catalog | authored questlines are Phase-2 | leave unported |

## FORBID until the gate opens (do not start)

- **New backend systems of any kind.** The breadth is done. Adding more is the relapse.
- **Procedural city generation.** Hand-build one block. Procedural = generic = the flash-game look the
  spec exists to avoid.
- **Systemic surface chemistry at large** (fire spreads to blood spreads to oil…). Ship **one** high-ROI
  interaction only: a **sunlight patch** the player can lure the fleeing herald into (dust-kill payoff,
  reuses the nemesis + sun-damage code). Everything else (water-shock, electric, blood-lash chains) is
  Phase-2.
- **More than 3 playable clans in the slice.** 7 exist; the slice proves 3.
- **Dialogue trees / branching narrative tech.** The slice's story is *embodied in mechanics* + a
  handful of barks + one banner per humanity step. Authored narrative is Phase-2/3.
- **Radio, weather variety, multiple districts, NG+/bloodline prestige.** All Phase-2/3.
- **Controller-perfect remap polish / Steam Deck tuning.** Architecture exists (`Rebind`); final
  polish is Milestone-7 (Steam readiness), not the slice gate.

## CUT outright (remove or abandon)

- **`break_responder_locks`** (`Sim.gd:361`) — orphaned, never called. Remove.
- **Legacy `js/` as a *porting target*** — it's reference only; do not port further breadth from it.
  Mine it for *design DNA and tuning numbers*, not more features.
- **Procedural hero-sprite generation (`spriter.js` lineage)** — explicitly rejected as the
  "flash-game look." Do not resurrect for characters; OK only for variation assets (splatter, glows).
- **The parallel "ActionDef `.tres` for all powers vs dicts" ambiguity** — pick one. Recommendation:
  keep dicts authoritative for the 33 utility powers; author `.tres` only for the handful of slice
  powers that need authored hitboxes. Don't maintain both half-heartedly.

## Quarantine (isolate so it can't mislead)

- **Audio/caption stubs** that silently no-op — until wired, they should at least not *look* wired.
- **Surface tiles** (water/fire/electric) that render but do nothing — hide them in the slice level so
  players don't try to use them.
- **Half-wired UI screens** — gate them behind a "Phase 2" flag or remove from the slice menu so a
  playtester never opens a non-functional inventory.

---

**Rule of thumb:** if a thing is *already tested in the backend*, that is **not** a reason to surface
it in the slice — it's a reason to trust it later and ignore it now. The slice's job is to make the
*felt* 15% catch up to the *systemic* 85%, not to expose more of the 85%.
