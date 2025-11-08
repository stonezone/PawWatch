#!/usr/bin/env python3
"""Utility to bump the shared marketing/build version across all pawWatch targets."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION_FILE = ROOT / "Config" / "version.json"
PBXPROJ_FILE = ROOT / "pawWatch.xcodeproj" / "project.pbxproj"

MARKETING_PATTERN = re.compile(r"MARKETING_VERSION = [0-9.]+;")
BUILD_PATTERN = re.compile(r"CURRENT_PROJECT_VERSION = [0-9]+;")


def load_version() -> dict:
    if not VERSION_FILE.exists():
        raise SystemExit(f"Version file missing: {VERSION_FILE}")
    with VERSION_FILE.open() as handle:
        return json.load(handle)


def save_version(data: dict) -> None:
    with VERSION_FILE.open("w") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")


def update_pbxproj(marketing: str, build: int) -> None:
    if not PBXPROJ_FILE.exists():
        raise SystemExit(f"project.pbxproj missing: {PBXPROJ_FILE}")

    text = PBXPROJ_FILE.read_text()

    text, marketing_hits = MARKETING_PATTERN.subn(f"MARKETING_VERSION = {marketing};", text)
    text, build_hits = BUILD_PATTERN.subn(f"CURRENT_PROJECT_VERSION = {build};", text)

    if marketing_hits == 0:
        raise SystemExit("MARKETING_VERSION not found in project.pbxproj")
    if build_hits == 0:
        raise SystemExit("CURRENT_PROJECT_VERSION not found in project.pbxproj")

    PBXPROJ_FILE.write_text(text)


def parse_set_version(raw: str) -> tuple[int, int, int]:
    pieces = raw.split(".")
    if len(pieces) != 3:
        raise SystemExit("--set expects semantic version format: MAJOR.MINOR.PATCH")
    try:
        major, minor, patch = (int(part) for part in pieces)
    except ValueError as exc:  # pragma: no cover - defensive guard
        raise SystemExit(f"Invalid integer in version '{raw}': {exc}") from exc
    return major, minor, patch


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Bump pawWatch marketing/build version")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--set", metavar="MAJOR.MINOR.PATCH", help="Set explicit version")
    group.add_argument("--major", action="store_true", help="Increment the major version and reset minor/patch")
    group.add_argument("--minor", action="store_true", help="Increment the minor version and reset patch")
    group.add_argument("--patch", action="store_true", help="Increment only the patch version (default)")
    args = parser.parse_args(argv)

    data = load_version()
    major, minor, patch = data["major"], data["minor"], data["patch"]

    if args.set:
        major, minor, patch = parse_set_version(args.set)
    elif args.major:
        major += 1
        minor = 0
        patch = 0
    elif args.minor:
        minor += 1
        patch = 0
    else:
        patch += 1

    data.update({"major": major, "minor": minor, "patch": patch})

    marketing = f"{major}.{minor}.{patch}"
    build = max(patch, 1)

    save_version(data)
    update_pbxproj(marketing, build)

    print(f"Updated version to {marketing} (build {build})")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
