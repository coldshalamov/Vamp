#!/usr/bin/env python3
"""Pixel-level acceptance gate for CaptureGraphicsPass.

No third-party packages are required. The decoder supports the non-interlaced, 8-bit
RGB/RGBA PNGs emitted by Godot's Image.save_png(). It rejects blank, near-monochrome,
low-detail, duplicate, incorrectly sized, or sub-30-FPS evidence.
"""

from __future__ import annotations

import hashlib
import json
import math
import struct
import sys
import zlib
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs" / "evidence" / "graphics_pass"
EXPECTED = [
    "graphics_01_lineup.png",
    "graphics_02_locomotion.png",
    "graphics_03_attack.png",
    "graphics_04_ballistics.png",
    "graphics_05_impacts.png",
    "graphics_06_stress.png",
]
EXPECTED_SIZE = (1280, 720)


@dataclass(frozen=True)
class ImageMetrics:
    width: int
    height: int
    file_bytes: int
    sampled_pixels: int
    unique_colors: int
    visible_ratio: float
    luma_stddev: float
    edge_energy: float
    sha256: str


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def _decode_png(path: Path) -> tuple[int, int, int, bytes]:
    blob = path.read_bytes()
    if not blob.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"{path.name}: invalid PNG signature")

    offset = 8
    width = height = bit_depth = color_type = interlace = -1
    compressed = bytearray()
    while offset < len(blob):
        if offset + 8 > len(blob):
            raise ValueError(f"{path.name}: truncated chunk header")
        length = struct.unpack(">I", blob[offset : offset + 4])[0]
        chunk_type = blob[offset + 4 : offset + 8]
        start = offset + 8
        end = start + length
        if end + 4 > len(blob):
            raise ValueError(f"{path.name}: truncated {chunk_type!r} chunk")
        data = blob[start:end]
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", data
            )
        elif chunk_type == b"IDAT":
            compressed.extend(data)
        elif chunk_type == b"IEND":
            break
        offset = end + 4

    if bit_depth != 8 or interlace != 0:
        raise ValueError(
            f"{path.name}: expected non-interlaced 8-bit PNG, got depth={bit_depth} "
            f"interlace={interlace}"
        )
    channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(color_type)
    if channels is None:
        raise ValueError(f"{path.name}: unsupported PNG color type {color_type}")

    packed = zlib.decompress(bytes(compressed))
    stride = width * channels
    expected = height * (stride + 1)
    if len(packed) != expected:
        raise ValueError(
            f"{path.name}: unexpected decompressed size {len(packed)} != {expected}"
        )

    raw = bytearray(height * stride)
    source = 0
    for y in range(height):
        filter_type = packed[source]
        source += 1
        row = bytearray(packed[source : source + stride])
        source += stride
        prior = raw[(y - 1) * stride : y * stride] if y else bytes(stride)
        for x in range(stride):
            left = row[x - channels] if x >= channels else 0
            up = prior[x]
            upper_left = prior[x - channels] if x >= channels else 0
            if filter_type == 1:
                row[x] = (row[x] + left) & 0xFF
            elif filter_type == 2:
                row[x] = (row[x] + up) & 0xFF
            elif filter_type == 3:
                row[x] = (row[x] + ((left + up) >> 1)) & 0xFF
            elif filter_type == 4:
                row[x] = (row[x] + _paeth(left, up, upper_left)) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"{path.name}: unsupported PNG filter {filter_type}")
        raw[y * stride : (y + 1) * stride] = row
    return width, height, channels, bytes(raw)


def _rgb_at(raw: bytes, channels: int, index: int) -> tuple[int, int, int]:
    base = index * channels
    if channels in (1, 2):
        value = raw[base]
        return value, value, value
    return raw[base], raw[base + 1], raw[base + 2]


def _metrics(path: Path) -> ImageMetrics:
    width, height, channels, raw = _decode_png(path)
    sample_step = 4
    colors: set[tuple[int, int, int]] = set()
    lumas: list[float] = []
    visible = 0
    edge_total = 0.0
    edge_count = 0

    for y in range(0, height, sample_step):
        for x in range(0, width, sample_step):
            index = y * width + x
            rgb = _rgb_at(raw, channels, index)
            colors.add((rgb[0] // 4, rgb[1] // 4, rgb[2] // 4))
            luma = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
            lumas.append(luma)
            if max(rgb) >= 18:
                visible += 1
            if x + sample_step < width:
                right = _rgb_at(raw, channels, index + sample_step)
                right_luma = 0.2126 * right[0] + 0.7152 * right[1] + 0.0722 * right[2]
                edge_total += abs(luma - right_luma)
                edge_count += 1
            if y + sample_step < height:
                down = _rgb_at(raw, channels, index + sample_step * width)
                down_luma = 0.2126 * down[0] + 0.7152 * down[1] + 0.0722 * down[2]
                edge_total += abs(luma - down_luma)
                edge_count += 1

    count = max(len(lumas), 1)
    mean = sum(lumas) / count
    variance = sum((value - mean) ** 2 for value in lumas) / count
    return ImageMetrics(
        width=width,
        height=height,
        file_bytes=path.stat().st_size,
        sampled_pixels=count,
        unique_colors=len(colors),
        visible_ratio=visible / count,
        luma_stddev=math.sqrt(variance),
        edge_energy=edge_total / max(edge_count, 1),
        sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
    )


def main() -> int:
    failures: list[str] = []
    report: dict[str, object] = {"images": {}}
    hashes: set[str] = set()

    for filename in EXPECTED:
        path = EVIDENCE / filename
        if not path.exists():
            failures.append(f"missing capture: {path}")
            continue
        try:
            metrics = _metrics(path)
        except Exception as exc:  # CI should print all malformed files, not only the first.
            failures.append(str(exc))
            continue
        report["images"][filename] = metrics.__dict__
        hashes.add(metrics.sha256)
        if (metrics.width, metrics.height) != EXPECTED_SIZE:
            failures.append(
                f"{filename}: size {(metrics.width, metrics.height)} != {EXPECTED_SIZE}"
            )
        if metrics.file_bytes < 35_000:
            failures.append(f"{filename}: suspiciously small ({metrics.file_bytes} bytes)")
        if metrics.unique_colors < 180:
            failures.append(
                f"{filename}: insufficient sampled color structure ({metrics.unique_colors})"
            )
        if metrics.visible_ratio < 0.12:
            failures.append(
                f"{filename}: mostly black/empty (visible ratio {metrics.visible_ratio:.3f})"
            )
        if metrics.luma_stddev < 9.0:
            failures.append(
                f"{filename}: near-flat luminance (stddev {metrics.luma_stddev:.2f})"
            )
        if metrics.edge_energy < 2.0:
            failures.append(
                f"{filename}: too little spatial detail (edge {metrics.edge_energy:.2f})"
            )

    if len(hashes) != len(EXPECTED):
        failures.append(
            f"captures are missing or duplicate: {len(hashes)} unique hashes for "
            f"{len(EXPECTED)} expected frames"
        )

    metrics_path = EVIDENCE / "graphics_metrics.json"
    if not metrics_path.exists():
        failures.append(f"missing performance evidence: {metrics_path}")
    else:
        runtime = json.loads(metrics_path.read_text(encoding="utf-8"))
        report["runtime"] = runtime
        average_fps = float(runtime.get("average_fps", 0.0))
        entity_count = int(runtime.get("entity_count", 0))
        if average_fps < 30.0:
            failures.append(f"stress capture averaged only {average_fps:.1f} FPS")
        if entity_count < 32:
            failures.append(f"stress capture exercised only {entity_count} entities")

    report["passed"] = not failures
    report["failures"] = failures
    report_path = EVIDENCE / "visual_acceptance_report.json"
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")

    for filename, values in report["images"].items():
        print(
            f"[VISUAL_GATE] {filename}: bytes={values['file_bytes']} "
            f"colors={values['unique_colors']} visible={values['visible_ratio']:.3f} "
            f"luma_std={values['luma_stddev']:.2f} edge={values['edge_energy']:.2f}"
        )
    if failures:
        for failure in failures:
            print(f"::error::{failure}")
        return 1
    print("[VISUAL_GATE] PASS — six distinct, nonblank, detailed frames and >=30 FPS stress evidence")
    return 0


if __name__ == "__main__":
    sys.exit(main())
