# Example 2 — A B2B SaaS product: a fenceless draft rebuilt from paid-pilot evidence (standard profile)

Self-contained. A growing SaaS product at the **standard** profile, where this artifact is **optional**. It is written because the Scale table's trigger applied: Stage 2 showed two segments with different leaders, and a newly hired account executive is now quoting prices. It fixes three defects in the team's draft: a tier below the GTM's range, the main leader in every tier (no fences), and discounts with nothing in return.

## Input

> Product: **Ledgerline**, accounts-receivable software that small accounting firms use to chase their own clients' unpaid invoices.
>
> GTM strategy (approved): subscription; charging unit per firm per month, tiered by active clients chased; price strategy maximisation; ranges Practice $79–99, Practice Plus $139–179; list prices to be set in Stage 2.
>
> Canvas: WTP stated $60–100 acceptable, $150 expensive, over $250 too expensive (5 interviews); committed $89 (3 paid pilots). Value anchor ~6 partner hours a month at ~$120 (assumption). Cost to serve ~$15 per firm per month (hosting, bookkeeping API calls, payment fees).
>
> Stage 2 (12 weeks, 200 firms reached): 14 trials, 7 paid. 5–20-staff firms ranked **same-day import** and **approve-before-send** first. 20–50-staff firms ranked **partner reporting** (who owes what, by partner) and a **second bookkeeping connection** first; two of them said reminder **templates they cannot edit** would stop them buying. 2 losses logged as "price" turned out to be **no decision** (partners deferred to year-end).
>
> The team's draft:
> | | Starter $49 | Practice $89 | Plus $159 |
> |---|---|---|---|
> | Same-day import | ✓ | ✓ | ✓ |
> | Approve-before-send | ✓ | ✓ | ✓ |
> | Active clients | unlimited | unlimited | unlimited |
> | Extras | — | PDF export, themes | PDF export, themes, priority email, partner reporting |
>
> "Sales can discount up to 30% to close deals before month end."

## Working it

- **Starter at $49 sits below the GTM's range and below the committed $89.** Out of bounds (rule 5): it would need the GTM reopened, and the evidence argues against it (minivation). Dropped.
- **No fence anywhere.** Import and approvals, the leaders of the small-firm segment, are in every tier, and active clients are unlimited, so a 40-staff firm on Practice gets everything except partner reporting. The extras are fillers (themes, PDF export, priority email). Rebuilt: the charging unit becomes the fence, and partner reporting plus the second connection, leaders only the bigger firms value, sit above it.
- **Killer found:** locked templates would stop larger firms buying. Editable templates go into Practice Plus.
- **Discounts with no get**, granted by anyone, timed to month end: replaced by a give-get list.

## Output — the artifact (abridged: the value brief and presentation lines shortened)

```markdown
---
name: pricing-and-packaging
product: ledgerline
version: 1.0.0
phase: strategy
created: 2026-10-23
summary: Two tiers fenced by active clients and partner reporting, $89 and $159 per firm per month from 3 paid pilots and 7 Stage 2 sales; discounts only as give-get.
owner: product-strategist
profile: standard
traces_to: strategy/gtm-strategy.md; strategy/business-model-canvas.md; strategy/competitive-analysis.md
---

# Pricing and Packaging

## 1. From the GTM
Subscription · per firm per month, tiered by active clients chased · maximisation · Practice $79–99, Practice Plus $139–179.

## 2. Willingness-to-Pay Evidence
| Segment | Who | How many | Label | Range | Date |
|---|---|---|---|---|---|
| 5–20 staff | Managing partners | 5 | stated | $60–100 / $150 / $250 | 2026-07 |
| 5–20 staff | Managing partners | 3 pilots + 5 sales | committed | $89 | 2026-10 |
| 20–50 staff | Managing partners | 2 sales | committed | $159 (Stage 2 test price) | 2026-10 |

**Still to confirm:** 20–50-staff WTP above $159 (two sales only); test $179 on new sign-ups.

## 3. Segments
| Segment | Needs that differ | WTP | Found by |
|---|---|---|---|
| Single-office practice | One office manager chases everything | $89 committed | 5–20 staff, hourly billing |
| Multi-partner practice | Each partner owns clients; two bookkeeping tools | $159 committed (2) | 20–50 staff |

## 4. Leaders, Fillers and Killers
| Feature | Single-office | Multi-partner | Evidence |
|---|---|---|---|
| Same-day import | L | L | Ranked first by both |
| Approve-before-send | L | F | Ranked first (small); "nice" (large) |
| Partner reporting | F | L | Ranked first by 20–50-staff firms |
| Second bookkeeping connection | F | L | 4 of 6 larger firms run two tools |
| Locked reminder templates | F | **K** | 2 firms: "would stop us buying" |
| Themes, PDF export, priority email | F | F | Nobody ranked them |

## 5. Tiers and Fences
| | Practice | Practice Plus |
|---|---|---|
| Aimed at | Single-office | Multi-partner |
| Leaders inside | Import, approve-before-send | + partner reporting, second connection, editable templates |
| Active clients | up to 150 | up to 600 |
| List price | **$89** /firm/month | **$159** /firm/month |

| Boundary | Fence | Holds |
|---|---|---|
| Practice → Plus | 150 active clients **and** partner reporting | Multi-partner firms (all chase > 150 clients and need reporting) |

**Price basis:** value anchor ~$720/month (assumption; confirm from Stage 2 telemetry) · WTP committed $89 / $159 · floor ~$15. Maximisation: the evidence supports $89, inside the range; Plus at $159 with $179 to test.

## 6. Business Case (USD per year; calculate-business-case output)
| Segment | Size | Adoption | Customers | Price | Revenue | Cost to serve | Contribution |
|---|---|---|---|---|---|---|---|
| Practice (5–20 staff) | 3,000 | 4.0% | 120 | 1,068 | 128,160 | 180 | 106,560 |
| Practice Plus (20–50 staff) | 900 | 5.0% | 45 | 1,908 | 85,860 | 300 | 72,360 |
| **Total** | | | | | 214,020 | | 178,920 |

Fixed cost: 120,000. **Net: 58,920.** Break-even adoption at base price: 0.67x.

| Price \ Adoption | -20% | +0% | +20% |
|---|---|---|---|
| -20% | -11,107 | 16,116 | 43,339 |
| +0% | 23,136 | 58,920 | 94,704 |
| +20% | 57,379 | 101,724 | 146,069 |

**Inputs:** sizes counted from professional-body directories (home market); adoption from Stage 2 (7 paid of 200 reached, 3.5%, rounded up for year-end timing — labelled estimate); cost to serve from the canvas.
**Pessimistic row:** price and adoption both 20% lower loses ~$11k a year.
**Gate:** proceed. The case survives either input falling alone; it fails only if both fall, and the discount policy below protects price.

## 8. Discounts and Price Integrity
| Get | Give | Granted by | Limit |
|---|---|---|---|
| Annual prepay | 2 months free (GTM) | Anyone selling | — |
| Public case study | One month free | Account executive | Once per firm |
| Referral that converts | One month free | Automatic | — |

**Not a get:** month-end closing; "a competitor is cheaper" (answer with the import on their own data first). Above these: the product owner only.
**Tracked:** realised vs list; share of deals with any discount.

## 10. Launch and Change Rules
- Pilot firms keep $89 until their first annual renewal after GA, then move to list with 60 days' notice.
- A rise for existing customers: 60 days' notice; annual customers keep their price to renewal.
- Review triggers: price-labelled losses > 20% of losses in a quarter (after separating no decision); Practice Plus < 15% of new firms; cost to serve > $25.

## 11. Four-Failure Check
Feature shock — themes, PDF export, priority email kept as fillers in both tiers, no price weight. Minivation — Starter at $49 dropped. Hidden gem — firms over 50 staff, deferred by the kernel. Undead — 3 pilots and 7 sales.
```

## What changed, and why

- The fence is the charging unit plus a leader only multi-partner firms value; before, every tier held the small firms' leaders and nothing held the large firms up.
- The "price" losses were reclassified as no decision, so they argued for collective learning with the partners, not a cheaper tier.
- Discounts now buy something (term, a case study, a referral) and only the product owner goes beyond the list.
