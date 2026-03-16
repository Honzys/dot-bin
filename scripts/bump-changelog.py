#!/usr/bin/env python3
"""Bump CHANGELOG.md with package version changes.

Usage: bump-changelog.py <old-versions.json> <new-versions.json>

Reads CHANGELOG.md, bumps the patch version, inserts a new entry
describing the package changes, and writes the updated CHANGELOG.md.
Prints the new version to stdout. Exits with code 2 if no changes detected.
"""

import json
import re
import sys
from datetime import date


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <old-versions.json> <new-versions.json>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1]) as f:
        old = json.load(f)
    with open(sys.argv[2]) as f:
        new = json.load(f)

    added, updated, removed = [], [], []
    for key in sorted(set(list(old) + list(new))):
        old_v, new_v = old.get(key), new.get(key)
        if old_v is None and new_v is not None:
            added.append((key, new_v))
        elif old_v is not None and new_v is None:
            removed.append((key, old_v))
        elif old_v != new_v:
            updated.append((key, old_v, new_v))

    if not added and not updated and not removed:
        sys.exit(2)

    with open("CHANGELOG.md") as f:
        changelog = f.read()

    match = re.search(r"## \[(\d+)\.(\d+)\.(\d+)\]", changelog)
    if match:
        major, minor, patch = int(match.group(1)), int(match.group(2)), int(match.group(3))
        new_version = f"{major}.{minor}.{patch + 1}"
    else:
        new_version = "0.1.0"

    today = date.today().isoformat()
    lines = [f"## [{new_version}] - {today}", ""]

    if updated:
        lines += ["### Updated", ""]
        for name, old_v, new_v in updated:
            lines.append(f"- {name}: {old_v} \u2192 {new_v}")
        lines.append("")

    if added:
        lines += ["### Added", ""]
        for name, ver in added:
            lines.append(f"- {name} {ver}")
        lines.append("")

    if removed:
        lines += ["### Removed", ""]
        for name, ver in removed:
            lines.append(f"- ~~{name}~~ (was {ver})")
        lines.append("")

    entry = "\n".join(lines)

    # Insert before the first version entry
    insert_pos = changelog.find("\n## [")
    if insert_pos >= 0:
        new_changelog = changelog[:insert_pos] + "\n" + entry + changelog[insert_pos:]
    else:
        new_changelog = changelog.rstrip() + "\n\n" + entry

    with open("CHANGELOG.md", "w") as f:
        f.write(new_changelog)

    print(new_version)


if __name__ == "__main__":
    main()
