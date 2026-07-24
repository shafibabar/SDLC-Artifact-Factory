# Toil and Review Discipline

## What Toil Is, Formally

Google's SRE discipline (*Site Reliability Engineering*, Beyer/Jones/Petoff/Murphy, eds., 2016, Ch. 5, "Eliminating Toil," Vivek Rau) defines toil precisely — not as a synonym for "busywork," but as operational work meeting **all** of these properties:

- **Manual** — a human runs it by hand.
- **Repetitive** — done the same way each time; not a novel investigation.
- **Automatable** — a machine could do it. This is the property that separates toil from genuinely irreducible engineering judgment: diagnosing a novel failure mode is not toil, no matter how tedious it feels, because a script cannot yet do it.
- **Tactical** — interrupt-driven, reactive to the moment, not part of a strategic plan.
- **Devoid of enduring value** — the system is no better off after the task than before. Restarting a hung process doesn't teach the system anything; the same failure recurs next week.
- **Scales linearly with service growth** — the property that makes toil dangerous rather than merely annoying. Twice the traffic means twice the manual restarts. Engineering work that *reduces* toil should scale sub-linearly with growth; toil itself does not.

A task failing even one of these tests is not toil — it's either legitimate engineering work (not automatable, or has enduring value) or a one-off (not repetitive). Precision matters because the definition is what makes toil a trackable, budgetable quantity rather than a vague complaint.

## The Toil Ceiling, Honestly Scoped for One Operator

Google's stated policy is that SRE teams should spend no more than **50% of their time on toil**, with the rest protected for engineering work that reduces future toil. That ceiling is enforceable at Google because it assumes a structural escalation valve: an SRE org with the standing authority to hand a misbehaving service back to a separate product-development team if reliability work exceeds the ceiling for too long.

That valve does not exist here. This repo has one `platform-engineer` agent who is simultaneously "SRE" and the entire ops function, with no product-dev team to hand anything back to. Applying the 50% ceiling as an organizational policy would be borrowing a mechanism this repo doesn't have.

What *does* transfer: the ceiling still works as a **personal-sustainability heuristic**. A rising, unaddressed toil footprint — the same manual remediation recurring week after week — is not something the platform can absorb by rebalancing across a team; it is a signal worth surfacing to Shafi directly, because the only real fix at headcount one is a headcount or tooling-investment decision, and that decision is his to make, not something this skill or its review discipline can resolve on its own. The review's job is to make that signal visible early, not to enforce a percentage.

## The Toil Line in the Monthly Review

`SKILL.md`'s existing monthly review asks, per alert that fired: *did a human act? keep/tune/delete.* That question measures alert hygiene — whether the alert itself is well-calibrated — but says nothing about the cost of the human response it triggers.

Add one more question, asked for every alert where the answer to "did a human act?" was yes:

> **Did resolving this again require the same manual steps as last time — and if this is now the third-plus repetition, should the remediation be scripted or automated instead of paged at all?**

The "third-plus" threshold is deliberate: a manual fix run once or twice might still be cheaper to do by hand than to automate; a third occurrence of the identical manual procedure is the point at which automating the remediation is very likely to be the cheaper option and shouldn't need re-litigating from scratch each time. Where an alert repeatedly triggers the same fix, either automate the fix (turning the alert into a self-healing action with no page needed at all) or, if automation genuinely isn't warranted yet, note it explicitly as a known, accepted toil cost rather than letting it recur silently.

## The Solo-Operator Pager-Load Heuristic

The book's sustainable-on-call guidance is built around a *team*: a healthy rotation keeps reactive/interrupt work under roughly 25–50% of an engineer's time, spread across multiple people, and a single on-call shift seeing more than a couple of genuine incidents is treated as a signal that the system or the alert design — not the person — is unhealthy.

There is no rotation to spread load across here, so the team-scale percentage doesn't translate directly. What does translate is the underlying principle — sustained high pager volume is a system signal, not a personal-endurance test — restated as a solo-operator trigger:

> **A week producing more than a small, fixed number of real pages is itself a trigger for an unscheduled alert-hygiene pass**, run immediately rather than deferred to the next monthly review cadence.

"Real pages" excludes anything already flagged for deletion at the last review — the heuristic exists to catch the platform actually degrading between reviews, not to relitigate known, already-decided noise. When the threshold trips, apply the same keep/tune/delete/automate discipline as the monthly review, just out of cycle.
