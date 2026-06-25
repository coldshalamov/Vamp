#!/usr/bin/env python3
"""visual_asset_core — primitive SVG emitters, the character profile model, and
the asset-writing entry point shared by ``generate_visual_atlas.py``.

This module is intentionally side-effect free except for ``write_assets`` (which
touches the filesystem).  ``generate_visual_atlas.py`` imports it as ``b`` and
*injects* the heavy art logic back onto the module:

    b.PROFILES               = [...]
    b._draw_character        = draw_character
    b._draw_grounded         = draw_grounded
    b.generate_character_atlas = _generate_character_atlas_clipped

So ``write_assets`` must reference those names as bare module globals at *call*
time (late binding) — never capture them at import time.

The art is authored in a 96x128 cell, 8 directional columns, 16 semantic rows.
Each archetype atlas is therefore 768x2048.  Light is top-lit: gradients run a
lighter top stop -> base -> darker bottom stop.
"""
from __future__ import annotations

import json
import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Sequence

# ---------------------------------------------------------------------------
# Atlas contract constants.  The generator injects ATLAS_COLS / DIRECTION_ANGLES
# but reads ATLAS_ROWS / FRAME_W / FRAME_H / BASELINE_Y straight from here.
FRAME_W: float = 96.0
FRAME_H: float = 128.0
ATLAS_COLS: int = 8
ATLAS_ROWS: int = 16
BASELINE_Y: float = 112.0

# Overwritten by the generator with the authored E,SE,S,SW,W,NW,N,NE angles.
DIRECTION_ANGLES: list[float] = [i * math.pi / 4.0 for i in range(8)]


# ---------------------------------------------------------------------------
# Colour helpers.
def _clamp8(v: float) -> int:
    return max(0, min(255, int(round(v))))


def _parse_hex(hex_color: str) -> tuple[int, int, int]:
    s = hex_color.strip().lstrip("#")
    if len(s) == 3:
        s = "".join(ch * 2 for ch in s)
    if len(s) != 6:
        raise ValueError(f"not a 6-digit hex colour: {hex_color!r}")
    return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)


def shade(hex_color: str, amount: float) -> str:
    """Lighten (amount > 0) or darken (amount < 0) a hex colour.

    ``amount`` is a fraction in roughly [-1, 1].  Positive blends toward white,
    negative blends toward black, so the magnitude reads as a perceptual nudge
    rather than a raw channel offset.  Returns ``#rrggbb``.
    """
    r, g, b = _parse_hex(hex_color)
    if amount >= 0.0:
        r = r + (255 - r) * amount
        g = g + (255 - g) * amount
        b = b + (255 - b) * amount
    else:
        f = 1.0 + amount  # amount negative -> scale toward 0
        r *= f
        g *= f
        b *= f
    return f"#{_clamp8(r):02x}{_clamp8(g):02x}{_clamp8(b):02x}"


# ---------------------------------------------------------------------------
# SVG primitive emitters.  Each returns an SVG element *string*; the generator
# concatenates them inside an <svg> document.
def _fmt(v: float) -> str:
    # Compact but stable numeric formatting.
    return f"{v:.3f}".rstrip("0").rstrip(".") if isinstance(v, float) else str(v)


def _pts(points: Sequence[Sequence[float]]) -> str:
    return " ".join(f"{_fmt(float(x))},{_fmt(float(y))}" for x, y in points)


def _stroke_attrs(stroke: str | None, sw: float, *, cap: str | None = None) -> str:
    if not stroke:
        return ""
    out = f' stroke="{stroke}" stroke-width="{_fmt(float(sw))}"'
    if cap:
        out += f' stroke-linecap="{cap}" stroke-linejoin="round"'
    else:
        out += ' stroke-linejoin="round"'
    return out


def polygon(points, fill, *, opacity: float = 1.0, stroke: str | None = None, sw: float = 0.0) -> str:
    op = "" if opacity >= 0.999 else f' opacity="{_fmt(float(opacity))}"'
    return f'<polygon points="{_pts(points)}" fill="{fill}"{_stroke_attrs(stroke, sw)}{op}/>'


def ellipse(cx, cy, rx, ry, fill, *, opacity: float = 1.0, stroke: str | None = None,
            sw: float = 0.0, rotate: float = 0.0) -> str:
    op = "" if opacity >= 0.999 else f' opacity="{_fmt(float(opacity))}"'
    tr = ""
    if rotate:
        tr = f' transform="rotate({_fmt(float(rotate))} {_fmt(float(cx))} {_fmt(float(cy))})"'
    return (f'<ellipse cx="{_fmt(float(cx))}" cy="{_fmt(float(cy))}" '
            f'rx="{_fmt(float(rx))}" ry="{_fmt(float(ry))}" fill="{fill}"'
            f'{_stroke_attrs(stroke, sw)}{op}{tr}/>')


def line(a, b, color, width, *, cap: str = "round", opacity: float = 1.0) -> str:
    op = "" if opacity >= 0.999 else f' opacity="{_fmt(float(opacity))}"'
    return (f'<line x1="{_fmt(float(a[0]))}" y1="{_fmt(float(a[1]))}" '
            f'x2="{_fmt(float(b[0]))}" y2="{_fmt(float(b[1]))}" '
            f'stroke="{color}" stroke-width="{_fmt(float(width))}" '
            f'stroke-linecap="{cap}"{op}/>')


def path(d, *, fill: str = "none", stroke: str | None = None, sw: float = 0.0, opacity: float = 1.0) -> str:
    # fill defaults to "none" so stroke-only folds/lapels/blood do not become
    # solid black blobs (SVG defaults missing fill to black).
    op = "" if opacity >= 0.999 else f' opacity="{_fmt(float(opacity))}"'
    return f'<path d="{d}" fill="{fill}"{_stroke_attrs(stroke, sw, cap="round")}{op}/>'


# ---------------------------------------------------------------------------
# Character profile.
@dataclass
class CharacterProfile:
    name: str
    coat: str
    coat_dark: str
    coat_side: str
    pants: str
    skin: str
    rim: str
    accent: str
    metal: str
    hair: str
    weapon: str
    build: float
    contrast: float = 1.0
    long_coat: bool = False
    hooded: bool = False
    masked: bool = False
    armored: bool = False
    helmeted: bool = False
    eyes: bool = False
    # Optional / rarely positional.  Defaulted to valid hex in __post_init__ so
    # _defs never calls shade("") and the draw code never fills with "".
    cloth: str = ""
    leather: str = ""

    def __post_init__(self) -> None:
        # Cloth (hood/mask lining) defaults to a muted, slightly cool dark
        # derived from the coat shadow.  Leather (belt/straps) defaults the same.
        if not self.cloth:
            self.cloth = shade(self.coat_dark, 0.10)
        if not self.leather:
            self.leather = shade(self.coat_dark, 0.06)


# ---------------------------------------------------------------------------
# Pose table.  CharacterAtlas2D._select_row maps the same 16 rows; keep aligned.
def _pose_for_row(row: int) -> dict:
    pose = {
        "down": 0,
        "corpse": 0,
        "phase": 0.0,
        "walk": 0,
        "attack": 0,
        "hit": 0,
        "feed": 0,
    }
    if row == 0:        # idle A
        pose["phase"] = 0.0
    elif row == 1:      # idle B (breathing offset)
        pose["phase"] = math.pi
    elif 2 <= row <= 7:  # walk 0..5
        pose["walk"] = 1
        pose["phase"] = (row - 2) / 6.0 * 2.0 * math.pi
    elif row == 8:      # attack anticipate
        pose["attack"] = 1
    elif row == 9:      # attack strike
        pose["attack"] = 2
    elif row == 10:     # follow-through
        pose["attack"] = 3
    elif row == 11:     # recover
        pose["attack"] = 4
    elif row == 12:     # hit reaction
        pose["hit"] = 1
    elif row == 13:     # feed
        pose["feed"] = 1
    elif row == 14:     # downed (still alive)
        pose["down"] = 1
    elif row == 15:     # corpse (inert)
        pose["corpse"] = 1
    return pose


# ---------------------------------------------------------------------------
# Gradient defs.  Returns the inner <linearGradient> markup only; the generator
# wraps it with <defs>...</defs>.  Top-lit: lighter top stop -> base -> darker.
def _linear_grad(grad_id: str, base: str, *, top: float = 0.10, bottom: float = -0.14) -> str:
    c_top = shade(base, top)
    c_bot = shade(base, bottom)
    return (
        f'<linearGradient id="{grad_id}" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{c_top}"/>'
        f'<stop offset="0.5" stop-color="{base}"/>'
        f'<stop offset="1" stop-color="{c_bot}"/>'
        f'</linearGradient>'
    )


def _defs(profile: CharacterProfile) -> str:
    n = profile.name
    parts = [
        _linear_grad(f"{n}_coat", profile.coat),
        _linear_grad(f"{n}_coat_side", profile.coat_side),
        _linear_grad(f"{n}_pants", profile.pants),
        # Both _face and _skin are referenced by the draw code (face on the
        # head, skin on the hands).  Define BOTH from profile.skin.
        _linear_grad(f"{n}_face", profile.skin, top=0.12, bottom=-0.16),
        _linear_grad(f"{n}_skin", profile.skin, top=0.12, bottom=-0.16),
        _linear_grad(f"{n}_cloth", profile.cloth),
        _linear_grad(f"{n}_metal", profile.metal, top=0.22, bottom=-0.20),
    ]
    return "".join(parts)


# ---------------------------------------------------------------------------
# Asset writer.  Late-binds PROFILES / generate_character_atlas as module
# globals because generate_visual_atlas.py injects them before calling this.
def write_assets(output_dir) -> list:
    out = Path(output_dir)
    char_dir = out / "characters"
    char_dir.mkdir(parents=True, exist_ok=True)

    g = globals()
    profiles = g["PROFILES"]
    gen = g["generate_character_atlas"]

    written: list[Path] = []
    for profile in profiles:
        svg = gen(profile)
        dest = char_dir / f"{profile.name}_atlas.svg"
        dest.write_text(svg, encoding="utf-8")
        written.append(dest)

    # main() reads this back via json.loads then .update — must be parseable.
    manifest = out / "atlas_manifest.json"
    manifest.write_text(json.dumps({}, indent=2) + "\n", encoding="utf-8")
    written.append(manifest)
    return written
