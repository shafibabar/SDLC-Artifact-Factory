---
name: bounded-context-mapping
description: >
  Teaches how to define Bounded Contexts, draw their boundaries, and produce
  a Context Map showing the relationships between contexts. Covers the six
  context relationship patterns (Shared Kernel, Customer/Supplier, Conformist,
  Anti-Corruption Layer, Open Host Service, Published Language), how to choose
  the right relationship pattern, and what each pattern implies for service
  design and team ownership. Used by the domain-modeler agent after Event
  Storming, before service decomposition.
version: 1.0.0
phase: design
owner: domain-modeler
tags: [design, ddd, bounded-context, context-map, service-design, architecture]
---

# Bounded Context Mapping

## Purpose

A Bounded Context is an explicit boundary within which a particular Ubiquitous Language applies and a domain model is consistent. Outside that boundary, the same words may mean different things, and the model may look different.

Bounded Context Mapping produces two outputs:
1. **The Bounded Context definitions** — what each context is, what it owns, and where its boundary lies
2. **The Context Map** — how contexts relate to each other, and what relationship pattern governs each connection

The Context Map is the primary input to service decomposition: each Bounded Context is a candidate for one or more deployable services.

---

## Bounded Context Definition

Every Bounded Context must be defined with:

| Attribute | Description |
|---|---|
| **Name** | A name from the Ubiquitous Language — not a technical name ("UserService") but a domain name ("Identity & Access") |
| **Responsibility** | What this context is responsible for — one sentence |
| **Boundary justification** | Why the boundary is here — language change, team ownership, or distinct deployment need |
| **Owned aggregates** | The Aggregates that live inside this context |
| **Owned domain events** | The Domain Events emitted by Aggregates in this context |
| **Incoming dependencies** | Which other contexts this context consumes data or events from |
| **Outgoing dependencies** | Which other contexts depend on this context |
| **Team / ownership** | Who owns this context (important for relationship pattern selection) |

---

## Bounded Context Boundaries

Boundaries are justified by one or more of:

1. **Language change** — the word "File" means something different here than in the adjacent context. The boundary is where the language changes.
2. **Invariant isolation** — the rules governing a concept here are different from the rules in the adjacent context. Different rules → different model → different context.
3. **Team ownership** — different teams own different parts of the domain. Boundaries at team ownership lines prevent coupling across team boundaries.
4. **Deployment independence** — the system must deploy this capability independently from adjacent capabilities. Deployment independence requires a context boundary.
5. **Change rate isolation** — one area changes frequently; another rarely. Boundary prevents churn in one from destabilising the other.

---

## Context Relationship Patterns

Once Bounded Contexts are defined, the relationship between each pair of connected contexts must be named. There are six canonical patterns:

### 1. Shared Kernel

Two teams share a small, explicitly agreed-upon subset of the domain model. Changes to the shared kernel require agreement from both teams.

**When to use:** When two contexts are genuinely tightly coupled and the coupling is intentional and manageable.
**Risk:** The shared kernel becomes a bottleneck. Any change requires coordination. Use sparingly — prefer ACL or OHS instead.

---

### 2. Customer / Supplier

One context (the Customer) depends on another (the Supplier). The Supplier has obligations to the Customer — it should not change its interface without consulting the Customer.

**When to use:** When a clear upstream/downstream dependency exists and the upstream team is willing to negotiate.
**Implementation:** Consumer-Driven Contract tests enforce the Supplier's obligations.

---

### 3. Conformist

One context simply conforms to the model of another context — it does not negotiate. The downstream team accepts the upstream model as-is.

**When to use:** When the upstream team has no incentive to cooperate (e.g., a third-party API or a legacy system with no owner).
**Risk:** The downstream model becomes polluted with concepts that belong to the upstream. Consider ACL if the upstream model is poor.

---

### 4. Anti-Corruption Layer (ACL)

The downstream context isolates itself from the upstream model by building a translation layer — the ACL — that converts the upstream model into the downstream's own Ubiquitous Language.

**When to use:** When the upstream model is significantly different from the downstream model, or when the upstream is a legacy system or third-party API with a poor model.
**Implementation:** A dedicated package/module containing adapters, translators, and mappers. The rest of the downstream context never sees the upstream model directly.
**This plugin's default:** ACL is the default pattern for all third-party integrations (Google Drive API, AWS S3 API, Office 365 API). The upstream vendor models must not leak into the domain model.

---

### 5. Open Host Service (OHS)

One context publishes a well-defined protocol — an API — that any other context can consume. The OHS team is responsible for keeping the protocol stable and backward-compatible.

**When to use:** When many contexts need to integrate with one context. Rather than each pair negotiating privately, the upstream publishes a standard interface.
**Implementation:** OpenAPI specification; versioned; Consumer-Driven Contract tests between the OHS and each consumer.

---

### 6. Published Language (PL)

A shared language (event schema, data model) is published and used by multiple contexts. Often combined with OHS — the OHS publishes using the Published Language.

**When to use:** When event-driven integration is used across many contexts. The event schema is the Published Language.
**Implementation:** JSON Schema or Avro schema registered in a schema registry. All producers and consumers validate against the schema.

---

## Context Map Diagram

The Context Map is expressed as a diagram showing all Bounded Contexts and the relationship pattern between each connected pair.

```
┌─────────────────────┐              ┌──────────────────────────┐
│  Storage            │              │  Classification           │
│  Integration        │──OHS/PL─────▶│  Engine                  │
│  Context            │              │  Context                  │
│                     │              │                          │
│  [Google Drive ACL] │              │  [DataAsset Aggregate]   │
│  [AWS S3 ACL]       │              │  [SensitivityLevel VO]   │
└─────────────────────┘              └──────────────────────────┘
         │                                        │
         │ PL (Domain Events)                     │ PL (Domain Events)
         ▼                                        ▼
┌─────────────────────┐              ┌──────────────────────────┐
│  Compliance         │◀─Customer/───│  Graph                   │
│  Intelligence       │  Supplier    │  Context                 │
│  Context            │              │                          │
│                     │              │  [EntityRelationship]    │
│  [ComplianceGap]    │              │  [KnowledgeGraph]        │
│  [AuditRecord]      │              └──────────────────────────┘
└─────────────────────┘
```

Direction of the arrow = direction of dependency. Upstream is on the left or top; downstream is on the right or bottom.

---

## Selecting the Right Pattern

| Situation | Recommended pattern |
|---|---|
| Integrating with a third-party API (Google Drive, S3) | ACL — always |
| Two internal contexts with negotiating teams | Customer/Supplier with Consumer-Driven Contracts |
| Many consumers of one core context | OHS + PL |
| Legacy system with no maintainable model | ACL |
| Tight coupling between two contexts that must change together | Shared Kernel (last resort) |
| Event-driven integration across contexts | PL (event schemas) |
| Third-party service with no control over changes | Conformist (if model is tolerable) or ACL (if model is poor) |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Named contexts | All contexts have Ubiquitous Language names | Technical names ("UserService", "FileDB") |
| Boundary justification | Every boundary is justified by language change, team ownership, or deployment need | Arbitrary boundaries with no justification |
| All relationships named | Every connection between contexts has a named pattern | Unnamed "depends on" relationships |
| ACL for third-party | All external system integrations use ACL | External API models leaking into domain model |
| Consumer-Driven Contracts | All Customer/Supplier relationships have contract test plans | Verbal agreements only |
| Event schemas as PL | All cross-context events use a Published Language schema | Untyped or undocumented event payloads crossing boundaries |

---

## Output Format

```markdown
---
artifact: context-map
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: domain-modeler
---

# Context Map

## Bounded Contexts

### [Context Name]
| Attribute | Value |
|---|---|
| **Responsibility** | [one sentence] |
| **Boundary justification** | [language change / team / deployment] |
| **Owned Aggregates** | [list] |
| **Owned Domain Events** | [list] |
| **Upstream dependencies** | [contexts this consumes from] |
| **Downstream dependents** | [contexts that consume from this] |

[Repeat for each context]

---

## Context Relationships

| Upstream Context | Downstream Context | Pattern | Implementation |
|---|---|---|---|

---

## Context Map Diagram
[ASCII diagram showing all contexts and their relationships]

---

## Anti-Corruption Layers
| ACL | Upstream | Translates | Implementation location |
|---|---|---|---|

## Published Language Schemas
| Schema | Used by | Format | Registry |
|---|---|---|---|
```
