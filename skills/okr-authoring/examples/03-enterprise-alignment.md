# Example 3 — An enterprise multi-tenant platform: aligned, not cascaded (hardest case)

Self-contained. The **enterprise** profile: a multi-tenant, multi-region platform with a high-availability commitment, data-residency obligations and three product lines. It shows the cascade draft the teams first wrote, why it fails, and the aligned version: company, product line and team sets, each with its own KRs, each naming the Objective it advances, with a sideways dependency check. It also shows where an availability commitment belongs (a health metric, not an Objective).

## Input

> A B2B platform for organisations accountable for sensitive data: 4,000 tenants (60 enterprise) in EU and US regions, per-tenant data residency, a 99.95% availability commitment. Product lines **Discover** (classification), **Govern** (access reviews) and **Prove** (audit evidence).
>
> Company vision North Star: *share of tenants whose estate is continuously provable*. Discover's line North Star (from the vision cascade): *classified share of each tenant's connected estate*.
>
> Company strategy kernel: **Crux:** findings data owners act on without re-checking. **Guiding policy:** fix the weakest link first; make every finding explainable and evidenced in-region before widening scope; rules out new connectors before accuracy is proven, cross-region processing and auto-remediation. **Proximate objectives handed on:** "Data owners in the enterprise tenants act on findings without re-checking them." "Owner feedback measurably improves classification in every region." Prove has its own line kernel (crux: evidence an auditor can accept), with a pilot with two audit firms promised for March.

## The cascade draft (rejected)

| Level | Objective | KR |
|---|---|---|
| Company | Owners trust findings | Owner confirm rate on findings from 55% to 80% |
| Discover line | Owners trust Discover's findings | Owner confirm rate from 55% to 80% |
| Classification team | Owners trust our classifications | Owner confirm rate from 55% to 80% in the EU |
| Connectors team | Owners trust findings | Owner confirm rate from 55% to 80% for new connectors |

Every level copied the level above and narrowed it. Four failures at once:
- **Cascade.** No team wrote a KR about its own lever; nobody can tell which team moved the number.
- **Against the policy.** The connectors team's KR assumes new connectors, which the guiding policy rules out until accuracy is proven.
- **Sideways blind spot.** The confirm rate depends on the regional runtime team (explanations must be computed in-region) but that team has no KR anywhere.
- **Business as usual hiding.** The runtime team's draft Objective was "keep 99.95% availability": work that happens anyway. That is a health metric.

## Output 1 — the company set (summary)

```markdown
---
name: okr-set
product: data-accountability-platform
cycle: H1 2027 (annual layer) / Q1 2027
version: 1.0.0
phase: strategy
created: 2026-10-21
summary: Company Q1 2027 OKRs: data owners act on findings without re-checking, owner feedback improves classification in every region, and the Prove audit pilots start on the promised date.
owner: product-strategist
traces_to: strategy/vision-statement.md; strategy/strategy-kernel.md; strategy/prove-strategy-kernel.md
---
```

| # | Objective | Type | KRs (company level) |
|---|---|---|---|
| C-O1 | Data owners in enterprise tenants act on findings without re-checking them | aspirational | Share of findings acted on without a manual re-check, enterprise tenants: 30% → 65% · owner confirm rate: 55% → 80% |
| C-O2 | Owner feedback measurably improves classification in every region | aspirational | Regions where confirm rate rose quarter on quarter: 0 of 2 → 2 of 2 |
| C-O3 | The Prove audit pilots start on the date promised to both audit firms | **committed** | 2 of 2 audit firms receive control-mapped reports for their pilot tenants by 2027-03-01 (start confidence 90%) |

**Health metrics (company):** availability per region ≥ 99.95% · cross-region data copies = 0 · enterprise tenant support escalations ≤ 4 per month.

The availability commitment is a health metric: the set is not trying to improve it, and must not break it while pursuing C-O1 and C-O2.

## Output 2 — the Discover line set, aligned

| # | Objective | Type | Aligns to | KRs (the line's own) |
|---|---|---|---|---|
| D-O1 | Every Discover finding shows why it was flagged, in the tenant's region | aspirational | C-O1 | Share of findings with a reason and matched evidence shown: 10% → 90% · median time an owner spends on a finding: 4 min → 1 min |
| D-O2 | Owners' confirm and reject decisions feed back into classification | aspirational | C-O2 | Share of owner decisions used in the next model update per region: 0% → 70% |
| D-O3 | Accuracy on existing connectors is proven before any new connector | aspirational | C-O1 (and the policy's rules-out) | Connectors meeting the per-tenant precision bar: 2 of 5 → 5 of 5 |

## Output 3 — team sets in Discover, aligned and checked sideways

| Team | Objective | Aligns to | Own KR (not a copy) | Depends on (sideways) |
|---|---|---|---|---|
| Classification | Explanations an owner can read in under a minute | D-O1 | Owner "explanation was clear" rating: n/a → ≥ 4 of 5 | Regional runtime: explanation compute in-region (holds KR below) |
| Regional runtime | Explanations computed in-region for every enterprise tenant | D-O1 | Enterprise tenants with in-region explanation compute: 0 of 60 → 60 of 60 | Platform engineering: capacity per region |
| Connectors | The five existing connectors meet the precision bar | D-O3 | Connectors at precision bar: 2 → 5 | Classification: per-tenant precision dashboard |

Each team writes the KR for its own lever, names the line Objective it advances, and lists who it depends on. The runtime team now has a real Objective, and its availability duty stays in the health metrics. No team KR is a parent KR with a smaller number, so each can fail or succeed on its own and the line can see which lever moved.

**Count check:** the company has three Objectives, Discover three, each team one: within 3–5 per level for company and line; teams below a line may hold one.

## Where product-specific rules go

Data residency, the 99.95% commitment and the audit-firm pilot are this product's obligations. They appear here, in this product's set, never in the skill's general rules.
