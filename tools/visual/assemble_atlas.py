#!/usr/bin/env python3
"""assemble_atlas.py — stitch rendered cells into Godot atlas textures.

Pure PIL/numpy (no Blender).  Reads the per-cell PNGs produced by
blender_render_atlas.py and writes, under assets/visual/atlases/:

    {arche}_diffuse.png    1536x4096 RGBA  edge-dilated lit sprite
    {arche}_normal.png      768x2048 RGBA  renormalized, +Y-up, flat bg
    {arche}_specular.png    384x1024 RGBA  material-keyed grayscale

The diffuse keeps full cell resolution; normal/specular are halved/quartered
because their spatial frequency does not justify full VRAM at game scale.

Run:
    python tools/visual/assemble_atlas.py --archetype hero \
        --cells <cells_dir> [--atlas-dir assets/visual/atlases]
"""
from __future__ import annotations
import argparse, json
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
ATLAS_DIR = REPO / "assets" / "visual" / "atlases"

COLS, ROWS = 8, 16
CELL_W, CELL_H = 192, 256
BASELINE_Y = 224
NORMAL_DIV = 2      # half-res normal atlas
SPEC_DIV = 4        # quarter-res specular atlas
ALPHA_THR = 24
SPEC_FLOOR = 0.10   # matte background / unlit value
FLAT_NORMAL = (128, 128, 255)


def _load_cell(cells: Path, arche: str, passname: str, row: int, col: int) -> Image.Image:
    p = cells / f"{arche}_{passname}_r{row:02d}_c{col}.png"
    if not p.exists():
        raise FileNotFoundError(p)
    return Image.open(p).convert("RGBA")


def edge_dilate(rgba: np.ndarray, iters: int = 4) -> np.ndarray:
    """Bleed RGB outward beneath the alpha edge so linear filtering / mipmaps
    do not pull transparent-black halos into the silhouette."""
    out = rgba.copy()
    rgb = out[..., :3].astype(np.float32)
    a = out[..., 3]
    solid = a > ALPHA_THR
    for _ in range(iters):
        unknown = ~solid
        if not unknown.any():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros(rgb.shape[:2], np.float32)
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)):
            sh = np.roll(np.roll(rgb, dy, 0), dx, 1)
            sm = np.roll(np.roll(solid, dy, 0), dx, 1)
            acc += sh * sm[..., None]
            cnt += sm
        fill = unknown & (cnt > 0)
        rgb[fill] = (acc[fill] / cnt[fill, None])
        solid = solid | fill
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return out


def assemble_diffuse(cells, arche):
    atlas = Image.new("RGBA", (COLS*CELL_W, ROWS*CELL_H), (0,0,0,0))
    for row in range(ROWS):
        for col in range(COLS):
            cell = _load_cell(cells, arche, "diffuse", row, col)
            arr = edge_dilate(np.array(cell), iters=4)
            atlas.paste(Image.fromarray(arr, "RGBA"), (col*CELL_W, row*CELL_H))
    return atlas


def assemble_normal(cells, arche, flip_g):
    cw, ch = CELL_W//NORMAL_DIV, CELL_H//NORMAL_DIV
    atlas = Image.new("RGBA", (COLS*cw, ROWS*ch), (*FLAT_NORMAL, 255))
    for row in range(ROWS):
        for col in range(COLS):
            cell = _load_cell(cells, arche, "normal", row, col).resize((cw, ch), Image.LANCZOS)
            a = np.array(cell).astype(np.float32)
            alpha = a[..., 3]
            n = a[..., :3] / 255.0 * 2.0 - 1.0          # decode to [-1,1]
            if flip_g:
                n[..., 1] *= -1.0
            ln = np.linalg.norm(n, axis=2, keepdims=True)
            ln[ln < 1e-4] = 1.0
            n = n / ln                                   # renormalize
            enc = ((n * 0.5 + 0.5) * 255.0)
            flat = alpha <= ALPHA_THR
            enc[flat] = FLAT_NORMAL
            out = np.zeros((ch, cw, 4), np.uint8)
            out[..., :3] = np.clip(enc, 0, 255).astype(np.uint8)
            out[..., 3] = 255
            atlas.paste(Image.fromarray(out, "RGBA"), (col*cw, row*ch))
    return atlas


def assemble_specular(cells, arche):
    cw, ch = CELL_W//SPEC_DIV, CELL_H//SPEC_DIV
    atlas = Image.new("RGBA", (COLS*cw, ROWS*ch), (0,0,0,255))
    floor = int(SPEC_FLOOR*255)
    for row in range(ROWS):
        for col in range(COLS):
            cell = _load_cell(cells, arche, "spec", row, col).resize((cw, ch), Image.LANCZOS)
            a = np.array(cell).astype(np.float32)
            alpha = a[..., 3]
            val = a[..., 0]                              # emission grayscale
            val = np.where(alpha > ALPHA_THR, val, floor)
            out = np.zeros((ch, cw, 4), np.uint8)
            g = np.clip(val, 0, 255).astype(np.uint8)
            out[..., 0] = out[..., 1] = out[..., 2] = g
            out[..., 3] = 255
            atlas.paste(Image.fromarray(out, "RGBA"), (col*cw, row*ch))
    return atlas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--archetype", required=True)
    ap.add_argument("--cells", required=True)
    ap.add_argument("--atlas-dir", default=str(ATLAS_DIR))
    args = ap.parse_args()

    cells = Path(args.cells)
    adir = Path(args.atlas_dir); adir.mkdir(parents=True, exist_ok=True)
    arche = args.archetype

    meta_p = cells / f"{arche}_render_meta.json"
    flip_g = True
    if meta_p.exists():
        flip_g = bool(json.loads(meta_p.read_text()).get("normal_flip_g", True))

    diff = assemble_diffuse(cells, arche)
    nrm = assemble_normal(cells, arche, flip_g)
    spc = assemble_specular(cells, arche)

    diff.save(adir / f"{arche}_diffuse.png")
    nrm.save(adir / f"{arche}_normal.png")
    spc.save(adir / f"{arche}_specular.png")
    print(f"[assemble] {arche}: diffuse {diff.size}  normal {nrm.size}  specular {spc.size}")
    print(f"[assemble] wrote -> {adir}")


if __name__ == "__main__":
    main()
