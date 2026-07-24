#!/bin/bash
# scripts/scaffold-aggregate-design.sh — skill-owned script for
# skills/aggregate-design.
# Purpose: generate a new Aggregate design doc from
#          assets/aggregate-design-template.md, pre-filled with product
#          and Bounded Context metadata.
# Usage:   scaffold-aggregate-design.sh <product> <bounded-context>
#   product          - directory name under artifacts/ (e.g. "data-estate-mapping")
#   bounded-context  - Bounded Context name (e.g. "Classification")
# Output:  writes artifacts/<product>/design/<bounded-context-slug>/aggregate-design.md
#          relative to the current working directory, and prints the path.
# Contract: plain CLI args, not a hook's stdin-JSON contract -- agent-invoked
#           action. Exit 0 on success, non-zero with a message on stderr on
#           failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$SKILL_DIR/assets/aggregate-design-template.md"

if [ $# -lt 2 ]; then
  echo "Usage: scaffold-aggregate-design.sh <product> <bounded-context>" >&2
  exit 1
fi

PRODUCT="$1"
BOUNDED_CONTEXT="$2"

if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found at $TEMPLATE" >&2
  exit 1
fi

SLUG="$(echo "$BOUNDED_CONTEXT" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"

OUT_DIR="artifacts/$PRODUCT/design/$SLUG"
mkdir -p "$OUT_DIR"

OUT="$OUT_DIR/aggregate-design.md"

if [ -f "$OUT" ]; then
  echo "error: $OUT already exists" >&2
  exit 1
fi

DATE="$(date +%Y-%m-%d)"

# Escape sed-special characters before using these as replacements.
ESCAPED_PRODUCT=$(printf '%s' "$PRODUCT" | sed -e 's/[\/&]/\\&/g')
ESCAPED_CONTEXT=$(printf '%s' "$BOUNDED_CONTEXT" | sed -e 's/[\/&]/\\&/g')

sed \
  -e "s/\[product name\]/$ESCAPED_PRODUCT/g" \
  -e "s/\[context name\]/$ESCAPED_CONTEXT/g" \
  -e "s/\[Bounded Context Name\]/$ESCAPED_CONTEXT/g" \
  -e "s/\[date\]/$DATE/g" \
  "$TEMPLATE" > "$OUT"

echo "$OUT"
