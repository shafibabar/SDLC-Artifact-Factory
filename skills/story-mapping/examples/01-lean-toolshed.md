# Example 1 — Lean: no map file; narrating the spine finds two missing steps, and the skeleton becomes the Must / Won't-this-time block (simplest case)

Self-contained. **Toolshed** is a tool-loan tracker one volunteer is building for a 60-member community makerspace, replacing a shared Google Sheet. The product runs at the **lean** profile: `phase-requirements.json` makes the story map **optional** and **skips** the MoSCoW artifact, so the backlog closes with a short Must / Won't-this-time block. There is no impact map and no epic list: stories sit under two epic headings in `ideate/user-stories.md` and trace to the KR.

## Input

> **User:** "Do I actually need a story map for Toolshed? I just want to know what goes in the first release. I think it's EPIC-1 done properly (US-1, US-3, US-4) and the steward stuff next month."
>
> **KR-1.1:** "Share of borrowed tools back by their due date, 55% → 85% by 2027-03-31." **Assumption ASM-1:** members will check a due date online rather than ask a steward.
>
> **Backlog (`ideate/user-stories.md`, provisional priorities):**
> - EPIC-1 Members know what is in and when their loans are due: US-1 see whether a tool is in, and when it is due back (high); US-3 see my own loans and their due dates (high); US-4 get a reminder the evening before a loan is due (high)
> - EPIC-2 Overdue tools come back before the weekend: US-7 stewards see every open loan from the old sheet on day one (TR-1, high); US-2 Friday list of overdue tools and who has them (high); US-5 a member 7+ days overdue cannot start another loan (BR-2, medium); US-6 a steward extends a loan once by 7 days (BR-1, medium)
> - BR-1 loans are due after 7 days. The sheet holds 1,240 rows, about 25 of them open loans.

## Working it

- **No map file.** At lean the story map is optional and the user did not ask for one. The thinking still happens: lay the backbone, narrate it, cut the skeleton. The result lands in the backlog's closing block.
- **Lay the backbone from the member's journey:** find a tool → borrow it → know when it's due → bring it back; and the steward's step: chase what's overdue.
- **Narrate it, and it breaks twice.** "The member sees the drill is in, then *borrows it*…" There is no story for recording a loan, or for recording a return. The backlog was written from the two epics, and neither epic covered the loan itself. Two **gaps**: propose US-8 and US-9 to the user; do not add them silently.
- **The user's release is a vertical slice.** EPIC-1 alone lets a member see that the drill is out, but nobody can record lending it, so the due date never exists. Stewards cannot chase anything. One epic finished, journey unwalkable.
- **Apply the workaround clause (DSDM) to every candidate.** US-4 reminder: the member can look up their loans (US-3), so it is not a Must; it is contingency, built if the release has room. US-5 block: a steward can refuse at the workshop when the Friday list names someone, so not a Must. US-6 extend: a steward can record a return and a new loan, so Won't this time. US-7 history import: stewards can key the ~25 open loans with US-8 on day one, and the history stays in the archived sheet, so Won't this time.
- **Must = skeleton, both ways.** The skeleton stories are the Musts; no Must sits off it.

## Output — the reply, and the block closing `ideate/user-stories.md`

> You don't need a separate story map at lean, but I walked the journey anyway, and it showed two things. First, the backlog has no story for lending a tool or taking it back, so I've proposed US-8 and US-9 below for you to approve. Second, EPIC-1 on its own can't be the first release: without recording loans there are no due dates to show, and stewards can't chase anything. The first release is the thinnest path through the whole journey, and those stories are the Musts.

```markdown
## Must / Won't-this-time — Release 1 (the walking skeleton)

Spine: a member sees a tool is in → a steward lends it → the member sees when it is due →
a steward takes it back; on Friday, stewards chase what is overdue.

### Must (the walking skeleton)
| Step | Story |
|---|---|
| Find a tool | US-1 See whether a tool is in, and when it is due back |
| Borrow it | US-8 Steward records a loan at the workshop (proposed: gap) |
| Know when it's due | US-3 See my own loans and their due dates |
| Bring it back | US-9 Steward records a return (proposed: gap) |
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
# Story Map — Toolshed
| Release | Stories |
| MVP | US-1, US-3, US-4 |
| v2 | US-2, US-5, US-6, US-7 |
```

A map file the profile did not need, built from one epic (the vertical slice), no backbone at all, nothing noticing that loans and returns are never recorded, and an "MVP" whose Musts cannot be used.

## Why this is right at lean

| Choice | Reason |
|---|---|
| No `story-map.md`, no `moscow.md` | Optional and skipped at lean; the backlog's closing block carries the decision |
| The spine narrated anyway | It is what exposed US-8 and US-9 |
| Gap stories proposed, not added | The user approves backlog changes |
| Musts = the skeleton | DSDM's Minimum Usable SubseT: five stories that together walk |
| Won'ts with a workaround and a "look again" | The workaround clause, and "this time" means not now, not never |
