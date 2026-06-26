#!/usr/bin/env python3
"""validate_visual_assets.py — regression gate for the 3D->2D atlas pipeline.

Checks the assembled atlases under assets/visual/atlases/ against the shipping
contract and rejects the classic failure modes the visual guide names:

  * wrong normal/specular ratio vs the diffuse atlas;
  * empty animation cells;
  * narrow / low-area standing silhouettes (stick-figure regression);
  * floating actors (baseline drift) or feet clipped off the cell;
  * non-normalized normal vectors (when the map carries real normals);
  * non-flat normal-map background outside the silhouette;
  * broken res:// material paths in the CanvasTexture .tres;
  * a live renderer that no longer binds CharacterAtlas2D.

Cell size is derived per atlas (W/8 x H/16) so the 192x256 Blender atlases and
the legacy 96x128 SVG atlases (e.g. rat) validate side by side during rollout.

Exit code 0 == all checks pass.  --json-out writes a metrics file that
test/unit/test_visual_assets.gd consumes.
"""
from __future__ import annotations
import argparse, json, re, sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
ATLAS_DIR = REPO / "assets" / "visual" / "atlases"
MAT_DIR = REPO / "assets" / "visual" / "materials" / "characters"
SOURCE_DIR = REPO / "assets" / "visual" / "source" / "characters"
ENTITY_RENDERER = REPO / "src" / "present" / "EntityRenderer.gd"

COLS, ROWS = 8, 16
ALPHA_THR = 24
NON_HUMANOID = {"rat"}                      # quadruped: skip the standing-figure checks
STANDING_ROWS = list(range(0, 12)) + [13]   # idles, walk, attack, feed
FLAT_NORMAL = (128, 128, 255)


def _cell(arr, row, col, cw, ch):
    return arr[row*ch:(row+1)*ch, col*cw:(col+1)*cw]


def check_archetype(arche: str, errors: list, warnings: list) -> dict:
    diff_p = ATLAS_DIR / f"{arche}_diffuse.png"
    nrm_p = ATLAS_DIR / f"{arche}_normal.png"
    spc_p = ATLAS_DIR / f"{arche}_specular.png"
    rec: dict = {"frames": COLS * ROWS}
    for p in (diff_p, nrm_p, spc_p):
        if not p.exists():
            errors.append(f"{arche}: missing {p.name}")
            return rec

    diff_img = Image.open(diff_p).convert("RGBA")
    W, H = diff_img.size
    cw, ch = W // COLS, H // ROWS
    rec["cell"] = [cw, ch]
    rec["compressed_bytes"] = diff_p.stat().st_size

    nrm_img = Image.open(nrm_p).convert("RGBA")
    spc_img = Image.open(spc_p).convert("RGBA")
    if nrm_img.size != (W // 2, H // 2):
        errors.append(f"{arche}: normal {nrm_img.size} != diffuse/2 {(W//2, H//2)}")
    if spc_img.size != (W // 4, H // 4):
        errors.append(f"{arche}: specular {spc_img.size} != diffuse/4 {(W//4, H//4)}")

    diff = np.array(diff_img)
    alpha = diff[..., 3] > ALPHA_THR
    humanoid = arche not in NON_HUMANOID
    base_lo, base_hi = ch * 0.74, ch * 0.99
    min_fill, min_stand_fill, min_w = 0.010, 0.040, cw * 0.13

    empty, narrow, floaty = [], [], []
    for row in range(ROWS):
        for col in range(COLS):
            c = _cell(alpha, row, col, cw, ch)
            fill = c.mean()
            if fill < min_fill:
                empty.append((row, col)); continue
            ys, xs = np.where(c)
            w = xs.max() - xs.min(); feet = ys.max()
            if humanoid and row in STANDING_ROWS:
                if fill < min_stand_fill or w < min_w:
                    narrow.append((row, col, round(float(fill), 3), int(w)))
                if not (base_lo <= feet <= base_hi):
                    floaty.append((row, col, int(feet)))
    if empty:
        errors.append(f"{arche}: {len(empty)} empty cells e.g. {empty[:4]}")
    if narrow:
        errors.append(f"{arche}: {len(narrow)} stick/narrow standing cells e.g. {narrow[:4]}")
    if floaty:
        errors.append(f"{arche}: {len(floaty)} baseline-drift cells (feet y) e.g. {floaty[:4]}")
    rec.update(empty_cells=len(empty), narrow_cells=len(narrow), baseline_drift=len(floaty))

    # ---- normal map: normalized + flat background (only when it carries real normals) ----
    nrm = np.array(nrm_img)
    rgb = nrm[..., :3].astype(np.float32)
    isflat = (np.abs(rgb[..., 0]-128) <= 6) & (np.abs(rgb[..., 1]-128) <= 6) & (np.abs(rgb[..., 2]-255) <= 8)
    nonflat = ~isflat
    if nonflat.mean() < 0.01:
        warnings.append(f"{arche}: normal map is flat placeholder (legacy) — skipping normal checks")
        rec["normal_normalized_frac"] = None
    else:
        n = rgb[nonflat] / 255.0 * 2.0 - 1.0
        lens = np.linalg.norm(n, axis=1)
        frac_ok = float(np.mean((lens > 0.82) & (lens < 1.18)))
        rec["normal_normalized_frac"] = round(frac_ok, 4)
        if frac_ok < 0.92:
            errors.append(f"{arche}: normal vectors not normalized ({frac_ok:.2%} ok)")
        # flat background: sample cell corners
        cwn, chn = W // 2 // COLS, H // 2 // ROWS
        off = 0
        for row in range(ROWS):
            for col in range(COLS):
                cc = _cell(nrm, row, col, cwn, chn)
                for (yy, xx) in ((2, 2), (2, cwn-3), (chn-3, 2)):
                    px = cc[yy, xx, :3]
                    if abs(int(px[0])-128) > 8 or abs(int(px[1])-128) > 8 or abs(int(px[2])-255) > 10:
                        off += 1
        if off > ROWS*COLS*3*0.06:
            errors.append(f"{arche}: normal background not flat ({off} corner samples off)")

    # ---- material .tres ----
    tres = MAT_DIR / f"{arche}.tres"
    if not tres.exists():
        errors.append(f"{arche}: missing material {tres.name}")
    else:
        for ref in re.findall(r'path="res://([^"]+)"', tres.read_text(encoding="utf-8")):
            if not (REPO / ref).exists():
                errors.append(f"{arche}: .tres references missing {ref}")
    return rec


def check_wiring(errors: list) -> None:
    if not ENTITY_RENDERER.exists():
        errors.append("EntityRenderer.gd not found"); return
    src = ENTITY_RENDERER.read_text(encoding="utf-8")
    if "CharacterAtlas2D" not in src:
        errors.append("live EntityRenderer.gd does not bind CharacterAtlas2D (atlas orphaned)")
    if re.search(r'preload\([^)]*CharacterRig2D\.gd', src):
        errors.append("live EntityRenderer.gd preloads CharacterRig2D.gd (procedural regression)")


def count_production_files() -> int:
    n = 0
    for d, pat in ((ATLAS_DIR, "*.png"), (MAT_DIR, "*.tres"), (SOURCE_DIR, "*.svg")):
        n += len(list(d.glob(pat))) if d.exists() else 0
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--archetypes", default="")
    ap.add_argument("--json-out", default="")
    ap.add_argument("--skip-wiring", action="store_true")
    args = ap.parse_args()

    if args.archetypes:
        arches = [a.strip() for a in args.archetypes.split(",") if a.strip()]
    else:
        arches = sorted({p.name[:-len("_diffuse.png")] for p in ATLAS_DIR.glob("*_diffuse.png")})
    if not arches:
        print("No atlases found to validate.")
        return 1

    errors, warnings = [], []
    characters = {}
    for a in arches:
        characters[a] = check_archetype(a, errors, warnings)
    if not args.skip_wiring:
        check_wiring(errors)

    metrics = {
        "errors": errors, "warnings": warnings,
        "production_files": count_production_files(),
        "characters": characters,
    }
    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"FAIL  {e}")
    print("-" * 60)
    print(f"Validated: {', '.join(arches)}   production_files={metrics['production_files']}")
    if args.json_out:
        Path(args.json_out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.json_out).write_text(json.dumps(metrics, indent=2))

    if errors:
        print(f"RESULT: FAIL ({len(errors)} errors)")
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
