#!/usr/bin/env python3
"""Generate markdown release notes by diffing old and new versions.json files."""

import json
import sys


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <old-versions.json> <new-versions.json>", file=sys.stderr)
        sys.exit(1)

    old_path, new_path = sys.argv[1], sys.argv[2]

    try:
        with open(old_path) as f:
            old = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        old = {}

    with open(new_path) as f:
        new = json.load(f)

    added = []
    updated = []
    removed = []

    all_keys = sorted(set(list(old.keys()) + list(new.keys())))
    for key in all_keys:
        old_ver = old.get(key)
        new_ver = new.get(key)
        if old_ver is None and new_ver is not None:
            added.append((key, new_ver))
        elif old_ver is not None and new_ver is None:
            removed.append((key, old_ver))
        elif old_ver != new_ver:
            updated.append((key, old_ver, new_ver))

    lines = ["## What changed\n"]

    if updated:
        lines.append("### Updated\n")
        lines.append("| Package | From | To |")
        lines.append("|---------|------|----|")
        for name, old_v, new_v in updated:
            lines.append(f"| {name} | {old_v} | {new_v} |")
        lines.append("")

    if added:
        lines.append("### Added\n")
        for name, ver in added:
            lines.append(f"- **{name}** {ver}")
        lines.append("")

    if removed:
        lines.append("### Removed\n")
        for name, ver in removed:
            lines.append(f"- ~~{name}~~ (was {ver})")
        lines.append("")

    if not updated and not added and not removed:
        lines.append("No package changes.\n")

    # Package summary table
    lines.append("### All packages\n")
    lines.append("| Package | Version |")
    lines.append("|---------|---------|")
    for key in sorted(new.keys()):
        lines.append(f"| {key} | {new[key]} |")

    print("\n".join(lines))


if __name__ == "__main__":
    main()
