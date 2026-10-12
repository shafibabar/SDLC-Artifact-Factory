#!/bin/bash
# memory-bootstrap.sh — PreToolUse hook, matcher: Agent
# Purpose: provision the SDLC memory engine (scripts/memory/) in whichever
#          repo this plugin is enabled in, before the first agent of a
#          session runs. Idempotent (scripts/memory/bootstrap.sh no-ops
#          once already provisioned) — only the very first invocation in a
#          fresh repo pays the one-time dependency-install cost.
# Contract: JSON on stdin (PreToolUse schema). Never blocks (always allows)
#           — a slow/failed install must never stop an agent from running.
set -uo pipefail

INPUT="$(cat)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

CWD="$(python3 -c '
import json, sys
try:
    print(json.loads(sys.argv[1]).get("cwd", "."))
except Exception:
    print(".")
' "$INPUT" 2>/dev/null || echo ".")"

# SDLC_MEMORY_BOOTSTRAP lets tests substitute a stub for the real (~220 MB) install.
BOOTSTRAP="${SDLC_MEMORY_BOOTSTRAP:-$PLUGIN_ROOT/scripts/memory/bootstrap.sh}"
OUT="$(bash "$BOOTSTRAP" "$CWD" 2>/dev/null || true)"

# bootstrap.sh prints "sdlc-memory: installed <size> into <dir>" only on the one
# run that actually installs, so the user is told exactly once per repo (#1258).
if [[ "$OUT" == *"sdlc-memory: installed"* ]]; then
  python3 -c '
import json, sys
line = next(l for l in sys.argv[1].splitlines() if "sdlc-memory: installed" in l)
size = line.split("installed", 1)[1].split("into", 1)[0].strip() or "about 220 MB"
print(json.dumps({"continue": True, "systemMessage": (
    "SDLC memory engine: installed local search libraries (" + size + ") into "
    ".sdlc-memory/.venv, once for this repo. It is git-ignored. To remove it: "
    "rm -rf .sdlc-memory/.venv. To skip it in a repo: create .sdlc-memory/.skip-install "
    "(keyword search is used instead).")}))
' "$OUT" 2>/dev/null || echo '{"continue": true}'
else
  echo '{"continue": true}'
fi
