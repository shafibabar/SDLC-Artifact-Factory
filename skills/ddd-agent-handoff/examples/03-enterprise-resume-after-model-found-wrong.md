# Example 3 — Enterprise: Resuming When the Model Was Found Wrong

Self-contained. **Theatrewise** is a multi-tenant SaaS for hospital operating theatres: about 40 hospital trusts (tenants) in three regions book surgeries, allocate theatres and roster theatre staff. **Enterprise** profile. Design was approved; the backend-engineer was implementing the **Theatres** context when the session stopped. A new session is asked to carry on.

## Input

> **User:** "Yesterday's session stopped halfway through Theatres. Just pick up where it left off and finish the implementation."

## Working it

- **Read the open hand-over records first.** Two are open in this phase:
  - `domain-modeler-to-backend-engineer.md` (Implement): the backend-engineer wrote, before stopping, that the `SurgeryBooking` Aggregate's rule "a theatre is never double-booked" cannot be enforced inside `SurgeryBooking`: a theatre is shared by many bookings, so two bookings each loading their own state can both take it. That is not a bug to code around: the Aggregate boundary is wrong.
  - `enterprise-architect-to-platform-engineer.md` (Implement): container topology for Theatres; it stopped when the session hit its limit, with nothing in question.
- **Two kinds of interruption, two resumptions.**
  - The platform hand-over is an **operational pause**: continue from its artifacts and open questions.
  - The Theatres hand-over is **model found wrong**: do not resume forward. Evans' point: a breakthrough reshapes the model; building on the old one compounds the error. Route back to the domain-modeler to revise the boundary (perhaps a `TheatreSchedule` Aggregate per theatre and day), and list everything built on the old one for review: the Read Models, the API contract and the event catalog.
- **What happens to "just finish it":** declined for Theatres, with the reason; the platform work continues. The revised model needs the product owner's re-approval before implementation resumes, under a new hand-over record that cites this one.
- **Tenancy:** unchanged; the revision stays inside each tenant's data, so the isolation decision is not reopened.

## Output: `artifacts/theatrewise/implement/handoffs/domain-modeler-to-backend-engineer.md` (after resumption)

```markdown
---
name: handoff-record
product: theatrewise
version: 1.0.0
phase: implement
owner: domain-modeler
created: 2026-06-08
summary: Theatres implementation stopped: theatre double-booking can't be enforced in SurgeryBooking; routed back to domain-modeler for a boundary revision.
from: domain-modeler
to: backend-engineer
mode: hand-over
status: model-revision
traces-to: [design/theatres/aggregates.md, design/theatres/domain-event-catalog.md, design/theatres/read-models.md, design/architecture/api-contract-theatres.md]
---

# Hand-over: domain-modeler → backend-engineer (Implement)

## Concerns handed over

| Concern | Artifact | Definition of Done met | Note |
|---|---|---|---|
| Aggregates for Theatres | design/theatres/aggregates.md | yes | approved 2026-05-30; now found wrong |
| Domain Event catalog for Theatres | design/theatres/domain-event-catalog.md | yes | — |

## Mode

- **Mode:** hand-over
- **Why:** hand-over: the default (the model was approved and stable when handed over)
- **Changes:** none

## Flags back

| # | Raised by | Artifact | What is wrong or missing, with evidence | Owner | Status |
|---|---|---|---|---|---|
| 1 | backend-engineer | design/theatres/aggregates.md | "a theatre is never double-booked" can't hold inside SurgeryBooking: two bookings load separate state and both take theatre 4 (failing concurrency test, 2026-06-07) | domain-modeler | open |

## Open questions

- Which Aggregate owns theatre allocation (per theatre and day?) — domain-modeler — blocking Theatres implementation

## Resumption

- **Interrupted:** 2026-06-07 — implementing SurgeryBooking
- **Kind:** model found wrong
- **Next step:** domain-modeler revises the Theatres Aggregate boundary for theatre allocation; downstream artifacts to review: design/theatres/domain-event-catalog.md, design/theatres/read-models.md, design/architecture/api-contract-theatres.md; implementation resumes under a new hand-over record once the product owner re-approves
```

## Why this is right

- The new session read the open records before doing anything, and told the two interruptions apart.
- The model found wrong went back to its owner, with every downstream artifact named for review; nothing was resumed forward on it.
- The operational pause continued as normal.
- `validate-handoff-record.sh` exits clean on the record.
