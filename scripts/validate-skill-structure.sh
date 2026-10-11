#!/usr/bin/env bash
# validate-skill-structure.sh <path-to-SKILL.md>
#
# Checks a single SKILL.md against the skill-authoring-standards rubric:
#   1. Required frontmatter fields present in the canonical order
#   2. Body line count flagged if it exceeds the 200-line split threshold
#   3. Pointer integrity — bidirectional, across every spec folder:
#      a. Every <folder>/<file> the body mentions exists on disk
#         (folder = references|resources|templates|examples|steps|scripts|assets)
#      b. The folder spec itself — delegated to scripts/lint-skill-layout.py, the
#         single definition of the layout rules: entry file, allowed folders,
#         no empty dirs, every file reachable from SKILL.md (transitively), and
#         no hard-coded pointers to skill content.
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

# ── 3a. Body → disk: every <folder>/<file> mentioned in the body exists ─────
# Which mentions count as pointers INTO this skill:
#   * anything written skill-relative with ./ — `./templates/plan.md`,
#     `./scripts/score.sh` — the convention skill-authoring-standards requires;
#   * a bare `references/...` — the legacy form, never ambiguous.
# A bare templates/, scripts/, assets/ … is NOT checked: in a skill body it may
# equally name a PRODUCT path (a Helm chart's templates/rollout.yaml) or the
# plugin's repo-root scripts/ (lint-manifests.py), which do not live in the skill.
FOLDERS='references|resources|templates|examples|steps|scripts|assets'
mentioned=()
while IFS= read -r ref; do
  mentioned+=("$ref")
done < <( { grep -oE "\./($FOLDERS)/[A-Za-z0-9_./-]*[A-Za-z0-9_-]\.[A-Za-z0-9]+" "$SKILL_FILE";
            grep -oE "(^|[^A-Za-z0-9_./-])references/[A-Za-z0-9_./-]*[A-Za-z0-9_-]\.[A-Za-z0-9]+" "$SKILL_FILE" \
              | sed -E 's#^[^r]##'; } \
          | sed 's#^\./##' | sort -u)

if [[ "${#mentioned[@]}" -eq 0 ]]; then
  pass "no folder files mentioned in body (nothing to check)"
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

# ── 3b. Folder spec (delegated to the layout linter) ─────────────────────────
LAYOUT_LINTER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lint-skill-layout.py"
layout_out="$(python3 "$LAYOUT_LINTER" --dir "$SKILL_DIR" 2>&1)"
layout_rc=$?
if [[ $layout_rc -eq 0 ]]; then
  pass "folder spec: clean under lint-skill-layout (entry, folders, no empty dirs, reachability, relative pointers)"
else
  while IFS= read -r line; do
    [[ "$line" =~ ^L[1-5][[:space:]] ]] && fail "folder spec: $line"
  done <<<"$layout_out"
  [[ $layout_rc -eq 2 ]] && fail "folder spec: lint-skill-layout could not run ($layout_out)"
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
