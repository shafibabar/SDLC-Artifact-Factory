#!/bin/bash
# scripts/scaffold-alerting-rules-design.sh — skill-owned script for
# skills/alerting-rules-design.
# Purpose: generate a new alerting rules design doc from
#          assets/alerting-rules-design-template.md, pre-filled with
#          product and date metadata -- replaces hand-copying the template.
# Usage:   scaffold-alerting-rules-design.sh <product>
#   product - directory name under artifacts/ (e.g. "data-estate-mapping")
# Output:  writes artifacts/<product>/deploy/alerting-rules-design.md
#          relative to the current working directory, and prints the path.
# Contract: plain CLI arg, not a hook's stdin-JSON contract -- agent-invoked
#           action. Exit 0 on success, non-zero with a message on stderr on
#           failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$SKILL_DIR/assets/alerting-rules-design-template.md"

if [ $# -lt 1 ]; then
  echo "Usage: scaffold-alerting-rules-design.sh <product>" >&2
  exit 1
fi

PRODUCT="$1"

if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found at $TEMPLATE" >&2
  exit 1
fi

OUT_DIR="artifacts/$PRODUCT/deploy"
mkdir -p "$OUT_DIR"

OUT="$OUT_DIR/alerting-rules-design.md"

if [ -f "$OUT" ]; then
  echo "error: $OUT already exists" >&2
  exit 1
fi

DATE="$(date +%Y-%m-%d)"

# Title-cased form for the '<Product>' placeholder in the H1 heading, e.g.
# "data-estate-mapping" -> "Data Estate Mapping".
PRODUCT_TITLE="$(echo "$PRODUCT" | tr '-' ' ' | sed -E 's/(^| )([a-z])/\1\U\2/g')"

# Escape sed-special characters before using these as replacements. Each
# placeholder below is a distinct bracketed token ('<product-name>' is not
# a substring match for '<product>' because of the trailing '>' boundary),
# so replacement order does not risk one substitution corrupting another.
ESCAPED_PRODUCT=$(printf '%s' "$PRODUCT" | sed -e 's/[\/&]/\\&/g')
ESCAPED_PRODUCT_TITLE=$(printf '%s' "$PRODUCT_TITLE" | sed -e 's/[\/&]/\\&/g')

sed \
  -e "s/<product-name>/$ESCAPED_PRODUCT/g" \
  -e "s/<product>/$ESCAPED_PRODUCT/g" \
  -e "s/<Product>/$ESCAPED_PRODUCT_TITLE/g" \
  -e "s/<date>/$DATE/g" \
  "$TEMPLATE" > "$OUT"

echo "$OUT"
