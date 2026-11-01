#!/bin/bash
# scripts/validate-beta-program-design.sh — skill-owned script for skills/beta-program-design.
# Purpose: mechanically check a beta program record against the structural
#          items of resources/beta-program-checklist.md -- a real Stage, filled
#          Participants, a Data Handling Statement that relaxes no control and
#          names the product's own frameworks (never a fixed framework list),
#          all four graduation dimensions filled, a valid Decision, and a
#          suspect hypothesis on a Pivot. Judgment calls (is this participant
#          an earlyvangelist, did the evidence come from outside the building)
#          stay with the requirements-analyst's own review.
# Usage:   validate-beta-program-design.sh <path-to-beta-program-doc.md>
# Output:  one PASS/FAIL line per check to stdout.
# Contract: plain CLI arg, not a hook's stdin-JSON contract -- advisory only.
#           Exit 0 if every check passes, 1 if any check fails, 2 on a
#           usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-beta-program-design.sh <path-to-beta-program-doc.md>" >&2
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

# Body of a "## <heading>" section, up to the next "## ".
_section() {
  awk -v h="## $1" '$0 == h {f=1; next} f && /^## / {exit} f' "$FILE"
}

# The text after "<prefix>" on the first matching line of a section.
_field() {
  _section "$1" | awk -v p="$2" 'index($0, p) == 1 {print substr($0, length(p) + 1); exit}'
}

# A field is filled when it has text and no unfilled "[...]" placeholder.
_filled() {
  [ -n "$(printf '%s' "$1" | tr -d '[:space:]')" ] && ! printf '%s' "$1" | grep -q '\['
}

# Stage: exactly one of the four values, not the placeholder listing all four.
STAGE="$(_section "Stage" | awk 'NF {print; exit}')"
printf '%s' "$STAGE" | grep -qE '^(Closed alpha|Closed beta|Open beta|GA)$'
_check "Stage is a real value, not the unfilled placeholder" "$([ $? -eq 0 ] && echo 1 || echo 0)"

# Participants: real content, neither the summary nor the table-row placeholder.
PARTICIPANTS="$(_section "Participants")"
if [ -n "$(printf '%s' "$PARTICIPANTS" | tr -d '[:space:]')" ] \
   && ! printf '%s' "$PARTICIPANTS" | grep -qF '[Names, companies' \
   && ! printf '%s' "$PARTICIPANTS" | grep -qF '[name, company]'; then
  _check "Participants section is filled in (not the unfilled placeholder)" 1
else
  _check "Participants section is filled in (not the unfilled placeholder)" 0
fi

# Data handling: the no-relaxation statement, and the product's own frameworks.
if _section "Data Handling Statement" | grep -q '^No control is relaxed'; then
  _check "Data Handling Statement says no control is relaxed for the beta" 1
else
  _check "Data Handling Statement says no control is relaxed for the beta" 0
fi
FRAMEWORKS="$(_field "Data Handling Statement" "- Frameworks:")"
TELEMETRY="$(_field "Data Handling Statement" "- Telemetry:")"
if _filled "$FRAMEWORKS" && _filled "$TELEMETRY"; then
  _check "Data Handling Statement names the product's own frameworks and its telemetry" 1
else
  _check "Data Handling Statement names the product's own frameworks and its telemetry" 0
fi

# Graduation: all four dimensions present and filled.
for DIM in "Quality" "Traction" "Behaviour and commitment" "Repeatability and operations"; do
  VALUE="$(_field "Graduation Criteria" "- $DIM:")"
  if _filled "$VALUE"; then
    _check "Graduation Criteria: $DIM dimension filled" 1
  else
    _check "Graduation Criteria: $DIM dimension filled" 0
  fi
done

# Decision: one valid value; a Pivot names its suspect hypothesis.
DECISION="$(_field "Graduation Record" "Decision: ")"
printf '%s' "$DECISION" | grep -qE '^(Pending|Advance|Extend|Remediate|Pivot)$'
_check "Graduation Record decision is Pending, Advance, Extend, Remediate or Pivot" "$([ $? -eq 0 ] && echo 1 || echo 0)"

HYPOTHESIS="$(_field "Graduation Record" "Suspect hypothesis: ")"
if [ "$DECISION" != "Pivot" ] \
   || { _filled "$HYPOTHESIS" && printf '%s' "$HYPOTHESIS" | grep -qiE '^(segment|problem|solution|process)'; }; then
  _check "a Pivot names its suspect hypothesis (segment, problem, solution or process)" 1
else
  _check "a Pivot names its suspect hypothesis (segment, problem, solution or process)" 0
fi

echo "---"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "$FAIL_COUNT check(s) failed."
  exit 1
fi
