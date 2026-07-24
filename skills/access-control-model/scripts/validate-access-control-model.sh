#!/bin/bash
# scripts/validate-access-control-model.sh — skill-owned script for
# skills/access-control-model.
# Purpose: mechanically check a design doc against the parts of this
#          skill's own completeness bar that are actually checkable by a
#          script -- required frontmatter, and that key tables have real
#          data rows, not just headers. Judgment (is this policy actually
#          correct, are the Domain Primitives well-chosen) stays with the
#          security-architect's own review.
# Usage:   validate-access-control-model.sh <path-to-design-doc.md>
# Output:  one PASS/FAIL line per check to stdout.
# Contract: plain CLI arg, not a hook's stdin-JSON contract -- advisory only.
#           Exit 0 if every check passes, 1 if any check fails, 2 on a
#           usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-access-control-model.sh <path-to-design-doc.md>" >&2
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

FRONTMATTER="$(sed -n '/^---$/,/^---$/p' "$FILE" | sed '1d;$d')"

for field in name product version phase created owner; do
  if printf '%s\n' "$FRONTMATTER" | grep -qE "^${field}:"; then
    _check "frontmatter has '$field'" 1
  else
    _check "frontmatter has '$field'" 0
  fi
done

# _table_has_data <section-heading>: extracts the lines between the given
# ## heading and the next ## heading (or EOF), and checks whether more than
# the header + separator rows are present -- i.e. the table has real data,
# not just column names and an empty separator line.
_table_has_data() {
  local heading="$1"
  local section
  section="$(awk -v h="$heading" '
    $0 == h { found=1; next }
    found && /^## / { exit }
    found { print }
  ' "$FILE")"
  local row_count
  row_count="$(printf '%s\n' "$section" | grep -cE '^\|')"
  [ "$row_count" -gt 2 ]
}

for section in "## Domain Primitives" "## Policies" "## Per-Aggregate Trust-Boundary Decisions"; do
  if _table_has_data "$section"; then
    _check "'$section' table has at least one data row" 1
  else
    _check "'$section' table has at least one data row" 0
  fi
done

echo "---"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "$FAIL_COUNT check(s) failed."
  exit 1
fi
