#!/bin/bash
# scripts/validate-signoff.sh — skill-owned script for skills/acceptance-sign-off.
# Purpose: mechanically check a sign-off doc against the parts of this
#          skill's own rules that are actually checkable by a script --
#          structure, presence and the defect rule's hard edges, not the
#          go/no-go judgment, which stays with the named signatories.
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

# Print the body of the "## <heading>..." section (heading line excluded).
_section() {
  awk -v h="$1" '
    /^## / { p = (index($0, "## " h) == 1); next }
    p { print }
  ' "$FILE"
}

# Print the "- " lines under a bold "**<label>" block inside the Decision section.
_block() {
  _section "Decision:" | awk -v h="$1" '
    /^\*\*/ { p = (index($0, "**" h) == 1); next }
    p && /^[[:space:]]*- / { print }
  '
}

CONTENT="$(cat "$FILE")"

# 1. Checklist present and populated.
if printf '%s\n' "$CONTENT" | grep -qF '## Sign-Off Criteria Checklist'; then
  _check "Sign-Off Criteria Checklist section present" 1
else
  _check "Sign-Off Criteria Checklist section present" 0
fi

if _section "Sign-Off Criteria Checklist" | grep -qE '^\s*- \[[ xX]\]'; then
  _check "checklist has at least one item" 1
else
  _check "checklist has at least one item" 0
fi

# 2. Authority: two named parties, or a filled solo-operator Exception.
EXCEPTION="$(_section "Exception: solo operator")"
EXCEPTION_FILLED=0
if [ -n "$EXCEPTION" ] \
   && printf '%s\n' "$EXCEPTION" | grep -qE 'Independence level \(ISTQB\): *none' \
   && ! printf '%s\n' "$EXCEPTION" | grep -qF '['; then
  EXCEPTION_FILLED=1
fi

AUTHORITY="$(_section "Sign-Off Authority")"
PO_OK=0
if printf '%s\n' "$AUTHORITY" | grep -F '(product owner)' | grep -qvF '[Name]'; then
  PO_OK=1
fi
[ "$EXCEPTION_FILLED" = "1" ] && PO_OK=1
_check "product owner named as sign-off authority (not the unfilled placeholder)" "$PO_OK"

REP_OK=0
if printf '%s\n' "$AUTHORITY" | grep -F '(customer representative)' | grep -qvF '[Name, role, company]'; then
  REP_OK=1
fi
[ "$EXCEPTION_FILLED" = "1" ] && REP_OK=1
_check "customer representative named, or a filled solo-operator Exception (independence level none)" "$REP_OK"

# 3. Exactly one valid decision.
DECISION="$(printf '%s\n' "$CONTENT" | sed -nE 's/^## Decision: (FULL SIGN-OFF|CONDITIONAL SIGN-OFF|NO-GO)[[:space:]]*$/\1/p')"
if [ "$(printf '%s\n' "$DECISION" | grep -c .)" -eq 1 ]; then
  _check "Decision line names exactly one valid outcome" 1
else
  _check "Decision line names exactly one valid outcome" 0
fi

# 4. Defect rule, hard edge: no sign-off while the Critical line is unchecked.
CRITICAL_OK=1
if [ "$DECISION" = "FULL SIGN-OFF" ] || [ "$DECISION" = "CONDITIONAL SIGN-OFF" ]; then
  if _section "Sign-Off Criteria Checklist" | grep -qE '^\s*- \[ \] Zero open Critical'; then
    CRITICAL_OK=0
  fi
fi
_check "no full or conditional sign-off while open Critical defects remain unchecked" "$CRITICAL_OK"

# 5. Conditions: each has owner and target date; a High one names workaround and re-test.
COND_OK=1
HIGH_OK=1
if [ "$DECISION" = "CONDITIONAL SIGN-OFF" ]; then
  CONDITIONS="$(_block "Conditions")"
  if [ -z "$CONDITIONS" ]; then
    COND_OK=0
    HIGH_OK=0
  else
    while IFS= read -r line; do
      if ! printf '%s' "$line" | grep -qi 'owner:' \
         || ! printf '%s' "$line" | grep -qi 'target date:' \
         || printf '%s' "$line" | grep -qF '[...]'; then
        COND_OK=0
      fi
      if printf '%s' "$line" | grep -q 'High'; then
        if ! printf '%s' "$line" | grep -qi 'workaround:' || ! printf '%s' "$line" | grep -qi 're-test:'; then
          HIGH_OK=0
        fi
      fi
    done <<< "$CONDITIONS"
  fi
fi
_check "every condition names an owner and a target date (conditional only)" "$COND_OK"
_check "every High condition names a workaround and a re-test (conditional only)" "$HIGH_OK"

# 6. Residual risk and rollout action stated.
RESIDUAL="$(_section "Residual Risk" | grep -v '^\s*$')"
if [ -n "$RESIDUAL" ] && ! printf '%s\n' "$RESIDUAL" | grep -qF '[What is knowingly accepted'; then
  _check "Residual Risk is stated (not the unfilled placeholder)" 1
else
  _check "Residual Risk is stated (not the unfilled placeholder)" 0
fi

ROLLOUT="$(_section "Rollout Action" | grep -v '^\s*$')"
if [ -n "$ROLLOUT" ] && ! printf '%s\n' "$ROLLOUT" | grep -qF '[canary-deployment widen/hold/revert instruction'; then
  _check "Rollout Action is stated (not the unfilled placeholder)" 1
else
  _check "Rollout Action is stated (not the unfilled placeholder)" 0
fi

echo "---"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "$FAIL_COUNT check(s) failed."
  exit 1
fi
