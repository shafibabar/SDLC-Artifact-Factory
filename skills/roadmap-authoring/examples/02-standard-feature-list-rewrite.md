# Example 2 — A B2B SaaS roadmap rewritten from a feature-and-date list (standard profile)

Self-contained. A growing SaaS product at the **standard** profile, where the strategy kernel, the OKR set, a GTM strategy and a stakeholder map exist. The draft the team brought was the commonest roadmap failure: features with dates. This example shows the rewrite into themes, a scorecard, a committed date that is allowed to stay, policy-cited exclusions, a pre-wired review and the external view.

## Input

> Product: **Ledgerline**, accounts-receivable software for small accounting firms.
>
> Vision (approved), North Star: *share of billed hours paid within terms, across customer firms*.
>
> Strategy kernel (approved): **Crux:** switching costs a firm weeks; it must cost an afternoon. **Guiding policy:** make switching a same-day import and concentrate on firms of 5–50 staff that bill hourly. **Rules out:** a partner/consultant implementation program; firms over 50 staff; UK expansion in 2027. **Coherent actions:** (1) the import covers 100% of the two common bookkeeping tools' data; (2) a trial that starts from the imported history; (3) year-end switch guides; (4) reminder templates the office manager approves before they send.
>
> OKR set Q1 2027 (approved): **O1** (aspirational) trial firms see their own overdue clients on day one — KR1.1 day-one import 22% → 70%; KR1.2 first real reminder within 3 days 9% → 40%; KR1.3 trial-to-paid 8% → 15%. **O2** (aspirational) win the year-end switching window — KR2.1 paying 5–50-staff firms 180 → 500; KR2.2 new firms from the switch-guide campaign 0% → 50%. **O3** (**committed**) every December switcher starts January with its full history — KR3.1 100% reconciled before their first reminder run; KR3.2 zero reminders on unreconciled balances.
>
> GTM strategy: one beachhead (5–50-staff hourly-billing firms); the stakeholder map lists two design-partner firms, a part-time sales contractor and a three-person accountant advisory board as "Manage Closely".

## The draft (rejected)

| Quarter | Item | Date |
|---|---|---|
| Q4 2026 | Importer v2 | Nov 30 |
| Q1 2027 | Mobile app | Feb 15 |
| Q2 2027 | AI reminder drafting | May 1 |
| Q3 2027 | UK VAT invoices | Aug 1 |
| Q4 2027 | Partner portal | Nov 1 |

Five failures: every row is a solution; dates run a year out; nothing names a KR (it reads as if written before the OKR set, with its own goals); two rows (UK, partner portal) are things the guiding policy rules out; and there is no disclaimer, confidence or exclusions list.

## Working it

- **Themes from the KRs, not from the draft.** Each KR got at least one customer problem. "Importer v2" became the problem it answers; the mobile app and AI drafting served no KR and reinforced no Now theme, so they left the roadmap with a reason.
- **Weakest link:** the import. A trial, a campaign and reminders are all worthless if the history is wrong, and O3 is a promise. Theme A goes first regardless of score.
- **Coherence:** A feeds B (the trial runs on imported data); C (the campaign) sends firms into A and B; each Now theme names what it reinforces.
- **The committed date stays.** "Before each December switcher's first January reminder run" is carried by committed KR3.1. It is marked committed; nothing else has a date.

## Output — the roadmap artifact (internal view)

```markdown
---
name: strategic-roadmap
product: ledgerline
version: 1.0.0
phase: strategy
created: 2026-10-22
summary: Ledgerline roadmap: same-day history import first (committed for December switchers), trial on real data and the year-end campaign in Now; UK, partners and 50+ firms excluded.
owner: product-strategist
profile: standard
format: now-next-later
traces_to: strategy/vision-statement.md; strategy/strategy-kernel.md; strategy/okrs.md; strategy/gtm-strategy.md
---

# Strategic Roadmap — Ledgerline

## Disclaimer
This roadmap is a statement of intent and direction. It reflects our current understanding and will change as we learn. Confidence describes how sure we are about sequence and scope, not importance. Nothing here is a delivery date unless marked **committed**.

## Vision
Small accounting firms get paid for every hour they bill, on time — North Star: share of billed hours paid within terms.

## Objectives this roadmap serves
**Guiding policy:** make switching a same-day import; concentrate on firms of 5–50 staff that bill hourly.
| Objective | Type | Key Results |
|---|---|---|
| O1 — Trial firms see their own overdue clients on day one | aspirational | KR1.1, KR1.2, KR1.3 |
| O2 — Win the year-end switching window | aspirational | KR2.1, KR2.2 |
| O3 — Every December switcher starts January with its full history | **committed** | KR3.1, KR3.2 |

## How this was prioritised
**Weakest link:** the import (theme A) — every other theme's value is capped by it.
**Framework:** value / effort / confidence scorecard; score = value × confidence ÷ effort.
| Theme | Value | Effort | Confidence | Score |
|---|---|---|---|---|
| A | 5 | 4 | 1.0 | 1.25 (first regardless: weakest link) |
| B | 4 | 2 | 1.0 | 2.0 |
| C | 4 | 2 | 0.8 | 1.6 |
| D | 3 | 2 | 0.8 | 1.2 |
| E | 3 | 4 | 0.5 | 0.38 |

## Now — Q1 2027
| Theme (customer problem) | Serves | Candidate solutions (bets) | Stage | Confidence | Reinforces | Dependencies |
|---|---|---|---|---|---|---|
| A. "Moving our invoice history takes weeks, so we put off switching" | KR1.1, KR3.1 (**committed**: reconciled before each December switcher's first January reminder run), KR3.2 | We believe covering partial payments and a reconciliation check before the first run will move KR1.1 and hold KR3.1 | development | High | Policy (the import advantage) | Export formats of the two common tools |
| B. "We can't tell if it works for our clients until we've paid" | KR1.2, KR1.3 | We believe a trial that opens on the imported overdue list will move KR1.2 | discovery | High | A (runs on imported data) | A |
| C. "We only have time to switch tools at year-end" | KR2.1, KR2.2 | We believe switch guides for the two common tools, timed to the window, will move KR2.2 | development | Medium | A, B (sends firms into a working import and trial) | A |

## Next — Q2 2027
| Theme (customer problem) | Serves | Stage | Confidence | Dependencies |
|---|---|---|---|---|
| D. "Our office manager won't let software email clients she hasn't checked" | KR1.2; protects the client-complaints health metric | discovery | Medium | B |

## Later — H2 2027
| Theme (customer problem) | Serves | Stage | Confidence | Next segment it unlocks |
|---|---|---|---|---|
| E. "Our bookkeeping tool isn't one of the two you import from" | Guiding policy: same-day import (coherent action 1) | research | Low | — |
| F. "Our fixed-fee engagements don't fit reminders built for hourly billing" | Guiding policy: concentrate on 5–50-staff firms | research | Low | Fixed-fee firms of 5–50 staff (shares the import and trial) |

## Not On This Roadmap
| Declined direction or request | Excluded by |
|---|---|
| Partner portal / implementation partners | Guiding policy rules out a consultant program: it rebuilds the weeks-long switch the crux says must go |
| UK VAT invoices | Guiding policy rules out UK expansion in 2027: a second set of norms splits the import work |
| Features for firms over 50 staff (requested by one large prospect) | Guiding policy: concentrate on 5–50 staff |
| Mobile app | Diagnosis: the crux is switching cost; a mobile app reinforces no Now theme |
| AI reminder drafting | Diagnosis: same; revisit only if theme D's discovery shows drafting, not approval, is the blocker |

## Review pre-wiring
| Order | Stakeholder | Date | Concern | How the draft answered it |
|---|---|---|---|---|
| 1 | Design-partner firm (Ashby & Co) | 2026-10-14 | "Will partial payments import?" | Named as theme A's first bet |
| 2 | Sales contractor | 2026-10-15 | Wants the mobile app for demos | Declined, with the diagnosis reason; external view gives sales the themes to talk about |
| 3 | Advisory board | 2026-10-17 | Fixed-fee firms are a large share of the market | Theme F in Later, naming that segment |

## Revision history
Revise at: each OKR cycle · discovery results · a kernel revision · the story map (its first slice tests Now) · a KR no theme can move. Near-term review monthly.
| Date | Trigger | What moved | What was dropped | The learning |
|---|---|---|---|---|
| 2026-10-22 | First version (rewrite of the dated draft) | All rows rewritten as themes | Mobile app, AI drafting, UK, partner portal | Served no KR, or ruled out by the guiding policy |
```

## Output — the external view (for prospects and the sales contractor)

```markdown
> This roadmap reflects our current understanding and will change. It is not a list of delivery dates.

| Problem we're working on | Stage |
|---|---|
| Moving your invoice history takes weeks | In development |
| Knowing it works for your clients before you pay | In discovery |
| Switching at year-end without a project | In development |
| Approving reminders before they go to clients | Coming next |
```

No KRs, no scores, no candidate solutions, no dates, no exclusions. The committed import promise was made to 40 firms directly, not through this view.

## What changed, and why

- Rows became problems a firm would recognise; the five features either became bets under a theme or left with a policy reason.
- Every KR is served; the one committed date stays, labelled; everything else is a stage.
- The draft's dates for Q2–Q4 2027 became Next and Later, with confidence falling as they get further out.
