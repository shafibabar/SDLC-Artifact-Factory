# UAT Scenario — Format, Authoring Rules, Test Data, and Worked Examples

Reference material for the `uat-scenario` skill. The SKILL.md body carries the decision-shaping principles (Specification by Example, no rule re-derivation, same-ID traceability, the automated-vs-manual split, the pass/fail-and-defect rule, the exploratory pairing). This file holds the full authoring mechanics and complete worked scenarios grounded in the data-estate / compliance platform.

---

## The full scenario template

A single UAT scenario is written as a self-contained block a non-technical executor can follow end to end:

```markdown
### UAT-[NNN]: [Short title, plain language]

**Traces to:** AC-[US-ID] — [criterion title] (`acceptance-criteria`)
**Persona:** [Who performs this — matches the story's persona, e.g. Data Steward, Compliance Officer]

**Preconditions / Test data:**
- [Each fact the tester must be able to confirm is true before starting]
- [Each seeded fixture — named file, tenant, prior state — that must already exist]

**Context (Given):**
[The starting state, in plain language a non-technical tester can verify — no code, no API calls]

**Steps (When):**
1. [Exact action, numbered, one observable UI/system interaction per step]
2. [Next action]
3. ...

**Expected Outcome (Then):**
- [What the tester should see, read, or receive — at the level a screenshot could confirm]
- [Additional And/But outcome lines, carried over unchanged in meaning from the source criterion]

**Result:**
- [ ] Pass
- [ ] Fail — defect ID: ______ (see `feedback-template`)

**Tester:** [name] · **Date:** [date] · **Environment:** [tenant id / staging label]
```

The `### UAT-[NNN]` heading uses the **same numeric root** as the source `AC-US-[NNN]`, so `AC-US-005` and `UAT-005` line up one-to-one for forward/back tracing.

---

## Translating Gherkin into a UAT scenario — the mechanical mapping

Do not re-derive the rule. Open the source `acceptance-criteria` file, take its `Given/When/Then`, and translate only the execution mode:

| Gherkin element | UAT scenario element | Translation rule |
|---|---|---|
| `Given` | Context | Restate as a checkable starting condition; drop any system-internal detail the tester cannot verify from the UI or an export |
| `When` | Steps | Decompose into the literal UI/system actions a human performs to trigger that action — one action per numbered step |
| `Then` | Expected Outcome | Restate as what appears on screen, in a report, or in an export — never an internal state |
| `And` / `But` | Additional Steps / Outcome lines | Carried over unchanged in meaning |

If translating an acceptance criterion into a UAT scenario requires inventing a new rule the criterion did not state, the criterion itself was incomplete — that is an Ideate-phase gap to flag to the `requirements-analyst`, not something to silently patch at UAT time.

### Plain-language authoring rules for the steps

- **No jargon the persona wouldn't use** — write "classify the file as Restricted," not "PATCH the `sensitivity_level` field."
- **One observable action per step** — if the acceptance criterion's `When` had one action, the UAT step has one action too.
- **The Expected Outcome must be literally observable** — something the tester can see on screen or in an exported artifact (a downloaded PDF, an on-screen banner, a status chip). Never an internal system state the tester has no way to check.
- **Declarative, not imperative about internals** — describe the business outcome ("the report is marked audit-ready and can be exported"), not the plumbing that produced it.

---

## Preconditions and test-data setup

A UAT scenario runs against a **live or live-like environment** — a canary tenant or staging, per `uat-plan`. Because this platform uses **per-tenant physical isolation**, the test data for a scenario lives inside a dedicated UAT tenant whose fixtures are seeded before execution and never shared with a production tenant.

Setup discipline:

- **Name the tenant explicitly** in the `Environment` field (e.g. `tenant-northwind-uat`) so a failure is reproducible and a reviewer knows exactly which isolated dataset was exercised.
- **Seed real-feeling fixtures, not placeholders.** A scenario that says "a file has been scanned" needs a *named* file already present in that tenant's Assets list with the correct prior state (Scanned, classified, connected to Google Drive / S3 as the story requires). Specification by Example depends on the concreteness — "Q3_Payroll.xlsx, scanned, containing a national ID number" is checkable; "a file" is not.
- **List every precondition the tester must confirm before starting.** If a precondition cannot be visually confirmed by the tester (an internal pipeline ran, an event was published to Redpanda), restate it as its observable proxy (the asset shows a "Scanned" status chip) — the tester verifies the proxy, not the internal event.
- **Isolate the variable under test.** One scenario exercises one rule; do not fold three rules into one long click-path. Prefer several small scenarios that each isolate one behavior over one combinatorial mega-scenario.

---

## Pass / fail recording and the severity ladder

Every scenario ends with an explicit result — a bare, unrecorded execution is a defect in the process. The result carries **tester identity, date, and environment** so the outcome is attributable and reproducible.

A `Fail` immediately opens a feedback record via `feedback-template`, classified for severity at the moment of capture by the facilitator (`requirements-analyst`) using the tester's description of impact — never negotiated down to make the sign-off numbers look better:

| Severity | Definition | Effect on `acceptance-sign-off` |
|---|---|---|
| Critical | A Must Have behavior does not work at all, or causes data loss / security exposure | Blocks sign-off — no conditional path |
| High | A Must Have behavior works incorrectly in a way that affects the core outcome | Blocks sign-off unless remediated before sign-off |
| Medium | Behavior works but with friction, confusing wording, or a minor incorrect edge case | May ship under a conditional sign-off with a remediation plan |
| Low | Cosmetic or negligible impact | Logged; does not block sign-off |

---

## Worked example 1 — Compliance Officer signs off an audit-ready report

**Source acceptance criterion** (`acceptance-criteria`, story US-012):

```gherkin
Given a compliance report has been generated for tenant "Northwind" covering all
  Restricted DataAssets discovered in the last scan cycle,
When the Compliance Officer reviews the report and marks it as reviewed,
Then the report is stamped "Audit-Ready" with the reviewer's name and timestamp,
And the report can be exported as a PDF that carries the Audit-Ready stamp,
And the exported PDF lists every Restricted DataAsset with its detected special category.
```

**Derived UAT scenario:**

```markdown
### UAT-012: Compliance Officer marks a report Audit-Ready and exports it

**Traces to:** AC-US-012 — Compliance report reaches Audit-Ready state (`acceptance-criteria`)
**Persona:** Compliance Officer (Maya Chen)

**Preconditions / Test data:**
- A compliance report for the current scan cycle already exists in tenant-northwind-uat
  and is visible in the Reports list with status "Draft."
- The report covers at least two Restricted DataAssets (e.g. "Q3_Payroll.xlsx" and
  "Contracts_2026.pdf"), each already carrying a detected special category (PII, financial).

**Context (Given):**
The compliance report for Northwind's latest scan cycle is listed under Reports with a
"Draft" status, and lists the Restricted assets found in that cycle.

**Steps (When):**
1. Open the Reports section of the Data Estate dashboard.
2. Open the Draft compliance report for the current scan cycle.
3. Review the listed Restricted DataAssets, then click "Mark as Reviewed."
4. Click "Export as PDF" and open the downloaded file.

**Expected Outcome (Then):**
- The report's status changes to "Audit-Ready" and shows "Reviewed by Maya Chen"
  with the current date and time.
- The downloaded PDF carries a visible "Audit-Ready" stamp with the reviewer name.
- The PDF lists both Restricted DataAssets, each with its special-category label.

**Result:**
- [x] Pass
- [ ] Fail — defect ID: ______

**Tester:** Maya Chen · **Date:** 2026-07-24 · **Environment:** tenant-northwind-uat
```

Nothing here loosens or invents rule content — the Audit-Ready stamp, the reviewer attribution, the PDF export, and the per-asset special-category listing are exactly what AC-US-012 specified. Only the execution mode changed: a human reviewing and exporting through the dashboard instead of a godog step calling the report API directly. Note the outcome is entirely observable — an on-screen status, a name-and-timestamp, a downloadable PDF a PM can open — never an internal report-state flag.

---

## Worked example 2 — Restricted DataAsset classification and access gate

**Source acceptance criterion** (`acceptance-criteria`, story US-005):

```gherkin
Given a DataAsset "Q3_Payroll.xlsx" has been scanned and the extraction pipeline
  detected a national ID number at confidence above the review threshold,
When the Compliance Officer opens the asset's classification panel,
Then the asset is shown with sensitivity level "Restricted"
And the detected special category "PII" is displayed
And the asset requires ABAC least-privilege access before it can be opened.
```

**Derived UAT scenario:**

```markdown
### UAT-005: Restricted DataAsset shows correct classification and access gate

**Traces to:** AC-US-005 — Automatic classification escalates to Restricted (`acceptance-criteria`)
**Persona:** Compliance Officer (Maya Chen)

**Preconditions / Test data:**
- "Q3_Payroll.xlsx" is already present in tenant-northwind-uat's Assets list with a
  "Scanned" status and is known to contain a national ID number.
- The signed-in reviewer does NOT hold the Restricted-access permission (to prove the gate).

**Context (Given):**
The file "Q3_Payroll.xlsx" has already been scanned by the platform (visible in the Assets
list with a "Scanned" status) and is known to contain a national ID number.

**Steps (When):**
1. Open the Data Estate dashboard.
2. Locate "Q3_Payroll.xlsx" in the Assets list and click into it.
3. Open the Classification panel for the asset.
4. Attempt to open the file's contents.

**Expected Outcome (Then):**
- The Sensitivity Level shown is "Restricted."
- The "PII" special-category tag is visible on the panel.
- Opening the file's contents without the Restricted-access permission shows an
  access-denied message naming the required permission.

**Result:**
- [x] Pass
- [ ] Fail — defect ID: ______

**Tester:** Maya Chen · **Date:** 2026-07-22 · **Environment:** tenant-northwind-uat
```

The `max`-classification logic, the PII tag, and the ABAC access gate are exactly what AC-US-005 specified — the UAT scenario proves them to a human without restating or loosening the rule. The access-gate step is written as an *observable* denial (a message naming the required permission), not as an assertion about internal ABAC policy evaluation.

---

## Emitted artifact — the `## Output Format`

A `uat-scenarios-[US-ID]` artifact groups all scenarios for one story under its story reference:

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

**Preconditions / Test data:** [seeded fixtures, tenant, prior state]

**Context (Given):** [plain language]

**Steps (When):**
1. ...

**Expected Outcome (Then):** [observable outcome]

**Result:**
- [ ] Pass
- [ ] Fail — defect ID: ______

**Tester:** [name] · **Date:** [date] · **Environment:** [tenant/staging]
```

The emitted artifact uses the key `name:` (never `artifact:`), carries the canonical frontmatter fields, and stays reviewable by a PM in plain Markdown with no IDE tooling.

---

## Quality checklist for a finished scenario set

- Every scenario cites its Ideate `acceptance-criteria` ID and preserves the source rule exactly.
- Every step is executable by the named persona with no engineering knowledge.
- Every Expected Outcome is visible on screen or in an export.
- Every scenario names its seeded fixtures and its isolated UAT tenant.
- Every scenario has an explicit pass/fail result with tester, date, and environment.
- Every `Fail` links to a `feedback-template` record with an assigned severity.
