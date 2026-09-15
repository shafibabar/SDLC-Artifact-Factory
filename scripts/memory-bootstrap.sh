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

bash "$PLUGIN_ROOT/scripts/memory/bootstrap.sh" "$CWD" >/dev/null 2>&1 || true

echo '{"continue": true}'
