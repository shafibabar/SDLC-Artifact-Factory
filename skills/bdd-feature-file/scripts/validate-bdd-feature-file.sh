#!/bin/bash
# scripts/validate-bdd-feature-file.sh — skill-owned script for skills/bdd-feature-file.
# Purpose: mechanically check a .feature file against the parts of this
#          skill's Quality Criteria / Anti-Patterns that are actually
#          checkable by a script -- Golden Triangle tag presence, imperative/
#          HTTP-mechanics leakage in step text, and multiple-When-per-Scenario.
#          Judgment calls (is this Then actually observable, is the example
#          real-feeling) stay with the test-strategist's own review.
# Usage:   validate-bdd-feature-file.sh <path-to-feature-file>
# Output:  one PASS/FAIL line per check to stdout.
# Contract: plain CLI arg, not a hook's stdin-JSON contract -- advisory only.
#           Exit 0 if every check passes, 1 if any check fails, 2 on a
#           usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-bdd-feature-file.sh <path-to-feature-file>" >&2
  exit 2
fi

FILE="$1"
FAIL_COUNT=0

if [ ! -f "$FILE" ]; then
  echo "error: file not found: $FILE" >&2
  exit 2
fi

CONTENT="$(cat "$FILE")"

_check() {
  local label="$1" ok="$2"
  if [ "$ok" = "1" ]; then
    echo "PASS: $label"
  else
    echo "FAIL: $label"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# Golden Triangle: each of the three angle tags is present as a trailing
# comment on a Scenario line, per SKILL.md's own worked example convention
# ("Scenario: ... # happy").
for tag in "# happy" "# negative" "# edge"; do
  if printf '%s\n' "$CONTENT" | grep -qF "$tag"; then
    _check "Golden Triangle: '$tag' tag present" 1
  else
    _check "Golden Triangle: '$tag' tag present" 0
  fi
done

# Imperative/HTTP-mechanics leakage: step lines (Given/When/Then/And/But)
# should never name an HTTP verb or protocol detail -- that belongs in the
# step definition, not the spec (Anti-Patterns: "Imperative scripts in Gherkin").
STEP_LINES="$(printf '%s\n' "$CONTENT" | grep -E '^\s*(Given|When|Then|And|But)\b')"
if printf '%s\n' "$STEP_LINES" | grep -qiE '\b(PATCH|POST|GET|PUT|DELETE|http|https|endpoint|/v[0-9]+/)\b'; then
  _check "no imperative/HTTP-mechanics leakage in step text" 0
else
  _check "no imperative/HTTP-mechanics leakage in step text" 1
fi

# Multiple When steps in one Scenario: split the file into per-Scenario
# blocks (Scenario: or Scenario Outline: through the next such line, or EOF)
# and count leading "When" steps in each block independently.
# Note: gawk's \b inside a regex means a literal backspace character, not a
# word-boundary assertion (that's Perl/PCRE convention) -- using \b here
# would silently match nothing. Match "When" followed by whitespace instead,
# which is sufficient since it's always used as a line-leading step keyword.
MULTI_WHEN_FOUND=0
awk '
  /^[ \t]*Scenario( Outline)?:/ {
    if (block != "") {
      count = gsub(/\n[ \t]*When[ \t]/, "\n  When ", block)
      print count
    }
    block = ""
  }
  { block = block "\n" $0 }
  END {
    if (block != "") {
      count = gsub(/\n[ \t]*When[ \t]/, "\n  When ", block)
      print count
    }
  }
' <<<"$CONTENT" | grep -q '^[2-9][0-9]*$' && MULTI_WHEN_FOUND=1

if [ "$MULTI_WHEN_FOUND" = "1" ]; then
  _check "no Scenario with more than one When step" 0
else
  _check "no Scenario with more than one When step" 1
fi

echo "---"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "$FAIL_COUNT check(s) failed."
  exit 1
fi
