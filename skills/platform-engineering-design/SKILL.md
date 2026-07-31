---
name: platform-engineering-design
description: >
  Teaches Platform Engineering as a product discipline — the Thinnest Viable Platform principle, golden path design, Developer Experience measurement (Time-to-First-Deploy, self-service coverage, out-of-band exceptions), platform-as-product SLOs, service catalog design, X-as-a-Service vs collaboration interaction modes, toil quantification, and how to evaluate whether a platform capability is genuinely self-service. Used by the platform-engineer to design and evaluate internal platform capabilities.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-31
tags: ["deploy","platform","developer-experience","golden-path","tvp","idp","service-catalog","toil","cognitive-load"]
---

# Platform Engineering Design

Platform engineering is a **product discipline applied to internal infrastructure**. The platform team's customers are the organisation's own engineering teams; its product is the set of tools, services, and processes those teams use to build and operate their services. Platform success is measured by developer adoption and productivity — not just system uptime.

---

## The Thinnest Viable Platform (TVP)

Start from the minimum set of capabilities that meaningfully reduces cognitive load. Ask: *"what is the smallest set of platform capabilities that removes the largest friction from developers building on this platform?"*

Define the TVP by asking each customer team: **"what was the most time-consuming, most frustrating infrastructure task you did last month?"** The top three answers across teams define the initial golden paths — not the platform team's own estimates.

Growing beyond the TVP without validated customer pull is over-engineering that creates maintenance burden without adoption benefit. Do not add a new platform capability until at least **two different product teams** have independently requested it — one request is a special case; two independent requests are a pattern.

---

## Golden Paths — Not Forced Rails

A **golden path** is a well-lit, opinionated, supported route through a problem space. It is NOT the only allowed route; it is an investment that makes the recommended way significantly easier than any alternative.

| Attribute | Golden Path | Forced Rail |
|---|---|---|
| Deviation allowed? | Yes — off-path is signal, not violation | No — permission gate required |
| Developer trust | High — choice is preserved | Low — workarounds proliferate |
| Hidden debt | None — deviations are visible | High — workarounds are invisible |
| Platform feedback | Exceptions expose gaps | Gaps are suppressed |

When developers choose to go off the golden path, the platform team investigates why — rising exceptions are a leading indicator that the golden path does not cover real needs.

---

## Developer Experience (DX) Measurement

Cognitive load — the amount of complexity a developer must hold in their head — is the primary metric the platform reduces.

| DX Metric | Definition | Target | Failure Signal |
|---|---|---|---|
| Time-to-First-Deploy | Minutes from new-engineer day-one to first production deploy | ≤1 business day | >2 days = golden path has failed |
| Self-Service Coverage | % of common platform operations achievable without a support ticket | ≥90% | Any core op requiring a ticket |
| Out-of-Band Exceptions | Count of deviation requests from the golden path per sprint | Declining trend | Rising count = golden path gaps |
| Platform Adoption Rate | % of services/teams using the golden path | Growing trend | Flat or declining adoption |

**Time-to-First-Deploy is the single most important DX metric.** If it exceeds two days, the platform's onboarding golden path has failed — that failure is the platform team's problem, not the new engineer's.

Full measurement guide with instrumentation, quarterly survey template, and embedded-engineer session format: `references/dx-measurement-guide.md`.

---

## Platform-as-Product SLOs

The platform team is accountable for its own SLIs and SLOs, reviewed monthly, just as product services are accountable for theirs.

| Platform Capability | SLI | Target SLO |
|---|---|---|
| CI pipeline | P95 job duration | < 10 min |
| CD pipeline | Availability | > 99.5% |
| Environment provisioning | Time from request to working environment | < 5 min |
| Service template creation | Time from request to new service with passing CI | < 15 min |

These are the platform team's accountability SLOs — tracked as SLIs with the same rigour as product service SLOs. Complete platform SLI/SLO definitions with measurement sources: `references/platform-slo-catalog.md`.

---

## Service Catalog

A service catalog is the platform's primary discoverability surface: every service, its owner, its dependencies, its SLO status, its documentation, and its deployment pipeline queryable in one place. It is also the gateway to the golden path: *"click here to create a new service using the platform's standard template."*

**Introduce a service catalog when service count exceeds 20.** Below 20, a well-organised `README.md` or shared wiki page is a viable TVP for discoverability. At 50 services, the absence of a catalog creates real coordination failures.

Backstage is the dominant open-source implementation. For early-stage platforms (<20 services), a spreadsheet is sufficient. Full design guidance including what each service record must contain, Backstage vs. lighter alternatives, and relationship to `sdlc-config.json`: `references/service-catalog-design.md`.

---

## Interaction Modes (Team Topologies)

Platform teams interact with product (stream-aligned) teams in two modes:

| Mode | When | Steady State? |
|---|---|---|
| **X-as-a-Service** | Platform offers well-defined, self-service capability; product team consumes without platform involvement | YES — the target |
| **Collaboration** | New capability requires product team's domain knowledge; temporary, time-boxed | NO — return to X-as-a-Service once stable |

**Anti-pattern: permanently in collaboration mode.** If every use of a platform capability requires a support ticket or a platform engineer to pair, the self-service layer has not been built or is broken. Collaboration mode should have an explicit exit criterion (typically: the capability is self-service AND the golden path exists AND there is an automated test of the golden path).

---

## Toil Quantification

Toil is work that is manual, repetitive, tactical, devoid of enduring value, and scales linearly with service growth.

**Rule:** A runbook procedure executed more than once per week is a toil candidate — an automation gap. A runbook step that has been executed 20 times without change is not a runbook step; it is evidence that a self-service capability has not been built.

Toil reduction is a third platform success category alongside adoption and DORA metrics. Track hours per week engineers spend on undifferentiated infrastructure work, trended over time.

---

## DX Review Checklist for New Platform Capabilities

Before shipping a new platform capability, the platform engineer evaluates it against this checklist:

- [ ] Can a new engineer use this capability without reading more than 2 pages of documentation?
- [ ] Is there a self-service path — no support ticket needed for the common case?
- [ ] Does the error message tell the developer what to do (not just what failed)?
- [ ] Is there an automated test of the golden path itself (not just the underlying components)?
- [ ] Has this been validated with at least one real customer team (embedded session or structured interview)?

A capability that fails two or more of these checks ships as collaboration mode only, with a clear X-as-a-Service exit criterion.

---

## Platform Success Metrics

Three categories of platform success metrics — all required:

1. **Adoption** — % of teams/services using the golden path; growth rate over time
2. **Delivery performance** — DORA four key metrics (Deployment Frequency, Lead Time, MTTR, Change Failure Rate) for services on the platform, compared against pre-platform baseline
3. **Toil** — hours per week on undifferentiated infrastructure work, trended over time

A platform that improves DORA metrics and reduces toil is succeeding. A platform that improves adoption but not DORA metrics is providing the wrong golden path.

---

## References

- `references/dx-measurement-guide.md` — Instrumenting and tracking all four DX metrics; quarterly DX survey template; embedded-engineer session format
- `references/golden-path-design.md` — Designing a golden path: TVP question, customer interviews, out-of-band exception tracking, iteration; worked examples for this repo
- `references/platform-slo-catalog.md` — Complete platform SLI/SLO definitions with measurement sources for this repo's platform capabilities
- `references/service-catalog-design.md` — Service record schema, Backstage vs. lightweight alternatives, relationship to `sdlc-config.json`
