#!/usr/bin/env python3
"""Create the SKILL GEN Project's Insights fields and Sprint iterations (#1266).

Usage: setup_insights_fields.py
Safe to re-run: missing fields are created, existing ones are left alone, and
the Sprint field is rewritten only if it differs from config.SPRINT_*.
"""

import sys

from ghp import gh, project


def main():
    gh.check_auth()
    fields = project.ensure_insights_fields()
    changed = project.ensure_sprints()
    fields = project.ensure_insights_fields()
    for name, f in fields.items():
        print(f"{name:14} {f['id']}  {len(f['options'])} option(s)")
    print("Sprint iterations " + ("rewritten." if changed else "already current."))


if __name__ == "__main__":
    try:
        main()
    except gh.GhError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)
