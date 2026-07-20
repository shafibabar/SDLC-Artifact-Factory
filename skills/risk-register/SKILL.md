---
name: risk-register
description: >
  Defines the living register of standing risks with ongoing exposure across
  the product's lifecycle — probability, impact, severity, owner, mitigation,
  and status — distinct from sdlc-context.json's open_questions, which are
  tactical and short-lived. Consulted by any agent whose Escalation Rules
  surface an exposure that persists across phases, and by Shafi during phase
  reviews to check what is being actively monitored.
version: 1.0.0
phase: cross-cutting
owner: factory-governance
created: 2026-07-20
tags: [governance, risk-register, risk-management, escalation, cross-cutting]
---

# Risk Register

## Purpose

Some things an agent discovers during a product's build are one-time decision points — resolved by a single answer and then closed. Others are standing exposures: conditions that persist, could still go wrong weeks or phases later, and need someone watching them. The risk register exists for the second kind. It is the product's running ledger of "here is what we are exposed to, how likely it is, how bad it would be, and who is keeping an eye on it."

Without a risk register, standing exposures either get raised once and forgotten, or get raised repeatedly by different agents as if new each time. Neither serves Shafi, whose job is to make informed calls — he needs to see accumulated exposure, not rediscover it.

## Risk vs. Open Question vs. Escalation

These three are easy to conflate. They are not the same thing.

| | **Open Question** (`sdlc-context.json → open_questions`) | **Escalation** (direct to Shafi) | **Risk Register Entry** |
|---|---|---|---|
| Nature | A gap in information needed to proceed | A decision only Shafi can make, right now | A standing exposure with ongoing probability and impact |
| Lifespan | Short — resolved by an answer, then removed | Instantaneous — resolved by Shafi's call, then done | Long — tracked across phases until mitigated, accepted, or closed |
| Example | "Which cloud provider does the pilot customer use?" | "This requires a paid API — approve the spend?" | "Entity extraction accuracy may be insufficient for compliance-grade PII detection" |
| Resolved by | Getting the missing fact | Shafi answering yes/no/choose | Ongoing mitigation work, monitored over time; eventually mitigated, accepted, or closed |
| Where it lives | `sdlc-context.json → open_questions` array | Conversation with Shafi; not persisted as its own artifact | `artifacts/[product]/governance/risk-register.md` |

**The test:** if resolving it is a single answer that makes the concern go away, it is an open question or a one-time escalation — not a risk. If resolving it requires ongoing work, monitoring, or acceptance of exposure that could still materialize later, it belongs in the risk register.

## When to Log a Risk vs. Escalate Directly

Log a risk register entry when an agent's Escalation Rules surface something that:
- Persists across multiple phases (identified in Design, still relevant in Deploy)
- Has a probability of occurring that is not zero and not certain — it is a real "might happen"
- Has a material impact if it does occur (technical, business, compliance, schedule, or security)
- Needs a named owner watching it, not just a single decision to close it out

Escalate directly to Shafi (no risk register entry) when the concern is:
- A one-time decision point with a clear yes/no or choice — logging it as a "risk" would misrepresent a decision as an exposure
- Resolved immediately by Shafi's answer, with no residual exposure afterward
- Already covered by an existing risk register entry — update the existing entry rather than creating a duplicate

**Worked distinction:** "Should we use MongoDB for the entity extraction bounded context?" is a one-time escalation — Shafi decides, the question closes. "Entity extraction accuracy could degrade on scanned/low-quality PDFs, causing PII to go undetected" is a risk — it doesn't resolve with one answer; it needs mitigation (extraction quality tests, confidence thresholds, human review triggers) and ongoing monitoring across Data, Quality, and Customer Validation phases.

## Risk Fields

| Field | Meaning |
|---|---|
| Risk ID | `RISK-[NNN]`, product-scoped, sequential, never reused (same discipline as ADR numbering in `adr-authoring`) |
| Description | One or two sentences: what could happen, and what triggers it |
| Category | `technical` \| `business` \| `compliance` \| `schedule` \| `security` \| `data` |
| Probability | `Low` \| `Medium` \| `High` — likelihood the risk materializes within the product's current horizon |
| Impact | `Low` \| `Medium` \| `High` — consequence if it does materialize |
| Severity | Derived from Probability × Impact — see matrix below |
| Owner | The agent role or "Shafi" — whoever is accountable for tracking and mitigating this risk |
| Mitigation strategy | What is being done to reduce probability, reduce impact, or prepare a response |
| Status | `open` \| `mitigated` \| `accepted` \| `closed` |
| Phase identified | Which SDLC phase surfaced the risk |
| Review cadence | How often the owner re-assesses this risk (e.g. "every phase gate," "monthly," "at each Deploy") |

## Category Definitions

| Category | Covers |
|---|---|
| `technical` | Architecture, implementation, or infrastructure exposure — performance, scalability, technical debt, tooling limitations |
| `business` | Market, adoption, or value-delivery exposure — a feature not achieving its intended business goal, competitive pressure |
| `compliance` | Regulatory or framework exposure — SOC 2 control gaps, data residency, audit readiness |
| `schedule` | Timeline exposure — a dependency or rework loop that threatens the product's delivery cadence |
| `security` | Threat exposure — attack surface, access control gaps, secrets handling |
| `data` | Data quality, lineage, or integrity exposure — extraction accuracy, classification correctness, retention compliance |

A risk may touch more than one category in practice (RISK-001 below is both `compliance` and `data`-flavored) — pick the single category that best represents where mitigation ownership sits, and note the secondary angle in the description.

## Probability × Impact Severity Matrix

| | Impact: Low | Impact: Medium | Impact: High |
|---|---|---|---|
| **Probability: High** | Medium | High | Critical |
| **Probability: Medium** | Low | Medium | High |
| **Probability: Low** | Low | Low | Medium |

Severity drives review cadence, not just optics: `Critical` and `High` severity risks are reviewed at every phase gate; `Medium` at least once per phase; `Low` at product-level retrospectives.

## Risk Status Lifecycle

`open` → `mitigated` (probability or impact has been reduced by concrete action, but the exposure has not fully disappeared) → `closed` (the exposure no longer applies — the underlying condition is gone). Alternatively `open` → `accepted` (Shafi has explicitly decided the exposure is tolerable as-is, with rationale recorded) → `closed` only if the underlying condition later disappears.

A risk is never silently removed from the register. Like ADRs, closed and accepted risks stay in the register with their final status — they are part of the record of what the product was exposed to and how it was handled.

## Where Risks Come From

A risk register entry is nearly always the product of an agent's own Escalation Rules — the point at which an agent's own file tells it to surface a concern rather than proceed silently. The distinction from a one-time escalation (see above) is what happens next:

1. The agent identifies a concern during its normal work (a design review, a code review, a compliance check).
2. It applies the test in "When to Log a Risk vs. Escalate Directly."
3. If it is a standing exposure, the agent appends an entry to `artifacts/[product]/governance/risk-register.md` directly — logging a risk does not require a separate escalation to Shafi, though Shafi reviews the register at every phase gate.
4. If it is a one-time decision, the agent escalates to Shafi in conversation as usual, per its own Escalation Rules.

This means the risk register is populated continuously by whichever agent is active in a given phase, not authored wholesale by one owner. `security-architect` is likely to log compliance and security risks during Design; `data-engineer` and `data-architect` are likely to log data-quality risks during Data; `platform-engineer` is likely to log operational risks during Deploy. Any agent may append at any phase — the register has no single producing agent, consistent with this skill domain having no owning persona-agent.

## Review Procedure

At every phase gate, and whenever Shafi requests a status check:

1. Read `artifacts/[product]/governance/risk-register.md` in full.
2. For every entry with `status: open`, confirm its `review cadence` has been met since the last review — if not, this is itself worth flagging to the owner.
3. For every `Critical` or `High` severity open risk, confirm the mitigation strategy is still active and has not stalled.
4. Check for duplicate or near-duplicate entries that should be merged.
5. Summarize open Critical/High risks in the phase gate report so Shafi sees standing exposure alongside the artifacts being reviewed.

## Worked Example

Four risks for the running product (Data Estate Mapping and Compliance Intelligence):

| Risk ID | Description | Category | Probability | Impact | Severity | Owner | Mitigation | Status | Phase Identified |
|---|---|---|---|---|---|---|---|---|---|
| RISK-001 | Entity extraction may misclassify or miss PII in low-quality scanned PDFs, causing a DataAsset's SensitivityLevel to be under-classified and a compliance gap to go undetected | Compliance | Medium | High | High | data-engineer | Confidence-threshold routing to human review queue; extraction quality test suite with adversarial low-quality fixtures | open | Data |
| RISK-002 | Physical multi-tenancy boundary could be breached by a misconfigured deployment, exposing one customer's data estate to another | Compliance | Low | High | Medium | security-architect | Tenant isolation verified per-deployment via automated OpenTofu policy checks; SOC 2 CC6 control mapped and tested | open | Design |
| RISK-003 | Apache AGE graph queries may degrade under the relationship volume of a large customer's full data estate, slowing compliance rule evaluation past acceptable SLOs | Technical | Medium | Medium | Medium | platform-engineer | Load testing against synthetic large-estate graphs before GA; Neo4j Community fallback path documented as an ADR-backed escape hatch | open | Quality |
| RISK-004 | Redpanda consumer group rebalancing during a rolling deploy could cause a burst of duplicate or delayed Domain Events, affecting alert timeliness for compliance findings | Operational | Medium | Low | Low | backend-engineer | Idempotent consumers via `eventId` (per ADR-002); alerting on consumer lag; documented in the outbox relay runbook | mitigated | Implement |

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Distinct from open questions | Entry represents ongoing exposure, not a single unanswered fact | A question masquerading as a risk because it hasn't been asked of Shafi yet |
| Probability and impact stated | Both fields are populated with a reasoned Low/Medium/High, not left blank | "Could be a problem" with no probability or impact assigned |
| Owner assigned | Every open risk has a named agent role or "Shafi" accountable for it | A risk with no owner — nobody is watching it |
| Mitigation is concrete | Mitigation names a specific action, control, or monitoring practice | Mitigation reads "we'll keep an eye on it" with no specific action |
| Status kept current | Status reflects the risk's actual state as of the last review cadence | A risk marked `open` for months past its review cadence with no re-assessment |
| Never silently removed | Closed/accepted risks remain in the register with final status | Risks deleted once no longer a concern, losing the record |

## Anti-Patterns

- **The write-only register** — risks are logged once and never revisited. If a register has no risks with a `mitigated` or `closed` status over the product's lifetime, nobody is reviewing it on cadence.
- **Ownerless risks** — a risk with no accountable owner is not being managed, only recorded. Every `open` or `mitigated` risk must have an owner.
- **Risks that never close** — a risk sits at `open` indefinitely with no change in mitigation activity. Either the mitigation is working (move to `mitigated`), the exposure is gone (move to `closed`), or Shafi has decided to live with it (move to `accepted`) — "open forever" is not a valid steady state.
- **Vague entries** — "something could go wrong with the graph database" has no probability, no impact, no mitigation path. A risk entry must be specific enough that someone unfamiliar with the conversation that raised it can act on it.
- **Escalation inflation** — logging every one-time decision point as a "risk" clutters the register and dilutes attention to genuine standing exposures. Use the test in "When to Log a Risk vs. Escalate Directly" before creating an entry.
- **Duplicate risks** — the same underlying exposure logged multiple times under different wording because different agents didn't check the existing register first. Always search the register before adding a new entry.

## Output Format

This skill's output is a standard Markdown artifact with frontmatter — a living document any agent can append to, and any Shafi review can consult:

```markdown
---
name: risk-register-<product-slug>
version: 1.0.0
phase: cross-cutting
owner: factory-governance
created: <YYYY-MM-DD>
---

# Risk Register — <Product Name>

## Active Risks

| Risk ID | Description | Category | Probability | Impact | Severity | Owner | Mitigation Strategy | Status | Phase Identified | Review Cadence |
|---|---|---|---|---|---|---|---|---|---|---|
| RISK-001 | ... | ... | ... | ... | ... | ... | ... | open | ... | ... |

## Mitigated / Accepted / Closed Risks

<!-- Same table shape, for risks that have moved past open. Kept for the record — never deleted. -->

| Risk ID | Description | Category | Probability | Impact | Severity | Owner | Mitigation Strategy | Status | Phase Identified | Review Cadence |
|---|---|---|---|---|---|---|---|---|---|---|
```

Stored at: `artifacts/[product]/governance/risk-register.md`. One register per product, appended to continuously — not versioned per-risk like an ADR chain, but the whole file's frontmatter `version` increments on structural changes (e.g. a new category added).
