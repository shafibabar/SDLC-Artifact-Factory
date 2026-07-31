---
name: epic-definition
description: >
  Define an Epic — a large body of work that delivers a coherent outcome and
  decomposes into multiple user stories. Covers the epic format and its fields,
  epic-level acceptance criteria versus story-level detail, the theme/epic/story/task
  hierarchy, the sizing signals that mark work as epic-scale (too big for one sprint),
  and the decomposition/splitting techniques (by workflow step, by business rule, by
  user role, by happy/edge path, verb-before-noun, SPIDR) that break an epic into
  INVEST-sized stories. Fires when structuring a feature area before story-level detail,
  deciding epic vs story vs theme, or splitting an oversized epic. Used by the
  requirements-analyst during Ideate, after impact mapping and before user-story-writing.
version: 2.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, requirements, epic, story-decomposition, acceptance-criteria, agile]
related: [user-story-writing, acceptance-criteria, impact-mapping, story-mapping, moscow-prioritization, glossary-management, methodology-review]
---

# Epic Definition

## What an Epic Is

An epic is a large unit of product work that:

- Delivers a **coherent outcome** to a user or the business — describable as one capability
- Is **too big to finish in a single sprint or iteration** (the primary sizing signal)
- **Decomposes into 3–10 user stories**, each independently completable and INVEST-sized

Epics bridge impact-map deliverables (high-level WHAT) and user stories (granular, immediately
implementable). An epic answers: *what outcome are we delivering, and roughly what is involved?*

### The Cohn divergence — read this before citing a source

In Mike Cohn's *User Stories Applied*, an "epic" is nothing more than **a story too big to plan
into an iteration yet** — no hypothesis, no OKR linkage, no Bounded Context tag. This repo's epic
construct (outcome hypothesis + business-goal trace + Bounded Context) is an **intentional
Lean-Startup-style layering on top of Cohn's simpler idea**, added for product-discovery rigor —
not "what Cohn calls an epic." State this divergence rather than attribute the hypothesis/OKR
apparatus to Cohn. Likewise, Jeff Patton's *User Story Mapping* has no "epic" at all — its
**backbone tasks** are the closest equivalent (the pre-decomposition form of an epic).

---

## Epic vs Story vs Theme vs Task

| Level | Is | Sizing | Owns |
|---|---|---|---|
| **Theme** | A loose grouping label for related epics | Release / roadmap scale | Reporting only — no acceptance criteria |
| **Epic** | One coherent outcome, too big for a sprint | Multiple sprints | Epic-level (high-level) acceptance criteria |
| **Story** | One user-facing outcome, fits in a sprint | Days | Story-level Given/When/Then criteria |
| **Task** | A technical step inside a story | Hours | No independent user value |

Decide by the sizing signals below — never by gut feel. The full hierarchy, the fields of the epic
artifact, and the epic-vs-story acceptance-criteria rule live in
`references/epic-format-and-criteria.md`. The splitting toolkit and a worked repo decomposition live
in `references/decomposition-techniques.md`.

---

## Sizing Signals — is this an epic, a story, or a theme?

| Signal | Verdict | Action |
|---|---|---|
| Fits comfortably in one sprint, one clear "done" | **Story** | Write it directly with `user-story-writing` — no epic needed |
| Too big for one sprint; one coherent outcome; splits into 3–10 stories | **Epic** | Define the epic here, then decompose |
| Cannot be finished in a quarter | **Too large** — split into multiple epics | Split by outcome or user segment |
| Contains exactly one story | **Not an epic** | Promote the story to a standalone requirement |
| "Done" state is indistinguishable from the whole product | **Everything epic** — split | Cut by outcome until each epic can independently succeed or fail |
| A grouping of several epics for a release | **Theme** | Use as a reporting label only |
| Spans multiple Bounded Contexts | **Architectural concern** | Flag for domain-modeler; may indicate a missing Bounded Context |

Fuller sizing guidance and the theme/epic/story/task hierarchy: `references/epic-format-and-criteria.md`.

---

## Epic Format (fields)

Name the epic after the **outcome**, never a feature or component. The epic artifact carries: an
outcome statement (`As a result of this epic, [actor] will be able to [outcome]`), a falsifiable
**hypothesis**, a business-goal link (OKR KR / impact-map goal), the impact-map deliverable(s) it
implements, personas affected, the primary Bounded Context, **epic-level acceptance criteria**, a
**decomposition** (story titles only), MoSCoW priority, and a relative size (S/M/L/XL).

The complete annotated template, a worked example, and the `epic-list` output format are in
`references/epic-format-and-criteria.md`.

| Poor epic name (feature/component) | Better epic name (outcome) |
|---|---|
| "Build the dashboard" | "A Data Steward sees the full classified estate risk in one screen" |
| "Storage connector" | "Connect any supported storage source in under 5 minutes" |
| "Authentication service" | "Users authenticate securely without IT involvement" |

---

## Epic-Level vs Story-Level Acceptance Criteria

This distinction is load-bearing:

- **Epic-level criteria** are 3–5 *high-level conditions* that describe what must be true when the
  whole epic is complete. They are outcome checkpoints, not test cases.
- **Story-level criteria** are detailed **Given/When/Then** written per story *after* decomposition,
  once discovery has actually happened (see `acceptance-criteria`).

Writing full story-level Given/When/Then at epic-definition time is an anti-pattern: it hardens
guesses into commitments before the conversation that should shape them has occurred (Cohn's Three
Cs — the detail belongs in the *Conversation*, deferred by design). Rule and examples:
`references/epic-format-and-criteria.md`.

---

## The Decomposition Principle

**Split an epic by outcome or workflow step — never by technical layer.**

A "frontend story + backend story + database story" split is wrong: those are tasks inside one
story, not stories. Every story must be an independently valuable, user-facing outcome (INVEST —
Independent, Valuable). The named splitting techniques — by workflow step, by business rule, by
user role, by data variation, by happy/edge path, verb-before-noun, and Mike Cohn's **SPIDR**
pattern — plus a full worked decomposition of the repo epic *"A Data Steward reviews a classified
estate"* into stories, are in `references/decomposition-techniques.md`.

| Split by | Use when |
|---|---|
| **Workflow step** | The epic is a multi-step process; each step becomes a story |
| **Business rule** | Behavior varies by rule (a compliance threshold, a retention policy) |
| **User role** | Data Steward and Compliance Officer use the capability differently |
| **Data variation** | Same behavior, different sources (Google Drive vs S3 vs SharePoint) |
| **Happy / edge path** | Ship the simple common case first; edge cases as later stories |

Full technique catalogue (SPIDR, verb-before-noun, CRUD, defer-the-hard-part) and the worked
example: `references/decomposition-techniques.md`.

---

## Epic Readiness Checklist

Before an epic is handed to `user-story-writing`, it must pass:

- [ ] Title is outcome-oriented (not a feature or component name)
- [ ] Outcome statement written ("As a result of this epic, [actor] will be able to…")
- [ ] Falsifiable hypothesis written
- [ ] OKR KR / business goal linked, and impact-map deliverable linked
- [ ] 3–5 epic-level acceptance criteria written (high-level, not Given/When/Then)
- [ ] At least 3 user-story titles listed (decomposition started)
- [ ] Primary Bounded Context identified
- [ ] MoSCoW priority assigned (see `moscow-prioritization`)

---

## Anti-Patterns

- **The component epic** — "API layer", "Auth service". Named after a system part, delivers no
  user-visible outcome, cannot be hypothesis-tested. Components are built *inside* outcome epics.
- **The everything epic** — its "done" state equals the whole product. If it cannot fail without the
  product failing, it carries no information. Split by outcome or segment.
- **The hypothesis-free epic** — work described with no falsifiable belief attached; when it ships,
  no one can say whether it worked.
- **The orphan epic** — no link to an impact-map deliverable or OKR KR. Either the trace exists and
  was not recorded, or the epic is unjustified scope.
- **Premature story detail** — full story-level Given/When/Then written at epic time. Epic criteria
  are 3–5 high-level conditions; detail is written per story after decomposition.
- **Layer-cake decomposition** — splitting into frontend/backend/database "stories". Those are tasks.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Outcome orientation | Title and statement name a user capability | Title names a feature or component |
| Traceability | Linked to impact map and OKR KR | No business-goal linkage |
| Hypothesis | "If we build X we believe Y" | Description only |
| Decomposability | ≥3 user-story titles, split by outcome | Monolithic, or split by layer |
| Criteria altitude | 3–5 high-level epic criteria | Story-level Given/When/Then at epic time |
| Bounded Context | Named, or explicit flag to domain-modeler | Cross-cutting epic, no architectural flag |
