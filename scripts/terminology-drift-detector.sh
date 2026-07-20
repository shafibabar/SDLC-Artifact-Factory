#!/bin/bash
# terminology-drift-detector.sh — PostToolUse hook, matcher: Write
# Purpose: warn (never block) when a written artifact uses a drifted form of
#          a canonical glossary term, per the Drift Quick Reference table in
#          skills/governance/glossary-management/SKILL.md.
# Contract: JSON on stdin (PostToolUse schema). Exit 0 = clean. Exit 1 =
#           non-blocking warning (message on stderr) — work is never stopped
#           for terminology; it's reported for a human/agent to fix.
# Scope: only artifacts/ paths — this repo's own skill content is not
#        re-checked here (the content-improvement campaign already covers it).
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

if "/artifacts/" not in file_path.replace("\\", "/"):
    sys.exit(0)

DRIFT_PATTERNS = [
    # Whole-phrase drift: wrong regardless of case (the phrase itself is wrong).
    (re.compile(r"\boutbox pattern\b", re.I), "Transactional Outbox"),
    (re.compile(r"\boutbox table pattern\b", re.I), "Transactional Outbox"),
    (re.compile(r"\bgiven-when-then\b", re.I), "Given/When/Then"),
    # Casing-only drift: only the lowercase form is wrong (adjectival lowercase
    # use is legitimate prose, e.g. "a least-privilege policy" — see the Drift
    # Quick Reference in glossary-management). Coarse and warning-only: this
    # script cannot reliably distinguish "naming the pattern" from adjectival
    # use, so it over-flags a little on purpose. The agent-type
    # methodology-compliance-check hook makes the authoritative, nuanced call.
    (re.compile(r"\bcircuit breaker\b"), "Circuit Breaker"),
    (re.compile(r"\bleast privilege\b(?! \()"), "Principle of Least Privilege"),
]

hits = []
for pattern, canonical in DRIFT_PATTERNS:
    for m in pattern.finditer(content):
        hits.append(f"'{m.group(0)}' found — canonical form is '{canonical}'")

if not hits:
    sys.exit(0)

sys.stderr.write(
    f"Terminology drift in {file_path}:\n" + "\n".join(f"  - {h}" for h in hits) +
    "\nThis does not block the write — fix before the artifact is reviewed.\n"
)
sys.exit(1)
PYEOF
