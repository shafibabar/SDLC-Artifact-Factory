# Example 1 — Lean: no epic list; epic headings in the backlog (simplest case)

Self-contained. **Toolshed** is a tool-loan tracker one volunteer is building for a 60-member community makerspace, replacing a shared Google Sheet. The product runs at the **lean** profile. `phase-requirements.json` **skips** the epic list at lean, and there is no impact map and no functional requirements document either: the user story backlog is the requirements. This example shows what the agent writes when the user asks for an epic list anyway.

## Input

> **User:** "Can you do the epic list for Toolshed before the stories? Make the overdue stuff a Must, and say how many sprints each epic is."
>
> **KR (strategy/okrs.md, KR-1.1):** "Share of borrowed tools back by their due date, 55% → 85% by 2027-03-31."
>
> **Personas (ideate/user-personas.md, PROTO):** P-1 member who borrows: J-1 "get the tool I need for a weekend project without asking around", JS-1.1 "When I start planning a project on Thursday, I want to see whether the tool is in, so I can plan the weekend around it", JS-1.2 "When I've finished with a tool, I want to know when it's due back, so I can return it before someone else needs it". P-2 tool steward: J-2 "keep the shared tools in working order and where people expect them", JS-2.1 "When a tool is overdue, I want to know who has it, so I can ask for it back before Saturday".
>
> **Backlog header (already written, `requirements-analysis` lean):** BR-1 loans are due after 7 days, extendable once; BR-2 a member 7+ days overdue cannot borrow again until it is back; TR-1 import the sheet's 1,240 loan rows; TR-2 one-week parallel run; TR-3 a 5-minute walkthrough for the two stewards; TR-4 the sheet made read-only. ASM-1 members will check a due date online rather than ask a steward.

## Working it

- **No `ideate/epics.md`.** The profile skips it. Seven stories still cluster into two outcomes, so they are grouped under two epic headings inside `ideate/user-stories.md`. With three or four stories, no epics at all would be right.
- **Trace to the KR, not a map.** There is no impact map at lean, so each heading carries one trace line, KR → actor → behaviour change, with a typed assumption and a signal (the same shape `impact-mapping` uses at lean).
- **"Make it a Must" is declined, kindly.** Priority stays provisional (high / medium / low). At lean the backlog's closing Must / Won't-this-time block finalises it (`user-story-writing`); it is not set on the epic.
- **No sprints.** There are none; an agent builds Toolshed. Size is the story count.
- **Transition.** TR-2 to TR-4 are procedures and stay in the header. The import (TR-1) becomes a story because the overdue list is useless without the loans already out.

## Output — the reply, and the epic headings for `ideate/user-stories.md`

> At lean there's no separate epic list (and no impact map or FRD), so I haven't written `ideate/epics.md`. Your seven stories fall into two outcomes, so I've grouped them under two epic headings in the backlog, each traced straight to KR-1.1. I've left priority provisional rather than marking the overdue epic Must: the Must / Won't-this-time block at the end of the backlog settles that once all stories are written. And there are no sprints to size against, so each epic is sized by its stories.

```markdown
### EPIC-1: Members know what is in and when their loans are due

Trace: KR-1.1 → members (P-1, primary) → return tools by the due date instead of keeping them
until someone asks → this epic. Assumption [desirability]: members check a due date online
rather than asking a steward (ASM-1). Signal: share of loans back by the due date.
Priority (provisional): high · Size: S (3 stories)

- US-1 See whether a tool is in, and when it is due back (JS-1.1)
- US-3 See my own loans and their due dates (JS-1.2)
- US-4 Get a reminder the evening before a loan is due (JS-1.2)

### EPIC-2: Overdue tools come back before the weekend

Trace: KR-1.1 → tool stewards (P-2, secondary) → ask for overdue tools on Friday instead of
finding them missing on Saturday → this epic. Assumption [usability]: stewards read a Friday
list on a phone in the workshop. Signal: overdue loans still out on Saturday morning.
Priority (provisional): high · Size: S (4 stories)

- US-7 Stewards see every open loan from the old sheet on day one (TR-1)
- US-2 Friday list of overdue tools and who has them (JS-2.1, BR-1)
- US-5 A member 7+ days overdue cannot start another loan (BR-2)
- US-6 A steward extends a loan once by 7 days (BR-1)
```

## What the weak first draft looked like

```markdown
# Epics
| Epic | Priority | Sprints |
| Overdue management module | Must | 2 |
| Member portal | Should | 3 |
```

A separate epic file the lean profile skips, component names instead of outcomes ("module", "portal"), MoSCoW set before the backlog's Must / Won't-this-time block, sprint counts in a pipeline with no sprints, and no trace to KR-1.1.

## Why this is right at lean

| Choice | Reason |
|---|---|
| Headings in the backlog, no `epics.md` | The profile skips the epic list; the backlog is the requirements |
| A trace line instead of the full epic shape | Short artifacts at lean; the trace, assumption and signal still apply |
| Provisional priority | The backlog's closing block finalises it, as MoSCoW does at standard |
| Size by story count | No sprints, no estimates; S = 3–4 stories |
| Import as a story, other transition lines as procedures | The import changes what a user can see; the walkthrough and archiving do not |
