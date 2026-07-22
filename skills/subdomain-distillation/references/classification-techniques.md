# Subdomain Classification Techniques

Deeper tools for applying and refining the Core/Supporting/Generic
classification from `SKILL.md`, drawn from Vernon, Khononov, Kaiser, and
Evans. Self-contained — loadable without reading `SKILL.md` first, though it
assumes the three-way classification as a starting point. Board specs in
this file follow `miro-board-notation`.

---

## Vernon's Outsource Test

*Domain-Driven Design Distilled.* A sharper, more actionable Generic-subdomain
test than "is it a solved problem": **would you outsource it?** If a
competent third party could build or provide this identically well for any
comparable organization, it's Generic — regardless of how technically
non-trivial it is to build.

Two corrections Vernon adds to how teams typically apply Core/Supporting/
Generic:

- **Most systems have only one or two genuine Core Domains.** Teams
  habitually over-classify — everything feels important once you're building
  it. If more than two or three subdomains are labeled Core, that's a signal
  to re-run the classification more skeptically, not evidence the product is
  unusually differentiated.
- **A Core Domain can span multiple Bounded Contexts.** Classification is a
  business-value question; Bounded Context boundaries are a modeling-boundary
  question. They're related — Core Domain work usually gets its own
  dedicated Bounded Context(s) — but one Core Domain classification does not
  imply exactly one Bounded Context, and a Bounded Context boundary decision
  should still go through `bounded-context-mapping`/`context-map-patterns` on
  its own terms.

## Khononov's Two Axes: Complexity vs. Strategic Importance

*Learning Domain-Driven Design.* The single most load-bearing distinction in
this reference: **complexity and strategic importance are separate axes.**
"Hard to build" and "Core" are not synonyms.

| | High strategic importance | Low strategic importance |
|---|---|---|
| **High complexity** | **Core** — invest deeply, custom-built | **Complicated, not Core** — needs careful modeling, but the investment should match the complexity, not an assumed Core status. This is the danger zone: teams over-invest here because it's hard, mistaking difficulty for importance. |
| **Low complexity** | **Core, simple** — rare but real (e.g. a small pricing rule that *is* the differentiator); don't under-invest just because it's simple |
| **Low + Low** | — | **Generic** — buy it |

Khononov also ties classification to **pattern selection**, not just
investment level: Core Domain subdomains often warrant full DDD tactical
patterns (Aggregates, Domain Events, possibly Event Sourcing where
justified — see `aggregate-design`, `cqrs-pattern`); Generic subdomains
warrant the *simplest* viable approach — even a plain CRUD/Transaction
Script, or a bought SaaS product, with no DDD tactical machinery at all.
Applying rich tactical patterns uniformly regardless of classification is
itself the named mistake — a Generic subdomain modeled with the same rigor
as the Core Domain has wasted effort exactly where it was least needed.

*Note: this repo's `CLAUDE.md` currently states DDD tactical patterns as
non-negotiable across every service. Khononov's guidance creates mild
tension with that blanket rule for genuinely Generic subdomains — noted here
as a real consideration for whoever applies this classification, not as a
change to CLAUDE.md, which is outside this skill's scope to alter.*

## Kaiser's Wardley Evolution Axis

*Architecture for Flow.* Wardley Mapping's evolution axis gives a rigorous,
visual classification tool, and — critically — captures that **subdomains
evolve over time**. What's Genesis/Core today (cloud compute, decades ago)
becomes Commodity/Generic later. This turns "classification is a hypothesis,
revisit iteratively" (see `SKILL.md`) into an actual tool instead of a vague
intention.

This reference applies a **simplified, one-axis version** of Wardley
Mapping — the evolution stage only, not the full value-chain/visibility
dimension a complete Wardley Map also encodes. That's sufficient for
subdomain classification; a full Wardley Map is a separate, broader
strategic exercise outside this skill's scope.

The four evolution stages, each modeled as a Miro frame subdomains are
placed into:

| Stage | Meaning | Roughly maps to |
|---|---|---|
| **Genesis** | Novel, uncertain, being invented for the first time | Core |
| **Custom-Built** | Understood in principle, still built bespoke per organization | Core |
| **Product/Rental** | Established products/services exist; some customization still needed | Supporting |
| **Commodity** | Fully standardized utility — nobody differentiates on it anymore | Generic |

**Board spec** — Wardley evolution placement for this product's subdomains:

Color Legend: `green` = Core, `yellow` = Supporting, `gray` = Generic.

**Items:**

| ID | Type | Content | Frame | Color |
|---|---|---|---|---|
| F1 | frame | Genesis | — | — |
| F2 | frame | Custom-Built | — | — |
| F3 | frame | Product/Rental | — | — |
| F4 | frame | Commodity | — | — |
| S1 | sticky_note | Entity Extraction & Graph Engine | F2 | green |
| S2 | sticky_note | Compliance Rule Engine | F2 | green |
| S3 | sticky_note | Storage Connectors | F3 | yellow |
| S4 | sticky_note | Authentication/Authorization | F4 | gray |

**Connectors:**

| From | To | Label | Style |
|---|---|---|---|
| S1 | S2 | feeds compliance rules | arrow |
| S3 | S1 | supplies extracted content | arrow |

Placement is a hypothesis, same as the base classification — re-run this
placement whenever a subdomain's maturity in the industry changes, not only
when this product changes.

## Evans' Segregated Core and Abstract Core

*Domain-Driven Design*, Part IV. Two concrete refactoring techniques for
when classification reveals a problem in an *already-built* model, not just
a greenfield planning tool:

- **Segregated Core** — when Core Domain concepts have become tangled with
  Generic or Supporting concepts inside an existing model (common after
  organic growth), deliberately extract the Core parts into their own
  module, even accepting some temporary duplication, so the Core Domain
  becomes visible and cleanly bounded again. Apply when classification
  reveals the Core Domain is *not currently distinguishable* in the code as
  it stands.
- **Abstract Core** — when the Core Domain itself has grown large, identify
  the most fundamental abstractions that cut across its different parts
  (the deepest shared concepts, expressed as interfaces or base types) and
  pull them into a small, distinct abstract layer the more specific parts
  depend on. Apply when the Core Domain is correctly identified but
  internally incoherent — too large to reason about as one undifferentiated
  mass.

Both techniques assume classification already happened (per `SKILL.md`'s
checklist) and are triggered by what that classification reveals about the
*current* state of the model — they are not alternatives to classification,
they are what you do next when classification exposes a tangled or
oversized Core Domain.
