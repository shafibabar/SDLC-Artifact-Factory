---
name: architecture-evaluation
product: [product slug]
version: 1.0.0
phase: design
owner: enterprise-architect
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: the design's risks and trade-off points against its top scenarios, and how each was resolved]
traces-to: [ideate/nfr-specification.md, design/architecture/container-diagram.md, [ADR ids]]
self-check: true
---

# Architecture Evaluation for [Product]

<!-- Path: artifacts/<product>/design/architecture/architecture-evaluation.md. Required at every profile; the shape differs.
     Lean: top 2 or 3 scenarios, a questionnaire, risks and non-risks, fitness functions; sensitivity and trade-off points only if met; no risk themes.
     With no scenario rated high on architectural impact: replace the Scenarios table with one sentence saying so.
     Standard: every scenario in the Architecture Handoff; risk themes only where two or more risks share a cause.
     Enterprise: as standard, every carried trade-off point resolved or carried, risk themes tied to business drivers, the product owner's confirmation.
     Scenarios and response measures come from nfr-specification; never invent a target here. Names no code.
     Never write "ATAM" as the method used: this is a lightweight self-check. "CDC" means Change Data Capture only. -->

**Readers:** [enterprise-architect, the product owner, backend-engineer, platform-engineer]
**Question it answers:** does the design, as it stands, meet its highest-impact scenarios, and where does it not, or only at a cost?

- **Profile:** [lean | standard | enterprise]
- **Self-check:** This is a self-check by the agent that designed the architecture: not independent, and not an ATAM (a full ATAM needs many stakeholders, an outside team and several days).

## Scenarios Evaluated

| Scenario | Rating (value, impact) | Response measure | Approaches that serve it |
|---|---|---|---|
| [NFR-… from the Architecture Handoff] | [(H, H)] | [the measure from the NFR] | [containers, ADRs and tactics] |

## Tactics Questionnaire

| Scenario | Tactic family | Question | Answer | Where in the design |
|---|---|---|---|---|
| [NFR-…] | [family, e.g. recover from faults] | [does the design do this, and at what cost?] | [yes / partial / no] | [container, ADR or component] |

## Risks

| ID | Scenario | Decision | Why it may fail | Action |
|---|---|---|---|---|
| R-1 | [NFR-…] | [the decision that may leave the scenario unmet] | [the reason] | [an ADR to write, a design change, or a user decision] |

## Non-Risks

| ID | Scenario | Decision | Reason it is safe |
|---|---|---|---|
| N-1 | [NFR-…] | [the decision] | [the reason; a non-risk with no reason is an assertion] |

## Sensitivity Points

| ID | Property | Response it governs | Value or limit that matters |
|---|---|---|---|
| S-1 | [a property of a component] | [the one response it is critical for] | [the value or limit] |

## Trade-off Points

| ID | Property | Raises | Lowers | Carried from | Resolution |
|---|---|---|---|---|---|
| T-1 | [a property that is a sensitivity point for two attributes] | [attribute pushed up] | [attribute pushed down] | [TP-n from the NFR handoff, or "found here"] | [ADR-n, or "accepted, no ADR: the reason", or "the user decides: the cost or scope question"] |

## Risk Themes

<!-- Enterprise always; standard only where two or more risks share a cause; omit at lean. -->

| ID | Risks | Systemic weakness | Business driver threatened |
|---|---|---|---|
| RT-1 | [R-1, R-2] | [the shared cause] | [the driver or key result at stake] |

## Fitness Functions

| Characteristic | Rule that must stay true | Check | Where it runs | Owner |
|---|---|---|---|---|
| [the attribute or rule] | [in a measurable form] | [an objective automated check] | [build, deployment gate, scheduled job, production monitor] | [who keeps it green, and the skill that builds it] |

## Actions

- [An ADR to write, a design change that reopens an approved artifact, or a decision for the user, each with an owner]

## Confirmation

<!-- Enterprise: the product owner's confirmation of the risks at the Design gate. Omit at lean and standard. -->

- **Product owner confirmation:** [who confirmed which risks and trade-off points, and when]

## Open Questions

- [A question for the product owner or a named role, with an owner; or "none"]
