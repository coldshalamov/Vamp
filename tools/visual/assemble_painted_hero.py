#!/usr/bin/env python3
"""Assemble painted directional renders into the hero atlas (painted pipeline proof).

Cuts each painted direction off its dark background, baseline-aligns it into a
192x256 cell, maps the 4 rendered facings onto the 8 atlas columns, and writes
hero_diffuse/normal/specular. The hero material is render_mode unshaded so the
pre-lit painted art shows as-is in-engine.
"""
import os, sys, numpy as np
from PIL import Image
from scipy import ndimage

SP = os.path.join(os.environ['LOCALAPPDATA'], 'Temp', 'claude',
                  'C--Users-93rob-Documents-GitHub-Vamp',
                  '868aa258-6dac-490f-9774-98e2b9156810', 'scratchpad')
REPO = r"C:\Users\93rob\Documents\GitHub\Vamp"
ATLAS = os.path.join(REPO, "assets", "visual", "atlases")
COLS, ROWS, CW, CH, BASE = 8, 16, 192, 256, 224


def cutout(img):
    """Flood-fill the dark background from the borders -> figure alpha."""
    a = np.array(img.convert("RGB")).astype(np.int16)
    corners = np.concatenate([a[:10, :10].reshape(-1, 3), a[:10, -10:].reshape(-1, 3),
                              a[-10:, :10].reshape(-1, 3), a[-10:, -10:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(2))
    close = dist < 42
    lbl, n = ndimage.label(close)
    edge = np.unique(np.concatenate([lbl[0], lbl[-1], lbl[:, 0], lbl[:, -1]]))
    edge = edge[edge > 0]
    fig = ~np.isin(lbl, edge)
    fig = ndimage.binary_closing(fig, iterations=2)
    fig = ndimage.binary_fill_holes(fig)
    # keep the largest connected figure component
    fl, fn = ndimage.label(fig)
    if fn > 1:
        sizes = ndimage.sum(np.ones_like(fl), fl, range(1, fn + 1))
        fig = fl == (np.argmax(sizes) + 1)
    rgba = np.dstack([np.array(img.convert("RGB")), (fig * 255).astype(np.uint8)])
    return rgba, fig


def cell_from(rgba, fig):
    ys, xs = np.where(fig)
    crop = Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")
    th = 206
    tw = max(1, int(crop.width * th / crop.height))
    crop = crop.resize((tw, th), Image.LANCZOS)
    cell = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    ox = (CW - tw) // 2
    cell.alpha_composite(crop, (max(0, ox), BASE - th))
    # edge dilate
    arr = np.array(cell).astype(np.float32)
    rgb, al = arr[..., :3], arr[..., 3]
    solid = al > 24
    for _ in range(4):
        unk = ~solid
        acc = np.zeros_like(rgb); cnt = np.zeros(rgb.shape[:2], np.float32)
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)):
            sh = np.roll(np.roll(rgb, dy, 0), dx, 1); sm = np.roll(np.roll(solid, dy, 0), dx, 1)
            acc += sh * sm[..., None]; cnt += sm
        fill = unk & (cnt > 0); rgb[fill] = acc[fill] / cnt[fill, None]; solid |= fill
    arr[..., :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def main():
    # painted dirs available
    dirs = {}
    for i in range(4):
        p = os.path.join(SP, f"pdir_{i}.png")
        if os.path.exists(p):
            rgba, fig = cutout(Image.open(p))
            dirs[i] = cell_from(rgba, fig)
            print(f"cut pdir_{i}")
    if not dirs:
        print("no painted dirs"); return 1
    # map 4 facings -> 8 columns (each dir fills 2 adjacent cols); fall back to any available
    order = sorted(dirs.keys())
    colmap = {}
    for c in range(COLS):
        colmap[c] = dirs[order[(c // 2) % len(order)]]
    atlas = Image.new("RGBA", (COLS * CW, ROWS * CH), (0, 0, 0, 0))
    for c in range(COLS):
        cell = colmap[c]
        for r in range(ROWS):
            atlas.paste(cell, (c * CW, r * CH))
    atlas.save(os.path.join(ATLAS, "hero_diffuse.png"))
    Image.new("RGBA", (COLS*CW//2, ROWS*CH//2), (128,128,255,255)).save(os.path.join(ATLAS, "hero_normal.png"))
    Image.new("RGBA", (COLS*CW//4, ROWS*CH//4), (28,28,28,255)).save(os.path.join(ATLAS, "hero_specular.png"))
    print(f"wrote painted hero atlas from {len(dirs)} dirs -> {ATLAS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
