# Alignment and Audience Views

Self-contained. Read this before asking for the roadmap's approval at any profile, and when producing more than one view of it (standard and enterprise). Source: Lombardo, McCarthy, Ryan and Connors, *Product Roadmaps Relaunched*, on alignment and buy-in and on presenting the roadmap; LeMay, *Product Management in Practice*, on the product role as connective work, where making sure nobody is surprised by a change is most of the job.

---

## Alignment, not consensus

**Alignment** means everyone understands and supports the direction. **Consensus** means everyone agrees with every item. The goal is alignment. Chasing consensus re-opens every theme with every stakeholder and ends with a roadmap that rules nothing out.

The book's two techniques for getting alignment **before** the roadmap is shown, not after:

- **Shuttle diplomacy.** Meet key stakeholders one at a time before any group review. Learn their concerns, show them how their input shaped the draft, and resolve objections privately.
- **Nemawashi.** Preparing the ground: talking a change through informally with everyone it affects before the formal decision, so the review confirms an agreement instead of starting a fight.

## Pre-wiring, scaled

| Profile | What pre-wiring means | Recorded where |
|---|---|---|
| **lean** (solo product owner) | There is no meeting. Before asking the product owner to approve, list the 2–4 decisions they are most likely to push back on (a theme they asked for that is in "Not On This Roadmap", a Later theme they expected in Now) and give the reason for each, citing the KR or the guiding policy | A short "Decisions you may question" list under the disclaimer, or in the hand-off message |
| **standard** | Read the `stakeholder-mapping` engagement plan. Consult the "Manage Closely" stakeholders one at a time before the review; note each one's concern and how the draft answered it | "Review pre-wiring" table: stakeholder, date, concern, how answered |
| **enterprise** | As standard, across product areas and levels, **in a recorded order** (usually the owners of shared dependencies first, then each area, then the executive sponsor) | Same table, with the order |

A "no" given during pre-wiring goes into "Not On This Roadmap" with its guiding-policy reason, so the requester sees the decision and the reason in writing.

---

## Audience views

One roadmap, several views. Different audiences need different detail; the disclaimer goes on every version.

| View | Audience | Shows | Leaves out |
|---|---|---|---|
| **Internal** (the artifact) | Product owner, delivery team | Everything: themes, KRs, candidate solutions, stage, confidence, dependencies, scores, exclusions, revision history | — |
| **Executive** (enterprise) | Sponsors | Objectives, themes per product area, confidence, top dependencies | Candidate solutions, scores |
| **Sales** (enterprise) | Sales and account teams | Themes and stages; what may be said to customers and **what must not be promised** | Candidate solutions, confidence numbers, any date |
| **Engineering** (enterprise) | Delivery teams | Now detail, dependencies, the link to the release plan | — |
| **External** (standard and enterprise) | Customers, prospects | Themes in the customer's words and their stage | Dates, candidate solutions, internal KRs, exclusions that name competitors |

**Lean produces one view only.** Produce a view only when someone will read it.

**The sales-deck roadmap.** The book warns against roadmaps used as sales collateral: a promise made to close a deal turns a theme into a dated feature commitment. If a customer contract genuinely needs a date, it becomes a **committed** OKR first (`okr-authoring`), and only then appears on the roadmap, marked committed.
