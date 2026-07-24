# Escalation and Postmortem Linkage

## Escalation at a Headcount of One

Google's on-call model (*Site Reliability Engineering*, Ch. 11 and Ch. 13) assumes a rotation: primary and secondary on-call, spread across at least two — ideally more — geographically distributed engineers, with a documented escalation path to the secondary if the primary doesn't acknowledge a page in time. Escalation, in that model, means *notify a different human*.

That mechanism has no honest analog here. This platform has exactly one operator; there is no secondary to escalate to. `SKILL.md`'s Alertmanager config uses a short `repeat_interval` on page-severity routes (`4h`, re-firing until resolved or silenced) — that is the closest available mechanic, but it must not be presented as an escalation policy, because it isn't one: a shorter repeat interval re-pages the *same* unresponsive person more insistently. It notifies no one else and answers nothing about what happens if the page is never acknowledged at all.

The honest scope for "escalation" at headcount one is narrower than the word usually implies: not a second human to fail over to, but a documented answer to *what happens when a page goes unacknowledged*. Concretely, that means:

- Treat "page fired, no acknowledgment within the repeat window" as its own tracked condition — an **unacknowledged-page leaf** — rather than letting the repeating page stand in silently for a real escalation policy.
- State plainly, wherever this gap could otherwise be assumed away, that no secondary exists. A future reader (including a future Shafi staffing decision) should be able to tell from this skill's text alone that "escalation" here means "the same person gets paged again, more often" — not infer a rotation that was never built.
- If sustained unacknowledged pages become a real pattern, that is itself toil-adjacent signal — see the pager-load heuristic in `references/toil-and-review-discipline.md` — worth surfacing as a staffing or tooling question, not something this skill can fix by adding more repeat-interval tuning.

## What This Skill Does Not Own

`alerting-rules-design` detects and routes alerts; it does not own incident narrative or retrospective process. Specifically, this skill does **not** author postmortems — the document that captures what happened during an incident, why, and what corrective action follows from it.

A standalone `postmortem-authoring` skill is a real candidate, surfaced independently during this rebuild's discovery from two separate sources (this book's Ch. 15, and — for the DevOps Handbook's own related finding — `research/devops-and-delivery/devops-handbook-kim-humble-debois-willis.md`). Two independent primary sources landing on the same missing artifact is a reason to trust the gap is real, not a coincidence to explain away. Building that skill is explicitly out of scope for this issue — noted here as a follow-up candidate, not built.

This also leaves `runbook-authoring`'s existing scope untouched: its lightweight post-incident note (worked as written / needed correction, against a specific runbook) remains what it already is — a note about the runbook's own accuracy — and is not stretched to cover incident-level postmortem content it was never designed to hold.

## The Postmortem-Linkage Check

The one new input this skill's monthly review gains, alongside the toil line in `references/toil-and-review-discipline.md`:

> **Does this alert's fired-and-actioned history have an open postmortem with unresolved action items?**

This is a review *input* the skill consumes, not a new artifact it produces. If a postmortem exists (however it was authored, pending a future `postmortem-authoring` skill) and its corrective actions remain open, that context belongs in the same review pass that decides whether to keep, tune, delete, or automate the alert — an alert tied to an incident with unresolved follow-up is a weaker candidate for deletion or threshold-loosening than one with none, even if it hasn't fired again recently. The check surfaces that connection explicitly instead of leaving it to be remembered informally.
