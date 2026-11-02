# Example 1 — Lean: one Core, everything else bought or kept simple (simplest case)

Self-contained. **Handrota** is a volunteer rota app for Westmere Community Kitchen, a charity that serves 400 meals a week with about 60 volunteers, at the **lean** profile. The domain-modeler has just built the Event Storming Big Picture (agent-run) from the vision and job stories.

## Input

> **User:** "Can you do the subdomain bit? I'd say it's all Core, really. Every part of it matters to us."

## Working it

- **"It all matters" isn't the test.** The question is what the kitchen would choose Handrota for over a spreadsheet or a generic scheduling tool. The vision answers it: the coordinator spends Sunday evenings filling gaps, because each session needs a food-hygiene-certified volunteer, at least one driver for deliveries, and no more than two first-timers.
- **Splitting the Big Picture.** The capabilities are Volunteers, Rota and Messages. Rota splits into *filling sessions under the kitchen's rules* and *the calendar view*, which get different types, so splitting is worth it there. Splitting stops at "swap a session" and "cancel a session": same type as their parent.
- **Three tests per piece:**

| Piece | Advantage? | Complex? | Solved elsewhere? | Type |
|---|---|---|---|---|
| Filling sessions under the kitchen's rules | Yes: the reason to switch from the spreadsheet | Yes: certification, drivers, first-timer limits, availability | No: generic schedulers don't know these rules | **Core** |
| Calendar view | No | No | Yes: a calendar component | Generic |
| Volunteer records | No | No | No: too specific to buy, but simple | Supporting |
| Sign-in | No | Yes, but solved | Yes: an identity service | Generic |
| Reminders (email, SMS) | No | No, once bought | Yes: a messaging service | Generic |

- **Security axis:** volunteer records hold names, phone numbers and certificates (checklist question 1). The slice is *which coordinator sees which volunteers' contact details*. Lean records it in one line.

## Output — the reply, and `artifacts/handrota/design/subdomain-classification.md`

> Not all Core. The one thing the kitchen would switch for is filling sessions under its own rules: certified volunteers, drivers, the first-timer limit. That's the Core, and it gets a proper domain model with its rules made explicit. The calendar, sign-in and reminders are solved problems, so we use existing components. Volunteer records are simple and specific, so we build them plainly, as straightforward record-keeping code with no elaborate model. One flag: contact details are personal data, so who can see them gets proper rules even though records are simple. I've dated the table; if a scheduling product with rule support appears, we revisit.

```markdown
---
name: subdomain-classification
product: handrota
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-05-04
summary: Handrota subdomains; Core is filling sessions under the kitchen's staffing rules; calendar, sign-in and reminders adopted; volunteer contact details flagged sensitive.
profile: lean
traces-to: [design/event-storming-big-picture.md, strategy/vision.md, ideate/job-stories.md]
classified-on: 2026-05-04
---

# Subdomain Classification: Handrota

## How the Subdomains Were Found

From the Big Picture's three capabilities; Rota split into session filling and the calendar view because they get different types. Swaps and cancellations stay inside session filling.

## Classification

| Subdomain | Type | Advantage? | Complex? | Solved elsewhere? | Sourcing | Modelling | Security-sensitive slice | Revisit when |
|---|---|---|---|---|---|---|---|---|---|
| Session filling | Core | Yes: why the kitchen switches | Yes: four interacting rules | No | In-house | Domain Model | Checklist run: none | A rota product with configurable staffing rules appears |
| Calendar view | Generic | No | No | Yes: calendar component | Adopt | Thin integration | None | — |
| Volunteer records | Supporting | No | No | No | Cheap build | Transaction Script | Coordinator access to contact details | A second kitchen joins (sharing rules) |
| Sign-in | Generic | No | Solved | Yes: identity service | Adopt | Thin integration | None beyond records | — |
| Reminders | Generic | No | No | Yes: messaging service | Buy | Thin integration | None | — |

## Open Questions for the Product Owner

| # | Question | Label assumed meanwhile |
|---|---|---|
| 1 | Will other kitchens use Handrota, each with their own rules? | Session filling stays Core either way; volunteer records would gain sharing rules |
```

## Why this is right

- "Everything matters" was answered with the advantage test, not agreement.
- The split happened only where types differed, and stopped there.
- Lean is a short table with evidence, a date and a security flag, not a skipped step.
