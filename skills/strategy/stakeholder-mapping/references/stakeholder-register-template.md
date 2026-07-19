---
name: stakeholder-map
product: Data Estate Mapping and Compliance Intelligence
version: 1.0.0
phase: strategy
created: 2026-07-19
owner: product-strategist
---

# Stakeholder Map

## Stakeholder Register

Power and Interest scored 1–3 (low/medium/high). Customer-side roles are archetypes drawn from the ICP.

| Name/Role | Category | Power | Interest | Quadrant | Engagement Need |
|---|---|---|---|---|---|
| Maya Chen — Compliance Officer (customer) | Primary user | 2 | 3 | Keep Informed → cultivate into champion | Early access to gap-report design; monthly product updates in her language (controls, evidence), not engineering language |
| CTO / VP Engineering (customer) | Buyer / economic decision-maker | 3 | 2 | Keep Satisfied | ROI framing (audit-prep hours saved), security architecture summary, pricing clarity before renewal conversations |
| IT / DevOps Lead (customer) | Influencer + technical implementer | 2 | 3 | Keep Informed | Deployment docs, Helm chart quality, upgrade path; a bad first deployment loses the account |
| CISO / IT Security (customer) | Blocker | 3 | 1 | Keep Satisfied | Security architecture brief (zero data egress, mTLS, Principle of Least Privilege) delivered *before* the deployment request is raised |
| External SOC 2 auditor | Beneficiary | 2 | 1 | Monitor | Evidence exports must match what auditors accept; validate format with a practising auditor at Stage 1 |
| Legal / Data Privacy Officer (customer) | Influencer / potential blocker | 2 | 2 | Keep Informed | DPA template, data-flow diagram showing no processor relationship is created |
| Design partners (3–5 companies) | Primary users + co-creators | 2 | 3 | Manage Closely | Bi-weekly feedback sessions during closed beta; roadmap input; named contact |
| Shafi — product owner | Internal | 3 | 3 | Manage Closely | Reviews every phase-gate artifact; approves each chunk before build |

## Power/Interest Grid

```
High Power  │  Keep Satisfied         │  Manage Closely
            │  · CTO / VP Eng (buyer) │  · Shafi (product owner)
            │  · CISO (blocker)       │  · Design partners
            │─────────────────────────│──────────────────────────
Low Power   │  Monitor                │  Keep Informed
            │  · SOC 2 auditor        │  · Maya Chen (Compliance Officer)
            │                         │  · IT / DevOps Lead
            │                         │  · Legal / DPO
            └─────────────────────────┴──────────────────────────
                 Low Interest              High Interest
```

## Engagement Plan

| Quadrant | Approach | Frequency | Responsible |
|---|---|---|---|
| Manage Closely | Bi-weekly design-partner sessions; artifact review with Shafi at every chunk | Weekly / bi-weekly | Shafi |
| Keep Satisfied | Buyer: ROI one-pager at trial start and pre-renewal. CISO: unprompted security brief before deployment request | Monthly, plus event-driven | Shafi |
| Keep Informed | Release notes and compliance-language changelog to users, deployment notes to IT leads | Monthly | Shafi |
| Monitor | Auditor-format validation at Stage 1; re-check when evidence templates change | At milestones | Shafi |

## Blocker Risk Register

| Stakeholder | Concern | Risk Level | Mitigation Approach |
|---|---|---|---|
| CISO / IT Security | "A tool that reads all our files is itself our biggest data risk" | High | Security architecture brief: zero data egress, in-cluster processing, mTLS via service mesh, read-only scoped credentials; offer network-traffic verification during POC |
| IT / DevOps Lead | "Another thing to deploy and keep alive" | Medium | Single Helm chart install, documented resource footprint, upgrade path tested every release |
| Legal / DPO | "Does this create a new data-processor relationship?" | Medium | Data-flow diagram showing no customer data reaches the vendor; DPA template ready before it is asked for |
| CTO (buyer) | "Compliance tooling is a cost centre — why now?" | Medium | Anchor to the buying trigger: the enterprise customer questionnaire or audit window that started the evaluation |

## RACI — Key Decisions

| Decision | Responsible | Accountable | Consulted | Informed |
|---|---|---|---|---|
| Product direction changes | product-strategist agent | Shafi | Design partners | All customer-side stakeholders |
| Major architecture decisions | enterprise-architect agent | Shafi | domain-modeler agent | Design partners' IT leads |
| Release gates (phase advance) | Governance hooks | Shafi | test-strategist agent | Design partners |
| Pricing and packaging | product-strategist agent | Shafi | Design-partner buyers | All prospects |
| Compliance evidence format | requirements-analyst agent | Shafi | External SOC 2 auditor | Compliance-officer users |
