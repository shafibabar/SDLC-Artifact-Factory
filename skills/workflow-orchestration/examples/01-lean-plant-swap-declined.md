# Example 1 — Lean: A Two-Step Flow Where the Requested Engine Is Declined

Self-contained. **Swapleaf** is a hobby app where neighbours swap houseplant cuttings. **Lean** profile, one deployable (a modular monolith) with one database and two modules: **Swaps** (offers, acceptances) and **Notifications** (emails and pushes). When a member accepts an offer, the swap is confirmed and both members are told.

## Input

> **User:** "Set up a workflow engine so the swap flow is orchestrated: step one confirms the swap, step two sends both notifications. Every step needs a compensation so a failure undoes everything, and I want a dashboard of where each swap is."

## Working it

- **Trigger check (Richardson's rule).** Branching or looping: no. A long wait: no (acceptance is instant). One view of progress as a requirement: a status column covers it. Compensation across 4 or more services: no, there is one deployable. **No trigger fired.** There is also no saga: both steps live in one deployable and one database, so they are not separate local transactions across services.
- **What to do instead.** Confirming the swap and recording the "send notifications" work happen in **one local transaction**. After it commits, the Notifications module reacts and sends; a failed email is retried by the module and, if it keeps failing, an alert goes to the maintainer. The swap is never undone because an email failed.
- **"A compensation for every step"** does not apply: a failed notification is retried forward, not undone, and the confirmation is not something to roll back for the sake of an email. A workflow engine for this adds a component to run for no benefit, against the frugality rule; even once a trigger fires, one flow gets a hand-rolled coordinator, and an engine is considered only when many orchestrated flows have accumulated.
- **The dashboard** reads the swap's own status (offered, confirmed, notified). That is the Swaps module's table, not an orchestrator's.
- **When the answer would change:** the flow gains branching (counter-offers, a courier option), a wait of hours or days (the other member must agree within a week), a need for one view of progress across several services, or an undo that spans 4 or more services. Then revisit, with the Richardson trigger named.

## Output: the reply (no document at lean)

> **No orchestration for the swap flow.** None of Richardson's triggers fires, and both steps live in one deployable and one database, so this is one local transaction, not a saga.
>
> - Confirming the swap and queuing the notifications commit together. The Notifications module sends after commit and retries a failed send; it never undoes the swap.
> - No per-step compensation: a failed email is retried, not reversed.
> - No workflow engine: it is one more component to run, with nothing to coordinate. The dashboard reads the swap's status column.
> - **I would revisit** if the flow gains branching, a multi-day wait, a requirement for one progress view across several services, or an undo across 4 or more services.
>
> No Workflow Orchestration Design document is produced at lean. If the swap flow later meets a trigger, it becomes a short design with one saga, one pivot and its compensations.
