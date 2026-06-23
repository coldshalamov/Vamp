# Vampire City — UI Style Guide

> For the frontend agent building UI scenes and the vision agent auditing them.
> This is a living document; update it when final art replaces placeholders.

## 1. Design principles

- **Diegetic where possible.** The HUD should feel like it belongs to the vampire, not a spreadsheet.
  - Vitae bar = a physical blood gauge.
  - Heat = Masquerade stars that burn brighter as threat rises.
  - Hunger = sharpened fangs / red-tinged pips.
- **Readability in darkness.** All UI must be legible against the dark city backdrop.
- **Minimal chrome.** Avoid heavy borders and panels; use negative space and subtle gradients.
- **Motion with purpose.** Every tween communicates state change. Avoid ambient drift.

## 2. Color palette

All UI colors and spacing are defined in `src/ui/UITheme.gd`. Do not hard-code colors in scenes.

### Core palette
| Token | Hex | Usage |
|---|---|---|
| `bg_void` | `#08080c` | Screen backgrounds, deepest shadows |
| `bg_panel` | `#12121a` | Menu panels, HUD backing |
| `bg_panel_hover` | `#1a1a26` | Hovered panels |
| `bg_panel_pressed` | `#0d0d14` | Pressed panels |
| `border_subtle` | `#2a2a3a` | Dividers, inactive borders |
| `border_bright` | `#4a4a62` | Focus rings, active borders |

### Accent palette
| Token | Hex | Usage |
|---|---|---|
| `blood_primary` | `#c01028` | Vitae bar, damage, frenzy |
| `blood_bright` | `#ff2a4a` | Critical vitae, perfect feed |
| `blood_dark` | `#5a0010` | Low vitae warning background |
| `hp_primary` | `#7c9c7c` | HP bar |
| `hp_low` | `#d07030` | Low HP |
| `hunger` | `#e07020` | Hunger pips |
| `humanity` | `#9c8cc8` | Humanity number, virtuous choices |
| `heat_1` | `#f0d060` | 1–2 heat stars |
| `heat_2` | `#f08030` | 3–4 heat stars |
| `heat_3` | `#ff2030` | 5–6 heat stars, Inquisition |
| `discipline` | `#c79bff` | Power costs, discipline aura |
| `caution` | `#f0c040` | Warnings, prompts |
| `text_primary` | `#e8e8f0` | Body text |
| `text_secondary` | `#a0a0b0` | Subtitles, cooldowns |
| `text_disabled` | `#606070` | Disabled controls |

### Discipline colors (for power icons/hotbar)
| Discipline | Hex |
|---|---|
| `celerity` | `#7ad0ff` |
| `potence` | `#e0b050` |
| `fortitude` | `#9aa0a8` |
| `obfuscate` | `#8a8fb0` |
| `auspex` | `#aef0ff` |
| `dominate` | `#b98cff` |
| `presence` | `#ff9ecf` |
| `protean` | `#c1722a` |
| `blood_sorcery` | `#e0203f` |
| `dark_arts` | `#8a4bd0` |

## 3. Typography

Use a single font family for consistency. Current placeholder: `art/ui/fonts/AnonymousPro-Bold.ttf` (monospace) for HUD numbers; swap to a gothic serif for titles later.

| Token | Size | Weight | Usage |
|---|---|---|---|
| `font_h1` | 48px | Bold | Title screen, banners |
| `font_h2` | 32px | Bold | Menu headers |
| `font_h3` | 22px | Bold | Section headers |
| `font_body` | 16px | Regular | Body text, tooltips |
| `font_small` | 12px | Regular | Cooldowns, subtitles |
| `font_hud_value` | 18px | Bold | HP/blood numbers |

Text scaling (75%–150%) multiplies all sizes. Layouts must survive 150% without clipping.

## 4. Spacing & sizing

Base grid: **8px**.

| Token | Value |
|---|---|
| `space_xs` | 4px |
| `space_sm` | 8px |
| `space_md` | 16px |
| `space_lg` | 24px |
| `space_xl` | 32px |

### HUD layout (1280x720 reference)
- Vitae + HP bars: bottom-left, 16px from edges, 220px wide × 18px tall.
- Hunger pips: above vitae bar, 8px gap.
- Heat stars: bottom-right, 16px from edges, 32px per star.
- Hotbar: centered bottom, 48px × 48px slots with 4px gap.
- Notifications: bottom-center above hotbar, max width 480px.
- Banners: center screen.
- Captions: bottom-center, max width 640px, 48px from bottom.
- Damage numbers: spawn at entity screen position, float up 48px over 0.7s.

## 5. Components

### Panel
- Background: `bg_panel` at 90% opacity.
- Border: 1px `border_subtle`.
- Corner radius: 4px.
- Shadow: subtle drop shadow 0px 4px 12px `#000000` at 60%.

### Button
- Normal: `bg_panel`, 1px `border_subtle`, 6px padding, 4px radius.
- Hover: `bg_panel_hover`, `border_bright`.
- Pressed: `bg_panel_pressed`.
- Disabled: `bg_panel`, `text_disabled`.
- Focus: 2px `border_bright` outline.

### Bar (Vitae / HP)
- Track: `bg_void` with 1px `border_subtle`.
- Fill gradient: left-to-right, primary color → slightly brighter primary.
- Low-value flash: when value < 25%, pulse opacity 0.7 → 1.0 every 0.6s.
- Animated fill: tween width over 0.15s on change (skip if reduced motion).

### Hunger pip
- Empty: dark outline shape.
- Filled: `hunger` color, sharp/tooth shape.

### Heat star
- Empty: dim 5-point star outline.
- Filled: glowing star with bloom; color by heat level (`heat_1` → `heat_3`).
- On gain: star scales up 1.3 → 1.0 with a flash.

### Hotbar slot
- Slot size: 48px.
- Background: `bg_panel`.
- Icon: 32px centered.
- Cooldown overlay: radial wipe in `bg_void` at 70% opacity.
- Cost text: bottom-right, `discipline` color, `font_small`.
- Keybind label: top-left, `text_secondary`, `font_small`.

### Notification
- Slide in from bottom, 0.3s ease-out.
- Background: `bg_panel`.
- Text: `font_body`, color by severity (info = `text_primary`, warning = `caution`, danger = `blood_primary`).
- Auto-dismiss after 4s unless hovered.

### Banner
- Full-screen dim overlay at 60% black.
- Title: `font_h1`, `blood_primary` or `discipline`.
- Body: `font_h2`, `text_primary`.
- Dismiss with any action after 1.5s.

### Caption
- Background: `bg_void` at 80% opacity.
- Text: `font_body`, `text_primary`.
- Directional prefix when audio is off-screen: "[left] ", "[right] ", "[behind] ".
- Max 2 lines, fade out after 3s.

## 6. Animation & easing

| Token | Duration | Easing | Usage |
|---|---|---|---|
| `ease_quick` | 0.12s | `ease-out` | Button states, small feedback |
| `ease_standard` | 0.25s | `ease-out` | Menu open/close, panel fades |
| `ease_dramatic` | 0.45s | `ease-in-out` | Banners, star gain, humanity loss |
| `ease_bounce` | 0.55s | `ease-out-back` | Damage numbers, loot pop |

### Camera
- Follow smoothing: `lerp` factor 0.12 per frame.
- Trauma decay: 0.9 per second.
- Shake max offset: 12px at trauma 1.0.
- Push-in on heavy hit: scale 1.0 → 1.04 over 0.08s, return 0.15s.

### Hitstop / time scaling
- Default hitstop: 2 ticks (~33ms) at 60 FPS.
- Heavy hit / finisher: 5 ticks.
- Frenzy pulse: slow time to 0.6x for 0.3s.
- Reduced-motion mode: convert hitstop to a single-frame flash, no time scale.

## 7. Diegetic UI rules

- **Vitae bar** should look like a glass tube of blood; bubbles or shimmer when full.
- **Heat stars** are Masquerade seals that crack/burn at high heat.
- **Hunger** is shown as fangs; more filled = more ravenous.
- **Buff/debuff icons** use discipline colors and sharp geometric shapes.
- **Damage numbers** use color for type: white (phys), red (blood), blue (shadow), gold (sun), green (poison).

## 8. Accessibility

- **Text scale:** 75%–150%; all layouts must reflow.
- **High-contrast text:** increase text-to-bg contrast to 7:1 minimum.
- **Reduced motion:** disable all non-essential tweens; no screen shake; hitstop becomes flash.
- **Reduced flash:** no full-screen white flashes; use brief dark-red tints instead.
- **Colorblind mode:** never use color alone for status. Add icons/shape/text.
- **Captions:** on by default; include directional audio cues.
- **Focus indicators:** 2px solid `border_bright` outline on focused control.

## 9. Placeholder assets

Until final art arrives, generate these in `art/ui/`:
- `panel_bg.png` — 32x32 panel tile, rounded 4px.
- `bar_vitae.png`, `bar_hp.png`, `bar_track.png` — 64x8 bar fills, stretched as needed.
- `star_empty.png`, `star_filled.png` — 16x16.
- `hungertooth_empty.png`, `hungertooth_filled.png` — 16x16.
- `slot_bg.png`, `slot_cooldown.png` — 32x32 (displayed in 48x48 slots).
- `icon_placeholder.png` — 32x32 power icon placeholder.

Final art will replace these without scene changes.

## 10. Integration notes

- All UI scenes must use `UITheme` (`src/ui/UITheme.gd`) as their theme source.
- All colors must reference `UITheme` constants; no hard-coded hexes.
- All durations must reference the animation tokens; no magic numbers.
- Frontend agent building menus: use `BaseScreen.gd` pattern, respect focus order.
- Vision agent: verify every screen at 100% and 150% text scale via screenshots.
