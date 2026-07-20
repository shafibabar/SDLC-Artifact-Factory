---
name: uat-scenario
description: >
  Teaches how to write a UAT scenario — the human-executed counterpart to the
  Ideate phase's Gherkin acceptance criteria and the Implement phase's
  automated `bdd-feature-file` scenarios. Covers the scenario format (context,
  plain-language steps, expected observable outcome, pass/fail recording),
  the explicit distinction between automated and manual execution modes for
  the same underlying rule, defect capture on failure feeding
  `feedback-template`, and traceability back to the original user story and
  its acceptance criteria without rewriting the rule. Used by the
  requirements-analyst during Customer Validation.
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-07-20
tags: [customer-validation, uat, acceptance-testing, gherkin, specification-by-example, traceability]
---

# UAT Scenario

## Purpose

A UAT scenario takes an existing Ideate-phase Gherkin acceptance criterion (`acceptance-criteria`) and restates it as a script a non-technical human can follow, in the live or live-like environment, to confirm the deployed release actually does what was agreed. It does not invent new rules. It does not rewrite the rule the acceptance criterion already stated. It changes only the **execution mode** — from an automated assertion running in CI to a person performing an action and observing an outcome.

This is Specification by Example carried all the way through: the same example that was agreed during Ideate, made executable by code during Implement (`bdd-feature-file`), is now made executable by a human during Customer Validation. One rule, three moments, one identifier.

```
acceptance-criteria (Ideate)  →  bdd-feature-file (Implement/Quality)  →  uat-scenario (Customer Validation)
   the agreement                    the automated proof                    the human proof, live
```

---

## Automated vs. Human-Executed — Not a Replacement

`bdd-feature-file` and `uat-scenario` are both Specification by Example. Neither replaces the other, and a UAT scenario is never written as a substitute for missing automated test coverage — if a Must Have behavior has no `bdd-feature-file` scenario, that is a Quality-phase gap owned by `test-strategist`, not something UAT quietly covers instead.

| | `bdd-feature-file` (automated) | `uat-scenario` (manual) |
|---|---|---|
| **Executed by** | CI pipeline (godog / Playwright) | A human — design partner or internal proxy |
| **Runs** | On every commit/PR, continuously | Once per release slice, against a live/live-like environment |
| **Owner** | test-strategist | requirements-analyst |
| **Phase** | Implement, Quality | Customer Validation |
| **Proves** | The code satisfies the rule under controlled, repeatable conditions | The deployed release behaves correctly to a real person, in real conditions, including things automation cannot judge (is this actually useful? is the language clear to Maya?) |
| **Environment** | Test containers / ephemeral CI environment | Canary tenant or staging (`canary-deployment`, `environment-config`) |
| **On failure** | Build fails, blocks merge | Defect captured (`feedback-template`), feeds `acceptance-sign-off` decision |

A UAT scenario existing for a story does not mean its `bdd-feature-file` scenario can be skipped, and vice versa. Both are required; they answer different questions.

---

## Format

Every UAT scenario carries the **same ID root** as the acceptance criterion it extends (`AC-US-005` → `UAT-005`), so a reviewer can trace forward and back without ambiguity.

```markdown
### UAT-[NNN]: [Short title, plain language]

**Traces to:** AC-[US-ID] — [criterion title] (`acceptance-criteria`)
**Persona:** [Who performs this — matches the story's persona]

**Context (Given):**
[The starting state, in plain language a non-technical tester can verify is true before starting — no code, no API calls]

**Steps (When):**
1. [Exact action, numbered, one observable UI/system interaction per step]
2. [Next action]
3. ...

**Expected Outcome (Then):**
[What the tester should see, read, or receive — described at the level a screenshot could confirm]

**Result:**
- [ ] Pass
- [ ] Fail — defect ID: ______ (see `feedback-template`)

**Tester:** [name] · **Date:** [date] · **Environment:** [tenant id / staging label]
```

**Rules for writing the plain-language steps:**
- No jargon the persona wouldn't use — write "classify the file as Restricted," not "PATCH the sensitivity_level field"
- One observable action per step; if the acceptance criterion's `When` had one action, the UAT step has one action too
- The expected outcome must be something the tester can literally see on screen or in an exported artifact — never an internal system state the tester has no way to check

---

## Deriving a UAT Scenario from Its Acceptance Criterion — the Rule

Do not re-derive the rule. Open the source `acceptance-criteria` file, take the `Given/When/Then`, and translate mechanically:

| Gherkin element | UAT scenario element | Translation rule |
|---|---|---|
| `Given` | Context | Restate as a checkable starting condition; drop any system-internal detail the tester cannot verify |
| `When` | Steps | Decompose into the literal UI/system actions a human performs to trigger that action |
| `Then` | Expected Outcome | Restate as what appears on screen, in a report, or in an export — never an internal state |
| `And`/`But` | Additional Steps / Outcome lines | Carried over unchanged in meaning |

If translating an acceptance criterion into a UAT scenario requires inventing a new rule the criterion didn't state, the criterion itself was incomplete — that is an Ideate-phase gap to flag, not something to silently patch at UAT time.

---

## Defect Capture on Failure

A `Fail` result is never left as a bare checkbox. It immediately opens a feedback record via `feedback-template`, classified for severity:

| Severity | Definition | Effect on sign-off |
|---|---|---|
| Critical | Must Have behavior does not work at all, or causes data loss / security exposure | Blocks `acceptance-sign-off` — no conditional path |
| High | Must Have behavior works incorrectly in a way that affects the core outcome | Blocks `acceptance-sign-off` unless remediated before sign-off |
| Medium | Behavior works but with friction, confusing wording, or a minor incorrect edge case | May be shipped under a conditional sign-off with a remediation plan |
| Low | Cosmetic or negligible impact | Logged, does not block sign-off |

The severity is assigned by the facilitator (requirements-analyst) at the moment of capture, using the tester's description of impact — not negotiated down to make numbers look better before sign-off.

---

## Worked Example — Classifying a Restricted DataAsset

Source acceptance criterion (`acceptance-criteria`, story US-005):

```gherkin
Given a DataAsset "Q3_Payroll.xlsx" has been scanned and the extraction pipeline
  detected a national ID number at confidence above the review threshold,
When the Compliance Officer opens the asset's classification panel,
Then the asset is shown with sensitivity level "Restricted"
And the detected special category "PII" is displayed
And the asset requires ABAC least-privilege access before it can be opened.
```

Derived UAT scenario:

```markdown
### UAT-005: Restricted DataAsset shows correct classification and access gate

**Traces to:** AC-US-005 — Automatic classification escalates to Restricted (`acceptance-criteria`)
**Persona:** Compliance Officer (Maya Chen)

**Context (Given):**
The file "Q3_Payroll.xlsx" has already been scanned by the platform (visible in the
Assets list with a "Scanned" status) and is known to contain a national ID number.

**Steps (When):**
1. Open the Data Estate dashboard.
2. Locate "Q3_Payroll.xlsx" in the Assets list and click into it.
3. Open the Classification panel for the asset.

**Expected Outcome (Then):**
- The Sensitivity Level shown is "Restricted."
- The "PII" special category tag is visible on the panel.
- Attempting to open the file's contents without the Restricted-access permission
  shows an access-denied message naming the required permission.

**Result:**
- [x] Pass
- [ ] Fail — defect ID: ______

**Tester:** Maya Chen · **Date:** 2026-07-22 · **Environment:** tenant-northwind
```

Nothing here restates or loosens the rule from AC-US-005 — the `max` classification logic, the PII tag, and the access gate are exactly what the criterion specified. Only the execution mode changed: a human clicking through the dashboard instead of a godog step function calling the API directly.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Traces to source AC | Every UAT scenario cites its Ideate `acceptance-criteria` ID, same rule | UAT scenarios with no traceable source, or restating a different rule |
| No rule rewriting | Given/When/Then content matches the source criterion's meaning exactly | UAT scenario loosens, tightens, or invents behavior not in the original AC |
| Plain-language steps | A non-technical tester can follow every step without engineering knowledge | Steps reference APIs, database fields, or internal system calls |
| Observable outcome | Expected Outcome is something visible on screen or in an export | Expected Outcome describes an internal state the tester cannot check |
| Pass/fail recorded | Every scenario has an explicit result, tester identity, and date | Scenarios executed with no recorded outcome or attribution |
| Failure triggers defect capture | Every Fail opens a `feedback-template` record with severity | Failures noted only as a checkbox with no follow-up record |

---

## Anti-Patterns

**Writing UAT scenarios from scratch instead of deriving them.** Skipping the source acceptance criterion and inventing the scenario language independently risks testing a different rule than what was actually agreed — and produces two disagreeing specifications of the same story.

**Engineering language in tester-facing steps.** "Verify the `sensitivity_level` field equals `restricted`" is not something Maya Chen can execute. Steps must be written at the persona's literacy level, matching how `acceptance-criteria` already insists Then-statements be observer-friendly.

**Treating a passing UAT scenario as proof the automated tests can be thinner.** UAT is not a substitute for `bdd-feature-file` coverage — it validates the deployed release once, by a human; automation validates every commit, continuously. Removing automated coverage because "UAT covers it" reintroduces regressions the very next release.

**No severity discipline on failure.** Recording every failure as the same undifferentiated "bug" collapses the sign-off decision — Critical and Low defects require completely different responses (see `acceptance-sign-off`).

**Silent scope expansion during execution.** A tester who discovers an interesting edge case outside the scenario's Given should have it captured as feedback (`feedback-template`), not silently folded into the UAT-005 result — the traceability to the original AC must stay clean.

---

## Output Format

```markdown
---
name: uat-scenarios-[US-ID]
product: [product name]
story-id: US-[ID]
version: 1.0.0
phase: customer-validation
created: [date]
owner: requirements-analyst
---

# UAT Scenarios: US-[ID] — [Story title]

## Story Reference
As a [Persona], I want to [action], so that [outcome].

### UAT-[NNN]: [Short title]
**Traces to:** AC-[US-ID]
**Persona:** [persona]

**Context (Given):** [plain language]

**Steps (When):**
1. ...

**Expected Outcome (Then):** [observable outcome]

**Result:**
- [ ] Pass
- [ ] Fail — defect ID: ______

**Tester:** [name] · **Date:** [date] · **Environment:** [tenant/staging]
```
