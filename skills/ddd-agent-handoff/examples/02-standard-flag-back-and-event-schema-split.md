# Example 2 — Standard: A Flag Back, and Who Owns an Event

Self-contained. **Hearthline** delivers heating oil to 9,000 rural homes from three depots: customers order online or by phone, drivers deliver from tankers. **Standard** profile; contexts **Ordering**, **Deliveries** and **Accounts**. The domain-modeler has handed the Deliveries Aggregates and event catalog to the data-architect, who is designing the physical model and the event schemas.

## Input

> **Data-architect (to the user):** "Two things. The `Delivery` Aggregate says one delivery is made by exactly one tanker, but the depot data has 40 deliveries last winter split across two tankers when the first ran dry. I'll change the invariant in `aggregates.md` so I can model the tables. Also, `DeliveryCompleted` is ambiguous: I'll redefine it as 'tanker left the customer's drive' and publish it as `delivery.completed.v2` so consumers know."

## Working it

- **The invariant is the domain-modeler's** (`aggregate-design`). The data-architect has evidence a rule is wrong; it **flags it back** and does not edit `aggregates.md`. The domain-modeler decides what the rule becomes (a delivery may have several *legs*, each by one tanker?), which may change events and Commands too. Since the Aggregate design was approved, the fix returns it to draft for re-approval.
- **What `DeliveryCompleted` means is also the domain-modeler's** (`domain-event-catalog`, D047-2). Whether "completed" means the tanker left, or the oil is metered in, is a business fact: Accounts bills on it. The data-architect flags the ambiguity; it doesn't redefine the event.
- **How a changed event is published is the data-architect's** (`event-schema-design`, D047-1): if the domain-modeler changes the meaning, that is a breaking change, so it becomes a **new event type** (for example `DeliveryMetered`) in the CloudEvents envelope, never a `.v2` suffix on the old one.
- **Mode:** the hand-over started as a plain hand-over. This is the data-architect's second flag on the same artifact (the first was a missing `TankerAssigned` field), which is the trigger to escalate to joint review for the rest of Deliveries.
- **Physical model:** the data-architect continues with Ordering and Accounts; Deliveries tables wait for the revised Aggregate.

## Output: `artifacts/hearthline/design/handoffs/domain-modeler-to-data-architect.md` (excerpt)

```markdown
---
name: handoff-record
product: hearthline
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-01-19
summary: Aggregates and event catalogs handed to data-architect; Deliveries in joint review after two flags (split deliveries, DeliveryCompleted meaning).
from: domain-modeler
to: data-architect
mode: joint review
status: open
traces-to: [design/ordering/aggregates.md, design/deliveries/aggregates.md, design/deliveries/domain-event-catalog.md, design/accounts/aggregates.md]
---

# Hand-over: domain-modeler → data-architect (Design)

## Concerns handed over

| Concern | Artifact | Definition of Done met | Note |
|---|---|---|---|
| Aggregates for Ordering | design/ordering/aggregates.md | yes | — |
| Aggregates for Accounts | design/accounts/aggregates.md | yes | — |
| Aggregates for Deliveries | design/deliveries/aggregates.md | no — single-tanker invariant contradicted by depot data (flag 2) | — |
| Domain Event catalog for Deliveries | design/deliveries/domain-event-catalog.md | no — DeliveryCompleted meaning ambiguous (flag 3) | — |

## Mode

- **Mode:** joint review
- **Why:** second flag of the same kind on design/deliveries/aggregates.md; joint review until Deliveries is stable
- **Changes:** 2026-01-19: hand-over → joint review, because a second flag was raised on the Deliveries Aggregates

## Flags back

| # | Raised by | Artifact | What is wrong or missing, with evidence | Owner | Status |
|---|---|---|---|---|---|
| 1 | data-architect | design/deliveries/aggregates.md | TankerAssigned carries no tanker capacity; the physical model needs it to size a delivery | domain-modeler | fixed |
| 2 | data-architect | design/deliveries/aggregates.md | "one delivery, one tanker" is contradicted by 40 split deliveries last winter (depot export, 2025-26) | domain-modeler | open |
| 3 | data-architect | design/deliveries/domain-event-catalog.md | DeliveryCompleted: left the drive, or oil metered in? Accounts bills on it | domain-modeler | open |

## Open questions

- If DeliveryCompleted's meaning changes, data-architect publishes the new meaning as a new event type (event-schema-design); which name? — domain-modeler — not blocking Ordering or Accounts
```

## Why this is right

- Two defects in artifacts the data-architect doesn't own became flags with evidence; nothing was edited across the boundary.
- Meaning stayed with the domain-modeler, publishing with the data-architect: a breaking change is a new type, not a suffix.
- The second flag escalated the mode, with the trigger recorded; unaffected contexts carried on.
- `validate-handoff-record.sh` exits clean on the excerpt.
