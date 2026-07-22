---
name: subdomain-distillation
description: >
  Teaches Core/Supporting/Generic Subdomain classification and how to apply
  it — Eric Evans' Domain-Driven Design Part IV (Distillation), Vaughn
  Vernon's outsource-test heuristic, Vlad Khononov's complexity-vs-strategic-
  importance distinction, Susanne Kaiser's Wardley evolution mapping, Dan
  Bergh Johnsson's security-sensitivity axis (Secure by Design), and Carola
  Lilienthal & Henning Schwentner's legacy-transformation sequencing (Domain-
  Driven Transformation). Used by domain-modeler during Strategic Design,
  early in the Design phase, before Bounded Contexts are modeled in tactical
  depth. This classification is the primary input to ddd-agent-handoff's
  Mode Selection Criteria (see
  skills/ddd-agent-handoff/references/handoff-protocol.md).
version: 2.0.0
phase: design
owner: domain-modeler
created: 2026-07-22
tags: [design, ddd, strategic-design, subdomain, distillation, core-domain, security]
---

# Subdomain Distillation

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
| **Core Domain** | The part of the domain that is the primary reason the product exists — where real business complexity and competitive differentiation live. Getting this right is what makes the product valuable. | Deepest modeling investment. Full tactical DDD patterns (Aggregates, Domain Events, Event Storming) applied rigorously. Collaboration-mode handoffs by default (see `ddd-agent-handoff`). |
| **Supporting Subdomain** | Necessary for the business to function, requires custom logic specific to this product, but is not itself a differentiator — customers don't choose the product because of it. | Adequate modeling, simpler patterns where sufficient. Don't over-invest, but don't neglect either. |
| **Generic Subdomain** | A solved problem — any organization building a comparable product would need essentially the same thing (authentication, generic file storage, email sending, PDF parsing libraries). | Minimal custom modeling. Buy, adopt an existing library/service, or apply a well-known off-the-shelf pattern. X-as-a-Service handoffs, or skip cross-agent DDD process entirely. |

**Complexity is not the same axis as Core-ness.** A subdomain can be
genuinely hard to build without being Core — confusing "hard" with
"important" is a named, common mistake (Khononov). See
`references/classification-techniques.md` for the full complexity-vs-
strategic-importance breakdown before defaulting something to Core just
because it's difficult.

## Classification Checklist

For each candidate subdomain, ask in order:

1. **Differentiation** — If we got this wrong, would customers notice or leave? If yes → likely **Core**.
2. **Buy-vs-build** — Could a mature off-the-shelf product or library do this identically well for any organization? If yes → likely **Generic**.
3. **Necessity without differentiation** — Is it necessary, product-specific, but not something customers evaluate us on? → **Supporting**.
4. **When uncertain** — Default to Supporting rather than Core (avoids over-investment) and revisit the classification once the Core Domain is better understood; classification is a hypothesis, not a one-time verdict.

Vernon's sharper framing of step 2 — "would you outsource it?" — and his
warning that most systems have only one or two genuine Core Domains are in
`references/classification-techniques.md`, alongside Kaiser's Wardley
evolution-stage tool for revisiting a classification as it ages, and Evans'
Segregated Core / Abstract Core techniques for when classification exposes
a tangled or oversized Core Domain in an already-built model.

## Security Is a Separate Axis

Core/Supporting/Generic answers a build-vs-buy and investment question. It
does not answer whether a modeling mistake here could cause unauthorized
data exposure or a safety/financial failure — that is a distinct axis, run
alongside the classification above, not folded into it. A Generic subdomain
(buy the library) can still have a security-critical slice that deserves
Core-level modeling rigor. See `references/security-sensitive-subdomains.md`
for the checklist and technique (Domain Primitives, Assertions).

## Legacy and Transformation

The guidance above is sufficient for a greenfield product. If this
classification is being applied to an **existing system**, classification
also drives *sequencing* — which subdomain to transform first, and which
Generic subdomains are replace-not-migrate candidates. See
`references/legacy-transformation-guidance.md` for prioritization rules,
the Strangler Fig pattern, and the Domain Vision Board artifact for
socializing the classification with stakeholders (classification is
organizationally political in a transformation, not a purely technical
call).

## Recording a Classification

Use `assets/subdomain-classification-canvas.md` — one canvas per subdomain,
combining the base classification with every technique above (outsource
test, complexity quadrant, Wardley stage, security-sensitivity flag,
transformation priority) into a single fill-in worksheet.

## Worked Example

Applied to this repo's first product (Data Estate Mapping and Compliance
Intelligence — see `sdlc-context.json`'s `first_product`):

- **Entity Extraction & Graph Relationship Engine** — **Core**. No
  off-the-shelf tool maps an organization's data estate into a
  compliance-aware relationship graph the way this product must.
- **Compliance Rule Engine** — **Core**. Directly differentiating — the
  product's compliance intelligence *is* the sellable outcome.
- **Storage Connectors (Google Drive, S3)** — **Supporting** overall, but
  its credential-handling slice is security-sensitive and gets Core-level
  rigor regardless (see `references/security-sensitive-subdomains.md`).
- **Authentication/Authorization** — **Generic** for build-vs-buy (use an
  existing identity provider), but *not* an excuse to skip modeling how
  access decisions interact with this product's specific invariants — that
  slice is security-sensitive and gets Core-level rigor too. See
  `references/security-sensitive-subdomains.md` for the full correction to
  this example.

## Applying This Classification

Record the classification per subdomain using
`assets/subdomain-classification-canvas.md`, as part of the domain-modeler's
Strategic Design output alongside the Context Map. Downstream,
`ddd-agent-handoff`'s Mode Selection Criteria reads this classification as
its primary signal for recommending Collaboration vs. X-as-a-Service vs.
Facilitating interaction mode between agents working on that subdomain.
