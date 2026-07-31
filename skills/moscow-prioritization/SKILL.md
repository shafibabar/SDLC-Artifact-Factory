---
name: moscow-prioritization
description: >
  Prioritize requirements and user stories with MoSCoW — Must have, Should have,
  Could have, and Will-not-have-this-time — for a single defined release window.
  Covers the precise inclusion criterion for each category, the Must-have discipline
  (Must = the release fails without it, not "important"), the capacity rule that
  Must-haves should not exceed roughly 60 percent of a release's capacity, the
  Will-not-have category as an explicit scope-control tool, negotiation of contested
  items, the time-boxed (per-release, not permanent) framing, and how MoSCoW relates
  to the Kano model (Must-be/basic, performance, delighter). Used during Ideate to
  agree a defensible, capacity-bounded scope for one release after the story map and
  backlog exist.
version: 2.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, requirements, prioritization, moscow, must-should-could, release-planning]
related: [user-story-writing, story-mapping, jtbd-analysis, requirements-analysis]
---

# MoSCoW Prioritization

## Purpose

MoSCoW forces explicit, defensible decisions about what belongs in **one specific
release** and what does not. It replaces vague "high / medium / low" labels with four
categories whose meanings are tied to a fixed scope constraint — a delivery window, a
budget, or both.

The technique only works when a scope limit is defined first. Without a fixed window,
"Must" expands to fill all available time and the forcing function is lost. Apply
MoSCoW **after** the story map and backlog exist (see `story-mapping`,
`user-story-writing`), so there are concrete stories to sort rather than vague themes.

---

## The Four Categories — one-line inclusion test each

| Category | Inclusion test (if the answer is no, it does not belong here) |
|---|---|
| **Must have** | Does the release *fail* without this — un-shippable, no value to the primary persona, or a legal/regulatory breach? |
| **Should have** | Is this important and expected, yet the release still delivers core value without it (degraded, not broken)? |
| **Could have** | Is this desirable but its absence would be barely noticed — included only if Musts and Shoulds finish early? |
| **Won't have (this time)** | Is this a valid, acknowledged request that is *explicitly deferred* out of this release (recorded, not discarded)? |

---

## Must-have discipline

A Must is **not** "the important ones." A Must is a requirement whose absence makes the
release fail. Interrogate every candidate Must with the **necessity test** (Hathaway):
*"What happens if we don't build this?"* If the honest answer is "nothing that gates the
release," it is a preference, not a Must — demote it. Priority is assigned by
interrogation, never by how confidently a stakeholder stated the want.

Three questions confirm a Must; any one "yes" qualifies it:
- Without this, does the release fail to meet its stated goal?
- Is there a legal, safety, or contractual obligation requiring it?
- Without this, can the primary persona not complete their core job?

If all three are "no," it is at most a Should. See `references/moscow-rubric.md` for the
full per-category criteria, the tie-break questions, and negotiation techniques for
contested items.

---

## The ~60% capacity ceiling

Must-haves should account for **no more than roughly 60 percent** of a release's
estimated capacity. The remaining ~40 percent (Shoulds and Coulds) is deliberate
contingency: it absorbs estimation error and mid-release surprises without threatening
the Musts.

If Musts exceed ~60%, one of two things is wrong — the scope constraint is too loose
(narrow the window) or requirements are being over-promoted to Must (be more rigorous).
A backlog where everything is a Must is not prioritized; it is a wish list with zero
contingency, and it fails the moment the first estimate slips. The *why* behind the
ceiling and how to react when it is breached are in `references/moscow-rubric.md`.

---

## Won't-have as a scope-control tool

The Won't-have category is the technique's primary defense against scope creep. "Won't"
means **"not in this release,"** not "never." Explicitly recording a Won't item with a
one-line rationale and a target release:

- Stops stakeholders re-raising the same request every conversation.
- Makes the exclusion visible and intentional rather than a silent omission.
- Prevents wasted discovery on out-of-scope work.

A Won't item captures a decision; leaving scope exclusions implicit or verbal captures
nothing. An item that is genuinely *never* going to be built should be closed, not parked
as Won't — Won't means "acknowledged, deferred," and it belongs in the future backlog.

---

## MoSCoW is per-release, not permanent

Every categorization is scoped to **one delivery window**. A Could in Release 1 may be a
Must in Release 3 once the market or the roadmap moves. Re-run MoSCoW each release
against that release's constraint; never treat last release's bins as fixed labels.

---

## MoSCoW is not Kano

MoSCoW answers *"given fixed capacity, which scoped stories are in versus deferred?"* —
binary, per story, meaningless without a delivery window. The Kano model answers a
different question: *"for a feature, what shape is the curve between how much we build and
how satisfied customers are?"* A feature can be MoSCoW-Must and Kano-Basic (e.g. SOC 2
control mapping — expected, fails the release if absent, no extra satisfaction from
over-building), or MoSCoW-Should and Kano-Delighter (absent it fails the necessity test,
present it drives outsized satisfaction). Treating every non-Must as undifferentiated
"nice to have" hides high-leverage Delighters. The full mapping, and a worked
prioritization of this repo's backlog, are in `references/moscow-and-kano.md`.

---

## Applying MoSCoW to the backlog (procedure)

1. **Set the constraint** — state the delivery window and capacity (e.g. "MVP: 8 weeks,
   1 senior + 1 full-stack"). Fix the Must ceiling at ~60% of it.
2. **Necessity + Must test on every story** — any "yes" marks Must; otherwise start at Should.
3. **Negotiate Shoulds** — "Would the primary persona give negative feedback if this were
   missing?" If yes, consider promotion and re-run the 60% check; if no, confirm Should.
4. **Assign Coulds** — remaining desirable, non-deferred stories.
5. **Assign Won'ts** — valid-but-deferred stories get Won't + one-line rationale + target release.
6. **Validate against the story map** — Must-haves must equal the MVP slice. A story in
   the MVP slice ranked Should/Could is a conflict; resolve it before closing Ideate.

Category criteria, contested-item negotiation, the capacity-loading math, and the
time-boxed framing: `references/moscow-rubric.md`. Kano cross-check and the worked
example: `references/moscow-and-kano.md`.

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Everything is a Must | No trade-offs; Musts exceed capacity with zero contingency | Apply the ~60% rule; necessity-test every Must |
| Nothing is a Won't | Scope unconstrained; backlog grows indefinitely | Explicitly assign Won't with rationale + target release |
| MoSCoW with no window | Applied to a timeless backlog — meaningless | Define a specific release window first |
| Priority by consensus | Everyone agrees everything is important | Tie every Must to the necessity + Must test |
| "Should" as a soft Must | Shoulds always ship, so they are Musts in disguise | Promote to Must and tighten the constraint, or hold the line |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Defined constraint | A specific window/budget is stated | Applied without a scope constraint |
| ~60% Must rule | Musts are ≤ ~60% of estimated capacity | Musts are 80%+ of capacity |
| Won't documented | Exclusions carry rationale + target release | Exclusions implicit or verbal only |
| Necessity + Must test | Every Must traces to a test pass | Musts that fail all test questions |
| Story-map alignment | Musts equal the MVP slice | Discrepancy between Must list and MVP slice |

Output-artifact template (frontmatter + Must/Should/Could/Won't tables + capacity check):
`references/moscow-rubric.md`.
