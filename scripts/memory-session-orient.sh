#!/bin/bash
# memory-session-orient.sh — SessionStart hook
# Purpose: surface a cheap, always-on orientation layer at the start of
#          every session -- level-0 abstracts only (a one-liner per node),
#          mirroring OpenViking's pre-seeded directory-level L0 vectors.
#          This is the "always available, negligible cost" half of
#          retrieval; the expensive drill-down (THINKING mode, rerank,
#          hotness) is agent-invoked via skills/memory-recall/SKILL.md,
#          matching how OpenViking-integrated agents call its MCP search
#          tool themselves rather than having every turn forced through it.
# Contract: JSON on stdin (SessionStart schema). Never blocks.
set -uo pipefail

INPUT="$(cat)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MEM="$PLUGIN_ROOT/scripts/memory"

python3 - "$INPUT" "$MEM" <<'PYEOF'
import json, os, sys

try:
    payload = json.loads(sys.argv[1])
except Exception:
    payload = {}
mem_dir = sys.argv[2]
cwd = payload.get("cwd") or "."

def done(extra=None):
    print(json.dumps(extra or {"continue": True}))
    sys.exit(0)

os.environ["SDLC_MEMORY_REPO_ROOT"] = cwd
sys.path.insert(0, mem_dir)

try:
    import store
    conn = store.connect()
    rows = conn.execute(
        "SELECT uri, abstract FROM contexts WHERE level = 0 AND is_leaf = 0 "
        "ORDER BY updated_at DESC LIMIT 20"
    ).fetchall()
except Exception:
    done()

if not rows:
    done()

lines = [f"- {r['uri']}: {r['abstract']}" for r in rows]
text = (
    "SDLC memory engine is active for this repo (.sdlc-memory/, no external service). "
    "Directory-level orientation (abstracts only):\n" + "\n".join(lines) +
    "\n\nBefore reading raw artifacts/research/skills for anything non-trivial, search first: "
    "python3 " + mem_dir + "/retrieve.py --mode thinking \"<query>\" "
    "(see skills/memory-recall). If this list looks empty or stale, run "
    "python3 " + mem_dir + "/ingest.py --all."
)
done({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": text}})
PYEOF
