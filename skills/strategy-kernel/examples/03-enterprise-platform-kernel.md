# Example 3 — An enterprise multi-tenant platform: a company kernel and one line kernel

Self-contained. The hardest common case, at the **enterprise** profile: a multi-tenant, multi-region platform with high-availability and data-residency obligations and three product lines. It shows how one diagnosis serves the whole company, why two lines get actions instead of kernels, and when a line earns its own.

## Input

> A B2B platform for organisations accountable for sensitive data: 4,000 tenants (60 enterprise, the rest SMB) in EU and US regions, data-residency commitments per tenant, a 99.95% availability commitment. Three product lines: **Discover** (finds and classifies sensitive data), **Govern** (policy and access reviews) and **Prove** (audit evidence and reporting).
>
> Company vision (approved): "Every organisation accountable for sensitive data can know, govern and prove what it holds continuously, wherever that data lives, so trust between organisations, their customers and regulators rests on evidence instead of annual reconstruction."
>
> Competitive analysis (approved), summarised: alternatives are hyperscaler DLP suites (require data to move to the vendor's region), consultancies doing annual audits by sampling, and in-house scripts. The real, valued unique attribute: all processing runs inside the tenant's own region and boundary.
>
> Stakeholder map (approved), summarised: tenant compliance officers (buyers), data owners (daily users), external auditors (must accept the output), the platform's own SRE team (owns the 99.95%).

## Working the diagnosis

| Challenge | Important? | Addressable? | Verdict |
|---|---|---|---|
| Data owners re-check classification findings by hand, so "continuous" collapses back into manual review | Yes: Govern and Prove are only as good as Discover's findings (a chain-link system) | Yes: accuracy and explainability are in our hands | **Company crux** |
| Hyperscalers bundle DLP for free | Yes | No | Set aside |
| Auditors don't accept tool-generated evidence without a recognised format | Yes, for Prove | Yes | **A different crux, for Prove only** |
| Running every region to 99.95% is costly | Yes | Yes | Follows from the policy: a constraint on the actions, not the crux |

## Output 1 — the company kernel

```markdown
---
name: strategy-kernel
product: data-accountability-platform
version: 1.0.0
phase: strategy
created: 2026-10-19
summary: Strategy: owners re-check findings by hand, so continuous accountability fails; we make every finding explainable and evidenced in-region before widening scope.
owner: product-strategist
traces_to: strategy/vision-statement.md; strategy/competitive-analysis.md; strategy/stakeholder-map.md
---

# Strategy Kernel

## Diagnosis
Tenants buy continuous accountability, then their data owners re-check every classification by hand because they cannot see why a file was flagged. Every downstream line inherits that doubt: a policy review or audit report built on findings nobody trusts is worth nothing. Classification trust is the weakest link, and it caps the whole platform.
**Crux:** findings data owners act on without re-checking.

| Challenge set aside | Why not the crux |
|---|---|
| Hyperscaler DLP bundling | Important, not addressable |
| Auditor acceptance of evidence | Real but specific to Prove — handled by Prove's own kernel |
| Cost of 99.95% in every region | A constraint on the actions, not the obstacle |

## Guiding Policy
Fix the weakest link first: make every finding explainable and evidenced, inside the tenant's region, before widening what we scan or govern.
**Relies on:** in-region processing (competitive analysis: the attribute the alternatives lack), and the chain-link structure — trust gained in Discover lifts Govern and Prove at once.
**Rules out:**
- New connectors before accuracy is proven on the existing ones — because breadth multiplies untrusted findings.
- Cross-region or central processing to cut cost — because it breaks residency and the one advantage the policy relies on.
- Auto-remediation (deleting or moving data on a finding) — because acting automatically on a finding owners don't trust deepens the crux.

## Coherent Actions
| # | Action | Reinforces |
|---|---|---|
| 1 | Every finding carries its reason and the matching evidence, shown in-region | The policy |
| 2 | One-click owner confirm / reject, feeding per-tenant accuracy back into classification | 1 (explanations make the feedback meaningful) |
| 3 | Govern reviews only findings above a tenant-set confidence | 1, 2 (Govern spends attention where trust is earned) |
| 4 | Each region's runtime sized to keep the 99.95% commitment for actions 1–3 before any new workload | 1–3 (nothing in-region degrades the trust path) |

## Proximate Objectives
- Data owners in the enterprise tenants act on findings without re-checking them.
- Owner feedback measurably improves classification in every region.

## Review Trigger
**Wrong if:** owners still re-check findings that carry full explanations — **watched in:** confirm/reject telemetry and enterprise tenant reviews.
```

## Output 2 — which lines get their own kernel

| Line | Own kernel? | Why |
|---|---|---|
| **Discover** | No | Its challenge *is* the company crux; it receives actions 1 and 2 |
| **Govern** | No | Its value is capped by the same weakest link; it receives action 3 |
| **Prove** | **Yes** | It faces a different crux the company kernel set aside: auditor acceptance |

The test mirrors the vision cascade rule: a line kernel is warranted only when it faces a **different crux**, names the company kernel as its parent, and contradicts nothing the parent rules out. Teams below the lines get proximate objectives through the OKR set, never a kernel of their own.

## Output 3 — the Prove line kernel (body)

> **Diagnosis.** Prove's reports are accurate, but external auditors fall back to sampling because the evidence arrives in a format they do not recognise. **Crux:** evidence an auditor can accept without re-performing the work.
>
> **Guiding policy.** Map every report to the control frameworks auditors already test against, and let the auditor verify the evidence chain themselves. **Relies on:** the company kernel's explainable findings (actions 1–2) as the evidence source. **Rules out:** a proprietary "trust score" — because auditors cannot test it; building our own certification — because the crux is acceptance by existing auditors.
>
> **Coherent actions.** (1) Report sections keyed to control IDs. (2) An auditor read-only view that shows each finding's evidence in the tenant's region. (3) Pilot with two audit firms on enterprise tenants. Each reinforces the next.
>
> **Parent kernel:** company kernel. **Why its own:** a different crux. **Consistent with:** the auditor view stays in-region, so nothing the parent rules out is pursued.

This line kernel is where a regulated product's specific obligations appear (here, control frameworks auditors test against). Such product-specific rules belong in the product's own kernel, never in the skill's general guidance.
