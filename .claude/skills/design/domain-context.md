# Skill: design/domain-context

## Purpose
Produce the Domain Context document — the first design artifact. Identifies the domain, its subdomains (Core / Supporting / Generic), and the boundaries of modelling scope. This document is the anchor that every subsequent design artifact references.

## Inputs
- `artifacts/strategy/vision.md`
- `artifacts/ideate/requirements/functional.md`
- `sdlc-config.json`

## Output
**File:** `artifacts/design/domain/context.md`
**Registers in manifest:** yes

## Process
1. Read vision and functional requirements.
2. Identify the top-level domain (the sphere of business activity).
3. Decompose into subdomains. Classify each as Core, Supporting, or Generic.
4. Justify each classification — Core subdomains are the competitive advantage; wrong classifications lead to under-investing in what matters and over-building commodities.
5. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Domain Context

**Product:** {product_name}
**Phase:** Design
**Artifact:** Domain Context
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## The Domain
{Name and describe the top-level domain. What sphere of business activity are we modelling? What are the natural language boundaries of this domain?}

## Why This Domain Matters
{One paragraph connecting the domain to the product vision and the problem statement. Why is understanding this domain precisely the key to building the right product?}

---

## Subdomain Map

| Subdomain | Classification | Description | Rationale |
|-----------|---------------|-------------|-----------|
| {e.g. Data Estate Mapping} | **Core** | Crawling, extracting, and graphing entities across storage locations | This is the primary competitive advantage — nobody else maps the estate with this depth and residency model |
| {e.g. Compliance Assessment} | **Core** | Evaluating the estate graph against compliance framework rules | Direct value delivery to the buyer — compliance posture is the primary purchase reason |
| {e.g. Identity & Access Management} | **Supporting** | Authentication, authorisation, user management | Necessary but not differentiating — supports the core |
| {e.g. Notification & Alerting} | **Supporting** | Delivering findings and alerts to users | Supports the core experience; not the reason customers buy |
| {e.g. Billing & Subscription} | **Generic** | Tenant billing, usage metering | Commodity — use a third-party service rather than building |
| {e.g. Infrastructure Provisioning} | **Generic** | Kubernetes, database, queue deployment | Buy/use open-source; not a competitive concern |

### Core Subdomains (build with maximum investment)
{Explain why each Core subdomain is truly a competitive differentiator. If you cannot explain why, reconsider the classification.}

### Supporting Subdomains (build simply, or buy)
{Explain what "simply" means here — what is the minimum viable implementation that supports the Core without stealing investment from it?}

### Generic Subdomains (buy or open source)
{Name the specific third-party services or open-source tools that will fulfil each Generic subdomain. Budget is not spent building these.}

---

## Modelling Scope
{What is in scope for domain modelling in this product release? Which subdomains will have Bounded Contexts defined?}

**In scope for modelling:**
- {Subdomain 1}
- {Subdomain 2}

**Out of scope (deferred or handled by third parties):**
- {Subdomain 3 — handled by {tool/service}}

---

## Key Domain Concepts (preliminary)
{The most important concepts in this domain, before bounded contexts are defined. These will be refined into the ubiquitous language per bounded context after Event Storming.}

| Concept | Preliminary definition |
|---------|----------------------|
| {concept 1} | {definition} |
| {concept 2} | {definition} |
```

## Quality Checks
- [ ] Every subdomain is classified as Core, Supporting, or Generic — none left unclassified
- [ ] Core subdomains are genuinely differentiating — if everything is Core, the classification has failed
- [ ] Generic subdomains name a specific tool/service that will handle them
- [ ] No undefined ubiquitous language terms
