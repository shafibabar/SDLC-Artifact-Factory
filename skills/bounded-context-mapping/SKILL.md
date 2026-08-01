---
name: bounded-context-mapping
description: >
  Teaches the domain-modeler to discover, define, and document Bounded Contexts — the explicit
  boundaries within which a Ubiquitous Language is consistent and a model applies without
  ambiguity. Covers the BC discovery procedure (linguistic fracture lines, team ownership, data
  ownership, deployment independence), the BC definition artifact, the Context Map as the
  system-level view of BC relationships, and how BC boundaries drive service decomposition
  decisions in this platform. Used during Design whenever a new domain is modeled or an existing
  boundary is challenged.
version: 2.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: ["design","domain-modeling","bounded-context","context-map","ddd","subdomain","team-topology"]
produces: context-map
domain: domain-modeling
status: stable
related: [context-map-patterns, subdomain-distillation, aggregate-design, event-storming-facilitation, glossary-management]
---

# Bounded Context Mapping

## What Is a Bounded Context

A Bounded Context (Evans, *Domain-Driven Design*, Ch. 14–15) is the explicit boundary within
which a single Ubiquitous Language applies and a domain model is internally consistent. Inside
the boundary, every term has one meaning and one model shape. Outside the boundary, the same
term may carry a different meaning — that linguistic fracture is where one Bounded Context ends
and another begins.

**Key principle: one model per Bounded Context; no model leaks across boundaries.** A concept
that crosses a boundary must be explicitly translated — by an Anti-Corruption Layer, an Open
Host Service, or another named Context Map pattern.

Khononov (*Learning DDD*) adds precision: a Bounded Context boundary is driven by *linguistic
and model-consistency* forces — where the Ubiquitous Language changes meaning. This is distinct
from the transactional-consistency force that drives Aggregate boundaries (a finer granularity
inside the same context) and from the deployment-independence force that shapes service
boundaries (which usually, but need not exactly, align with Bounded Context boundaries).

---

## Discovery Signals

A Bounded Context boundary is justified by one or more of these four signals:

1. **Linguistic fracture line** — the same word means something different in this area than in
   the adjacent area. The boundary is where the language changes. This is the primary signal;
   all others are secondary confirmations.
2. **Team ownership** — different teams own different capabilities. Drawing boundaries at
   team-ownership lines prevents coupling across team boundaries and reflects Conway's Law.
3. **Data ownership** — only the owning context may write to its master record; other contexts
   consume events or Read Models. Where data ownership changes, a context boundary likely exists.
4. **Deployment independence** — this capability must be deployed, scaled, and versioned
   independently of adjacent capabilities. A deployment independence requirement is a service-
   boundary signal that usually aligns with a Bounded Context boundary.

Full facilitation procedure — including the linguistic-fracture-line technique step-by-step, the
data-ownership exercise, and the "one BC or two?" decision tree — is in
`references/bc-discovery-guide.md`.

---

## BC Definition Artifact

Every discovered Bounded Context must be documented with five required fields before any
service-decomposition decision is made:

| Field | What it captures |
|---|---|
| **Name** | A name from the Ubiquitous Language — a domain noun, not a technical name ("DataAsset Management", not "AssetService") |
| **Ubiquitous Language excerpt** | 5–10 key terms that have specific, bounded meanings inside this context — terms that would mean something different in an adjacent context |
| **Owned Aggregates** | The Aggregate Roots that live inside this context and whose invariants this context enforces |
| **Owned Domain Events** | The Domain Events this context emits — the facts it publishes for other contexts to consume |
| **Team / service owner** | Who owns this context and which deployable service embodies it in this platform |

Full fill-in template and worked example (DataAsset Management BC with its Ubiquitous Language
terms, Aggregates, and events) in `references/bc-definition-artifact.md`.

---

## Context Map

The Context Map is the system-level view of all Bounded Contexts and the relationship pattern
governing each connection between them. Draw it after BCs are defined and before
service-decomposition decisions are finalised.

The Context Map captures for each connection: which contexts are involved, which is upstream and
which is downstream, and the single named relationship pattern that governs that connection.

**Relationship patterns — select exactly one per connection:**

| Pattern | When to use |
|---|---|
| **Anti-Corruption Layer (ACL)** | Downstream protects itself from an upstream model it does not control. **Default for all external integrations in this platform** (Google Drive, AWS S3, Office 365). |
| **Open Host Service (OHS)** | Upstream publishes a stable, versioned API consumed by many downstreams |
| **Published Language (PL)** | Shared event or schema format crossing context boundaries; usually combined with OHS |
| **Customer / Supplier** | Upstream has obligations to one specific downstream; Consumer-Driven Contracts enforce the agreement |
| **Conformist** | Downstream adopts the upstream model as-is — only when that model is genuinely good enough to adopt without distortion |
| **Shared Kernel** | Two contexts share a small, explicitly agreed-upon model subset — high coordination cost, use sparingly |
| **Partnership** | Two contexts succeed or fail together; plan all changes jointly |
| **Separate Ways** | Contexts deliberately do not integrate — record the absence to make it explicit on the map |
| **Big Ball of Mud** | A legacy region with no coherent model — draw a boundary around it, protect everything else with an ACL |

Full diagram conventions, notation for each pattern, and worked multi-BC example (DataAsset
Management + Compliance Intelligence + Reporting) in `references/context-map-template.md`.

---

## Pattern Selection

| Situation | Recommended pattern |
|---|---|
| Third-party API (Google Drive, AWS S3) | ACL — always |
| Two internal contexts, both teams willing to negotiate | Customer/Supplier + Consumer-Driven Contracts |
| Many consumers of one context | OHS + PL |
| Legacy system with no maintainable model | ACL |
| Event-driven integration across contexts | PL (event schemas via schema registry) |
| Upstream model is tolerable to adopt wholesale | Conformist — only if no linguistic distortion results |
| Tight co-evolution between two contexts | Shared Kernel as last resort; prefer Customer/Supplier |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Named contexts | All contexts have Ubiquitous Language names | Technical names ("UserService", "FileDB") |
| Boundary justified | Every boundary is justified by at least one discovery signal | Arbitrary boundary, no justification stated |
| All relationships named | Every context connection has a named pattern | Unnamed "depends on" lines |
| ACL for external systems | All third-party integrations use ACL | Vendor model leaking into domain model |
| Consumer-Driven Contracts | All Customer/Supplier relationships have a contract test plan | Verbal agreements only |
| Published Language schemas | All cross-context events use a registered schema | Untyped or undocumented payloads crossing boundaries |

---

## Anti-Patterns

| Anti-pattern | Correction |
|---|---|
| **Context per Aggregate** — every Aggregate is its own BC | A BC holds a whole consistent model with several Aggregates sharing one Ubiquitous Language |
| **Shared database across contexts** | Each context owns its persistence; integrate via Domain Events or OHS |
| **Technical layers as contexts** ("API context", "DB context") | Draw boundaries where the language changes, not where technology changes |
| **Shared Kernel by default** | Default to ACL or OHS/PL; Shared Kernel only for a small, explicitly agreed subset |
| **God Context** — one context absorbs the entire domain | Split on linguistic fracture lines; a 1:1 BC-to-domain is almost never correct |
| **Nano-Context** — one BC per Aggregate or per table | Aggregates are a transactional-consistency mechanism inside a BC, not a BC sizing unit |

---

## References

| File | Contains |
|---|---|
| `references/bc-discovery-guide.md` | BC discovery workshop facilitation, linguistic fracture line technique step-by-step, data ownership exercise, "one BC or two?" decision tree |
| `references/bc-definition-artifact.md` | Complete BC definition template, worked example (DataAsset Management BC), versioning a BC definition when the boundary changes |
| `references/context-map-template.md` | Context Map diagram conventions, notation for each pattern, worked multi-BC example with DataAsset + Compliance + Reporting BCs |
| `references/service-decomposition.md` | How BC boundaries translate to service boundaries in this platform, the one-BC-one-service default, exceptions for merging or splitting |
