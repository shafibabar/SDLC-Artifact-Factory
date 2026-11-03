# Example 1 — Lean: one context, drafted from documents, one synonym ban (simplest case)

Self-contained. **Rotawise** is a shift-swap app for Elmbrook House, a 60-bed care home, at the **lean** profile. Carers swap shifts with each other; the shift coordinator approves. Event Storming was a Big Picture wall the domain-modeler built from the Ideate artifacts (agent-run). There was no workshop with carers.

## Input

> **User:** "Write up the language for Rotawise. The vision says 'swap', the job stories say 'trade' and the care manager says 'cover'. Just pick one and move on."

## Working it

- **One Bounded Context** (Rota). Lean, so one short document.
- **Are swap, trade and cover one concept?** Saying it out loud: "a carer asks to swap her Tuesday late with Sam's Thursday early" (two shifts change hands); "a carer asks someone to cover her Tuesday late" (one shift changes hands, nothing given back). They are *not* the same. "Swap" and "trade" look like synonyms of one exchange; "cover" looks like a second concept. Picking one word for all three would lose a rule: a cover leaves the coordinator one carer short on the giver's side, a swap doesn't.
- **Agent-run:** every term cites its artifact; the cover meaning is inferred from one line in the care manager's interview notes, so it's *assumed* and becomes an open question.
- **No ban yet.** That "trade" means the same as "swap" is the agent's reading of two documents, not a confirmed fact, so "trade" is a candidate synonym in Open Questions, not a row in Banned Synonyms. The hook enforces whatever is in that table; a guessed ban would start flagging a word nobody has agreed to drop.
- **Behaviour** points to events on the Big Picture wall instead of being described in the table.

## Output — the reply, and `artifacts/rotawise/design/rota/ubiquitous-language.md`

> I didn't merge all three. "Swap" and "trade" seem to name the same thing, two carers exchanging shifts, so I've used **Shift Swap** and will ban "trade" once you confirm they're the same. "Cover" looks like a different thing: one carer takes another's shift with nothing given back. I've kept it as **Shift Cover** and marked it as assumed, because only the interview notes mention it. Three questions for you before the review: do "swap" and "trade" mean exactly the same, is a Shift Cover approved the same way as a Shift Swap, and can a carer cover a shift on a ward they aren't trained for? And a quick check you can do with a coordinator in five minutes: read them the three sentences at the end of the document. Any that sounds wrong tells us a word is wrong.

```markdown
---
name: ubiquitous-language-rota
product: rotawise
bounded-context: Rota
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-03-09
summary: Rotawise Rota context language, 8 terms; Shift Swap canonical, "trade" a candidate synonym pending confirmation; Shift Cover kept separate as an assumed second concept pending the product owner.
profile: lean
traces-to: [ideate/vision.md, ideate/job-stories.md, ideate/interview-notes-care-manager.md, design/event-storming-big-picture.md]
---

# Ubiquitous Language: Rota

## Context Boundary

Rota decides who works which shift at Elmbrook House and handles changes between carers. Payroll (hours paid) and Training (who is qualified for which ward) are outside it; Rota reads their facts but doesn't use their words for its own concepts.

**How this language was found:** agent-run from the artifacts in `traces-to`; terms marked *assumed* are unconfirmed.

## Terms

| Term | Type | Meaning in this context | Rules that always hold | Behaviour | Source |
|---|---|---|---|---|---|
| Shift | Entity | A fixed block of work on one ward, with a start, an end and one assigned Carer | Exactly one Carer at a time | `ShiftAssigned` | ideate/vision.md |
| Carer | Entity | A member of care staff who can be given Shifts | Holds at most one Shift at any moment | `ShiftAssigned` | ideate/vision.md |
| Coordinator | Concept (role) | The person who approves changes to the Rota | — | `ShiftSwapApproved` | design/event-storming-big-picture.md |
| Rota | Read Model | Who works which Shift over the next four weeks | — | — | ideate/job-stories.md |
| Shift Swap | Aggregate Root | Two Carers exchanging one Shift each | Both Shifts change hands together or not at all; needs Coordinator approval | `ShiftSwapRequested`, `ShiftSwapApproved`, `ShiftSwapDeclined` | ideate/job-stories.md |
| Shift Cover | Aggregate Root | One Carer taking another's Shift with nothing given back | *assumed:* needs Coordinator approval | `ShiftCoverRequested` | *assumed* (interview notes, one line) |
| Open Shift | Concept | A Shift with no Carer, visible to all Carers | — | `ShiftReleased` | design/event-storming-big-picture.md |
| Short Notice | Policy | A change requested less than 12 hours before the Shift starts goes to the Coordinator by phone as well | — | — | ideate/job-stories.md |

## Key Scenarios

    Scenario: A Shift Swap moves both Shifts or neither
      Given Ana holds Tuesday late and Sam holds Thursday early
      When the Coordinator approves their Shift Swap
      Then Ana holds Thursday early and Sam holds Tuesday late

    Scenario: A Shift Cover leaves nothing to give back (assumed, see question 2)
      Given Ben holds Friday night and Priya holds nothing on Friday
      When the Coordinator approves Priya's Shift Cover of Friday night
      Then Priya holds Friday night and Ben holds no Shift on Friday

    Scenario: A Short Notice change also goes to the Coordinator by phone
      Given Ana's Shift starts in 8 hours
      When Ana requests a Shift Swap
      Then the request is marked Short Notice

## Banned Synonyms

None confirmed yet. "trade" waits on question 1.

## Homonyms at the Boundary

None yet. Payroll's "Shift" (hours paid, including breaks) may differ; check when Payroll is modelled.

## Open Questions for the Product Owner

| # | Question | Why it matters | Assumed meanwhile |
|---|---|---|---|
| 1 | Do "swap" (vision) and "trade" (job stories) mean exactly the same thing? | If yes, "trade" is banned; if not, there's a concept missing | Same thing: Shift Swap |
| 2 | Is a Shift Cover approved the same way as a Shift Swap? | If not, Shift Cover has its own rules and maybe its own approver | Same approval |
| 3 | Can a Carer swap or cover onto a ward they aren't trained for? | A rule on both Aggregates, and a dependency on Training | Not allowed |

**Sentences to read to a coordinator** (any that sounds wrong is a finding):
1. "Ana asked for a Shift Swap with Sam, and the Coordinator approved it, so the Rota changed for both of them."
2. "Ben asked for Shift Cover on Friday's night shift; Priya took it, and Ben gave nothing back."
3. "Monday's early shift is an Open Shift until a Carer takes it."

## Retired Terms

| Term | Retired on | Reason | Successor (if merged) |
|---|---|---|---|
```

## Why this is right

- Not "pick one and move on": saying the sentences showed two concepts, and merging them would have hidden a rule.
- Lean is short, but nothing was skipped: types, rules, behaviour links, a scenario per key term, and open questions, including the candidate ban, which waits for the product owner's answer.
- The check with a person is concrete and cheap: three sentences to read aloud, not a workshop.
- Nothing is presented as carers' language; the assumed term and its questions go to the product owner.
