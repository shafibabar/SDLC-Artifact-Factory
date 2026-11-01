# Example 2 — A B2B SaaS quarter: one committed and two aspirational Objectives (standard profile)

Self-contained. A growing SaaS product at the **standard** profile. It shows three Objectives that all serve one guiding policy, one of them committed because customers were promised something, and how the two types grade differently at quarter-end.

## Input

> Product: **Ledgerline**, accounts-receivable software for small accounting firms.
>
> Vision (approved), North Star implication: *share of billed hours paid within terms, across customer firms*.
>
> Strategy kernel (approved): **Crux:** switching costs a firm weeks; it must cost an afternoon. **Guiding policy:** make switching a same-day import and concentrate on firms of 5–50 staff; rules out a consultant implementation program, firms over 50 staff, and UK expansion in 2027. **Proximate objectives handed on:** "Firms that start a trial see their own overdue clients on day one." "Win the coming year-end switching window among 5–50-staff firms."
>
> Context: the year-end campaign promises every firm that switches in December that its history is fully imported before its first reminder run in January. Forty firms have signed up on that promise.

## Working it

- **Three Objectives, one policy.** Two come straight from the kernel's hand-off. The third is the year-end promise, which is how the "win the window" objective is kept: a firm that switches and finds its history wrong is lost. All three serve "same-day import, 5–50 staff". A fourth draft Objective, "launch the mobile app", served nothing in the policy and was cut (dog's dinner).
- **One committed Objective.** The import promise is contractual in spirit: customers rely on it. It is labelled committed, starts at 95% confidence and is expected to grade 1.0.
- **Two aspirational Objectives**, starting near 50% confidence and expected to grade about 0.7.
- **The draft's "500 paying firms" goal** from the old strategy became a KR target under Objective 2, not an Objective.

## Output — the OKR artifact

```markdown
---
name: okr-set
product: ledgerline
cycle: Q1 2027
version: 1.0.0
phase: strategy
created: 2026-10-21
summary: Q1 2027 OKRs for Ledgerline: day-one value in trials, win the year-end switch, and keep the import promise to every December switcher (committed).
owner: product-strategist
traces_to: strategy/vision-statement.md; strategy/strategy-kernel.md
---

# OKR Set — Q1 2027

## Strategy this set serves
**Crux:** switching costs a firm weeks; it must cost an afternoon.
**Guiding policy:** make switching a same-day import; concentrate on firms of 5–50 staff.
**North Star (from the vision):** share of billed hours paid within terms — this cycle moves it by bringing new firms' overdue invoices under reminders sooner.
**Levels:** solo product owner; product and company OKRs are one set.

## Objective 1 — Trial firms see their own overdue clients on the first day
**Type:** aspirational
**From the kernel's proximate objective:** "Firms that start a trial see their own overdue clients on day one."

| KR | Metric | Baseline | Target | Dir | Owner | Start confidence |
|---|---|---|---|---|---|---|
| KR1.1 | Share of trials with history imported on day one | 22% | 70% | ↑ | the product owner | 50% |
| KR1.2 | Share of trials that send a first reminder to a real overdue client within 3 days | 9% | 40% | ↑ | the product owner | 50% |
| KR1.3 | Trial-to-paid conversion | 8% | 15% | ↑ | the product owner | 45% |

**Candidate Initiatives:** cover partial payments in the import → KR1.1; trial opens on the imported overdue list → KR1.2.

## Objective 2 — Win the year-end switching window among 5–50-staff firms
**Type:** aspirational
**From the kernel's proximate objective:** "Win the coming year-end switching window among 5–50-staff firms."

| KR | Metric | Baseline | Target | Dir | Owner | Start confidence |
|---|---|---|---|---|---|---|
| KR2.1 | Paying firms of 5–50 staff | 180 | 500 | ↑ | the product owner | 40% |
| KR2.2 | Share of new firms that came from the switching-guide campaign | 0% | 50% | ↑ | the product owner | 50% |

**Candidate Initiatives:** year-end switch guides for the two common bookkeeping tools → KR2.2.

## Objective 3 — Every firm that switched in December starts January with its full history
**Type:** committed
**From the kernel:** the import advantage the guiding policy relies on; the year-end promise made to 40 firms.

| KR | Metric | Baseline | Target | Dir | Owner | Start confidence |
|---|---|---|---|---|---|---|
| KR3.1 | Share of December switchers whose imported totals reconcile to their bookkeeping tool before their first reminder run | n/a (new cohort) | 100% | ↑ | the product owner | 95% |
| KR3.2 | Reminders sent on wrong (unreconciled) balances | n/a | 0 | ↓ | the product owner | 90% |

## Health Metrics
| Metric | Healthy range | Status |
|---|---|---|
| Client complaints about reminders, per 100 firms per month (pairs KR1.2) | ≤ 2 | green |
| Support tickets per new firm | ≤ 1.5 | green |
| Product owner's hours on manual import fixes per week | ≤ 3 | green |

## Weekly Check-in Log
| Week of | KR | Confidence | Note |
|---|---|---|---|

## Grading (quarter-end)
| KR | Type | Expected | Final value | Grade | Committed miss: what happened and recovery plan |
|---|---|---|---|---|---|

| Objective | Grade (avg) | What we learned |
|---|---|---|
```

## Quarter-end — grading the two types differently

| KR | Type | Expected | Final | Grade | Read |
|---|---|---|---|---|---|
| KR1.1 | aspirational | ~0.7 | 58% | 0.75 | Win |
| KR1.2 | aspirational | ~0.7 | 31% | 0.71 | Win |
| KR1.3 | aspirational | ~0.7 | 12% | 0.57 | Short; informative |
| KR2.1 | aspirational | ~0.7 | 410 | 0.72 | Win |
| KR2.2 | aspirational | ~0.7 | 30% | 0.60 | Short |
| KR3.1 | committed | 1.0 | 37 of 40 | 0.93 | **Miss.** Three firms used a bookkeeping export format the importer misread. Recovery: manual reconciliation for the three by 2027-01-15; importer fix and a reconciliation check before every first run by 2027-02-01 |
| KR3.2 | committed | 1.0 | 0 | 1.0 | Delivered |

Objective 1 averages 0.68 and Objective 2 averages 0.66: healthy for aspirational Objectives. Objective 3 averages 0.96, which would look green on an aspirational scale but is **a failure for a committed Objective**: three customers were let down on a promise, and the recovery plan above is required, not optional. Grading KR3.1 as "0.93, a win" is exactly the mistake the type label prevents.
