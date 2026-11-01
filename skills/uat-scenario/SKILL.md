---
name: uat-scenario
description: >
  Teaches how to write UAT scenarios: the human-executed, live-environment
  form of a Must story's agreed acceptance criteria. Covers translating
  Given/When/Then into plain-language Context, numbered Steps and an Expected
  Outcome the tester can see, without inventing or softening the rule;
  business scenarios that follow a whole piece of work; the 1:N ID convention
  (AC-US-5 to UAT-5a, UAT-5b); preconditions and named seeded test data,
  per-tenant fixtures and recorded environment and flag state; recording each
  result as Pass, Fail, Blocked or Not run with tester, date, environment and
  evidence; on a Fail, a defect record with workaround and re-test; and
  logging a stray finding as feedback instead of folding it into the result.
  Use when writing or reviewing UAT scenarios or UAT test scripts, turning
  acceptance criteria into steps a business user can run, recording UAT
  results, deciding what to do with a scenario that could not run or a bug
  found outside the scenario, or scaling scenarios for lean, standard or
  enterprise products. Used by the requirements-analyst agent in Customer
  Validation (/sdlc-validate), after uat-plan and before acceptance-sign-off;
  written to customer-validation/uat-scenarios/.
version: 3.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-07-20
tags: [validation, uat, acceptance-testing, given-when-then, specification-by-example, business-scenarios, test-results]
produces: uat-scenario
domain: validation
status: stable
related: [uat-plan, acceptance-criteria, bdd-feature-file, feedback-template, acceptance-sign-off, example-mapping, glossary-management, methodology-review]
sources:
  - research/testing/user-acceptance-testing-hambling.md
  - research/testing/specification-by-example-adzic.md
  - research/requirements-and-user-stories/lean-agile-atdd-pugh.md
  - research/testing/agile-testing-crispin-gregory.md
  - research/testing/explore-it-hendrickson.md
---

# UAT Scenario

## Purpose

A UAT scenario is a script a business user follows in the deployed (canary or live-like) environment to confirm the release does what was agreed. It starts from a Must story's agreed `acceptance-criteria` and changes only the **execution mode**: from an automated check in CI (`bdd-feature-file`) to a person doing real work and looking at the result.

```
acceptance-criteria (Ideate)  →  bdd-feature-file (Implement, Quality)  →  uat-scenario (Customer Validation)
    the agreement                    the automated check                     the human proof, live
```

It answers one question per scenario: *can the person this story was written for do this piece of work, and does the outcome match what we agreed?*

## What this skill does not cover

- Scope, roles, the independence level, entry and exit criteria, schedule, exploratory charters and the acceptance types in scope: `uat-plan`. Exploration is **not** a scenario. Its charter, session and debrief formats live in `uat-plan`.
- The severity scale, triage and routing of a defect or a stray finding: `feedback-template`.
- What an open defect allows at sign-off: the single defect rule in `acceptance-sign-off`. It is never restated here. When someone asks what a defect allows, read that rule and give it whole, every severity it covers, not only the one asked about, and name `acceptance-sign-off` as where it lives.
- Automated acceptance checks: `bdd-feature-file` (test-strategist). A UAT scenario never stands in for a missing automated check.

## The rules that shape every scenario

**1. Translate, never re-derive (Pugh; Adzic).** The agreed acceptance test is a contract: once agreed, it is not renegotiated by whoever executes it next (Pugh, *Lean-Agile ATDD*). Take the criterion's Given/When/Then and translate the execution mode only. If the translation forces you to invent a rule, or a user asks you to soften one ("just check the report opens"), stop: that is a change to the acceptance criterion, and it goes back to the product owner through the loop that created it. Flag it; do not patch it in the scenario.

**2. Business language, observable outcome (Pugh; Adzic).** Given/When/Then illustrates a business rule; it is not a script for the machinery (Adzic, *Specification by Example*). Steps use words the user would use, one action each. The Expected Outcome is something the tester can **see**: a screen, a message, an exported file, an email. A criterion written as `Then sensitivity_level = 'restricted'` becomes "the file shows the label Restricted". A database value, an API response or an event on a topic is never an expected outcome, because the tester cannot check it. Keep the technical wording out of the scenario entirely, notes beside a line included: the `Traces to:` line is the link to the criterion, and the criterion keeps its own wording. If no visible proxy exists, that is a gap to flag to the product owner, not a step to fake.

**3. Business scenarios, traced both ways (Hambling).** UAT owns its test basis: business requirements and how the work is actually done, not the technical specification (Hambling, *User Acceptance Testing*). Write each scenario around a realistic piece of work that crosses screens ("a planner closes today's orders"), then confirm every acceptance criterion of every Must story is covered by at least one scenario. Never copy system-test scripts into UAT: re-running them with a user at the keyboard adds no new information.

**4. One criterion, one or more scenarios: the 1:N ID convention.** IDs keep the story's number root and add a letter per scenario: `AC-US-5` → `UAT-5a`, `UAT-5b`. Always add the letter, even for one scenario, so adding a second never renames the first. Each scenario isolates one rule (Pugh: several small examples over one combinatorial one) and uses the minimum set of examples that pins the rule down (Adzic's key examples).

**5. Real, named test data.** Specification by Example depends on concreteness: "invoice INV-2041, €1,200, due 3 March" is checkable; "an invoice" is not. Each scenario lists its preconditions and seeded fixtures, and how the tester confirms each one before starting. On a multi-tenant product, every fixture names its tenant, and a scenario that proves isolation seeds data in **two** tenants and checks that one cannot see the other's. Record the environment (tenant, region, build) and any feature-flag state the outcome depends on, so a failure can be reproduced.

**6. Four results, with evidence (Hambling).** Every scenario ends with exactly one result:

| Result | Meaning | Counts as passed? |
|---|---|---|
| **Pass** | Every expected outcome observed | Yes |
| **Fail** | An expected outcome not observed | No; opens a defect record |
| **Blocked** | Could not run: an environment problem or an earlier defect, with the reason | No, until re-run |
| **Not run** | Not attempted in this window | No, until run |

A scenario that could not run is never marked Pass "so it doesn't hold us up": that hides it and overstates readiness. Each result carries tester, date, environment and evidence (a screenshot or recording), so a later reviewer can re-judge it without trusting the executor. This evidence matters most under `uat-plan`'s solo-operator exception, where the tester and the approver are the same person.

**7. A Fail opens a defect record; a fix is re-tested.** Each Fail opens a `feedback-template` record. Severity (business impact, on `feedback-template`'s scale) is set once, at capture, from what the tester saw, never bargained down later. Priority (how urgently to fix) is separate. The record carries a workaround a business user could follow, because a conditional sign-off needs one for every open High. A fix counts only when the scenario is re-run and passes: the re-run records `Re-test of:` the failed run, and the neighbouring scenarios are re-checked. "Deployed" is not "fixed".

**8. Checking is not testing; stray findings go to feedback (Crispin and Gregory; Hendrickson).** A scripted scenario *checks* what was specified. It cannot find what nobody wrote down, which is why `uat-plan` pairs scenarios with exploratory charters run by a human (Crispin and Gregory, *Agile Testing*; Hendrickson, *Explore It!*). A bug the tester trips over outside the scenario's Context is logged as its own `feedback-template` item and listed under the scenario's *Found outside this scenario* line. It never changes this scenario's result. Folding it in breaks the trace to the acceptance criterion.

## Scale: what changes by profile

| | lean | standard | enterprise |
|---|---|---|---|
| Scenarios | One per Must criterion, usually | 1:N where the work crosses screens or roles | 1:N, plus per-tenant isolation and per-region variants where the Must depends on them |
| Test data | Named records in the one environment | Named fixtures per partner tenant, seeded before the window | Per-tenant, per-region fixtures; flag state and build recorded per run |
| Evidence | One screenshot per result | Screenshot per result; recording for any Fail | Screenshot or recording per result, kept with the sign-off evidence |

The rules above never relax with the profile. Only the volume does.

## Applying This Skill

1. **Read** the Must stories' `acceptance-criteria` and `uat-plan`'s scope traceability, roles and environment. Without a plan, stop and ask for one.
2. **Draft** the scenarios in `./templates/uat-scenarios.md`, one file per Must story, at `artifacts/<product>/customer-validation/uat-scenarios/US-<n>.md`. For the translation table, plain-language rules, fixtures, flag state and the defect fields, read `./references/authoring-rules.md`.
3. **Compare** with an example at the product's profile: `./examples/01-lean-lunch-orders.md` (one criterion, one scenario), `./examples/02-standard-invoice-export.md` (1:N, seeded partner fixtures, a Fail with workaround and re-test), or `./examples/03-enterprise-tenant-isolation.md` (two-tenant isolation, flag state, a Blocked result, a stray finding).
4. **Validate** against `./resources/uat-scenario-checklist.md` and run `python3 ./scripts/check-uat-scenarios.py <file>` on each file. If you cannot run it, walk the checklist by hand.
5. **Hand off**: defects and stray findings to `feedback-template`; the recorded results to `uat-plan`'s completion summary and then `acceptance-sign-off`. Any acceptance criterion that could not be translated without a new rule goes back to the product owner.

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Writing scenarios from scratch** | Tests a different rule from the one agreed; two specs now disagree |
| **Softening the criterion while translating** | Renegotiates the contract at execution time; the change bypasses the product owner |
| **Engineering words in steps** (`PATCH`, field names, SQL) | The intended user cannot run it; an internal value is not observable |
| **System-test scripts reused as UAT** | Adds no information; misses the end-to-end work the business does |
| **"An invoice", "a user"** | Not checkable; not reproducible |
| **Blocked or Not run marked Pass** | Overstates readiness; hides the scenarios nobody ran |
| **A stray bug folded into the result** | Breaks traceability; the scenario now fails for a reason the criterion never stated |
| **Severity bargained after capture** | Makes the sign-off numbers lie |
| **A restated defect bar** | A second rule that drifts from `acceptance-sign-off`'s |
| **"Fixed" without a re-run** | A deploy is not evidence |
