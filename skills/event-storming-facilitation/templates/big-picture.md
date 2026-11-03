---
name: event-storming-big-picture
product: [product slug]
version: 1.0.0
phase: design
owner: domain-modeler
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: the flow covered, the pivotal events, the boundary candidates and the top hotspot]
profile: [lean | standard | enterprise]
mode: [agent-run | human session on YYYY-MM-DD with <roles>]
traces-to: [the artifacts read]
---

# Event Storming Big Picture: [Product]

**How this wall was built:** [agent-run from the artifacts in `traces-to`: a hypothesis, N of M cards *assumed* | human session: who attended]

## Timeline

Left to right; pivotal events in **bold**; swimlanes as separate rows where flows run in parallel.

| # | Domain Event | Actor or system | Swimlane | Source |
|---|---|---|---|---|
| 1 | [EventName] | [actor / external system] | [lane] | [artifact path, *assumed*, or session] |

## Pivotal Events

| Event | Why it marks a change of phase |
|---|---|

## Bounded Context Candidates (hints, not decisions)

| Candidate | Spans events | Evidence: pivotal event or swimlane · actor change · word whose meaning shifts |
|---|---|---|

## Hotspots (ranked)

| Rank | ID | Hotspot | Kind (language / rule / risk / scope) | Goes to | Question for the product owner | Assumed meanwhile |
|---|---|---|---|---|---|---|

## Opportunities

| ID | Opportunity | Related hotspot |
|---|---|---|

## Words Found

[Terms and disputed words for `ubiquitous-language`]

## Next

[The processes chosen for Process Modelling, and why, or "lean: none; subdomain classification next"]
