#!/usr/bin/env python3
"""Safely install the Vampire City cinematic graphics overlay."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import subprocess
import sys
from pathlib import Path

PACKAGE_ROOT = Path(__file__).resolve().parent
OVERLAY_ROOT = PACKAGE_ROOT / "overlay"

FINGERPRINTS: dict[str, tuple[str, ...]] = {
    "src/present/EntityRenderer.gd": ("class_name EntityRenderer", "func setup(entities"),
    "src/present/WorldFX.gd": ("class_name WorldFX", "func _on_cue"),
    "src/entities/SimProjectile.gd": ("class_name SimProjectile", "static func configure"),
    "test/CaptureSlice.gd": ("const GameViewScene", "func _shot"),
}


def run_git(repo: Path, args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def validate_repo(repo: Path, force: bool) -> list[str]:
    problems: list[str] = []
    if not (repo / "project.godot").is_file():
        problems.append("project.godot was not found")
    project_text = (repo / "project.godot").read_text(encoding="utf-8", errors="replace") if (repo / "project.godot").is_file() else ""
    if "Vampire City" not in project_text and "config/name=\"Vampire City\"" not in project_text:
        problems.append("project.godot does not appear to be Vampire City")

    for rel, markers in FINGERPRINTS.items():
        target = repo / rel
        if not target.is_file():
            problems.append(f"expected existing file is missing: {rel}")
            continue
        text = target.read_text(encoding="utf-8", errors="replace")
        missing = [marker for marker in markers if marker not in text]
        if missing:
            problems.append(f"{rel} does not match the expected interface; missing {missing}")

    if problems and not force:
        joined = "\n  - ".join(problems)
        raise RuntimeError(f"Repository validation failed:\n  - {joined}\nUse --force only after reviewing the differences.")
    return problems


def create_branch(repo: Path, branch: str, force: bool) -> None:
    if not (repo / ".git").exists():
        if force:
            print("warning: --git-branch ignored because the target is not a Git checkout", file=sys.stderr)
            return
        raise RuntimeError("--git-branch requested, but the target has no .git directory")

    status = run_git(repo, ["status", "--porcelain"]).stdout.strip()
    if status and not force:
        raise RuntimeError("Git working tree is not clean. Commit/stash changes or use --force after review.")

    existing = run_git(repo, ["branch", "--list", branch], check=False).stdout.strip()
    if existing:
        current = run_git(repo, ["branch", "--show-current"], check=False).stdout.strip()
        if current != branch:
            run_git(repo, ["checkout", branch])
        print(f"Using existing branch {branch}")
    else:
        run_git(repo, ["checkout", "-b", branch])
        print(f"Created branch {branch}")


def iter_overlay_files() -> list[Path]:
    return sorted(path for path in OVERLAY_ROOT.rglob("*") if path.is_file())


def install(repo: Path, args: argparse.Namespace) -> Path:
    repo = repo.resolve()
    warnings = validate_repo(repo, args.force)
    if args.git_branch:
        create_branch(repo, args.git_branch, args.force)

    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_root = repo / ".cinematic_upgrade_backup" / stamp
    files = iter_overlay_files()
    overwritten: list[str] = []
    added: list[str] = []

    print(f"Target: {repo}")
    print(f"Overlay files: {len(files)}")
    if args.dry_run:
        for source in files:
            rel = source.relative_to(OVERLAY_ROOT)
            state = "replace" if (repo / rel).exists() else "add"
            print(f"  {state:7} {rel.as_posix()}")
        return backup_root

    for source in files:
        rel = source.relative_to(OVERLAY_ROOT)
        target = repo / rel
        rel_text = rel.as_posix()
        if target.exists():
            overwritten.append(rel_text)
            if not args.no_backup:
                backup = backup_root / rel
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(target, backup)
        else:
            added.append(rel_text)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        print(f"  installed {rel_text}")

    receipt = {
        "package": "Vampire City cinematic graphics upgrade",
        "installed_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "repository": str(repo),
        "backup": None if args.no_backup else str(backup_root),
        "overwritten_files": overwritten,
        "added_files": added,
        "validation_warnings": warnings,
    }
    if not args.no_backup:
        backup_root.mkdir(parents=True, exist_ok=True)
        (backup_root / "receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    (repo / "cinematic_upgrade_receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")

    print("\nInstalled successfully.")
    if not args.no_backup:
        print(f"Backup: {backup_root}")
    print("Next:")
    print("  1. Run a clean Godot import.")
    print("  2. Run the full GUT suite.")
    print("  3. Run res://test/CaptureSlice.tscn windowed and inspect docs/evidence/.")
    return backup_root


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo", type=Path, help="Path to the coldshalamov/Vamp checkout")
    parser.add_argument("--git-branch", metavar="NAME", help="Create or checkout this branch before copying")
    parser.add_argument("--force", action="store_true", help="Proceed despite interface or dirty-tree warnings")
    parser.add_argument("--no-backup", action="store_true", help="Do not create a timestamped backup")
    parser.add_argument("--dry-run", action="store_true", help="Show the copy plan without changing files")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        install(args.repo, args)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        if isinstance(exc, subprocess.CalledProcessError) and exc.stderr:
            print(exc.stderr.strip(), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
