# Worked Examples

Self-contained — loadable without reading `SKILL.md` first.

**STATUS: STUB — full content to be written in sub-issue #182 (d7).** This file's job: at least 3 full worked Aggregate designs for the data-estate-mapping product, each with the complete worksheet, Go type sketch, and a written rationale trail — including a genuinely hard boundary-drawing case with a documented alternative considered and rejected. Grounded in all three `research/domain-driven-design/` files.

## Worked Example 1: DataAsset
[Stub: a full worked design — invariants, entities, value objects, commands/events, cross-aggregate references, contention estimate, Go type sketch.]

## Worked Example 2: StorageSource
[Stub: full worked design, same shape as above.]

## Worked Example 3: A Genuinely Hard Boundary Case
[Stub: a case with real ambiguity — e.g., should ClassificationRule (a Knowledge-Level-shaped concept per Evans' Large-Scale Structure) be its own Aggregate referenced by ID from DataAsset, or folded into DataAsset directly? Show the alternative that was considered and rejected, and the specific reasoning (has-a vs. must-be-atomic-with, contention estimate) that decided it — modeling the "one big Aggregate, then correctly split it" narrative Vernon's own SaaSOvation walkthrough demonstrates, adapted to this repo's actual domain.]

## Worked Example 4 (if warranted): An Event-Sourced Aggregate
[Stub: if a plausible event-sourcing candidate exists in this repo's domain (e.g., classification history where Khononov's audit-as-record justification genuinely applies) — a full worked example of the event-sourced shape, contrasted with why the current-state alternative was rejected for this specific case.]
