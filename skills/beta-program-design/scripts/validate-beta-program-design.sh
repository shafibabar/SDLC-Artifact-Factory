#!/bin/bash
# scripts/validate-beta-program-design.sh — skill-owned script for skills/beta-program-design.
# Purpose: mechanically check a beta program record against the parts of
#          this skill's Quality Criteria table that are actually checkable
#          by a script -- a real (non-placeholder) Stage value, a non-empty
#          Participants section, an unchanged SOC 2 CC6/CC7/A1 Data Handling
#          Statement, and both Graduation Criteria dimensions present.
#          Judgment calls (is this participant actually representative, is
#          the qualitative affirmation genuinely outside-the-building)
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

CONTENT="$(cat "$FILE")"

# Stage: must be exactly one of the four valid values, not the unfilled
# bracket placeholder listing all four as alternatives.
STAGE_LINE="$(printf '%s\n' "$CONTENT" | awk '/^## Stage$/{getline; print; exit}')"
if printf '%s' "$STAGE_LINE" | grep -qE '^(Closed alpha|Closed beta|Open beta|GA)$'; then
  _check "Stage is a real value, not the unfilled placeholder" 1
else
  _check "Stage is a real value, not the unfilled placeholder" 0
fi

# Participants: the section must have real content, not the unfilled
# bracket placeholder.
PARTICIPANTS_LINE="$(printf '%s\n' "$CONTENT" | awk '/^## Participants$/{getline; print; exit}')"
if printf '%s' "$PARTICIPANTS_LINE" | grep -qF '[Names, companies, ICP-fit rationale, named contact]'; then
  _check "Participants section is filled in (not the unfilled placeholder)" 0
elif [ -n "$(printf '%s' "$PARTICIPANTS_LINE" | tr -d '[:space:]')" ]; then
  _check "Participants section is filled in (not the unfilled placeholder)" 1
else
  _check "Participants section is filled in (not the unfilled placeholder)" 0
fi

# Data Handling Statement: must name all three unchanged SOC 2 control
# families this skill's Beta Agreement section treats as non-negotiable.
if printf '%s\n' "$CONTENT" | grep -q 'CC6' \
   && printf '%s\n' "$CONTENT" | grep -q 'CC7' \
   && printf '%s\n' "$CONTENT" | grep -q 'A1'; then
  _check "Data Handling Statement names the unchanged SOC 2 CC6/CC7/A1 posture" 1
else
  _check "Data Handling Statement names the unchanged SOC 2 CC6/CC7/A1 posture" 0
fi

# Graduation Criteria: both dimensions must be present as real sub-bullets,
# not just the section heading.
if printf '%s\n' "$CONTENT" | grep -qE '^- Quantitative:'; then
  _check "Graduation Criteria: Quantitative dimension present" 1
else
  _check "Graduation Criteria: Quantitative dimension present" 0
fi

if printf '%s\n' "$CONTENT" | grep -qE '^- Qualitative:'; then
  _check "Graduation Criteria: Qualitative dimension present" 1
else
  _check "Graduation Criteria: Qualitative dimension present" 0
fi

echo "---"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "$FAIL_COUNT check(s) failed."
  exit 1
fi
