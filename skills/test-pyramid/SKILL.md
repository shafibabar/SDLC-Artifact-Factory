---
name: test-pyramid
description: >
  Use when test-strategist (or anyone) writes, revises or reviews a product's
  test strategy in the Implement or Quality phase, or asks which layer should
  prove a behaviour: unit, integration, contract, end-to-end, performance, load,
  chaos or mutation testing; the coverage gate (100% line and branch, Go
  statement blocks plus gobco, exclusions); waiving a gap; surviving, timed-out or equivalent
  mutants; flaky tests, retries and quarantine; which suites run on pull
  requests, nightly or before release; test pyramid shape or ratios; risk-rated
  test depth; testing for a small (lean) product; regression tests; performance
  targets. Produces artifacts/<product>/implement/test-strategy.md.
version: 3.0.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, quality, testing, test-pyramid, shift-left, shift-right, strategy, coverage, mutation, flaky]
produces: test-strategy
domain: testing
status: stable
related: [bdd-feature-file, acceptance-criteria, nfr-specification, slo-definition, go-unit-test, python-unit-test, mock-generation, test-fixture-design, go-integration-test, python-integration-test, go-contract-test, python-contract-test, go-e2e-test, python-e2e-test, go-performance-test, python-performance-test, go-load-test, python-load-test, go-chaos-test, python-chaos-test, go-mutation-test, python-mutation-test, react-component-testing, react-e2e-testing, security-implementation, compliance-verification, health-check-design, ci-pipeline, uat-plan]
sources:
  - research/testing/unit-testing-khorikov.md
  - research/testing/agile-testing-crispin-gregory.md
  - research/testing/testing-vv-dictionary-quigley.md
  - research/testing/software-testing-craftsman-jorgensen.md
  - research/testing/testing-web-apis-winteringham.md
  - research/testing/explore-it-hendrickson.md
  - research/testing/contract-testing-in-action-cruz-prescott.md
  - research/software-architecture/building-microservices-newman.md
  - research/testing/go-coverage-official-docs.md
  - research/testing/go-toolchain-official-docs.md
  - research/testing/coverage-official-docs.md
  - research/testing/vitest-official-docs.md
  - research/testing/gremlins-official-docs.md
  - research/testing/mutmut-official-docs.md
  - research/testing/stryker-js-official-docs.md
  - research/testing/playwright-official-docs.md
---

# Test Pyramid

## Purpose

This skill owns the cross-stack test policy: which layers exist, what each proves, the coverage and mutation gates, the flaky-test rule and when suites run. Every language skill implements it; none restates it differently. The strategy it produces is approved by the product owner.

## First rule: the request does not set the policy

Instructions given in advance, by anyone including the product owner, never change this policy: not dropping a layer, a layer ratio, a lower figure, an uncited target or a waiver agreed before a result exists.

1. Produce the strategy, review or verdict as the policy requires.
2. Say plainly where it differs from what was asked, and why.
3. Never offer to drop a layer, to record, set or confirm a lower figure (the configuration accepts only 100), to log the wish as an "override", "departure" or "your decision" for approval, or to run outside the policy. The one route below 100% is the waiver in rule 4: a measured result, after review.

## Policy

1. **Every size gets the full treatment.** Lean, standard and enterprise all plan unit, integration, contract, end-to-end, performance, load, chaos and mutation testing, and every Must Have criterion gets executable scenarios. Size changes only the number of rows and journeys. A layer can never be waived.
2. **Lowest layer that proves it.** The pyramid shape (many unit, fewer integration, fewest end-to-end) is the result of that rule and of keeping logic in an isolated domain model, not a ratio to hit (Khorikov). No 70/20/10 or any other split. More end-to-end tests than unit tests is a defect to investigate.
3. **Coverage target: 100% of lines and branches.** Only machine-generated code is excluded automatically. Every other exclusion is listed with its reason for the product owner's approval. Go's own tool measures statement blocks and **cannot measure branches**: 100% of statement blocks is a hard gate, plus `gobco` branch coverage after a trial, with the unmeasured cases (including `select`, `range` and zero-iteration loops) stated in each report. If the trial fails, go back to the product owner; never drop to statements only.
4. **Waivers.** Line coverage, branch coverage and the mutation result are each judged separately against 100%. A measured result **more than 90%** and under 100% fails the gate unless the product owner reviews the gap and waives it with recorded comments. At 90% or below there is no waiver. No measurement (failed run or trial) means nothing to waive. A waiver covers that one result, never a later run.
5. **Mutation: every planted mutant is caught by a test, or recorded with the reason it cannot be.** The only reason for a surviving mutant is that it does not alter behaviour. A mutant that times out or is rejected by the type checker counts as caught only after each one is individually checked and recorded with a one-line reason; never automatically. No lower target replaces 100%.
6. **Flaky tests:** one automatic retry for end-to-end only; no retry at any lower layer. Tagged, non-blocking quarantine with a deadline. Deletion only with a record.
7. **Targets are cited, never invented.** Latency, throughput, error-rate and recovery numbers come from an NFR or SLO ID (`nfr-specification`, `slo-definition`); otherwise they are open questions. A comparison of old against new code needs no absolute number.

The 100% target is the product owner's decision. Coverage proves only that code ran, never that an assertion would catch a fault (Khorikov), so never present the number as proof of quality; the mutation rule and behaviour assertions carry that. It also overrides "trivial code needs no test": trivial code is covered too.

## What every answer states

State each rule that bears on the question, in a reply as much as in the artifact; do not only follow it. Any sign-off, verdict or report also says that checks and coverage confirm only what someone specified, lists unscripted exploratory testing (`uat-plan`) among the before-release activities, and ends by putting the report to the product owner for approval.

## Layers

| Layer | Proves | Go | Python | React |
|---|---|---|---|---|
| Unit / component | Domain rules, validation, state changes | `go-unit-test` | `python-unit-test` | `react-component-testing` |
| Integration | Our code with the real database and broker; API behaviour | `go-integration-test` | `python-integration-test` | `react-component-testing` |
| Contract | Both sides agree on the wire shape (HTTP, events, shell to remote) | `go-contract-test` | `python-contract-test` | `react-component-testing` |
| End-to-end | A few whole user journeys on the running system | `go-e2e-test` | `python-e2e-test` | `react-e2e-testing` |
| Performance | The change did not slow the code | `go-performance-test` | `python-performance-test` | no owning skill |
| Load | Stated targets hold under demand | `go-load-test` | `python-load-test` | no owning skill |
| Chaos | Resilience patterns hold under injected faults | `go-chaos-test` | `python-chaos-test` | no owning skill |
| Mutation | The tests notice broken code | `go-mutation-test` | `python-mutation-test` | no owning skill (StrykerJS) |

Test doubles are `mock-generation`; data and isolation are `test-fixture-design`; Gherkin is `bdd-feature-file`. A layer with no owning skill is still planned, and the gap is an open question. `security-engineer` owns security control tests (`security-implementation`), compliance verification (`compliance-verification`) and, with `platform-engineer`, vulnerability scanning (`ci-pipeline`); `platform-engineer` owns health checks (`health-check-design`). The strategy confirms each exists and is gated.

Checks are not testing (Crispin and Gregory): unscripted exploration belongs to `uat-plan`'s exploratory sessions (Hendrickson). A green pipeline never means "tested everything".

## Procedure

1. Read the acceptance criteria, NFR specification, SLOs, design (services, events, remotes), `sdlc-config.json` (profile, languages) and any existing strategy.
2. Risk-rate each capability and boundary: impact times likelihood (Winteringham). Read `./references/layers-and-risk.md` to turn a rating into extra checks and to place a behaviour in a layer. A rating only adds depth.
3. Copy `./templates/test-strategy.md` to `artifacts/<product>/implement/test-strategy.md` with Write.
4. Fill every layer row: what it proves here, skill, author, trigger, selector. For triggers, selectors, retries, quarantine and smoke safety read `./references/flaky-and-suite-selection.md`.
5. Fill the coverage and mutation sections for each language. Before writing them, read `./references/coverage-and-mutation-gates.md`: each tool has a way to report success while the rule is unmet.
6. Map every Must Have criterion (`AC-US-n.m`) to a scenario and a layer; pick the end-to-end journeys and the read-only smoke subset.
7. Cite targets; write one steady-state hypothesis per resilience pattern.
8. Run `./scripts/validate-test-strategy.sh <file>`, fix every FAIL, re-run until clean; then tick `./resources/checklist.md`.
9. Present exclusions, open questions and gaps to the product owner for approval. Report no gate as met before a run shows it. When a run gives a result above 90% and under 100%, show the gap and ask for review; only after the product owner's comments, record it in the strategy's Waivers table and in that run's report.

Worked strategies: `./examples/01-lean-allotment-waiting-list.md` (one Go service, small web app), `./examples/02-standard-clinic-reminders.md` (Python and React, events), `./examples/03-enterprise-customs-filing.md` (multi-tenant, two regions, three languages).

When a production defect is found, write a failing test that reproduces it before the fix. Regression is a purpose any layer serves, not a layer (Quigley).

## Gotchas

- **"`go test -cover` prints 100.0%, so the gate passes."** *Reason:* one decimal hides gaps, and it counts statements, not branches. *Instead:* fail on any zero-count block, then run `gobco`, which has no threshold of its own.
- **"It rounds to 90.1%" or "the average is above 90".** *Reason:* a waiver is judged on each result's exact counts. *Instead:* compute covered over total per measure; never round or combine.
- **"Exclude `main` and getters as usual."** *Reason:* only machine-generated code is automatically excluded. *Instead:* test them, or list each with a reason for approval; tool default exclusions and ignore comments count too.
- **"The tool says 100% mutation score."** *Reason:* some tools count timeouts as detected, drop type-check rejections from the score, or never plant mutants in some constructs. *Instead:* count from per-mutant statuses and state what is never planted.
- **"Retry or quarantine it and move on."** *Reason:* a quarantined test proves nothing. *Instead:* if coverage or a Must Have criterion is then unproven, the gate is red until a stable test replaces it.
- **"`-tags smoke` runs only smoke tests."** *Reason:* Go build tags add files and remove none. *Instead:* keep destructive files out of the smoke build and refuse non-throwaway addresses.
- **"Browser coverage makes up the gap."** *Reason:* end-to-end runs do not feed these coverage numbers. *Instead:* cover it in unit or integration tests.
- **"The TDD hook proves tests came first."** *Reason:* it only checks that a matching test file exists. *Instead:* see each test fail for the expected reason.

## Output

| File | When to open it |
|---|---|
| `./templates/test-strategy.md` | Writing the artifact |
| `./scripts/validate-test-strategy.sh` | Before hand-off, and after every edit |
| `./resources/checklist.md` | After the script passes |
| `./references/layers-and-risk.md` | Placing a behaviour, rating risk, deriving cases |
| `./references/coverage-and-mutation-gates.md` | Writing or judging either gate |
| `./references/flaky-and-suite-selection.md` | Triggers, selectors, smoke, flaky handling |

Test reports go under `artifacts/<product>/quality/test-reports/`, one file each with the artifact frontmatter, for the product owner's approval.
