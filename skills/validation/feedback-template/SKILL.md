---
name: feedback-template
description: >
  Teaches how to capture, classify, and triage feedback gathered during
  Customer Validation — a structured capture format (context, expected vs
  actual, severity/impact, category), anti-leading-question guidance for
  facilitated sessions, a triage routing table from category to owning
  agent, and the aggregation discipline that distinguishes a real pattern
  across multiple reports from a single-report over-reaction. Used by the
  requirements-analyst during Customer Validation.
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-07-20
tags: [customer-validation, feedback, triage, severity, beta-program, uat]
---

# Feedback Template

## Purpose

Feedback gathered during UAT execution (`uat-scenario`) and the beta program's check-ins (`beta-program-design`) is only useful if it is captured in a consistent, comparable format. Unstructured notes ("Maya said the report was confusing") cannot be triaged, cannot be aggregated across participants, and cannot support a defensible `acceptance-sign-off` decision. This skill defines the capture format, the discipline for facilitating feedback without leading the participant, the routing rule that gets each report to the agent who owns fixing it, and the aggregation logic that separates signal from noise.

---

## Structured Capture Format

Every feedback item — whether from a UAT scenario failure, a structured check-in, or an ad hoc report — is captured in this shape:

```markdown
### FB-[NNN]: [Short title]

**Source:** [UAT-[ID] failure / structured check-in / ad hoc report]
**Reporter:** [name, persona/company]
**Date:** [date]

**Context — what happened:**
[Plain description of the situation the reporter was in]

**Expected vs. Actual:**
- Expected: [what the reporter believed should happen]
- Actual: [what actually happened]

**Category:** [bug / UX friction / missing capability / positive signal / documentation gap]

**Severity/Impact:** [Critical / High / Medium / Low / N/A for positive signal]

**Supporting detail:** [screenshot reference, story/scenario ID it relates to, any reproduction steps the reporter gave]
```

**Category definitions:**

| Category | Definition |
|---|---|
| **Bug** | The system does something the acceptance criteria or specification says it should not — a defect against an existing rule |
| **UX friction** | The system works as specified but is confusing, slow to use, or requires unnecessary effort to accomplish the task |
| **Missing capability** | The reporter needed something the product doesn't do at all — not a defect, a gap |
| **Positive signal** | Something worked well enough that the reporter called it out unprompted — valuable evidence, not just an absence of complaints |
| **Documentation gap** | The reporter couldn't find or understand guidance for a step they needed to take |

**Severity/Impact definitions** (same scale as `uat-scenario`'s defect severity, applied consistently across all feedback sources):

| Severity | Definition |
|---|---|
| Critical | Must Have behavior does not work at all, or causes data loss/security exposure |
| High | Must Have behavior works incorrectly in a way affecting the core outcome |
| Medium | Works but with friction, confusing wording, or a minor edge-case error |
| Low | Cosmetic or negligible impact |

---

## Anti-Leading-Question Guidance for Facilitated Sessions

The facilitator's job during a structured check-in is to surface what the participant actually experienced, not to confirm what the facilitator already believes. Leading questions produce feedback that validates the roadmap instead of testing it.

| Instead of asking... | Ask... | Why |
|---|---|---|
| "The gap report was easy to read, right?" | "Walk me through what you did when you opened the gap report." | The first invites agreement; the second surfaces actual behavior |
| "Did you notice the new classification badge?" | "What did you notice about how assets are shown on the dashboard?" | The first fishes for a specific answer; the second is open |
| "Was the scan fast enough for you?" | "Tell me about the last time you waited on a scan — what were you doing while it ran?" | The first invites a yes/no that hides real friction; the second surfaces the actual experience |
| "You'd want an export button here, wouldn't you?" | "If you needed to share this with your auditor, what would you do next?" | The first plants the answer; the second lets the participant reveal the real gap (or the real workaround they already use) |

**General rules:**
- Ask what happened before asking what they think about it
- Silence after a question is not a failure — let the participant finish before prompting
- If a participant volunteers a complaint, ask "what would you have expected instead?" rather than proposing a fix — the fix is this plugin's job, not the participant's, and proposing one anchors their answer

---

## Triage Routing Table

Every captured feedback item is routed to its owning agent within one business day of capture (faster for Critical/High per the beta agreement's response SLA):

| Category | Routes to | Why |
|---|---|---|
| Bug (backend behavior) | `backend-engineer` | Owns the Go services and domain logic the bug violates |
| Bug (frontend behavior) | `frontend-engineer` | Owns the React UI the bug manifests in |
| UX friction | `ux-architect` | Owns interaction and flow design; friction is a design concern even when nothing is technically broken |
| Missing capability | `product-strategist` | A scope/roadmap decision, not a defect — enters roadmap consideration, does not silently become a Must Have for the current release |
| Documentation gap | requirements-analyst (this agent) | Owns discovery and validation artifacts; documentation clarity for the customer-facing experience is validated here |
| Positive signal | Logged, no routing required | Retained as evidence for `acceptance-sign-off` and as roadmap validation, not actioned as a defect |

The requirements-analyst does not resolve bugs or UX issues itself — it captures, classifies, and routes. Resolution ownership stays with the domain agent named in the table, consistent with each agent's declared "Owns"/"Does not own" boundary.

---

## Aggregation Discipline — Pattern vs. Over-Reaction

A single report is a data point. A pattern is multiple independent reports converging on the same underlying issue. The two require different responses, and conflating them either over-reacts to noise or under-reacts to a real signal.

**Frequency/Severity Matrix:**

| | Single report | Multiple independent reports (pattern) |
|---|---|---|
| **Low/Medium severity** | Log; track for the next release's backlog consideration | Elevate for remediation-plan consideration in `acceptance-sign-off` even though individual severity is low — frequency itself is evidence of impact |
| **High/Critical severity** | Treat as blocking regardless of frequency — one report of data loss is enough | Blocks unconditionally; the pattern confirms rather than changes the response |

**Rules for calling something a pattern:**
- Independent reporters — the same participant repeating themselves across sessions is not a pattern, it is one persistent concern
- Same underlying cause, not merely similar symptoms — two participants confused by different screens for different reasons are two single reports, not one pattern
- A pattern is named explicitly in the sign-off record ("3 of 3 design partners independently found the gap report's PDF export button below the fold") rather than left as a count buried in a table

**The over-reaction trap:** one participant's strong reaction to a Low-severity item ("I hate this button placement") should not trigger a scope change on its own — log it, watch for a second independent report, and let the aggregation discipline do its job rather than reacting to the loudest single voice.

---

## Worked Example — Three Feedback Items, Triaged

```markdown
### FB-001: Gap report PDF export is hard to find
**Source:** Structured check-in — Northwind Compliance Co.
**Reporter:** Maya Chen
**Context:** Maya was preparing for an internal audit meeting and needed to
  share the gap report. She scrolled the full report page before finding the
  export option below the fold.
**Expected vs. Actual:** Expected an obvious way to export near the top;
  actual — export control is below the report content, easy to miss.
**Category:** UX friction
**Severity/Impact:** Medium
**Routed to:** ux-architect

### FB-002: Gap report PDF export is hard to find
**Source:** Ad hoc report — Ridgeline Analytics
**Reporter:** compliance lead
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
**Reporter:** compliance lead
**Context:** Reporter called out, unprompted, that seeing the PII tag and the
  access-gate explanation together made it obvious why an asset needed
  Restricted handling — said it would help her justify access decisions to
  her own leadership.
**Category:** Positive signal
**Severity/Impact:** N/A
**Routed to:** Logged as evidence for acceptance-sign-off; no action required.
```

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Structured capture | Every item uses the full format (context, expected/actual, category, severity) | Free-text notes with no consistent fields |
| Consistent severity scale | Same Critical/High/Medium/Low scale as `uat-scenario` applied across all sources | A different or informal severity vocabulary per source |
| Leading questions avoided | Check-in questions are open, ask "what happened" before "what do you think" | Questions that supply the expected answer |
| Correct routing | Every item reaches the agent that owns its category | Bugs left with the requirements-analyst instead of routed to engineering |
| Pattern discipline applied | Multiple independent reports named as a pattern explicitly; single reports not over-weighted | A single loud complaint treated as a confirmed pattern, or a real pattern buried in a raw count |
| Positive signals retained | Positive feedback logged as evidence, not discarded for containing no action item | Only negative feedback captured, losing usability confirmation evidence |

---

## Anti-Patterns

**Free-text feedback with no structure.** "Maya wasn't thrilled with the report" cannot be triaged, routed, or aggregated — it is not usable evidence for a sign-off decision.

**Leading the witness.** Asking a participant to confirm what the team already believes ("that worked well, right?") manufactures agreement instead of surfacing real experience — see the guidance table above.

**Requirements-analyst fixing bugs itself.** Routing exists so each item reaches its owning agent; the requirements-analyst capturing a bug and then attempting the fix crosses the ownership boundary declared in every agent's agent file.

**Treating one report as a pattern.** A single participant's Medium-severity complaint escalated as if three people said it inflates the sign-off record and can force unnecessary scope changes.

**Ignoring positive signals.** Capturing only complaints biases the sign-off record toward negativity and discards evidence that a Must Have flow actually works well for real users.

**Severity inflation or deflation to hit a number.** Adjusting a defect's severity after the fact to make the exit-criteria pass rate look better undermines the entire purpose of `acceptance-sign-off` — severity is assigned once, at capture, from the reporter's actual impact.

---

## Output Format

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
**Routed to:** ...

## Aggregation Summary
| Pattern | Reports | Reporters (independent) | Severity | Status |
|---|---|---|---|---|

## Positive Signals
[List, retained as evidence]
```
