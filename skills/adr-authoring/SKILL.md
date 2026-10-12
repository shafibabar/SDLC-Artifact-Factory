---
name: adr-authoring
description: >
  Teaches how to write Architecture Decision Records (ADRs) and when not to:
  the risk-driven gate for which decisions earn an ADR (cost of change x
  breadth of dependency x uncertainty), the ADR format with a named trade-off
  between architecture characteristics, the status lifecycle and superseding
  chains, and the companion Architecture Principle for durable cross-cutting
  guidance. Use when making, recording, reviewing, superseding or deprecating
  an architecture decision, deciding whether a decision needs an ADR at all,
  numbering a new ADR (scaffold-adr.sh), or checking one before acceptance
  (validate-adr.sh). Used by the enterprise-architect agent throughout the
  Design phase.
version: 4.0.2
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, adr, decision-records, trade-offs, principles, governance]
produces: architecture-decision-record
domain: architecture
status: stable
related: [skill-authoring-standards, nfr-specification, api-contract-design]
sources:
  - research/software-architecture/fundamentals-of-software-architecture-richards-ford.md
  - research/software-architecture/just-enough-software-architecture-fairbanks.md
  - research/software-architecture/documenting-software-architectures-clements.md
  - research/software-architecture/api-first-transformation-lane.md
---

# ADR Authoring

## Purpose

An Architecture Decision Record (ADR, Michael Nygard) is a short document that captures one significant architectural decision. It records the context that made the decision necessary, the options that were considered, the decision that was made, and the consequences — both positive and negative.

ADRs serve two purposes:
1. **Prevent re-litigation.** Once a decision is recorded as `Accepted`, it is settled. Teams stop re-arguing settled decisions and spend that energy building.
2. **Enable informed change.** When circumstances change and a decision needs to be revisited, the ADR gives the context needed to understand what was originally intended and why. Changing the decision means superseding the ADR, not deleting it.

Per Richards & Ford's *Fundamentals of Software Architecture* (Ch. 1), the deeper reason both purposes work is that **why is more important than how** — the reasoning behind a decision is what lets a future architect know when the decision no longer applies. An ADR that records the "how" without the "why" cannot be safely revisited later.

---

## When to Write an ADR — and When Not To

An ADR is an investment, so spend it where a wrong decision is expensive. Fairbanks (*Just Enough Software Architecture*) gives the gate: weigh three things together.
1. **Cost of change later.** How much rework would reversing this decision take?
2. **Breadth of dependency.** How many other decisions, components or teams rely on it?
3. **Uncertainty.** How likely is it that we're wrong, or that circumstances shift?

Write an ADR when the first two are high, more so as uncertainty rises: service decomposition, Context Map patterns, the tenancy model, cross-context integration style, API versioning strategy, data residency enforcement, and any deviation from a **stack-level** tech-stack default (`sdlc-config-management`) (language, API framework, primary database, message broker, CI/CD, IaC, service mesh, orchestration, observability). These are Richards & Ford's "architecture is the stuff that's hard to change" (*Fundamentals of Software Architecture*, Ch. 1).

**Deliberately write no ADR** when a decision is cheap to reverse and narrowly scoped, even if it is mildly non-obvious: a library hidden behind an interface, a config default, code style. **The gate takes precedence:** a library or tool that sits behind your own interface is not a stack-level choice, so picking one, whether or not it is the library some agent usually reaches for, never needs an ADR on the "deviation" rule alone. For the listed stack-level concerns, choosing the default is already recorded; write an ADR only to deviate from it. Over-recording is a real cost: the decisions that matter get buried. For a worked triage of six candidate decisions, read `./examples/04-when-not-to-write-an-adr.md`.

**A diagram's shape is not an ADR.** "Why does this view look this way" is a sentence or two of rationale in the diagram's own documentation (Clements, *Documenting Software Architectures*). An ADR records a cross-cutting decision that may outlive many views. Merging the two creates a record with two lifecycles.

---

## Architecture Decisions vs. Architecture Principles

Not everything that sounds like a decision is one. An ADR is a specific, point-in-time choice for this system, in this context — superseded when circumstances change, never edited in place. A **Principle** is durable, general guidance cited by many future ADRs (e.g., "prefer asynchronous communication across Bounded Contexts"). Writing a Principle's reasoning inside a single ADR's Rationale buries guidance that should outlive that one decision — if that ADR is ever superseded, the general guidance silently disappears along with the specific choice it happened to be attached to.

**The test:** if the reasoning would apply unchanged to many future, unrelated decisions — not just the one at hand — it belongs in a Principle, not an ADR's Rationale. For the full distinction, the Principle format, its storage convention and two illustrative Principles, read `./references/architecture-principles.md`.

---

## ADR Format

An ADR is a product artifact, so its frontmatter carries the plugin's six standard fields (`name: adr-NNN-<slug>`, `version`, `phase`, `owner`, `created`, `summary`, where the summary states the decision *and* its trade-off), then the ADR fields `adr-id`, `title`, `status`, `deciders`, and `traces_to` (the NFR, requirement or earlier ADR that made the decision necessary). Without the standard fields, the artifact-structure hook blocks the write. The body has six required sections: Status, Context (stated neutrally — facts and forces, not an argument for the conclusion), Decision (an active declarative sentence), Options Considered (at least two, each with honest pros/cons), Rationale, and Consequences (Positive, Negative/Trade-offs, and Risks — all three, not just the positive). A closing Related ADRs section links dependent or related decisions.

**Rationale must name the trade-off.** Per Ch. 4's framing of architecture characteristics as inherently competing, the Rationale section requires an explicit `**Trade-off:**` line naming the 2-3 characteristics being traded off against each other — e.g., "durability over latency," not left implicit in surrounding prose. The characteristics being traded off are frequently the same ones `nfr-specification`'s Architecture Handoff section already flagged as architecturally significant — cite them by the same name rather than restating them in different words. For a decision with three or more genuinely competing characteristics, add an optional trade-off matrix (rows = characteristics, columns = options) to Options Considered — text-only pros/cons lose a multi-dimensional trade-off past two axes.

**To produce one:**
- Run `./scripts/scaffold-adr.sh <product> <slug>`. It fills `./templates/adr-template.md` with the next number, name and date.
- Or copy that template by hand.
- For what belongs in each field, read `./references/adr-field-guide.md`.

**Examples, from simple to complex:**
- A two-option decision with a prose trade-off: `./examples/01-two-options-prose-trade-off.md`.
- Three or more competing characteristics, with a trade-off matrix: `./examples/02-three-characteristics-trade-off-matrix.md`.
- The enterprise case: a multi-tenant isolation decision superseded when enterprise isolation, residency and per-tenant availability arrive. It shows the full superseding mechanics: `./examples/03-enterprise-tenancy-supersession.md`.

---

## ADR Status Lifecycle

| Status | Meaning |
|---|---|
| **Proposed** | Under consideration — not yet accepted. May be discussed and revised. |
| **Accepted** | The decision is settled. Implement accordingly. Do not re-argue without new information. |
| **Deprecated** | The decision is no longer relevant — the context has changed. Not superseded; just no longer active. |
| **Superseded by ADR-NNN** | A newer ADR has replaced this one. This ADR is kept for historical context — never deleted. |

ADRs are never deleted. Even superseded ADRs remain in the record because they show what was decided before and why the team changed course.

### Superseding Chains

Superseding has mechanics that keep the record navigable years later:

- **Links are bidirectional.** The new ADR carries `Supersedes: ADR-NNN` in its Related ADRs; the old ADR's status becomes `Superseded by ADR-MMM`. Updating the old ADR's status line is part of accepting the new one — an unlinked supersession is a defect.
- **Supersede whole decisions, never fractions.** If only part of a decision changes, the new ADR restates the parts being kept alongside the parts being changed, and supersedes the old ADR entirely. An ADR that is "half active" cannot be trusted by a reader who finds it first.
- **Supersede the head of the chain.** A new decision replaces the *current* ADR, not one already superseded. Chains read `ADR-003 → superseded by ADR-017 → superseded by ADR-041`; a reader landing anywhere in the chain can walk forward to the live decision in one direction.
- **A superseding ADR must say what changed.** Its Context section names the original decision, what shifted since (new constraint, new information, changed scale), and why the original rationale no longer holds. "We changed our minds" without new information is re-litigation, not evolution.
- **Deprecated ≠ Superseded.** Use `Deprecated` when the decision's subject no longer exists (the feature was removed); use `Superseded` when a replacement decision exists. A Deprecated ADR has no forward link.

---

## ADR Numbering

ADRs are numbered sequentially: `ADR-001`, `ADR-002`, ... Within a product, ADR numbering is product-scoped. `./scripts/scaffold-adr.sh` resolves the next number automatically by scanning `artifacts/[product]/design/decisions/` for the highest existing `ADR-NNN` — do not hand-assign a number when the script is available, since a hand-assigned number is exactly the kind of thing two concurrent decisions can silently collide on.


---

## ADR Storage

ADRs are stored at: `artifacts/[product]/design/decisions/ADR-[NNN]-[slug].md`

The enterprise-architect maintains an ADR index at `artifacts/[product]/design/decisions/README.md`. It is an artifact too, so it opens with the standard frontmatter (`name: adr-index`, …, `summary` giving the count of Accepted and Superseded ADRs).

Principles for the same product live alongside them in `PRINCIPLES.md`; `./references/architecture-principles.md` gives the storage convention and its frontmatter.

---

## Scripts

Per `skill-authoring-standards`, this skill owns two deterministic, single-purpose scripts — neither makes a judgment call; both are mechanical checks or generation steps that free the enterprise-architect to spend reasoning on the decision itself, not the paperwork around it.

| Script | Does | Run when |
|---|---|---|
| `./scripts/scaffold-adr.sh <product> <slug>` | Copies `./templates/adr-template.md`, resolves the next `ADR-NNN` by scanning `artifacts/[product]/design/decisions/`, fills in `created`, the `name`, and the resolved `adr-id`/`title` placeholders, writes `artifacts/[product]/design/decisions/ADR-[NNN]-[slug].md` | Starting any new ADR — replaces hand-copying the template and hand-counting existing files |
| `./scripts/validate-adr.sh <path-to-adr.md>` | Checks the required frontmatter (the six standard fields plus `adr-id`, `title`, `status`, `deciders`), a Rationale `**Trade-off:**` line exists, Consequences has all three subsections (Positive/Negative/Risks), and a Related ADRs section is present — reports pass/fail per check, mirroring the Quality Criteria table below | Before marking an ADR `Accepted`, or as a final check before considering an ADR done |

Both are advisory, not blocking — they mechanize the parts of this skill's Quality Criteria that are actually checkable by a script (structure, presence, required sections) and leave the parts that require judgment (is the Context neutral, is the Rationale honest) to the enterprise-architect's own review.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Context is neutral | Context states facts and forces — does not argue for a conclusion | Context written to justify the chosen option |
| Multiple options | At least two options considered with honest pros/cons | Single-option "decision" with no alternatives |
| Named trade-off | Rationale's `**Trade-off:**` line names the 2-3 characteristics traded off | Rationale describes the choice without naming competing characteristics |
| Honest consequences | Negative consequences and trade-offs explicitly listed | Only positive consequences listed |
| Active decision statement | "We will..." or "We have decided to..." | Passive or hedged decision statements |
| Status current | Status field reflects actual state | ADR still marked Proposed after it was implemented |
| Never deleted | Superseded ADRs link to the superseding ADR; both exist | ADRs deleted when decisions change |
| Chain integrity | Supersession links are bidirectional and always point to the chain head | One-way links, or an ADR superseding an already-superseded ADR |
| Earned its place | The decision passed the risk gate (costly to change, widely depended on) | An ADR for a cheap, local, reversible choice |
| Decision vs. Principle | General, durable guidance is recorded as a Principle, cited by ADRs | A Principle's reasoning is buried inside one ADR's Rationale |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **The retrofitted ADR** — writing the ADR after implementation to bless what was built | Options were never really considered; the "rationale" is reverse-engineered justification | Write the ADR at `Proposed` before implementation; acceptance is the gate to building |
| **Advocacy context** — a Context section that argues for the chosen option | Readers cannot evaluate whether the forces still hold; the ADR loses its power to enable informed change | Context states facts, forces, and constraints neutrally; the argument belongs in Rationale |
| **Straw-man options** — alternatives listed only to be knocked down | The decision looks considered but is not; when circumstances change, no genuine fallback exists in the record | Each option gets its honest best case; the chosen option must win against real competition |
| **The consequences-free decision** — only positive consequences listed | Every architectural decision buys something by giving something up; hiding the cost guarantees surprise later | Negative consequences and accepted trade-offs are mandatory; an ADR with no downsides is incomplete |
| **ADR as documentation dump** — recording tutorials, diagrams, and how-to content in an ADR | The decision drowns; nobody can find what was actually decided | One decision per ADR; reference designs and diagrams live in their own artifacts, linked |
| **Editing an Accepted ADR in place** — updating the decision text as things change | The historical record is destroyed; "why did we believe X in June?" becomes unanswerable | Accepted ADRs are immutable except for status-line updates; changes require a superseding ADR |
| **The mega-ADR** — one record covering event publication, API versioning, and tenancy | The parts have different lifecycles; superseding one aspect falsely invalidates the rest | Split into one ADR per independently reversible decision, cross-linked in Related ADRs |
| **The principle disguised as a decision** — a Rationale whose reasoning generalizes far beyond the one decision at hand ("we always prefer async") | If this ADR is ever superseded, the general guidance silently disappears with it — future ADRs have nothing to cite | Pull the generalization into a Principle record (`./references/architecture-principles.md`); the ADR's Rationale cites it instead of restating it |
| **The ADR for everything** — recording every non-obvious choice, including cheap, narrow ones | The few decisions that are expensive to change get buried; recording becomes ceremony nobody reads | Apply the risk gate: no ADR for decisions that are cheap to reverse and narrowly depended on |
| **Hand-counting the next ADR number** — reading the directory listing and guessing the next `NNN` | Two decisions written close together can silently collide on the same number | Run `./scripts/scaffold-adr.sh`, which resolves the number by scanning the directory itself |

---

## Output Format

To produce the ADR, copy `./templates/adr-template.md` (or generate it with `./scripts/scaffold-adr.sh`) and fill every field, using `./references/adr-field-guide.md` for what each one needs. Before marking it `Accepted`, run `./scripts/validate-adr.sh` for the mechanical checks; the Quality Criteria above cover the judgment calls.
