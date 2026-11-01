# Example 1 — Lean: one ad hoc email becomes two items, one bug routed to a named engineer and one idea turned into a need (simplest case)

Self-contained. **Fernpost** tracks parcels in the post room of a 140-flat apartment building, at the **lean** profile. The concierge logs each parcel; residents get a text to collect it. The only users in the beta are the two concierges.

## Input

> **User:** "Got this from Dev, the day concierge: 'Residents in block C keep saying they never get the pickup text. Three came to the desk yesterday asking. Also you should add WhatsApp, everyone uses it.' Can you log it? Sounds like a big pattern, and let's put WhatsApp on the list."

## Working it

- **Two findings, two items.** The missing texts are a bug; WhatsApp is an idea.
- **Context as a specific event.** Dev's email names yesterday and three residents; ask Dev for one flat number and a parcel ID so the item is reproducible.
- **Pattern?** It is one reporter. Three residents asking at the desk is one concierge's account of one symptom, not three independent reports through the log. It is still **High**: notification is a Must flow and it fails for a whole block. A single report is enough to act on a High; the pattern question does not change the severity.
- **Route to a named engineer.** The text is sent by the notification service, so it goes to the `backend-engineer`, who re-routes it with a reason if the cause turns out elsewhere.
- **WhatsApp is an idea.** The need behind it: residents notice the text too late or not at all. That is a missing capability for the requirements-analyst, as a later-release requirement, not a Must added now.
- **Severity scale.** Critical, High, Medium and Low are this plugin's house scale.

## Output — the reply, and `customer-validation/feedback/2026-04-09.md`

> Logged as two items. The missing texts in block C are High: residents of a whole block don't learn their parcel has arrived. They go to the backend-engineer, and I've asked Dev for one flat and parcel ID so it can be reproduced. It's one report so far, not a pattern, but a High doesn't need a pattern to be acted on. WhatsApp is logged as the need underneath it, "residents don't see the pickup message in time", for the requirements-analyst to weigh for a later release.

````markdown
---
name: feedback-log-fernpost-2026-04-09
product: fernpost
release-slice: r1
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-04-09
summary: Fernpost feedback 9 April: pickup texts not reaching block C (High, backend-engineer); WhatsApp request recorded as a need to notice pickups in time.
profile: lean
traces_to: customer-validation/uat-plan.md; email from the day concierge, 2026-04-09
---

# Feedback Log — fernpost 2026-04-09

## Sources
One ad hoc email from the day concierge.

## Items

### FB-01: Block C residents receive no pickup text
**Source:** ad hoc report
**Reporter:** Dev Malik, day concierge, Harbour Court
**Date:** 2026-04-09
**Context — what happened:** On 8 April three block C residents came to the desk asking for parcels logged that morning; none had received a text. Block A and B residents collected as normal.
**Expected vs. Actual:**
- Expected: a pickup text when a parcel is logged
- Actual: no text for block C flats
**Category:** bug
**Severity:** High
**Underlying need:** n/a
**Supporting detail:** relates to US-2, UAT-2a; flat and parcel ID requested from the reporter
**Routed to:** backend-engineer
**Rollup:** symptom "no pickup text", cause unknown; single reporter

### FB-02: Residents don't see the pickup message in time
**Source:** ad hoc report
**Reporter:** Dev Malik, day concierge, Harbour Court
**Date:** 2026-04-09
**Context — what happened:** In the same email: "you should add WhatsApp, everyone uses it."
**Expected vs. Actual:**
- Expected: residents notice a pickup message the day it arrives
- Actual: (reported) texts are missed or seen late
**Category:** missing capability
**Severity:** Low
**Underlying need:** "When a parcel arrives, I want to notice the message the same day, wherever I usually read messages." (notification moment)
**Supporting detail:** proposed feature: WhatsApp notifications
**Routed to:** requirements-analyst
**Rollup:** need "notice pickups in time"; one story

## Rollup by Symptom and Cause
| Group | Items | Independent reporters | Cause | Severity | Owner | Status |
|---|---|---|---|---|---|---|
| No pickup text (block C) | FB-01 | 1 | unknown | High | backend-engineer | open |

## Rollup by Customer Need
| Customer need | Stories mentioning it (independent) | Items | Parent opportunity |
|---|---|---|---|
| Notice pickups the same day | 1 | FB-02 | Residents collect parcels quickly |

## Patterns for the Sign-Off
None.

## Positive Signals
None reported.

## Sent Elsewhere
None.
````

## What the weak first draft looked like

One item, "Texts not working + add WhatsApp, big pattern, route to engineering". It merged a bug with a feature idea, called one concierge's email a pattern, sent it to nobody in particular, and put WhatsApp on the list as a solution with no need behind it.
