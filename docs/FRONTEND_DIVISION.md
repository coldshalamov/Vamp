# Frontend Work Division — Vision vs Non-Vision Agents

## Roles

- **Vision-capable agent (you):** owns the *visual* layer — style, composition, animation, asset consistency, and screenshot-based QA.
- **Non-vision frontend agent:** owns the *functional* UI layer — scene hierarchy, data binding, menu navigation, input handling, accessibility metadata, and settings persistence.

## Workflow

1. **Parallel start:** Vision agent creates the visual design system and mockups. Non-vision agent builds the UI scene architecture and data-binding patterns.
2. **Converge:** Non-vision agent implements all screens using the design system. Vision agent reviews via screenshots/Playwright and files concrete iteration requests.
3. **Polish:** Vision agent runs final visual QA, tunes animation timing, and validates accessibility visuals.

---

## Path A — Vision-Capable Agent (you)

### Phase 1: Design system (parallel)
- Create `docs/UI_STYLE_GUIDE.md` with:
  - Gothic color palette (deep blues/purples, blood reds, candle golds, moonlight whites)
  - Type scale and font choices
  - Spacing/sizing tokens
  - Panel, button, and icon styles
  - Diegetic UI direction (blood gauge, heat stars, etc.)
- Produce mockups/screenshots for:
  - HUD layout (vitae, HP, hunger pips, heat stars, hotbar, minimap)
  - Title screen
  - Pause menu
  - Settings / accessibility screen
  - Skill tree screen
  - Inventory / equipment screen
- Define animation/easing tokens for transitions, damage numbers, hit-flash, and HUD updates.

### Phase 2: Asset & visual consistency
- Audit existing `assets/images/` and `art/` folders; flag non-transparent or off-style assets.
- Define sprite atlas conventions for UI icons and character frames.
- Create/procure placeholder UI assets that match the style guide until final art arrives.
- Specify Light2D/atmosphere requirements for UI screens (title background, menu ambiance).

### Phase 3: Screenshot-based QA & iteration
- LOCAL WINDOWS SAFETY: do not run raw Godot/windowed capture on this machine without explicit
  user approval. Prefer CI or a bounded safe harness; stop immediately on memory growth.
- Review actual screenshots only after the run path is explicitly approved and bounded.
- Check visual hierarchy, readability in dark scenes, contrast, and focus states.
- Iterate on layout mockups based on real captured frames.
- Validate reduced-motion mode and colorblind-safe palettes visually.
- Tune camera shake, hitstop, damage-number tweening, and screen flash by observing recorded gameplay.

### Phase 4: Final visual polish
- Tween timings, easing curves, and transition durations.
- Particle/VFX placement relative to HUD elements.
- Ensure diegetic UI reads correctly at 1280x720 and scaled resolutions.
- Final accessibility visual pass (contrast ratios, focus rings, caption readability).

---

## Path B — Non-Vision Frontend Agent

### Phase 1: UI architecture (parallel)
- Create reusable UI scene templates in `scenes/ui/`:
  - `HUD.tscn` / `HUD.gd`
  - `MainMenu.tscn` / `MainMenu.gd`
  - `PauseMenu.tscn`
  - `SettingsMenu.tscn`
  - `SkillTreeScreen.tscn`
  - `InventoryScreen.tscn`
  - `CoterieScreen.tscn`
  - `ShopScreen.tscn`
  - `LoadingScreen.tscn`
- Build a `UIManager.gd` autoload or CanvasLayer controller that owns screen stack, focus management, and pause-state.
- Implement CueBus → UI subscription pattern so backend events update HUD without direct Sim access.

### Phase 2: HUD & real-time UI
- Bind HUD elements to Sim/CueBus events:
  - Vitae bar
  - HP bar
  - Hunger pips
  - Heat stars
  - Hotbar slots with cooldown overlays
  - Active buff/debuff list
  - Damage numbers (floating text)
  - Notification/banner queue
  - Caption overlay for audio cues
- Implement combo feedback and action-phase indicators.
- Implement minimap/radar using world data.

### Phase 3: Menus & navigation
- Main menu: New Game, Continue, Settings, Quit.
- Pause menu: Resume, Settings, Save, Quit to Menu.
- Settings menu with tabs: Video, Audio, Gameplay, Accessibility, Controls.
- Full input remapping UI with conflict detection and persistence via `Rebind.gd` / `InputMap.gd`.
- Skill tree: node layout, connections, tooltip data, purchase flow.
- Inventory: grid, drag-and-drop or equip buttons, item tooltips.
- Coterie: roster list, summon/assign/job buttons, Embrace flow.
- Shop / haven services: buy/sell, service buttons, cost display.

### Phase 4: Accessibility & localization
- Add focus neighbors and keyboard navigation to every control.
- Add screen-reader/ARIA-style labels and descriptions.
- Implement text scaling (75%–150%) without layout breakage.
- Implement reduced-motion and reduced-flash toggles that all CueBus consumers respect.
- Implement colorblind mode retinting.
- Add caption system with priority and directionality.
- Structure all player-facing strings for localization (`tr()` keys).

---

## Integration Contract

1. **Vision agent provides:** `UI_STYLE_GUIDE.md`, mockup images, animation timing specs, and visual asset requests.
2. **Non-vision agent provides:** working UI scenes with placeholder theming, clean data binding, and keyboard/controller navigation.
3. **Handoff point:** Non-vision agent's screens must be visually restylable by swapping theme constants/fonts/textures — no hard-coded positions or colors.
4. **QA loop:** Vision agent captures screenshots → writes concrete change requests ("move heat stars 12px left", "use ease-out for damage numbers") → non-vision agent applies.

---

## Stop Condition

Both agents are done when:
- A player can boot the game and see a styled title screen.
- In-game HUD shows vitae, HP, hunger, heat, hotbar, and captions without console errors.
- Pause/settings menus are navigable by keyboard, mouse, and gamepad.
- Input remapping persists across sessions.
- Accessibility toggles work and are visually verified.
- Vision agent signs off on screenshots of all major screens.
