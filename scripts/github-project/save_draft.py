#!/usr/bin/env python3
"""save-draft <add|update|reject|list|clear> ...

Persists the in-conversation sub-issue draft table, one row at a time, keyed
by a stable draft id (d1, d2, ...) so that modifying or rejecting one row
never touches the others.

  save-draft add --title T --description D [--depends-on d1,d2] [--sequence 3.a]
  save-draft update <id> [--title T] [--description D] [--depends-on d1,d2] [--sequence 3.a]
  save-draft reject <id>
  save-draft list
  save-draft clear
"""
import argparse
import json
import re
import sys

from ghp import state

SEQUENCE_RE = re.compile(r"^\d+(\.[a-z])?$")


def _split_ids(raw):
    if raw is None:
        return None
    return [x.strip() for x in raw.split(",") if x.strip()]


def _warn_sequence(value):
    if value and not SEQUENCE_RE.match(value):
        print(
            f"warning: sequence \"{value}\" doesn't match the expected "
            f"dotted-letter notation (e.g. 1, 2, 3.a, 3.b) — saved as-is.",
            file=sys.stderr,
        )


def cmd_add(args, st):
    rows = st["draft"]["rows"]
    depends_on = _split_ids(args.depends_on) or []
    unknown = [d for d in depends_on if d not in rows]
    if unknown:
        print(f"error: unknown depends-on id(s): {', '.join(unknown)}", file=sys.stderr)
        sys.exit(1)
    _warn_sequence(args.sequence)

    row_id = f"d{st['draft']['next_id']}"
    st["draft"]["next_id"] += 1
    rows[row_id] = {
        "title": args.title,
        "description": args.description or "",
        "depends_on": depends_on,
        "sequence": args.sequence or "",
    }
    state.save(st)
    print(f"added {row_id}: {args.title}")


def cmd_update(args, st):
    rows = st["draft"]["rows"]
    if args.id not in rows:
        print(f"error: no draft row {args.id}", file=sys.stderr)
        sys.exit(1)
    row = rows[args.id]
    if args.title is not None:
        row["title"] = args.title
    if args.description is not None:
        row["description"] = args.description
    if args.depends_on is not None:
        depends_on = _split_ids(args.depends_on)
        unknown = [d for d in depends_on if d not in rows or d == args.id]
        if unknown:
            print(f"error: unknown/self depends-on id(s): {', '.join(unknown)}", file=sys.stderr)
            sys.exit(1)
        row["depends_on"] = depends_on
    if args.sequence is not None:
        _warn_sequence(args.sequence)
        row["sequence"] = args.sequence
    state.save(st)
    print(f"updated {args.id}")


def cmd_reject(args, st):
    rows = st["draft"]["rows"]
    if args.id not in rows:
        print(f"error: no draft row {args.id}", file=sys.stderr)
        sys.exit(1)
    del rows[args.id]
    for row in rows.values():
        row["depends_on"] = [d for d in row["depends_on"] if d != args.id]
    state.save(st)
    print(f"rejected {args.id} (removed, and stripped from other rows' dependencies)")


def cmd_list(args, st):
    rows = st["draft"]["rows"]
    if not rows:
        print("(draft is empty)")
        return
    print(json.dumps(rows, indent=2))


def cmd_clear(args, st):
    st["draft"] = {"next_id": 1, "rows": {}}
    state.save(st)
    print("draft cleared")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_add = sub.add_parser("add")
    p_add.add_argument("--title", required=True)
    p_add.add_argument("--description", default="")
    p_add.add_argument("--depends-on")
    p_add.add_argument("--sequence")
    p_add.set_defaults(func=cmd_add)

    p_update = sub.add_parser("update")
    p_update.add_argument("id")
    p_update.add_argument("--title")
    p_update.add_argument("--description")
    p_update.add_argument("--depends-on")
    p_update.add_argument("--sequence")
    p_update.set_defaults(func=cmd_update)

    p_reject = sub.add_parser("reject")
    p_reject.add_argument("id")
    p_reject.set_defaults(func=cmd_reject)

    p_list = sub.add_parser("list")
    p_list.set_defaults(func=cmd_list)

    p_clear = sub.add_parser("clear")
    p_clear.set_defaults(func=cmd_clear)

    args = parser.parse_args()
    st = state.load()
    args.func(args, st)


if __name__ == "__main__":
    main()
