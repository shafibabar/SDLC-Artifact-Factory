# Example 2 — Standard: three design partners screened as earlyvangelists, a closed beta with green quality metrics and decaying use, and a pivot on the segment hypothesis

Self-contained. **Quillpoint** runs client conflict checks at intake for small UK law firms (2–15 solicitors), at the **standard** profile. Each firm is a tenant. Release 1 passed UAT on the canary tenant. The product owner had four candidate design partners.

## Input (design)

> **User:** "Pick three partners for the closed beta. I'd like Ashby Kerr in: their managing partner is on the Law Society council and loved the demo."

Candidates: **Ferris & Lowe** (8 solicitors; merged with a two-partner firm in 2024; the cashier keeps a 4,000-row spreadsheet of the old firm's clients and searches it by hand). **Monk Solicitors** (5; searches its practice-management system and "a box of index cards from before 2010"). **Bayliss Hart** (12; paid a consultant last year to de-duplicate client records). **Ashby Kerr** (6; uses its practice-management system's built-in conflict search; "never had a problem", but "loves the idea").

## Working it (design)

- **Earlyvangelist screen.** Ferris & Lowe, Monk and Bayliss Hart each have a named workaround and recognise the pain. Ashby Kerr has no pain and no prior effort: enthusiasm, not evidence. **Declined** for the closed beta and offered an interview; the managing partner's reach is useful later, as a reference once the product proves itself elsewhere.
- **Commitment at entry (Fitzpatrick).** Each partner agrees to run every new matter's check through Quillpoint for six weeks and to give read access to their legacy client list. That is a commitment, not a compliment.
- **Data handling** in Quillpoint's own frameworks: UK GDPR and the SRA's confidentiality duties for client data. Nothing relaxed.
- **Graduation targets set before the stage**, all four dimensions; traction is weekly checks per firm against new matters opened.

## Input (graduation, six weeks later)

> **User:** "Quality is perfect: UAT all green, no Highs, SLOs fine. Use is down, though, and Monk and Bayliss Hart barely touch it now. Let's extend four weeks and add the integration with their practice-management system they asked for, then go to open beta."

Evidence: checks as a share of new matters, weeks 1→6: Ferris & Lowe 100% → 96%; Monk 90% → 20%; Bayliss Hart 85% → 15%. Exit interviews: Monk and Bayliss Hart said their practice-management search "covers everything since we went digital", and neither could name a missed conflict in the past year. Ferris & Lowe: "Last month it found the old firm's client on the other side of a lease dispute. The spreadsheet missed it."

## Working it (graduation)

- **Name the suspect hypothesis first.** Quality is met; traction and behaviour are not. The pain is real and recent at Ferris & Lowe, the one firm carrying a merged firm's legacy records, and absent where all records are already in one system. The problem exists, but not for "small firms" in general. **Segment** is the suspect hypothesis: Customer Segments / Early Adopters on the canvas.
- **Pivot, not extend.** Four more weeks with the same cohort repeats a test that has already answered. The integration request is an opportunity to examine (`opportunity-solution-tree`), not a fix for missing pain.
- **No stage sign-off.** The release has no sign-off yet, so this failed graduation keeps Customer Validation open; the one `acceptance-sign-off` comes when a cohort graduates. Had the sign-off already been written, a failed graduation would re-open Customer Validation: a new UAT pass and a superseding sign-off, never an extra stage sign-off.

## Output — the reply, and `customer-validation/beta-program/quillpoint-r1.md`

> I wouldn't extend. Quality is fine, but the evidence says the segment is wrong, not the product. Only Ferris & Lowe, the firm that absorbed another firm's clients, still runs every check, and it caught a real conflict. Monk and Bayliss Hart's own systems already cover them. I recommend a pivot on the segment: re-screen for firms that have taken on another firm's client records in the last three years, recruit two more like Ferris & Lowe, and update the canvas's Customer Segments and Early Adopters. The integration request goes to the opportunity tree. Please approve the pivot and the new screening question.

````markdown
---
name: beta-program-quillpoint-r1
product: quillpoint
release-slice: r1
version: 1.2.0
phase: customer-validation
owner: requirements-analyst
created: 2026-05-04
summary: Quillpoint R1 closed beta: quality met but use decayed at two of three firms; pivot on segment to firms carrying merged legacy client records; canvas updated.
profile: standard
traces_to: strategy/stakeholder-map.md; customer-validation/uat-plan.md; strategy/business-model-canvas.md
---

# Beta Program — quillpoint r1

## Shape
B2B design partners — stages run: closed alpha → closed beta → open beta → GA; left out, and why: none.

## Stage
Closed beta

## Participants
Three firms screened as earlyvangelists; Ashby Kerr declined (no pain, no prior effort) and offered an interview.

| Candidate | ICP | Feedback | Rough edges | Named contact | Pain + prior effort (name the workaround) | Budget + reference | Result |
|---|---|---|---|---|---|---|---|
| Ferris & Lowe | y — 8 solicitors | y | y | Dana Ferris, managing partner | 4,000-row spreadsheet of the merged firm's clients, searched by hand | y / y | in |
| Monk Solicitors | y — 5 | y | y | Tom Monk, partner | Practice-management search plus pre-2010 index cards | y / n | in |
| Bayliss Hart | y — 12 | y | y | Sara Hart, COLP | Consultant paid to de-duplicate client records (2025) | y / y | in |
| Ashby Kerr | y — 6 | y | y | Ian Kerr, managing partner | None: built-in search, "never had a problem" | y / y | declined |

## Rollout Mechanic
canary-deployment: each firm's tenant joins the canary wave after the alpha tenant. feature-flag-design: `intake.conflict-check` scoped to the three tenant ids. The platform splits traffic per tenant, not within one.

## Beta Agreement Status
Accepted: Ferris & Lowe 2026-03-16, Monk 2026-03-17, Bayliss Hart 2026-03-17.

## Feedback Cadence
Bi-weekly 30-minute check-in per firm; ad hoc reports by email, Critical and High triaged the same day; UAT window in week 1.

## Data Handling Statement
No control is relaxed for this beta: the same access control, data classification, encryption, tenant isolation and audit logging apply as at GA.
- Frameworks: UK GDPR; the SRA's confidentiality duties for client information (per compliance-design)
- Telemetry: none beyond GA

## Graduation Criteria
Targets set before the stage starts.
- Quality: uat-plan threshold (all Must scenarios); open defects within acceptance-sign-off's defect rule; check-time SLO held through the canary window
- Traction: ≥ 80% of new matters checked through Quillpoint, per firm, in each of weeks 4–6
- Behaviour and commitment: each contact describes a recent check and what it found, past tense; every new matter run through Quillpoint for six weeks, legacy list shared
- Repeatability and operations: each firm onboarded from the setup guide alone; legacy-list imports handled by support without the product owner

## Graduation Record
Decision: Pivot
Suspect hypothesis: segment — Customer Segments / Early Adopters: the pain sits with firms carrying another firm's legacy client records, not small firms in general
2026-05-04, closed beta, not graduated. Quality met (UAT 9 of 9; no open High; SLO held). Traction missed: week 6 checks/new matters 96% (Ferris & Lowe), 20% (Monk), 15% (Bayliss Hart). Behaviour: only Ferris & Lowe describe a recent catch (lease dispute, April). Repeatability met: all three onboarded from the guide; support ran the imports. Next: re-screen with "Have you taken on another firm's client records since 2023?"; recruit two such firms; canvas Customer Segments and Early Adopters updated; the practice-management integration request logged as an opportunity. Rollout: canary held at the current tenants; flag stays scoped; no open beta.
````

## What the weak first draft looked like

"Extend four weeks and add the integration; quality is green." It read green defect counts as readiness, ignored the decaying use at two firms, and spent another month and a feature on a cohort that had already shown it lacked the pain. It also had Ashby Kerr as lead partner on the strength of a demo.
