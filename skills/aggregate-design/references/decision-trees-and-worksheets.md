# Decision Trees and Worksheets

Self-contained — loadable without reading `SKILL.md` first.

**STATUS: STUB — full content to be written in sub-issue #183 (d8), after d5-d7 land.** This file's job: explicit, branching if/then decision-support structures — not prose to infer branches from — plus the expanded fill-in worksheet. This is the "sentinel"-style content Shafi specifically asked for: a modeler (or an agent) should be able to follow a literal decision tree to a conclusion, not need to synthesize one from paragraphs.

## Decision Tree 1: Which Business Logic Design Pattern Does This Aggregate/Use Case Need?
[Stub: an explicit branching tree starting from subdomain classification (Core/Supporting/Generic per subdomain-distillation) and actual logic complexity, routing to Transaction Script / Active Record / Domain Model / Event-Sourced Domain Model — per Khononov's four-pattern catalog. This is the FIRST gate a modeler should pass through, before any of this skill's other content applies.]

## Decision Tree 2: Is This a True Invariant?
[Stub: Vernon's three-question test as an explicit branching structure — would a momentary violation cause real business harm? / can a violation be fixed with a reasonable compensating action? / is it already enforced by an external system? — routing to "belongs in this consistency boundary" or "push outside, use eventual consistency" or "this isn't actually a rule this Aggregate needs to enforce at all."]

## Decision Tree 3: Should This Be One Aggregate or Two?
[Stub: branching on the has-a vs. must-be-atomic-with test, the three sizing angles (performance/scalability/collaboration), and the contention estimate — routing to a clear split/merge/keep-as-is conclusion.]

## Decision Tree 4: Optimistic Concurrency, Pessimistic Locking, or Serializable Isolation?
[Stub: branching on expected contention, cost of a failed optimistic attempt, and whether the workload is interactive (user-facing) or batch/administrative.]

## Decision Tree 5: Should This Aggregate Adopt Event Sourcing?
[Stub: Khononov's three-question justification test as an explicit branch — temporal query need? retroactive projection need? audit-as-record need? — with "no" to all three routing firmly to current-state persistence regardless of Core Domain status, and "yes" to any routing to the event-sourced pattern with its attendant costs named.]

## Decision Tree 6: Is a Cross-Aggregate Operation a Modeling Smell or a Genuine Process?
[Stub: branching on whether the operation reveals a true invariant spanning what are currently two Aggregates (merge them, or accept the documented exception) versus a genuinely multi-step business process (model it as a Saga).]

## The Aggregate Design Worksheet (Expanded)
[Stub: the existing worksheet, expanded with new fields: Business Logic Pattern chosen + one-line justification; Identity generation strategy; Concurrency strategy; Event Sourcing justification (or "not applicable — current-state, no qualifying need"); the has-a vs. must-be-atomic-with answer for every cross-Aggregate relationship, not just a bare reference list.]

## Finalize SKILL.md
[This sub-issue also updates skills/aggregate-design/SKILL.md's References routing table and any section that still points at a STUB marker, replacing every stub reference with the real, completed content from d5-d8 — the last step before this skill is considered complete.]
