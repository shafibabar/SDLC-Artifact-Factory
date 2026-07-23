# ADR Output Format Template

Self-contained — loadable without reading `SKILL.md` first.

This is the **annotated** version — every placeholder explains what belongs there and why. For a literal, fill-in-and-go copy with no explanatory brackets, use `assets/adr-template.md` directly, or run `scripts/scaffold-adr.sh <product> <slug>` to generate a new ADR file from it with the frontmatter and next `ADR-NNN` already resolved.

---

```markdown
---
adr-id: ADR-[NNN]
title: [Short imperative title — "Use Transactional Outbox for Event Publication"]
status: [Proposed | Accepted | Deprecated | Superseded by ADR-NNN]
date: [YYYY-MM-DD]
deciders: [Who made this decision]
---

# ADR-[NNN]: [Title]

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-NNN]

## Context
[The situation that made this decision necessary. What forces are at play?
What problem are we solving? What constraints exist? What would happen
if we did nothing?]

## Decision
[The decision that was made, stated as a clear, active declarative sentence.
"We will..." or "We have decided to..."]

## Options Considered

### Option A: [Name]
**Description:** [What this option entails]
**Pros:** [Benefits]
**Cons:** [Drawbacks]

### Option B: [Name]
[Repeat]

### Option C: [Name] (if applicable)
[Repeat]

[If 3 or more architecture characteristics are genuinely competing across
these options — not just 2 options with 1 obvious axis — add a trade-off
matrix here. Rows are characteristics (availability, consistency, latency,
cost, decoupling, ...), columns are the options above. A two-option,
single-axis decision does not need one; forcing a matrix onto a simple
trade-off just adds ceremony. See `references/worked-example.md` Example 2
for a filled-in matrix.]

| Characteristic | Option A | Option B | Option C |
|---|---|---|---|
| [characteristic] | | | |

## Rationale
**Trade-off:** [Required. Name the 2-3 architecture characteristics being
traded off against each other explicitly — e.g., "durability over latency"
or "workflow visibility over decoupling." This is a distinct, named line,
not left implicit in the prose that follows.]

[Why was this option chosen over the others? Which criteria were most important?
What trade-offs were deliberately accepted?]

## Consequences

### Positive
- [Benefit that results from this decision]

### Negative / Trade-offs
- [Cost or constraint this decision introduces]

### Risks
- [What could go wrong; how it is mitigated]

## Related ADRs
- [ADR-NNN — related or dependent decision]
```

Each ADR is a standalone Markdown file:
`artifacts/[product]/design/decisions/ADR-[NNN]-[kebab-case-title].md`

For the companion Principle artifact format (durable, cross-cutting
guidance cited by many ADRs, as distinct from a single point-in-time
decision), see `references/architecture-principles.md`.
