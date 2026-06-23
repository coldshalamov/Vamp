# STEAM_VALUE_AUDIT.md — the game as a store product

> Assesses Vampire City as a sellable Steam product, not just a codebase. The question this answers:
> *what would make someone watch the trailer, wishlist, and pay $X?*

## 1. The hook (what makes it different)

**"A top-down vampire predator-sim where the city remembers what you did."** You are a supernatural
predator who must *feed to survive*, but every feed risks the Masquerade: witnesses report you, hunters
search your **last-known position** (not your live position), and the ones you fail to kill **come back
scarred and remember how you hurt them.** Dawn is a hard deadline. Humanity is a slope, not a number —
drop it and the city visibly fears you.

This is **not** a Vampire Survivors clone (no auto-attack bullet-heaven) and **not** a walking-sim RPG.
It's **Hades-tight action + GTA's wanted-system chases + Bloodlines' clan identity**, expressed
top-down. The differentiators that are *already in code* and most other vampire games lack:
- **Last-known-position heat** (the "duck down an alley, lose them" loop) — tested, working.
- **The nemesis loop** (Shadow-of-Mordor-flavored personal hunters) — tested, working.
- **Feeding as a skill+choice verb** (gulp timing + resonance + kill/spare) — partially built.
- **Clan-as-identity rule changes** — backend done, needs runtime wiring.

## 2. What the screenshots would show (the capsule promise)

The Dirty Top-Down Urban Horror look (user-chosen): a rain-slick concrete street under sodium-orange
streetlamps, headlight and **police-light cones** raking the asphalt, neon signage reflected in wet
ground, the vampire mid-feed over a victim with a **blood trail** behind, blood-red HUD accents, heat
stars glowing. **None of this is screenshot-ready today** — the current build is colored circles on
black (see `docs/evidence/`). The capsule promise is gated entirely on the M5 art+light pass.

## 3. The 10-second trailer beat

1. (0–2s) Dark street, heartbeat audio rising. A civilian walks alone.
2. (2–4s) Blur-dash; grab; the **gulp pulse**; a slow-mo gold flash on a perfect feed.
3. (4–6s) A witness screams; **heat stars ignite**; flashlight cones converge.
4. (6–8s) A clan-power burst (Brujah frenzy / Tremere blood-bolt); a hunter wounded, **fleeing**.
5. (8–10s) Sky lerps to killing gold; the vampire sprints for a haven door as sun-light bites; cut to
   title. Tagline: *"Rise before dawn. Or burn."*

Every one of those beats is backed by an existing system; the trailer is a *production* problem, not a
*design* problem.

## 4. Tags & positioning

`Action Roguelike`-adjacent but **run-structured night**, not roguelike-required. Suggested Steam tags:
**Vampire, Top-Down, Action RPG, Stealth, Gothic, Singleplayer, Difficult, Character Action Game,
Immersive Sim, Choices Matter, Atmospheric, Dark.** Comps for the store page: *VtM: Bloodlines*,
*Hades*, *Hotline Miami*, *Katana ZERO*, *Shadows of Doubt* (for the perception/witness sim).

## 5. The value argument

| Price | What it must contain |
|---|---|
| **$0 demo** | The First Hunt slice, polished: one night, 3 clans, the full feed→hunt→escape→dawn→nemesis loop, real art/audio. This is the wishlist driver. |
| **$15** | The slice's loop × 4–6 districts, 7 clans, full power roster, the living-city events, the lair, ~3–4 hrs of authored progression to "Lord of the Night." |
| **$20** | Above + the loot/affix build endgame (Diablo-style), nemesis depth, the 5 authored missions, radio, difficulty modes, ~8–12 hrs. |
| **$25–30** | Above + NG+/New Bloodline, endgame siege, achievements/cloud, Steam Deck verified, a content cadence that signals "alive." |

The **realistic launch target is $15–20** given a solo/small-team scope; the backend breadth already
ported (domains, coterie, businesses, loot, nemesis, events) is what justifies the upper end *if and
only if* each is surfaced with the same care the slice gets.

## 6. What must exist before ANY public demo (gating checklist)

1. The First Hunt slice meets its DoD (`FIRST_HUNT_SLICE_PLAN.md §4`).
2. Authored art for every on-screen actor (zero primitives).
3. Audio on every meaningful action; not silent.
4. Zero console errors over 5 runs; save/load works; controller works.
5. A 30-second clip where the hook is legible without narration.
6. Settings/accessibility baseline (remap, reduced-motion, captions, text scale — architecture exists).

Until #1–4 hold, a public demo would **undersell** the strong systemic foundation — it would read as
"unfinished prototype," not "deep vampire predator-sim." The systems are a genuine moat; the
presentation is currently hiding it.

## 7. Honest competitive risk

The market has many vampire and many top-down action games. The win condition is **felt identity**:
the chase/witness/nemesis loop and clan-distinct play have to be *immediately legible and satisfying*
in the first 10 minutes. The backend can support that today; the art/audio/juice/authoring pass is what
converts "interesting systems" into "I need to play this." That conversion is the entire remaining job.
