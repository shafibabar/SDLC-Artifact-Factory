#!/bin/bash
# scripts/scaffold-criteria.sh — skill-owned script for skills/acceptance-criteria.
# Purpose: generate a new acceptance-criteria doc from assets/acceptance-criteria-template.md,
#          pre-filled with story metadata -- replaces hand-copying the template
#          and hand-typing the story ID into three separate places.
# Usage:   scaffold-criteria.sh <product> <story-id> <story-title>
#   product     - directory name under artifacts/ (e.g. "data-estate-mapping")
#   story-id    - numeric or short ID (e.g. "042") -- becomes US-042
#   story-title - human-readable title (e.g. "Classify a newly connected file")
# Output:  writes artifacts/<product>/ideate/acceptance-criteria/US-<story-id>-<slug>.md
#          relative to the current working directory, and prints the path it wrote.
# Contract: plain CLI args, not a hook's stdin-JSON contract -- agent-invoked action.
#           Exit 0 on success, non-zero with a message on stderr on failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$SKILL_DIR/assets/acceptance-criteria-template.md"

if [ $# -lt 3 ]; then
  echo "Usage: scaffold-criteria.sh <product> <story-id> <story-title>" >&2
  exit 1
fi

PRODUCT="$1"
STORY_ID="$2"
TITLE="$3"

if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found at $TEMPLATE" >&2
  exit 1
fi

SLUG="$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"

OUT_DIR="artifacts/$PRODUCT/ideate/acceptance-criteria"
mkdir -p "$OUT_DIR"

OUT="$OUT_DIR/US-$STORY_ID-$SLUG.md"

if [ -f "$OUT" ]; then
  echo "error: $OUT already exists" >&2
  exit 1
fi

DATE="$(date +%Y-%m-%d)"

# Escape sed-special characters in TITLE before using it as a replacement.
ESCAPED_TITLE=$(printf '%s' "$TITLE" | sed -e 's/[\/&]/\\&/g')

sed \
  -e "s/US-\[ID\]/US-$STORY_ID/g" \
  -e "s/\[Story title\]/$ESCAPED_TITLE/g" \
  -e "s/\[date\]/$DATE/g" \
  "$TEMPLATE" > "$OUT"

echo "$OUT"
