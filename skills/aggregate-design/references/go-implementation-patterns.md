# Go Implementation Patterns

Self-contained — loadable without reading `SKILL.md` first.

**STATUS: STUB — full content to be written in sub-issue #182 (d7).** This file's job: full Go implementation depth for BOTH current-state and event-sourced Aggregates, grounded in all three `research/domain-driven-design/` files plus this repo's existing `go-domain-model`/`go-repository-pattern` skills (for consistency, not reinvention).

## Aggregate Root in Go — Current-State Persistence
[Stub: existing content to preserve and deepen — the full struct shape, constructor/reconstitution split, domain event collection, mutation methods enforcing invariants before applying change.]

## Identity Generation in Go
[Stub: client-generated (uuid.New() at construction, Vernon's preferred default) vs. persistence-generated (DB sequence, disfavored) vs. Repository.NextIdentity() for business-meaningful identifiers — concrete Go code for each, with the reasoning for why client-generated is the default (a fully valid instance, ID included, exists before any I/O).]

## Concurrency Strategy in Go
[Stub: the existing optimistic compare-and-swap UPDATE ... WHERE version = $N pattern, PLUS a concrete SELECT ... FOR UPDATE pessimistic-locking example for the narrow, justified exception case Vernon names.]

## Factory Methods and the Construction/Reconstitution Split
[Stub: NewDataAsset (construction, emits events) vs. Reconstitute (no events, no re-validation) as a named Factory-method pair, plus a worked example of a genuinely complex Factory case — construction that must simultaneously create and validate a companion object as one atomic operation.]

## A Worked Child Entity Example
[Stub: this repo's existing skills never show a locally-identified child Entity (only a root plus Value Objects) — a full example (e.g. ExtractedEntity inside DataAsset) demonstrating local identity scoped to the root, per Evans' local-vs-global identity distinction.]

## Event-Sourced Aggregates in Go
[Stub: the alternative persistence shape — Apply/When methods per event type, state derived by folding the event stream, used identically for replay-from-storage and in-memory update-after-command. Concrete Go interface and struct shape, genuinely new to this repo per the Khononov research finding that no event-sourced Go pattern exists anywhere yet.]

## The Event-Sourced Repository: Conditional Append
[Stub: an append-only event store with append-if-expected-version, framed explicitly as the same optimistic-concurrency principle as the current-state CAS pattern, applied to a different storage shape — not a different concurrency philosophy.]

## Snapshotting
[Stub: periodic persistence of derived current state alongside (not instead of) the event stream, purely as a load-time performance optimization, always regeneratable from the stream. Concrete Go pattern for snapshot cadence and rebuild.]

## Event Upcasting
[Stub: a versioned, load-time transformation converting an old-shape stored event into the current expected shape, without ever rewriting the stored event. Distinguished from domain-event-catalog's additive/breaking-version strategy for transient integration events — this is the discipline for permanently-stored internal events specifically.]

## Distinguishing Internal Events from Published Domain Events
[Stub: an event-sourced Aggregate's internal persistence events may be more granular than what's business-meaningful externally — the translation/enrichment step that derives the coarser public Domain Event, and why publishing every internal state transition as an external contract is a hidden-coupling hazard.]
