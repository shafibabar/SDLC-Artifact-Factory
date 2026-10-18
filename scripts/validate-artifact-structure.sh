#!/bin/bash
# validate-artifact-structure.sh — PreToolUse hook, matcher: Write|Edit
# Purpose: block writing or editing a product artifact (artifacts/<product>/...)
#          so that it lacks required frontmatter fields (name, version, phase,
#          owner, created, summary), per CLAUDE.md's Artifact Standards.
# Contract: JSON on stdin (PreToolUse schema). A Write carries the whole new
#           text in tool_input.content; an Edit carries old_string/new_string,
#           so the post-edit text is worked out from the file on disk (#1288).
#           Exit 0 to allow, JSON with
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

if payload.get("tool_name") == "Edit":
    # The text the file will have once the Edit is applied, exactly as the Edit
    # tool applies it. If old_string isn't there the Edit itself fails, so
    # there is nothing to check.
    try:
        with open(file_path, encoding="utf-8", errors="replace") as fh:
            current = fh.read()
    except OSError:
        allow()
    old, new = tool_input.get("old_string", ""), tool_input.get("new_string", "")
    if not old or old not in current:
        allow()
    content = current.replace(old, new) if tool_input.get("replace_all") else current.replace(old, new, 1)

REQUIRED = ["name", "version", "phase", "owner", "created", "summary"]
# "summary": one sentence (<= ~200 chars) stating what the artifact establishes.
# scripts/memory/ingest.py uses it verbatim as the artifact's L0 abstract in
# .sdlc-memory/ -- the line retrieval shows before anyone opens the artifact --
# so it is authored, not inferred from the body. Every skill's artifact
# template carries it (CLAUDE.md § Artifact Standards).

m = re.match(r"^---\n(.*?)\n---\n", content, re.S)
if not m:
    deny(f"{file_path} would have no frontmatter block (--- ... ---) at the top of the file.")

block = m.group(1)
missing = [f for f in REQUIRED if not re.search(rf"^{f}:", block, re.M)]
if missing:
    deny(f"{file_path} frontmatter would be missing required field(s): {', '.join(missing)}.")

allow()
PYEOF
