# MoSCoW Rubric — Category Criteria, Capacity Loading, Negotiation, Output Template

Reference material for `moscow-prioritization`. The SKILL.md body carries the
one-line inclusion test per category, the ~60% ceiling, and the procedure. This file
carries the precise inclusion criteria, the tie-break questions, the capacity-loading
math and why over-loading Musts fails, negotiation techniques for contested items, the
time-boxed framing, and the output-artifact template.

MoSCoW originates in the Dynamic Systems Development Method (DSDM); the acronym is Dai
Clegg's. The necessity test cited throughout ("what happens if we don't build this?") is
from Thomas and Angela Hathaway, *Getting and Writing IT Requirements in a Lean and Agile
World* — a candidate requirement with no consequential answer is a *preference*, and must
not compete for Must/Should priority on equal footing with things that gate release.

---

## 1. Precise inclusion criteria per category

### Must have — inclusion criterion

A story is a Must **if and only if** the release fails without it. "Fails" means one of
exactly three things, and one is sufficient:

| Failure mode | What it means | Example (data-estate product) |
|---|---|---|
| **Un-shippable** | The product cannot be released at all without it — a hard technical or contractual dependency of everything else | Tenant isolation for the physical multi-tenancy model — nothing can ship without it |
| **No primary-persona value** | The primary persona (the Data Steward) cannot complete their *core job* — the one the release exists to enable | Connect a source + run the first classification scan |
| **Legal / regulatory / contractual breach** | Shipping without it violates a law, a regulation, a safety obligation, or a signed contract | SOC 2 audit-logging of who accessed which classified file |

Questions that test a candidate Must (any one "yes" qualifies; all three "no" disqualifies):

1. **Necessity test (Hathaway):** "What happens to *this release* if we don't build
   this?" If the answer is not "the release fails / cannot ship / breaches an
   obligation," it is not a Must.
2. **Goal test:** "Does the release's stated goal go unmet without it?" Tie the goal to a
   concrete outcome (e.g. "first compliance gap surfaced within 30 minutes of connecting
   a source"), not a vague theme.
3. **Core-job test:** "Without this, is the *primary* persona blocked from their core
   job?" A *secondary* persona being blocked is a Should signal, not a Must signal.

If a candidate passes only because a stakeholder insisted loudly, it fails. Volume is not
a Must criterion.

### Should have — inclusion criterion

Important and expected, but the release still delivers its core value without it. The
absence produces a **degraded but functional** experience. The precise distinction from a
Must:

- A Must's absence means the product **fails** to deliver its primary promise.
- A Should's absence means the product **delivers, but not as well** as it should.

Typical Should candidates: a secondary persona's core workflow (the Compliance Officer's
report export while the Data Steward's scan is the Must), error/empty states that improve
experience, export and sharing that extend core value, non-critical configuration.

### Could have — inclusion criterion

Desirable but not important; included **only if** capacity remains after all Musts and
Shoulds are complete. The distinction from a Should: a Should would be *missed*; a Could
would be *barely noticed* in its absence. Typical Could candidates: cosmetic polish,
alternate views of data already shown elsewhere, convenience shortcuts that save one step.

### Won't have (this time) — inclusion criterion

A valid, understood request that is **explicitly excluded from this release**, recorded
with a one-line rationale and a target release. Won't means "not now, acknowledged,"
**never** "never." Distinguish three things that are easy to conflate:

| Disposition | Meaning | Where it goes |
|---|---|---|
| **Won't (this release)** | Valid, deferred to a named future release | Future backlog, with rationale + target |
| **Closed / rejected** | Genuinely never going to be built | Closed — not left dangling as Won't |
| **Could** | Might be built *this* release if time allows | This release's backlog, conditional |

---

## 2. Capacity loading — the math and why over-loading fails

### The default split

| Category | Share of estimated capacity | Purpose of the share |
|---|---|---|
| Must have | **≤ ~60%** | The non-negotiable release contents |
| Should have | ~20% | High-value contingency; ships if Musts land on estimate |
| Could have | ~20% | Low-value contingency; the first thing dropped when Musts slip |
| Won't have | 0% of *this* window | Explicitly out — consumes no capacity |

Worked example: an 8-week MVP with 2 contributors ≈ 16 person-weeks of capacity. The Must
ceiling is ~60% ≈ 9.6 person-weeks. If the Must list estimates at 12 person-weeks (75%),
the ceiling is breached — act (see below) rather than accept it.

### Why over-loading Musts fails — the contingency argument

The ~40% held in Shoulds and Coulds is not slack to be "recovered" by promoting more work
to Must. It is the buffer that lets a release land **on time with its Musts intact** when
estimates are wrong — and estimates are always wrong. Mechanism:

- At 60% Musts, a 30% estimation overrun on the Musts still fits inside the window by
  sacrificing Coulds first, then Shoulds. The Musts — the release's reason to exist —
  still ship.
- At 90% Musts, the same 30% overrun blows the window. There is nothing left to cut but
  Musts, so either the date slips or the release ships incomplete. Both are failures the
  ceiling exists to prevent.

A backlog that is "all Must" has therefore not been prioritized at all — it has removed
the buffer and guaranteed that the first surprise becomes a crisis.

### What to do when the ceiling is breached

The ceiling breaking is a **signal**, not a number to fudge. Exactly two legitimate
responses:

1. **The constraint is too loose** — the window is longer than the Musts warrant, or the
   release is trying to be two releases. Narrow the window / split the release so each
   release's Musts fit under 60% of *its* capacity.
2. **Requirements are over-promoted** — items marked Must are really Shoulds. Re-run the
   necessity + Must test on every Must, ranked by weakest justification first, and demote
   until the list fits.

Never respond by silently raising the ceiling or by shrinking estimates to make the Musts
fit. Both hide the risk the ceiling was meant to surface.

---

## 3. Negotiating contested items

Contested priority is normal; the technique's value is that it makes the argument
explicit and resolvable against a criterion rather than by seniority. Techniques:

| Situation | Technique | What it forces |
|---|---|---|
| Two stakeholders each call their item Must | Run the necessity test on both, out loud | Only items whose absence *fails the release* survive as Must; the rest are Shoulds competing for the ~20% buffer |
| A stakeholder insists on Must with no test-pass | Ask "which *existing* Must do you want to demote to make room?" (zero-sum framing) | Musts stop being a free list; every addition costs a removal once the ceiling is hit |
| "Everything is important" | Concede importance is not the axis — MoSCoW ranks *release necessity*, not importance | Separates "matters to the business" from "gates this release" |
| A Should that is always delivered anyway | If it ships every release, it is a Must — promote it and tighten the constraint | Removes fake Shoulds that are Musts in disguise |
| Deadlock between peers | Escalate to the single accountable owner (product-strategist / requirements-analyst), not to consensus | A defensible decision with one owner, not a committee average |

Rule of thumb: **the argument is never "how important is this?"** — it is always "does the
release fail without it?" Redirecting every contest to that question is most of the job.

---

## 4. The time-boxed framing — MoSCoW is per-release, not permanent

MoSCoW is a *time-boxed* technique inherited from DSDM's fixed-time, fixed-cost,
variable-scope philosophy. Consequences:

- Every category assignment is scoped to **one delivery window**. Re-run MoSCoW each
  release against that release's own constraint.
- A Could in Release 1 can legitimately be a Must in Release 3 — the category is a
  statement about *this release's necessity*, not a permanent property of the story.
- The variable in "fixed time, fixed cost, variable scope" is the **Coulds and Shoulds**.
  When time runs short, Coulds drop first and Shoulds next; **Musts never drop** — if the
  Musts cannot land, the window itself was wrong.
- Won't items are re-examined at the *next* release's MoSCoW pass, where they may be
  promoted, demoted to a later target, or closed.

---

## 5. Output-artifact template

```markdown
---
name: moscow-prioritization
product: [product name]
delivery-window: [e.g. MVP — 8 weeks]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
must-capacity-pct: [estimated % of capacity consumed by Musts]
---

# MoSCoW Prioritization — [Release name]

## Delivery Constraint
**Window:** [dates or sprint count]
**Capacity:** [estimated available effort, e.g. 16 person-weeks]
**Must Have capacity ceiling:** [~60% of the above]

## Must Have
| Story ID | Title | Necessity + Must-test justification |
|---|---|---|

## Should Have
| Story ID | Title | Why Should and not Must (what degrades if absent) |
|---|---|---|

## Could Have
| Story ID | Title | Condition for inclusion |
|---|---|---|

## Won't Have (this release)
| Story ID | Title | Rationale for deferral | Target release |
|---|---|---|---|

## Capacity Check
**Estimated Must effort:** [X person-weeks / story points]
**Must % of total capacity:** [X%]
**Status:** [Within ~60% ceiling / Exceeds ceiling — narrow window or demote Musts]

## Story-Map Alignment
[Confirm Musts equal the MVP slice, or document and resolve each discrepancy]
```

---

## 6. Quick reference — the disqualifiers

- Must with no necessity-test pass → demote to Should.
- Musts > ~60% of capacity → narrow the window or demote over-promoted Musts.
- Any Won't with no rationale + target → incomplete; add both or close the item.
- MoSCoW applied with no delivery window → invalid; define the window first.
- Must list ≠ MVP slice on the story map → conflict; resolve before closing Ideate.
