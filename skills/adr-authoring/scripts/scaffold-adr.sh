#!/bin/bash
# scripts/scaffold-adr.sh — skill-owned script for skills/adr-authoring.
# Purpose: generate a new ADR file from assets/adr-template.md, resolving
#          the next ADR-NNN automatically by scanning existing files —
#          replaces hand-copying the template and hand-counting numbers,
#          which is exactly the kind of collision two concurrent decisions
#          can silently produce.
# Usage:   scaffold-adr.sh <product> <slug> [title]
#   product - directory name under artifacts/ (e.g. "data-estate-mapping")
#   slug    - kebab-case filename slug (e.g. "use-transactional-outbox")
#   title   - optional human-readable title; defaults to the slug, Title Cased
# Output:  writes artifacts/<product>/design/decisions/ADR-<NNN>-<slug>.md
#          relative to the current working directory (the repo root, when
#          invoked normally), and prints the path it wrote to stdout.
# Contract: plain CLI args, not a hook's stdin-JSON contract — this is an
#           agent-invoked action, not a hook handler. Exit 0 on success,
#           non-zero with a message on stderr on any failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$SKILL_DIR/assets/adr-template.md"

if [ $# -lt 2 ]; then
  echo "Usage: scaffold-adr.sh <product> <slug> [title]" >&2
  exit 1
fi

PRODUCT="$1"
SLUG="$2"
TITLE="${3:-}"

if [ -z "$TITLE" ]; then
  TITLE="$(echo "$SLUG" | sed -E 's/(^|-)([a-z])/\1\U\2/g; s/-/ /g')"
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found at $TEMPLATE" >&2
  exit 1
fi

DECISIONS_DIR="artifacts/$PRODUCT/design/decisions"
mkdir -p "$DECISIONS_DIR"

# Resolve next ADR-NNN by scanning existing files; default to 001 if none.
# `10#$LAST` forces base-10 arithmetic — without it, numbers like 008/009
# are misread as invalid octal literals by bash's arithmetic expansion.
LAST=$(find "$DECISIONS_DIR" -maxdepth 1 -name 'ADR-*.md' -print 2>/dev/null \
  | sed -E 's#.*/ADR-([0-9]+)-.*#\1#' \
  | sort -n | tail -1)
if [ -z "${LAST:-}" ]; then
  NEXT="001"
else
  NEXT=$(printf "%03d" $((10#$LAST + 1)))
fi

DATE="$(date +%Y-%m-%d)"
OUT="$DECISIONS_DIR/ADR-$NEXT-$SLUG.md"

if [ -f "$OUT" ]; then
  echo "error: $OUT already exists" >&2
  exit 1
fi

# Escape sed-special characters in TITLE before using it as a replacement.
ESCAPED_TITLE=$(printf '%s' "$TITLE" | sed -e 's/[\/&]/\\&/g')

sed \
  -e "s/\[NNN\]/$NEXT/g" \
  -e "s/\[Title\]/$ESCAPED_TITLE/g" \
  -e "s/\[YYYY-MM-DD\]/$DATE/g" \
  "$TEMPLATE" > "$OUT"

echo "$OUT"
