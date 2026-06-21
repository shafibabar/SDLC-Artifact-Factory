# Command: /sdlc-adr

## Purpose
Interactive Architecture Decision Record creator. Guides the user through the ADR template with prompts, auto-numbers the ADR, writes the file, and adds it to the ADR index. Makes capturing architectural decisions fast enough that engineers actually do it.

Usage:
```
/sdlc-adr <decision-slug>
/sdlc-adr --list
/sdlc-adr --supersede <ADR-NNN>
```

Examples:
```
/sdlc-adr use-redpanda-over-kafka
/sdlc-adr physical-multi-tenancy-model
/sdlc-adr postgresql-as-primary-write-store
/sdlc-adr --list
/sdlc-adr --supersede ADR-003
```

---

## Pre-Flight Checks

### 1. Phase check
- ADRs can be created in any phase (design or later)
- WARN if in strategy/ideate phase: "ADRs are typically created during the design phase. Are you sure you want to create one now?"

### 2. ADR index check
- Read or initialise `artifacts/design/adrs/INDEX.md`
- Determine next ADR number (count existing ADRs + 1; format as three digits: `001`, `002`)

---

## Interactive Flow

### Mode 1: Standard ADR (`/sdlc-adr <slug>`)

The command presents a guided form:

```
=== Creating ADR: {slug} ===
ADR Number: {auto-assigned NNN}
File: artifacts/design/adrs/ADR-{NNN}-{slug}.md

Answer each prompt. Press Enter to skip optional fields.

[1/6] What is the decision in one sentence?
      (e.g. "We will use Redpanda as our event streaming backbone instead of Apache Kafka")
> _

[2/6] What context or situation requires this decision?
      (Describe the problem, constraints, and why a decision is needed now)
> _

[3/6] What are the key decision drivers?
      (Enter one per line, blank line to finish)
> _

[4/6] What options were considered? (comma-separated names)
      (e.g. "Redpanda, Apache Kafka, RabbitMQ")
> _

For each option above, you'll be asked for pros and cons.

[5/6] Which option was chosen?
> _

[6/6] What are the consequences? (positive and negative)
      (Enter positives, then negatives)
> _
```

After all prompts are answered, the command generates the full ADR using the `design/adr` skill template, fills in all fields, and shows a preview before writing.

Preview confirmation:
```
=== Preview ===
[full ADR text shown here]

Write this ADR? (yes / edit / cancel)
> _
```

### Mode 2: List ADRs (`/sdlc-adr --list`)

Display the INDEX.md in a readable format:

```
=== ADR Index ===

  ADR-001  Use Redpanda over Apache Kafka         [Accepted]  2026-01-15  Platform-wide
  ADR-002  Physical multi-tenancy model           [Accepted]  2026-01-16  Platform-wide
  ADR-003  PostgreSQL as primary write store      [Accepted]  2026-01-17  All services
  ADR-004  Apache AGE for graph storage           [Proposed]  2026-01-18  Entity, Graph

4 ADRs total. 3 accepted, 1 proposed.

Run /sdlc-adr <slug> to add a new ADR.
```

### Mode 3: Supersede (`/sdlc-adr --supersede ADR-NNN`)

Guide user through creating a new ADR that supersedes an existing one:
1. Read the existing ADR to understand the context
2. Prompt for the new decision (what changed and why)
3. Write the new ADR with `Status: Accepted` and `Supersedes: ADR-{NNN}`
4. Update the original ADR's status to `Superseded by ADR-{new-NNN}`

---

## File Generation

### ADR file
Written to: `artifacts/design/adrs/ADR-{NNN}-{slug}.md`

Uses the template from `design/adr` skill with all fields populated from the interactive session.

### ADR index update
Append to `artifacts/design/adrs/INDEX.md`:

```markdown
| ADR-{NNN} | {Title} | {Status} | {date} | {Affected contexts} |
```

If INDEX.md does not exist, create it with header:
```markdown
# ADR Index

| ADR | Title | Status | Date | Affected |
|-----|-------|--------|------|---------|
```

### Manifest registration
Register `artifacts/design/adrs/ADR-{NNN}-{slug}.md` with the design phase artifacts list.

---

## Completion Output

```
=== ADR Created ===

ADR-{NNN}: {Title}
Status: Proposed
File: artifacts/design/adrs/ADR-{NNN}-{slug}.md
Index updated: artifacts/design/adrs/INDEX.md

Next steps:
  - Share ADR with team for review
  - Update status to 'Accepted' or 'Rejected' once decided
  - If accepted, check for follow-on ADRs mentioned in the 'Follow-on decisions required' section
```

---

## ADR Status Lifecycle

| Status | Meaning | How set |
|--------|---------|--------|
| `Proposed` | Written; not yet decided | Default on creation |
| `Accepted` | Decision made and approved | Manual update or `/sdlc-adr --accept ADR-NNN` |
| `Rejected` | Considered and rejected | Manual update or `/sdlc-adr --reject ADR-NNN` |
| `Superseded by ADR-{NNN}` | Replaced by a newer decision | `/sdlc-adr --supersede ADR-NNN` |
| `Deprecated` | No longer relevant; not superseded | Manual update |

ADRs are NEVER deleted — only their status changes. Deleted ADRs leave a gap in the numbering that is confusing and unacceptable.
