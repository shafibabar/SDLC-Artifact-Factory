# Example 1 — A lean internal tool: no JTBD artifact, a guide, one snapshot, and JTBD folded into the persona (simplest case)

Self-contained. A lunch-order tracker built by one person for one 20-person office, at the **lean** profile, where `phase-requirements.json` **skips** the `jtbd-analysis` artifact and the personas carry the job instead. It shows what this skill still contributes at lean: an interview guide the user can use in a ten-minute chat, a snapshot written from the user's notes, and the job block that goes into the persona.

## Input

> Personas (approved, PROTO): **Sam**, staff member who orders (primary of the chat picker), job statement "get my chosen lunch each workday without tracking a cut-off"; **Ana**, office admin (primary of the combined-order view), job statement "send the office's lunch order complete and on time without chasing anyone".
>
> The user (the office's operations lead): "Before you write anything else, I can grab Ana for ten minutes tomorrow. What should I ask her?"

## Working it

- **No artifact.** Lean skips `jtbd-analysis`; writing one would be an extra artifact the profile does not ask for. The job lives in each persona: the job statement, one or two job stories and a forces line.
- **The user interviews; the agent writes the guide.** Ana switched from "collect by chat" to "chat plus a spreadsheet" last spring, a recent switch, so a short switch-interview guide fits.
- **One prompt, past-specific.** Not "would a tracker help you?" but "tell me about last Tuesday's order".
- **Snapshot from the notes, dated.** The user sends notes the same afternoon. The agent writes one snapshot file and touches no approved artifact. Then it proposes the persona's job block, citing the snapshot, for the user to approve as a persona revision.

## Output 1 — the interview guide (abridged)

```markdown
---
name: interview-guide
product: lunch-tracker
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-23
summary: Ten-minute switch interview with the office admin about the last lunch order and why she added a spreadsheet last spring.
interview-type: switch
interviewer: the user (operations lead)
traces_to: ideate/user-personas.md (Ana)
---

# Interview Guide — the daily lunch order

**Interviewer:** the user. The agent wrote this guide and will write the snapshot from your notes; it is not in the conversation.

## Opening
"Tell me about last Tuesday's lunch order, from the moment the menu came in."

## Timeline probes
| Stage | Ask |
|---|---|
| First thought | "When did you first decide the chat alone wasn't enough? What had just happened?" |
| Event → active looking | "What made you set up the spreadsheet then?" |
| Deciding | "What nearly stopped you? What did you give up?" |
| Ongoing use | "What do you still do by hand every morning?" |

**If she generalises** ("I always have to chase"): "And last Tuesday, who did you chase, and how?"

## The question I'm afraid to ask
"When did you last think about handing the lunch order to someone else? What happened?"

## Ask for advancement
"Could I watch tomorrow's order go out?"
```

## Output 2 — the snapshot, from the user's notes

```markdown
---
name: interview-snapshot
product: lunch-tracker
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-24
summary: Ana chased four people by name before 10:30 last Tuesday; she added a spreadsheet in spring after a wrong order, and fears sending an order she cannot check.
participant: ADMIN-1 (Ana)
interview-date: 2026-10-24
interviewer: the user (operations lead)
synthesised-by: requirements-analyst (AI), from the interviewer's notes; the agent did not witness the conversation
guide: ideate/interviews/guides/2026-10-23-lunch-order.md
---

# Interview Snapshot — ADMIN-1, 2026-10-24

**Quick facts:** office admin · runs the order daily · chat thread + email + a spreadsheet for the monthly split
**Memorable quote:** "I spend more time chasing than ordering."

## The story
Tuesday: menu posted 09:15 → at 10:20 four people had not replied → she messaged each by name → two answered after 10:30 → she phoned the restaurant to add them; one dish was wrong on arrival.
Spring: an order went out missing three people; she added the spreadsheet so she could tick names off.

## Forces heard
| Force | What they described |
|---|---|
| Push | Chasing four people by name every day; the spring order missing three people |
| Pull | "If people just picked by themselves, I'd send it at 10:30 and be done" |
| Anxiety | Sending an order she cannot check against the names |
| Habit | The spreadsheet she ticks off: "at least I know where I am" |

## What was fired
Chat-only collection (fired in spring); the spreadsheet was hired.

## Opportunities heard
| Opportunity (customer's voice) | Experience step |
|---|---|
| "I don't know who hasn't chosen until I count" | Collect choices |
| "Late orders mean a phone call and a wrong dish" | Send the order |

## Advancement
Agreed to be watched sending tomorrow's order.

## Discarded
| Said | Type | Problem recovered |
|---|---|---|
| "You should make it a bot that nags people" | idea | She cannot see who is missing without counting |
```

## Output 3 — the job block proposed for Ana's persona (a revision for the user to approve)

```markdown
### Job
- **Job statement:** send the office's lunch order complete and on time without chasing anyone
- **Job story:** When the cut-off is ten minutes away and I don't know who hasn't chosen, I want to know who is missing without counting, so I can send the order at 10:30 and stop chasing. [2026-10-24-admin-1]
- **Forces:** push: daily chasing by name, the spring order missing three people · pull: send at 10:30 and be done · anxiety: an order she cannot check · habit: the tick-off spreadsheet [2026-10-24-admin-1]
```

## Why this is right at lean

| Choice | Reason |
|---|---|
| No `ideate/jtbd-analysis.md` | Skipped at lean; the persona carries the job |
| A guide and a snapshot anyway | The interview discipline is not scaled away; only the artifact count is |
| The motivation says "know who is missing", not "get a nagging bot" | The idea was recorded as discarded and the problem behind it kept |
| The snapshot is a new dated file | The approved personas change only when the user approves the job-block revision |
