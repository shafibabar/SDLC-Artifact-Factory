# Example 1 — Lean: the backlog is the requirements; gap stories from the map, split by CRUD; the closing Must / Won't-this-time block (simplest case)

Self-contained. **Toolshed** is a tool-loan tracker one volunteer is building for a 60-member community makerspace, replacing a shared Google Sheet. The product runs at the **lean** profile: `phase-requirements.json` skips the functional requirements document, the epic list, the impact map and the MoSCoW artifact, and makes the story map optional. So `ideate/user-stories.md` holds everything Ideate decides: the **requirements header** (`requirements-analysis`), **epic headings** with a KR trace line (`epic-definition`), the stories, and the closing **Must / Won't-this-time block** (`story-mapping`). This example shows the whole file after one round trip with the story map.

## Input

> **KR-1.1:** "Share of borrowed tools back by their due date, 55% → 85% by 2027-03-31."
>
> **Personas (ideate/user-personas.md, PROTO):** P-1 member who borrows: J-1 "get the tool I need for a weekend project without asking around", JS-1.1 (see whether the tool is in, Thursday), JS-1.2 (know when it's due back). P-2 tool steward: J-2 "keep the shared tools in working order and where people expect them", JS-2.1 (know who has an overdue tool before Saturday).
>
> **Already in the file:** the requirements header (BR-1 loans due after 7 days, one 7-day extension; BR-2 a member 7+ days overdue cannot borrow; TR-1 to TR-4) and two epic headings with their story titles: EPIC-1 (US-1, US-3, US-4) and EPIC-2 (US-7, US-2, US-5, US-6).
>
> **The user's draft of US-4:** "As a user, I want the system to text reminders, so that I get reminded."
>
> **Later, from the story-map narration:** "Gap: no story records a loan or a return (between 'find a tool' and 'know when it's due', and at 'bring it back'). Proposed US-8 and US-9 for your approval." **The user:** "Yes, but make it one story: stewards manage loans — lend, return, extend, and delete ones entered by mistake."

## Working it

- **US-4 fails three ways.** "A user" is no persona; "the system" texting is the product's action, not the member's; "so that I get reminded" restates the want and fails the "so what?" test. Rewritten: the member (P-1) gets a reminder, so that the tool is back before someone else needs it, which is JS-1.2 and moves KR-1.1.
- **Lean traces.** There is no FRD and so no UR-n: each story traces to its epic heading, the job story and KR-1.1. US-7 (the import) also cites TR-1.
- **Seed example, not Given/When/Then.** Each story gets one concrete case. Example maps are optional at lean; the acceptance criteria are drafted next from these seeds, and act as the stories' fit criteria.
- **Intake: the gap is approved, the user's one big story is not.** "Manage loans" bundles create, update and delete of one entity: a **CRUD split** (Cohn). Record a loan (create) is US-8; record a return (update) is US-9; extend is already US-6; delete a mistaken loan has a workaround (record the return at once), so with the user's agreement it is not written now and goes in the intake log.
- **The epic heading's size follows.** EPIC-2 now has six stories, so its size moves from S to M; nothing else in the heading changes.
- **Priorities stay provisional** until the closing block. The block is the walking skeleton found by walking the spine (`story-mapping`): every journey step has a Must, every Won't has a workaround.

## Output — `ideate/user-stories.md`

````markdown
---
name: user-story-backlog
product: toolshed
version: 1.1.0
phase: ideate
owner: requirements-analyst
created: 2026-10-26
summary: Toolshed's lean backlog and requirements: 9 stories under two epics traced to KR-1.1, with loan rules, sheet migration and a 5-story walking skeleton as the Release 1 Musts.
profile: lean
status: draft
linked-kr: KR-1.1
linked-epics: none (lean: epic headings below)
linked-requirements: none (lean: the requirements header below)
linked-jtbd: ideate/user-personas.md
traces_to: strategy/okrs.md (KR-1.1); ideate/user-personas.md (P-1, P-2; J-1, JS-1.1, JS-1.2, J-2, JS-2.1)
---

# User Story Backlog — Toolshed

## Requirements Header (lean: the backlog is the functional requirements)

**Translation.** KR-1.1 and the job stories of P-1 and P-2 become the stories below; there is no FRD at lean.

**Scope:** borrowing, due dates, returns and an overdue list for stewards.
**Excluded:** deposits and fines (no payment handling this cycle); booking ahead; member sign-up (stewards add members).

**Business rules**
- BR-1 (constraint): a loan is due 7 days after it starts; stewards may extend once by 7 days. Source: makerspace tool policy, 2025.
- BR-2 (inference): a member with a tool 7+ days overdue cannot borrow another until it is back. Source: the product owner, 2026-10-24.

**Transition (replacing the Google Sheet)**
- TR-1 data migration: import all 1,240 loan rows; the import report's row count equals the sheet's, and every open loan appears as open.
- TR-2 parallel run: one week where stewards record loans in both; zero mismatches on the last three days before the sheet goes read-only.
- TR-3 training: both stewards record a loan and a return unaided in a 5-minute walkthrough.
- TR-4 decommission: the sheet is made read-only and archived after the parallel run.

**Quality concerns for the NFR specification:** the overdue list must be readable on a phone in the workshop (usability); member names visible only to stewards (privacy).

**Assumptions:** ASM-1 members will check a due date online rather than ask a steward. Confirm by asking three members about the last time they returned a tool late (product owner to ask).

**Waiting room:** a text to the steward on every loan (fails the necessity test as a per-loan text; the Friday overdue list meets the need).

Priorities below are provisional; the closing Must / Won't-this-time block finalises them.

## Stories

### EPIC-1: Members know what is in and when their loans are due

Trace: KR-1.1 → members (P-1, primary) → return tools by the due date instead of keeping them
until someone asks → this epic. Assumption [desirability]: members check a due date online
rather than asking a steward (ASM-1). Signal: share of loans back by the due date.
Priority (provisional): high · Size: S (3 stories)

#### US-1: See whether a tool is in, and when it is due back
As a member who borrows (P-1), I want to see whether a tool is in or out and when it is due back, so that I can plan my weekend project around it on Thursday.
- Traces to: EPIC-1 · J-1 → JS-1.1 · KR-1.1
- Rules: BR-1 (due date)
- Priority (provisional): high
- Seed example: the mitre saw is out with Sam, due Saturday 14 Dec; Priya opens it on Thursday and sees "out, due Sat 14 Dec", so she plans the shelf project for Sunday.
- Acceptance criteria: ideate/acceptance-criteria/US-1.md (drafted next; at lean, its fit criteria)

#### US-3: See my own loans and their due dates
As a member who borrows (P-1), I want to see the tools I have out and when each is due, so that I bring them back before someone else needs them.
- Traces to: EPIC-1 · J-1 → JS-1.2 · KR-1.1
- Rules: BR-1
- Priority (provisional): high
- Seed example: Priya has the drill (due Tue) and the clamps (due Fri); her list shows both, the drill first.
- Acceptance criteria: ideate/acceptance-criteria/US-3.md (drafted next; at lean, its fit criteria)

#### US-4: Get a reminder the evening before a loan is due
As a member who borrows (P-1), I want a reminder the evening before a tool is due, so that it is back on the shelf before the next person comes for it.
- Traces to: EPIC-1 · J-1 → JS-1.2 · KR-1.1
- Rules: BR-1
- Priority (provisional): high
- Seed example: the drill is due Tuesday; on Monday at 19:00 Priya gets "Drill due back tomorrow"; the clamps (due Friday) get no reminder yet.
- Acceptance criteria: ideate/acceptance-criteria/US-4.md (drafted next; at lean, its fit criteria)
- Notes: rewritten from "As a user, I want the system to text reminders, so that I get reminded".

### EPIC-2: Overdue tools come back before the weekend

Trace: KR-1.1 → tool stewards (P-2, secondary) → ask for overdue tools on Friday instead of
finding them missing on Saturday → this epic. Assumption [usability]: stewards read a Friday
list on a phone in the workshop. Signal: overdue loans still out on Saturday morning.
Priority (provisional): high · Size: M (6 stories)

#### US-8: Steward records a loan at the workshop
As a tool steward (P-2), I want to record who is taking which tool, so that its due date exists and nobody has to remember who has it.
- Traces to: EPIC-2 · J-2 → JS-2.1 · KR-1.1
- Rules: BR-1 (due 7 days after the loan starts), BR-2 (refused when overdue)
- Priority (provisional): high
- Seed example: on Saturday 7 Dec Dee lends the mitre saw to Sam; it shows "out, due Sat 14 Dec".
- Acceptance criteria: ideate/acceptance-criteria/US-8.md (drafted next; at lean, its fit criteria)
- Notes: Source: story-map gap, approved 2026-10-28. CRUD split of the user's "manage loans" (create).

#### US-9: Steward records a return
As a tool steward (P-2), I want to record that a tool has come back, so that it shows as in and drops off the overdue list.
- Traces to: EPIC-2 · J-2 → JS-2.1 · KR-1.1
- Rules: none
- Priority (provisional): high
- Seed example: Sam returns the mitre saw on Friday 13 Dec; Dee records it, the saw shows "in", and it is not on that evening's Friday list.
- Acceptance criteria: ideate/acceptance-criteria/US-9.md (drafted next; at lean, its fit criteria)
- Notes: Source: story-map gap, approved 2026-10-28. CRUD split of "manage loans" (update).

#### US-7: Stewards see every open loan from the old sheet on day one
As a tool steward (P-2), I want every loan still open in the old sheet to be there when we start, so that the first Friday list is complete.
- Traces to: EPIC-2 · TR-1 · J-2 → JS-2.1 · KR-1.1
- Rules: none
- Priority (provisional): high
- Seed example: the sheet has 1,240 rows, 25 of them open; on day one the 25 show as out with their original due dates, and the import report says 1,240.
- Acceptance criteria: ideate/acceptance-criteria/US-7.md (drafted next; at lean, its fit criteria)

#### US-2: Friday list of overdue tools and who has them
As a tool steward (P-2), I want a list every Friday of overdue tools and who has them, so that I can ask for them back before Saturday.
- Traces to: EPIC-2 · J-2 → JS-2.1 · KR-1.1
- Rules: BR-1
- Priority (provisional): high
- Seed example: three loans are past due and one is due tomorrow; Friday's list shows exactly the three, with member and tool.
- Acceptance criteria: ideate/acceptance-criteria/US-2.md (drafted next; at lean, its fit criteria)

#### US-5: A member 7+ days overdue cannot start another loan
As a tool steward (P-2), I want a loan refused to a member who is 7 or more days overdue, so that one member cannot hold several tools nobody can get back.
- Traces to: EPIC-2 · J-2 → JS-2.1 · KR-1.1
- Rules: BR-2
- Priority (provisional): medium
- Seed example: Sam's sander is 8 days overdue; Dee tries to lend him the drill and is told "Sam has the sander, 8 days overdue".
- Acceptance criteria: ideate/acceptance-criteria/US-5.md (drafted next; at lean, its fit criteria)

#### US-6: A steward extends a loan once by 7 days
As a tool steward (P-2), I want to extend a loan once by a week, so that a member finishing a long project does not show as overdue.
- Traces to: EPIC-2 · J-2 → JS-2.1 · KR-1.1
- Rules: BR-1 (one extension)
- Priority (provisional): medium
- Seed example: the tile cutter is due Saturday; Dee extends it to the next Saturday; a second extension is refused.
- Acceptance criteria: ideate/acceptance-criteria/US-6.md (drafted next; at lean, its fit criteria)

## Intake Log (from the story map)

| Item | Kind | Decision |
|---|---|---|
| "Borrow it": no story records a loan | Gap | US-8 written, approved 2026-10-28 |
| "Bring it back": no story records a return | Gap | US-9 written, approved 2026-10-28 |
| Delete a loan entered by mistake (from the user's "manage loans") | Gap | Not written: workaround is to record the return at once; the user agreed 2026-10-28 |
| Orphans | Orphan | None: every story is placed on the spine |

## Must / Won't-this-time — Release 1 (the walking skeleton)

Spine: a member sees a tool is in → a steward lends it → the member sees when it is due →
a steward takes it back; on Friday, stewards chase what is overdue.

### Must (the walking skeleton)
| Step | Story |
|---|---|
| Find a tool | US-1 See whether a tool is in, and when it is due back |
| Borrow it | US-8 Steward records a loan at the workshop |
| Know when it's due | US-3 See my own loans and their due dates |
| Bring it back | US-9 Steward records a return |
| Chase what's overdue | US-2 Friday list of overdue tools and who has them |

### Won't this time
| Story | Why not now | Look again |
|---|---|---|
| US-6 Steward extends a loan once | Workaround: record a return and a new loan | After Release 1 |
| US-7 Import the sheet's history | Workaround: stewards key the ~25 open loans with US-8 on day one; history stays in the archived sheet | If stewards need history |

Contingency, built after the Musts if the release allows: US-4 reminder the evening before (high),
US-5 block a member 7+ days overdue (medium).

Learning checkpoint: after four weeks, read the share of loans back by their due date (KR-1.1).
If it has not moved, US-4 (the reminder) is the next story to build.
````

## What the weak first draft looked like

```markdown
# User Stories
| ID | Story | Priority | Points |
| US-4 | As a user, I want the system to text reminders, so that I get reminded | Must | 3 |
| US-8 | As a steward, I want to manage loans (lend, return, extend, delete) | Must | 8 |
```

No requirements header, although at lean this file is the functional requirements; "a user" and the system as the actor; a circular benefit; MoSCoW on the card before the block that finalises it; story points in a pipeline with no estimates; one CRUD bundle instead of separate stories; no traces to a job story or KR-1.1; and nothing closing the file to say what Release 1 is.

## Why this is right at lean

| Choice | Reason |
|---|---|
| Header, epic headings, stories and closing block in one file | Lean skips the FRD, epic list and MoSCoW artifact; the backlog carries their decisions |
| Traces to the epic, job story and KR, no UR | There is no FRD at lean, so no user requirements to cite |
| Seed example on each card, criteria in their own files | The card is the promise; the Confirmation is `acceptance-criteria`'s |
| Gap stories written only after approval, logged with dates | Nothing joins the backlog without the user |
| "Manage loans" split by CRUD; delete not written | Each operation is its own story; a workaround keeps delete out of this release |
| Provisional priority on cards, Musts only in the block | The block is the walking skeleton and finalises priority (D045) |
