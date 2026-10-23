# Example 2 — A B2B SaaS product: product-assisted self-serve, priced from paid pilots (standard profile)

Self-contained. A growing SaaS product at the **standard** profile, written after its first eight weeks with design partners. It shows the full standard shape for one beachhead, and fixes three defects in the team's first draft: positioning against the best-known vendor instead of the alternative firms actually use, prices deferred to a "commercial plan", and a borrowed conversion benchmark.

## Input

> Product: **Ledgerline**, accounts-receivable software for small accounting firms, which use it to chase their own clients' unpaid invoices.
>
> Strategy kernel (approved): crux, switching costs a firm weeks and must cost an afternoon. Guiding policy: make switching a same-day import and concentrate on firms of 5–50 staff that bill hourly; relies on the import. Rules out a consultant implementation programme, firms over 50 staff, and UK expansion this year.
>
> Competitive analysis (approved): alternatives A1 write off late fees (doing nothing), A2 no decision (partner defers to year-end), A3 spreadsheet plus email reminders (most firms), A4/A5 the AR modules in two practice-management suites (Suite B lists at $129 per firm per month, verified 2026-10-02), A6 a general AR tool. Differentiation: D1 same-day history import (verified against Suite A; hypothesis against Suite B); D2 reminders the office manager approves before they send (real and valued, not defensible: messaging only). Win/loss log: design partner 1 won against the spreadsheet ("we saw our overdue clients the first afternoon"); design partner 2 no decision ("revisit at year-end").
>
> Business model canvas (approved): subscription; charging unit per firm per month, tiered by active clients chased; WTP stated range from 5 solution interviews, committed by 3 paid pilots at the quoted $89; price levels are the GTM's.
>
> Stakeholder map: the managing partner buys; the office manager uses it daily.

## The draft the team brought (excerpt)

> **Positioning:** "Unlike Suite A, Ledgerline is modern and AI-powered."
> **Pricing:** "Tiered subscription. Exact price points are set in the commercial plan."
> **Metric:** "Trial-to-paid ≥ 15% (PLG B2B benchmark 15–25%)."

Run the checklist:
- **Row 5:** Suite A is not what most firms use: the competitive analysis says the spreadsheet (A3) and no decision (A2) are. "Modern and AI-powered" passed no filter there.
- **Row 9:** no artifact produces a "commercial plan"; the evidence for a range already exists (5 stated, 3 committed).
- **Row 12:** the benchmark has no source. The target must come from Ledgerline's own funnel.

## Output — the GTM strategy artifact (abridged: objections and the deferred-channel list shortened)

```markdown
---
name: gtm-strategy
product: ledgerline
version: 1.0.0
phase: strategy
created: 2026-10-23
summary: Win 5–50-staff hourly-billing firms in the quarter before year-end, unlike their spreadsheet, with a same-day import trial priced $79–179 per firm per month.
owner: product-strategist
profile: standard
traces_to: strategy/strategy-kernel.md; strategy/competitive-analysis.md; strategy/business-model-canvas.md
---

# Go-to-Market Strategy

## 1. Beachhead Segment

Carries out the kernel's guiding policy: "concentrate on firms of 5–50 staff that bill hourly".

| Criterion | A: 5–50-staff firms, year-end next quarter | B: all small businesses chasing invoices | C: firms of 50–200 staff |
|---|---|---|---|
| Reason to buy now | ✓ year-end is when firms switch (7 of 9 calls) | ~ | ✓ |
| One coherent channel | ✓ professional-body directories + year-end timing | ✗ no single channel | ~ |
| Accessible economic buyer | ✓ managing partner | ~ owner, varied | ✗ finance committee |
| No entrenched competitor | ✓ spreadsheet is the incumbent | ✗ A6 general AR tools | ✗ suites own it |
| Winnable now | ✓ 3 paid pilots | ✗ | ✗ needs migration services |
| Reference base | ✓ firms trust other firms' references | ✗ | ~ |
| WTP evidence | $60–100 acceptable, stated (5); $89 committed (3) | none | none |
| Kernel fit | inside | outside the focus | ruled out |

**Chosen:** A. Smaller than B, but it has a trigger (year-end), one channel and references firms recognise.
**Next pin:** not yet; the kernel holds expansion until the import is proven at year-end.

## 2. Ideal Customer Profile

| Attribute | Definition |
|---|---|
| Size | 5–50 staff, billing hourly |
| Type | Independent accounting firms |
| Geography | Home market only (UK ruled out this year) |
| Technical maturity | Uses one of the two common bookkeeping tools |
| Buying triggers | Year-end in the next quarter; a partner taking over collections; a bad write-off year |
| Observed in | Design partners 1, 3 and 4 (paid pilots) |
| Disqualifiers | Over 50 staff; fixed-fee only (nothing hourly to chase); bookkeeping tool with no API; wants a consultant-led rollout |

### Buying group

| Role | Must believe | Likely objection | Proof | Likely profile | Loses by staying put |
|---|---|---|---|---|---|
| Managing partner (economic buyer) | It pays for itself and the switch costs an afternoon | "Not mid-year" | Import on their own data in the trial | Skeptic (likely) | Another year of write-offs |
| Office manager (user) | Nothing goes to a client without approval | "I won't let a robot email clients" | D2 approve-before-send | Go-Getter (likely) — **Mobilizer hypothesis** | Evenings writing reminders |
| Other partners (20–50-staff firms) | Their clients won't be annoyed | "Our clients are sensitive" | Reminder templates they approve | Blocker (likely) | Little; they rarely chase |

**Mobilizer hypothesis:** the office manager, who runs the trial and shows the partner the first-afternoon overdue list. Stage 1 result: held in 3 of 5 partners. In design partner 5 the office manager was a **Friend** — answered every email, never brought the partner in — and that account went quiet.
**Where consensus is built:** a 20-minute product-assisted call where the office manager walks the partners through their own overdue list.

## 3. Positioning

**Competitive alternatives** (competitive analysis §1): A1 write off, A2 no decision, A3 spreadsheet, A4/A5 suite AR modules, A6 general AR tool.
**Unique attributes used:** D1 same-day import (verified vs Suite A; hypothesis vs Suite B). D2 for messaging only.
**Value themes:** paid on time without partner evenings; switch in an afternoon; nothing reaches a client unapproved.
**Market category:** subcategory — "accounts receivable for accounting firms". Rejected: fitting "AR automation" (imports A6's criteria: automatic sending, which these buyers reject).

> For accounting firms of 5–50 staff approaching year-end, who lose fees to clients nobody has time to chase, Ledgerline is accounts receivable built for accounting firms that shows every overdue client the afternoon you sign up. Unlike the spreadsheet and email reminders most firms use, Ledgerline imports your full invoice history the same day, so switching never waits for next year.

## 4. Messaging

**Reframe:** "Your write-offs aren't a client problem, they're a calendar problem: every year you wait to switch tools is another year of fees lost to a spreadsheet you know is failing."
**Headline:** Get paid for every hour, starting this afternoon.
**Value proposition:** Your office manager sees every overdue client the day you sign up, and sends reminders you approve. Your partners stop spending evenings chasing, and you don't wait for year-end to switch.
**Proof points:**
1. Full history imported the same day from the two common bookkeeping tools (4 of 5 partner imports).
2. No reminder sends without approval.
3. Customer story: design partner 1 (12 staff, named with consent) saw 31 overdue clients on the first afternoon and recovered two years of late fees in the pilot quarter.

**Lead proof point by role:** partner → 3 then 1; office manager → 2; other partners → 2.

## 5. Channel Strategy

**Primary:** a year-end switching campaign (content and email) to firms whose year-end is next quarter, found through professional-body directories; leads into the self-serve import trial.
**Supporting:** the bookkeeping tools' app directories; referrals from pilot firms.
**Deferred:** events and paid ads — revisit after Stage 2.

## 6. Sales and Distribution Model

| Decision | Choice |
|---|---|
| Sales motion | Product-assisted: self-serve import trial plus one 20-minute call |
| Contract model | Monthly; annual prepay for two months free (give-get: term) |
| Procurement path | Card or invoice |
| Trial model | 14-day free trial on the firm's own imported data |
| Expansion motion | Moves up a tier as active clients chased grow (follows the charging unit) |
| Buying group | Office manager as Mobilizer; consensus on the partners' call |

## 7. Pricing

**WTP evidence:** 5 solution interviews, stated: acceptable $60–100, expensive $150, prohibitive above $250 per firm per month. Committed: 3 paid pilots at $89.
**Monetisation model:** subscription — value is ongoing and firms want a predictable cost.
**Charging unit:** per firm per month, tiered by active clients chased. Tracks value (more clients chased, more cash recovered); predictable (the firm knows its client count); grows with the firm. Rejected: per seat (value doesn't track staff count); a share of fees recovered (firms dislike a cut of client money — canvas draft B).
**Packaging:** two tiers. Practice (up to 150 active clients): leaders D1 import and approvals. Practice Plus (up to 600): adds a second bookkeeping connection and partner reporting.
**Value anchor (ceiling):** ~6 partner hours a month at a ~$120 loaded rate (~$720), plus late fees recovered. Assumption from design-partner estimates; confirm with Stage 2 data.
**Price strategy:** maximisation — no network effect or lock-in justifies penetration.
**Price range per tier:** Practice $79–99; Practice Plus $139–179. List prices set in Stage 2.
**Failure-mode check:** feature shock — AI reminder drafting cut (no buyer criterion); minivation — $89 is far below the anchor but inside committed WTP, so test the top of the range in Stage 2; hidden gem — firms over 50 staff, deferred by the kernel; undead — 3 paid pilots.

## 8. Launch Sequencing

| Stage | Audience | Planned length | Exit criteria |
|---|---|---|---|
| 1 — Closed beta | 5 design partners | 8 weeks (done) | Met: ICP and value confirmed from partners' own past write-off figures and 3 paid pilots, not compliments; 4 of 5 imports same-day without help; WTP recorded; Mobilizer held in 3 of 5 |
| 2 — Soft launch | Year-end campaign to 200 firms | 12 weeks | ≥ 10 trials started; a repeatable trial → call → paid path; price accepted in range without structural discounting; no-decision losses logged with reasons |
| 3 — GA | All channels | Ongoing | Stage 2 criteria hold for 4 consecutive weeks |

**Positioning refresh:** at each transition, and when the win/loss log contradicts D1 (e.g. a firm with a same-day import still defers).

## 9. GTM Success Metrics

| Metric | Target | Measured from |
|---|---|---|
| Time to first value | Overdue list within 4 hours of sign-up | Product telemetry |
| Trial-to-paid | Set from the first 10 Stage 2 trials; no external benchmark | Trial cohort |
| Acquisition cost | ≤ 3 months of the Practice tier price | Campaign spend / new firms |
| ICP hit rate | > 80% of new firms match the ICP | Sign-up fields |
| Lost to no decision | Baseline in Stage 2, then halve it | Win/loss log |
```

## What changed, and why

- "Unlike Suite A" became "unlike the spreadsheet": the competitive analysis shows that is what the beachhead uses, and D1 beats it on its own evidence.
- The Reframe sells the cost of waiting, which is the kernel's crux and the no-decision loss in the win/loss log; only a same-day import answers it.
- The office manager is a Mobilizer *hypothesis* that Stage 1 tested; design partner 5 showed the Friend pattern.
- Prices became a range per tier from stated and committed WTP, and the benchmark became a target the team sets from its own funnel.
