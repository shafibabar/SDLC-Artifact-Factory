# Invariants and Consistency Boundaries

Self-contained — loadable without reading `SKILL.md` first.

**STATUS: STUB — full content to be written in sub-issue #180 (d5).** This file's job: give a modeler an unambiguous, applicable test for "is this a True Invariant" and full depth on the exception process, grounded in `research/domain-driven-design/implementing-ddd-vernon.md` (Vernon's three-question test, the SaaSOvation Product/BacklogItem counter-example) and `research/domain-driven-design/domain-driven-design-evans.md` (the original invariant-clustering argument, Assertions).

## What Vernon's Three-Question Test Actually Tests
[Stub: the precise test — would a momentary violation cause real business harm? does correcting it need more than a reasonable compensating action? is it already enforced externally? A "yes/no/no" is the only combination that earns a consistency boundary.]

## A Correctly Identified True Invariant, Worked
[Stub: this skill's own DataAsset/StorageSource classification example, walked through against the three-question test explicitly.]

## A Rule That Looks Like an Invariant But Isn't — Worked Counter-Example
[Stub: Vernon's Product/BacklogItem/Task SaaSOvation narrative, adapted to this repo's own domain — a rule that seems to demand atomicity but is really conceptual composition ("has-a") mistaken for a transactional requirement.]

## The Relationship Between an Invariant and a Database Transaction
[Stub: why the consistency boundary and the transaction boundary must coincide, and what goes wrong when they don't.]

## When It's OK to Break These Rules
[Stub: Vernon's own explicitly-not-absolutist stance and his two named exception categories — a genuine cross-object business invariant (e.g. financial debit/credit), or a measured (not hypothesized) performance bottleneck with a read-only, never-authoritative denormalized copy as the only sanctioned fix. Both require deliberate documentation, not convenience.]

## Assertions: Pre- and Post-Conditions as a Design Discipline
[Stub: Evans' Assertion concept — explicit pre/post-conditions per operation, not just a static list of invariants — distinct from the testing-assertion sense and Secure by Design's security-hardening sense, both already in this repo's vocabulary elsewhere.]

## Quality Checklist for This File's Content
[Stub: a short checklist a modeler can run against a candidate invariant before finalizing a boundary.]
