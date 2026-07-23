---
name: adr-authoring
description: >
  Teaches how to write Architecture Decision Records (ADRs) — the authoritative
  log of every significant architectural choice, the context that prompted it,
  the options considered, and the rationale for the decision made, including
  naming which architecture characteristics were explicitly traded off against
  each other (per Fundamentals of Software Architecture). ADRs are mandatory
  for every non-obvious architecture decision in this plugin. They prevent
  re-litigating settled decisions and give future engineers (and future
  Claude sessions) the context needed to understand why the system is built
  the way it is. Also teaches the companion Architecture Principle format for
  durable, cross-cutting guidance that many ADRs cite, as distinct from a
  single point-in-time decision. Includes scripts/scaffold-adr.sh (generates
  a new ADR file pre-filled from the template, auto-resolving the next
  ADR-NNN) and scripts/validate-adr.sh (mechanically checks an existing ADR
  against this skill's Quality Criteria). Used by the enterprise-architect
  agent throughout the Design phase.
version: 3.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, adr, decision-records, trade-offs, principles, governance]
related: [skill-authoring-standards, nfr-specification]
---

# ADR Authoring

## Purpose

An Architecture Decision Record (ADR, Michael Nygard) is a short document that captures one significant architectural decision. It records the context that made the decision necessary, the options that were considered, the decision that was made, and the consequences — both positive and negative.

ADRs serve two purposes:
1. **Prevent re-litigation.** Once a decision is recorded as `Accepted`, it is settled. Teams stop re-arguing settled decisions and spend that energy building.
2. **Enable informed change.** When circumstances change and a decision needs to be revisited, the ADR gives the context needed to understand what was originally intended and why. Changing the decision means superseding the ADR, not deleting it.

Per Richards & Ford's *Fundamentals of Software Architecture* (Ch. 1), the deeper reason both purposes work is that **why is more important than how** — the reasoning behind a decision is what lets a future architect know when the decision no longer applies. An ADR that records the "how" without the "why" cannot be safely revisited later.

---

## When to Write an ADR

Write an ADR for every decision that is:
- **Non-obvious** — a reasonable engineer could have made a different choice
- **Consequential** — changing the decision later would require significant rework
- **Contested** — there was disagreement about the right approach
- **Cross-cutting** — the decision affects multiple services or teams

Do NOT write an ADR for:
- Implementation details that follow obviously from the architecture (e.g., "we will use pgx for PostgreSQL" — this follows from the tech stack decision)
- Decisions that can be trivially reversed with no architectural impact
- Code style or formatting choices

**In this plugin:** Every major architecture decision captured during the Design phase is an ADR. The enterprise-architect writes ADRs for: service decomposition decisions, context map pattern selections, event schema design choices, API versioning strategy, data residency enforcement mechanisms, and technology choices that deviate from the defaults in `sdlc-context.json`.

---

## Architecture Decisions vs. Architecture Principles

Not everything that sounds like a decision is one. An ADR is a specific, point-in-time choice for this system, in this context — superseded when circumstances change, never edited in place. A **Principle** is durable, general guidance cited by many future ADRs (e.g., "prefer asynchronous communication across Bounded Contexts"). Writing a Principle's reasoning inside a single ADR's Rationale buries guidance that should outlive that one decision — if that ADR is ever superseded, the general guidance silently disappears along with the specific choice it happened to be attached to.

**The test:** if the reasoning would apply unchanged to many future, unrelated decisions — not just the one at hand — it belongs in a Principle, not an ADR's Rationale. Full distinction, Principle format, storage convention, and a worked example: `references/architecture-principles.md`.

---

## ADR Format

An ADR's frontmatter carries `adr-id`, `title`, `status`, `date`, and `deciders`. The body has six required sections: Status, Context (stated neutrally — facts and forces, not an argument for the conclusion), Decision (an active declarative sentence), Options Considered (at least two, each with honest pros/cons), Rationale, and Consequences (Positive, Negative/Trade-offs, and Risks — all three, not just the positive). A closing Related ADRs section links dependent or related decisions.

**Rationale must name the trade-off.** Per Ch. 4's framing of architecture characteristics as inherently competing, the Rationale section requires an explicit `**Trade-off:**` line naming the 2-3 characteristics being traded off against each other — e.g., "durability over latency," not left implicit in surrounding prose. The characteristics being traded off are frequently the same ones `nfr-specification`'s Architecture Handoff section already flagged as architecturally significant — cite them by the same name rather than restating them in different words. For a decision with three or more genuinely competing characteristics, add an optional trade-off matrix (rows = characteristics, columns = options) to Options Considered — text-only pros/cons lose a multi-dimensional trade-off past two axes.

Full template with both additions inline, ready to copy: `references/output-format-template.md`. The identical template as a literal, fill-in-and-go file: `assets/adr-template.md` — use it directly, or run `scripts/scaffold-adr.sh` to generate a new ADR from it with the frontmatter and next ADR number already filled in. Two full worked examples — one two-option/prose-trade-off ADR, one three-characteristic ADR with a filled-in matrix: `references/worked-example.md`.

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

ADRs are numbered sequentially: `ADR-001`, `ADR-002`, ... Within a product, ADR numbering is product-scoped. `scripts/scaffold-adr.sh` resolves the next number automatically by scanning `artifacts/[product]/design/decisions/` for the highest existing `ADR-NNN` — do not hand-assign a number when the script is available, since a hand-assigned number is exactly the kind of thing two concurrent decisions can silently collide on.

The SDLC Artifact Factory plugin itself also has ADRs for its own design decisions (already captured in `sdlc-context.json → decisions` — those will be formalised as ADRs when the remaining governance skills are built).

---

## ADR Storage

ADRs are stored at: `artifacts/[product]/design/decisions/ADR-[NNN]-[slug].md`

The enterprise-architect maintains an ADR index at: `artifacts/[product]/design/decisions/README.md`

Principles for the same product live alongside them — see `references/architecture-principles.md` for the storage convention.

---

## Scripts

Per `skill-authoring-standards`, this skill owns two deterministic, single-purpose scripts — neither makes a judgment call; both are mechanical checks or generation steps that free the enterprise-architect to spend reasoning on the decision itself, not the paperwork around it.

| Script | Does | Run when |
|---|---|---|
| `scripts/scaffold-adr.sh <product> <slug>` | Copies `assets/adr-template.md`, resolves the next `ADR-NNN` by scanning `artifacts/[product]/design/decisions/`, fills in `date` and the resolved `adr-id`/`title` placeholders, writes `artifacts/[product]/design/decisions/ADR-[NNN]-[slug].md` | Starting any new ADR — replaces hand-copying the template and hand-counting existing files |
| `scripts/validate-adr.sh <path-to-adr.md>` | Checks required frontmatter fields are present, a Rationale `**Trade-off:**` line exists, Consequences has all three subsections (Positive/Negative/Risks), and a Related ADRs section is present — reports pass/fail per check, mirroring the Quality Criteria table below | Before marking an ADR `Accepted`, or as a final check before considering an ADR done |

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
| **The principle disguised as a decision** — a Rationale whose reasoning generalizes far beyond the one decision at hand ("we always prefer async") | If this ADR is ever superseded, the general guidance silently disappears with it — future ADRs have nothing to cite | Pull the generalization into a Principle record (`references/architecture-principles.md`); the ADR's Rationale cites it instead of restating it |
| **Hand-counting the next ADR number** — reading the directory listing and guessing the next `NNN` | Two decisions written close together can silently collide on the same number | Run `scripts/scaffold-adr.sh`, which resolves the number by scanning the directory itself |

---

## Output Format

Fill-in-and-go: `assets/adr-template.md` (or generate it directly via `scripts/scaffold-adr.sh`). Annotated template explaining each field: `references/output-format-template.md`. Two worked examples: `references/worked-example.md`. Companion Principle format: `references/architecture-principles.md`. Mechanical structure check before calling an ADR done: `scripts/validate-adr.sh`.
