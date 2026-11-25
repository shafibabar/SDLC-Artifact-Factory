# Layers, Risk and Case Derivation

Self-contained. Use when deciding which layer proves a behaviour, how deep to test a capability, or how to derive its cases.

## Contents
Placing a behaviour; risk rating; deriving cases; quadrants; vocabulary.

## Placing a behaviour

Test a behaviour at the lowest layer that can prove it.

| Behaviour | Layer | Why not higher or lower |
|---|---|---|
| A domain invariant or validation rule | Unit | Needs no dependency; assert the observable result, not private state |
| A repository query, a migration, optimistic concurrency | Integration | Only the real database can prove it |
| Two services, or a shell and a remote, agree on a shape | Contract | Runs in each side's own pipeline with no live counterpart (Cruz and Prescott) |
| Repeat-request safety, rate limit, deprecation header, each documented error branch | Integration, in the language's integration test skill | A schema check proves shape, not that the behaviour happens (Winteringham) |
| One critical journey from the user's screen to the stored result | End-to-end | Everything below cannot prove the wiring |
| Speed of changed code | Performance | Compare old and new code in the same job |
| A stated latency or throughput target under demand | Load | Needs an NFR or SLO ID |
| A retry, circuit breaker or dead letter queue under failure | Chaos | Write the steady-state hypothesis first |
| Business signal after a release | Production check (semantic monitoring, Newman) | An addition to testing, never a replacement |

Test code by shape (Khorikov): domain logic gets most unit tests; thin controllers get integration tests; code that is both complex and full of collaborators is split so the logic becomes plainly testable (Humble Object). The 100% gate still applies to all of it; a thin wrapper can be covered by integration tests that run in the coverage run.

Mock only dependencies whose effect others can observe (a published message, a sent email, a third-party call). The product's own database is verified by its end state, never by counting calls.

## Risk rating

Rate each capability, endpoint and boundary: impact if it breaks (H/M/L) and likelihood of failure (H/M/L), with whoever knows the domain.

| Rating | Extra depth beyond the standing gates |
|---|---|
| Any H with H or M | Decision table or boundary sets, path coverage of the rule, a workflow test (create, read back, change, read), an exploratory charter handed to `uat-plan` |
| Mixed M | Boundary and equivalence classes, error branches |
| L with L | The standing gates only |

A rating never removes a layer or lowers the coverage or mutation rule.

## Deriving cases (Jorgensen)

- Ranges and ordered values: boundary values (min, just above, nominal, just below max, max) plus invalid neighbours.
- Categories: one case per valid and invalid class; combine classes only where they interact.
- Three or more interacting conditions: a decision table first, checked for missing and contradictory rules.
- Lifecycles: cover each transition, then short sequences of transitions.
- Path coverage costs combinatorially: reserve it for the highest-risk rules.

## Quadrants (Crispin and Gregory)

| Quadrant | Examples | Owner |
|---|---|---|
| Supports the team, technology-facing | Unit, component | engineers, under test-strategist standards |
| Supports the team, business-facing | Gherkin scenarios | test-strategist (`bdd-feature-file`) |
| Critiques the product, business-facing | Exploration, user acceptance | requirements-analyst (`uat-plan`) |
| Critiques the product, technology-facing | Performance, load, chaos | test-strategist |

## Vocabulary (Quigley)

A human error causes a fault in an artifact; an executed fault may cause a failure. A smoke test is shallow and broad (is the build usable); a sanity check is narrow and deep (does this change work). Regression testing is named by its purpose, so any layer can serve it. Statement coverage is weaker than branch coverage, which is weaker than path coverage.
