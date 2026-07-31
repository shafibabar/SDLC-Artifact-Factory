---
name: risk-register
description: >
  Log and track a standing risk with ongoing exposure — a RISK-NNN entry with
  category (technical, business, compliance, schedule, security, data),
  likelihood, impact, derived severity, owner, mitigation strategy, and status
  (open, mitigated, accepted, closed). Decide whether a surfaced concern is a
  risk-register entry, a tactical open_question, or a one-time escalation to
  Shafi. Apply Fairbanks' risk-driven judgment — scale architecture and
  mitigation effort to an architecturally-significant risk, one that if
  unmitigated could force a costly re-design. Consulted at every phase gate and
  whenever an agent's Escalation Rules surface a persistent exposure.
version: 2.0.0
phase: cross-cutting
owner: factory-governance
created: 2026-07-20
tags: [governance, risk, risk-register, risk-driven, mitigation, likelihood-impact]
related: [adr-authoring, methodology-review, glossary-management, multi-tenancy-design, event-driven-patterns]
---

# Risk Register

## Purpose

The risk register is the product's running ledger of standing exposures — conditions that persist, could still go wrong phases later, and need someone watching them: "here is what we are exposed to, how likely it is, how bad it would be, and who is keeping an eye on it." Without it, standing exposures get raised once and forgotten, or re-raised by different agents as if new each time. Shafi's job is to make informed calls; he needs accumulated exposure in one place, not to rediscover it.

## Risk vs. Open Question vs. Escalation

These three are easy to conflate. They are not the same thing.

| | **Open Question** (`sdlc-context.json → open_questions`) | **Escalation** (direct to Shafi) | **Risk Register Entry** |
|---|---|---|---|
| Nature | A gap in information needed to proceed | A decision only Shafi can make, now | A standing exposure with ongoing likelihood and impact |
| Lifespan | Short — resolved by an answer, then removed | Instantaneous — resolved by Shafi's call | Long — tracked until mitigated, accepted, or closed |
| Resolved by | Getting the missing fact | Shafi answering yes/no/choose | Ongoing mitigation, monitored over time |
| Where it lives | `sdlc-context.json → open_questions` | Conversation with Shafi; not persisted | `artifacts/[product]/governance/risk-register.md` |

**The test:** if resolving it is a single answer that makes the concern go away, it is an open question or a one-time escalation — not a risk. If resolving it requires ongoing work, monitoring, or acceptance of exposure that could still materialize later, it belongs in the register.

## When to Log a Risk vs. Escalate Directly

Log a risk register entry when a concern surfaced by an agent's Escalation Rules:
- Persists across multiple phases (identified in Design, still relevant in Deploy)
- Has a likelihood that is neither zero nor certain — a real "might happen"
- Has a material impact (technical, business, compliance, schedule, security, or data)
- Needs a named owner watching it, not just one decision to close it out

Escalate directly to Shafi (no register entry) when the concern is a one-time decision with a clear yes/no or choice, resolves immediately with no residual exposure, or is already covered by an existing entry (update it, don't duplicate).

**Worked distinction:** "Should we use MongoDB for the entity-extraction Bounded Context?" is a one-time escalation — Shafi decides, the question closes. "Entity extraction could miss PII in low-quality scanned PDFs, leaving a compliance gap" is a risk — it needs mitigation (quality tests, confidence thresholds, human-review triggers) and monitoring across Data, Quality, and Customer Validation.

## Risk Categories

Pick the single category where mitigation ownership sits; note any secondary angle in the description.

| Category | Covers |
|---|---|
| `technical` | Architecture, implementation, infrastructure — performance, scalability, technical debt, tooling limits |
| `business` | Market, adoption, value delivery — a feature missing its business goal, competitive pressure |
| `compliance` | Regulatory / framework exposure — SOC 2 control gaps, data residency, audit readiness |
| `schedule` | Timeline exposure — a dependency or rework loop threatening delivery cadence |
| `security` | Threat exposure — attack surface, access-control gaps, secrets handling |
| `data` | Data quality, lineage, integrity — extraction accuracy, classification correctness, retention |

## Register Fields

| Field | Meaning |
|---|---|
| Risk ID | `RISK-[NNN]`, product-scoped, sequential, never reused (same discipline as ADR numbering in `adr-authoring`) |
| Description | One or two sentences: what could happen, and what triggers it |
| Category | One of the six above |
| Likelihood | `Low` \| `Medium` \| `High` — chance it materializes within the current horizon |
| Impact | `Low` \| `Medium` \| `High` — consequence if it does |
| Severity | Derived from Likelihood × Impact (see scoring reference) |
| Owner | Agent role or "Shafi" — accountable for tracking and mitigating |
| Mitigation strategy | Concrete action to reduce likelihood, reduce impact, or prepare a response |
| Status | `open` \| `mitigated` \| `accepted` \| `closed` |
| Phase identified | Which SDLC phase surfaced the risk |
| Review cadence | How often the owner re-assesses (e.g. "every phase gate," "monthly") |

## Likelihood × Impact, in Brief

Severity is a function of Likelihood × Impact and ranges `Low` → `Medium` → `High` → `Critical`. Roughly: High-likelihood + High-impact is `Critical`; a High on one axis with a Medium on the other is `High`; two Lows are `Low`. Severity drives review cadence, not just optics — `Critical`/`High` risks are reviewed at every phase gate, `Medium` at least once per phase, `Low` at product retrospectives.

The full 3×3 matrix, the calibrated Low/Medium/High definitions for each axis, the register artifact template, and worked entries for this product live in **`references/register-template-and-scoring.md`** — load it when writing or scoring an entry.

## Status Lifecycle

`open` → `mitigated` (likelihood or impact reduced by concrete action, but exposure not fully gone) → `closed` (the underlying condition is gone). Or `open` → `accepted` (Shafi has explicitly decided the exposure is tolerable, with rationale recorded) → `closed` only if the condition later disappears. A risk is **never silently removed** — like ADRs, closed and accepted risks stay in the register with their final status as part of the record.

## The Risk-Driven Principle

Fairbanks' risk-driven method is the reasoning behind why a register exists at all: **scale architecture and mitigation effort to actual risk, not to habit or ceremony.** A cheap-to-reverse, narrowly-depended-upon concern does not warrant heavy design work; a concern that is expensive to change and broadly depended-upon does. An **architecturally-significant risk** is one that, if left unmitigated, could force a costly re-design — the severity that justifies deliberate mitigation and, usually, an ADR recording the decision.

This is why a register entry's severity should be read as a *budget signal*: a `Critical`/`High` entry earns proportional design investment; a `Low` entry is often a "watch it, don't over-engineer it" note. The full method — identify risks → select proportional techniques → evaluate — the architecturally-significant criterion, and how the register feeds `adr-authoring` and design decisions are in **`references/risk-driven-design.md`**.

## Where Risks Come From & Review

Any active agent may append an entry directly — the register has no single producing agent. `security-architect` logs compliance/security risks in Design; `data-engineer`/`data-architect` log data-quality risks in Data; `platform-engineer` logs operational risks in Deploy. Logging a risk does not require a separate escalation to Shafi, though he reviews the register at every phase gate.

At every phase gate (and on request): read the register in full; confirm each `open` entry's review cadence has been met; confirm every `Critical`/`High` mitigation is still active and not stalled; merge duplicates; summarize open `Critical`/`High` risks in the phase-gate report so Shafi sees standing exposure alongside the artifacts under review.

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Distinct from open questions | Represents ongoing exposure, not a single unanswered fact | A question masquerading as a risk |
| Likelihood and impact stated | Both populated with a reasoned Low/Medium/High | "Could be a problem" with neither assigned |
| Owner assigned | Every open/mitigated risk has a named owner | Nobody is watching it |
| Mitigation is concrete | Names a specific action, control, or monitoring practice | "We'll keep an eye on it" |
| Status kept current | Reflects actual state as of the last review cadence | `open` for months with no re-assessment |
| Never silently removed | Closed/accepted risks remain with final status | Deleted once no longer a concern |

## Anti-Patterns

- **The write-only register** — logged once, never revisited. A register with no `mitigated`/`closed` entries over the product's life is not being reviewed.
- **Ownerless risks** — recorded but not managed. Every `open`/`mitigated` risk needs an owner.
- **Risks that never close** — "open forever" is not a valid steady state; move to `mitigated`, `closed`, or `accepted`.
- **Vague entries** — no likelihood, no impact, no mitigation path. An entry must be actionable by someone who wasn't in the raising conversation.
- **Escalation inflation** — logging every one-time decision as a "risk" dilutes attention. Apply the test above first.
- **Duplicate risks** — the same exposure logged under different wording. Search the register before adding.
