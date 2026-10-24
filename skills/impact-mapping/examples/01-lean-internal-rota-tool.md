# Example 1 — Lean: no map, one trace line per epic (simplest case)

Self-contained. **Swapline** is an internal on-call swap tool a practice manager is building alone for a nine-vet veterinary practice, at the **lean** profile. `phase-requirements.json` **skips** the impact map at lean. This example shows what the skill does instead when the user asks for a map anyway, and why the agent does not draw one backwards from requirements already written.

## Input

> **User:** "We're lean. I've already written the functional requirements for Swapline (FR-1 to FR-6). Can you draw the impact map from them so the epics have something to trace to?"
>
> **KR (strategy/okrs.md, KR-1.1):** "Share of on-call swaps agreed without the practice manager stepping in, 20% → 80% by 2027-01-31."
>
> **Ranked opportunity list (lean, `opportunity-solution-tree`):** target OPP-2 "I can't tell who is free to swap without messaging everyone" (three of four vets).

## Working it

- **Lean skips the map.** The profile says skipped, so no `ideate/impact-map.md` is written. A lean artifact set is smaller; the methodology still applies, so the impact thinking moves into one trace line per epic.
- **Not from the requirements.** Drawing goal → actor → impact branches from FR-1…FR-6 would be backwards mapping: every deliverable would already be decided, and the map would launder them. The trace runs from the KR down, and each requirement is then checked against it.
- **One actor matters, one blocks.** The vets produce the effect (primary). The practice manager is the current bottleneck: as long as she approves every swap by hand, nothing changes (blocker). Two actors, one impact each.
- **Cheapest option first.** Before any epic, a non-software option: a pinned "who's free" sheet in the vets' group chat. The user decides whether the tool is still needed; here it is, because the sheet goes stale within a week (the user's own observation).

## Output — the reply, and the trace lines for `ideate/epics.md`

> At lean the impact map is skipped, so I won't write one, and I won't draw one from FR-1…FR-6: a map built from requirements just justifies them. Instead each epic carries one trace line from KR-1.1, and I've checked your requirements against those lines.

```text
EPIC-1 Free-to-swap board
  KR-1.1 → vets (primary) → offer and accept swaps directly instead of messaging everyone
  (OPP-2: "I can't tell who is free to swap") → this epic.
  Assumption [desirability]: vets keep their free slots current if it takes under a minute.
  Signal: share of swaps agreed with no manager message in the thread.

EPIC-2 Rule check on accept
  KR-1.1 → practice manager (blocker) → stops approving each swap by hand
  instead of re-checking rest-hour rules herself → this epic.
  Assumption [viability]: she trusts an automatic rest-hour check enough to stop reviewing.
  Signal: swaps the manager reopens per month.
```

> **Requirements check:** FR-1–FR-4 trace to EPIC-1 or EPIC-2. FR-5 (monthly swap report) and FR-6 (calendar colour themes) trace to no behaviour change that moves KR-1.1, so I've marked them as options to drop or defer rather than writing epics for them. Option tried first and rejected by you: the pinned group-chat sheet (stale within a week).

## Why this is right at lean

| Choice | Reason |
|---|---|
| No map file | The profile skips it; producing it anyway is the over-production the lean profile exists to stop |
| Trace lines instead | The epics still trace KR → actor → behaviour change, with an assumption and a signal |
| Refused to map from the FRs | Backwards mapping: the trace runs from the goal, and requirements are checked against it |
| A blocker named | The manager's hand approval is the real obstruction; removing it moves the KR |
| Two requirements flagged | They trace to no impact, so they are options, not epics |
