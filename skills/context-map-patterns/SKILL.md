---
name: context-map-patterns
description: >
  Teaches the domain-modeler and enterprise-architect to select and apply the correct Context Map
  integration pattern for each Bounded Context relationship — covering the full Evans/Vernon pattern
  catalogue (Partnership, Shared Kernel, Customer/Supplier, Conformist, Anti-Corruption Layer, Open
  Host Service / Published Language, Separate Ways, Big Ball of Mud), with explicit selection
  criteria for each pattern, the political/organizational dynamics that drive pattern choice as much
  as technical ones, and how each pattern manifests in this platform's implementation (Go ACL
  adapter, OpenAPI-based OHS, schema-registry Published Language, etc.). Used during Design when
  establishing inter-BC communication contracts.
version: 2.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: ["design","domain-modeling","context-map","integration-patterns","acl","open-host-service","partnership","conformist"]
produces: pattern-selection-rationale
domain: domain-modeling
status: stable
related: [bounded-context-mapping, go-contract-test, integration-design, event-driven-patterns]
---

# Context Map Patterns

## Purpose

This skill teaches pattern selection for Context Map relationships. Where `bounded-context-mapping`
teaches how to draw the map, this skill teaches which pattern belongs on each line — and why.

Use this skill when:
- Selecting a pattern for a new Bounded Context relationship
- Evaluating whether an existing integration design is correctly pattern-matched
- A Consumer-Driven Contract requirement needs to be designed
- An integration anti-pattern (pass-through ACL, conformist-by-inertia) needs to be identified

**References:**
- `references/integration-patterns-catalogue.md` — full per-pattern details, Go implementation
  shapes, precise use/do-not-use criteria, and worked examples from this repo's domain
- `references/pattern-selection-guide.md` — the worked decision tree: start from team relationship,
  arrive at 1–2 pattern candidates; political signals that override technical preference
- `references/worked-example.md` — complete 3-BC Context Map (DataAsset Management, Compliance,
  Reporting) with every relationship annotated with pattern and rationale

---

## The Primary Organizing Principle: Power and Obligation

Pattern selection is driven as much by the **organizational relationship** between teams as by
technical factors. The upstream/downstream power dynamic determines which patterns are viable:

| Upstream/Downstream Dynamic | Pattern Space |
|---|---|
| Two teams with mutual obligation, negotiating as equals | Partnership, Shared Kernel, Customer/Supplier |
| Upstream has no obligation to downstream | Conformist or ACL |
| Upstream serves many consumers | Open Host Service + Published Language |
| No real dependency | Separate Ways |
| Legacy system with undefined boundaries | Big Ball of Mud → plan ACL migration |

The political signal overrides the technical preference. Conformist is not a compromise — it is
the correct pattern when the upstream team has no obligation to the downstream. An ACL protects the
downstream's model regardless of the upstream's cooperation level.

---

## Pattern Quick Reference

| # | Pattern | One-Sentence Description | Primary Selection Signal |
|---|---|---|---|
| 1 | **Partnership** | Two teams coordinate releases; neither can proceed without the other | Shared delivery deadline with mutual veto power over interface changes |
| 2 | **Shared Kernel** | Two contexts share a small, jointly-owned subset of the domain model | Immutable canonical concepts genuinely shared; both teams govern every change |
| 3 | **Customer/Supplier** | Upstream has obligations to downstream; Consumer-Driven Contracts enforce them | Two internal teams negotiating; downstream can demand a stable contract |
| 4 | **Conformist** | Downstream adopts upstream model as-is; upstream has no obligation | Upstream is indifferent or inaccessible; model is coherent in the downstream's domain sense |
| 5 | **Anti-Corruption Layer** | Downstream translates upstream model into its own Ubiquitous Language via an adapter | Third-party API, legacy system, or upstream vocabulary that conflicts with the downstream's model |
| 6 | **Open Host Service** | Upstream publishes a versioned protocol any downstream can consume | One upstream serves multiple downstream consumers; stability and versioning discipline required |
| 7 | **Published Language** | A shared, versioned event or data schema multiple contexts use to communicate | Event-driven integration; the schema is the cross-context contract |
| 8 | **Separate Ways** | No integration; both contexts operate independently | Cost of integration exceeds its value; no domain concepts genuinely shared |
| 9 | **Big Ball of Mud** | Existing system with no clear boundaries; documented honestly | Naming reality in a legacy system; plan ACL as the single entry point |

---

## Decision Table: Situation → Pattern Candidates

| Situation | Primary Pattern | When to Escalate |
|---|---|---|
| Third-party API (Google Drive, AWS S3) | ACL — always | N/A |
| Legacy system with poor model | ACL | N/A |
| Internal team, upstream cooperative | Customer/Supplier + Consumer-Driven Contracts | To OHS when downstream count exceeds 2–3 |
| Internal team, upstream uncooperative | Conformist (model OK) or ACL (model poor) | Escalate Conformist to ACL when upstream vocabulary conflicts with downstream's Ubiquitous Language |
| One upstream, many consumers | OHS + Published Language | — |
| Event-driven integration | Published Language (event schemas) | — |
| Same team, tightly coupled contexts | Shared Kernel (small) or Partnership (temporary) | — |
| No shared domain concepts | Separate Ways | — |
| Existing legacy without clear boundaries | Big Ball of Mud → plan ACL migration | — |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Pattern archaeology** | Names whatever integration exists as a pattern — documents accidents, not decisions | Select the pattern first; build the integration to match it |
| **Pass-through ACL** | Translator maps upstream fields 1:1 into identically-shaped downstream types — all cost, no insulation | Translate into the downstream's Ubiquitous Language, or admit the relationship is Conformist |
| **Conformist by inertia** | Conforming to an internal upstream because negotiating felt difficult | Escalate to Customer/Supplier; reserve Conformist for genuinely non-negotiable upstreams |
| **Union-of-wishes OHS** | OHS extended with every consumer's special request | Design for the primary consumer; additive extensions only after a named consumer commits |
| **`common/` labelled Shared Kernel** | Grab-bag utility package with no agreed scope or joint ownership | Enumerate a minimal kernel with two-owner approval, or dissolve it into per-context code |
| **Building against Big Ball of Mud directly** | Legacy instability propagates into every new service | One ACL is the single entry point; all new integration goes through it |

---

## Consumer-Driven Contracts Requirement

Every **Customer/Supplier** and **Open Host Service** relationship must have:
1. A named contract owner (the Consumer context)
2. A contract test suite (schema-based or Pact)
3. A CI gate: Supplier's pipeline fails if any Consumer's contract test fails
4. A process for the Consumer to update the contract when its needs change

Without Consumer-Driven Contracts, a Customer/Supplier relationship is a verbal agreement — it
will be violated. See `go-contract-test` for the Go implementation.

---

## Output Format

```markdown
## Pattern Selection Rationale

| Relationship | Pattern selected | Rationale | Consumer-Driven Contracts required? |
|---|---|---|---|
| [Context A] → [Context B] | [Pattern] | [Why this pattern and not alternatives] | [Yes / No] |
```

See `references/worked-example.md` for a complete, annotated 3-BC context map.
