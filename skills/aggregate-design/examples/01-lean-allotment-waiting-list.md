# Example 1 — Lean: No Aggregate Needed

Self-contained. **Plotkeeper** runs the plot waiting list for a town's allotment society, at the **lean** profile. Two Bounded Contexts from the context map: **Membership** (members, contact details, annual rent) and **Plots** (sites, plots, the waiting list, offers and tenancies). The subdomain classification marks Plots as Supporting and Membership as Generic.

## Input

> **User:** "Design the Aggregates. The waiting list is the heart of it, so give it a proper Domain Model: a WaitingList Aggregate holding every applicant in order."

## Working it

- **The deciding question first (§ 1):** is there a rule across more than one record that must hold at every instant? The candidates, each as one sentence:
  - "An offer goes to the applicant at the top of the site's list." Q1: a committee member skipping someone causes a complaint, not lasting harm; Q2: yes, the committee withdraws the offer and re-offers; → **rejected**. The offer screen shows who is next and the committee reviews each offer.
  - "A plot has at most one current tenancy." This lives on one record, the plot. It is a uniqueness rule on that record, not a rule across records, so it needs a constraint, not an Aggregate.
  - "Positions on the list have no gaps." A derived value: positions are computed from join dates at query time. Rejected.
- **The request.** A `WaitingList` Aggregate holding every applicant would be the has-a trap: the list "has" applicants, but no rule needs them changed together. Every join would also contend on one instance per site. Each entry is a record of its own.
- **Result:** no Domain Model at all. That is a valid lean result, and much cheaper to build. Membership's use cases are Transaction Scripts; Plots' are Active Records.

## Output: `design/domain-model.md`

```markdown
---
name: domain-model
product: plotkeeper
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-11-05
summary: Plotkeeper's two contexts need no Aggregate; waiting-list, offer and tenancy use cases are Active Records, membership upkeep is Transaction Script.
profile: lean
traces-to: [design/event-storming/big-picture.md, design/subdomain-classification.md, design/context-map.md, design/plots/ubiquitous-language.md]
---

# Domain Model: Plotkeeper

## Use case: Update contact details

| Field | Value |
|---|---|
| **Context** | Membership |
| **Pattern** | Transaction Script — no rule across records; one validated update |
| **Records touched** | member |
| **Rules** | email must parse (a self-validating EmailAddress value) |

## Use case: Join the waiting list

| Field | Value |
|---|---|
| **Context** | Plots |
| **Pattern** | Active Record — single-record rules only; "offer goes to the top applicant" failed the test (fixable by re-offering) |
| **Records touched** | waiting-list entry |
| **Rules** | one entry per member per site (uniqueness constraint); join date set once |

## Use case: Offer a plot

| Field | Value |
|---|---|
| **Context** | Plots |
| **Pattern** | Active Record — the offer and the plot are separate records with no rule needing them changed together |
| **Records touched** | offer, plot |
| **Rules** | a plot has at most one open offer and one current tenancy (constraints on the plot); an offer expires after 14 days |

## Use case: Accept an offer

| Field | Value |
|---|---|
| **Context** | Plots |
| **Pattern** | Active Record — starting the tenancy and closing the entry may lag by seconds; the list view tolerates it |
| **Records touched** | offer, tenancy, waiting-list entry |
| **Rules** | only an open, unexpired offer can be accepted |

## Domain Events

| Context | Event (past tense) | Raised by | Carries | Who reacts |
|---|---|---|---|---|
| Plots | ApplicantJoinedWaitingList | Join the waiting list | member, site, join date | waiting-list view |
| Plots | PlotOffered | Offer a plot | plot, member, expiry | email to the member |
| Plots | OfferAccepted | Accept an offer | offer, plot, member | tenancy starts; entry closed (idempotent) |
| Plots | OfferExpired | daily expiry job | offer, plot | committee's "next in line" view |
| Membership | RentPaid | Record rent payment | member, year, amount | Plots marks the tenancy as paid |

## Commands

| Context | Command | Guard | Handled by | Idempotency |
|---|---|---|---|---|
| Plots | JoinWaitingList | member is current; no entry at this site | Join the waiting list | one entry per member per site |
| Plots | OfferPlot | plot vacant, no open offer | Offer a plot | one open offer per plot |
| Plots | AcceptOffer | offer open and unexpired | Accept an offer | accepting twice is ignored |
| Membership | RecordRentPayment | member exists | Transaction Script | payment reference |

## Read Models

| Context | Read Model | Answers | Built from | Staleness accepted |
|---|---|---|---|---|
| Plots | Waiting list by site | who is next, and each applicant's position | entries ordered by join date | seconds |
| Plots | Vacant plots | which plots can be offered | plots, offers, tenancies | seconds |

## Open questions

- Is skipping an applicant ever allowed (for an accessible plot, say)? If so, the offer screen needs a reason field. (assumed: no)
```

## Why this is right

- The pattern came from the rules, not from how central the waiting list feels. No rule across records passed the test, so there is no Aggregate.
- The single-record rules are constraints, stated where they live.
- The declined request is answered with its reason: a list Aggregate is the has-a trap, and it would serialise every join at a site.
