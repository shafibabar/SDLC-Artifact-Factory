# Architecture Decisions vs. Architecture Principles

Self-contained — loadable without reading `SKILL.md` first. Per Mark
Richards and Neal Ford's *Fundamentals of Software Architecture* (Ch. 18,
"Architecture Decision Records" —
`research/software-architecture/fundamentals-of-software-architecture-richards-ford.md`),
which distinguishes two artifact types this repo has historically
conflated into one.

---

## The Distinction

| | Architecture Decision (ADR) | Architecture Principle |
|---|---|---|
| **Scope** | One specific, concrete choice made for this system, in this context | A general rule of thumb that guides many future decisions |
| **Lifespan** | Point-in-time. Accepted, then immutable except for status changes. Superseded when circumstances change — never edited in place. | Durable. Revised directly as understanding improves — it is guidance, not a historical record. |
| **Example** | "Use the Transactional Outbox pattern for Domain Event publication in the Classification Service" | "Prefer asynchronous communication across Bounded Contexts" |
| **What cites what** | An ADR's Rationale may cite a Principle as a standing default it upholds or a justified exception to | A Principle is cited by many ADRs over time; it does not itself reference a single decision |

**The test:** if the reasoning in an ADR's Rationale would apply unchanged to many future, unrelated decisions — not just the one at hand — it is a Principle wearing a Decision's clothes. Pull it out.

A concrete failure mode this test catches: an ADR's Rationale reads "we chose async because we always prefer async for cross-context flows." That sentence is doing two jobs. The specific choice (which pattern, for which flow) belongs in the ADR. The general preference ("we always prefer async") is a Principle — and if it stays buried in one ADR's prose, a future engineer who supersedes *that* ADR unknowingly deletes the general guidance along with the one-off decision it happened to be attached to.

---

## When a Repo-Wide Convention Is Already a Principle

This repo's own `CLAUDE.md` and several skills already state durable, general guidance in prose without naming it as a Principle — for example, `integration-design`'s "Default rule: Use asynchronous (events) for cross-Bounded-Context communication. Use synchronous only when a response is required in the current request's flow." That sentence is a Principle by the test above: it is cited implicitly by every future sync-vs-async decision, not scoped to one flow.

Whether to retroactively formalize this repo's own existing conventions as named Principle records is a decision for Shafi, not something this skill does unilaterally — see `sdlc-context.json`'s `open_questions`. What this skill's Principle format is *for* is a specific, recurring situation the enterprise-architect hits per product: a product-level default that will be cited by name across many ADRs for that product (e.g., "this product prefers eventual consistency over strong consistency for cross-service reads" — established once, cited by every Read Model ADR that follows).

---

## Principle Format

```markdown
---
principle-id: PRINCIPLE-[NNN]
statement: [One sentence, stated as a standing rule — "Prefer X over Y for Z"]
established: [YYYY-MM-DD]
owner: enterprise-architect
---

# PRINCIPLE-[NNN]: [Short name]

## Statement
[The rule itself, one or two sentences, imperative — this is the part
every citing ADR quotes or paraphrases.]

## Rationale
[Why this holds generally for this product — the characteristics or
constraints that make it the right default across many decisions, not
just one.]

## Scope
[What this Principle governs, and what it explicitly does not — a
Principle stated too broadly invites ADRs to misapply it outside its
actual domain.]

## Exceptions
[Known situations where a specific ADR justifiably deviates from this
Principle, and why deviation was accepted rather than treated as a
violation. A Principle with zero acknowledged exceptions is either
young or being applied too rigidly — revisit it as real exceptions
accumulate.]

## Cited By
- [ADR-NNN — how this ADR applied or deviated from the Principle]
```

Unlike an ADR, a Principle is **not superseded** — it is revised in place. The `established` date marks when it was first recorded; a revision updates the Statement/Rationale/Scope directly and the change is visible in the file's own version history (git blame), not through a supersession chain. If a Principle is reversed outright (not refined — actually abandoned), record that reversal as its own ADR ("Stop applying PRINCIPLE-NNN for X") rather than silently deleting or rewriting the Principle to say the opposite of what it said when ADRs cited it.

---

## Worked Example (Illustrative)

If a product's enterprise-architect wanted to formalize this repo's own `integration-design` default as a citable Principle for that product — rather than leaving it as prose only that skill states — it would look like this:

```markdown
---
principle-id: PRINCIPLE-001
statement: Prefer asynchronous Domain Events over synchronous calls for cross-Bounded-Context communication.
established: 2026-06-25
owner: enterprise-architect
---

# PRINCIPLE-001: Asynchronous by Default Across Bounded Contexts

## Statement
Cross-Bounded-Context communication uses asynchronous Domain Events by
default. Synchronous calls are the justified exception, not the default.

## Rationale
Synchronous cross-context calls multiply availability down the call
chain — every downstream incident becomes every upstream service's
incident too. This product's compliance use case depends on the platform
staying available even when a single downstream integration (e.g. a
storage source connector) degrades; async decoupling is what makes that
possible without a much more expensive resilience investment per
synchronous edge.

## Scope
Governs Bounded-Context-to-Bounded-Context communication only — within
a single Bounded Context, direct method/function calls remain normal
and this Principle does not apply. Also does not govern
external-partner integrations, which have their own resilience
requirements documented in `integration-design`.

## Exceptions
- A synchronous call is used when the caller's request cannot complete
  without the response (e.g., a read that must return current data,
  not eventually-consistent data) — see `integration-design`'s
  synchronous resilience patterns (timeout/retry/circuit
  breaker/bulkhead) for how these are made safe.

## Cited By
- ADR-005 — Choreography-based event flow for classification pipeline
  (upholds this Principle)
- ADR-012 — Synchronous read for real-time compliance-gap dashboard
  query (justified exception, per Scope)
```

---

## Storage

Principles for a product are kept in a single evolving catalog, not one
file per Principle (unlike ADRs, which are point-in-time and immutable):
`artifacts/[product]/design/decisions/PRINCIPLES.md` — a table of
Principle ID, Statement, and which ADRs cite it, alongside the full
Principle records below the table.
