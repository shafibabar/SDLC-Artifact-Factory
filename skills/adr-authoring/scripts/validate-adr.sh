#!/bin/bash
# scripts/validate-adr.sh — skill-owned script for skills/adr-authoring.
# Purpose: mechanically check an ADR file against the parts of this skill's
#          Quality Criteria that are actually checkable by a script --
#          structure and presence, not judgment calls like "is the Context
#          neutral" or "is the Rationale honest," which remain the
#          enterprise-architect's own review.
# Usage:   validate-adr.sh <path-to-adr.md>
# Output:  one PASS/FAIL line per check to stdout.
# Contract: plain CLI arg, not a hook's stdin-JSON contract -- advisory only.
#           Exit 0 if every check passes, 1 if any check fails, 2 on a
#           usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-adr.sh <path-to-adr.md>" >&2
  exit 2
fi

FILE="$1"
FAIL_COUNT=0

if [ ! -f "$FILE" ]; then
  echo "error: file not found: $FILE" >&2
  exit 2
fi

_check() {
  local label="$1" ok="$2"
  if [ "$ok" = "1" ]; then
    echo "PASS: $label"
  else
    echo "FAIL: $label"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

CONTENT="$(cat "$FILE")"

# Frontmatter block: the first --- ... --- at the top of the file.
FRONTMATTER="$(printf '%s\n' "$CONTENT" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')"

for field in adr-id title status date deciders; do
  if printf '%s\n' "$FRONTMATTER" | grep -qE "^${field}:"; then
    _check "frontmatter has '$field'" 1
  else
    _check "frontmatter has '$field'" 0
  fi
done

if printf '%s\n' "$CONTENT" | grep -qE '^\*\*Trade-off:\*\*'; then
  _check "Rationale has a **Trade-off:** line" 1
else
  _check "Rationale has a **Trade-off:** line" 0
fi

for subsection in "### Positive" "### Negative / Trade-offs" "### Risks"; do
  if printf '%s\n' "$CONTENT" | grep -qF "$subsection"; then
    _check "Consequences has '$subsection'" 1
  else
    _check "Consequences has '$subsection'" 0
  fi
done

if printf '%s\n' "$CONTENT" | grep -qE '^## Related ADRs'; then
  _check "Related ADRs section present" 1
else
  _check "Related ADRs section present" 0
fi

echo "---"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "$FAIL_COUNT check(s) failed."
  exit 1
fi
