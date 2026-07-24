#!/bin/bash
# scripts/validate-aggregate-design.sh — skill-owned script for
# skills/aggregate-design.
# Purpose: mechanically check an Aggregate design doc against the parts
#          of this skill's own completeness bar that are actually
#          checkable by a script -- required frontmatter, at least one
#          Aggregate with a real Root Entity and Invariant, and that the
#          Entities/Value Objects tables have data, not just headers.
#          Judgment (is the boundary actually correct, was the right
#          Decision Tree branch taken) stays with the domain-modeler's
#          own review.
# Usage:   validate-aggregate-design.sh <path-to-design-doc.md>
# Output:  one PASS/FAIL line per check to stdout.
# Contract: plain CLI arg, not a hook's stdin-JSON contract -- advisory only.
#           Exit 0 if every check passes, 1 if any check fails, 2 on a
#           usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-aggregate-design.sh <path-to-design-doc.md>" >&2
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
FRONTMATTER="$(sed -n '/^---$/,/^---$/p' "$FILE" | sed '1d;$d')"

for field in name product bounded-context version phase created owner; do
  if printf '%s\n' "$FRONTMATTER" | grep -qE "^${field}:"; then
    _check "frontmatter has '$field'" 1
  else
    _check "frontmatter has '$field'" 0
  fi
done

if printf '%s\n' "$CONTENT" | grep -qE '^## Aggregate: '; then
  _check "at least one '## Aggregate:' section present" 1
else
  _check "at least one '## Aggregate:' section present" 0
fi

if printf '%s\n' "$CONTENT" | grep -qE '^### Root Entity' && \
   ! printf '%s\n' "$CONTENT" | grep -A1 '^### Root Entity' | grep -qF '[Name and responsibility]'; then
  _check "Root Entity is named (not the unfilled placeholder)" 1
else
  _check "Root Entity is named (not the unfilled placeholder)" 0
fi

if printf '%s\n' "$CONTENT" | grep -qE '^### Invariants' && \
   ! printf '%s\n' "$CONTENT" | grep -A2 '^### Invariants' | grep -qF '[Rule that must always be true]'; then
  _check "at least one real Invariant stated (not the unfilled placeholder)" 1
else
  _check "at least one real Invariant stated (not the unfilled placeholder)" 0
fi

# _table_has_data <section-heading>: same technique as access-control-model's
# validator -- count '|'-leading lines in the section; more than 2 (header +
# separator) means real data rows exist.
_table_has_data() {
  local heading="$1"
  local section
  section="$(awk -v h="$heading" '
    $0 == h { found=1; next }
    found && /^### / { exit }
    found { print }
  ' "$FILE")"
  local row_count
  row_count="$(printf '%s\n' "$section" | grep -cE '^\|')"
  [ "$row_count" -gt 2 ]
}

for section in "### Entities" "### Value Objects"; do
  if _table_has_data "$section"; then
    _check "'$section' table has at least one data row" 1
  else
    _check "'$section' table has at least one data row" 0
  fi
done

# Cross-Aggregate Relationships: if the table has data rows, check the
# "Reference shape" column doesn't contain an obvious live-object-reference
# smell (a Go pointer sigil) -- a lightweight text-pattern check, not full
# parsing, per this sub-issue's own stated scope.
if _table_has_data "### Cross-Aggregate Relationships"; then
  if printf '%s\n' "$CONTENT" | awk '/^### Cross-Aggregate Relationships/{f=1;next} f&&/^### /{f=0} f' | grep -qE '\*[A-Z][a-zA-Z]*\b'; then
    _check "Cross-Aggregate Relationships reference by ID, not a Go pointer" 0
  else
    _check "Cross-Aggregate Relationships reference by ID, not a Go pointer" 1
  fi
else
  _check "Cross-Aggregate Relationships reference by ID, not a Go pointer" 1
fi

echo "---"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "$FAIL_COUNT check(s) failed."
  exit 1
fi
