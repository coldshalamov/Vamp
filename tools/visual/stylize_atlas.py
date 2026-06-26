#!/usr/bin/env python3
"""stylize_atlas.py — gritty rotoscope / hand-painted-over-3D post for a diffuse atlas.

Pure PIL/numpy (no Blender).  Takes the smooth lit diffuse atlas produced by
assemble_atlas.py and re-grades it toward the "Dead Cells" rotoscoped look and
the "Vampire: the Masquerade Bloodlines" gritty urban-gothic mood: inked
silhouettes + interior creases, a touch of painterly value quantization, crisp
local-contrast grit, film grain and a faint procedural grime, and an optional
sub-pixel chromatic offset.

It operates PER CELL on the assembled diffuse atlas
(1536x4096 RGBA; 8 cols x 16 rows; 192x256 cells).  Every operation is confined
to a single cell rect and gated by that cell's own alpha, so ink, grain and
grime can NEVER bleed across cell boundaries or out of the silhouette.  The
alpha channel is preserved untouched (the assembler already edge-dilated the RGB
under it, so linear filtering / mipmaps stay halo-free).

This enhances line and grit; it does not repaint the render.  Defaults are
tuned to be tasteful — readable inking, gentle posterize, subtle grain — not a
cartoon filter.  Push the strength flags up for a heavier pass.

Run (writes back over the assembler's diffuse atlas):
    python tools/visual/stylize_atlas.py --archetype hero

Non-destructive (writes {arche}_diffuse_styl.png alongside the source):
    python tools/visual/stylize_atlas.py --archetype hero --suffix _styl

Heavier ink + grime, lighter posterize:
    python tools/visual/stylize_atlas.py --archetype thug \
        --ink 1.4 --grime 1.3 --posterize 10
"""
from __future__ import annotations
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

REPO = Path(__file__).resolve().parents[2]
ATLAS_DIR = REPO / "assets" / "visual" / "atlases"

# Atlas contract (kept in sync with assemble_atlas.py / CharacterAtlas2D.gd).
COLS, ROWS = 8, 16
CELL_W, CELL_H = 192, 256
ALPHA_THR = 24                       # below this a texel is "background"

# Rec.709 luma weights — perceptual luminance for ink + grime.
LUMA = np.array([0.2126, 0.7152, 0.0722], np.float32)


# --------------------------------------------------------------------------
# Small numeric helpers.  A pure-numpy separable Gaussian keeps the blur running
# on the exact float luminance/grime fields (PIL 12 dropped GaussianBlur for 'F'
# mode planes) and stays confined to the cell — edges are clamp-replicated, never
# wrapped, so nothing leaks across the cell rect.
_GAUSS_CACHE: dict = {}


def _gauss_kernel(sigma: float) -> np.ndarray:
    sigma = float(max(sigma, 1e-3))
    key = round(sigma, 4)
    k = _GAUSS_CACHE.get(key)
    if k is None:
        radius = max(1, int(round(sigma * 3.0)))
        x = np.arange(-radius, radius + 1, dtype=np.float32)
        k = np.exp(-(x * x) / (2.0 * sigma * sigma))
        k /= k.sum()
        _GAUSS_CACHE[key] = k
    return k


def _gauss(plane: np.ndarray, radius: float) -> np.ndarray:
    """Separable Gaussian blur of a float32 HxW plane (edge-clamped), float32 out."""
    if radius <= 0.0:
        return plane.astype(np.float32, copy=True)
    k = _gauss_kernel(radius)
    r = (k.size - 1) // 2
    p = np.pad(plane.astype(np.float32), ((0, 0), (r, r)), mode="edge")
    # horizontal pass
    out = np.zeros_like(plane, dtype=np.float32)
    for i, w in enumerate(k):
        out += w * p[:, i:i + plane.shape[1]]
    p = np.pad(out, ((r, r), (0, 0)), mode="edge")
    # vertical pass
    out = np.zeros_like(plane, dtype=np.float32)
    for i, w in enumerate(k):
        out += w * p[i:i + plane.shape[0], :]
    return out


def _luma(rgb: np.ndarray) -> np.ndarray:
    """Rec.709 luminance of an HxWx3 float array in [0,1]."""
    return rgb @ LUMA


def _median3(rgb: np.ndarray) -> np.ndarray:
    """3x3 median per channel — knocks out render speckle / fireflies before the
    edge pass without the smear of a box blur.  Operates on a [0,1] HxWx3 array."""
    src = Image.fromarray(np.clip(rgb * 255.0, 0, 255).astype(np.uint8), "RGB")
    out = src.filter(ImageFilter.MedianFilter(size=3))
    return np.asarray(out, np.float32) / 255.0


def _smooth(rgb: np.ndarray, strength: float) -> np.ndarray:
    """Edge-aware-ish painterly smoothing.  A gentle Gaussian flattens micro-noise
    and consolidates value blocks (the cheap stand-in for a bilateral filter),
    blended back toward the source by `strength` so silhouette detail survives."""
    if strength <= 0.0:
        return rgb
    blurred = np.empty_like(rgb)
    for c in range(3):
        blurred[..., c] = _gauss(rgb[..., c], radius=1.1)
    s = float(np.clip(strength, 0.0, 1.0))
    return rgb * (1.0 - s) + blurred * s


def _posterize_value(rgb: np.ndarray, levels: int) -> np.ndarray:
    """Gentle value quantization in luminance only — quantize the brightness band
    and rescale RGB to it, so hue/saturation are untouched and the result reads as
    painted value steps rather than a flat cel-shade.  `levels` <= 1 disables it."""
    if levels <= 1:
        return rgb
    y = _luma(rgb)
    yq = np.round(y * (levels - 1)) / float(levels - 1)
    # soften the steps so banding doesn't read as posterization
    yq = 0.6 * yq + 0.4 * y
    scale = np.where(y > 1e-4, yq / np.maximum(y, 1e-4), 1.0)
    return np.clip(rgb * scale[..., None], 0.0, 1.0)


def _hash_noise(h: int, w: int, seed: int) -> np.ndarray:
    """Deterministic [0,1) HxW noise.  A fixed seed keeps re-runs byte-identical so
    the atlas import hash is stable and grain doesn't crawl between builds."""
    rng = np.random.default_rng(seed)
    return rng.random((h, w), dtype=np.float32)


# --------------------------------------------------------------------------
def stylize_cell(rgba: np.ndarray, opt: dict) -> np.ndarray:
    """Apply the full stylize pipeline to one CELL_H x CELL_W x 4 uint8 array.

    Alpha is preserved exactly; all RGB work is masked by `solid` (alpha>thr) so
    nothing leaks into the transparent margin or across the cell rect."""
    a = rgba[..., 3]
    solid = a > ALPHA_THR
    if not solid.any():
        return rgba.copy()

    rgb = rgba[..., :3].astype(np.float32) / 255.0
    base = rgb.copy()
    m = solid.astype(np.float32)[..., None]            # broadcastable RGB mask

    # (0) de-speckle so the edge pass inks real form, not render fireflies.
    rgb = _median3(rgb)

    # (1) EDGE INK — Difference-of-Gaussians on luminance picks up the silhouette
    # rim and interior creases (coat folds, jaw, knuckles).  Thresholded to dark
    # ink and composited MULTIPLICATIVELY, only inside the silhouette.
    if opt["ink"] > 0.0:
        y = _luma(rgb)
        # keep the DoG inside the body: blur a masked luminance so the hard alpha
        # edge itself doesn't register as a giant ink line around the whole cell.
        ym = y * solid
        g1 = _gauss(ym, radius=opt["ink_fine"])
        g2 = _gauss(ym, radius=opt["ink_coarse"])
        sm = _gauss(solid.astype(np.float32), radius=opt["ink_coarse"])
        sm = np.maximum(sm, 1e-3)
        dog = (g1 / sm) - (g2 / sm)                     # normalize by coverage
        # Sobel gradient magnitude adds the crisp silhouette/crease lines.
        gx = np.zeros_like(y); gy = np.zeros_like(y)
        gx[:, 1:-1] = y[:, 2:] - y[:, :-2]
        gy[1:-1, :] = y[2:, :] - y[:-2, :]
        grad = np.sqrt(gx * gx + gy * gy)
        edge = np.maximum(np.maximum(dog, 0.0) * 6.0, grad * 2.2)
        # soft threshold -> ink amount in [0,1]
        t = opt["ink_thresh"]
        ink = np.clip((edge - t) / max(1e-3, (1.0 - t)), 0.0, 1.0)
        ink = ink ** 1.4                                # bias toward the strong lines
        ink *= solid.astype(np.float32)
        ink = _gauss(ink, radius=0.6)                   # 1px feather, anti-alias
        ink *= solid.astype(np.float32)                 # re-clip to silhouette
        # darken multiplicatively: 1.0 where no ink, -> ink_dark where full ink.
        darken = 1.0 - ink[..., None] * (opt["ink"] * (1.0 - opt["ink_dark"]))
        rgb = rgb * np.clip(darken, 0.0, 1.0)

    # (2) PAINTERLY — light smoothing then a gentle value posterize.
    rgb = _smooth(rgb, opt["smooth"])
    rgb = _posterize_value(rgb, opt["posterize"])

    # (3) LOCAL CONTRAST / GRIT — unsharp on a blurred copy lifts surface micro
    # detail (fabric weave, edge-wear, grime) without the ringing of a global S-curve.
    if opt["grit"] > 0.0:
        blur = np.empty_like(rgb)
        for c in range(3):
            blur[..., c] = _gauss(rgb[..., c], radius=2.4)
        rgb = np.clip(rgb + (rgb - blur) * opt["grit"], 0.0, 1.0)

    # (4) FILM GRAIN + PROCEDURAL GRIME.  Grain is luminance-coupled (stronger in
    # midtones, quiet in highlights/shadows).  Grime is a low-frequency dark mottle
    # multiplied in, biased toward the lower body where a street predator gets dirty.
    if opt["grain"] > 0.0:
        y = _luma(rgb)
        n = _hash_noise(CELL_H, CELL_W, opt["seed"]) - 0.5
        midtone = 1.0 - np.abs(y - 0.5) * 2.0           # 1 at mid, 0 at the rails
        rgb = np.clip(rgb + (n * midtone)[..., None] * opt["grain"], 0.0, 1.0)

    if opt["grime"] > 0.0:
        gnoise = _hash_noise(CELL_H, CELL_W, opt["seed"] + 977)
        gnoise = _gauss(gnoise, radius=opt["grime_scale"])
        gnoise = (gnoise - gnoise.min()) / max(1e-4, (gnoise.max() - gnoise.min()))
        # vertical bias: cleaner at the head, grimier toward the feet.
        yy = np.linspace(0.0, 1.0, CELL_H, dtype=np.float32)[:, None]
        bias = 0.55 + 0.45 * yy
        grime = 1.0 - (gnoise * bias) * opt["grime"] * 0.22
        rgb = rgb * np.clip(grime, 0.0, 1.0)[..., None]

    # (5) CHROMATIC OFFSET — sub-pixel R/B split for a faint film/lens grit.  Tiny;
    # masked so fringes can't spill past the silhouette.
    if opt["chroma"] > 0.0:
        sh = max(1, int(round(opt["chroma"])))
        r = np.roll(rgb[..., 0], sh, axis=1)
        b = np.roll(rgb[..., 2], -sh, axis=1)
        rgb[..., 0] = rgb[..., 0] * 0.5 + r * 0.5
        rgb[..., 2] = rgb[..., 2] * 0.5 + b * 0.5

    # Composite back only inside the silhouette; transparent margin keeps the
    # assembler's edge-dilated RGB so we never introduce a halo.
    out_rgb = base * (1.0 - m) + np.clip(rgb, 0.0, 1.0) * m

    out = rgba.copy()
    out[..., :3] = np.clip(out_rgb * 255.0 + 0.5, 0, 255).astype(np.uint8)
    # alpha untouched
    return out


# --------------------------------------------------------------------------
def stylize_atlas(src: Image.Image, opt: dict) -> Image.Image:
    arr = np.array(src.convert("RGBA"))
    H, W = arr.shape[:2]
    exp_w, exp_h = COLS * CELL_W, ROWS * CELL_H
    if (W, H) != (exp_w, exp_h):
        # Derive the cell grid from the actual texture so legacy/other-sized atlases
        # still process per-cell (mirrors CharacterAtlas2D._refresh_atlas).
        cw, ch = W // COLS, H // ROWS
    else:
        cw, ch = CELL_W, CELL_H
    if cw <= 0 or ch <= 0:
        raise ValueError(f"atlas {W}x{H} is smaller than the {COLS}x{ROWS} grid")

    for row in range(ROWS):
        for col in range(COLS):
            y0, x0 = row * ch, col * cw
            cell = arr[y0:y0 + ch, x0:x0 + cw]
            if cell.shape[0] != ch or cell.shape[1] != cw:
                continue
            # Per-cell deterministic seed so grain differs cell-to-cell but is
            # reproducible across builds.
            cell_opt = dict(opt, seed=opt["seed"] + row * COLS + col)
            arr[y0:y0 + ch, x0:x0 + cw] = stylize_cell(cell, cell_opt)

    return Image.fromarray(arr, "RGBA")


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--archetype", required=True,
                    help="atlas basename, e.g. hero -> {arche}_diffuse.png")
    ap.add_argument("--atlas-dir", default=str(ATLAS_DIR))
    grp = ap.add_mutually_exclusive_group()
    grp.add_argument("--in-place", action="store_true",
                     help="overwrite the diffuse atlas (default)")
    grp.add_argument("--suffix", default=None,
                     help="write {arche}_diffuse{suffix}.png instead of overwriting")

    # Strength flags (defaults tuned tasteful, not cartoon).
    ap.add_argument("--ink", type=float, default=0.85,
                    help="edge-ink strength 0..~1.5 (0 disables)")
    ap.add_argument("--ink-dark", type=float, default=0.30,
                    help="darkest ink multiplier (0=black line, 1=no darkening)")
    ap.add_argument("--ink-thresh", type=float, default=0.16,
                    help="edge response threshold before a line inks")
    ap.add_argument("--ink-fine", type=float, default=0.9, help="DoG fine sigma")
    ap.add_argument("--ink-coarse", type=float, default=2.6, help="DoG coarse sigma")
    ap.add_argument("--smooth", type=float, default=0.35,
                    help="painterly smoothing blend 0..1")
    ap.add_argument("--posterize", type=int, default=14,
                    help="value-quantize levels (<=1 disables; lower = chunkier)")
    ap.add_argument("--grit", type=float, default=0.45,
                    help="local-contrast / unsharp amount")
    ap.add_argument("--grain", type=float, default=0.045,
                    help="film grain amplitude (0 disables)")
    ap.add_argument("--grime", type=float, default=0.85,
                    help="procedural grime strength 0..~1.5 (0 disables)")
    ap.add_argument("--grime-scale", type=float, default=14.0,
                    help="grime blob blur radius (bigger = larger smears)")
    ap.add_argument("--chroma", type=float, default=0.0,
                    help="chromatic R/B pixel offset (0 disables)")
    ap.add_argument("--seed", type=int, default=1337,
                    help="base RNG seed for deterministic grain/grime")
    args = ap.parse_args()

    adir = Path(args.atlas_dir)
    src_path = adir / f"{args.archetype}_diffuse.png"
    if not src_path.exists():
        raise FileNotFoundError(src_path)

    if args.suffix:
        dst_path = adir / f"{args.archetype}_diffuse{args.suffix}.png"
    else:
        dst_path = src_path        # in-place is the default

    opt = dict(
        ink=args.ink, ink_dark=args.ink_dark, ink_thresh=args.ink_thresh,
        ink_fine=args.ink_fine, ink_coarse=args.ink_coarse,
        smooth=args.smooth, posterize=args.posterize, grit=args.grit,
        grain=args.grain, grime=args.grime, grime_scale=args.grime_scale,
        chroma=args.chroma, seed=args.seed,
    )

    src = Image.open(src_path)
    out = stylize_atlas(src, opt)
    out.save(dst_path)
    print(f"[stylize] {args.archetype}: {src.size} -> {dst_path.name}")
    print(f"[stylize] ink={args.ink} posterize={args.posterize} grit={args.grit} "
          f"grain={args.grain} grime={args.grime} chroma={args.chroma}")
    print(f"[stylize] wrote -> {dst_path}")


if __name__ == "__main__":
    main()
