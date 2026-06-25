#!/usr/bin/env python3
"""rasterize_visual_assets — turn the deterministic source SVGs into the shipping
raster atlases the Godot CanvasTexture materials load.

For every ``assets/visual/source/characters/{name}_atlas.svg`` (768x2048) we
produce, under ``assets/visual/atlases/``:

    {name}_diffuse.png    768x2048 RGBA   (rasterized SVG, transparent bg)
    {name}_normal.png     384x1024 RGB    flat (128,128,255)
    {name}_specular.png   192x512  L->RGB low grey (~40)

Rasterizer: Playwright Chromium.  The SVG is embedded in a minimal transparent
HTML page, the viewport is sized to the SVG, and ``omit_background=True`` keeps
the alpha channel.  cairosvg / resvg are tried as fallbacks if Playwright is
unavailable.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
SOURCE_CHAR = REPO / "assets" / "visual" / "source" / "characters"
ATLAS_DIR = REPO / "assets" / "visual" / "atlases"

NORMAL_SIZE = (384, 1024)
SPECULAR_SIZE = (192, 512)
FLAT_NORMAL = (128, 128, 255, 255)
SPECULAR_GREY = (40, 40, 40, 255)


def _svg_dimensions(svg_text: str) -> tuple[int, int]:
    w = re.search(r'<svg[^>]*\bwidth="(\d+)"', svg_text)
    h = re.search(r'<svg[^>]*\bheight="(\d+)"', svg_text)
    return (int(w.group(1)) if w else 768, int(h.group(1)) if h else 2048)


# ---------------------------------------------------------------------------
# Rasterizer backends.  Each returns RGBA bytes written to dest, or raises.
def _rasterize_playwright(svg_text: str, width: int, height: int, dest: Path) -> None:
    from playwright.sync_api import sync_playwright

    html = (
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<style>html,body{margin:0;padding:0;background:transparent;}"
        "svg{display:block;}</style></head><body>"
        f"{svg_text}</body></html>"
    )
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--force-color-profile=srgb"])
        page = browser.new_page(viewport={"width": width, "height": height},
                                device_scale_factor=1)
        page.set_content(html, wait_until="networkidle")
        page.screenshot(path=str(dest), omit_background=True, clip={
            "x": 0, "y": 0, "width": width, "height": height})
        browser.close()


def _rasterize_cairosvg(svg_text: str, width: int, height: int, dest: Path) -> None:
    import cairosvg
    cairosvg.svg2png(bytestring=svg_text.encode("utf-8"),
                     output_width=width, output_height=height,
                     write_to=str(dest), background_color="transparent")


def _rasterize_resvg(svg_text: str, width: int, height: int, dest: Path) -> None:
    import resvg_py
    png_bytes = resvg_py.svg_to_bytes(svg_string=svg_text)
    dest.write_bytes(png_bytes)


_BACKENDS = [
    ("playwright", _rasterize_playwright),
    ("cairosvg", _rasterize_cairosvg),
    ("resvg", _rasterize_resvg),
]


def pick_backend() -> tuple[str, callable]:
    errors = []
    for name, fn in _BACKENDS:
        try:
            if name == "playwright":
                from playwright.sync_api import sync_playwright  # noqa: F401
            elif name == "cairosvg":
                import cairosvg  # noqa: F401
            elif name == "resvg":
                import resvg_py  # noqa: F401
            return name, fn
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{name}: {exc}")
    raise RuntimeError("No SVG rasterizer available. Tried:\n  " + "\n  ".join(errors))


def rasterize_diffuse(svg_path: Path, dest: Path, backend_fn) -> tuple[int, int]:
    svg_text = svg_path.read_text(encoding="utf-8")
    width, height = _svg_dimensions(svg_text)
    dest.parent.mkdir(parents=True, exist_ok=True)
    backend_fn(svg_text, width, height, dest)
    # Normalize to a true RGBA PNG of the exact contract size.
    img = Image.open(dest).convert("RGBA")
    if img.size != (width, height):
        img = img.resize((width, height), Image.LANCZOS)
    img.save(dest)
    return img.size


def write_flat_maps(name: str) -> None:
    normal = Image.new("RGBA", NORMAL_SIZE, FLAT_NORMAL)
    normal.save(ATLAS_DIR / f"{name}_normal.png")
    specular = Image.new("RGBA", SPECULAR_SIZE, SPECULAR_GREY)
    specular.save(ATLAS_DIR / f"{name}_specular.png")


def main() -> int:
    parser = argparse.ArgumentParser(description="Rasterize Vampire City source SVG atlases to PNG.")
    parser.add_argument("--force", action="store_true", help="overwrite existing PNGs")
    parser.add_argument("--only", default="", help="comma list of names to rasterize (default all)")
    args = parser.parse_args()

    ATLAS_DIR.mkdir(parents=True, exist_ok=True)
    backend_name, backend_fn = pick_backend()
    print(f"Rasterizer backend: {backend_name}")

    svgs = sorted(SOURCE_CHAR.glob("*_atlas.svg"))
    if args.only:
        wanted = {s.strip() for s in args.only.split(",") if s.strip()}
        svgs = [s for s in svgs if s.stem.replace("_atlas", "") in wanted]

    if not svgs:
        print("No source atlases found.")
        return 1

    for svg in svgs:
        name = svg.stem.replace("_atlas", "")
        diffuse = ATLAS_DIR / f"{name}_diffuse.png"
        if diffuse.exists() and not args.force:
            print(f"  skip {name} (exists; use --force)")
        else:
            size = rasterize_diffuse(svg, diffuse, backend_fn)
            print(f"  {name}_diffuse.png {size[0]}x{size[1]} ({diffuse.stat().st_size:,} bytes)")
        write_flat_maps(name)
    print(f"Done. Atlases in {ATLAS_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
