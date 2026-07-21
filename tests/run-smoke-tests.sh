#!/bin/bash
# run-smoke-tests.sh — single entry point for the SDLC Artifact Factory
# smoke-test suite. Runs every category, prints one PASS/FAIL line per test
# case (each category script already does this), then an overall summary.
# Exits 0 iff every case across every category passed.
#
# Usage:
#   tests/run-smoke-tests.sh              # everything
#   tests/run-smoke-tests.sh scripts       # one category only
#   tests/run-smoke-tests.sh scripts schemas
#
# Categories: skills agents commands hooks scripts schemas
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ALL_CATEGORIES=(skills agents commands hooks scripts schemas)
if [[ $# -gt 0 ]]; then
  CATEGORIES=("$@")
else
  CATEGORIES=("${ALL_CATEGORIES[@]}")
fi

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

for category in "${CATEGORIES[@]}"; do
  dir="$REPO_ROOT/tests/$category"
  if [[ ! -d "$dir" ]]; then
    echo "Unknown category: $category (expected one of: ${ALL_CATEGORIES[*]})" >&2
    exit 1
  fi
  echo "=== $category ==="
  shopt -s nullglob
  files=("$dir"/*.test.sh "$dir"/*.fixture.sh "$dir"/*.test.py)
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
