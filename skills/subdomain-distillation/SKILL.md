---
name: subdomain-distillation
description: >
  Teaches Core/Supporting/Generic Subdomain classification per Eric Evans'
  Domain-Driven Design, Part IV (Distillation) — how to identify which parts
  of a domain deserve the deepest modeling investment (Core), which are
  necessary but not differentiating (Supporting), and which are solved
  problems better bought or adopted than modeled from scratch (Generic).
  Used by domain-modeler during Strategic Design, early in the Design phase,
  before Bounded Contexts are modeled in tactical depth. This classification
  is the primary input to ddd-agent-handoff's Mode Selection Criteria (see
  skills/ddd-agent-handoff/references/handoff-protocol.md).
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-07-22
tags: [design, ddd, strategic-design, subdomain, distillation, core-domain]
---

# Subdomain Distillation

**Status: MVP.** This skill covers the classification itself — enough to
be genuinely usable now and to unblock `ddd-agent-handoff`'s Mode Selection
Criteria, which depends on it. It is explicitly flagged as a candidate for
its own full refactor session later (progressive disclosure into
`references/`/`assets/`, deeper worked examples, boundary/pattern
relationships) under the skill-refactor campaign.

## Purpose

Before a domain is modeled tactically (Aggregates, Bounded Contexts, Event
Storming), it must be distilled strategically: not every part of a domain
deserves equal investment. Evans' central claim in Part IV is that
misallocating modeling effort — treating a Generic Subdomain with the same
rigor as the Core Domain, or under-investing in the Core Domain — is one of
the most common and costly strategic mistakes in software design.

## The Three Subdomain Types

| Type | Definition | Investment |
|---|---|---|
| **Core Domain** | The part of the domain that is the primary reason the product exists — where real business complexity and competitive differentiation live. Getting this right is what makes the product valuable. | Deepest modeling investment. Best available modeling effort (human or agent). Full tactical DDD patterns (Aggregates, Domain Events, Event Storming) applied rigorously. Collaboration-mode handoffs by default (see `ddd-agent-handoff`). |
| **Supporting Subdomain** | Necessary for the business to function, requires custom logic specific to this product, but is not itself a differentiator — customers don't choose the product because of it. | Adequate modeling, simpler patterns where sufficient. Don't over-invest, but don't neglect either — it still needs a correct model. |
| **Generic Subdomain** | A solved problem — any organization building a comparable product would need essentially the same thing (authentication, generic file storage, email sending, PDF parsing libraries). | Minimal custom modeling. Buy, adopt an existing library/service, or apply a well-known off-the-shelf pattern. Modeling effort here is often wasted effort. X-as-a-Service handoffs, or skip cross-agent DDD process entirely. |

## Classification Checklist

For each candidate subdomain, ask in order:

1. **Differentiation** — If we got this wrong, would customers notice or leave? If yes → likely **Core**.
2. **Buy-vs-build** — Could a mature off-the-shelf product or library do this identically well for any organization? If yes → likely **Generic**.
3. **Necessity without differentiation** — Is it necessary, product-specific, but not something customers evaluate us on? → **Supporting**.
4. **When uncertain** — Default to Supporting rather than Core (avoids over-investment) and revisit the classification once the Core Domain is better understood; classification is a hypothesis, not a one-time verdict — Evans treats distillation as iterative, refined as domain insight deepens.

## Worked Example

Applied to this repo's first product (Data Estate Mapping and Compliance
Intelligence — see `sdlc-context.json`'s `first_product`):

- **Entity Extraction & Graph Relationship Engine** — **Core**. This is the
  product's actual value proposition; no off-the-shelf tool maps an
  organization's data estate into a compliance-aware relationship graph the
  way this product must.
- **Compliance Rule Engine** — **Core**. Directly differentiating — the
  product's compliance intelligence *is* the sellable outcome, not a
  side-effect.
- **Storage Connectors (Google Drive, S3)** — **Supporting**. Necessary and
  product-specific (each connector has real integration work), but customers
  don't choose this product because it connects to S3 — they choose it for
  what it does once connected.
- **Authentication/Authorization** — **Generic**. ABAC/JWT via well-known
  libraries and patterns (see `access-control-model`) — modeling this from
  scratch as a domain concept would be wasted effort.

## Applying This Classification

Record the classification per subdomain as part of the domain-modeler's
Strategic Design output (alongside the Context Map). Downstream,
`ddd-agent-handoff`'s Mode Selection Criteria reads this classification as
its primary signal for recommending Collaboration vs. X-as-a-Service vs.
Facilitating interaction mode between agents working on that subdomain.
