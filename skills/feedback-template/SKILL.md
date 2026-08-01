---
name: feedback-template
description: >
  Capture, interpret, and triage customer feedback during Customer Validation —
  the structured capture fields (context, expected vs actual, category, severity),
  the Mom-Test question-design rules for facilitated check-ins (talk about their
  life not your idea; ask for specific past behavior not opinions or future
  hypotheticals; avoid leading questions), the triage workflow (dedupe → interpret
  the underlying need → severity/frequency → route to owning agent), and the
  pattern-vs-over-reaction aggregation discipline that separates a real signal
  across independent reporters from one loud complaint. Fires when a UAT-scenario
  failure, a beta-program-design check-in, or an ad hoc report must be logged;
  when a stated feature request must be probed for its real job (jtbd-analysis);
  when compliments, fluff, or ideas must be filtered out of feedback; or when a
  feedback log feeds an acceptance-sign-off decision. Used by requirements-analyst.
version: 2.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-07-20
tags: [validation, feedback, customer-validation, mom-test, interview, feedback-triage]
produces: feedback-log
domain: validation
status: stable
related: [uat-scenario, beta-program-design, acceptance-sign-off, jtbd-analysis, user-persona, gtm-strategy]
---

# Feedback Template

## Purpose

Feedback from UAT execution (`uat-scenario`) and beta program check-ins (`beta-program-design`) is only useful if it is captured in a consistent, comparable format and interpreted for the real need behind it. Unstructured notes ("Maya said the report was confusing") cannot be triaged, aggregated, or used to defend an `acceptance-sign-off` decision. This skill defines the capture fields, the Mom-Test discipline for facilitating feedback without leading the participant or accepting a compliment as data, and the triage workflow that gets each report to the agent who owns fixing it.

The requirements-analyst captures, interprets, and routes — it does not resolve bugs or UX issues itself. Resolution ownership stays with the domain agent named in the routing table (see reference), consistent with each agent's declared Owns/Does-not-own boundary.

---

## Capture Fields

Every feedback item — a UAT failure, a structured check-in, or an ad hoc report — is captured in the same shape so items can be compared and aggregated:

- **FB-ID + short title** — a stable identifier and one-line summary
- **Source** — UAT-[ID] failure / structured check-in / ad hoc report
- **Reporter** — name, persona (Data Steward / Compliance Officer), company
- **Context — what happened** — the plain situation the reporter was in, in their words
- **Expected vs. Actual** — what they believed should happen vs. what did
- **Category** — bug / UX friction / missing capability / positive signal / documentation gap
- **Severity/Impact** — Critical / High / Medium / Low (N/A for a positive signal), the same scale `uat-scenario` uses so severity is comparable across every source
- **Supporting detail** — screenshot reference, the scenario/story ID it relates to, reproduction steps

Full capture template, the category definitions, the severity rubric, the routing table, and worked examples: `references/feedback-capture-and-triage.md`.

---

## Mom-Test Question Design for Check-Ins

The facilitator's job during a structured check-in is to surface what the participant actually experienced — not to confirm what the team already believes. A design-partner group per `gtm-strategy`'s Stage 1 is small, relationship-warm, and reflexively polite: it is the single easiest place to self-deceive, so the question discipline matters most here. Fitzpatrick's **Mom Test** is the standard: a question either passes all three rules or it produces false-positive data that *feels* like validation.

**The three rules, applied to feedback elicitation:**

1. **Talk about their life, not your idea.** Ask what they did, not what they think of the product. Describing or pitching the feature first ("leading the witness") tells them what answer would please you and biases everything after.
2. **Ask about specific past behavior, not opinions or future hypotheticals.** "Walk me through the last time you needed to export a gap report" beats "would you use an export button?" A question answerable only by describing something that actually happened cannot be satisfied by a polite guess.
3. **Talk less, listen more.** Ask what happened before asking what they think about it; let silence sit; when a participant volunteers a complaint, ask "what would you have expected instead?" rather than proposing a fix — proposing one anchors their answer, and the fix is this plugin's job, not theirs.

**Separate the stated request from the real job.** An unsolicited feature idea ("you should build a dashboard") is evidence of a pain, not a validated spec. Record the underlying problem — "what's the problem you picture that dashboard solving?" — not the raw request, so it reaches `jtbd-analysis` as a real job rather than a solution-shaped one.

Good-vs-bad question pairs, the compliments/fluff/ideas taxonomy, and the advancement/commitment discipline: `references/mom-test-question-design.md`.

---

## Triage Workflow

Every captured item runs through the same four steps, fastest for Critical/High per the beta agreement's response SLA:

1. **Dedupe.** Collapse items describing the same underlying issue into one entry with multiple reporters — but only when the *cause* is the same, not merely the symptom. Two participants confused by different screens for different reasons are two items, not one.
2. **Interpret the underlying need.** For a UX-friction or missing-capability item, name the job the reporter was trying to make progress on, not just the surface complaint — this is where a stated request is converted into its real job before it can distort a roadmap or sign-off decision.
3. **Assess severity and frequency.** Severity is assigned once, at capture, from the reporter's actual impact — never adjusted later to make an exit-criteria pass rate look better. Frequency is a separate axis: a single report is a data point; multiple *independent* reporters converging on the same cause is a pattern.
4. **Route to the owning agent.** Each category routes to exactly one owning agent (bug → engineering, UX friction → `ux-architect`, missing capability → `product-strategist`, documentation gap → requirements-analyst, positive signal → logged as evidence). The routing table lives in the reference.

**Pattern vs. over-reaction.** A single Medium complaint, however loud, is logged and watched for a second independent report — not escalated as if three people said it. A confirmed pattern (independent reporters, same root cause) is named explicitly in the sign-off record ("3 of 3 design partners independently found the PDF export below the fold"), not left as a buried count. High/Critical items block regardless of frequency — one report of data loss is enough. The full frequency/severity matrix and worked examples are in the reference.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Structured capture | Every item uses the full field set | Free-text notes, no consistent fields |
| Consistent severity | Same scale as `uat-scenario` across all sources | A different severity vocabulary per source |
| Mom-Test questions | Open, past-tense, specific-instance; no pitch before the question | Questions that supply the expected answer |
| Need interpreted | Stated requests probed for the underlying job | Raw feature requests logged verbatim as requirements |
| Correct routing | Every item reaches the agent owning its category | Bugs left with requirements-analyst |
| Pattern discipline | Independent reports named as a pattern; single reports not over-weighted | One loud complaint treated as a confirmed pattern |
| Positive signals retained | Logged as evidence for `acceptance-sign-off` | Only complaints captured, usability confirmation lost |

---

## Anti-Patterns

- **Free-text feedback with no structure.** "Maya wasn't thrilled with the report" cannot be triaged, routed, or aggregated.
- **Leading the witness.** "That worked well, right?" manufactures agreement instead of surfacing real experience.
- **Accepting a compliment as data.** "This is great" costs the speaker nothing and predicts nothing — deflect it back into a specific-instance question.
- **Logging a feature request as a requirement.** A proposed solution is evidence of a pain; record the job, not the request.
- **Requirements-analyst fixing bugs itself.** Routing exists so each item reaches its owning agent; crossing that boundary violates every agent's declared ownership.
- **Treating one report as a pattern.** A single Medium complaint escalated as if three people said it inflates the sign-off record and can force needless scope changes.
- **Ignoring positive signals.** Capturing only complaints biases the record toward negativity and discards evidence a Must Have flow works.
- **Severity inflation or deflation to hit a number.** Severity is assigned once, at capture, from real impact — not adjusted to make exit criteria pass.
