#!/bin/bash
# scripts/validate-signoff.sh — skill-owned script for skills/acceptance-sign-off.
# Purpose: mechanically check a sign-off doc against the parts of this
#          skill's own criteria that are actually checkable by a script --
#          structure and presence, not the actual go/no-go judgment, which
#          stays with the two named sign-off parties.
# Usage:   validate-signoff.sh <path-to-signoff.md>
# Output:  one PASS/FAIL line per check to stdout.
# Contract: plain CLI arg, not a hook's stdin-JSON contract -- advisory only.
#           Exit 0 if every check passes, 1 if any check fails, 2 on a
#           usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-signoff.sh <path-to-signoff.md>" >&2
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

if printf '%s\n' "$CONTENT" | grep -qF '## Sign-Off Criteria Checklist'; then
  _check "Sign-Off Criteria Checklist section present" 1
else
  _check "Sign-Off Criteria Checklist section present" 0
fi

if printf '%s\n' "$CONTENT" | grep -qE '^\s*- \[[ xX]\]'; then
  _check "checklist has at least one item" 1
else
  _check "checklist has at least one item" 0
fi

if printf '%s\n' "$CONTENT" | grep -qF 'Shafi (product owner)'; then
  _check "Shafi named as sign-off authority" 1
else
  _check "Shafi named as sign-off authority" 0
fi

if printf '%s\n' "$CONTENT" | grep -qF '[Name, role, company]'; then
  _check "customer/design-partner representative named (not the unfilled placeholder)" 0
else
  _check "customer/design-partner representative named (not the unfilled placeholder)" 1
fi

if printf '%s\n' "$CONTENT" | grep -qE '^## Decision: (FULL SIGN-OFF|CONDITIONAL SIGN-OFF|NO-GO)\s*$'; then
  _check "Decision line names exactly one valid outcome" 1
else
  _check "Decision line names exactly one valid outcome" 0
fi

if printf '%s\n' "$CONTENT" | grep -A1 '## Rollout Action' | grep -qF '[canary-deployment widen/hold/revert instruction; feature-flag-design scope change]'; then
  _check "Rollout Action is stated (not the unfilled placeholder)" 0
else
  if printf '%s\n' "$CONTENT" | grep -qF '## Rollout Action'; then
    _check "Rollout Action is stated (not the unfilled placeholder)" 1
  else
    _check "Rollout Action is stated (not the unfilled placeholder)" 0
  fi
fi

echo "---"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "$FAIL_COUNT check(s) failed."
  exit 1
fi
