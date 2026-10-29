# Example 1 — Lean: "write moscow.md, EPIC-2 is all Must" becomes the closing Must / Won't-this-time block (simplest case)

Self-contained. **Toolshed** is a tool-loan tracker one volunteer is building for a 60-member community makerspace, replacing a shared Google Sheet. The product runs at the **lean** profile: `phase-requirements.json` **skips** the MoSCoW artifact, and the story map is optional. So there is no `ideate/moscow.md`: the backlog `ideate/user-stories.md` closes with a short **Must / Won't-this-time block**, and that block finalises the provisional priorities.

## Input

> **User:** "Stories are done. Please write `ideate/moscow.md` with Must / Should / Could / Won't for Release 1. EPIC-2 is high, so all six of its stories are Musts, and the reminder too. Can you also check the Musts are under 60% of capacity? I have about four evenings a week."
>
> **KR-1.1:** "Share of borrowed tools back by their due date, 55% → 85% by 2027-03-31."
>
> **Backlog (`ideate/user-stories.md`, provisional priorities, after the spine was walked and the user approved gap stories US-8 and US-9):**
> - EPIC-1 Members know what is in and when their loans are due (high): US-1 see whether a tool is in, and when it is due back (high); US-3 see my own loans and their due dates (high); US-4 get a reminder the evening before a loan is due (high)
> - EPIC-2 Overdue tools come back before the weekend (high): US-8 steward records a loan at the workshop (high); US-9 steward records a return (high); US-7 stewards see every open loan from the old sheet on day one (TR-1, high); US-2 Friday list of overdue tools and who has them (high); US-5 a member 7+ days overdue cannot start another loan (BR-2, medium); US-6 a steward extends a loan once by 7 days (BR-1, medium)
> - BR-1 loans are due after 7 days, one 7-day extension. The sheet holds 1,240 rows, about 25 of them open loans.

## Working it

- **No `moscow.md` at lean.** The decision still gets made; it lands in the backlog's closing block, the last section of `ideate/user-stories.md`.
- **No 60% check, and no estimates.** "Four evenings a week" is the user's constraint, and it belongs in the conversation, but this plugin does not compute a Must percentage (D045): there are no person-week estimates, and inventing some would be false precision. The purpose of the rule, a release that survives surprises, is kept by checking the Musts walk end to end and that something can be dropped.
- **"EPIC-2 is high, so all Must" fails DSDM's decomposition rule.** Each story is judged on its own with "what happens if it is not delivered?" and the **workaround clause** (any workaround, even manual, means not a Must):
  - US-8 record a loan, US-9 record a return: no workaround in the product, and without them there are no due dates to show. Musts.
  - US-2 Friday overdue list: once the sheet is archived, Toolshed holds the only record of who has what, and no other story shows a steward all open loans. No workaround, and "chase what's overdue" is the step that moves KR-1.1. Must.
  - US-7 import the sheet's history: workaround, stewards key the ~25 open loans with US-8 on day one; history stays in the archived sheet. Won't this time.
  - US-5 block an overdue member: workaround, a steward refuses at the workshop when the Friday list names someone. Not a Must; contingency.
  - US-6 extend a loan: workaround, record a return and a new loan. Won't this time.
- **The reminder (US-4) is not a Must either.** The member can look up their loans (US-3). It stays contingency, built first if the release has room, and the learning checkpoint names it as the next story if KR-1.1 does not move.
- **Must = the walking skeleton, both ways.** One Must per journey step, no Must off the spine, no legal or safety story needing to be added.

## Output — the reply, and the block closing `ideate/user-stories.md`

> At lean there's no separate MoSCoW file, so I haven't written `ideate/moscow.md`. Release 1's priorities go in a short block at the end of your backlog instead. I also didn't calculate a Must percentage: we have no effort estimates, and making some up wouldn't tell us anything. What protects your four evenings is that the Musts are the five stories a loan can't happen without, with two stories ready to drop or build if time allows.
>
> EPIC-2 being high doesn't make each of its stories a Must. Three of them have a workaround: stewards can key the 25 open loans by hand, refuse a loan at the bench, and record a return plus a new loan instead of an extension. So those aren't Musts.

```markdown
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
```

## What the weak first draft looked like

```markdown
# ideate/moscow.md — Toolshed
Capacity: 4 evenings × 8 weeks = 32 evenings; Must ceiling 60% = 19 evenings
| Must | US-1, US-2, US-3, US-4, US-5, US-6, US-7, US-8, US-9 (est. 24 evenings) |
| Should | — |
```

A file the profile skips; invented estimates for a rule this plugin dropped; every story under a high epic made a Must; no workaround tested; nothing left to drop; no Won't with a reason and a look-again point.

## Why this is right at lean

| Choice | Reason |
|---|---|
| No `moscow.md`; the block closes the backlog | The MoSCoW artifact is skipped at lean; the backlog carries the decision |
| Same block as the story map produced | The skeleton walked in `story-mapping` *is* the Must list; one source, no drift |
| No Must percentage, no estimates | D045: structural checks instead of a person-week ratio |
| EPIC-2's stories judged one by one | DSDM: a Must epic's parts do not inherit Must |
| No Should / Could labels | Lean keeps it short: contingency with provisional priorities |
| Won'ts carry the workaround and a look-again | "This time" means not now, not never |
