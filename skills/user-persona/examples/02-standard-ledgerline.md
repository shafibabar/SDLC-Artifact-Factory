# Example 2 — A B2B SaaS product: fixing an over-claimed draft, then upgrading attributes from real interviews (standard profile)

Self-contained. A growing SaaS product at the **standard** profile. The agent's first draft claimed research nobody had done, blended the buyer and the daily user, and wrote solution-shaped goals and job stories inside the persona. The output fixes it, and is shown at version 1.1.0, after the product owner held five design-partner sessions and gave the agent the notes. **Illustrative:** the interviews below are part of the example, to show the format an interview-grounded attribute takes; an agent never writes such tags without real notes.

## Input

> Product: **Ledgerline**, accounts-receivable software for small accounting firms (5–50 staff, billing hourly) to chase their own clients' unpaid invoices. Self-serve 14-day trial on the firm's imported data.
>
> GTM (approved): beachhead and ICP "independent accounting firms, 5–50 staff, billing hourly, using one of the two common bookkeeping tools"; disqualifier "firms with an in-house credit-control team".
>
> Stakeholder map §2, buying committee: managing partner (economic buyer, Skeptic likely), office manager (user, Mobilizer hypothesis; objection "I won't let a robot email clients"), other partners at larger firms (Blocker likely).
>
> Interview notes the product owner supplied for v1.1: DP-1 to DP-5, one office manager and one managing partner per firm, each asked about the last month's chasing.

## The draft the agent wrote first (v1.0, excerpt)

> **Persona: Firm user** — `RESEARCH — interview-grounded`
> Age 38–55, enjoys golf. Goals: use Ledgerline's AI reminders to save time; see the cash dashboard.
> Jobs: When an invoice is 30 days overdue, I want Ledgerline to email the client… / When a partner asks about cash… / When year-end comes…

## Working it

- **The RESEARCH label was false.** No interview had been held when v1.0 was written. Relabelled PROTO with the provenance line; the agent never applies RESEARCH itself.
- **One persona for buyer and user.** The office manager works the reminder queue every day; the managing partner signs off the purchase and reads a weekly summary. Their variables differ (daily operator vs occasional reader, verify-first vs results-only), so they split: the office manager is the **primary** of the reminder queue, the managing partner a **customer** persona. One primary, one interface.
- **The firm's clients receive the reminders but never use Ledgerline.** That makes them a **served** persona: they constrain tone and frequency, nobody designs a screen for them.
- **Demographics out.** Age and golf drive nothing.
- **Solution-shaped goals rewritten.** "Use Ledgerline's AI reminders" pre-decides the design; the end goal is "get paid for billed work without chasing clients by hand".
- **Job stories moved out.** At standard, `jtbd-analysis` owns job stories; the persona keeps one job statement.
- **v1.1 from the notes.** In the five sessions, a bookkeeper at DP-3 also worked the queue. On every variable she sat with the office managers, so she was **merged** into that persona, not given her own. DP-4's office manager let reminders send unseen after a month: the trust attribute changed from "always verifies" to "verifies until it has proven itself". Attributes the notes support are tagged with the session; the rest stay `[assumption]`.

## Output — the personas artifact (v1.1.0)

```markdown
---
name: user-personas
product: ledgerline
version: 1.1.0
phase: ideate
owner: requirements-analyst
created: 2026-10-23
summary: Ledgerline's office manager is the primary of the reminder queue; the managing partner buys; firms' clients are served. 7 of 9 primary attributes interview-grounded.
profile: standard
grounding: mixed
authored-by: requirements-analyst (AI)
evidence: interviews: DP-1…DP-5, held by the product owner 2026-10-05…10-16 (notes in discovery/design-partners/)
review-by: 2027-01-15
traces_to: strategy/gtm-strategy.md (ICP); strategy/stakeholder-map.md §2; problem statement
---

# User Personas — Ledgerline

## Persona Set

| Persona | Type | Interface | Grounding | Status |
|---|---|---|---|---|
| Priya, office manager | Primary | Reminder queue | MIXED (7 of 9) | active |
| Martin, managing partner | Customer | — (weekly summary email) | MIXED (3 of 6) | active |
| The firm's clients | Served | — | PROTO | active |
| Firms with a credit-control team | Negative | — | PROTO | active |

## Behavioural Variables

| Variable | DP-1 OM | DP-2 OM | DP-3 OM + bookkeeper | DP-4 OM | DP-5 OM | Managing partners (5) |
|---|---|---|---|---|---|---|
| Chasing: weekly batch ↔ the day it falls due | weekly | weekly | weekly | due day | weekly | never chases |
| Trust: verifies every reminder ↔ lets them send | verifies | verifies | verifies | verified for a month, then let them send | verifies | wants results only |
| Motivation: avoid upsetting a client ↔ clear the ledger | avoid upset | avoid upset | avoid upset | clear | avoid upset | clear |
| Time in the tool: daily ↔ weekly glance | daily | daily | daily | daily | daily | weekly |

**Patterns:** all office managers and the DP-3 bookkeeper cluster on every variable → one persona (Priya), the bookkeeper merged: her title differs, her behaviour does not. The managing partners form a second pattern (weekly, results-only) → Martin. Gap: no interviewee at a 30–50-staff firm; recruit one before the review date.

---

## Persona: Priya, office manager

**Type:** Primary · **Interface:** reminder queue
**Grounding:** MIXED — 7 of 9 load-bearing attributes interview-grounded
**Status:** active

**Role and context:** runs billing admin at a 5–50-staff firm; owns the overdue list; reports to the managing partner `[DP-1…DP-5]`
**Distinguishing variables:** daily in the tool · verifies reminders until the tool has proven itself · avoids upsetting clients `[DP-1…DP-5]`

### Goals
- **End goals:** get the firm paid for billed work without chasing clients by hand `[DP-1, DP-2, DP-5]`
- **Experience goals:** never be surprised by something sent to a client in the firm's name `[DP-2 · 2026-10-08]`
- **Life goals:** be seen by the partners as the person who keeps cash flowing `[assumption]`

### Forces and context
- **Current approach (habit):** a spreadsheet of overdue invoices exported weekly, then reminder emails written by hand on Friday afternoons `[DP-1, DP-3, DP-5]`
- **Primary frustration:** evenings writing reminders before month-end; partners asking why the list is old `[DP-1 · 2026-10-05; DP-5]`
- **Trigger (push):** a partner asks about a client who is 60 days overdue and she has not chased `[DP-2 · 2026-10-08]`
- **Adoption barrier (anxiety):** a reminder reaching a sensitive client she did not approve `[DP-1…DP-5]`
- **Trust in automated output:** verifies every drafted reminder, with the invoice and days overdue beside it, until it has been right for a few weeks; one wrong client name ends it `[DP-4 · 2026-10-14]`
- **Time to first value:** the first afternoon of the trial must show her real overdue list `[assumption]`

### Job
- **Job statement:** collect overdue client payments without damaging the client relationship → `jtbd-analysis`

### Validation questions
| Attribute | Ask (a specific past event) | Wrong if |
|---|---|---|
| Life goal: seen as keeping cash flowing | "What did the partners last thank you for, or chase you about?" | Recognition comes from something else (client service) |
| Time to first value: first afternoon | "When you tried your last new tool, how long before you gave up or kept it?" | A week of setup is acceptable to her |

**Recruit first:** an office manager at a 30–50-staff firm (the gap in the variable table).

---

## Persona: Martin, managing partner

**Type:** Customer
**Grounding:** MIXED — 3 of 6 load-bearing attributes interview-grounded
**Status:** active

**Role and context:** signs off software spend; reads a weekly summary; never works the queue `[DP-1…DP-5]`

### Goals
- **End goals:** fewer write-offs at year-end `[DP-2, DP-4]`
- **Experience goals:** no client complaint about the firm's tone `[assumption]`

### Forces and context
- **Adoption barrier (anxiety):** "Not mid-year" — switching during a busy season `[stakeholder map §2]`
- **Decision style and information sources:** wants proof on the firm's own data during the trial; trusts other firms' references more than vendor claims `[DP-1, DP-3]`
- **Trust in automated output:** results only; does not open reminders `[assumption]`

### Job
- **Job statement:** convert billed work into cash before year-end

### Validation questions
| Attribute | Ask | Wrong if |
|---|---|---|
| Experience goal: no tone complaints | "When did a client last complain about how the firm chased them?" | Never: tone is the office manager's concern only |
| Results only | "Last week's summary — what did you open?" | He reads individual reminders |

---

## Persona: the firm's clients — Served

**Type:** Served
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from the stakeholder map and the problem statement · no user research
**Status:** active

**Role and context:** the firm's own clients who receive reminders; never log in `[problem statement]`
**Constraints on the design:** reminders sound like the firm, carry the invoice, and stop the day payment lands `[assumption]`

---

## Negative Persona: firms with a credit-control team

**Type:** Negative
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from the GTM's ICP disqualifier · no user research
**Status:** active

**Who and why excluded:** firms with in-house credit control want dunning workflows and collector queues; designing for them buries Priya's approve-and-send loop `[ICP]`

## Lifecycle

- **Review by:** 2027-01-15, after the first year-end
- **Reopen when:** a journey map finds a job no persona covers · a design partner contradicts an attribute · the GTM adds the 50–200-staff segment
- **Retired personas:** "Firm user" (v1.0) · 2026-10-16 · blended buyer and user · replaced by Priya and Martin

## Version Log

| Version | Date | Change | Trigger |
|---|---|---|---|
| 1.0.0 | 2026-10-02 | First set (relabelled PROTO before approval) | Ideate start |
| 1.1.0 | 2026-10-16 | Split buyer from user; merged bookkeeper into Priya; trust attribute corrected; attributes tagged from DP-1…DP-5 | Design-partner sessions held by the product owner |
```

## What changed between draft and v1.1

| Draft defect | Fix |
|---|---|
| RESEARCH label with no interviews | PROTO with provenance; MIXED only after notes arrived, per attribute |
| Buyer and user blended | Primary (Priya) and Customer (Martin) |
| Age and hobby | Removed |
| "Use Ledgerline's AI reminders" | Solution-free end goal |
| Three job stories in the persona | One job statement; stories in `jtbd-analysis` |
| The bookkeeper as a third persona (proposed in the notes) | Merged: same place on every variable |
