---
name: subdomain-classification
product: [product slug]
version: 1.0.0
phase: design
owner: domain-modeler
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: the Core subdomain(s), what is bought, and any security-sensitive slice]
profile: [lean | standard | enterprise]
traces-to: [design/event-storming-big-picture.md, strategy/strategy-kernel.md, strategy/vision.md]
classified-on: [YYYY-MM-DD]
---

# Subdomain Classification: [Product]

## How the Subdomains Were Found

[One short paragraph: which Big Picture capabilities were split, and where splitting stopped because the parts had one type.]

## Classification

| Subdomain | Type | Advantage? | Complex? | Solved elsewhere? | Sourcing | Modelling | Security-sensitive slice | Revisit when |
|---|---|---|---|---|---|---|---|---|
| [name] | Core / Supporting / Generic | [yes/no + one line of evidence] | [yes/no + evidence] | [yes/no + the product or library] | In-house / Buy or adopt / Cheap build / Outsource build | Domain Model / Transaction Script or Active Record / thin integration | [the slice, or "checklist run: none"] | [the trigger] |

<!-- lean: the table above (every column, briefly), plus Open Questions; the sections below are standard and enterprise -->

## Domain Vision Statement

[About a page: what the Core Domain is and what value its model brings, in terms a domain expert recognises. About the model, not the market.]

## Highlighted Core

[The Bounded Contexts, Aggregates and terms that carry the Core, once they exist; until then, the Event Storming areas.]

## Security-Sensitive Slices

| Subdomain | Checklist answers (1 · 2 · 3) | The slice | Rigor required |
|---|---|---|---|

## Transformation Order (existing systems only)

| Subdomain | Type | Tangle and risk | Order | Why |
|---|---|---|---|---|

## Open Questions for the Product Owner

| # | Question | Label assumed meanwhile |
|---|---|---|
