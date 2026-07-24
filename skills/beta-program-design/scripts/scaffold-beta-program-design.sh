#!/bin/bash
# scripts/scaffold-beta-program-design.sh — skill-owned script for skills/beta-program-design.
# Purpose: generate a new beta program record from
#          assets/beta-program-design-template.md, pre-filled with product
#          and release-slice metadata -- replaces hand-copying the template
#          and hand-typing the release slice into three separate places.
# Usage:   scaffold-beta-program-design.sh <product> <release-slice>
#   product       - directory name under artifacts/ (e.g. "data-estate-mapping")
#   release-slice - short name/description (e.g. "classification-pipeline")
# Output:  writes artifacts/<product>/customer-validation/beta-program/<slug>.md
#          relative to the current working directory, and prints the path.
# Contract: plain CLI args, not a hook's stdin-JSON contract -- agent-invoked
#           action. Exit 0 on success, non-zero with a message on stderr on
#           failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$SKILL_DIR/assets/beta-program-design-template.md"

if [ $# -lt 2 ]; then
  echo "Usage: scaffold-beta-program-design.sh <product> <release-slice>" >&2
  exit 1
fi

PRODUCT="$1"
RELEASE_SLICE="$2"

if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found at $TEMPLATE" >&2
  exit 1
fi

SLUG="$(echo "$RELEASE_SLICE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"

OUT_DIR="artifacts/$PRODUCT/customer-validation/beta-program"
mkdir -p "$OUT_DIR"

OUT="$OUT_DIR/$SLUG.md"

if [ -f "$OUT" ]; then
  echo "error: $OUT already exists" >&2
  exit 1
fi

DATE="$(date +%Y-%m-%d)"

# Escape sed-special characters before using these as replacements.
ESCAPED_SLICE=$(printf '%s' "$RELEASE_SLICE" | sed -e 's/[\/&]/\\&/g')
ESCAPED_PRODUCT=$(printf '%s' "$PRODUCT" | sed -e 's/[\/&]/\\&/g')

# The name: field's [product]/[release-slice] tokens are targeted separately
# from the body heading's "[product] [release-slice]" to avoid a naive
# global replace corrupting the space-joined heading form.
sed \
  -e "s/name: beta-program-\[product\]-\[release-slice\]/name: beta-program-$ESCAPED_PRODUCT-$SLUG/" \
  -e "s/product: \[product name\]/product: $ESCAPED_PRODUCT/" \
  -e "s/# Beta Program — \[product\] \[release-slice\]/# Beta Program — $ESCAPED_PRODUCT $ESCAPED_SLICE/" \
  -e "s/\[date\]/$DATE/g" \
  "$TEMPLATE" > "$OUT"

echo "$OUT"
