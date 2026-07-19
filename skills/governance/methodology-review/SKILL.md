---
name: methodology-review
description: >
  Provides the review criteria and compliance checklist for the five non-negotiable
  methodologies: DDD, Event Storming, TDD, BDD, and SOLID. Used by the
  methodology-compliance-check hook and by any agent performing a self-review
  before submitting an artifact for phase gate validation. Defines what constitutes
  a pass, a warning, and a defect for each methodology in each phase.
version: 1.1.0
phase: cross-cutting
owner: factory-governance
created: 2026-06-24
tags: [ddd, tdd, bdd, solid, event-storming, governance, compliance, cross-cutting]
---

# Methodology Review

## Purpose

Every artifact this plugin produces must be reviewed against the five non-negotiable methodologies before it can pass a phase gate. This skill provides the checklist and criteria for that review. It is used by:

- The `methodology-compliance-check` hook (automated, runs on every artifact save)
- Any agent performing a pre-submission self-review
- Shafi when manually reviewing an artifact before approval

A **defect** is a methodology requirement that applies to an artifact but is absent. Defects must be resolved before the phase gate advances.

A **warning** is a methodology consideration that is worth noting but does not block the gate (e.g. a pattern that would be beneficial but is not strictly required for this artifact type).

---

## Domain-Driven Design (DDD)

### Applies to
Design phase artifacts, Implement phase code, any artifact that names or describes a domain concept.

### Required checks

| Check | Pass | Defect |
|---|---|---|
| Ubiquitous Language | All domain terms match the canonical glossary in `skills/governance/glossary-management/` | Any term deviates from the canonical definition without a declared Bounded Context override |
| Bounded Context boundaries | Every service and data model is assigned to exactly one Bounded Context | A service or model spans multiple Bounded Contexts without an Anti-Corruption Layer |
| Aggregate design | Aggregates enforce invariants internally and expose state changes as Domain Events | Business logic leaks outside aggregate boundaries; direct state mutation without events |
| Domain Events | State changes are expressed as immutable, past-tense Domain Events | State changes are expressed as CRUD operations with no corresponding event |
| Context Map | Integration between Bounded Contexts is documented in a Context Map | Two Bounded Contexts integrate without a documented relationship pattern |
| CQRS | Read Models and Write Models are separated in services where query load and command load differ significantly | A single model is used for both commands and queries in a service where separation is indicated |
| Data Ownership | Every data entity has a single owning Bounded Context declared | Multiple contexts write to the same data entity without an ownership declaration |

### Review procedure
1. Identify every domain concept named in the artifact.
2. Check each against `skills/governance/glossary-management/references/ubiquitous-language.md`.
3. Identify every service or component boundary — confirm each maps to a named Bounded Context.
4. Check that state changes produce Domain Events.
5. Confirm the Context Map covers all inter-context relationships referenced.

---

## Event Storming

### Applies to
Design phase — every domain and subdomain must be Event Stormed before architecture decisions are made.

### Required checks

| Check | Pass | Defect |
|---|---|---|
| Event Storm artifact exists | A completed Event Storm board exists for the domain before any architecture document is authored | Architecture or service design artifacts exist with no corresponding Event Storm |
| Domain Events identified | At least one Domain Event per meaningful business state change is identified | State changes have no corresponding Domain Events on the storm board |
| Commands identified | Every Domain Event has a corresponding Command that caused it | Domain Events appear without causal Commands |
| Aggregates identified | Every Command is handled by a named Aggregate | Commands have no owning Aggregate |
| Bounded Context boundaries | Bounded Context boundaries are drawn on the storm board | The storm board has no context boundaries |
| Hotspots documented | Ambiguous areas, conflicts, and open questions are marked as hotspots and tracked | Disagreements or uncertainties were identified but not captured |

### Review procedure
1. Locate the Event Storm artifact for the domain being reviewed.
2. Verify it shows: Domain Events (orange) → Commands (blue) → Aggregates (yellow) → Bounded Context boundaries (dashed lines).
3. Confirm every bounded context in the architecture maps to a boundary drawn on the storm board.
4. Confirm hotspots are tracked as open questions.

---

## Test-Driven Development (TDD)

### Applies to
Every implementation file in the Implement phase. Without exception.

### The TDD Cycle
```
1. Write a failing test (Red)
2. Write the minimum code to make it pass (Green)
3. Refactor without breaking tests (Refactor)
```

### Required checks

| Check | Pass | Defect |
|---|---|---|
| Tests exist before code | Every implementation file has a corresponding test file. The test file's first commit precedes or is concurrent with the implementation file's first commit | Implementation file exists; no corresponding test file |
| Tests are failing-first | Tests were written to fail before the implementation was written | Tests were written after implementation (detectable by commit order and test content) |
| Test naming | Test names describe behaviour, not implementation (`TestProcessPayment_WhenAmountIsZero_ReturnsError` not `TestProcessPaymentCase1`) | Tests have non-descriptive names that do not communicate intent |
| No test-only logic in production code | Production code does not contain `if testing.T()` or equivalent test-only branches | Production code modified specifically to make tests pass without changing real behaviour |
| Table-driven tests (Go) | Tests with multiple input/output cases use Go table-driven test patterns | Multiple near-identical test functions instead of a table |
| Test coverage | All public functions and methods have test coverage. Critical paths have integration test coverage | Public functions with no test coverage |

### Review procedure
1. For every `.go` file in the service, verify a corresponding `_test.go` file exists.
2. Check git log to confirm test file creation precedes or is concurrent with implementation file creation.
3. Run `go test ./...` — all tests must pass.
4. Run `go test -cover ./...` — review coverage report.

---

## Behavior-Driven Development (BDD)

### Applies to
All features with defined acceptance criteria (Ideate and Implement phases). All E2E and Acceptance tests (Quality phase).

### Required checks

| Check | Pass | Defect |
|---|---|---|
| Feature files exist | Every user story or epic with acceptance criteria has a corresponding `.feature` file | User story has acceptance criteria defined in prose with no corresponding feature file |
| Given/When/Then structure | All scenarios use Given (context), When (action), Then (outcome) structure | Scenarios mix context, action, and outcome in a single step |
| Declarative language | Scenarios describe behaviour from the user's perspective, not implementation details | Scenarios describe code-level operations (`When I call the API with parameter X`) |
| Acceptance criteria traceability | Every scenario traces back to a user story or acceptance criterion | Scenarios exist with no corresponding requirement |
| Executable scenarios | All `.feature` files are wired to step definitions and run as part of the CI pipeline | Feature files exist but are not executable (no step definitions) |
| Ubiquitous Language in scenarios | Scenarios use the canonical Ubiquitous Language terms | Scenarios use informal synonyms for canonical domain terms |

### Review procedure
1. For every user story, locate its `.feature` file.
2. Read each scenario — confirm it reads as a plain English description of behaviour.
3. Confirm step definitions exist for all steps.
4. Run `go test -v ./features/...` (godog) — all scenarios must pass.

---

## SOLID

### Applies to
All generated code in the Implement phase. Backend (Go) and Frontend (React+TypeScript).

### Principle definitions and checks

| Principle | Definition | Pass | Defect |
|---|---|---|---|
| **S** — Single Responsibility | A module, class, or function has exactly one reason to change | Each Go struct/function handles one concern; each React component has one responsibility | A handler function validates input, calls the database, sends email, and formats the response |
| **O** — Open/Closed | Open for extension, closed for modification | New behaviour is added by creating new types or functions, not by modifying existing ones | Adding a new payment method requires editing an existing `ProcessPayment` function with a new `if` branch |
| **L** — Liskov Substitution | Subtypes must be substitutable for their base types without altering correctness | Implementations of an interface satisfy the full interface contract | A `ReadOnlyRepository` implementation panics when `Save()` is called, violating the `Repository` interface contract |
| **I** — Interface Segregation | Clients should not depend on interfaces they do not use | Interfaces are small and focused; a type is not forced to implement methods it does not need | A single `UserService` interface has 20 methods; most consumers only need 2 |
| **D** — Dependency Inversion | High-level modules should not depend on low-level modules; both should depend on abstractions | Service layer depends on repository interfaces, not concrete pgx implementations | `OrderService` directly instantiates `PostgresOrderRepository` with `pgx.Connect()` |

### Review procedure (Go)
1. Check that every exported function accepts interfaces, not concrete types.
2. Check that each struct has one clearly named responsibility.
3. Check that interfaces in `internal/` are defined in the consuming package, not the providing package.
4. Check that dependency injection is used at the service layer — no `new()` or constructor calls inside business logic.
5. Check that new behaviour is added via new types, not by modifying existing switch statements or if-else chains.

### Review procedure (React + TypeScript)
1. Check that each component renders one concept.
2. Check that data fetching, business logic, and presentation are in separate hooks/utilities/components.
3. Check that components depend on props interfaces, not concrete service implementations.
4. Check that new feature behaviour is added through new components or hooks, not by expanding existing ones.

---

## Applying This Skill

When an artifact is submitted for phase gate validation:

1. Determine which methodologies apply to this artifact type (see Applies to sections above).
2. Run each applicable checklist.
3. Record every defect found with: artifact name, methodology, violated check, remediation required.
4. If zero defects: artifact passes methodology review.
5. If one or more defects: artifact fails. Return defects to the producing agent for remediation before re-submission.
6. Warnings are recorded in the artifact's frontmatter but do not block the gate.

See `references/review-report-template.md` for the standard output format of a methodology review result.
