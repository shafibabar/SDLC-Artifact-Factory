#!/bin/bash
# scaffold-criteria.sh — skill-owned script for skills/acceptance-criteria.
# Purpose: start a story's acceptance-criteria file from the template, with the
#          product, story ID, title, date and example-map path filled in. It
#          refuses a story whose example map is missing or not ready.
# Usage:   scaffold-criteria.sh <product> <story-id> <story-title>
#            product     - directory name under artifacts/ (e.g. dropbay)
#            story-id    - US-9, or just 9
#            story-title - e.g. "Parcel held for a known time"
#          Run from the product repository root (the folder holding artifacts/).
# Output:  writes artifacts/<product>/ideate/acceptance-criteria/US-n.md and
#          prints that path. Fill it with Edit so the write checks run.
# Contract: plain CLI args, agent-invoked. Exit 0 written; 1 refused (no ready
#           map, file exists); 2 usage or environment error.
set -euo pipefail

usage() { echo "Usage: scaffold-criteria.sh <product> <story-id> <story-title>" >&2; exit 2; }

[ $# -eq 3 ] || usage
PRODUCT="$1"; STORY="$2"; TITLE="$3"
[[ "$PRODUCT" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "error: product '$PRODUCT' is not a directory name under artifacts/" >&2; usage; }
[[ "$STORY" =~ ^(US-)?[0-9]+[a-z]?$ ]] || { echo "error: story-id '$STORY' is not US-n" >&2; usage; }
STORY="US-${STORY#US-}"
[ -n "$TITLE" ] || usage

TEMPLATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates/acceptance-criteria.md"
[ -f "$TEMPLATE" ] || { echo "error: template not found at $TEMPLATE" >&2; exit 2; }

BASE="artifacts/$PRODUCT/ideate"
MAP="$BASE/example-maps/$STORY.md"
OUT="$BASE/acceptance-criteria/$STORY.md"

if [ ! -f "$MAP" ]; then
  echo "error: no example map at $MAP. Draw it first (example-mapping); criteria are never drafted without it." >&2
  exit 1
fi
if ! sed -n '/^---$/,/^---$/p' "$MAP" | grep -qE '^readiness:[[:space:]]*ready[[:space:]]*$'; then
  echo "error: $MAP is not ready. Get the product owner's answers to its open questions first." >&2
  exit 1
fi
if [ -e "$OUT" ]; then
  echo "error: $OUT already exists" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
python3 - "$TEMPLATE" "$OUT" "$PRODUCT" "$STORY" "$TITLE" "$(date +%Y-%m-%d)" <<'PYEOF'
import sys
template, out, product, story, title, today = sys.argv[1:]
text = open(template, encoding="utf-8").read()
for old, new in (("US-<n>", story), ("<product>", product), ("<yyyy-mm-dd>", today),
                 ("<Story title>", title)):
    text = text.replace(old, new)
open(out, "x", encoding="utf-8").write(text)
PYEOF
echo "$OUT"
