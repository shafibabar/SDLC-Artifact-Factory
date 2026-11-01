# Example 1 — Lean: an internal tool rolled out to one team, then all staff, on a one-page record (simplest case)

Self-contained. **Deskbook** is a desk-booking tool for Hartwell & Co, a 220-person architecture practice, at the **lean** profile. Every user is a member of staff. `phase-requirements.json` skips the beta program at lean, but the user asked for a staged rollout because the last tool "went to everyone at once and nobody used it".

## Input

> **User:** "Can we try Deskbook with a few people first? I was going to just send it to the whole office on Monday with a how-to email. Facilities are keen."

## Working it

- **Lean, and the user asked**, so one page with two stages. The shape is **internal**: a closed alpha with the team that feels the pain most, then GA for all staff. No open beta, because there is no outside audience; the record says so.
- **Who goes first.** Facilities rebuild a desk spreadsheet every Friday (a named workaround, earlyvangelist 2) and field the complaints, so they recognise the pain. Add one studio (11 people) so the alpha includes ordinary users, not only the team that asked for it.
- **Graduation, all four dimensions, targets set now.** Traction is easy to measure here, so it carries weight: activation (booked at least once in week 1) and retention (booked again in week 2). Commitment: facilities stop maintaining the spreadsheet. Repeatability: the studio starts from the intranet page alone. Operations: facilities release no-show desks each morning without the product owner.
- **Data handling** in the practice's own terms: staff names and booking history, under its data protection policy and UK GDPR. No SOC 2 here; the practice has none.

## Output — the reply, and `customer-validation/beta-program/deskbook-r1.md`

> Yes. A one-page plan: two weeks with facilities and Studio 3, then everyone. It moves to all staff only if most of the alpha book again in week 2, facilities have stopped using their Friday spreadsheet, and Studio 3 got started from the intranet page without help. I've set the targets now so we can't move them later. Please approve the targets and the start date.

````markdown
---
name: beta-program-deskbook-r1
product: deskbook
release-slice: r1
version: 1.1.0
phase: customer-validation
owner: requirements-analyst
created: 2026-03-02
summary: Deskbook R1 internal rollout: facilities and Studio 3 alpha for two weeks, then all staff; graduated on week-2 rebooking, spreadsheet retired and self-serve start.
profile: lean
traces_to: customer-validation/uat-plan.md; strategy/business-model-canvas.md
---

# Beta Program — deskbook r1

## Shape
Internal rollout — stages run: closed alpha → GA; left out, and why: closed beta and open beta — all users are staff, so there is no outside cohort.

## Stage
GA

## Participants
Facilities team (4, lead Priya Natt) and Studio 3 (11, lead Owen Reyes) as the alpha; all staff (220) at GA.

| Candidate | ICP | Feedback | Rough edges | Named contact | Pain + prior effort (name the workaround) | Budget + reference | Result |
|---|---|---|---|---|---|---|---|
| Facilities team | y — books and polices desks daily | y | y | Priya Natt, facilities lead | Friday desk spreadsheet, rebuilt weekly since 2024 | y — owns the workplace budget; staff listen to her | in |
| Studio 3 | y — ordinary hybrid workers | y | y | Owen Reyes, studio lead | Slack "anyone using desk 14?" threads | n/a internal | in |

## Rollout Mechanic
Single-tenant deployment, no canary. feature-flag-design: `deskbook.enabled` on for the alpha group's accounts, then for all staff; removed after GA week 2.

## Beta Agreement Status
A short note to both alpha teams, acknowledged by Priya Natt and Owen Reyes on 2026-03-02.

## Feedback Cadence
Fifteen-minute check-in with each lead on days 5 and 10; issues in the #deskbook channel; UAT scenarios run by the facilities team on day 1.

## Data Handling Statement
No control is relaxed for this beta: the same access control, data classification, encryption, tenant isolation and audit logging apply as at GA.
- Frameworks: Hartwell & Co's data protection policy; UK GDPR (staff names and booking history)
- Telemetry: none beyond GA

## Graduation Criteria
Targets set before the stage starts.
- Quality: all Must UAT scenarios pass; open defects within acceptance-sign-off's defect rule
- Traction: ≥ 80% of the alpha book at least once in week 1; ≥ 60% book again in week 2
- Behaviour and commitment: each lead describes the last week's use, past tense; facilities stop maintaining the Friday spreadsheet
- Repeatability and operations: Studio 3 start from the intranet page with no walkthrough; facilities release no-show desks each morning without the product owner

## Graduation Record
Decision: Advance
Suspect hypothesis: none
2026-03-16, closed alpha → GA. Quality: UAT 5 of 5 pass; one Low open (calendar icon misaligned). Traction: 14 of 15 booked in week 1 (93%); 11 of 15 again in week 2 (73%). Behaviour: Priya Natt — "I didn't open the spreadsheet on Friday; Thursday's no-shows were released by 10." Commitment: the spreadsheet is archived. Repeatability: 10 of 11 in Studio 3 started from the intranet page; one asked how to book a recurring desk, and the page now covers it. Rollout: flag on for all staff, handed to platform-engineer.
````

## What the weak first draft looked like

"Send to the whole office Monday with a how-to email." No stage to learn from, no target set in advance, and no one checks whether people still book in week 2, which is exactly how the last tool died.
