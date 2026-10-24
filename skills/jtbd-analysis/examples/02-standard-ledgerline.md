# Example 2 — A B2B SaaS product: the full analysis from five design-partner snapshots (standard profile)

Self-contained. **Ledgerline**, accounts-receivable software for small accounting firms (5–50 staff) to chase their own clients' unpaid invoices, at the **standard** profile. The product owner held five design-partner sessions; the agent wrote a snapshot from each set of notes, then the analysis. It shows both formats named, stories citing snapshots, the forces table, what gets fired (including non-consumption), Big and Little Hire, the buyer's financial job, and outcomes ranked by compare-and-contrast because five participants cannot support survey maths. **Illustrative:** the sessions are part of the example; an agent never cites snapshots nobody wrote.

## Input

> Personas (approved): **Priya**, office manager, primary of the reminder queue, job statement "collect overdue client payments without damaging the client relationship"; **Martin**, managing partner, customer persona, job statement "convert billed work into cash before year-end".
>
> Snapshots: `2026-10-05-dp-1` … `2026-10-16-dp-5`, switch interviews held by the product owner with the office manager (and at DP-2 and DP-4 also the managing partner) of five firms. One of them is shown below.
>
> Competitive analysis (approved): alternatives "bookkeeping tool's built-in reminders; spreadsheet + hand-written emails; collection agency".

## One of the five snapshots

```markdown
---
name: interview-snapshot
product: ledgerline
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-14
summary: DP-4's office manager switched off the bookkeeping tool's auto-reminders after one reached a client who had paid the day before; now writes every reminder by hand.
participant: DP-4
interview-date: 2026-10-14
interviewer: the product owner
synthesised-by: requirements-analyst (AI), from the interviewer's notes; the agent did not witness the conversation
guide: ideate/interviews/guides/2026-10-01-chasing-switch.md
---

# Interview Snapshot — DP-4, 2026-10-14

**Quick facts:** 22-staff firm · office manager + managing partner · bookkeeping tool + spreadsheet
**Memorable quote:** "One automatic email to the wrong client and I was on the phone apologising for twenty minutes."

## The story
March: turned on the bookkeeping tool's automatic reminders → a reminder reached a long-standing client who had paid by bank transfer the day before (the payment had not been matched) → the partner took an angry call → she switched automation off that week → since then: Friday export to a spreadsheet, cross-check against the bank feed, hand-written emails, about three hours.

## Forces heard
| Force | What they described |
|---|---|
| Push | Friday afternoons gone; the partner asking why a 60-day debt was not chased |
| Pull | "If I could trust it not to hit people who've paid, I'd let it run" |
| Anxiety | A reminder reaching a client who has paid, or one the partner handles personally |
| Habit | The spreadsheet cross-checked against the bank feed: "slow, but I know it's right" |

## What was fired
The bookkeeping tool's automatic reminders (fired in March). Hired: spreadsheet + hand-written emails.

## Opportunities heard
| Opportunity (customer's voice) | Experience step |
|---|---|
| "I can't tell who has actually paid until the bank feed is matched" | Check before chasing |
| "Writing thirty emails that all say the same thing" | Prepare reminders |
| "Some clients only the partner may chase" | Decide who to chase |

## Advancement
Shared her Friday spreadsheet; agreed to a trial on the firm's real ledger in November.

## Discarded
| Said | Type | Problem recovered |
|---|---|---|
| "It should have an AI that writes nicer emails" | idea | Reminders must sound like the firm, not a robot: tone matters for the relationship |
```

## Working it

- **Job statements refined, not restated.** Priya's line from the persona holds. Martin's is the **buyer's financial job** (Ulwick), written as its own J-row because the executor and the buyer differ.
- **Stories one per situation, each citing a snapshot.** The draft's first story read "I want to see a list of overdue invoices ranked by risk": a product output. Rewritten as the motivation ("know which clients I can safely chase today").
- **What gets fired includes non-consumption.** At DP-3, small debts were never chased: written off at year-end. That is the biggest market among small firms, and it frames J-2 around year-end, not a weekly workflow.
- **Ranking by compare-and-contrast.** Five participants. The product owner asked each for a 1–10 importance rating; they appear, labelled directional, and do not decide the ranking alone.
- **Onboarding requirements from anxiety, habit and the Little Hire**, not invented features.

## Output — the JTBD analysis

```markdown
---
name: jtbd-analysis
product: ledgerline
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-20
summary: Ledgerline's two jobs (collect without harming the relationship; cash before year-end); target outcome is never chasing a client who has paid. Evidence: five design-partner snapshots.
profile: standard
evidence: ideate/interviews/snapshots/2026-10-05-dp-1.md … 2026-10-16-dp-5.md
ranking: compare-and-contrast (n = 5 design partners)
traces_to: ideate/user-personas.md; strategy/competitive-analysis.md; problem statement
---

# Jobs To Be Done Analysis — Ledgerline

## Evidence

| Snapshot | Date | Participant | Segment / role | Interviewer | Interview type |
|---|---|---|---|---|---|
| [2026-10-05-dp-1] | 2026-10-05 | DP-1 | 8-staff firm, office manager | the product owner | switch |
| [2026-10-08-dp-2] | 2026-10-08 | DP-2 | 35-staff firm, office manager + managing partner | the product owner | switch |
| [2026-10-09-dp-3] | 2026-10-09 | DP-3 | 6-staff firm, office manager + bookkeeper | the product owner | story-based |
| [2026-10-14-dp-4] | 2026-10-14 | DP-4 | 22-staff firm, office manager + managing partner | the product owner | switch |
| [2026-10-16-dp-5] | 2026-10-16 | DP-5 | 15-staff firm, office manager | the product owner | switch |

## Core Jobs

| ID | Job statement (Ulwick) | Executor | Beneficiary | Buyer | Target outcome |
|---|---|---|---|---|---|
| J-1 | Collect overdue client payments without damaging the client relationship | Priya (office manager) | Martin (managing partner) | Martin | O-1.2 |
| J-2 | Convert billed work into cash before year-end | Martin | — | Martin | O-2.1 |

---

## J-1: Collect without harming the relationship

**Job statement (Ulwick):** Collect overdue client payments without damaging the client relationship
**Executor:** Priya · **Beneficiary:** Martin · **Buyer:** Martin

### Job spec

- **Functional:** get every overdue client reminded, at the right moment, in the firm's voice
- **Emotional:** never be surprised by something sent in the firm's name [2026-10-14-dp-4]
- **Social:** be the person who keeps cash flowing, not the one who upset a client [2026-10-08-dp-2]
- **Obstacles:** payments not yet matched in the bank feed; partner-only clients nobody has listed [2026-10-14-dp-4, 2026-10-08-dp-2]
- **Purchase experience:** a trial on the firm's own ledger, not demo data [2026-10-05-dp-1, 2026-10-14-dp-4]
- **Use experience:** first afternoon shows her real overdue list; every reminder previewable before it goes [2026-10-14-dp-4]

### What gets fired

| Alternative | Who uses it | Evidence |
|---|---|---|
| Spreadsheet + hand-written emails | 4 of 5 firms | [2026-10-05-dp-1] [2026-10-14-dp-4] [2026-10-16-dp-5] |
| The bookkeeping tool's automatic reminders (switched off) | DP-4, DP-5 | [2026-10-14-dp-4] |
| Nothing: small debts written off at year-end (non-consumption) | DP-3 | [2026-10-09-dp-3] |

### Big Hire / Little Hire

- **Big Hire:** the trial shows money recovered on the firm's own ledger, and no reminder went to anyone who had paid [2026-10-14-dp-4]
- **Little Hire:** on Monday morning Priya approves the week's reminders in minutes instead of losing Friday afternoon [2026-10-16-dp-5]

### Forces of progress

| Force | Specific event | Evidence |
|---|---|---|
| Push | Partner asked why a 60-day debt was not chased; Friday afternoons lost to hand-writing | [2026-10-08-dp-2] [2026-10-14-dp-4] |
| Pull | "If I could trust it not to hit people who've paid, I'd let it run" | [2026-10-14-dp-4] |
| Anxiety | An automatic reminder reached a client who had paid the day before; an apology call | [2026-10-14-dp-4] |
| Habit | Spreadsheet cross-checked against the bank feed: "slow, but I know it's right" | [2026-10-14-dp-4] [2026-10-05-dp-1] |

### Job stories (Klement / Intercom)

#### JS-1.1: Friday batch (routine)

When it is the end of the week and thirty invoices have slipped past due, I want to know which clients I can safely chase today, so I can send every reminder before I leave without checking each one by hand.

- **Evidence:** [2026-10-14-dp-4] [2026-10-16-dp-5]
- **Implied capability:** reconcile overdue invoices against received payments before reminders are prepared

#### JS-1.2: The partner asks (trigger)

When a partner asks me about a client who is 60 days overdue, I want to show what has been sent and when, so I can answer on the spot instead of promising to check.

- **Evidence:** [2026-10-08-dp-2]
- **Implied capability:** a per-client chasing history

#### JS-1.3: A sensitive client (high stakes)

When an overdue client is one the partner manages personally, I want to leave it to the partner whether and how they are chased, so I can avoid a reminder that damages the relationship.

- **Evidence:** [2026-10-08-dp-2] [2026-10-14-dp-4]
- **Implied capability:** mark clients as partner-handled; hold their reminders for the partner

### Desired outcomes

| ID | Desired-outcome statement (Ulwick) | Evidence | Sizing | Importance (strongest event) | Served today | Directional rating (n = 5) | Rank |
|---|---|---|---|---|---|---|---|
| O-1.1 | Minimize the time it takes to prepare the week's reminders | [2026-10-05-dp-1] [2026-10-16-dp-5] | 5 of 5 | Friday afternoons lost; no client harm | Poorly: hand-written | 7 | 2 |
| O-1.2 | Minimize the likelihood that a reminder reaches a client who has already paid | [2026-10-14-dp-4] | 4 of 5 | An apology call to a long-standing client | Badly: payments matched a day late | 9 | 1 |
| O-1.3 | Minimize the likelihood that a partner-handled client is chased without the partner knowing | [2026-10-08-dp-2] | 2 of 5 | A partner's angry call | Adequately: she asks by email | 8 | 3 |

**Target outcome:** O-1.2. It is the anxiety that made two firms fire automation; until it is served, O-1.1 (the time saving) cannot be delivered, because nobody lets reminders run.

---

## J-2: Cash before year-end (the buyer's financial job)

**Job statement (Ulwick):** Convert billed work into cash before year-end
**Executor:** Martin · **Beneficiary:** — · **Buyer:** Martin

### Job spec

- **Functional:** fewer write-offs at year-end
- **Emotional:** not discover in December how much will never come in [2026-10-09-dp-3]
- **Social:** [assumption] seen by the other partners as running a tight firm
- **Obstacles:** nobody chases small debts until it is too late [2026-10-09-dp-3]
- **Purchase experience:** proof on the firm's own data during the trial [2026-10-08-dp-2]
- **Use experience:** a short weekly summary; he never works the queue [2026-10-08-dp-2]

### What gets fired

| Alternative | Who uses it | Evidence |
|---|---|---|
| Nothing until year-end: write-off (non-consumption) | DP-3 | [2026-10-09-dp-3] |
| A collection agency for the largest debts | DP-2 | [2026-10-08-dp-2] |

### Big Hire / Little Hire

- **Big Hire:** the trial recovers a debt he had expected to write off [assumption]
- **Little Hire:** he reads the Monday summary because it shows money in, not activity [assumption]

### Forces of progress

| Force | Specific event | Evidence |
|---|---|---|
| Push | Last December's write-offs, found at the year-end review | [2026-10-09-dp-3] |
| Pull | [assumption] a predictable cash position before year-end | — |
| Anxiety | Switching tools mid-year, in a busy season | [2026-10-08-dp-2] |
| Habit | Leaving chasing to the office manager and the agency | [2026-10-08-dp-2] |

### Job stories (Klement / Intercom)

#### JS-2.1: Year-end review (trigger)

When the year-end review shows debts we will never collect, I want to know which of them could still have been recovered earlier, so I can stop them building up next year.

- **Evidence:** [2026-10-09-dp-3]
- **Implied capability:** ageing view of debts at risk of write-off

### Desired outcomes

| ID | Desired-outcome statement (Ulwick) | Evidence | Sizing | Importance (strongest event) | Served today | Directional rating (n = 2) | Rank |
|---|---|---|---|---|---|---|---|
| O-2.1 | Minimize the amount of billed work written off at year-end | [2026-10-09-dp-3] | 2 of 2 partners | December write-offs | Not served: non-consumption | 9 | 1 |

**Target outcome:** O-2.1, the only outcome heard; more partner interviews needed before comparing.

---

## Onboarding Requirements

| ID | Requirement | From |
|---|---|---|
| ONB-1 | The trial runs on the firm's own imported ledger and shows the real overdue list on the first afternoon | J-1 purchase and use experience; Big Hire |
| ONB-2 | No reminder sends during the trial without Priya's preview; automatic sending is switched on only by her | J-1 anxiety |
| ONB-3 | Import the existing chasing spreadsheet, including notes on partner-handled clients | J-1 habit; JS-1.3 |
| ONB-4 | A weekly summary to the buyer that reports money recovered, not reminders sent | J-2 Little Hire |

## Related Jobs

- Agree payment plans with clients who cannot pay in full (heard at DP-1; expansion, not this release).

## Assumptions to Validate

| Item | Validation question (a specific past event) | Wrong if |
|---|---|---|
| J-2 Big Hire | "When did a tool last pay for itself in a way you noticed? What did you see?" | He judges on time saved, not money recovered |
| J-2 pull | "At the last year-end review, what did you wish you had known in September?" | Cash timing does not matter to him |
| J-2 social | "When did the other partners last comment on write-offs?" | Write-offs are never discussed |

## Hand-off

- `impact-mapping`: target outcomes O-1.2 and O-2.1; JS-1.1–1.3 explain Priya's behaviour change.
- `requirements-analysis` / `user-story-writing`: implied capabilities, each traced to J-1 or J-2 and its story.
- `business-model-canvas`: J-1, J-2 and O-1.2, O-1.1, O-2.1 by ID.
- `competitive-analysis` / `gtm-strategy`: built-in reminders fired for trust reasons; non-consumption among the smallest firms.

## Version Log

| Version | Date | Change | Trigger |
|---|---|---|---|
| 1.0.0 | 2026-10-20 | First analysis from DP-1…DP-5 | Ideate |
```

## What the draft got wrong, and the fix

| Draft | Fix |
|---|---|
| "Job statement: When an invoice is overdue, I want…" | A job story under the wrong label; the statement is `[verb] [object] [clarifier]` |
| "I want to see a list of overdue invoices ranked by risk" | A product output; rewritten as the motivation: know which clients can safely be chased |
| "J-1 Opportunity 9 + (9 − 3) = 15" | Whole-job score; replaced by outcomes ranked by comparison |
| Average importance 8.2 from five people, called "validated" | Ratings kept as directional; the ranking rests on the comparison |
| Competitors only | The switched-off built-in reminders and the year-end write-off added to what gets fired |
