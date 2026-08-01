---
name: ux-flow-design
description: >
  Teaches the ux-architect to design UX flows — distinguishing a task flow (a
  single linear path), a user flow (branching paths with decision points), and a
  wireflow (flow annotated with low-fidelity screen sketches) — plus building the
  screen/state inventory and explicitly designing the error, edge, and empty
  states that happy-path flows omit. Used during Design to specify navigation and
  screen transitions before high-fidelity UI, across the microfrontend fragment
  boundaries.
version: 2.0.0
phase: design
owner: ux-architect
created: 2026-06-25
tags: [design, ux, user-flow, task-flow, wireflow, screen-inventory, error-states, empty-states]
produces: ux-flow
domain: ux
status: stable
related: [user-journey-mapping, information-architecture, acceptance-criteria, user-persona]
---

# UX Flow Design

## Purpose

A UX flow specifies the sequence of screens, states, and decisions a user moves
through to complete a single job-to-be-done — before any high-fidelity UI is
drawn. Flows are the authoritative spec the `frontend-engineer` builds against:
which screens to build, in what order, and what each screen must handle. Every
Job Story from Ideate maps to at least one flow; a job with multiple paths maps
to more than one.

A flow bridges upstream artifacts to implementation. It consumes the
`user-journey-mapping` output (the customer-perspective arc and its emotional
valleys) and the `information-architecture` (where screens live in navigation),
and it feeds `acceptance-criteria` — every branch a flow reveals should trace to
a Gherkin scenario, and any branch with no scenario is a gap in the criteria.

---

## The Three Flow Types — Pick the Right One

Do not draw every flow the same way. The artifact you choose depends on how much
branching and how much screen detail the job actually carries.

| Type | Shape | Use when | Do not use when |
|---|---|---|---|
| **Task flow** | One linear path, no branches — start → steps → end | The job has a single canonical route every user takes the same way (e.g. "log in", "rename an asset") | The job forks on a decision, permission, or system outcome |
| **User flow** | Branching paths with decision points, loops, and back-navigation | The job forks — validation, permissions, API outcomes, or user choices create alternate routes (most real flows) | The path is truly linear (a task flow is lighter and clearer) |
| **Wireflow** | A user flow whose nodes carry low-fidelity screen sketches | The screen-to-screen transition itself is the risk — a multi-step wizard, a novel navigation pattern, a cross-fragment journey | The screens are conventional and the branching, not the layout, is what needs review |

A task flow answers *"what are the steps?"*. A user flow answers *"what happens
when it forks?"*. A wireflow answers *"what does each screen roughly look like as
the user moves between them?"*. Start with a task flow, promote to a user flow
the moment a decision appears (almost always), and reach for a wireflow only when
the transitions themselves need review.

Depth on all three, decision-point modeling, loops/back-navigation, and the
cross-fragment hand-off notation: `references/flow-notation-and-types.md`.

---

## Flow Notation Basics

Flows are written as ASCII node-and-arrow sequences — no diagramming tool, so
Shafi reviews them as plain Markdown. Five node kinds cover every flow:

| Symbol | Node kind | Meaning |
|---|---|---|
| `(( ))` | Start / end | A terminal point — where the flow begins or ends |
| `[ ]` | Screen / state | A screen the user sees, or a distinct state of one |
| `< >` | System action | Invisible work (API call, validation) the user does not see |
| `{ }` | Decision | A branch point — routes to different paths by outcome |
| `→` / `↳` | Action arrow / branch | Flow continues; `↳` is an alternate path from a decision |

Every decision node must enumerate **all** its outcomes — a `{decision}` with only
one arrow out is a happy-path-only flow masquerading as a spec. Full notation
conventions and worked diagrams are in `references/flow-notation-and-types.md`.

---

## The Screen / State Inventory

Before drawing individual flows, produce a **screen/state inventory**: every
screen the flows touch, and for each screen every state it can be in. A screen is
not one thing — it is a set of states, and a flow that names only the populated
"success" version of a screen has under-specified it.

Every screen in the inventory must account for its full state set — loading,
empty, error, partial, and success are the minimum. These are not optional
polish; each is a distinct thing the `frontend-engineer` must build, and omitting
one means it gets discovered in production. The inventory method, the complete
canonical state set, and how to derive states per screen:
`references/states-and-edge-cases.md`.

---

## Design the Error, Edge, and Empty States — Not Just the Happy Path

The single most important discipline in this skill: **a flow that assumes every
API call succeeds and every list is populated is a storyboard, not a spec.** Real
usage hits expired sessions, missing permissions, deleted records, concurrent
edits, failed ingestions, and brand-new tenants with nothing yet.

- **Error states** — every system action (`< >`) and every decision on an API
  outcome must have an error branch, and every error branch must end in a
  recovery: a retry, a corrective action, or a signposted exit. "Something went
  wrong" with no next step is a flow-design failure, not a copy problem.
- **Edge states** — first-use, single-item lists, maximum limits, partial
  results. Valid but unusual; enumerate them so they are designed, not
  retrofitted.
- **Empty states** — a list or dashboard with no data yet is a *valid* state, not
  an error. Never route an empty estate to an error screen. An empty state always
  carries a message and an actionable next step (a CTA into the flow that
  populates it).

Treating empty as error, and letting errors dead-end, are the two failures this
skill exists to prevent. The full method plus a worked flow for this product
(Data Steward classifying an estate: happy path, empty-estate, ingestion-failure,
and permission-denied branches) is in `references/states-and-edge-cases.md`.

---

## Flows Cross Microfrontend Fragment Boundaries

This product's frontend is a microfrontend: a shell hosting independently
deployable remotes (fragments). A single job-to-be-done routinely spans more than
one fragment — a Data Steward may begin in the estate-browser remote, cross into
the classification remote, and end in a compliance remote hosted by the shell.

When a flow crosses from one remote to another, **mark the hand-off explicitly.**
The fragment boundary is where shared state, deep-link URL, and permission context
must be handed across a seam owned by a different deploy pipeline — the most
common place a flow silently breaks. An unmarked cross-fragment transition is a
defect: the flow reads as if it were one app when two independently-deployed
remotes must actually agree on the contract at that point. The cross-fragment
hand-off notation and a worked cross-remote example are in
`references/flow-notation-and-types.md`.

---

## Flow Inventory and Handoff

Before designing screens, produce a **flow inventory** mapping every Job Story to
the flows it needs. It is complete when every JS-NNN from the requirements output
has at least one flow.

| Job Story ID | Job description | Flows required |
|---|---|---|
| JS-001 | Scan a data source | happy-path, source-unavailable, auth-error, partial-scan |
| JS-002 | Classify a data asset | happy-path, no-permission, session-expired, validation-error, bulk-classify |
| JS-003 | View a compliance gap report | happy-path, no-reports-yet, report-generating |

The handoff package to `frontend-engineer` contains: the flow inventory, every
flow diagram, entry/exit/precondition documentation per flow, the screen/state
inventory, the marked cross-fragment hand-offs, and the acceptance-criteria gap
list (branches that revealed missing Gherkin scenarios).

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Right flow type chosen | Linear jobs are task flows; branching jobs are user flows | Every job forced into one notation |
| All Job Stories covered | Every JS-NNN maps to at least one flow | Job Stories with no flow |
| All branches enumerated | Every decision node shows all outcomes | Decision nodes with "happy path only" |
| Error branches recover | Every error path ends in retry, correction, or signposted exit | Errors that dead-end |
| State set complete | Every screen names loading/empty/error/partial/success | Screens defined only in their populated state |
| Empty ≠ error | Empty states have a message and a CTA | New-tenant empty list routed to an error screen |
| Cross-fragment hand-offs marked | Every remote-to-remote transition is annotated | Silent transitions across fragment seams |
| Acceptance criteria mapped | Every branch maps to a Gherkin scenario | Branches with no scenario |
| Abandon paths defined | Every flow states what Cancel/Escape/back does to in-progress work | Abandonment left to the implementer |

---

## Anti-Patterns

- **Happy-path-only flows.** Every API call succeeds, every list is full. Real
  usage hits expired sessions, missing permissions, deleted records, failed
  scans. A flow without those branches is a storyboard.
- **Errors that dead-end.** An error state with no recovery action. Every error
  path ends in a retry, a corrective action, or a signposted exit.
- **Treating empty as error.** Routing a new tenant's empty estate to an error
  screen. Empty is a valid first-use state with its own flow.
- **Screens before flows.** Laying out a modal before the flow reveals it needs a
  conflict, permission-denied, and not-found state. Flows determine what screens
  must handle.
- **Decision nodes hidden in prose.** "The system handles errors appropriately"
  instead of an enumerated `{decision}`. Unlisted outcomes get discovered in
  production.
- **Undefined abandonment.** No statement of what Cancel, Escape, or browser-back
  does mid-flow, especially in multi-step wizards with partial work.
- **Silent fragment hand-offs.** A flow that crosses from one remote to another
  without marking the seam, hiding where shared state and permission context must
  be handed across a separately-deployed boundary.
- **Everything is a wireflow.** Sketching every screen when the branching, not the
  layout, is the risk — wasted fidelity that ages badly. Reach for a wireflow only
  when the transitions themselves need review.
