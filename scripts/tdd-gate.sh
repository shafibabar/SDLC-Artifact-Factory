#!/bin/bash
# tdd-gate.sh — PreToolUse hook, matcher: Write
# Purpose: block writing a Go or TypeScript implementation file that has no
#          corresponding test file already on disk (TDD: tests first, always).
# Contract: JSON on stdin (PreToolUse schema). Exit 0 to allow, JSON with
#           hookSpecificOutput.permissionDecision:"deny" + reason to block.
# Applies to code the plugin generates for a product — this repo itself has
# no Go/TS implementation files, so this hook is inert against the factory's
# own content.
set -euo pipefail

INPUT="$(cat)"

python3 - "$INPUT" <<'PYEOF'
import json, os, re, sys

try:
    payload = json.loads(sys.argv[1])
except Exception:
    # Malformed/unexpected stdin — fail open, never crash a hook.
    print(json.dumps({"continue": True}))
    sys.exit(0)
file_path = payload.get("tool_input", {}).get("file_path", "")

def allow():
    print(json.dumps({"continue": True}))
    sys.exit(0)

def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)

norm = file_path.replace("\\", "/")

if norm.endswith("_test.go") or norm.endswith(".test.ts") or norm.endswith(".test.tsx") or norm.endswith(".spec.ts") or norm.endswith(".spec.tsx"):
    allow()  # this IS a test file

test_path = None
if norm.endswith(".go"):
    test_path = norm[:-len(".go")] + "_test.go"
elif norm.endswith(".ts"):
    test_path = norm[:-len(".ts")] + ".test.ts"
elif norm.endswith(".tsx"):
    test_path = norm[:-len(".tsx")] + ".test.tsx"

if test_path is None:
    allow()  # not a Go/TS implementation file — not in scope

if os.path.exists(test_path):
    allow()

deny(
    f"No test file found for {file_path} (expected {test_path} to already exist). "
    f"TDD is non-negotiable in this plugin: write the failing test first, then the "
    f"implementation. Create the test file before this one."
)
PYEOF
