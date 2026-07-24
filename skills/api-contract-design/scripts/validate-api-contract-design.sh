#!/bin/bash
# scripts/validate-api-contract-design.sh — skill-owned script for
# skills/api-contract-design.
# Purpose: mechanically check an API contract summary doc against the
#          parts of this skill's own completeness bar that are actually
#          checkable by a script -- required frontmatter, presence of all
#          three Output Format sections, and that the Endpoints table has
#          at least one real data row, not just the unfilled placeholder
#          row. Judgment (are the resources actually well-named, is a
#          custom method genuinely warranted) stays with the
#          enterprise-architect's own review.
# Usage:   validate-api-contract-design.sh <path-to-contract-summary.md>
# Output:  one PASS/FAIL line per check to stdout.
# Contract: plain CLI arg, not a hook's stdin-JSON contract -- advisory only.
#           Exit 0 if every check passes, 1 if any check fails, 2 on a
#           usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-api-contract-design.sh <path-to-contract-summary.md>" >&2
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

for field in name product service version phase created owner openapi-spec; do
  if printf '%s\n' "$FRONTMATTER" | grep -qE "^${field}:"; then
    _check "frontmatter has '$field'" 1
  else
    _check "frontmatter has '$field'" 0
  fi
done

for section in "## Endpoints" "## Breaking Change Log" "## Consumer Registry"; do
  if grep -qF "$section" "$FILE"; then
    _check "'$section' section present" 1
  else
    _check "'$section' section present" 0
  fi
done

# Endpoints table: real data means at least one row beyond header+separator,
# and that row must not still be the unfilled placeholder row.
ENDPOINTS_SECTION="$(awk '
  $0 == "## Endpoints" { found=1; next }
  found && /^## / { exit }
  found { print }
' "$FILE")"
ROW_COUNT="$(printf '%s\n' "$ENDPOINTS_SECTION" | grep -cE '^\|')"

if [ "$ROW_COUNT" -gt 2 ] && ! printf '%s\n' "$ENDPOINTS_SECTION" | grep -qF '[GET/POST/PUT/PATCH/DELETE]'; then
  _check "'## Endpoints' table has at least one real data row (not the unfilled placeholder)" 1
else
  _check "'## Endpoints' table has at least one real data row (not the unfilled placeholder)" 0
fi

echo "---"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "$FAIL_COUNT check(s) failed."
  exit 1
fi
