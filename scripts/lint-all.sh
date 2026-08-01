#!/usr/bin/env bash
# lint-all.sh — the Architecture Review governance gate runner (P1.9, closes #790).
#
# Runs, in a fixed order, the governance checks built across P1:
#
#   1. Schema + arch tests   BLOCKING   tests/schemas/*.schema.test.py + tests/arch/*.test.py
#   2. lint-manifests.py     BLOCKING   frontmatter/manifest shape conformance
#   3. lint-duplication.py   REPORT     duplication scan (never fails the gate)
#   4. lint-relationships.py BLOCKING   broken 'related:' refs + agent 'skills:' refs.
#                                       Was REPORT-only while P2's backlog stood; P2 drove
#                                       broken refs 11 -> 0 and orphans 48 -> 0, so this
#                                       check is now enforced (orphans stay a warning).
#
# The gate exits non-zero IFF a BLOCKING step failed. Report-only steps run,
# print their findings, and never change the gate's exit code.
#
# Wired into CI (.github/workflows/governance.yml) on pull_request + push to main,
# and surfaced to the local suite as the 'arch' category of tests/run-smoke-tests.sh.
#
# Standalone-runnable:  scripts/lint-all.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PY="${PYTHON:-python3}"

# Exit code the whole gate returns: 0 unless a BLOCKING step fails.
GATE_RC=0

hr() { printf '%s\n' "======================================================================"; }
section() { echo; hr; echo "  $1"; hr; }

# run_blocking_py <label> <file...> — run each python file; any non-zero exit
# marks the gate failed. Streams each file's output.
run_blocking_py() {
  local label="$1"; shift
  local file rc
  for file in "$@"; do
    echo "--- ${label}: ${file#$REPO_ROOT/}"
    "$PY" "$file"
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo ">>> BLOCKING FAILURE (exit $rc): ${file#$REPO_ROOT/}"
      GATE_RC=1
    fi
  done
}

# ---------------------------------------------------------------------------
# Step 1 — Schema + arch tests  (BLOCKING)
# ---------------------------------------------------------------------------
section "STEP 1/4  Schema + arch tests            [BLOCKING]"
shopt -s nullglob
SCHEMA_TESTS=("$REPO_ROOT"/tests/schemas/*.schema.test.py)
ARCH_TESTS=("$REPO_ROOT"/tests/arch/*.test.py)
shopt -u nullglob

if [[ ${#SCHEMA_TESTS[@]} -eq 0 && ${#ARCH_TESTS[@]} -eq 0 ]]; then
  echo ">>> BLOCKING FAILURE: no schema/arch tests found — gate cannot self-validate"
  GATE_RC=1
else
  run_blocking_py "schema-test" "${SCHEMA_TESTS[@]}"
  run_blocking_py "arch-test" "${ARCH_TESTS[@]}"
fi

# ---------------------------------------------------------------------------
# Step 2 — Manifest linter  (BLOCKING)
# ---------------------------------------------------------------------------
section "STEP 2/4  lint-manifests.py               [BLOCKING]"
"$PY" "$REPO_ROOT/scripts/lint-manifests.py"
MANIFEST_RC=$?
if [[ $MANIFEST_RC -ne 0 ]]; then
  echo ">>> BLOCKING FAILURE (exit $MANIFEST_RC): scripts/lint-manifests.py"
  GATE_RC=1
fi

# ---------------------------------------------------------------------------
# Step 3 — Duplication linter  (REPORT-ONLY, never fails)
# ---------------------------------------------------------------------------
section "STEP 3/4  lint-duplication.py             [REPORT-ONLY]"
"$PY" "$REPO_ROOT/scripts/lint-duplication.py" || true
echo "(lint-duplication is report-only — its exit code never affects the gate.)"

# ---------------------------------------------------------------------------
# Step 4 — Relationship linter  (BLOCKING since P2 close-out)
# ---------------------------------------------------------------------------
section "STEP 4/4  lint-relationships.py           [BLOCKING]"
REL_OUT="$("$PY" "$REPO_ROOT/scripts/lint-relationships.py" 2>&1)"
REL_RC=$?
echo "$REL_OUT"

# Count broken 'related:' refs dynamically from the linter's own output.
REL_BROKEN="$(grep -cE "related '.*' is not a real skill" <<<"$REL_OUT" || true)"

echo
if [[ $REL_RC -ne 0 ]]; then
  echo ">>> BLOCKING FAILURE (exit $REL_RC): scripts/lint-relationships.py"
  echo "    ${REL_BROKEN} broken 'related:' ref(s). P2 drove this count to 0 and the"
  echo "    check is now enforced — a broken cross-reference must be fixed, not tracked."
  GATE_RC=1
else
  echo "lint-relationships: ${REL_BROKEN} broken 'related:' ref(s) — enforced since P2 close-out."
fi

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
section "GOVERNANCE GATE RESULT"
if [[ $GATE_RC -eq 0 ]]; then
  echo "PASS: all BLOCKING checks green (schema+arch tests, lint-manifests, lint-relationships)."
  echo "      Report-only checks ran; their findings above do not gate."
else
  echo "FAIL: one or more BLOCKING checks failed (see >>> markers above)."
fi
hr

exit $GATE_RC
