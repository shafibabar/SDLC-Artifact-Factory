# DDD Handoff Record Template

Fill-in record for one handoff between two (or more) agents on a DDD
concern, per `references/handoff-protocol.md`. Copy the template, replace
the placeholders, delete the guidance comments. One record per concern
being handed off — not one per agent pairing in general.

---

```markdown
---
name: handoff-<concern-slug>
version: 1.0.0
phase: <phase of the concern being handed off>
owner: <from_agent>
created: <YYYY-MM-DD>
from_agent: <agent name>
to_agent: <agent name>
concern: <the specific piece of DDD work changing hands — name it precisely>
interaction_mode: collaboration | x-as-a-service | facilitating
subdomain_classification: core | supporting | generic
status: in-progress | blocked | abandoned | completed
resumption_type: operational-pause | breakthrough-triggered-refactor | n/a
---

# Handoff — <Concern Name>

## Roster

<!-- Every agent currently party to this handoff. Add a row with a join
     date/trigger whenever the Roster Change Protocol adds someone mid-session. -->

| Agent | Role in this handoff | Joined | Trigger (if added mid-session) |
|---|---|---|---|
| <from_agent> | Producing | <initial> | - |
| <to_agent> | Consuming | <initial> | - |

## Artifacts Produced

<!-- What was actually produced so far, with real paths. Not a plan — what exists. -->

| Artifact | Path | Definition of Done met? |
|---|---|---|
| <artifact name> | <path> | yes / no |

## Open Questions

<!-- Unresolved items the next agent, or a resumed session, must see before continuing.
     If this handoff is `blocked` on a disputed ownership question, say so explicitly here. -->

- <question, who needs to answer it, and why it's blocking or not>

## Mode History

<!-- Only needed if interaction_mode changed mid-session. One entry per change. -->

| Date | From mode | To mode | Trigger |
|---|---|---|---|
| <date> | <mode> | <mode> | <what signaled the transition, per handoff-protocol.md> |

## Resumption Notes

<!-- Only needed if status is in-progress/blocked/abandoned after an interruption.
     Required whenever resumption_type is set to something other than n/a. -->

<For operational-pause: what's done, what's pending, which agent/stage is next.
For breakthrough-triggered-refactor: what was discovered wrong with the model,
and confirmation this has been routed back to domain-modeler rather than
resumed forward.>

## Verdict

<One or two sentences: handoff completed and artifact accepted by to_agent,
or still open with the single most important next step.>
```

---

## Completion rules

- `interaction_mode` and `subdomain_classification` are both required on every
  record — the mode should be justified by the classification per
  `handoff-protocol.md`'s Mode Selection Criteria, not picked freehand.
- **Facilitating** records may omit the Mode History and Resumption Notes
  sections entirely (delete them) — facilitating handoffs don't carry
  artifact ownership and rarely need either.
- **X-as-a-Service** records should keep Open Questions empty at
  `status: completed` — a completed X-as-a-Service handoff with open
  questions is a sign it should have been Collaboration; either resolve the
  questions or change the mode (recorded in Mode History) before marking
  complete.
- **Collaboration** records must not be marked `completed` while Open
  Questions has any unresolved entry.
- `resumption_type` is set to `n/a` only when `status` is `completed` or the
  session has never been interrupted. Any other status requires a real
  value and a corresponding Resumption Notes entry.
- Set `resumption_type: breakthrough-triggered-refactor` — not
  `operational-pause` — whenever the interruption happened because the
  model itself (an Aggregate boundary, a Context Map relationship, a
  subdomain classification) was found to be wrong, per
  `handoff-protocol.md`'s Resumption section. Getting this wrong causes a
  resumed session to build further on a model everyone already knows is
  incorrect.
