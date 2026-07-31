# Feedback Capture and Triage — Full Reference

Reference material for the `feedback-template` skill. Holds the full capture template, category and severity rubrics, the triage routing table, the pattern-vs-over-reaction aggregation matrix, worked examples, and the feedback-log output template. The decision-shaping guidance (capture fields summary, Mom-Test rules, four-step triage workflow) lives in the skill body; this file is loaded when an actual feedback log is being produced.

Context: this repo's first product is an event-driven, per-tenant-isolated data-estate and compliance platform. The two customer personas are the **Data Steward** (owns asset classification and cataloguing) and the **Compliance Officer** (owns audit readiness and access justification). Feedback arrives during Customer Validation from three sources: a `uat-scenario` failure, a `beta-program-design` structured check-in, or an ad hoc report from a design partner.

---

## Full Capture Template

Every feedback item is recorded in this exact shape so items are comparable and machine-aggregatable:

```markdown
### FB-[NNN]: [Short title]

**Source:** [UAT-[ID] failure / structured check-in / ad hoc report]
**Reporter:** [name, persona (Data Steward / Compliance Officer), company]
**Date:** [YYYY-MM-DD]

**Context — what happened:**
[Plain description of the situation the reporter was in, in their words —
 a specific past event, not a generic habit]

**Expected vs. Actual:**
- Expected: [what the reporter believed should happen]
- Actual: [what actually happened]

**Category:** [bug / UX friction / missing capability / positive signal / documentation gap]

**Severity/Impact:** [Critical / High / Medium / Low / N/A for positive signal]

**Underlying need:** [the job the reporter was trying to make progress on —
 NOT the solution they proposed; omit only for a bug or positive signal]

**Supporting detail:** [screenshot reference, the story/scenario ID it relates
 to, any reproduction steps the reporter gave]

**Routed to:** [owning agent, from the routing table below]
**Aggregation note:** [pattern status, if this item is one of several]
```

The **Underlying need** field is what converts a stated request into its real job before triage — see `references/mom-test-question-design.md` for the elicitation technique that fills it, and `jtbd-analysis` for the job-story format it feeds.

---

## Category Definitions

| Category | Definition |
|---|---|
| **Bug** | The system does something the acceptance criteria or specification says it should not — a defect against an existing rule |
| **UX friction** | The system works as specified but is confusing, slow to use, or requires unnecessary effort to accomplish the task |
| **Missing capability** | The reporter needed something the product does not do at all — not a defect, a gap |
| **Positive signal** | Something worked well enough that the reporter called it out unprompted — valuable evidence, not merely an absence of complaints |
| **Documentation gap** | The reporter could not find or understand guidance for a step they needed to take |

A **positive signal** is captured with the same rigor as a complaint. A feedback log that contains only problems biases the `acceptance-sign-off` record toward negativity and discards the evidence that a Must Have flow actually works for a real user — which is exactly the usability confirmation a sign-off needs.

---

## Severity/Impact Rubric

Applied identically across all three feedback sources, the same scale `uat-scenario` uses for defect severity:

| Severity | Definition |
|---|---|
| **Critical** | Must Have behavior does not work at all, or causes data loss / security or tenant-isolation exposure |
| **High** | Must Have behavior works incorrectly in a way that affects the core outcome |
| **Medium** | Works but with friction, confusing wording, or a minor edge-case error |
| **Low** | Cosmetic or negligible impact |

**Severity is assigned once, at capture, from the reporter's actual impact.** Adjusting it after the fact — inflating to force attention, or deflating to make an exit-criteria pass rate look better — undermines the entire purpose of `acceptance-sign-off`. A tenant-isolation leak reported by one Compliance Officer is Critical on the strength of that one report; no frequency threshold applies to it.

---

## Triage Routing Table

Every captured item is routed to exactly one owning agent within one business day of capture (faster for Critical/High per the beta agreement's response SLA):

| Category | Routes to | Why |
|---|---|---|
| Bug (backend behavior) | `backend-engineer` | Owns the Go/chi/pgx services and domain logic the bug violates |
| Bug (frontend behavior) | `frontend-engineer` | Owns the React+TypeScript microfrontend the bug manifests in |
| UX friction | `ux-architect` | Owns interaction and flow design; friction is a design concern even when nothing is technically broken |
| Missing capability | `product-strategist` | A scope/roadmap decision, not a defect — enters roadmap consideration, does not silently become a Must Have for the current release |
| Documentation gap | requirements-analyst (this agent) | Owns discovery and validation artifacts; clarity of the customer-facing guidance is validated here |
| Positive signal | Logged, no routing | Retained as evidence for `acceptance-sign-off` and as roadmap validation, not actioned as a defect |

The requirements-analyst captures, interprets, classifies, and routes — it never resolves the bug or UX issue itself. Resolution ownership stays with the domain agent named above, consistent with each agent's declared Owns / Does-not-own boundary.

---

## Aggregation: Pattern vs. Over-Reaction

A single report is a data point. A **pattern** is multiple *independent* reports converging on the same underlying cause. Conflating the two either over-reacts to noise or under-reacts to a real signal.

**Frequency/Severity matrix:**

| | Single report | Multiple independent reports (pattern) |
|---|---|---|
| **Low / Medium severity** | Log; track for the next release's backlog consideration | Elevate for remediation-plan consideration in `acceptance-sign-off` — frequency itself is now evidence of impact, even though individual severity is low |
| **High / Critical severity** | Treat as blocking regardless of frequency — one report of data loss is enough | Blocks unconditionally; the pattern confirms rather than changes the response |

**Rules for calling something a pattern:**

- **Independent reporters.** The same participant repeating themselves across sessions is one persistent concern, not a pattern.
- **Same underlying cause, not merely similar symptoms.** Two participants confused by different screens for different reasons are two single reports.
- **Named explicitly in the sign-off record** — "3 of 3 design partners independently found the gap report's PDF export button below the fold" — rather than left as a count buried in a table.

**The over-reaction trap:** one participant's strong reaction to a Low-severity item ("I hate this button placement") must not trigger a scope change on its own. Log it, watch for a second independent report, and let the aggregation discipline do its job rather than reacting to the loudest single voice. This is the frequency counterpart to the compliments failure mode in `references/mom-test-question-design.md`: intensity of language is not evidence of impact.

---

## Worked Example — Three Items, Triaged

```markdown
### FB-001: Gap report PDF export is hard to find
**Source:** Structured check-in — Northwind Compliance Co.
**Reporter:** Maya Chen, Compliance Officer
**Context:** Maya was preparing for an internal audit meeting and needed to
  share the gap report. She scrolled the full report page before finding the
  export option below the fold.
**Expected vs. Actual:** Expected an obvious way to export near the top;
  actual — export control is below the report content, easy to miss.
**Category:** UX friction
**Severity/Impact:** Medium
**Underlying need:** get an audit-ready gap report out of the tool and into an
  audit meeting quickly, without hunting for the control.
**Routed to:** ux-architect

### FB-002: Gap report PDF export is hard to find
**Source:** Ad hoc report — Ridgeline Analytics
**Reporter:** compliance lead, Compliance Officer
**Context:** Independently reported the same difficulty locating the export
  action, same week, no contact with Northwind's team.
**Category:** UX friction
**Severity/Impact:** Medium
**Routed to:** ux-architect
**Aggregation note:** FB-001 and FB-002 are now a confirmed pattern (2 of 3
  design partners, independent, same root cause) — elevated for remediation-
  plan consideration in the release's `acceptance-sign-off`, even though
  individual severity remains Medium.

### FB-003: Classification panel clearly explains why an asset is Restricted
**Source:** Structured check-in — Harborview Legal Group
**Reporter:** compliance lead, Compliance Officer
**Context:** Reporter called out, unprompted, that seeing the PII tag and the
  access-gate explanation together made it obvious why an asset needed
  Restricted handling — said it would help her justify access decisions to
  her own leadership.
**Category:** Positive signal
**Severity/Impact:** N/A
**Routed to:** Logged as evidence for acceptance-sign-off; no action required.
```

---

## Output Format — Feedback Log

```markdown
---
name: feedback-log-[release-slice]
product: [product name]
version: 1.0.0
phase: customer-validation
created: [date]
owner: requirements-analyst
---

# Feedback Log — [release-slice]

## Items

### FB-[NNN]: [title]
**Source:** ...
**Reporter:** ...
**Context — what happened:** ...
**Expected vs. Actual:** ...
**Category:** ...
**Severity/Impact:** ...
**Underlying need:** ...
**Routed to:** ...

## Aggregation Summary
| Pattern | Reports | Reporters (independent) | Severity | Status |
|---|---|---|---|---|

## Positive Signals
[List, retained as evidence for acceptance-sign-off]
```

The Aggregation Summary is where a pattern is named for the sign-off record, and the Positive Signals section is where usability confirmation is preserved rather than discarded for lacking an action item.
