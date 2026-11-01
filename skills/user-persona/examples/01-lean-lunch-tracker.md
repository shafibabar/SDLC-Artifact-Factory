# Example 1 — A lean internal tool: two provisional personas, JTBD folded in (simplest case)

Self-contained. A product built by one person for one 20-person office, at the **lean** profile, where `phase-requirements.json` requires the personas and **skips** `jtbd-analysis`. Nobody has been interviewed. It shows the provenance label, two primaries justified by two named interfaces, the job folded into each persona, validation questions, and what a delivery stakeholder is not.

## Input

> Problem statement: "A lunch-order tracker for a 20-person office. People pick from a daily menu by 10:30 in the office chat, an admin sends one combined order to the restaurant, and costs are split per person."
>
> Vision (approved): "Everyone in the office gets the lunch they chose, on time, without the admin chasing anyone."
>
> Strategy artifacts at lean: vision, strategy kernel, Lean Canvas (Customer Segments: "the office's 20 staff; the admin runs the order"). No stakeholder map (skipped at lean), no ICP (nothing is sold).
>
> The user: "I'm the office's operations lead. Staff complain they miss the cut-off; Ana, our admin, spends every morning chasing people."

## Working it

- **Label first.** No interviews, so both personas are PROTO, and the provenance line names the real inputs: the problem statement, the Lean Canvas and the user's description.
- **Roles by brainstorming** (no buying committee at lean): staff who order, the admin who sends the order, the office manager who owns the budget, IT who approves the chat bot, the restaurant. The restaurant never uses the tool (it receives one order as today), so no served persona is needed: nothing about its experience changes. The office manager and IT are **delivery stakeholders** of the build, not personas.
- **Two interfaces, two primaries.** Staff use the chat picker; the admin uses the combined-order view. Neither design serves the other, so each has its own primary. With one interface there would be one primary.
- **Behavioural variables as one line each.** Lean keeps no table.
- **JTBD folded in.** `jtbd-analysis` is skipped at lean, so each persona carries its job statement, one job story and a forces line.
- **Negative persona in one line**, because the first scope creep request is predictable.

## Output — the personas artifact

```markdown
---
name: user-personas
product: lunch-tracker
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-23
summary: Two proto personas for the lunch tracker — staff who order in chat and the admin who sends one order; neither validated yet.
profile: lean
grounding: proto
authored-by: requirements-analyst (AI)
evidence: second-hand: the user's description of the office
review-by: 2026-11-20
traces_to: strategy/vision-statement.md; strategy/business-model-canvas.md (Customer Segments); problem statement
---

# User Personas — Lunch Tracker

## Persona Set

| Persona | Type | Interface | Grounding | Status |
|---|---|---|---|---|
| Sam, staff member who orders | Primary | Chat menu picker | PROTO | active |
| Ana, office admin | Primary | Combined-order view | PROTO | active |
| Office gourmets wanting any restaurant | Negative | — | PROTO | active |

---

## Persona: Sam, staff member who orders

**Type:** Primary · **Interface:** chat menu picker
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from the problem statement, the Lean Canvas and the user's description · no user research
**Status:** active

**Role and context:** one of 20 staff; orders 3–5 days a week; often in meetings at 10:30 `[user's description]`
**Distinguishing variables:** remembers the cut-off ↔ forgets until reminded (forgets) · picks the same dish ↔ varies daily (same dish) `[assumption]`

### Goals
- **End goals:** get the lunch they chose without thinking about it before 10:30 `[problem statement]`
- **Experience goals:** never be the person who held up the order `[assumption]`

### Forces and context
- **Current approach (habit):** replies to the admin's chat message, or does not and gets "the usual" `[user's description]`
- **Primary frustration:** misses the cut-off when a meeting runs over and gets no lunch or the wrong one `[user's description]`
- **Trigger (push):** a missed lunch `[assumption]`
- **Adoption barrier (anxiety):** one more app or login; anything slower than a chat reply `[assumption]`
- **Time to first value:** the first morning `[assumption]`

### Job
- **Job statement:** get my chosen lunch each workday without tracking a cut-off
- **Job stories:** When a meeting runs past 10:30, I want my usual order placed unless I said otherwise, so I can still eat what I like.
- **Forces:** push — missed lunches · pull — (for `jtbd-analysis` if it is ever written) · habit — replying in chat · anxiety — another tool

### Validation questions
| Attribute | Ask (a specific past event) | Wrong if |
|---|---|---|
| Picks the same dish | "What did you order on each of the last five days?" | Most people vary daily: a "usual" default would be wrong |
| Misses the cut-off in meetings | "When did you last miss the order? What happened?" | Misses are rare, or caused by something else (menu posted late) |

**Recruit first:** three staff, including one who missed an order this month.

---

## Persona: Ana, office admin

**Type:** Primary · **Interface:** combined-order view
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from the problem statement, the Lean Canvas and the user's description · no user research
**Status:** active

**Role and context:** sends the combined order to the restaurant by 10:45; reconciles costs monthly `[user's description]`
**Distinguishing variables:** chases each person ↔ sends what she has at 10:30 (chases) `[user's description]`

### Goals
- **End goals:** send one complete, correct order on time; split costs without arithmetic `[problem statement]`
- **Experience goals:** not be the office's lunch police `[assumption]`

### Forces and context
- **Current approach (habit):** a chat thread copied into an email, then a spreadsheet for the monthly split `[user's description]`
- **Primary frustration:** a morning lost chasing replies `[user's description]`
- **Trigger (push):** a wrong order she had to fix with the restaurant `[assumption]`
- **Adoption barrier (anxiety):** an order she cannot check before it goes `[assumption]`

### Job
- **Job statement:** send the office's lunch order complete and on time without chasing anyone
- **Job stories:** When 10:30 arrives, I want the order to be complete or to show who is missing, so I can send it without a round of messages.
- **Forces:** push — chasing · habit — chat thread and spreadsheet · anxiety — an unchecked order

### Validation questions
| Attribute | Ask (a specific past event) | Wrong if |
|---|---|---|
| Frustration is chasing | "Walk me through yesterday morning from 10:00." | Chasing takes minutes; the real pain is the monthly split |
| Wants to check before sending | "Last time an order went wrong, what did you check?" | She never checks: an auto-send is acceptable |

**Recruit first:** Ana herself, then the admin of a neighbouring office if there is one.

---

## Negative Persona: office gourmets wanting any restaurant

**Type:** Negative
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from the vision · no user research
**Status:** active

**Who and why excluded:** staff who want to order from any restaurant each day; one combined order from one daily menu is the product `[assumption]`

## Lifecycle

- **Review by:** 2026-11-20, or after the first week of use
- **Reopen when:** the admin's first week contradicts an attribute · a second office joins (that would move the product to standard)
```

## What was left out, and why

| Standard element | Left out because |
|---|---|
| Behavioural-variable table | Lean: one line per persona carries the distinguishing ranges |
| Customer persona | No purchase: the office pays for lunch, not for the tool |
| Office manager and IT as personas | They are delivery stakeholders (budget, chat approval), not users or buyers |
| Life goals | Nothing about lunch changes who anyone wants to be |
| Feature matrix, foundation | Lean |
