#!/usr/bin/env bash
# validate-skill-structure.sh <path-to-SKILL.md>
#
# Checks a single SKILL.md against the skill-authoring-standards rubric:
#   1. Required frontmatter fields present in the canonical order
#   2. Body line count flagged if it exceeds the 200-line split threshold
#   3. Reference pointer integrity — bidirectional:
#      a. Every references/<file>.md mentioned in the body exists on disk
#      b. Every file in references/ is pointed to from the body
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed (details printed to stdout)
#
# Usage:
#   bash scripts/validate-skill-structure.sh skills/my-skill/SKILL.md

set -uo pipefail

SKILL_FILE="${1:-}"
if [[ -z "$SKILL_FILE" ]]; then
  echo "USAGE: validate-skill-structure.sh <path-to-SKILL.md>"
  exit 1
fi

if [[ ! -f "$SKILL_FILE" ]]; then
  echo "FAIL: file not found: $SKILL_FILE"
  exit 1
fi

SKILL_DIR="$(dirname "$SKILL_FILE")"
REFS_DIR="$SKILL_DIR/references"
ERRORS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; ERRORS=$((ERRORS + 1)); }

# ── 1. Required frontmatter fields ──────────────────────────────────────────
# Fields must appear in this exact order in the --- block.
REQUIRED_FIELDS=(name description version phase owner created tags)

# Extract frontmatter (between first and second ---)
frontmatter="$(awk '/^---$/{count++; if(count==2) exit; next} count==1{print}' "$SKILL_FILE")"

prev_line=0
for field in "${REQUIRED_FIELDS[@]}"; do
  line_num="$(echo "$frontmatter" | grep -n "^${field}:" | head -1 | cut -d: -f1)"
  if [[ -z "$line_num" ]]; then
    fail "frontmatter missing required field: $field"
  else
    if [[ "$line_num" -le "$prev_line" ]]; then
      fail "frontmatter field '$field' is out of canonical order (expected after line $prev_line, found at $line_num)"
    else
      pass "frontmatter field present in order: $field"
      prev_line="$line_num"
    fi
  fi
done

# ── 2. Body line count ───────────────────────────────────────────────────────
# Count lines after the closing --- of the frontmatter block.
body_start="$(awk '/^---$/{count++; if(count==2){print NR; exit}}' "$SKILL_FILE")"
total_lines="$(wc -l < "$SKILL_FILE")"
body_lines=$(( total_lines - body_start - 1 ))

if [[ "$body_lines" -gt 200 ]]; then
  fail "body is $body_lines lines (threshold 200) — apply the resident-content test; reference material may need to move to references/"
else
  pass "body line count: $body_lines (≤ 200)"
fi

# ── 3a. Body → disk: every references/<file> mentioned in body exists ────────
# Match patterns like: references/<something>.md
mentioned=()
while IFS= read -r ref; do
  mentioned+=("$ref")
done < <(grep -oE 'references/[a-z0-9_-]+\.md' "$SKILL_FILE" | sort -u)

if [[ "${#mentioned[@]}" -eq 0 ]]; then
  pass "no references/ files mentioned in body (nothing to check)"
else
  for ref in "${mentioned[@]}"; do
    target="$SKILL_DIR/$ref"
    if [[ -f "$target" ]]; then
      pass "referenced file exists: $ref"
    else
      fail "referenced file missing on disk: $ref (mentioned in body but does not exist)"
    fi
  done
fi

# ── 3b. Disk → body: every file in references/ is pointed to from body ───────
if [[ -d "$REFS_DIR" ]]; then
  while IFS= read -r -d '' ref_file; do
    basename_ref="$(basename "$ref_file")"
    if grep -q "references/${basename_ref}" "$SKILL_FILE"; then
      pass "references/$basename_ref is pointed to from body"
    else
      fail "references/$basename_ref exists on disk but body never mentions it (orphaned reference file)"
    fi
  done < <(find "$REFS_DIR" -maxdepth 1 -name '*.md' -print0 | sort -z)
else
  pass "no references/ directory (nothing to check)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [[ "$ERRORS" -eq 0 ]]; then
  echo "OK: all checks passed for $(basename "$SKILL_DIR")"
  exit 0
else
  echo "ERRORS: $ERRORS check(s) failed for $(basename "$SKILL_DIR")"
  exit 1
fi
