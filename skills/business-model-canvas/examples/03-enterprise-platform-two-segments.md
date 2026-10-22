# Example 3 — An enterprise multi-tenant platform: two segments, a freemium tier and per-region cost to serve (hardest case)

Self-contained. The hardest common case, at the **enterprise** profile: a multi-tenant, multi-region platform with a high-availability commitment, data-residency obligations and two segments with different needs, channels and willingness to pay. It shows one full canvas with every entry tagged to its segment, a profile per stakeholder role, the freemium pattern's extra checks, cost to serve per segment and per region, a partner channel, and the enterprise block-by-block strength and weakness pass. The regulatory specifics (SOC 2, residency) are this product's, not the skill's rules.

## Input

> A B2B platform for organisations accountable for sensitive data: about 4,000 tenants (60 enterprise, the rest SMB) in EU and US regions, data-residency commitments per tenant, a 99.95% availability commitment. Product lines: Discover (finds and classifies sensitive data), Govern (policy and access reviews), Prove (audit evidence).
>
> Strategy kernel (approved): crux, data owners re-check findings by hand. Guiding policy: make every finding explainable and evidenced inside the tenant's region before widening scope; relies on in-region processing. Rules out new connectors before accuracy is proven, cross-region or central processing, and auto-remediation. Prove has its own line kernel: auditor acceptance, piloted with two audit firms.
>
> Evidence so far: SMB tenants arrive through a free Discover tier and upgrade; enterprise tenants buy through sales after a proof of concept. The product has years of revenue, so the full canvas is the right variant.

## Working it

- **One canvas, not three.** The three lines share one business model (same segments, one subscription, one cost base), so they share a canvas; Prove's different crux is a strategy matter, not a different model. One canvas, two segments.
- **Segment type: segmented.** SMB and enterprise want related things but differ in channel, relationship, willingness to pay and cost to serve, so every right-side entry is tagged [SMB] or [ENT].
- **Pattern: freemium** on the SMB side. Its checks are the ones a generic canvas misses: what one free tenant costs, the conversion rate, and the fence.
- **Three alternatives were drafted** (enterprise-only sales-led; usage-based per GB scanned; the chosen two-segment model). The per-GB model was rejected because its charging unit grows with data *volume*, not with the trust the kernel says customers buy, and it pushes tenants to scan less.

## Output — the canvas artifact (key sections)

```markdown
---
name: business-model-canvas
product: data-accountability-platform
version: 3.0.0
phase: strategy
created: 2026-10-22
summary: Two-segment model: freemium Discover converts SMB self-serve, sales-led enterprise buys all lines; in-region processing is the moat; free-tier cost per region is the top risk.
owner: product-strategist
canvas-type: bmc
traces_to: strategy/vision-statement.md; strategy/strategy-kernel.md; strategy/competitive-analysis.md; strategy/stakeholder-map.md
---

# Business Model Canvas — Data Accountability Platform

## Alternatives Considered
| Draft | Epicentre | Core idea | Decision |
|---|---|---|---|
| A | Customer | Enterprise only, sales-led | Rejected — loses the SMB funnel that produces most enterprise referrals |
| B | Finance | Usage-based, per GB scanned | Rejected — charging unit tracks volume, not trusted findings; tenants would scan less |
| C | Customer | Freemium SMB self-serve + sales-led enterprise | **Chosen** |

Pattern: freemium (SMB side).

## Value Proposition Canvas — [ENT] compliance officer (economic buyer)
Jobs from `jtbd-analysis` J1 (Opportunity Score 16.2), J3 (14.8).
| Kind | Item | Rank |
|---|---|---|
| Pain | P1 Audit evidence rebuilt by hand every year | extreme |
| Pain | P2 Data leaving the region breaches residency commitments | extreme |
| Gain | G1 Evidence an external auditor accepts without re-sampling | essential |

## Value Proposition Canvas — [ENT] data owner (user)
| Kind | Item | Rank |
|---|---|---|
| Pain | P3 Re-checking every flagged file by hand | extreme |
| Gain | G2 A finding with its reason and evidence shown | essential |

## Value Proposition Canvas — [SMB] IT lead (buyer and user)
| Kind | Item | Rank |
|---|---|---|
| Pain | P4 No idea what sensitive data sits in shared drives | high |
| Gain | G3 A first map without a project or a sales call | essential |

(Value maps omitted here; each reliever maps to P1–P4 or G1–G3. Auto-remediation was proposed as a gain creator and cut: the kernel rules it out.)

## 1. Customer Segments
- [ENT] Organisations of 2,000+ staff with residency obligations — 60 tenants — primary for revenue
- [SMB] Organisations of 50–500 staff — ~3,900 tenants — primary for acquisition
- Type: segmented. Economic buyer [ENT]: compliance officer; users: data owners. [SMB]: IT lead is both.

Evidence: validated

## 2. Value Propositions
- [ENT] Continuously provable data accountability, processed inside your region, unlike a hyperscaler suite that moves the data or an annual sampled audit — P1, P2, G1
- [ENT data owner] Findings you can act on without re-checking — P3, G2
- [SMB] Your sensitive-data map today, free, inside your own region — P4, G3

Evidence: validated [SMB, ENT buyer]; tested [ENT data owner — explainability pilot running]

## 3. Channels
- [SMB] Own, direct: free sign-up → in-product upgrade · after-sales: docs and community
- [ENT] Own, direct: sales-led proof of concept · Partner, indirect: two audit firms (Prove pilot) recommend the platform to their clients
- Delivery: tenant data processed in the tenant's chosen region (EU or US)

Evidence: validated [SMB, ENT direct]; hypothesis [audit-firm referral]

## 4. Customer Relationships
- [SMB] Automated onboarding and community — motivation: acquisition, then upsell
- [ENT] Dedicated customer success manager — motivation: retention

Evidence: validated

## 5. Revenue Streams
- [SMB] Freemium: Discover free up to 3 connected sources; subscription per tenant above it
- [ENT] Annual subscription, all lines · Mechanism: fixed list, segment-dependent; negotiated above 10,000 staff
- Charging unit: per tenant per year, tiered by connected sources (tracks the estate under accountability; predictable; grows as coverage grows)
- Value anchor: [ENT] audit-preparation effort removed and residency risk avoided; [SMB] the first map without a consultant
- Willingness to pay: [SMB] committed (observed upgrade rate); [ENT] committed (signed contracts), expansion to Prove stated only
- Price levels, tiers, fences, discount policy: `gtm-strategy` Pricing Model

Evidence: validated; Prove expansion: tested

## 6. Key Resources
- Intellectual (hard to copy or buy): per-tenant in-region processing architecture; per-tenant classification accuracy data from owner feedback
- Physical: EU and US region runtimes sized for 99.95%
- Human: compliance-domain experts curating control mappings

Evidence: validated

## 7. Key Activities
- Production: classification with explanations · Platform: operating two regions at 99.95% · Problem solving: mapping evidence to the control frameworks auditors test against (Prove)

Evidence: validated

## 8. Key Partnerships
| Partner | Type | Motivation | Provides | Status |
|---|---|---|---|---|
| Cloud provider (two regions) | buyer–supplier | optimisation, economy of scale | Regional infrastructure | exists |
| Two audit firms | strategic alliance | reduction of risk, acquisition of an activity | Auditor acceptance of evidence; referrals | pilot signed |

Evidence: validated [cloud]; tested [audit firms]

## 9. Cost Structure
- Orientation: value-driven
- Fixed: two regions at 99.95% (each region carries its own redundancy; the EU region costs more per tenant because it has fewer tenants); engineering; compliance experts
- Variable: scanning compute per connected source
- Cost to serve: [SMB free] compute for up to 3 sources per tenant per region · [SMB paid] + community support · [ENT] + dedicated success manager + proof of concept
- Customer acquisition cost: [SMB] near zero (product-led) · [ENT] sales cycle and proof of concept
- Fermi check: paying SMB and enterprise revenue covers free-tier compute in both regions at the current upgrade rate; it does not if the EU free base doubles with no rise in conversion (see risk 1)

Evidence: validated (billing data), except the EU free-tier projection: hypothesis

---

## Freemium Pattern Checks
- Cost to serve one free tenant: stated per region — pass
- Conversion: observed, per region — pass (US); EU below US — watch
- Fence: Govern, Prove and more than 3 sources are paid only — pass
- Paying tenants cover all free tenants: pass today; fails in the EU at double the free base (risk 1)

## Riskiest Assumptions → Tests
| Rank | Block | Risk type | We believe | Test | Pass if | Time box |
|---|---|---|---|---|---|---|
| 1 | Cost Structure | market | EU free-tier cost stays covered as the EU free base grows | Cap new EU free tenants at 3 sources and track EU conversion monthly | EU conversion ≥ 80% of US within two quarters | 2 quarters |
| 2 | Channels | customer | Audit firms refer enterprise clients | Count enterprise proofs of concept sourced by the two pilot firms | ≥ 4 in the pilot year | 12 months |
| 3 | Revenue | market | Enterprise tenants pay to add Prove at renewal | Offer Prove at 10 renewals | ≥ 4 add it | 2 quarters |

## Block Strengths and Weaknesses
| Block | Strength | Weakness |
|---|---|---|
| Value Propositions | In-region processing is valued and hard to copy | Data-owner trust still being earned (the kernel's crux) |
| Channels | SMB funnel is self-sustaining | Enterprise depends on a long sales cycle |
| Cost Structure | Compute scales with paid sources | Two fixed regions; the EU carries more fixed cost per tenant |

Outside forces most likely to break the model: a hyperscaler offering in-region DLP free (industry); a residency rule change requiring a third region (macro / regulatory).

## Coherence Check (excerpt)
- C3: pass — each segment pays for value it receives, inside committed WTP.
- C4: pass today; the EU free-tier Fermi fails at double the base → risk 1.
- C8: pass — no cross-region processing, no auto-remediation, no new connectors on the canvas.
- C10 (freemium): pass, with the EU watch item.
- B4: pass — dedicated success managers only at the enterprise price.
```

## What this example teaches

- **Segment tags keep one canvas honest.** Without [SMB] / [ENT] on every entry, the dedicated success manager would look affordable for everyone, and the freemium cost would vanish into an average.
- **The pattern adds the decisive check.** The generic questions passed; the freemium checks exposed the EU free-tier cost as the top market risk.
- **The kernel limits the canvas.** Auto-remediation was a tempting gain creator, and cross-region processing a tempting cost saving; both are ruled out by the kernel and stay off the canvas.
- **Per-region cost to serve** is where a multi-region, high-availability commitment shows up in a business model: the region with fewer tenants carries more fixed cost each.
