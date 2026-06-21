# Hook: adr-conflict-detector

## Trigger
Fires when:
- A new ADR is created via `/sdlc-adr` or `sdlc-artifact design/adr`
- A design artifact is created in `artifacts/design/architecture/` or `artifacts/design/domain/`
- The user runs `/sdlc-review` and the current phase is Design or later

## Purpose
Detect conflicts between a newly created artifact (or ADR) and existing Accepted ADRs. Prevent silent contradictions — where a design artifact makes a different architectural decision from one that is already recorded as Accepted.

## Execution

### Step 1: Load all Accepted ADRs

```
Read: artifacts/design/adrs/INDEX.md
Filter: status = "Accepted" or status = "Superseded"
Load: all ADR files listed in the index
Extract per ADR:
  - Decision statement (the "Decision" section)
  - Technologies/patterns mandated or prohibited
  - ADR number and title
```

### Step 2: Build conflict detection rules from ADRs

Convert each ADR decision into a machine-checkable rule. Examples:

| ADR | Decision | Derived rule |
|-----|---------|-------------|
| ADR-001: Use PostgreSQL for ACID store | "We will use PostgreSQL with pgx for all write models." | Flag any design artifact that specifies MySQL, SQLite, or a non-PostgreSQL RDBMS |
| ADR-003: Use Redpanda for messaging | "We will use Redpanda (Kafka-API) as the message broker." | Flag any artifact that specifies RabbitMQ, SQS, or a non-Kafka-API broker |
| ADR-007: Hexagonal Architecture | "Domain layer must have zero infrastructure imports." | Flag any code artifact where domain/ imports pgx, net/http, or messaging packages |

### Step 3: Scan the new artifact against derived rules

For each derived rule:
- Search the new artifact for terms, technology names, or patterns that contradict the ADR decision
- Use case-insensitive text matching for technology names
- For architecture rules: check import statements and package references

### Step 4: Classify conflicts

```
CONFLICT (blocking): The artifact makes a decision that directly contradicts an Accepted ADR
  → Example: A design artifact specifies MySQL for a write model (contradicts ADR-001)
  
POTENTIAL CONFLICT (warning): The artifact uses terminology or patterns that could contradict an ADR,
  but the conflict is ambiguous
  → Example: The artifact mentions "message queue" without specifying the technology
  
NEW DECISION (info): The artifact introduces an architectural decision not covered by any existing ADR
  → Recommend: Create a new ADR for this decision before the artifact is finalised
```

### Step 5: Output

```
ADR Conflict Detection — {artifact path}
────────────────────────────────────────────────────────────────

{If CONFLICTS:}
CONFLICTS DETECTED (ADR violations — must resolve before phase advance):

  CONFLICT: Artifact specifies MySQL as the persistence store
  Contradicts: ADR-001 — Use PostgreSQL for ACID Store (Status: Accepted)
  Resolution options:
    a) Update the artifact to use PostgreSQL + pgx
    b) Supersede ADR-001 with a new ADR that changes the decision (run: /sdlc-adr --supersede 001)

{If POTENTIAL CONFLICTS:}
POTENTIAL CONFLICTS (review and resolve):

  POTENTIAL: Artifact references "message queue" without specifying technology
  Related ADR: ADR-003 — Use Redpanda for Messaging
  Action: Confirm whether this refers to Redpanda (acceptable) or a different broker (conflict)

{If NEW DECISIONS:}
ARCHITECTURAL DECISIONS WITHOUT ADRs:

  DECISION CANDIDATE: Artifact specifies GraphQL for the API layer
  No ADR covers API protocol choice.
  Recommendation: Create an ADR before this decision is finalised.
  Run: /sdlc-adr to create a new ADR.

────────────────────────────────────────────────────────────────
{If clean:} No ADR conflicts detected. Artifact is consistent with all Accepted ADRs.
```

### Step 6: Record in manifest

```json
{
  "adr_conflict_scans": [
    {
      "artifact": "{path}",
      "scanned_at": "{ISO 8601}",
      "conflicts": {N},
      "potential_conflicts": {N},
      "new_decision_candidates": {N}
    }
  ]
}
```
