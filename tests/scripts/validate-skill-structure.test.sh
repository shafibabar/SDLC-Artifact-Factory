#!/usr/bin/env bash
# Tests for scripts/validate-skill-structure.sh
# All tests use synthetic skill directories in a temp scratch dir — no live model call.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/validate-skill-structure.sh"
SCRATCH="$(mktemp -d)"
PASS=0; FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

assert_exit0() {
  local label="$1"; shift
  if bash "$@" > /dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}
assert_exit1() {
  local label="$1"; shift
  if bash "$@" > /dev/null 2>&1; then fail "$label"; else pass "$label"; fi
}
assert_output_contains() {
  local label="$1" pattern="$2"; shift 2
  local out; out="$(bash "$@" 2>&1)"
  if echo "$out" | grep -q "$pattern"; then pass "$label"; else fail "$label — expected '$pattern' in output"; fi
}

# ── Helpers ──────────────────────────────────────────────────────────────────

make_skill() {
  # make_skill <dir> <frontmatter_block> <body_content>
  local dir="$1" fm="$2" body="$3"
  mkdir -p "$dir"
  printf -- '---\n%s\n---\n\n%s\n' "$fm" "$body" > "$dir/SKILL.md"
}

GOOD_FM="name: test-skill
description: >
  Test skill for validation.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-01-01
tags: [test]"

# ── 1. Missing required field ─────────────────────────────────────────────────
D="$SCRATCH/missing-field"
make_skill "$D" "name: test-skill
description: Test.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-01-01" "Body content."
# tags is missing
assert_exit1 "exits 1 when required field (tags) is missing" "$SCRIPT" "$D/SKILL.md"
assert_output_contains "reports missing field name" "missing required field: tags" "$SCRIPT" "$D/SKILL.md"

# ── 2. All required fields present in order — passes ─────────────────────────
D="$SCRATCH/all-fields"
make_skill "$D" "$GOOD_FM" "Body content."
assert_exit0 "exits 0 when all required fields present in order" "$SCRIPT" "$D/SKILL.md"

# ── 3. Body over 200 lines — flagged ─────────────────────────────────────────
D="$SCRATCH/long-body"
long_body="$(printf 'Line %d\n' $(seq 1 201) | tr '\n' '\n')"
make_skill "$D" "$GOOD_FM" "$long_body"
assert_exit1 "exits 1 when body exceeds 200 lines" "$SCRIPT" "$D/SKILL.md"
assert_output_contains "reports line count in failure" "threshold 200" "$SCRIPT" "$D/SKILL.md"

# ── 4. Body exactly 200 lines — passes ───────────────────────────────────────
D="$SCRATCH/exact-200"
exact_body="$(printf 'Line %d\n' $(seq 1 200))"
make_skill "$D" "$GOOD_FM" "$exact_body"
assert_exit0 "exits 0 when body is exactly 200 lines" "$SCRIPT" "$D/SKILL.md"

# ── 5. Body mentions reference file that exists — passes ─────────────────────
D="$SCRATCH/ref-exists"
mkdir -p "$D/references"
echo "# Ref" > "$D/references/output-format-template.md"
make_skill "$D" "$GOOD_FM" "See references/output-format-template.md for the template."
assert_exit0 "exits 0 when mentioned reference file exists" "$SCRIPT" "$D/SKILL.md"

# ── 6. Body mentions reference file that does NOT exist — fails ──────────────
D="$SCRATCH/ref-missing"
make_skill "$D" "$GOOD_FM" "See references/nonexistent.md for details."
assert_exit1 "exits 1 when mentioned reference file is missing on disk" "$SCRIPT" "$D/SKILL.md"
assert_output_contains "reports missing reference file" "referenced file missing on disk" "$SCRIPT" "$D/SKILL.md"

# ── 7. Reference file exists on disk but body never mentions it — fails ───────
D="$SCRATCH/orphan-ref"
mkdir -p "$D/references"
echo "# Orphan" > "$D/references/orphaned.md"
make_skill "$D" "$GOOD_FM" "Body content with no reference pointer."
assert_exit1 "exits 1 when reference file is orphaned (not mentioned in body)" "$SCRIPT" "$D/SKILL.md"
assert_output_contains "reports orphaned reference file" "orphaned reference file" "$SCRIPT" "$D/SKILL.md"

# ── 8. No references/ directory — passes without reference checks ─────────────
D="$SCRATCH/no-refs-dir"
make_skill "$D" "$GOOD_FM" "Body content with no references."
assert_exit0 "exits 0 when no references/ directory exists" "$SCRIPT" "$D/SKILL.md"

# ── 9. Missing SKILL.md file — exits 1 with clear message ────────────────────
assert_exit1 "exits 1 when SKILL.md does not exist" "$SCRIPT" "/nonexistent/SKILL.md"
assert_output_contains "reports file not found" "file not found" "$SCRIPT" "/nonexistent/SKILL.md"

# ── 10. No argument — exits 1 ────────────────────────────────────────────────
assert_exit1 "exits 1 when no argument provided" "$SCRIPT"

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -rf "$SCRATCH"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
