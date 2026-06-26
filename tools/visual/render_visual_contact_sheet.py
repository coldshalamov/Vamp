#!/usr/bin/env python3
"""render_visual_contact_sheet.py — human-review evidence from shipped atlases.

For each archetype it writes, under docs/evidence/visual_revamp/:

    {arche}_contact.png   the full 8x16 diffuse grid composited over the game's
                          night palette, so silhouette / direction / pose read
                          can be judged at game tone (not over white).
    {arche}_relight.png   a lighting-response panel: representative cells re-lit
                          from several directions using the baked normal map, to
                          prove the normals drive Godot's dynamic 2D lights
                          correctly (no inverted/flat lobes).

Pure PIL/numpy.  Run:
    python tools/visual/render_visual_contact_sheet.py --archetypes hero
"""
from __future__ import annotations
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
ATLAS_DIR = REPO / "assets" / "visual" / "atlases"
OUT_DIR = REPO / "docs" / "evidence" / "visual_revamp"

COLS, ROWS = 8, 16
CELL_W, CELL_H = 192, 256
DIR_LABELS = ["E","SE","S","SW","W","NW","N","NE"]
ROW_LABELS = ["idleA","idleB","walk0","walk1","walk2","walk3","walk4","walk5",
              "antic","strike","follow","recover","hit","feed","downed","corpse"]
NIGHT_BG = (14, 16, 24)


def composite_night(rgba: np.ndarray, bg) -> np.ndarray:
    a = rgba[..., 3:4].astype(np.float32)/255.0
    rgb = rgba[..., :3].astype(np.float32)
    out = rgb*a + np.array(bg, np.float32)*(1-a)
    return np.clip(out, 0, 255).astype(np.uint8)


def contact_sheet(arche: str):
    diff = np.array(Image.open(ATLAS_DIR / f"{arche}_diffuse.png").convert("RGBA"))
    comp = composite_night(diff, NIGHT_BG)
    img = Image.fromarray(comp, "RGB")
    # downscale 2x for a manageable sheet, add a grid + labels
    scale = 0.5
    sw, sh = int(COLS*CELL_W*scale), int(ROWS*CELL_H*scale)
    img = img.resize((sw, sh), Image.LANCZOS)
    sheet = Image.new("RGB", (sw+60, sh+24), NIGHT_BG)
    sheet.paste(img, (60, 24))
    d = ImageDraw.Draw(sheet)
    cwf, chf = CELL_W*scale, CELL_H*scale
    for c, lbl in enumerate(DIR_LABELS):
        d.text((60+int(c*cwf)+cwf*0.5-6, 8), lbl, fill=(190,190,200))
    for r, lbl in enumerate(ROW_LABELS):
        d.text((4, 24+int(r*chf)+chf*0.5-4), lbl, fill=(170,170,185))
        d.line((60, 24+int(r*chf), sw+60, 24+int(r*chf)), fill=(40,44,54))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT_DIR / f"{arche}_contact.png")
    return sheet.size


def relight(arche: str):
    diff = np.array(Image.open(ATLAS_DIR / f"{arche}_diffuse.png").convert("RGBA"))
    nrm = np.array(Image.open(ATLAS_DIR / f"{arche}_normal.png").convert("RGBA"))
    nh, nw = nrm.shape[0]//ROWS, nrm.shape[1]//COLS

    # representative (row,col) cells
    picks = [(0,2),(4,2),(9,2),(13,2),(14,2)]
    pick_lbls = ["idle","walk","strike","feed","downed"]
    # light directions in screen space (x right, y up, z out)
    lights = [(-0.6,0.4,0.7),(0.0,0.0,1.0),(0.7,0.3,0.6)]
    light_lbls = ["L-key","front","R-rim"]

    pad = 6
    panel_w = len(lights)*(CELL_W+pad)+CELL_W+pad
    panel_h = len(picks)*(CELL_H+pad)+24
    panel = Image.new("RGB", (panel_w+60, panel_h), NIGHT_BG)
    d = ImageDraw.Draw(panel)
    d.text((64, 6), f"{arche}: diffuse | " + " | ".join(light_lbls)+"  (normal-mapped relight)", fill=(200,200,210))

    for pi, ((row, col), plbl) in enumerate(zip(picks, pick_lbls)):
        y0 = 24 + pi*(CELL_H+pad)
        d.text((4, y0+CELL_H//2), plbl, fill=(170,170,185))
        dc = diff[row*CELL_H:(row+1)*CELL_H, col*CELL_W:(col+1)*CELL_W]
        panel.paste(Image.fromarray(composite_night(dc, NIGHT_BG), "RGB"), (60, y0))
        # normal cell upscaled to diffuse cell size
        ncell = nrm[row*nh:(row+1)*nh, col*nw:(col+1)*nw]
        ncell = np.array(Image.fromarray(ncell, "RGBA").resize((CELL_W, CELL_H), Image.BILINEAR))
        N = ncell[..., :3].astype(np.float32)/255.0*2.0-1.0
        Nl = np.linalg.norm(N, axis=2, keepdims=True); Nl[Nl<1e-3]=1.0; N=N/Nl
        alpha = dc[..., 3:4].astype(np.float32)/255.0
        albedo = dc[..., :3].astype(np.float32)
        for li, (L, llbl) in enumerate(zip(lights, light_lbls)):
            Lv = np.array(L, np.float32); Lv/=np.linalg.norm(Lv)
            ndl = np.clip((N*Lv).sum(axis=2, keepdims=True), 0, 1)
            lit = albedo*(0.25+0.95*ndl)
            litc = composite_night(np.dstack([np.clip(lit,0,255), dc[...,3:4]]).astype(np.uint8), NIGHT_BG)
            x0 = 60 + (li+1)*(CELL_W+pad)
            panel.paste(Image.fromarray(litc, "RGB"), (x0, y0))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    panel.save(OUT_DIR / f"{arche}_relight.png")
    return panel.size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--archetypes", default="")
    args = ap.parse_args()
    if args.archetypes:
        arches = [a.strip() for a in args.archetypes.split(",") if a.strip()]
    else:
        arches = sorted({p.name[:-len("_diffuse.png")] for p in ATLAS_DIR.glob("*_diffuse.png")})
    for a in arches:
        cs = contact_sheet(a)
        rl = relight(a)
        print(f"[contact] {a}: contact {cs}  relight {rl}")


if __name__ == "__main__":
    main()
