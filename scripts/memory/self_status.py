#!/usr/bin/env python3
"""Structured status reporting over sdlc://self/... nodes (this plugin's own
project memory, migrated out of sdlc-context.json by migrate_context.py).

Used by commands/sdlc-status.md and sdlc-next.md instead of instructing
Claude to Read the old monolithic sdlc-context.json build_checklist /
decisions / open_questions arrays in full -- this queries the structured
overview text directly (it already encodes status, per migrate_context.py's
`f"{abstract} -- {status}"` convention), which is exact and cheap, unlike a
semantic search (semantic search is for "what's relevant to X", not for
"what is literally the current state of Y").
"""

from __future__ import annotations

import argparse
import json
import re
import sys

import store


def build_checklist(conn) -> dict:
    rows = conn.execute(
        "SELECT uri, abstract, overview FROM contexts "
        "WHERE parent_uri = 'sdlc://self/build_checklist' AND level = 1 "
        "ORDER BY uri"
    ).fetchall()
    chunks = [{"uri": r["uri"], "title": r["abstract"], "status_line": r["overview"]} for r in rows]
    completed = [c for c in chunks if re.search(r"--\s*complete\b", c["status_line"], re.I)]
    incomplete = [c for c in chunks if c not in completed]
    return {
        "total_chunks": len(chunks),
        "last_completed": completed[-1] if completed else None,
        "first_incomplete": incomplete[0] if incomplete else None,
        "remaining": len(incomplete),
        "all_complete": not incomplete,
    }


def decisions(conn, limit: int) -> list:
    rows = conn.execute(
        "SELECT uri, abstract FROM contexts "
        "WHERE parent_uri = 'sdlc://self/decisions' AND level = 0 "
        "ORDER BY uri DESC LIMIT ?",
        (limit,),
    ).fetchall()
    return [{"uri": r["uri"], "decision": r["abstract"]} for r in rows]


def open_questions(conn, only_open: bool) -> list:
    rows = conn.execute(
        "SELECT uri, abstract, overview FROM contexts "
        "WHERE parent_uri = 'sdlc://self/open_questions' AND level = 1 "
        "ORDER BY uri"
    ).fetchall()
    out = []
    for r in rows:
        is_open = "resolved" not in r["overview"].lower()
        if only_open and not is_open:
            continue
        out.append({"uri": r["uri"], "question": r["abstract"], "status": r["overview"], "open": is_open})
    return out


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("build-checklist")
    dec = sub.add_parser("decisions")
    dec.add_argument("--limit", type=int, default=3)
    oq = sub.add_parser("open-questions")
    oq.add_argument("--only-open", action="store_true")
    args = parser.parse_args(argv)

    conn = store.connect()
    if args.cmd == "build-checklist":
        print(json.dumps(build_checklist(conn), indent=2))
    elif args.cmd == "decisions":
        print(json.dumps(decisions(conn, args.limit), indent=2))
    elif args.cmd == "open-questions":
        print(json.dumps(open_questions(conn, args.only_open), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
