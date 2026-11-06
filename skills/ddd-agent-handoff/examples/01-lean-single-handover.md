# Example 1 — Lean: One Short Hand-over

Self-contained. **Stitchroom** books sewing classes and machine time for one studio: two tutors, about 150 members, one deployable. **Lean** profile. The domain-modeler has produced the one lean domain model (`design/domain-model.md`, with Aggregates, events, Commands and the Read Models table) and hands it to enterprise-architect for the container diagram.

## Input

> **User:** "Can enterprise-architect also tidy the domain model while it's in there? The `MachineBooking` rule says a booking is at most 3 hours, but the studio actually allows 4 on Saturdays."

## Working it

- **Ownership:** the domain model is the domain-modeler's (`aggregate-design`); the container diagram is enterprise-architect's. Enterprise-architect does not edit `domain-model.md`.
- **The Saturday rule** is a defect in the domain model, so it is a **flag back** to the domain-modeler, with the evidence (the user's statement now; the studio's opening rules in the stories). The domain-modeler fixes the invariant; because the product owner had approved the model, it returns to draft for re-approval.
- **Does the flag stop the hand-over?** No: the container diagram doesn't depend on the booking limit. Enterprise-architect continues and the record stays *open* until the flag is fixed.
- **Mode:** hand-over. Lean, Supporting subdomain, nothing regulated, no disputed boundary.
- **Read side:** lean has no CQRS record; every context uses a Simple Read Model, listed in the domain model. Nothing to decide.

## Output: `artifacts/stitchroom/design/handoffs/domain-modeler-to-enterprise-architect.md`

```markdown
---
name: handoff-record
product: stitchroom
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-02-03
summary: Domain model handed to enterprise-architect for the container diagram; one flag open on the Saturday booking limit.
from: domain-modeler
to: enterprise-architect
mode: hand-over
status: open
traces-to: [design/domain-model.md, design/context-map.md]
---

# Hand-over: domain-modeler → enterprise-architect (Design)

## Concerns handed over

| Concern | Artifact | Definition of Done met | Note |
|---|---|---|---|
| Lean domain model: Classes and Machines contexts, Aggregates, events, Commands, Read Models | design/domain-model.md | yes | — |
| Context Map | design/context-map.md | yes | — |

## Mode

- **Mode:** hand-over
- **Why:** hand-over: the default
- **Changes:** none

## Flags back

| # | Raised by | Artifact | What is wrong or missing, with evidence | Owner | Status |
|---|---|---|---|---|---|
| 1 | enterprise-architect | design/domain-model.md | MachineBooking invariant caps a booking at 3 hours; the studio allows 4 on Saturdays (user, 2026-02-03) | domain-modeler | open |

## Open questions

- none
```

## Why this is right

- Enterprise-architect never touched the domain model; the defect went to its owner with evidence.
- The record stays *open* until the flag is fixed; the container diagram goes ahead because it doesn't depend on the rule.
- `validate-handoff-record.sh` exits clean on the record.
