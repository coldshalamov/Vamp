#!/usr/bin/env python3
"""Restore a Vampire City checkout from a cinematic-upgrade backup receipt."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo", type=Path)
    parser.add_argument("backup", type=Path, nargs="?", help="Backup directory; defaults to receipt backup")
    args = parser.parse_args()

    repo = args.repo.resolve()
    receipt_path = repo / "cinematic_upgrade_receipt.json"
    if not receipt_path.is_file():
        raise SystemExit("cinematic_upgrade_receipt.json was not found")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    backup = args.backup.resolve() if args.backup else Path(receipt.get("backup") or "")
    if not backup.is_dir():
        raise SystemExit(f"backup directory was not found: {backup}")

    for rel in receipt.get("overwritten_files", []):
        source = backup / rel
        target = repo / rel
        if not source.is_file():
            raise SystemExit(f"backup file missing: {source}")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        print(f"restored {rel}")

    for rel in receipt.get("added_files", []):
        target = repo / rel
        if target.is_file():
            target.unlink()
            print(f"removed {rel}")

    receipt_path.unlink(missing_ok=True)
    print("Restore complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
