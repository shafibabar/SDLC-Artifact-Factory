---
name: context-map-patterns
description: >
  Deep reference for the nine Context Map relationship patterns from Domain-Driven
  Design — covering when to apply each pattern, the team dynamics each implies,
  the implementation mechanism (ACL, OHS, Shared Kernel, etc.), the Consumer-Driven
  Contract test requirement, and the downstream risk of each pattern choice.
  Companion skill to bounded-context-mapping; used when the domain-modeler or
  enterprise-architect needs to reason through relationship pattern selection in
  detail.
version: 1.0.0
phase: design
owner: domain-modeler
tags: [design, ddd, context-map, bounded-context, acl, ohs, shared-kernel, contracts]
---

# Context Map Patterns

## Purpose

This skill is a deep reference for Context Map relationship patterns. Where `bounded-context-mapping` teaches how to draw the Context Map and select a pattern, this skill teaches the mechanics, trade-offs, and implementation implications of each pattern in detail.

Use this skill when:
- The domain-modeler needs to explain the rationale for a pattern selection
- The enterprise-architect is evaluating the service integration strategy
- A Consumer-Driven Contract requirement needs to be designed
- A new context relationship is being added to an existing system

---

## The Nine Patterns

### 1. Partnership

**What it is:** Two teams commit to succeed or fail together. They synchronise their planning and release cycles. Each team has veto power over the other's interface changes.

**Team dynamic:** Requires high trust and continuous communication. Cannot be forced — both teams must agree.

**When to use:** Two bounded contexts are so closely aligned in purpose that independent release is impossible for a period. Treat as temporary — work toward Customer/Supplier as the relationship matures.

**Risk:** High coordination cost. If the teams drift, the partnership degrades into implicit coupling without the governance of Shared Kernel.

**Implementation:** Shared planning meetings; unified release gates; joint architecture review for changes to shared interfaces.

---

### 2. Shared Kernel

**What it is:** Two Bounded Contexts share a small, explicitly agreed-upon subset of the domain model. The shared code is owned jointly and changes require agreement from both teams.

**Team dynamic:** Requires disciplined governance. Any change to the Shared Kernel must be negotiated, tested in both contexts, and released coordinately.

**When to use:** Two contexts genuinely share immutable concepts — canonical IDs, cross-cutting reference data, or published language schemas. Keep the shared kernel as small as possible.

**Risk:** The kernel grows. Every team wants to add to it; no team wants to remove from it. A Shared Kernel that grows becomes a bottleneck that slows both teams.

**Implementation:** A dedicated shared library or package. Both teams are owners. Changes require a PR approved by both teams. Consumer-Driven Contracts test the shared code from both directions.

---

### 3. Customer / Supplier

**What it is:** A clear upstream (Supplier) / downstream (Customer) dependency. The Supplier has obligations to the Customer — it must not make breaking changes without consulting the Customer, and it should prioritise the Customer's needs in its roadmap.

**Team dynamic:** The Supplier has power over the Customer. The risk is that the Supplier deprioritises the Customer's needs. Consumer-Driven Contracts are the mechanism that gives the Customer power — the Supplier cannot break the contract without breaking the Customer's tests.

**When to use:** Most internal upstream/downstream relationships should be Customer/Supplier. It is the most common pattern for well-governed microservices.

**Risk:** If the Supplier team does not honour the obligation, the relationship degrades to Conformist. Consumer-Driven Contracts prevent this.

**Implementation:** Consumer-Driven Contracts (Pact or equivalent). The Customer writes the contract tests; the Supplier runs them in CI. A failing contract test blocks the Supplier's deployment.

---

### 4. Conformist

**What it is:** The downstream context simply conforms to the upstream model. The upstream team has no obligation to the downstream and no incentive to negotiate.

**Team dynamic:** The upstream team is indifferent to the downstream's needs. This is the team dynamic when integrating with a large external vendor, a legacy system with no owner, or an internal team with much higher power.

**When to use:** When the upstream cannot be negotiated with. Accept the upstream model as-is. Do not fight it.

**Risk:** The upstream model leaks into the downstream domain model, polluting it with concepts that don't belong. The downstream becomes dependent on the upstream's quirks.

**Mitigation:** If the upstream model is poor or significantly different from the downstream's needs, escalate to ACL instead of Conformist. Conformist is acceptable only if the upstream model is reasonable and relatively stable.

**Implementation:** No special mechanism — the downstream simply uses the upstream's types and models directly. Document the dependency and the upstream's release cycle.

---

### 5. Anti-Corruption Layer (ACL)

**What it is:** The downstream context builds a translation layer that converts the upstream model into the downstream's own Ubiquitous Language. The ACL is the boundary — nothing inside the downstream context ever sees the upstream model directly.

**Team dynamic:** The downstream team is taking full control of its own model, regardless of the upstream's model quality or stability.

**When to use:**
- Integrating with third-party APIs (Google Drive, AWS S3, Office 365) — **always**
- Integrating with a legacy system with a poor or poorly-documented model
- When the upstream model is significantly different from the downstream's Ubiquitous Language
- When the upstream is expected to change frequently and the downstream must be insulated

**Risk:** The ACL must be maintained as the upstream changes. It is an investment — but the alternative (model pollution) is more expensive.

**Implementation:**
```
External API → ACL Package
                ├── adapters/     (HTTP client wrappers — call the external API)
                ├── translators/  (map upstream types to downstream types)
                └── ports/        (interface definitions the domain uses)
```

The domain never imports from `adapters/`. It imports only from `ports/`. The `translators/` convert in both directions.

---

### 6. Open Host Service (OHS)

**What it is:** The upstream context defines a well-documented, versioned protocol that any downstream context can use. The protocol is the contract — not the implementation.

**Team dynamic:** The upstream team takes on responsibility for a public API. This requires API versioning discipline, backward compatibility commitments, and change communication.

**When to use:** When one context must serve many downstream consumers. Rather than negotiating privately with each Consumer, publish a standard protocol.

**Risk:** The OHS becomes a lowest-common-denominator API that serves no consumer well because it tries to serve all. Design for the ICP consumer first; extend carefully.

**Implementation:** OpenAPI specification (versioned). Consumer-Driven Contracts for each known consumer. Breaking changes require a major version bump; all versions are supported for a defined sunset period.

---

### 7. Published Language (PL)

**What it is:** A well-documented, versioned shared language (event schemas, canonical data models) that multiple contexts use to communicate. Often used with OHS: the OHS publishes using the Published Language.

**Team dynamic:** Similar to Shared Kernel but for communication formats rather than shared code. Requires a schema registry and governance process for schema evolution.

**When to use:** Event-driven integration across Bounded Contexts. The event schema is the Published Language.

**Risk:** Schema evolution is hard to coordinate across many consumers. Additive changes are safe; breaking changes require coordinated migration.

**Implementation:**
- JSON Schema or Avro schemas registered in a schema registry
- All producers validate outgoing events against the schema
- All consumers validate incoming events against the schema
- Schema changes require a PR approved by the schema owner
- Breaking changes: run both schema versions simultaneously during migration

---

### 8. Separate Ways

**What it is:** Two contexts have no integration. They operate completely independently.

**When to use:** When the cost of integration exceeds the value. Two subdomains that have nothing to share should not be forced to integrate.

**Risk:** If the separation is wrong — if the contexts actually do share data or need to coordinate — the separation creates duplication and inconsistency. Validate the decision to separate with Event Storming before committing.

**Implementation:** No code shared. No events exchanged. No shared database tables. Complete independence.

---

### 9. Big Ball of Mud

**What it is:** Not a design pattern — a recognition that an existing system has no clear boundaries, no defined interfaces, and ad-hoc integration everywhere. Named in the Context Map to document reality.

**When to use:** When documenting a legacy system or an existing service that has accumulated coupling over time. Naming it "Big Ball of Mud" on the Context Map is an honest assessment — it does not pretend a boundary exists where there isn't one.

**Next step:** Plan migration toward defined boundaries (ACL or OHS as the entry point into the legacy system). Never design new services to directly integrate with a Big Ball of Mud — always introduce an ACL.

---

## Pattern Selection Guide

| Situation | Pattern |
|---|---|
| Third-party API or external service | ACL (always) |
| Legacy system with poor model | ACL |
| Many consumers of one service | OHS + PL |
| Two internal teams, negotiating | Customer/Supplier + Consumer-Driven Contracts |
| Non-cooperative upstream | Conformist (if model OK) or ACL (if model is poor) |
| Event-driven integration | PL (event schemas) |
| Two tightly coupled contexts, same team | Shared Kernel (small) or Partnership (temporary) |
| No real dependency | Separate Ways |
| Existing legacy without boundaries | Big Ball of Mud (documented); plan ACL migration |

---

## Consumer-Driven Contract Tests

Consumer-Driven Contracts are the enforcement mechanism for Customer/Supplier relationships. The Consumer writes the contract (what it expects from the Supplier); the Supplier runs the contract tests in CI.

Every Customer/Supplier relationship in the Context Map must have:
1. A named contract owner (the Consumer team / context)
2. A contract test suite (Pact or HTTP-level tests)
3. A CI gate: Supplier's deployment pipeline fails if any Consumer's contract test fails
4. A process for the Consumer to update the contract when its needs change

Without Consumer-Driven Contracts, a Customer/Supplier relationship is a verbal agreement — it will be violated.

---

## Output Format

This skill produces reference content used in `bounded-context-mapping`. Its direct output is the Pattern Selection Rationale section of the Context Map artifact:

```markdown
## Pattern Selection Rationale

| Relationship | Pattern selected | Rationale | Consumer-Driven Contracts required? |
|---|---|---|---|
| [Context A] → [Context B] | [Pattern] | [Why this pattern and not others] | [Yes / No] |
```
