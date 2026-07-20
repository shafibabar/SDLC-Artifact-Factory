#!/bin/bash
# validate-artifact-structure.sh — PreToolUse hook, matcher: Write
# Purpose: block writing a product artifact (artifacts/<product>/...) that is
#          missing required frontmatter fields (name, version, phase, owner,
#          created), per CLAUDE.md's Artifact Standards.
# Contract: JSON on stdin (PreToolUse schema, includes tool_input.content —
#           the content about to be written). Exit 0 to allow, JSON with
#           hookSpecificOutput.permissionDecision:"deny" + reason to block.
# Scope: only applies to paths under artifacts/ — this repo's own skill and
#        agent files are not product artifacts and are exempt.
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
tool_input = payload.get("tool_input", {})
file_path = tool_input.get("file_path", "")
content = tool_input.get("content", "")

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

if "/artifacts/" not in file_path.replace("\\", "/"):
    allow()  # not a product artifact — not in scope

if not file_path.endswith(".md"):
    allow()

REQUIRED = ["name", "version", "phase", "owner", "created"]

m = re.match(r"^---\n(.*?)\n---\n", content, re.S)
if not m:
    deny(f"{file_path} has no frontmatter block (--- ... ---) at the top of the file.")

block = m.group(1)
missing = [f for f in REQUIRED if not re.search(rf"^{f}:", block, re.M)]
if missing:
    deny(f"{file_path} frontmatter is missing required field(s): {', '.join(missing)}.")

allow()
PYEOF
