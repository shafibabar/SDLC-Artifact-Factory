# Escalation and Postmortem Linkage

## Escalation at a Headcount of One

*Stub — to be filled by sub-issue #206. Brief: honestly scopes on-call escalation for a solo operator — no secondary exists to escalate an unacknowledged page to, so Alertmanager's `repeat_interval` is the closest available mechanic, but it is explicitly *not* a real escalation policy since it only re-pages the same unresponsive person. States what escalation can honestly mean here: a documented "unacknowledged page" leaf that surfaces the gap rather than pretending a rotation exists.*

## What This Skill Does Not Own

*Stub — to be filled by sub-issue #206. Brief: states plainly that `alerting-rules-design` does not author postmortems — a standalone `postmortem-authoring` skill is a candidate surfaced independently by two research sources during this rebuild's discovery, but building it is out of scope for this issue. This skill's monthly review keeps `runbook-authoring`'s existing scope untouched.*

## The Postmortem-Linkage Check

*Stub — to be filled by sub-issue #206. Brief: the one new input this skill's monthly review gains — for a fired-and-actioned alert, does it have an open postmortem with unresolved action items? This is a review input the skill consumes, not a new artifact it produces.*
