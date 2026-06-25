#!/usr/bin/env python3
"""write_character_materials — emit one Godot 4 CanvasTexture .tres per archetype
so CharacterAtlas2D.gd's preloads resolve.

Each .tres references the diffuse / normal / specular PNGs under
res://assets/visual/atlases/.
"""
from __future__ import annotations

from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MAT_DIR = REPO / "assets" / "visual" / "materials" / "characters"

ARCHETYPES = [
    "hero", "thug", "gunner", "cop", "swat",
    "hunter", "elder", "thrall", "civilian", "rat",
]

TEMPLATE = '''[gd_resource type="CanvasTexture" load_steps=4 format=3]

[ext_resource type="Texture2D" path="res://assets/visual/atlases/{name}_diffuse.png" id="1"]
[ext_resource type="Texture2D" path="res://assets/visual/atlases/{name}_normal.png" id="2"]
[ext_resource type="Texture2D" path="res://assets/visual/atlases/{name}_specular.png" id="3"]

[resource]
diffuse_texture = ExtResource("1")
normal_texture = ExtResource("2")
specular_texture = ExtResource("3")
'''


def main() -> int:
    MAT_DIR.mkdir(parents=True, exist_ok=True)
    for name in ARCHETYPES:
        dest = MAT_DIR / f"{name}.tres"
        dest.write_text(TEMPLATE.format(name=name), encoding="utf-8")
        print(f"  {dest.relative_to(REPO)}")
    print(f"Wrote {len(ARCHETYPES)} CanvasTexture materials.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
