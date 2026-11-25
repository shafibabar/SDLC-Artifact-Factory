#!/bin/bash
# Tests skills/test-pyramid/scripts/validate-test-strategy.sh — a skill-owned
# script exercised directly with a file-path CLI arg. The passing fixture is
# built here, never from the skill's examples; the template is used only to
# prove that an unfilled one fails.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SKILL="$REPO_ROOT/skills/test-pyramid"
VALIDATE="$SKILL/scripts/validate-test-strategy.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <exit> <substring> <file>
  local label="$1" want="$2" sub="$3" file="$4"
  local out code
  out="$("$VALIDATE" "$file" 2>&1)"; code=$?
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || echo "$out" | grep -qF -- "$sub"; }; then
    _pass "validate-test-strategy: $label"
  else
    _fail "validate-test-strategy: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

mutate() { # mutate <name> <old> <new>: copy good.md with one replacement
  python3 - "$1" "$2" "$3" <<'PY'
import sys
name, old, new = sys.argv[1:4]
t = open("good.md").read()
assert old in t, "fixture missing: " + old
open(name, "w").write(t.replace(old, new, 1))
PY
}

bad() { # bad <label> <substring> <old> <new>
  mutate case.md "$3" "$4" || { _fail "validate-test-strategy: $1" "fixture"; return; }
  expect "$1" 1 "FAIL: $2" case.md
}

cat > good.md <<'FIXTURE'
---
name: test-strategy
product: shelfmark
version: 1.0.0
phase: implement
owner: test-strategist
created: 2026-11-25
summary: Eight layers, the 100% gates, and one open performance target.
traces-to: [ideate/nfr-specification.md]
---

# Test Strategy for Shelfmark

- **Profile:** lean
- **Languages:** go, python, typescript
- **Accessibility target:** WCAG 2.2, level from NFR-USE-01

## Risk

| ID | Capability or boundary | Traces to | Impact | Likelihood | Extra depth |
|---|---|---|---|---|---|
| RK-1 | loans | AC-US-1.1 | H | M | decision table |

## Layers

| Layer | What it proves here | Skill | Author | When it runs | Selected by |
|---|---|---|---|---|---|
| Unit | rules | go-unit-test | backend-engineer | pull request | default |
| Integration | storage | go-integration-test | backend-engineer | pull request | default |
| Contract | API shape | go-contract-test | test-strategist | pull request | default |
| End-to-end | borrow journey | go-e2e-test | test-strategist | nightly and before release | tag e2e |
| Performance | search code | go-performance-test | test-strategist | before release | tag perf |
| Load | search target | go-load-test | test-strategist | before release | tag load |
| Chaos | database loss | go-chaos-test | test-strategist | before release | tag chaos |
| Mutation | all packages | go-mutation-test | test-strategist | monthly and before release | own job |

## Acceptance and Journeys

| Journey or scenario group | Criteria | Layer | Smoke |
|---|---|---|---|
| borrow a book | AC-US-1.1 | End-to-end | no |
| view catalogue | AC-US-2.1 | End-to-end | yes (read-only) |

## Targets

| Check | Target | Source |
|---|---|---|
| search latency | 2 s at p95 | NFR-PERF-01 |
| load level | not set | OQ-1 |

## Chaos Experiments

| Experiment | Steady-state hypothesis | Resilience pattern proven |
|---|---|---|
| database unreachable | no loan is lost | retry and backoff |

## Coverage Gate

**Rule:** 100% of lines and branches. Only machine-generated code is excluded automatically.

| Language | Line gate | Branch gate | Not measured (stated in each report) |
|---|---|---|---|
| go | 100% of statement blocks | gobco after a trial | select, range and zero-iteration loops |
| python | missing lines zero | branch measurement, fail under 100 | one-line alternatives |
| typescript | coverage.include, lines 100% | branches 100% | browser runs |

**If a gate cannot be measured:** it returns to the product owner.

## Coverage Exclusions

| Path or pattern | Kind | Reason | Approval |
|---|---|---|---|
| internal/api/types_gen.go | generated | generator marker | automatic (generated) |
| cmd/server/main.go | other | process wiring | pending |

## Mutation Rule

**Rule:** every planted mutant is caught by a test, or recorded with the reason it cannot be (it does not alter behaviour).

**Timeouts and type-checker rejections:** each counts as caught only after it is individually checked and recorded with a one-line reason; never automatically.

| Language | Tool | Gate reads | Never planted (stated limit) |
|---|---|---|---|
| go | Gremlins | per-mutant JSON | statement removal |
| python | mutmut | results --all | module-level code |
| typescript | StrykerJS | JSON report | excluded mutators |

## Flaky Tests

| Layer | Automatic retries |
|---|---|
| Unit | 0 |
| Integration | 0 |
| Contract | 0 |
| End-to-end | 1 |
| Performance, Load, Chaos, Mutation | 0 |

- **Quarantine:** tagged, non-blocking, tracked issue, deadline of two weeks.
- **Deletion:** only with a record.
- **Regression:** a failing test before the fix.

## Delegated Testing

| Check | Owner | Skill | Gate |
|---|---|---|---|
| Security controls | security-engineer | security-implementation | merge |
| Compliance verification | security-engineer | compliance-verification | release |

## Open Questions

- OQ-1: what load level must search hold? Owner: product owner.
FIXTURE

expect "a complete strategy passes" 0 "0 check(s) failed" good.md
expect "a pending exclusion warns" 0 "WARN: exclusion 'cmd/server/main.go'" good.md
expect "the unfilled template fails" 1 "FAIL: no unfilled [placeholder]" "$SKILL/templates/test-strategy.md"
expect "missing file is a usage error" 2 "file not found" nope.md

bad "placeholder left in" "no unfilled [placeholder]" "decision table" "[checks added]"
bad "placeholder in frontmatter" "frontmatter has no unfilled value" "product: shelfmark" "product: [product slug]"
bad "unknown profile" "profile is lean" "**Profile:** lean" "**Profile:** tiny"
bad "typescript without WCAG 2.2" "accessibility target is WCAG 2.2" "WCAG 2.2" "WCAG 2.1"
bad "a layer missing" "layer 'chaos' is planned" "| Chaos | database loss | go-chaos-test | test-strategist | before release | tag chaos |" ""
bad "a layer skipped at lean" "layer 'load' is not skipped" "| search target | go-load-test | test-strategist | before release |" "| search target | go-load-test | test-strategist | not required at lean |"
bad "ratios in the layers" "no layer ratios" "| Unit | rules |" "| Unit | 70% of tests |"
bad "journey without criterion id" "journey 'borrow a book': cites" "| borrow a book | AC-US-1.1 |" "| borrow a book | story 1 |"
bad "destructive smoke" "journey 'borrow a book': smoke" "End-to-end | no |" "End-to-end | yes |"
bad "invented target" "target 'search latency': cites" "| NFR-PERF-01 |" "| team default |"
bad "open question not listed" "OQ-1 is listed" "- OQ-1: what" "- what"
bad "lower coverage rule" "coverage rule is 100%" "**Rule:** 100% of lines and branches." "**Rule:** 80% of lines."
bad "lower coverage figure" "no coverage figure other than 100%" "lines 100%" "lines 90%"
bad "statements only for go" "go: gobco branch gate" "gobco after a trial" "not measured"
bad "go unmeasured cases omitted" "go: states select" "select, range and zero-iteration loops" "none"
bad "typescript without include" "typescript: coverage.include" "coverage.include, " ""
bad "no escalation" "unmeasurable gate returns" "it returns to the product owner." "use statements only."
bad "exclusion without reason" "exclusion 'cmd/server/main.go': has a reason" "| process wiring |" "|  |"
bad "exclusion without approval state" "exclusion 'cmd/server/main.go': approval" "| pending |" "| yes |"
bad "percentage mutation target" "no percentage mutation target" "| per-mutant JSON |" "| score 60% |"
bad "timeouts counted automatically" "timeouts and rejections" "each counts as caught only after it is individually checked and recorded with a one-line reason; never automatically." "timeouts count as caught."
bad "mutation row missing" "mutation row for python" "| python | mutmut | results --all | module-level code |" ""
bad "retry below end-to-end" "retries: integration is 0" "| Integration | 0 |" "| Integration | 1 |"
bad "two retries at end-to-end" "retries: end-to-end is 1" "| End-to-end | 1 |" "| End-to-end | 2 |"
bad "retry in a grouped row" "retries: no other layer retries" "| Performance, Load, Chaos, Mutation | 0 |" "| Performance, Load, Chaos, Mutation | 3 |"
bad "blocking quarantine" "quarantine is non-blocking" "non-blocking, " ""
bad "silent deletion" "deletion needs a record" "only with a record." "when slow."
bad "no compliance gate" "delegated security and compliance" "| Compliance verification |" "| Other |"

smoke_test_summary
