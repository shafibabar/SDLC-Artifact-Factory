# Test Strategy Template

> **Self-contained reference.** This file is loadable independently of `skills/test-pyramid/SKILL.md`. It provides the complete fill-in template for a product's test strategy document — produced by the test-strategist at the start of the Implement phase and updated through Quality.

---

## How to Fill This Template

<!-- Section briefs live here — full content delivered in the next sub-issue (#428) -->

### Pyramid Targets table
Document the agreed proportions and tooling for each layer. The percentages are a guide for the suite's shape — if e2e tests outnumber unit tests, the pyramid is inverted.

### Shift-Left Plan
One row per service or bounded context. Name the TDD/BDD disciplines, unit-test scope, contract boundaries, and mutation schedule.

### Shift-Right Plan
Name the full-stack journeys, performance gates (p99 latency, SLO), load targets, and chaos experiments.

### Coverage and Flaky Policy
State the Branch Coverage gate, mutation cadence, quarantine process, and retry policy.

### Delegated Testing
Confirm which layers belong to security-engineer and platform-engineer, with the skill they use.

---

## Template

<!-- Full copyable template — delivered in content sub-issue #428 -->
