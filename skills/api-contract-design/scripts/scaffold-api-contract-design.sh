#!/bin/bash
# scripts/scaffold-api-contract-design.sh — skill-owned script for
# skills/api-contract-design.
# Purpose: generate a new API contract summary doc from
#          assets/api-contract-summary-template.md, pre-filled with
#          product, service, and date metadata -- replaces hand-copying
#          the template and hand-typing the service name into three
#          separate places.
# Usage:   scaffold-api-contract-design.sh <product> <service-name>
#   product      - directory name under artifacts/ (e.g. "data-estate-mapping")
#   service-name - human-readable service name (e.g. "Compliance Engine")
# Output:  writes artifacts/<product>/design/<service-slug>/api-contract-summary.md
#          relative to the current working directory, and prints the path.
# Contract: plain CLI args, not a hook's stdin-JSON contract -- agent-invoked
#           action. Exit 0 on success, non-zero with a message on stderr on
#           failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$SKILL_DIR/assets/api-contract-summary-template.md"

if [ $# -lt 2 ]; then
  echo "Usage: scaffold-api-contract-design.sh <product> <service-name>" >&2
  exit 1
fi

PRODUCT="$1"
SERVICE_NAME="$2"

if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found at $TEMPLATE" >&2
  exit 1
fi

SLUG="$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"

OUT_DIR="artifacts/$PRODUCT/design/$SLUG"
mkdir -p "$OUT_DIR"

OUT="$OUT_DIR/api-contract-summary.md"

if [ -f "$OUT" ]; then
  echo "error: $OUT already exists" >&2
  exit 1
fi

DATE="$(date +%Y-%m-%d)"

# Escape sed-special characters before using these as replacements. Each
# placeholder below is a distinct bracketed token -- '[service-name]' (the
# path-slug form) and '[Service Name]' (the human-readable form) are
# case-distinct literal strings, so replacement order does not risk one
# substitution corrupting another.
ESCAPED_PRODUCT=$(printf '%s' "$PRODUCT" | sed -e 's/[\/&]/\\&/g')
ESCAPED_SLUG=$(printf '%s' "$SLUG" | sed -e 's/[\/&]/\\&/g')
ESCAPED_SERVICE_NAME=$(printf '%s' "$SERVICE_NAME" | sed -e 's/[\/&]/\\&/g')

sed \
  -e "s/\[product name\]/$ESCAPED_PRODUCT/g" \
  -e "s/\[product\]/$ESCAPED_PRODUCT/g" \
  -e "s/\[service-name\]/$ESCAPED_SLUG/g" \
  -e "s/\[service name\]/$ESCAPED_SERVICE_NAME/g" \
  -e "s/\[Service Name\]/$ESCAPED_SERVICE_NAME/g" \
  -e "s/\[date\]/$DATE/g" \
  "$TEMPLATE" > "$OUT"

echo "$OUT"
