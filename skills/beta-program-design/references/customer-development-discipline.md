# Customer Development Discipline

The reasoning behind four of `SKILL.md`'s rules: the earlyvangelist screen, the pivot diagnosis, the outside-the-building check, and the repeatability and operations dimension of graduation. Grounded in Blank (*The Four Steps to the Epiphany*), Fitzpatrick (*The Mom Test*), Maurya (*Running Lean*), Moore (*Crossing the Chasm*) and Stickdorn et al. (*This Is Service Design Doing*).

## Earlyvangelist Screening Checklist

Blank's **earlyvangelist** is a stricter, checkable replacement for "early adopter": four facts about a **named** candidate, not a personality type.

1. **Already recognises the pain.** It does not need to be explained or sold to them.
2. **Has already spent effort on it.** Their own time, money or political capital: a manual workaround, a spreadsheet, a consultant, an internal stopgap, a rival tool they tried. This is direct evidence the pain is real. Record the workaround **by name** in the participant row.
3. **Has budget, or can get it.** Authority to adopt, not only enthusiasm.
4. **Is credible as a reference.** Visible enough in their organisation or market that their adoption persuades the next, colder audience.

A candidate who fails 1 or 2 is the classic trap: famous, enthusiastic, "loves the idea", and has never tried to solve the problem. Their feedback measures goodwill toward the relationship. Downgrade them (a later open-beta participant, or a discovery interview) or decline them. A candidate who fails only 3 or 4 may still join a closed stage; record the gap, because it limits how far their evidence transfers.

**Not Moore's early adopter.** Moore's visionary is defined by what they want (a strategic leap) and how much risk they accept. Blank's earlyvangelist is defined by checkable facts. They overlap, but answer different questions: Moore picks **which segment** to attack first (`gtm-strategy`'s beachhead); Blank picks **which named person** in that segment to let into the beta.

## Pivot Diagnosis

When a stage misses its bar, name the suspect hypothesis **before** choosing a decision. Blank treats a failed test as information about which assumption was wrong, not as a reason to repeat the test harder. Maurya adds: name the canvas block, so the business model is updated, not just the beta record.

| Suspect hypothesis | Evidence that points at it | Canvas block | Response |
|---|---|---|---|
| **Segment** | Participants who passed the screen still don't behave like the ICP; usage clusters in an unexpected kind of customer | Customer Segments / Early Adopters | Pivot: re-screen, recruit a different cohort |
| **Problem** | Participants can't recall a recent instance of the pain; their current workaround already handles it; activation is fine but retention decays | Problem / Existing Alternatives | Pivot: revisit the problem hypothesis the slice was built for |
| **Solution** | The pain is real and recent, but they keep their workaround alongside the product | Solution / Unique Value Proposition | Pivot: revisit the solution design, not this stage's execution |
| **Process** | Product and pain are confirmed, but each onboarding needed bespoke help | Channels | Remediate the documented onboarding and extend; pivot on process if it still won't repeat |

"Extend" and "remediate" assume the hypothesis holds. Adding a requested feature to a cohort that lacks the pain is not a remediation; it is extending a wrong hypothesis with more scope. A participant's feature request is an opportunity to examine (`opportunity-solution-tree`), not a fix for missing pain.

## Outside-the-Building Check

Before recording "behaviour and commitment" as met, ask how the evidence was obtained.

- **Counts:** the named contact described specific, recent use and friction in the past tense ("on Tuesday we booked 14 slots through it; two carriers ignored the link"); usage data shows the same; the contact made a **commitment** (Fitzpatrick): time on the calendar, an introduction to a colleague or buyer, access to real data, a paid pilot, a renewal.
- **Does not count:** a demo the team ran and liked; "it looks great"; "I would definitely use it"; a leading question the participant agreed with; internal consensus.

Fitzpatrick: compliments, generic claims and hypothetical futures are bad data; a conversation that ends with no advancement taught you little, however pleasant. Blank names the team-level version: a group can fool itself as easily as one person can be flattered. Question design for the check-ins: `feedback-template`.

## Repeatability and Operations

**Repeatability (Blank).** Customer Validation's real test is not "does it work for these customers" but whether a documented process converts a **new** one, run by someone other than the founder. Three partners who each say "it works" after three different hand-held onboardings is Discovery-grade evidence. Record, per participant: the documented steps used, the help needed beyond them, and who ran it. The same check feeds `acceptance-sign-off`'s repeatability line.

**Operations (Stickdorn).** A Minimum Viable Service is a small but fully real service, including its backstage: support, manual review, account set-up, escalation. Its riskiest unknowns are often operational: can the backstage run repeatedly, under real load, without the designer in the room? A closed stage rehearses that backstage with a real cohort. A support desk that has never handled a real query, or an onboarding only the product owner can do, fails this dimension however good the interface is.

## Traction (Maurya)

Maurya's progression: validate qualitatively (an MVP for early adopters, then interviews) and then verify quantitatively (launch, measured with cohort metrics). Product/Market Fit shows in **retention** and measurable demand. For graduation:

- take activation and retention from the canvas's Key Metrics (AARRR), one or two that matter at this stage;
- measure **per cohort** (the users who entered in week 1, week 2, …), as rates; never cumulative sign-ups, which only go up;
- set the target before the stage starts; a target set after the data is a negotiation.

A cohort whose weekly use decays while every quality metric is green has told you something about the problem or solution hypothesis, not about defects.
