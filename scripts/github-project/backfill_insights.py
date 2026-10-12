#!/usr/bin/env python3
"""Backfill the SKILL GEN Project's Insights fields on every board item (#1266).

Usage:
  backfill_insights.py            dry run: per-field distribution + pending write count
  backfill_insights.py --apply    write the values (batched, throttled, resumable)
  backfill_insights.py --only N   restrict writes to issue/PR number N (repeatable)

Values come from ghp/insights.derive_all(), which is the same rule set the
plan/exec tooling uses going forward. The run is idempotent: a value that
already matches is skipped. An item whose Data-Source is "Triaged" keeps its
Priority, Severity and Complexity, because a person set them on purpose.
"""

import argparse
import collections
import sys

from ghp import config, gh, project
from ghp.insights_sync import apply_writes, fetch_items, plan_writes


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--only", type=int, action="append")
    args = ap.parse_args()

    gh.check_auth()
    fields = project.ensure_insights_fields()
    nodes = fetch_items()
    derived, writes = plan_writes(nodes, set(args.only) if args.only else None)

    print(f"{len(nodes)} board items.\n")
    for field in list(config.INSIGHTS_SINGLE_SELECT) + [config.SPRINT_FIELD_NAME]:
        dist = collections.Counter(v[field] for v in derived.values())
        print(f"{field:13} " + "  ".join(f"{k}={n}" for k, n in sorted(dist.items(), key=lambda kv: -kv[1])))
    print(f"\n{len(writes)} field value(s) to write.")
    if not args.apply:
        print("Dry run. Re-run with --apply to write them.")
        return
    n = apply_writes(writes, fields, progress=True)
    print(f"Done: {n} value(s) written.")


if __name__ == "__main__":
    try:
        main()
    except gh.GhError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)
