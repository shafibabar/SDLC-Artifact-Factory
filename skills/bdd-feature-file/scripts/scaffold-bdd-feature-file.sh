#!/bin/bash
# scripts/scaffold-bdd-feature-file.sh — skill-owned script for skills/bdd-feature-file.
# Purpose: generate a new .feature file from assets/bdd-feature-file-template.feature,
#          pre-filled with the feature title and its comment-header path -- the
#          Given/When/Then bodies and the Background/Examples table stay as
#          bracket placeholders for the Specification Workshop to fill in.
# Usage:   scaffold-bdd-feature-file.sh <feature-title>
#   feature-title - human-readable title (e.g. "Classify a data asset")
# Output:  writes features/<slug>.feature relative to the current working
#          directory, and prints the path it wrote.
# Contract: plain CLI arg, not a hook's stdin-JSON contract -- agent-invoked action.
#           Exit 0 on success, non-zero with a message on stderr on failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$SKILL_DIR/assets/bdd-feature-file-template.feature"

if [ $# -lt 1 ]; then
  echo "Usage: scaffold-bdd-feature-file.sh <feature-title>" >&2
  exit 1
fi

TITLE="$1"

if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found at $TEMPLATE" >&2
  exit 1
fi

SLUG="$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g')"

OUT_DIR="features"
mkdir -p "$OUT_DIR"

OUT="$OUT_DIR/$SLUG.feature"

if [ -f "$OUT" ]; then
  echo "error: $OUT already exists" >&2
  exit 1
fi

# Escape sed-special characters in TITLE before using it as a replacement.
ESCAPED_TITLE=$(printf '%s' "$TITLE" | sed -e 's/[\/&]/\\&/g')

sed \
  -e "s/\[feature-slug\]/$SLUG/g" \
  -e "s/\[Feature Title\]/$ESCAPED_TITLE/g" \
  "$TEMPLATE" > "$OUT"

echo "$OUT"
