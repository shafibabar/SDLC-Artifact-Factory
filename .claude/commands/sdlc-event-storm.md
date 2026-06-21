# Command: /sdlc-event-storm

## Purpose
Launch an interactive Event Storming session. This command acts as the entry point and session manager for the `event-storming-facilitator` agent. It sets up the session context, validates prerequisites, and hands control to the facilitator agent.

Usage:
```
/sdlc-event-storm [--resume]
```

Options:
- `--resume`: Resume a previously interrupted Event Storming session from the last saved checkpoint

---

## Pre-Flight Checks

### 1. Phase check
- Verify `current_phase` is `design` (Event Storming is a Design phase activity)
- If not: BLOCK with guidance to advance phase first

### 2. Prerequisite artifacts check
The following must exist before Event Storming can begin:

| Artifact | Required? | Why |
|----------|----------|-----|
| `artifacts/strategy/vision.md` | Required | Grounds the domain exploration in the product goal |
| `artifacts/ideate/requirements/functional.md` | Required | Provides the functional scope for the sticky-note exercise |
| `artifacts/ideate/personas/` (at least one) | Required | The Event Storming facilitator needs to know the actors |
| `artifacts/design/domain/context.md` | Recommended | Subdomain classification informs boundary drawing |

If Required artifacts are missing:
```
Cannot start Event Storming — required artifacts are missing:
- artifacts/ideate/requirements/functional.md

Run these skills first:
  /sdlc-artifact ideate/functional-requirements
```

If Recommended artifacts are missing: WARN but allow continuation.

### 3. Resume check
If `--resume` is passed:
- Look for `artifacts/design/event-storm-session.md` (session checkpoint file)
- If found: load checkpoint and continue from last completed part
- If not found: start fresh session

---

## Session Setup

### Create session file
Write `artifacts/design/event-storm-session.md`:

```markdown
# Event Storming Session

**Product:** {product_name}
**Started:** {timestamp}
**Status:** in_progress
**Current part:** Big Picture (Part 1 of 4)

## Session Log
- {timestamp}: Session started
```

### Announce session start

```
=== Event Storming Session: {product_name} ===

This is a multi-part, interactive session. We will move through:

  Part 1 — Big Picture Event Storming
    Goal: Place ALL domain events on the timeline (no filtering)
    Duration: Expect 2–4 conversation turns

  Part 2 — Design-Level Event Storming
    Goal: Add commands, aggregates, policies around each event cluster
    Duration: Expect 3–5 conversation turns

  Part 3 — Bounded Context Mapping
    Goal: Draw boundaries, name contexts, type relationships
    Duration: Expect 1–2 conversation turns

  Part 4 — Artifact Generation
    Goal: Generate all domain model design artifacts from the session output
    Duration: Automated (8 skills run in sequence)

The session can be paused and resumed with /sdlc-event-storm --resume

Ready to begin? Type 'yes' to start Part 1, or 'agenda' to see the full session agenda.
```

---

## Hand-off to Agent

Once the user confirms, invoke the `event-storming-facilitator` agent with:
- Full session context (product_name, problem_statement, personas, functional requirements)
- The session checkpoint file path
- The phase part to start from (1 if fresh, or resume point)

The facilitator agent runs Parts 1–3 interactively, writing to the session file at each checkpoint.

After Part 3 completes, the command re-takes control to run Part 4 (artifact generation) by invoking skills in sequence.

---

## Part 4: Artifact Generation (post-session)

Run these skills in order after the facilitator agent completes Parts 1–3:

```
1. /sdlc-artifact design/domain-context
2. /sdlc-artifact design/event-catalogue
3. /sdlc-artifact design/bounded-context-map
   (for each bounded context identified:)
4. /sdlc-artifact design/ubiquitous-language-bc <bc-name>
   (for each aggregate identified:)
5. /sdlc-artifact design/aggregate-definition <AggregateName>
6. /sdlc-artifact design/command-catalogue
7. /sdlc-artifact design/policy-catalogue
   (for each read model identified:)
8. /sdlc-artifact design/read-model-definition <ReadModelName>
```

After all artifacts are generated:

```
=== Event Storming Complete ===

Generated artifacts:
  ✓ artifacts/design/domain/context.md
  ✓ artifacts/design/domain/events.md
  ✓ artifacts/design/bounded-contexts.md
  ✓ artifacts/design/language/{bc}.md (x{n})
  ✓ artifacts/design/domain/aggregates/{name}.md (x{n})
  ✓ artifacts/design/domain/commands.md
  ✓ artifacts/design/domain/policies.md
  ✓ artifacts/design/domain/read-models/{name}.md (x{n})

Suggested next steps:
  /sdlc-artifact design/system-context-diagram
  /sdlc-artifact design/container-diagram
  /sdlc-artifact design/integration-design
  /sdlc-repo-map (generate multi-repo structure from bounded contexts)
```

---

## Session File Format (checkpoint)

The session file (`artifacts/design/event-storm-session.md`) stores the raw Event Storming output so artifact generation skills can read it:

```markdown
# Event Storming Session

## Part 1 Output: Domain Events (Timeline)

### Events identified (chronological):
1. StorageLocationRegistered
2. CredentialsValidated
3. ScanInitiated
...

## Part 2 Output: Commands, Aggregates, Policies

### Aggregate: StorageLocation
Commands: RegisterStorageLocation, ValidateCredentials, InitiateScan, ...
Hotspots: [credentials validation timing]

## Part 3 Output: Bounded Contexts

### Contexts identified:
1. File Domain (Core) — aggregates: StorageLocation, FileProcessingJob
2. Entity Domain (Core) — aggregates: ExtractedEntity, GoldenRecord
...

### Relationships:
File Domain [OHS+PL / ACL] → Entity Domain
...
```
