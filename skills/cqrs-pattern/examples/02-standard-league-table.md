# Example 2 — Standard: One Projected View on a Named Trigger

Self-contained. **Courtside** runs amateur basketball leagues for a regional association: 60 clubs, 400 teams, results entered by referees from courtside tablets. **Standard** profile, three services: **Fixtures** (scheduling), **Results** (scores and standings) and **Membership** (players and clubs).

## Input

> **User:** "Make every context Full CQRS with projections; it's our core product. And for the player profile page, just read the Membership and Results tables directly from the profile service, it's simpler than calling two APIs."

## Working it

- **Fixtures:** the screens are the fixture list and a club's calendar, each one query over the fixtures table. No trigger: Simple Read Model.
- **Membership:** registration screens read one or two tables. No trigger: Simple Read Model. "It's core" is not a trigger.
- **Results:** the public league table is the problem. On match evenings it is read about 150 times a second (the NFR's peak) while referees enter about one result a minute. Each read aggregates every result of the season for the division, so computing it per request slows referees' result entry, which shares the tables. That is a trigger with evidence: **projections** for the standings view. The referee's result-entry screens stay on simple queries.
- **Staleness:** fans accept a standings table a minute behind; the referee who entered the score must see it counted, so the Command returns the version and the referee's view shows the result as *counting* until the standings view has applied it.
- **Player profile across services:** reading Membership's and Results' tables from the profile service is declined. It couples three services' schemas, and Results' rules about which games count would be bypassed. API Composition: the profile service calls both APIs; two small calls per view, which is cheap.
- **Revisit when:** the profile page needs season-by-season history for every player at match-evening load, which would make composition too wide.

## Output: `design/architecture/cqrs-decisions.md` (excerpt)

```markdown
---
name: cqrs-design
product: courtside
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-04-02
summary: Results projects the league standings on a match-evening load trigger; Fixtures and Membership use a Simple Read Model; profiles use API Composition.
profile: standard
traces-to: [design/results/aggregates.md, design/results/domain-event-catalog.md, ideate/nfr-specification.md, design/architecture/container-diagram.md]
---

# CQRS Decisions: Courtside

## Contexts

| Bounded Context | Read side | Trigger | Staleness accepted |
|---|---|---|---|
| Fixtures | simple read model | none — rung 1 | immediate |
| Membership | simple read model | none — rung 1 | immediate |
| Results | projections | league table at match-evening load | 1 minute |

## Context: Fixtures

| Field | Value |
|---|---|
| **Read side** | simple read model |
| **Business-logic pattern** | Domain Model |
| **Event sourced** | no |
| **Trigger** | none — a Simple Read Model serves every query |
| **Staleness accepted** | immediate |
| **Read-your-writes** | immediate (same tables) |
| **Replicas or regions** | one copy |
| **Revisit when** | a screen needs fixtures combined with results at match-evening load |

### Queries

| Query (screen or question) | Served by | Why |
|---|---|---|
| Fixture list for a division | simple read model | one query over the fixtures table |
| A club's calendar | simple read model | one query, filtered by club |

## Context: Membership

| Field | Value |
|---|---|
| **Read side** | simple read model |
| **Business-logic pattern** | Active Record |
| **Event sourced** | no |
| **Trigger** | none — a Simple Read Model serves every query |
| **Staleness accepted** | immediate |
| **Read-your-writes** | immediate (same tables) |
| **Replicas or regions** | one copy |
| **Revisit when** | registration week load slows the registration screens |

### Queries

| Query (screen or question) | Served by | Why |
|---|---|---|
| A club's registered players | simple read model | one join |

## Context: Results

| Field | Value |
|---|---|
| **Read side** | projections |
| **Business-logic pattern** | Domain Model |
| **Event sourced** | no |
| **Trigger** | league table: about 150 reads per second at match-evening peak (NFR-07) against about one result a minute; each read aggregates the division's whole season, slowing referees' result entry on the shared tables |
| **Staleness accepted** | 1 minute — fans check the table after the evening, nobody acts on it within seconds |
| **Read-your-writes** | the RecordResult Command returns the version; the referee's view shows the result as counting until the standings view has applied it |
| **Replicas or regions** | one copy |
| **Revisit when** | a second standings shape (per club, per player) is needed, or the projector falls behind at peak |

### Queries

| Query (screen or question) | Served by | Why |
|---|---|---|
| League table for a division | projection: DivisionStandings | the trigger |
| Results entered by this referee tonight | simple read model | the referee needs them at once |

## Cross-service queries

| Query | Services | Approach | Trigger | Owner of the view |
|---|---|---|---|---|
| Player profile (club, games played, points) | Membership, Results | API Composition | none — composition | — |

## Open questions

- Should a disputed result be shown in the table before the association confirms it? (product owner)
```

## Why this is right

- Only Results went up a rung, on evidence from the NFRs and the screens; "it's core" was declined with its reason.
- The referee sees their own result counted; fans accept a minute's lag.
- The cross-service profile uses composition instead of reading another service's tables.
- `validate-cqrs-decisions.sh` exits clean on the excerpt.
