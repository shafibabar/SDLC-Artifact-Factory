---
name: user-story-writing
description: >
  Teaches the requirements-analyst to write user stories — the role-goal-benefit
  format (As a / I want / so that), the INVEST quality criteria (Independent,
  Negotiable, Valuable, Estimable, Small, Testable), story-splitting patterns for
  stories that are too big, and the coupling to acceptance criteria. Used during
  Ideate to capture requirements as small, testable, valuable increments.
version: 2.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, requirements, user-story, invest, story-splitting, connextra, acceptance-criteria]
related: [acceptance-criteria, epic-definition, user-persona, moscow-prioritization, example-mapping, glossary-management]
---

# User Story Writing

## Purpose

A user story is the smallest unit of product work that delivers value to a specific
user. It is not a task, a technical requirement, or a feature specification — it is a
description of what a user needs to accomplish and why, written in a way that enables a
conversation about how to build it. This skill governs how the `requirements-analyst`
writes stories during Ideate, decomposing epics into small, testable, valuable
increments.

---

## The Role-Goal-Benefit Format

The canonical Connextra-style template (named for the team that popularized it):

```
As a [persona or role],
I want to [action or capability],
so that [outcome or benefit].
```

**The three slots each have a rule:**
- **As a** names a *persona or role* — never "a user" (too generic), never a system
  ("As the API"). Prefer a named persona from `user-persona`; if none exists yet, run
  the lightweight role-brainstorming fallback (see `references/invest-criteria.md`).
- **I want to** names an *action the user takes* — not something the system does
  ("I want the system to...").
- **so that** names the *outcome* — what concretely changes for the user.

### Why the "so that" matters most

The benefit clause is the slot most often written badly and the one that carries the
most value. A "so that" is only doing its job when it names a concrete change in the
user's world — time saved, risk avoided, a decision enabled, a blocker removed — not a
restatement of the want ("so that I can export the report") and not a product benefit
("so that the product has more data"). Apply the **"so what?" test**: keep asking "so
what?" of the benefit until the answer names a real-world change, not the feature
itself. If a story's benefit collapses under that test, its value is unproven —
escalate rather than build.

---

## Card, Conversation, Confirmation (the Three Cs)

Ron Jeffries' Three Cs, popularized by Mike Cohn (*User Stories Applied*, 2004), are
*why* the story is deliberately short:

| C | What it is | In this repo |
|---|---|---|
| **Card** | The short written story — a token, not a spec | The `As a / I want / so that` text |
| **Conversation** | Where the real detail is negotiated, over time | Shafi's review + the analyst reasoning through perspectives |
| **Confirmation** | The conditions that prove the conversation was delivered | The `acceptance-criteria` artifact |

A story is **a promise of a conversation** — the card intentionally defers detail.
Writing a fully-detailed card is a failure mode, not thoroughness: it means the
conversation never happened, or got frozen into text too early. The acceptance criteria
are the **Confirmation** leg — they close the loop by defining when the promise has been
kept. This is the coupling to `acceptance-criteria`: the story is the promise, the AC is
the confirmation.

---

## INVEST — the Quality Bar

Every story must pass all six INVEST criteria (Bill Wake; the core of Cohn's book)
before it enters the backlog:

- **I — Independent**: deliverable without waiting on another in-flight story.
- **N — Negotiable**: describes a need, not a chosen solution — the "how" stays open.
- **V — Valuable**: delivers value to a real user, not a developer convenience.
- **E — Estimable**: the team can form a rough view of the effort.
- **S — Small**: completable within a single sprint; if not, split it.
- **T — Testable**: verifiable via unambiguous acceptance criteria.

Each letter, how to test a story against it, and the fix when it fails — plus the
anti-pattern catalogue (technical-task stories, blank "so that", persona-free "As a
user", system-as-actor) — are in `references/invest-criteria.md`. Consult it whenever a
story is borderline on any letter.

---

## When a Story Is Too Big — Split It

A story that fails **Small** (or **Estimable**) must be split into INVEST-compliant
children, not planned as-is. Splitting is a first-class, continuous technique, not a
last resort. The named patterns:

| Pattern | Split by |
|---|---|
| **SPIDR** (Cohn) | Spikes, Paths, Interfaces, Data, Rules |
| By workflow step | Each step of a multi-step process |
| By CRUD operation | Separate Create / Read / Update / Delete |
| By business-rule variation | One story per rule (discount tier, compliance threshold) |
| Happy path first | Success scenario first; edge/error cases as follow-ons |
| Simple then complex | Ship the common case; defer the rare/hard case |
| Split by verb before noun | Decompose a compound action before splitting by data |

Every pattern in depth — with a full worked split of an oversized "connect any storage
source" repo story into INVEST-compliant stories — is in
`references/story-splitting-patterns.md`.

---

## Story Writing Process

1. **Source from an epic.** Each story implements part of a parent epic
   (`epic-definition`); start from the epic's decomposition list.
2. **Name a specific persona** from `user-persona` — never "user".
3. **Write the want** in the persona's own vocabulary, not engineering jargon.
4. **Write the "so that"** and apply the "so what?" test until it names a real change.
5. **Check INVEST** — all six. If any fail, refactor (or split) before continuing.
6. **Tag the parent epic and job story** so every story is traceable upward.
7. **Note what the acceptance criteria will cover** (detailed AC belongs to
   `acceptance-criteria`).

---

## Worked Example

From EPIC-002 ("Connect any supported storage source in under 5 minutes"):

**US-001: Connect Google Drive via OAuth**

> As Maya Chen, the Compliance Officer,
> I want to connect our company Google Drive by authorising it in a guided flow,
> so that the estate scan can begin without me raising an IT ticket.

The "so that" names what changes for Maya (no IT ticket, scan starts now) — not a
restatement of the want, not a product benefit. INVEST holds because the story is one
provider, happy path only; expired-token re-authentication is deliberately split out as
US-003 (a *Paths* split — see the references). **Source:** Job Story JS-001 · **Parent
Epic:** EPIC-002 · **Priority:** Must.

---

## Story Hierarchy

Every story must trace upward. If the trace breaks at any level, the story's inclusion
is unjustified:

```
Business Goal (OKR KR) → Impact → Epic (EPIC-001) → US-001 … US-00n
```

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Named persona | Specific persona/role | "As a user" |
| Action-oriented want | What the user does | "I want the system to..." |
| Substantive benefit | Survives the "so what?" test | "so that I can use the feature" |
| INVEST compliance | All six pass | Any letter fails |
| Epic linkage | Linked to a parent epic | Orphan story |
| AC promised | Names what Confirmation will cover | No path to acceptance criteria |

---

## Output Format

```markdown
---
name: user-story-backlog
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
---

# User Story Backlog

## Backlog Summary
| ID | Title | Epic | Persona | Priority | Size |
|---|---|---|---|---|---|

## Stories by Epic

### EPIC-001: [Epic Title]

#### US-001: [Short title]
**Story:**
As a [Persona Name], I want to [action], so that [outcome].

**Source:** Job Story JS-[ID] / Impact Map EPIC-[ID]
**Parent Epic:** EPIC-001
**Priority:** Must / Should / Could / Won't
**INVEST check:** [pass / note any exceptions]
**Acceptance criteria:** [Defined separately — see AC-001]
```
