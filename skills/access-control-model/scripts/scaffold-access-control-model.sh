#!/bin/bash
# scripts/scaffold-access-control-model.sh — skill-owned script for
# skills/access-control-model.
# Purpose: generate a new access control design doc from
#          assets/access-control-model-template.md, pre-filled with product
#          metadata -- replaces hand-copying the template.
# Usage:   scaffold-access-control-model.sh <product>
#   product - directory name under artifacts/ (e.g. "data-estate-mapping")
# Output:  writes artifacts/<product>/design/access-control-model.md
#          relative to the current working directory, and prints the path.
# Contract: plain CLI arg, not a hook's stdin-JSON contract -- agent-invoked
#           action. Exit 0 on success, non-zero with a message on stderr on
#           failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$SKILL_DIR/assets/access-control-model-template.md"

if [ $# -lt 1 ]; then
  echo "Usage: scaffold-access-control-model.sh <product>" >&2
  exit 1
fi

PRODUCT="$1"

if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found at $TEMPLATE" >&2
  exit 1
fi

OUT_DIR="artifacts/$PRODUCT/design"
mkdir -p "$OUT_DIR"

OUT="$OUT_DIR/access-control-model.md"

if [ -f "$OUT" ]; then
  echo "error: $OUT already exists" >&2
  exit 1
fi

DATE="$(date +%Y-%m-%d)"

# Escape sed-special characters in PRODUCT before using it as a replacement.
ESCAPED_PRODUCT=$(printf '%s' "$PRODUCT" | sed -e 's/[\/&]/\\&/g')

sed \
  -e "s/\[product name\]/$ESCAPED_PRODUCT/g" \
  -e "s/\[date\]/$DATE/g" \
  "$TEMPLATE" > "$OUT"

echo "$OUT"
