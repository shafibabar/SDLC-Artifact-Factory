#!/bin/bash
# Tests skills/adr-authoring/scripts/validate-adr.sh — a skill-owned script
# exercised directly with a file-path CLI arg, not smoke_test_script's
# stdin-JSON hook contract.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/adr-authoring/scripts/validate-adr.sh"

# A structurally complete ADR (all sections present, even with placeholder
# content) must pass -- this script checks structure, not whether
# placeholders were filled in. That's a deliberate scope boundary, not a gap:
# content-quality judgment (is Context neutral, is Rationale honest) stays
# with the enterprise-architect's own review, per skill-authoring-standards.
cd "$SCRATCH_DIR"
SCAFFOLDED="$("$REPO_ROOT/skills/adr-authoring/scripts/scaffold-adr.sh" acme complete-check "Complete Check")"

if "$VALIDATE" "$SCAFFOLDED" >/dev/null 2>&1; then
  _pass "validate-adr: a fresh, structurally-complete scaffold passes"
else
  _fail "validate-adr: a fresh, structurally-complete scaffold passes" "expected exit 0 on a structurally complete file"
fi

# A genuinely incomplete ADR (missing deciders, Trade-off line, one
# Consequences subsection, and Related ADRs) must fail with the right count.
cat > "$SCRATCH_DIR/broken.md" <<'EOF'
---
adr-id: ADR-999
title: Missing Deciders And Trade-off
status: Proposed
date: 2026-07-23
---

# ADR-999: Missing Deciders And Trade-off

## Status
Proposed

## Context
Some context.

## Decision
We will do the thing.

## Rationale
No trade-off line here, just prose.

## Consequences

### Positive
- Good thing

### Risks
- Some risk
EOF

OUTPUT="$("$VALIDATE" "$SCRATCH_DIR/broken.md" 2>&1)"
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 1 ]; then
  _pass "validate-adr: a structurally incomplete ADR exits 1"
else
  _fail "validate-adr: a structurally incomplete ADR exits 1" "got exit $EXIT_CODE"
fi

if echo "$OUTPUT" | grep -q "4 check(s) failed"; then
  _pass "validate-adr: reports the correct count of failed checks (4)"
else
  _fail "validate-adr: reports the correct count of failed checks (4)" "expected '4 check(s) failed' in output"
fi

if echo "$OUTPUT" | grep -q "FAIL: frontmatter has 'deciders'" && echo "$OUTPUT" | grep -q "FAIL: Rationale has a \*\*Trade-off:\*\* line" && echo "$OUTPUT" | grep -q "FAIL: Consequences has '### Negative / Trade-offs'" && echo "$OUTPUT" | grep -q "FAIL: Related ADRs section present"; then
  _pass "validate-adr: names each specific failing check"
else
  _fail "validate-adr: names each specific failing check" "one or more expected FAIL lines missing"
fi

# Missing file argument -> exit 2 (usage/file error, distinct from exit 1
# validation failure)
"$VALIDATE" /no/such/file.md >/dev/null 2>&1
ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 2 ]; then
  _pass "validate-adr: a nonexistent file exits 2 (usage/file error, distinct from 1)"
else
  _fail "validate-adr: a nonexistent file exits 2 (usage/file error, distinct from 1)" "got exit $ACTUAL_EXIT"
fi

smoke_test_summary
