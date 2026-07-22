#!/bin/bash
# run-smoke-tests.sh — single entry point for the SDLC Artifact Factory
# smoke-test suite. Runs every category, prints one PASS/FAIL line per test
# case (each category script already does this), then an overall summary.
# Exits 0 iff every case across every category passed.
#
# Usage:
#   tests/run-smoke-tests.sh                     # everything
#   tests/run-smoke-tests.sh scripts              # one category only
#   tests/run-smoke-tests.sh scripts schemas      # several categories
#   tests/run-smoke-tests.sh --skill vision-statement
#   tests/run-smoke-tests.sh --agent backend-engineer
#   tests/run-smoke-tests.sh --changed [ref]      # default ref: HEAD
#
# Categories: skills agents commands hooks scripts schemas
#
# --skill/--agent/--changed resolve to a specific set of test files instead
# of a whole category: a skill's own contract test plus every agent's
# acceptance test that declares it in that agent's frontmatter `skills:`
# list (the ownership graph already declared there — see CLAUDE.md's
# Component Frontmatter section — is the single source of truth; this file
# does not maintain a second one). --changed maps `git diff --name-only`
# against skills/<name>/SKILL.md and agents/<name>.md paths through the same
# resolution. All three selectors can combine; the union runs once, deduped.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ALL_CATEGORIES=(skills agents commands hooks scripts schemas)

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_FILES=()

run_file() {
  local file="$1"
  local out rc
  if [[ "$file" == *.py ]]; then
    out="$(python3 "$file" 2>&1)"
  else
    out="$(bash "$file" 2>&1)"
  fi
  rc=$?
  echo "$out"
  local file_pass file_fail
  file_pass="$(grep -c '^PASS:' <<<"$out" || true)"
  file_fail="$(grep -c '^FAIL:' <<<"$out" || true)"
  TOTAL_PASS=$((TOTAL_PASS + file_pass))
  TOTAL_FAIL=$((TOTAL_FAIL + file_fail))
  if [[ $rc -ne 0 || $file_fail -gt 0 ]]; then
    FAILED_FILES+=("$file")
  fi
}

# skill_owners <skill-name> — prints, one per line, the basename (no .md) of
# every agents/*.md whose frontmatter `skills:` list contains this skill.
skill_owners() {
  local skill="$1" agent_file
  for agent_file in "$REPO_ROOT"/agents/*.md; do
    if grep -qE "^[[:space:]]*-[[:space:]]*${skill}[[:space:]]*\$" "$agent_file"; then
      basename "$agent_file" .md
    fi
  done
}

declare -a RESOLVED=()

resolve_skill_files() {
  local skill="$1" f owner
  f="$REPO_ROOT/tests/skills/${skill}.contract.sh"
  [[ -f "$f" ]] && RESOLVED+=("$f")
  f="$REPO_ROOT/tests/skills/${skill}.acceptance.sh"
  [[ -f "$f" ]] && RESOLVED+=("$f")
  while IFS= read -r owner; do
    [[ -z "$owner" ]] && continue
    f="$REPO_ROOT/tests/agents/${owner}.acceptance.sh"
    [[ -f "$f" ]] && RESOLVED+=("$f")
  done < <(skill_owners "$skill")
}

resolve_agent_files() {
  local agent="$1" f
  f="$REPO_ROOT/tests/agents/${agent}.contract.sh"
  [[ -f "$f" ]] && RESOLVED+=("$f")
  f="$REPO_ROOT/tests/agents/${agent}.acceptance.sh"
  [[ -f "$f" ]] && RESOLVED+=("$f")
}

resolve_changed() {
  local ref="$1" line
  while IFS= read -r line; do
    if [[ "$line" =~ ^skills/([a-z0-9]+(-[a-z0-9]+)*)/SKILL\.md$ ]]; then
      resolve_skill_files "${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^agents/([a-z0-9]+(-[a-z0-9]+)*)\.md$ ]]; then
      resolve_agent_files "${BASH_REMATCH[1]}"
    fi
  done < <(git -C "$REPO_ROOT" diff --name-only "$ref" 2>/dev/null)
}

SELECTOR_MODE=0
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)
      SELECTOR_MODE=1
      resolve_skill_files "$2"
      shift 2
      ;;
    --agent)
      SELECTOR_MODE=1
      resolve_agent_files "$2"
      shift 2
      ;;
    --changed)
      SELECTOR_MODE=1
      if [[ $# -ge 2 && "$2" != --* ]]; then
        resolve_changed "$2"
        shift 2
      else
        resolve_changed "HEAD"
        shift 1
      fi
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [[ $SELECTOR_MODE -eq 1 ]]; then
  mapfile -t RESOLVED < <(printf '%s\n' "${RESOLVED[@]}" | awk 'NF && !seen[$0]++')
  echo "=== selected ==="
  if [[ ${#RESOLVED[@]} -eq 0 ]]; then
    echo "(no matching test files for this selection)"
  else
    for file in "${RESOLVED[@]}"; do
      run_file "$file"
    done
  fi
  echo
else
  if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
    CATEGORIES=("${POSITIONAL[@]}")
  else
    CATEGORIES=("${ALL_CATEGORIES[@]}")
  fi

  for category in "${CATEGORIES[@]}"; do
    dir="$REPO_ROOT/tests/$category"
    if [[ ! -d "$dir" ]]; then
      echo "Unknown category: $category (expected one of: ${ALL_CATEGORIES[*]})" >&2
      exit 1
    fi
    echo "=== $category ==="
    shopt -s nullglob
    files=("$dir"/*.test.sh "$dir"/*.contract.sh "$dir"/*.acceptance.sh "$dir"/*.test.py)
    shopt -u nullglob
    if [[ ${#files[@]} -eq 0 ]]; then
      echo "(no tests in this category yet)"
      continue
    fi
    for file in "${files[@]}"; do
      run_file "$file"
    done
    echo
  done
fi

echo "=========================================="
echo "TOTAL: $TOTAL_PASS passed, $TOTAL_FAIL failed"
if [[ ${#FAILED_FILES[@]} -gt 0 ]]; then
  echo "Files with failures:"
  for f in "${FAILED_FILES[@]}"; do
    echo "  - ${f#$REPO_ROOT/}"
  done
  exit 1
fi
exit 0
