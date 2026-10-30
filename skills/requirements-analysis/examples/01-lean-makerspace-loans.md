# Example 1 — Lean: no FRD; the backlog header carries the requirements thinking (simplest case)

Self-contained. **Toolshed** is a tool-loan tracker one volunteer is building for a 60-member community makerspace, replacing a shared spreadsheet. The product runs at the **lean** profile. `phase-requirements.json` **skips** the functional requirements document at lean and says "the backlog is also the functional requirements". The JTBD analysis and impact map are skipped too: the persona carries the job statement and job stories, and stories trace to the Key Result. This example shows what the agent writes when the user asks for an FRD anyway.

## Input

> **User:** "We're on lean. Can you write the functional requirements document for Toolshed before we do stories? Our steward, Dee, also wants a button that texts her every time something is borrowed."
>
> **KR (strategy/okrs.md, KR-1.1):** "Share of borrowed tools back by their due date, 55% → 85% by 2027-03-31."
>
> **Persona (ideate/user-personas.md, P-1 member who borrows, PROTO):** job statement J-1 "get the tool I need for a weekend project without asking around"; job stories JS-1.1 "When I start planning a project on Thursday, I want to see whether the tool is in, so I can plan the weekend around it" and JS-1.2 "When I've finished with a tool, I want to know when it's due back, so I can return it before someone else needs it". **P-2 tool steward:** J-2 "keep the shared tools in working order and where people expect them"; JS-2.1 "When a tool is overdue, I want to know who has it, so I can ask for it back before Saturday".
>
> **Today:** a Google Sheet with 1,240 loan rows since 2023, columns member, tool, out, due, back, notes; two stewards update it.

## Working it

- **No FRD at lean.** The profile skips it. The requirements thinking still happens, in a header on `ideate/user-stories.md`, and each story carries its traces; its acceptance criteria are its fit criteria.
- **The steward's want is a solution idea.** Why a text on every loan? "So I know who has the big tools." Why? "Because the mitre saw goes missing over weekends." The need is JS-2.1: know who has an overdue tool before the weekend. A text per loan (40 a week) is one solution; a Friday list of overdue tools is cheaper and closer to the need. Necessity test: without some overdue view, the KR does not move. Necessary, but the text-per-loan form goes to the waiting room.
- **It replaces a spreadsheet**, so transition lines are needed: import, a short parallel run, a five-minute show-and-tell for the two stewards, and retiring the sheet.
- **No interviews invented.** Members other than the user have not been asked whether they would check due dates online; that is an assumption with a question for the user to put to three members.
- **Priority stays provisional.** At lean the backlog's closing Must / Won't-this-time block finalises it (`user-story-writing`), not this header.

## Output — the reply, and the header for `ideate/user-stories.md`

> At lean there is no functional requirements document, so I won't write `ideate/requirements.md`. Your user story backlog *is* the functional requirements: I've put the requirements header at the top of it below, and each story traces to KR-1.1 and a job story, with its acceptance criteria acting as its fit criteria. Dee's "text me on every loan" is recorded as the need behind it (knowing who has an overdue tool before the weekend), with the per-loan text kept in the waiting room.

```markdown
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

### US-1 See whether a tool is in
As a member (P-1), I want to see whether a tool is in or out and when it is due, so I can plan my weekend project.
- Traces to: KR-1.1 · J-1 → JS-1.1
- Priority (provisional): high
- Acceptance criteria (fit criteria): Given the drill is on loan due Saturday, when a member opens the drill, then it shows "out, due Sat 14 Dec"; for every tool in the catalogue the status matches the loan records.

### US-2 Friday overdue list for stewards
As a tool steward (P-2), I want a list of overdue tools and who has them every Friday, so I can ask for them back before Saturday.
- Traces to: KR-1.1 · J-2 → JS-2.1 · BR-1, BR-2
- Priority (provisional): high
- Acceptance criteria (fit criteria): Given three loans past their due date and one due tomorrow, when the Friday list is produced, then it lists exactly the three overdue loans with member and tool, and no others.
```

## Why this is right at lean

| Choice | Reason |
|---|---|
| No `ideate/requirements.md` | The profile skips the FRD; writing one is the over-production lean exists to stop |
| A header on the backlog | Scope, rules, transition and assumptions still need a home; the backlog is the functional requirements |
| Traces to the KR and a job story | No impact map and no JTBD file at lean: the persona's job stories are the job source |
| Acceptance criteria as fit criteria | Each story is still verifiable pass/fail |
| The want turned into a need | "Text me on every loan" became "know who has an overdue tool before the weekend" |
| Transition lines | A spreadsheet replacement still needs import, parallel run, training and retirement |
| Assumption, not invented interviews | Members were not asked; the question is handed to the user |
