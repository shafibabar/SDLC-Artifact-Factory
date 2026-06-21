# Skill: core/methodology-review

## Purpose
Perform a methodology compliance review on a specified artifact or set of artifacts. Checks conformance to DDD, TDD, BDD, SOLID, and Event-Driven Architecture principles as defined in CLAUDE.md. Produces a structured review report with pass/fail findings.

## Inputs
- `CLAUDE.md` → Non-Negotiable Methodology Rules section
- Target artifact(s) — specified by argument or current phase directory
- `sdlc-manifest.json` → current phase, artifact registry
- **Argument optional:** artifact path (defaults to all current phase artifacts)

## Output
**File:** `artifacts/core/reviews/methodology-{YYYY-MM-DDTHH-MM}.md`
**Registers in manifest:** yes

## Review Checklist

### Domain-Driven Design
- [ ] Bounded Context is declared for every domain artifact
- [ ] All terms are from the ubiquitous language (no undefined jargon)
- [ ] Aggregates enforce invariants — no anemic domain model
- [ ] Domain Events are past-tense, immutable, carry sufficient payload
- [ ] Read Models are separate from Write Models
- [ ] Data ownership is declared — no shared tables between BCs

### Test-Driven Development
- [ ] Implementation artifacts have corresponding TDD specs
- [ ] TDD specs follow Red → Green → Refactor structure
- [ ] Integration tests use real infrastructure (not mocked at boundaries)
- [ ] `pre-implement` hook would not block this artifact

### Behaviour-Driven Development
- [ ] Acceptance criteria are written as testable examples
- [ ] BDD feature files exist for acceptance criteria
- [ ] Example Mapping has been used (examples/ directory has corresponding file)

### SOLID Principles
- [ ] **SRP**: Each class/module has one reason to change
- [ ] **OCP**: New behaviour extends, not modifies
- [ ] **LSP**: Implementations are substitutable
- [ ] **ISP**: Interfaces are focused, not fat
- [ ] **DIP**: High-level modules depend on abstractions

### Event-Driven Architecture
- [ ] Cross-BC communication is via events (no synchronous HTTP for domain ops)
- [ ] Transactional Outbox is specified for atomic event publishing
- [ ] Event handlers are idempotent
- [ ] DLQ is configured for all consumer groups
- [ ] Circuit breakers on external system calls

## Artifact Template

```markdown
# Methodology Review: {target}
**Date:** {date}
**Phase:** {phase}
**Target:** {artifact path or "Phase {N} — all artifacts"}
**Reviewer:** core/methodology-review skill

## Summary
| Category | Status | Findings |
|----------|--------|---------|
| DDD | PASS / FAIL | {N} findings |
| TDD | PASS / WARN | {N} findings |
| BDD | PASS / WARN | {N} findings |
| SOLID | PASS / FAIL | {N} findings |
| EDA | PASS / FAIL | {N} findings |

## Findings

### BLOCKING
{list}

### WARNINGS
{list}

## Overall Result
APPROVED | BLOCKED | CONDITIONAL
```

## Quality Checks
- [ ] All 5 methodology categories are checked
- [ ] Findings include the specific rule violated (not just "DDD violation")
- [ ] APPROVED is only given when all BLOCKING checks pass
