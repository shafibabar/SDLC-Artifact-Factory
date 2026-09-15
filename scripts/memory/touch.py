#!/usr/bin/env python3
"""CLI: bump active_count/updated_at for a context (URI or id), mirroring
OpenViking's access-driven hotness (active_count incremented on retrieval).

Usage: touch.py <uri-or-id> [<uri-or-id> ...]
"""

from __future__ import annotations

import sys
from datetime import datetime, timezone

import store


def main(argv: list[str]) -> int:
    if not argv:
        print("usage: touch.py <uri-or-id> [...]", file=sys.stderr)
        return 2
    conn = store.connect()
    now_iso = datetime.now(timezone.utc).isoformat()
    for uri in argv:
        new_count = store.touch(conn, uri, now_iso)
        print(f"{uri}\tactive_count={new_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
