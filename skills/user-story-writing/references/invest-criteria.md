# INVEST Criteria — In Depth

INVEST (Independent, Negotiable, Valuable, Estimable, Small, Testable) was coined by
Bill Wake and adopted as the central quality rubric of Mike Cohn's *User Stories
Applied* (2004). It is the checklist a `requirements-analyst` runs against every story
before it enters the backlog. This reference gives each letter its own treatment: what
it means, how to test a story against it, and the concrete fix when a story fails it. It
closes with the anti-pattern catalogue and the role-brainstorming fallback for when no
persona exists yet.

Format compliance (the `As a / I want / so that` syntax) is necessary but not
sufficient. Two stories can share identical structure and differ enormously in quality.
INVEST is what separates a well-crafted story from a box-ticking one.

---

## I — Independent

**What it means.** The story can be developed and delivered without waiting on another
in-flight story. Independence is about *scheduling freedom*: the team should be able to
pick this story up in any order relative to its siblings.

**How to test it.** Ask: "If we built this story next, before any of its siblings, would
it be blocked?" If the answer is "we'd have to build Story A first," the two are
coupled. Watch for hidden ordering: a story that assumes data another story produces, or
a UI that assumes a screen another story builds.

**The fix.** Two options:
- **Reorder** — if the dependency is real and unavoidable, sequence the dependency first
  and accept the ordering (record it explicitly so planning respects it).
- **Refactor to remove the coupling** — often the dependency is accidental. Split
  differently (e.g., a vertical slice through both stories) so each delivers a thin
  end-to-end increment instead of one horizontal layer that the other needs.

Perfect independence is not always achievable; the goal is to minimize coupling, not to
pretend it never exists.

---

## N — Negotiable

**What it means.** The story describes a *need*, not a chosen solution. The "how" stays
open for the Conversation. Cohn stresses this is the criterion most often lost in
practice: teams write implementation detail into the card, freezing the solution before
the conversation happens and defeating the story's purpose.

**How to test it.** Read the card and ask: "Does this dictate an implementation?" Words
like *REST endpoint*, *dropdown*, *PATCH*, *Postgres table*, *modal* are signals the
solution has been baked in. A negotiable story names what the user needs to accomplish
and leaves the design to the team.

**The fix.** Rewrite without the implementation. Move any genuinely-constraining
technical detail to a spike, a technical note, or an ADR reference — not the card. If a
constraint is real (e.g., "OAuth is mandated by the security NFRs"), state it as a
*constraint on the solution space*, not as the solution itself; the flow design remains
open.

---

## V — Valuable

**What it means.** The story delivers value to a real user (or a paying customer), not a
developer convenience. "Refactor the auth module" is work, but it is not a user story —
no user is better off in an observable way.

**How to test it.** Apply the **"so what?" test** to the benefit clause. Keep asking "so
what?" until the answer names a concrete change in the user's world:
- "so that I can export the report" → *so what?* → "so that I can hand the auditor
  evidence without rebuilding it by hand." Now it is valuable.
- "so that the system stores the data" → *so what?* → no user-facing answer surfaces.
  Not a user story.

**The fix.** If a story has no user-facing value, escalate rather than build. Ask
whether it should exist at all, or whether it is really a sub-task of a valuable story
(in which case it belongs under that story, not as a peer). Genuine technical enablers
are legitimate — but they are tracked as such, not disguised as user stories.

---

## E — Estimable

**What it means.** The team can form a rough view of the effort. A story need not be
estimated *precisely* — it must be estimable *at all*. Inability to estimate usually
signals one of two things: the story is too vague, or it is too large.

**How to test it.** Ask the team (or, for a solo analyst, reason through) whether a
ballpark size is possible. "We have no idea" is a fail. Distinguish *vague* (we don't
understand the need) from *large* (we understand it but it is too big).

**The fix.**
- **Too vague** → clarify the need, or write a time-boxed **spike** story whose output
  is knowledge, not shippable software. The spike removes the uncertainty; the original
  story becomes estimable afterward.
- **Too large** → split it (see `story-splitting-patterns.md`).

---

## S — Small

**What it means.** The story fits comfortably within a single sprint — small enough to
be built, tested, and demonstrated in one iteration. A story too big to fit is an
**epic** in Cohn's narrow sense: simply a story large enough that it must be split
before it can be planned.

**How to test it.** Signals a story is too big: it will span multiple sprints; it
carries a long list of acceptance criteria (say, more than five to seven); its title
uses "and" or lists several verbs ("connect, configure, and monitor").

**The fix.** Split using the named patterns in `story-splitting-patterns.md`. Do not
plan an oversized story as-is on the assumption it will be split "during the sprint" —
split it first, so each child is independently valuable and testable.

---

## T — Testable

**What it means.** The story can be verified — its done-ness is objectively checkable
via unambiguous acceptance criteria. "The system should be faster" is not testable;
"a scan of 10,000 files completes in under 60 seconds" is.

**How to test it.** Ask: "Could I write at least one Given/When/Then that unambiguously
passes or fails?" If the story's success is a matter of opinion, it is not testable.
Vague quality words — *better*, *faster*, *intuitive*, *seamless* — without a measurable
target are the tell.

**The fix.** Write at least one acceptance criterion before the story is considered
ready (the detailed set is owned by `acceptance-criteria`). If no criterion can be
written, the need is not understood well enough — return to the Conversation. Testable
and Estimable reinforce each other: a story you cannot exemplify with a concrete case is
usually a story you cannot size.

---

## The Fail-and-Fix Summary

| Fails | Symptom | Fix |
|---|---|---|
| Independent | "Story A must land first" | Reorder, or refactor into vertical slices |
| Negotiable | Card names an implementation | Rewrite as a need; move solution to a spike/note |
| Valuable | "so what?" finds no user change | Escalate; track as an enabler, not a story |
| Estimable | "We have no idea" | Spike (if vague) or split (if large) |
| Small | Spans sprints / long AC list | Split (see splitting patterns) |
| Testable | Success is a matter of opinion | Write one concrete acceptance criterion |

---

## Anti-Pattern Catalogue

| Anti-Pattern | Example | Why it fails | INVEST letter |
|---|---|---|---|
| **Solution story** | "As a user, I want a REST endpoint that returns JSON…" | Specifies the how, not the need | Negotiable |
| **Persona-free story** | "As a user, I want to…" | "User" is not a persona — which user? | (Format) |
| **System-as-actor** | "As the classification engine, I want to…" | Systems don't have wants; this is a technical task | Valuable |
| **Blank / circular "so that"** | "As a Compliance Officer, I want to export a report so that I can export a report." | The benefit restates the want — no user change named | Valuable |
| **Benefit-free story** | "As a Compliance Officer, I want to export a report." | No "so that" at all; value is unstated | Valuable |
| **Epic masquerading as a story** | 15 acceptance criteria; multiple sprints | Too big to plan or estimate | Small / Estimable |
| **Task masquerading as a story** | "Set up the database schema" | No user actor, no user value | Valuable |
| **Untestable quality story** | "As an admin, I want the dashboard to be intuitive." | No objective pass/fail | Testable |

The two most common and most damaging in practice are the **blank/circular "so that"**
(a benefit clause that merely restates the want — the "so what?" test is the guard) and
the **technical-task story** (an actor that is a system or a developer, with no user who
is observably better off).

---

## Role-Brainstorming Fallback

Cohn's technique predates persona-driven design. When `user-persona` has not yet
produced named personas — early-stage or under-resourced discovery — use **role
brainstorming** to generate the "As a ___" list mechanically:

1. **List** every distinct way a type of user interacts with the system.
2. **Consolidate** near-duplicate roles into one.
3. **Organize** the survivors along an axis that changes behavior — novice vs. expert,
   frequent vs. occasional, internal vs. external.

A **user role** is a lighter, earlier-stage construct than a **persona**: it is enough
to write and sanity-check a story's actor before deep persona work exists. For this
repo's product, the two anchor roles are the **Data Steward** and the **Compliance
Officer**; role brainstorming is how a third or fourth role (e.g., an external auditor,
a tenant administrator) gets surfaced before it is given full persona depth. Once
`user-persona` catches up, replace the role name with the named persona.
