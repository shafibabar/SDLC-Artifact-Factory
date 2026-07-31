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

---

## The Postmortem-Driven Alert Tuning Loop

This section describes the full closed loop connecting alerting design, incident response, and postmortem-driven improvement. It is the upstream counterpart to the monthly alert hygiene review: the review prunes noise; this loop generates structurally grounded changes.

### The Full Lifecycle

```
Alert fires
  → page
    → on-call responds (runbook applied)
      → incident declared (if SEV threshold met)
        → blameless postmortem
          → corrective actions (may include alert changes)
            → alert changes implemented
              → review log updated with "postmortem-generated change" flag
```

Every stage has a gate. An alert that fires but does not page (below-threshold, handled by dashboard monitoring) does not generate a postmortem. A page that is acknowledged and resolved via runbook without an incident declaration does not generate a postmortem. A postmortem is not always the right output — it is the right output when the incident met the SEV threshold requiring structured retrospective.

**Source:** The blameless-postmortem structure originates in Ch. 14 of *The DevOps Handbook* (Kim, Humble, Debois, Willis, 2016), which credits Etsy's practice and John Allspaw's "just culture" framing. The critical insight this skill borrows: corrective actions from a postmortem are *specific and grounded* — they come from a timeline with contributing factors, not from a general sense that "something should improve." Alert changes that come from a postmortem carry more epistemic weight than alert changes that come from noise reduction alone.

### What "Postmortem-Generated Alert Change" Means

A postmortem-generated alert change is one where the postmortem's corrective action items explicitly specify an alert modification. Three canonical forms:

| Corrective action type | Example | Alert effect |
|---|---|---|
| Add an alert | "There was no alert for X; we discovered the problem via dashboard 40 minutes into the incident" | New rule added to a rule group |
| Raise or lower a threshold | "The fast-burn multiplier of 14.4 paged us at a level that still had 26 days of budget remaining; incident resolved in 20 minutes — this is not a page-level severity" | `for:` window extended, or burn rate multiplier raised, or severity demoted from page to ticket |
| Delete a noisy alert | "This alert fired five times during the incident but gave no additional diagnostic value beyond the primary SLO burn alert" | Alert removed; inhibition rule added if the source condition is still worth knowing about on a dashboard |

In all three cases, the alert change is a *corrective action within the postmortem*, not a separate ongoing tuning process. The postmortem owns the decision rationale; this skill's review log records the implementation.

### The Monthly Cross-Check

The monthly alert review (run alongside the SLO review in `slo-definition`) gains one additional cross-check beyond the "did a human act?" hygiene pass:

**For every alert that fired in the review period but produced no postmortem:**

Investigate *why* no postmortem was generated. There are three valid explanations:

1. **Below SEV threshold, correctly handled via runbook only.** The alert fired, the on-call responded, the runbook resolved it, the incident did not rise to a level requiring a structured retrospective. This is correct behavior — not every page requires a postmortem, only those meeting the declared SEV threshold. No action needed; record "runbook-only" in the review log.

2. **False positive.** The alert fired, no real user-visible problem existed. This is the primary noise signal — a false positive is not handled via a runbook or incident; it is a page that should not have fired. Action: tune or delete (raise threshold, extend `for:` window, add a more restrictive condition, or delete the alert if it has only ever been noise). Record "false positive — tuned/deleted" in the review log.

3. **Missing postmortem.** The alert fired, a real incident occurred, a postmortem *should* have been produced but was not. This is a process gap — not an alerting gap. Action: produce the postmortem retrospectively if the incident is recent enough for the timeline to be reconstructible; acknowledge the gap in the review log if it is not. Do not tune the alert based on an incident with no retrospective documentation — the rationale for any change would be guesswork.

**For every alert that fired and DID produce a postmortem:**

Check whether the postmortem's alert-related corrective actions have been implemented. If a corrective action specified "add an alert for X" three months ago and no alert for X exists, that is an open item — record it in the review log as "postmortem corrective action pending" and schedule the implementation.

### Review Log Column: Postmortem-Generated Change?

The Review Log in `SKILL.md`'s Output Format includes a "Postmortem-generated change?" column. Valid values:

| Value | Meaning |
|---|---|
| `no` | Decision came from hygiene review only (noise reduction, keep, tune for `for:` window) |
| `yes — PM-YYYY-MM-DD` | Decision came from a postmortem corrective action; date is the postmortem date |
| `missing — needs postmortem` | Alert fired during an incident, no postmortem was produced; gap noted |
| `runbook-only` | Alert fired, resolved via runbook, below SEV threshold, no postmortem expected |
| `false positive — tuned/deleted` | Alert fired but no real user-visible problem existed |

The date reference (`PM-YYYY-MM-DD`) lets a future reviewer trace the alert change back to the postmortem document that produced it, without reconstructing the decision from memory. This traceability is the practical value of the column: alert designs that accumulate changes without documented rationale become opaque over time, particularly for a solo operator who is the only institutional memory.

### What This Skill Does and Does Not Own

| Activity | Owner |
|---|---|
| Designing alert rules and routing | `alerting-rules-design` (this skill) |
| Executing runbook procedures during a page | `runbook-authoring` skill |
| Authoring the blameless postmortem document | Candidate `postmortem-authoring` skill (not yet built — noted from two independent research sources) |
| Implementing postmortem corrective actions that affect alerts | `alerting-rules-design` (this skill) — the skill owns the alert definition change even when the decision originates in a postmortem |
| Tracking whether postmortem corrective actions have been completed | Monthly alert review (this skill's review discipline) |

The key boundary: postmortem *authorship* is not this skill's domain, but postmortem *consumption* — specifically, ingesting corrective actions that affect alert definitions — is. A postmortem that says "delete alert Z" is not complete until the alert is deleted and the review log records the deletion with its postmortem reference. This skill closes that loop.
