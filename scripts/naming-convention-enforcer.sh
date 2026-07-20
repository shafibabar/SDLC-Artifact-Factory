#!/bin/bash
# naming-convention-enforcer.sh — PreToolUse hook, matcher: Write
# Purpose: block creating a new component file whose name doesn't match
#          ^[a-z0-9]+(-[a-z0-9]+)*$ (CLAUDE.md's Naming Conventions).
# Contract: JSON on stdin (PreToolUse schema). Exit 0 to allow, JSON with
#           hookSpecificOutput.permissionDecision:"deny" + reason to block.
# Scope: skills/<name>/SKILL.md (flat — no domain nesting, fixed after live
#        testing confirmed domain-nested skills are not discoverable),
#        agents/<name>.md, commands/<name>.md, scripts/<name>.sh.
set -euo pipefail

INPUT="$(cat)"

python3 - "$INPUT" <<'PYEOF'
import json, re, sys

try:
    payload = json.loads(sys.argv[1])
except Exception:
    # Malformed/unexpected stdin — fail open, never crash a hook.
    print(json.dumps({"continue": True}))
    sys.exit(0)
file_path = payload.get("tool_input", {}).get("file_path", "").replace("\\", "/")

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

PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

# Extraction is deliberately permissive ([^/]+, not [a-z0-9-]+) — it must
# capture INVALID names too, so the strict PATTERN check below can catch them.
# A restrictive extraction regex would silently let bad names fall through
# as "not in scope" instead of being rejected (caught by live testing).
name = None
m = re.search(r"/skills/([^/]+)/SKILL\.md$", file_path)
if m:
    name = m.group(1)
else:
    m = re.search(r"/agents/([^/]+)\.md$", file_path)
    if m:
        name = m.group(1)
    else:
        m = re.search(r"/commands/([^/]+)\.md$", file_path)
        if m:
            name = m.group(1)
        else:
            m = re.search(r"/scripts/([^/]+)\.sh$", file_path)
            if m:
                name = m.group(1)

if name is None:
    allow()  # not a named component file — not in scope

if not PATTERN.match(name):
    deny(f"Component name '{name}' (from {file_path}) does not match ^[a-z0-9]+(-[a-z0-9]+)*$ — lowercase, hyphen-separated only.")

allow()
PYEOF
