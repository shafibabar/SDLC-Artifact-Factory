#!/bin/bash
# scripts/scaffold-analytics-requirements.sh — skill-owned script for
# skills/analytics-requirements.
# Purpose: generate a new analytics requirements doc from
#          assets/analytics-requirements-template.md, pre-filled with
#          product and date metadata -- replaces hand-copying the template.
# Usage:   scaffold-analytics-requirements.sh <product>
#   product - directory name under artifacts/ (e.g. "data-estate-mapping")
# Output:  writes artifacts/<product>/data/analytics-requirements.md
#          relative to the current working directory, and prints the path.
# Contract: plain CLI arg, not a hook's stdin-JSON contract -- agent-invoked
#           action. Exit 0 on success, non-zero with a message on stderr on
#           failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$SKILL_DIR/assets/analytics-requirements-template.md"

if [ $# -lt 1 ]; then
  echo "Usage: scaffold-analytics-requirements.sh <product>" >&2
  exit 1
fi

PRODUCT="$1"

if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found at $TEMPLATE" >&2
  exit 1
fi

OUT_DIR="artifacts/$PRODUCT/data"
mkdir -p "$OUT_DIR"

OUT="$OUT_DIR/analytics-requirements.md"

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
