---
name: uat-scenario
description: >
  Write a UAT scenario — the human-executed, live-environment counterpart to an
  Ideate-phase Gherkin acceptance criterion and its automated bdd-feature-file
  scenario. Covers Given/When/Then in plain tester language (Context, numbered
  Steps, observable Expected Outcome), preconditions and seeded test data,
  pass/fail recording with tester identity and environment, Specification by
  Example carried from agreement to human proof, same-ID traceability
  (AC-US-005 to UAT-005), the automated-vs-manual execution-mode split, defect
  capture feeding feedback-template on failure, and pairing scripted scenarios
  with a time-boxed exploratory charter so a release is checked for both known
  rules and unanticipated risk. Use when a Data Steward or Compliance Officer
  must confirm a deployed release does what was agreed, during Customer
  Validation, before acceptance-sign-off.
version: 2.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-07-20
tags: [validation, uat, acceptance-testing, given-when-then, specification-by-example, exploratory]
produces: uat-scenario
domain: validation
status: stable
related: [acceptance-criteria, bdd-feature-file, uat-plan, feedback-template, acceptance-sign-off, risk-register]
---

# UAT Scenario

## Purpose

A UAT scenario takes an existing Ideate-phase Gherkin acceptance criterion (`acceptance-criteria`) and restates it as a script a non-technical human can follow, in the live or live-like environment, to confirm the deployed release actually does what was agreed. It does not invent new rules and does not rewrite the rule the criterion already stated. It changes only the **execution mode** — from an automated assertion running in CI to a person performing an action and observing an outcome.

```
acceptance-criteria (Ideate)  →  bdd-feature-file (Implement/Quality)  →  uat-scenario (Customer Validation)
   the agreement                    the automated proof                    the human proof, live
```

## Specification by Example — the load-bearing principle

This is Specification by Example (Adzic) carried all the way through: the same concrete example agreed during Ideate, made executable by code during Implement, is now made executable by a human during Customer Validation. **One rule, three moments, one identifier.** The value comes from concrete, checkable examples — real file names, real personas, real values — not abstract restatements of the rule (Pugh's declarative-over-imperative discipline, one phase later).

Two rules follow directly:

- **Never re-derive the rule.** Open the source `acceptance-criteria`, take its `Given/When/Then`, and translate execution mode mechanically. If translating forces you to invent a rule the criterion never stated, that is an Ideate-phase gap to flag — not something to silently patch at UAT time.
- **Carry the same ID root.** `AC-US-005` becomes `UAT-005` so a reviewer traces forward and back without ambiguity. Once agreed, an acceptance test is not renegotiated by whoever executes it next.

## Scenario format at a glance

Every UAT scenario is Given/When/Then rewritten for a human executor:

| Gherkin element | UAT element | Written as |
|---|---|---|
| `Given` | **Context** | A checkable starting state, plain language, no system-internal detail the tester cannot verify |
| `When` | **Steps** | Numbered, one observable UI/system action per step — no jargon the persona wouldn't use |
| `Then` | **Expected Outcome** | Something visible on screen or in an export — never an internal state the tester cannot check |

Each scenario also records **preconditions and seeded test data** (what must be true before the tester starts), and an explicit **pass/fail result** with tester identity, date, and environment (the canary tenant or staging label). A `Fail` is never a bare checkbox — it opens a `feedback-template` record with an assigned severity that feeds the `acceptance-sign-off` go/no-go decision.

The full scenario template, the plain-language authoring rules, the test-data setup convention for per-tenant isolated fixtures, the severity ladder, worked scenarios (a Compliance Officer signing off an audit-ready report; a Restricted DataAsset classification), and the emitted `## Output Format` block are all in **`references/scenario-format-and-examples.md`**.

## Automated vs. human-executed — not a replacement

`bdd-feature-file` and `uat-scenario` are both Specification by Example. Neither replaces the other. A UAT scenario is never a substitute for missing automated coverage: if a Must Have behavior has no `bdd-feature-file` scenario, that is a Quality-phase gap owned by `test-strategist`, not something UAT quietly covers instead.

| | `bdd-feature-file` (automated) | `uat-scenario` (manual) |
|---|---|---|
| Executed by | CI pipeline (godog / Playwright) | A human — design partner or internal proxy |
| Runs | Every commit/PR, continuously | Once per release slice, live/live-like |
| Owner | test-strategist | requirements-analyst |
| Proves | Code satisfies the rule under controlled, repeatable conditions | The deployed release behaves correctly to a real person — including things automation cannot judge (is this useful? is the language clear?) |
| On failure | Build fails, blocks merge | Defect captured (`feedback-template`), feeds sign-off |

This is the "checking vs. testing" distinction (Crispin & Gregory): automation *checks* what was specified; both are required, and they answer different questions.

## Scripted scenarios plus exploration

A scripted UAT scenario set can only confirm rules someone already wrote down. It is structurally incapable of finding what nobody thought to specify — usability friction, unanticipated interactions, edge cases no criterion covered. That is the business-facing / critiquing-the-product quadrant (Q3 in the Agile Testing Quadrants), and it is filled not by another scenario but by a **time-boxed exploratory charter** (Hendrickson) run by the same executor, in the same environment, alongside the scripted set.

The two are complementary, not interchangeable:

- **Scripted UAT scenarios** prove the agreed Must Have rules work — pass/fail, one-to-one with acceptance criteria.
- **An exploratory charter** is a mission, not a script — it has findings, not a pass/fail, and surfaces risk the scenarios cannot by construction.

A tester who discovers an interesting edge case *outside* a scenario's Context logs it as feedback — never folds it into that scenario's result, keeping traceability to the source criterion clean. The charter format, the heuristics an executor runs down, the charter/time-box/debrief session shape, where findings route (`feedback-template`, and a recurring finding to `risk-register`), and the human-executor caveat (an agent authors the charter; a human does the exploring) are in **`references/exploratory-charter-link.md`**.

## Relationship to uat-plan and acceptance-criteria

- **`acceptance-criteria` (Ideate)** is the upstream source. A UAT scenario cites its criterion's ID and preserves its meaning exactly. `acceptance-criteria` + `bdd-feature-file` together are this repo's ATDD (pre-code) practice; `uat-scenario` is a distinct, later, human-executed validation of the *deployed* release — do not conflate the two.
- **`uat-plan` (Customer Validation)** is the campaign that owns the whole UAT effort: scope traceability across all Must Have stories, entry/exit criteria, schedule, and the executor assignment. A single `uat-scenario` is one line item in that plan; the exploratory charter above is authorized and scheduled by `uat-plan`, not by an individual scenario.

## Quality criteria

| Criterion | Pass | Fail |
|---|---|---|
| Traces to source AC | Cites its Ideate `acceptance-criteria` ID, same rule | No traceable source, or restates a different rule |
| No rule rewriting | Given/When/Then meaning matches the source exactly | Loosens, tightens, or invents behavior not in the AC |
| Plain-language steps | A non-technical tester can follow every step | Steps reference APIs, DB fields, or internal calls |
| Observable outcome | Expected Outcome is visible on screen or in an export | Describes an internal state the tester cannot check |
| Result recorded | Explicit pass/fail, tester identity, date, environment | Executed with no recorded outcome or attribution |
| Failure captured | Every `Fail` opens a `feedback-template` record with severity | Failures noted only as a checkbox with no follow-up |

## Anti-Patterns

**Writing scenarios from scratch instead of deriving them.** Inventing the language independently risks testing a different rule than what was agreed, producing two disagreeing specifications of one story.

**Engineering language in tester-facing steps.** "Verify the `sensitivity_level` field equals `restricted`" is not executable by a Compliance Officer. Steps must match the persona's literacy level.

**Treating a passing UAT scenario as license to thin the automated tests.** UAT validates once, by a human; automation validates every commit. Removing automated coverage because "UAT covers it" reintroduces regressions the next release.

**No severity discipline on failure.** Collapsing every failure into an undifferentiated "bug" breaks the sign-off decision — Critical and Low defects demand different responses (`acceptance-sign-off`).

**Silent scope expansion during execution.** An edge case found outside a scenario's Context is captured as feedback, not folded into the UAT result — the traceability to the original AC must stay clean.
