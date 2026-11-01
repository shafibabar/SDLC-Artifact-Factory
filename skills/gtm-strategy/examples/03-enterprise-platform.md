# Example 3 — An enterprise multi-tenant platform: sales-led into a regulated vertical (hardest case)

Self-contained. The hardest common case, at the **enterprise** profile: a multi-tenant, multi-region platform (EU and US regions, per-tenant data-residency commitments, a 99.95% availability commitment) with two segments that buy differently. It shows what enterprise adds: a buying committee with a consensus kit, a whole-product map whose gaps go to the roadmap, the chasm diagnostic choosing the beachhead, a positioning refresh fired by a lost deal, leaders / fillers / killers with fences and a discount policy, and the next bowling-alley pin. Residency, auditors and certifications appear because they are this product's facts, not general rules.

## Input

> A B2B platform for organisations accountable for sensitive data: 4,000 tenants (60 enterprise, the rest SMB). Lines: **Discover** (find and classify), **Govern** (policy and access reviews), **Prove** (audit evidence).
>
> Strategy kernel (approved): crux, data owners re-check findings by hand. Guiding policy: make every finding explainable and evidenced inside the tenant's region before widening scope; relies on in-region processing. Rules out new connectors before accuracy is proven, cross-region or central processing, and auto-remediation.
>
> Competitive analysis (approved): alternatives A1 wait for the audit window, A2 no decision (CISO's team blocks new data processors), A3 consultancy annual audit, A4 in-house scripts, A5 enterprise discovery suites, A6 hyperscaler DLP, A7 a rumoured hyperscaler bundle (future entrant). D1 in-region processing (verified vs one suite), D2 every finding carries its reason and evidence (verified for us). Category lens: "data discovery" (suites lead) vs subcategory "in-region data accountability for multi-region regulated organisations". Win/loss: two beta wins (EU bank on D1, US insurer on D2); one loss to A7 from a single-cloud EU retailer, which fired the Positioning Refresh Trigger; one no decision at a US health system (CISO's review unfinished).
>
> Business model canvas (approved): [SMB] freemium Discover free up to 3 connected sources, subscription above; [ENT] annual subscription, all lines; charging unit per tenant per year tiered by connected sources; WTP committed in both segments (upgrade rate; signed contracts); Prove expansion stated only.
>
> Stakeholder map (approved): §2 holds a buying committee for EU banks (head of compliance, CISO's team, data owners, procurement) and one for SMB self-serve tenants, with belief, objection, proof, collective-learning plan and consensus kit.

## Working it

**Chasm diagnostic first.** The six beta tenants were won on vision ("be first to continuous accountability"), and only the two EU banks could reference each other. That is the early-adopter side of the chasm. The beachhead must be a pragmatist segment where wins reference each other: EU banks with multi-region estates.

**The lost deal narrows the ICP.** The single-cloud retailer valued D1 less, because a hyperscaler bundle would give it in-region classification for free. Refresh result: single-cloud, single-region organisations become a disqualifier, and the message leads with D2 (findings owners act on) plus auditor acceptance, which a bundle that only classifies does not offer. The beachhead did not change, so the kernel is not reopened.

## Output — the GTM strategy artifact (abridged: the SMB self-serve funnel, objections and metrics shortened)

```markdown
---
name: gtm-strategy
product: data-accountability-platform
version: 2.0.0
phase: strategy
created: 2026-10-23
summary: Win multi-region EU banks sales-led on explainable in-region findings their auditors accept; SMB self-serves via free Discover; EU insurers are the next pin.
owner: product-strategist
profile: enterprise
traces_to: strategy/strategy-kernel.md; strategy/competitive-analysis.md; strategy/business-model-canvas.md; strategy/stakeholder-map.md
---

# Go-to-Market Strategy

## 1. Beachhead Segment

Carries out the kernel's guiding policy: explainable, in-region findings before wider scope.

| Criterion | A: EU banks, 2,000+ staff, multi-region | B: any regulated enterprise | C: US health systems |
|---|---|---|---|
| Reason to buy now | ✓ supervisory data-inventory reviews | ~ | ✓ |
| One coherent channel | ✓ two audit firms already piloting Prove | ✗ | ~ |
| Accessible economic buyer | ✓ head of compliance | ~ | ~ |
| No entrenched competitor | ~ suites present, none in-region | ✗ suites | ✗ |
| Winnable now | ✓ 2 beta wins | ✗ | ✗ no decision in beta |
| Reference base | ✓ banks reference banks | ✗ | ~ |
| WTP evidence | committed (2 contracts) | mixed | stated |
| Kernel fit | inside | inside | inside |

**Chosen:** A. **Next pin:** EU insurers — same supervisors' expectations, same audit firms, same residency needs; ~80% of the whole product transfers (missing: insurer-specific control mappings).

## 2. Ideal Customer Profile

| Attribute | Definition |
|---|---|
| Size | 2,000+ staff |
| Type | EU banks with data in two or more cloud regions |
| Buying triggers | Supervisory review scheduled; a failed sampled audit; a residency incident |
| Observed in | Beta tenant 1 (EU bank) |
| Disqualifiers | Single cloud and single region (a hyperscaler bundle will suffice — loss of 2026-09-11); needs auto-remediation (ruled out by the kernel); wants 100+ connectors on day one |

### Buying committee

**Committee:** `strategy/stakeholder-map.md` §2, segment "EU banks": head of compliance (economic buyer, Teacher likely), CISO's team (Skeptic or Blocker likely; the no-decision risk), data owners (Go-Getter likely), procurement (Guide likely); the bank's external auditor as an outside party. Belief, objection and proof per role, and the consensus kit, are in the map.
**Mobilizer hypothesis:** head of compliance; confirmed in beta tenant 1, not yet in tenant 4.
**Blocker plan:** the Mobilizer brings the CISO's team the architecture pack before any proposal (the health-system no decision started with a proposal).
**Where consensus is built:** a collective-learning session on the cost of the sampled audit, before any POC.
**Consensus kit:** the map's one page per role, delivered by the Mobilizer through the proof points in §4.

### Whole product (beachhead)

| Ring | Item | Status |
|---|---|---|
| Generic | In-region Discover + Govern + Prove | ✓ |
| Expected | SSO, audit logging, 99.95% commitment | ✓ |
| Augmented | SIEM integration | ~ (roadmap theme) |
| Augmented | Vendor's own independent security attestation | ✗ in progress (roadmap theme) |
| Augmented | Audit-firm references | ~ 2 firms piloting |

## 3. Positioning

**Alternatives** (competitive analysis §1): A1–A7; the beachhead mostly uses A3 (consultancy sampled audit) and stalls on A2.
**Unique attributes:** D2 (lead, verified for us), D1 (verified vs one suite; hypothesis vs others).
**Category:** subcategory — "in-region data accountability". Rejected: "data discovery" (imports connector breadth, where the suites lead by years).

> For multi-region EU banks facing supervisory data reviews, who still prove compliance by sampled audit, the platform is the in-region data-accountability platform whose findings data owners act on and auditors accept. Unlike an annual consultancy audit, every finding is continuous, explained and evidenced inside the bank's own region.

## 4. Messaging

**Reframe:** "A sampled audit doesn't tell you what you hold; it tells you what someone happened to look at — and your supervisor now knows the difference."
**Headline:** Know, prove and keep it in-region.
**Proof points:** continuous findings with reasons (beta confirm rates); evidence two audit firms are piloting; processing never leaves the tenant's region; customer story: beta tenant 1 (named with consent) replaced its annual sample.

## 5. Channel Strategy

**Primary:** sales-led, sourced through the two audit firms piloting Prove. **Supporting:** SMB self-serve (free Discover) as a separate funnel; banking-compliance community content. **Deferred:** events until three bank references exist.

## 6. Sales and Distribution Model

| Decision | Choice |
|---|---|
| Sales motion | Sales-led [ENT]; self-serve [SMB] |
| Contract model | Annual, multi-year with give-get |
| Procurement path | MSA, security review, data-processing agreement per region |
| Trial model | POC capped at 30 days, success criteria agreed before it starts (indefinite POCs are a chasm symptom) |
| Expansion motion | More connected sources; Prove added |
| Buying group | Head of compliance as Mobilizer; collective-learning session first |

## 7. Pricing

**WTP evidence:** [ENT] committed, 2 signed contracts; Prove expansion stated (4 interviews). [SMB] committed, observed upgrade rate.
**Model:** [SMB] freemium funnel; [ENT] annual subscription. **Charging unit:** per tenant per year, tiered by connected sources (tracks the estate under accountability; predictable; grows with coverage). Rejected: per GB scanned (pushes tenants to scan less).
**Price strategy:** maximisation. Freemium is a funnel, not penetration: the fence is 3 sources.
**Ranges:** Team €4,000–6,000/yr; Enterprise €60,000–120,000/yr by sources; Prove add-on range set after its pilot.

| Feature | [SMB] | [ENT] |
|---|---|---|
| In-region processing | Filler | Leader |
| Explanations on every finding | Leader | Leader |
| Control-mapped audit evidence (Prove) | Killer (complexity) | Leader |
| Dedicated success manager | Killer (cost) | Filler |

**Fences:** connected sources; regions; Prove only in Enterprise.
**Discount policy:** account owner up to 10% for a multi-year term; more needs the product owner and a named reference in return; no discount without a give-get.
**Note:** the full tier matrix, list prices, pricing business case and approval ladder are in `strategy/pricing-and-packaging.md` (the `pricing-and-packaging` skill), which works inside these ranges.

## 8. Launch Sequencing (Enterprise line)

| Stage | Audience | Exit criteria |
|---|---|---|
| 1 — Closed beta | 6 tenants (done) | Met for banks: value confirmed from owners' confirm/reject telemetry and 2 contracts; Mobilizer held in 1 of 2 banks |
| 2 — Limited availability | 10 EU banks via audit firms | 3 banks referenceable to each other; POCs close within 30 days; price within range; no-decision rate and reasons logged |
| 3 — GA, then next pin | EU insurers | Chasm diagnostic passes for banks |

**Positioning refresh:** fired on 2026-09-11 (A7 loss); next at Stage 2 exit.

## 9. GTM Success Metrics (excerpt)

| Metric | Target |
|---|---|
| POC-to-contract within 30 days | Set from the first 5 Stage 2 POCs |
| Deals lost to no decision | Baseline in Stage 2, then reduce |
| Bank references referenceable to each other | ≥ 3 before GA |
```

## What the enterprise shape added

- The chasm diagnostic, not the launch stage, chose the beachhead: six wins on vision and one mutual reference meant "scale now" would have been premature.
- The lost deal changed the ICP and the lead proof point but not the beachhead, so the GTM changed and the kernel did not.
- The buying committee explains the no-decision outcome and gives the Mobilizer something to do about it before any proposal.
- Leaders, fillers and killers show why Prove sits behind the Enterprise fence: it is a killer for SMB buyers.
