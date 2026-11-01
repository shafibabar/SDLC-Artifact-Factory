# Example 3 — An enterprise multi-tenant, multi-region platform: per-region case, add-on and approval ladder (hardest case)

Self-contained. The hardest common case, at the **enterprise** profile where the artifact is **required**: a multi-tenant platform running in EU and US regions with per-tenant data-residency commitments and a 99.95% availability commitment, sold self-serve to small organisations and sales-led to regulated enterprises. It shows what enterprise adds: a residency and region fence, an add-on whose price range had to go back to the GTM, a business case per segment and region with a sensitivity grid that changes the plan, an approval ladder, and a value brief per buying-group role. Residency, auditors and supervisors appear because they are this product's facts, not general rules.

## Input

> A B2B platform for organisations accountable for sensitive data. Lines: **Discover** (find and classify), **Govern** (policy and access reviews), **Prove** (audit evidence).
>
> GTM strategy (approved): beachhead multi-region EU banks, sales-led; SMB self-serve through free Discover (up to 3 connected sources). Charging unit per tenant per year, tiered by connected sources. Maximisation; freemium is a funnel, not penetration. Ranges: Team €4,000–6,000; Enterprise €60,000–120,000 by sources; Prove add-on "set after its pilot". GTM's leaders / fillers / killers: in-region processing filler (SMB) / leader (ENT); Prove killer (SMB) / leader (ENT).
>
> Evidence since: Prove pilot with 2 EU banks closed, both signed at €30,000/yr (committed); 4 US insurers interviewed, stated €70,000–110,000 for Enterprise; SMB upgrade rate observed 1.2% of free tenants a year. Cost to serve per Enterprise tenant: EU €21,000 (per-tenant region pinning, residency-certified hosting), US €15,000. Fixed cost €2.4M a year, of which €0.5M is the US region's build-out and on-call.
>
> Win/loss: a US health system lost to **no decision** (the CISO's review never finished); procurement at an EU bank asked for 35% off "to match last year's consultancy quote".

## Working it

- **Prove's price is not in the GTM.** The pilot produced committed evidence, so the GTM's Pricing section was reopened, a €25,000–40,000 range added, and the GTM re-approved (v2.1) before this artifact set a list price.
- **Region is a fence and a cost line.** Team runs in one region of the tenant's choice; Enterprise pins each data source to its own region and carries the 99.95% commitment. Because EU and US cost to serve differ, the case is split by region.
- **The business case changed the plan.** With US Enterprise at stated WTP only, the case depends on a segment with no commitment. Reshape: the US region build-out (€0.5M) is phased behind two paid US POCs.
- **The 35% request had no get.** It is answered with the value brief for procurement and the ladder.

## Output — the artifact (abridged: segment table, presentation and some change rules shortened)

```markdown
---
name: pricing-and-packaging
product: data-accountability-platform
version: 1.0.0
phase: strategy
created: 2026-10-23
summary: Free, Team €5k and Enterprise €90k per tenant per year, fenced by sources, regions and the 99.95% commitment, plus Prove at €30k; US build-out phased behind paid POCs.
owner: product-strategist
profile: enterprise
traces_to: strategy/gtm-strategy.md (v2.1); strategy/business-model-canvas.md; strategy/competitive-analysis.md
---

# Pricing and Packaging

## 1. From the GTM
Freemium funnel + annual subscription · per tenant per year, tiered by connected sources · maximisation · Team €4,000–6,000; Enterprise €60,000–120,000; Prove add-on €25,000–40,000 (added in GTM v2.1).

## 2. Willingness-to-Pay Evidence
| Segment | Who | How many | Label | Range | Date |
|---|---|---|---|---|---|
| EU banks (ENT) | Heads of compliance | 2 contracts | committed | €90,000 | 2026-08 |
| EU banks — Prove | Heads of compliance | 2 pilots → contracts | committed | €30,000 | 2026-10 |
| US insurers (ENT) | Heads of compliance, CISOs | 4 | stated | €70,000–110,000 | 2026-09 |
| SMB (Team) | Owners / IT leads | upgrades | observed | €5,000; 1.2% of free tenants a year | 2026-10 |

**Still to confirm:** US Enterprise — two paid POCs (Stage 2).

## 4. Leaders, Fillers and Killers
| Feature | SMB | Regulated enterprise | Evidence |
|---|---|---|---|
| Explanations on every finding | L | L | Beta confirm rates |
| Per-source region pinning | F | L | Both bank contracts require it |
| 99.95% commitment | F | L | Procurement requirement in every ENT deal |
| Prove (control-mapped audit evidence) | K (set-up complexity) | L | Pilot; SMB interviews |
| Dedicated success manager | K (cost) | F | Interviews |
| SSO | F | L | Security reviews |

## 5. Tiers and Fences
| | Free | Team | Enterprise |
|---|---|---|---|
| Aimed at | SMB, trying it | SMB | Regulated enterprise |
| Leaders inside | Discover, explanations | + Govern | + region pinning, 99.95%, SSO |
| Connected sources | 3 | 25 | by band |
| Regions | 1 | 1 (tenant's choice) | per source |
| List price | €0 | **€5,000** /tenant/yr | **€90,000** /tenant/yr (60–120k by source band) |

| Boundary | Fence | Holds |
|---|---|---|
| Free → Team | 3 sources | SMBs with a real estate to cover |
| Team → Enterprise | Per-source region pinning, the 99.95% commitment, SSO | Regulated enterprises (their procurement requires all three) |

**Add-on:** Prove, **€30,000**/yr, Enterprise only — a killer for SMB, so never bundled into Team; an add-on rather than in Enterprise because only half of Enterprise tenants run audits on it.
**Price basis:** value anchor — the annual sampled audit it replaces (€150,000–250,000 per bank, consultancy quotes; estimate) · WTP committed €90,000 · floor €21,000 (EU cost to serve).

## 6. Business Case (EUR per year; calculate-business-case output)
| Segment | Size | Adoption | Customers | Price | Revenue | Cost to serve | Contribution |
|---|---|---|---|---|---|---|---|
| Enterprise — EU | 350 | 6.0% | 21 | 90,000 | 1,890,000 | 21,000 | 1,449,000 |
| Enterprise — US | 500 | 2.0% | 10 | 90,000 | 900,000 | 15,000 | 750,000 |
| Team — EU + US | 20,000 | 1.2% | 240 | 5,000 | 1,200,000 | 1,300 | 888,000 |
| Prove add-on (Enterprise) | 30 | 50.0% | 15 | 30,000 | 450,000 | 4,000 | 390,000 |
| **Total** | | | | | 4,440,000 | | 3,477,000 |

Fixed cost: 2,400,000. **Net: 1,077,000.** Break-even adoption at base price: 0.69x.

| Price \ Adoption | -20% | +0% | +20% |
|---|---|---|---|
| -20% | -328,800 | 189,000 | 706,800 |
| +0% | 381,600 | 1,077,000 | 1,772,400 |
| +20% | 1,092,000 | 1,965,000 | 2,838,000 |

**Inputs:** EU banks counted from the supervisors' register (2,000+ staff, multi-region); adoption EU from the audit-firm pipeline (estimate), US from stated interviews only; Team from the observed upgrade rate; cost to serve per region from the canvas.
**Pessimistic row:** both inputs 20% lower loses ~€329k.
**Gate: reshape.** €750k of contribution rests on US Enterprise, which has stated WTP only. Without it, and with the US build-out deferred (fixed €1.9M), base net is ~€697k and break-even adoption 0.73x. Decision: build the US region only after two paid US POCs; review at Stage 2 exit.

## 7. Presentation
Proposals show the Enterprise three-region configuration first, then the tenant's own; the self-serve page shows Enterprise, Team, Free left to right with Team marked as the usual choice. No "was" prices; the 99.95% commitment and every region surcharge on the first page.

## 8. Discounts and Price Integrity
| Get | Give | Granted by | Limit |
|---|---|---|---|
| Multi-year term (3 years) | up to 10% | Account owner | 10% |
| + named public reference | up to 20% total | Head of sales | 20% |
| Above 20% | — | Product owner with finance | business-case check |
| Prove in year one | none | — | pilot price has ended |

**Not a get:** matching a consultancy quote; quarter-end closing. Realised price vs list reviewed monthly.

## 9. Value Brief by Buying-Group Role
| Role | What "too expensive" means | Value line | Proof |
|---|---|---|---|
| Head of compliance | Budget is the audit line | Replaces the sampled audit (€150k+) | Pilot audit-firm results |
| Procurement | Above the consultancy quote | Continuous vs once a year; the quote buys one sample | Scope comparison, 3-year give-get |
| CISO's team | A new data processor | Processing never leaves the region | Architecture pack — not a discount |
| Finance | Payback | Under a year against the audit line | Payback table |

**The 35% request:** answered with the procurement row and the ladder (10% for a 3-year term). Price-labelled losses are logged separately from **no decision** (the US health system was no decision).

## 10. Launch and Change Rules
- Pilot customers' Prove price (€30k) holds to first renewal; then list, 90 days' notice.
- Region surcharges change only with 90 days' notice and at renewal.
- Review triggers: average Enterprise discount > 12%; Team upgrades < 0.9% of free tenants; EU cost to serve > €25k; two US POCs signed (reopen the US case).

## 11. Four-Failure Check
Feature shock — success manager kept out of Team. Minivation — none; €90k is under half the value anchor but inside committed WTP; test €100k for 3-region estates. Hidden gem — US insurers, gated by POCs. Undead — committed in EU.
```

## What the enterprise shape added

- A fence built from contract terms (region pinning, 99.95%, SSO) that only the regulated segment's procurement requires, so no SMB feels a leader withheld.
- A business case split by region, whose sensitivity grid moved €0.5M of fixed cost behind evidence instead of approving the plan "with risk".
- An approval ladder that answered a 35% request with a 3-year term, and a value brief that treats the CISO's objection as a security question, not a price one.
