---
name: event-storming-design-level
product: [product slug]
version: 1.0.0
phase: design
owner: domain-modeler
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: the aggregates found, the Bounded Context candidates and the open hotspots]
profile: [standard | enterprise]
mode: [agent-run | human session on YYYY-MM-DD with <roles>]
traces-to: [design/event-storming/big-picture.md, design/event-storming/process-*.md]
---

# Event Storming Software Design: [Product or area]

## Aggregates (consistency units)

| Aggregate | Commands handled | Events emitted | Invariant that must hold at every instant | Source |
|---|---|---|---|---|

## Read Models

| Read Model | Built from events | Used by (actor) before (command) |
|---|---|---|

## Policies

| Whenever (event) | Then (command) | Crosses to aggregate |
|---|---|---|

## Bounded Context Candidates

| Candidate | Aggregates inside | Language change that justifies the boundary | Big Picture hint it confirms |
|---|---|---|---|

Aggregates and contexts are different boundaries: an aggregate is justified by an invariant, a context by a change of language.

## Hotspots

| ID | Hotspot | Kind | Goes to | Question for the product owner | Assumed meanwhile |
|---|---|---|---|---|---|
