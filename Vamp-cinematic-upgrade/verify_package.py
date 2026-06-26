#!/usr/bin/env python3
"""Static integrity checks for the cinematic upgrade package."""

from __future__ import annotations

import ast
import json
import py_compile
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OVERLAY = ROOT / "overlay"

REQUIRED = {
    "src/present/EntityRenderer.gd": [
        "class_name EntityRenderer",
        "func _build_pose",
        "func _draw_actor",
        "func _draw_projectile",
        "current_action",
        "ActionDef",
    ],
    "src/present/WorldFX.gd": [
        "class_name WorldFX",
        "MAX_PARTICLES",
        '"projectile.explode"',
        "func _emit_embers",
    ],
    "src/entities/SimProjectile.gd": [
        "class_name SimProjectile",
        "var ballistic: bool",
        "var vertical_velocity: float",
        "var gravity: float",
        '"projectile.bounce"',
        "state_hash",
    ],
    "test/unit/test_ballistic_projectile.gd": [
        "test_ballistic_projectile_rises_bounces_and_explodes",
        "test_ballistic_explosion_applies_aoe_and_is_deterministic",
    ],
    "test/CaptureSlice.gd": [
        '"06_ballistic_arc"',
        '"07_ballistic_impact"',
        "Engine.get_frames_per_second()",
    ],
    ".github/workflows/visual-proof.yml": [
        "Run all GUT tests",
        "Capture live rendering under Xvfb",
    ],
    "docs/CINEMATIC_GRAPHICS_RESEARCH.md": [
        "Techniques evaluated",
        "Quality gates before merge",
    ],
}


def balanced_delimiters(text: str, path: Path) -> None:
    stack: list[tuple[str, int]] = []
    pairs = {"(": ")", "[": "]", "{": "}"}
    quote: str | None = None
    escaped = False
    in_comment = False
    for index, char in enumerate(text):
        if in_comment:
            if char == "\n":
                in_comment = False
            continue
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char == "#":
            in_comment = True
            continue
        if char in {'"', "'"}:
            quote = char
        elif char in pairs:
            stack.append((char, index))
        elif char in pairs.values():
            if not stack:
                raise AssertionError(f"{path}: extra closing delimiter {char} at byte {index}")
            opening, opening_index = stack.pop()
            if pairs[opening] != char:
                raise AssertionError(
                    f"{path}: {opening} at {opening_index} closes with {char} at {index}"
                )
    if quote:
        raise AssertionError(f"{path}: unterminated string")
    if stack:
        raise AssertionError(f"{path}: unclosed delimiters: {stack[-5:]}")


def check_gdscript(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    balanced_delimiters(text, path)
    if "\r" in text:
        raise AssertionError(f"{path}: CRLF detected; package should be normalized")
    if re.search(r"^ +func ", text, flags=re.MULTILINE):
        raise AssertionError(f"{path}: top-level function appears space-indented")
    for lineno, line in enumerate(text.splitlines(), 1):
        if line.rstrip() != line:
            raise AssertionError(f"{path}:{lineno}: trailing whitespace")
    # Authoritative code must not introduce nondeterministic random/time APIs.
    if path.name == "SimProjectile.gd":
        forbidden = ["randf(", "randi(", "Time.get_ticks", "RandomNumberGenerator.new"]
        for token in forbidden:
            if token in text:
                raise AssertionError(f"{path}: authoritative nondeterminism token {token}")
        hash_block = text[text.index("func state_hash"):text.index("func _hit")]
        for field in [
            "ballistic", "height", "vertical_velocity", "gravity", "bounces_remaining",
            "bounce_factor", "ground_friction", "fuse_ticks", "collision_height", "spin",
        ]:
            if field not in hash_block:
                raise AssertionError(f"{path}: ballistic field not hashed: {field}")


def main() -> int:
    failures: list[str] = []
    for rel, markers in REQUIRED.items():
        path = OVERLAY / rel
        if not path.is_file():
            failures.append(f"missing {rel}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for marker in markers:
            if marker not in text:
                failures.append(f"{rel}: missing marker {marker!r}")
        if path.suffix == ".gd":
            try:
                check_gdscript(path)
            except AssertionError as exc:
                failures.append(str(exc))

    for python_file in [ROOT / "install.py", ROOT / "uninstall.py", ROOT / "verify_package.py"]:
        try:
            py_compile.compile(str(python_file), doraise=True)
            ast.parse(python_file.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            failures.append(f"{python_file.name}: {exc}")

    try:
        manifest = json.loads((ROOT / "MANIFEST.json").read_text(encoding="utf-8"))
        if manifest.get("repository") != "coldshalamov/Vamp":
            failures.append("MANIFEST.json repository mismatch")
    except Exception as exc:  # noqa: BLE001
        failures.append(f"MANIFEST.json: {exc}")

    image_dir = OVERLAY / "docs/evidence"
    for image in ["rig_preview_v1.png", "rig_preview_v2.png", "rig_preview_comparison.png"]:
        path = image_dir / image
        if not path.is_file() or path.stat().st_size < 10_000:
            failures.append(f"missing or suspicious preview: {image}")

    if failures:
        print("PACKAGE VERIFICATION FAILED", file=sys.stderr)
        for failure in failures:
            print(f" - {failure}", file=sys.stderr)
        return 1

    gd_files = list(OVERLAY.rglob("*.gd"))
    total_lines = sum(len(path.read_text(encoding="utf-8").splitlines()) for path in gd_files)
    print(f"PACKAGE VERIFICATION PASSED: {len(gd_files)} GDScript files, {total_lines} GDScript lines")
    print("Note: this is static integrity verification, not a Godot parser/runtime execution.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
