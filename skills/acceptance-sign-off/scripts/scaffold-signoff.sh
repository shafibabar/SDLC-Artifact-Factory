#!/bin/bash
# scripts/scaffold-signoff.sh — skill-owned script for skills/acceptance-sign-off.
# Purpose: generate a new sign-off doc from assets/sign-off-template.md,
#          pre-filled with release-slice metadata and the full Sign-Off
#          Criteria Checklist copied in unchecked -- replaces hand-copying
#          the template and hand-transcribing the checklist items.
# Usage:   scaffold-signoff.sh <product> <release-slice>
#   product       - directory name under artifacts/ (e.g. "data-estate-mapping")
#   release-slice - short name/description (e.g. "2026-08 classification v2")
# Output:  writes artifacts/<product>/customer-validation/sign-off/<slug>.md
#          relative to the current working directory, and prints the path.
# Contract: plain CLI args, not a hook's stdin-JSON contract -- agent-invoked
#           action. Exit 0 on success, non-zero with a message on stderr on
#           failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$SKILL_DIR/assets/sign-off-template.md"

if [ $# -lt 2 ]; then
  echo "Usage: scaffold-signoff.sh <product> <release-slice>" >&2
  exit 1
fi

PRODUCT="$1"
RELEASE_SLICE="$2"

if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found at $TEMPLATE" >&2
  exit 1
fi

SLUG="$(echo "$RELEASE_SLICE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"

OUT_DIR="artifacts/$PRODUCT/customer-validation/sign-off"
mkdir -p "$OUT_DIR"

OUT="$OUT_DIR/$SLUG.md"

if [ -f "$OUT" ]; then
  echo "error: $OUT already exists" >&2
  exit 1
fi

DATE="$(date +%Y-%m-%d)"

# Escape sed-special characters before using these as replacements.
ESCAPED_SLICE=$(printf '%s' "$RELEASE_SLICE" | sed -e 's/[\/&]/\\&/g')
ESCAPED_SLUG=$(printf '%s' "$SLUG" | sed -e 's/[\/&]/\\&/g')

# The name: field gets the machine-friendly slug; the heading and the
# release-slice: field get the human-readable text as typed -- targeted by
# line context so they don't collide despite sharing the same [release-slice]
# placeholder token in the raw template.
sed \
  -e "s/^name: acceptance-sign-off-\[release-slice\]/name: acceptance-sign-off-$ESCAPED_SLUG/" \
  -e "s/\[release-slice\]/$ESCAPED_SLICE/g" \
  -e "s/\[name\/description\]/$ESCAPED_SLICE/g" \
  -e "s/\[date\]/$DATE/g" \
  "$TEMPLATE" > "$OUT"

echo "$OUT"
