#!/bin/bash
# Tests skills/ubiquitous-language/scripts/validate-ubiquitous-language.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/ubiquitous-language/scripts/validate-ubiquitous-language.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-ubiquitous-language: $1"
  else
    _fail "validate-ubiquitous-language: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: ubiquitous-language-lending
product: shelfloop
bounded-context: Lending
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-02-01
summary: Shelfloop Lending context, 4 terms; Loan canonical, "borrowing" banned.
profile: standard
---

# Ubiquitous Language: Lending

## Terms

| Term | Type | Meaning in this context | Rules that always hold | Behaviour | Source |
|---|---|---|---|---|---|
| Loan | Aggregate Root | A tool lent to one Member for agreed dates | One open Loan per tool | `LoanStarted` | ideate/job-stories.md J2 |
| Member | Entity | A person who may borrow tools | At most three open Loans | — | ideate/personas.md |
| Late Return | Policy | Whenever a Loan passes its end date, a reminder goes out | — | `LoanOverdue` | *assumed* |
| Shelf | Read Model | Tools available today | — | — | ideate/vision.md |

## Key Scenarios

    Scenario: A tool can't be lent twice at once
      Given a Loan of the drill to Ana is open
      When Ben asks for a Loan of the drill
      Then it is refused

    Scenario: A Late Return reminder goes out
      Given a Loan ended yesterday
      When the day starts
      Then the Member gets a Late Return reminder

## Banned Synonyms

| Banned | Use instead | Renamed in (code · API · events · tests · docs) |
|---|---|---|
| borrowing, rental | Loan | nothing built yet |

## Homonyms at the Boundary

| Term | Meaning here | Other context | Meaning there | Translation (Context Map relationship) |
|---|---|---|---|---|
| Member | A borrower | Billing | A fee payer | Billing's ACL maps Member to Account |

## Open Questions for the Product Owner

| # | Question | Why it matters | Assumed meanwhile |
|---|---|---|---|
| 1 | Do reminders go out on the end date or the day after? | Changes Late Return | Day after |
EOF
expect "a complete document passes and counts terms, assumptions and scenarios" good.md 0 "INFO: 4 term(s), 1 *assumed*, 2 key scenario(s)"

sed 's/| ideate\/personas.md |/| |/' good.md > nosource.md
expect "a term with no source fails" nosource.md 1 "FAIL: term 'Member' has a source"

sed 's/| At most three open Loans |/| — |/' good.md > norule.md
expect "an Entity with no rule fails" norule.md 1 "FAIL: entity 'Member' states at least one rule"

awk '/^## Key Scenarios/{skip=1} /^## Banned Synonyms/{skip=0} !skip' good.md > noscen.md
expect "Aggregate Roots and Policies with no scenario fail" noscen.md 1 "FAIL: has a Key Scenarios section"

sed 's/| borrowing, rental | Loan |/| borrowing, member | Loan |/' good.md > banterm.md
expect "banning a word that is a term of this context fails" banterm.md 1 "FAIL: banned word 'member' is not itself a term"

sed 's/| borrowing, rental | Loan | nothing built yet |/| borrowing, rental | Loan | |/' good.md > nostatus.md
expect "a standard-profile ban with no rename status fails" nostatus.md 1 "FAIL: ban → 'Loan' records its rename status"

sed 's/| Billing.s ACL maps Member to Account |/| |/' good.md > notrans.md
expect "a homonym with no translation fails" notrans.md 1 "FAIL: homonym 'Member' names its translation"

awk '/^## Open Questions/{exit} {print}' good.md > noq.md
expect "assumed terms with no open questions fail" noq.md 1 "are *assumed*, so open questions for the product owner are listed"

sed 's/| A person who may borrow tools |/| A row in the members table |/' good.md > storage.md
expect "a meaning defined by storage fails" storage.md 1 "FAIL: term 'Member' is defined in domain words"

sed 's/| Shelf | Read Model |/| ShelfV2 | Read Model |/' good.md > v2.md
expect "a version-suffixed term warns but does not fail" v2.md 0 "WARN: a version-suffixed"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-ubiquitous-language: no argument exits 2" || _fail "validate-ubiquitous-language: no argument exits 2" "exit $code"

smoke_test_summary
