# Example 2 — A B2B SaaS product: a one-grid draft split into two halves (standard profile)

Self-contained. A growing SaaS product at the **standard** profile. The team's first draft put customer roles, design partners and the product owner on one grid with 1–3 scores, gave customer archetypes monthly updates, misplaced a high-power reviewer, and wrote a RACI with two Accountables, one of them an agent. The output splits the map, fixes the scale and the decision rights, and carries the buying committee the GTM later cites. Shown at version 1.1.0, after Stage 1 confirmed or replaced the committee hypotheses.

## Input

> Product: **Ledgerline**, accounts-receivable software for small accounting firms (5–50 staff, billing hourly), which use it to chase their own clients' unpaid invoices. Self-serve 14-day trial on the firm's own imported data, with a short assisted call.
>
> Vision (approved): small firms get paid for the work they do, without a partner spending evenings chasing clients.
>
> Facts: five design-partner firms. Ledgerline imports invoice history through a bookkeeping platform's partner API; the platform's marketplace team must approve the app before firms can connect it, and re-reviews any change to requested data scopes. A part-time support contractor answers trial questions.

## The draft the team brought (excerpt)

> | Name/Role | Power (1–3) | Interest (1–3) | Quadrant | Engagement |
> |---|---|---|---|---|
> | Managing partner (customer) | 3 | 2 | Keep Satisfied | Monthly ROI update |
> | Office manager (customer) | 2 | 3 | Keep Informed | Monthly newsletter |
> | Bookkeeping platform marketplace reviewer | 3 | 1 | Monitor | As needed |
> | Product owner | 3 | 3 | Manage Closely | Every chunk |
>
> | Decision | R | A | C | I |
> |---|---|---|---|---|
> | Data scopes requested from the bookkeeping API | backend-engineer agent | The product owner and backend-engineer agent | Marketplace reviewer | Design partners |

## Working it

- **Two kinds of entry on one grid.** "Managing partner (customer)" and "office manager (customer)" are roles in a segment; nobody can send "the office manager of a 20-person firm" a monthly newsletter. They move to the buying committee with belief, objection and proof, and no cadence. The design partners' actual office managers and partners, whom the product owner does talk to, stay on the delivery side as the design-partner cohort.
- **The scale has no midpoint rule.** On a 1–3 score, the office manager's power of 2 is placed "low" with no reason. Switched to High / Low with a reason.
- **The marketplace reviewer is a Context setter, not Crowd.** Power 3, interest 1 is high power, low interest: Keep Satisfied. "As needed" means they hear about Ledgerline when a scope request lands and they have no context. Mitigation: the scope justification is sent before the request. And because they can block the integration release, they hold an **Agree** (veto) on scope changes, not a Consulted.
- **Two Accountables, one an agent.** Accountable is one person: the product owner. The agent stays Responsible.
- **The product owner row** stays as a role ("the product owner"); no personal name.

## Output — the stakeholder map

```markdown
---
name: stakeholder-map
product: ledgerline
version: 1.1.0
phase: strategy
owner: product-strategist
created: 2026-10-23
summary: Ledgerline ships through the bookkeeping platform's marketplace review; firms buy via the managing partner, with the office manager as likely Mobilizer.
profile: standard
traces_to: strategy/vision-statement.md
---

# Stakeholder Map

## 1. Delivery Stakeholders

### Register

Scale: High / Low on each axis, with a reason.

| Stakeholder | Power | Interest | Quadrant | Salience | Engagement need |
|---|---|---|---|---|---|
| The product owner | High — approves every artifact and release | High — owns the outcome | Manage Closely | Definitive | Decisions framed as options with a recommendation |
| Design-partner cohort (5 firms: each office manager and managing partner) | High — their evidence sets the beachhead and price | High — they chose to pilot | Manage Closely | Dependent | Early sight of the import and reminder flows; their words in the release notes |
| Bookkeeping platform marketplace reviewer | High — can refuse the app or a scope change | Low — one app among hundreds | Keep Satisfied | Dominant → definitive when a scope request lands | Scope justification before each request |
| Support contractor (part-time) | Low — no decision rights | High — answers every trial question | Keep Informed | Discretionary | Release notes and known issues a day before each release |

### Grid

    High power │ Keep Satisfied                  │ Manage Closely
               │ · Marketplace reviewer (→ when  │ · The product owner
               │   a scope request lands)        │ · Design-partner cohort
               │─────────────────────────────────│─────────────────────────
    Low power  │ Monitor                         │ Keep Informed
               │ (none)                          │ · Support contractor
                  Low interest                      High interest

### Engagement Plan

| Stakeholder | What they need from us | Channel | Cadence | Owner (a person) | Re-score trigger |
|---|---|---|---|---|---|
| Design-partner cohort | Fortnightly 30-minute session on their own data; roadmap input | Video call | Bi-weekly | The product owner | A partner goes quiet for two sessions |
| Marketplace reviewer | Scope justification (what is read, why, retention), sent before the request | Partner portal | Before each scope change | The product owner | Any new scope in the backlog |
| Support contractor | Release notes, known issues, the three questions trialists ask most | Shared doc | Each release | The product owner | Trial volume doubles |

### Pre-wiring Order

Before the Strategy gate review: 1. the marketplace reviewer (scope list, so nothing in the roadmap depends on a scope they will refuse) · 2. two design-partner managing partners, one at a time (pricing range) · then the review with the product owner.

### Decision Rights

| Decision | Responsible | Accountable | Agree (veto) | Consulted | Informed |
|---|---|---|---|---|---|
| Product direction and beachhead | product-strategist agent | The product owner | — | Design-partner cohort | Support contractor |
| Data scopes requested from the bookkeeping API | backend-engineer agent | The product owner | Marketplace reviewer | — | Design-partner cohort |
| Pricing range | product-strategist agent | The product owner | — | Design-partner managing partners | Support contractor |
| Release gate | Governance hooks; test-strategist agent | The product owner | — | Support contractor | Design-partner cohort |

## 2. Customer Buying Committee

Hypothesised roles, not people. No cadence. Profiles are likely until Stage 1 confirms them.

### Segment: accounting firms, 5–50 staff, billing hourly

| Role | Must believe to say yes | Likely objection | Proof that answers it | Likely profile | Loses by staying put | Confirmed by |
|---|---|---|---|---|---|---|
| Managing partner (economic buyer) | It pays for itself and switching costs an afternoon | "Not mid-year" | The import run on their own data during the trial | Skeptic — likely | Another year of write-offs | Held in 4 of 5 partners |
| Office manager (user) | Nothing goes to a client without approval | "I won't let a robot email clients" | Approve-before-send reminders | Go-Getter — likely; **Mobilizer hypothesis** | Evenings writing reminders | Held in 3 of 5; in partner 5 a **Friend** (see below) |
| Other partners (20–50-staff firms) | Their clients won't be annoyed | "Our clients are sensitive" | Reminder templates the partner approves | Blocker — likely | Little; they rarely chase | Held in 2 of 2 larger firms |

**Mobilizer hypothesis:** the office manager, who runs the trial and shows the managing partner the first-afternoon overdue list. Tested by offering the insight "your overdue list is older than your partners think" and watching whether they take it to a partner. **Partner 5:** the office manager answered every email and never brought a partner in; that account went quiet. Recorded as a Friend; the hypothesis stands for the segment.
**Blocker:** other partners at larger firms, handled by the office manager with the approval templates, not by the vendor.
**Cost of no decision:** write-offs and evenings chasing; the "revisit at year-end" stall (design partner 2) costs the firm one more year-end of manual chasing. It costs the other partners almost nothing, which is why they block.

## 3. Blocker Risk Register

| Stakeholder or role | Half | Concern (their words) | Kind of trust | Risk | Mitigation, delivered before the ask |
|---|---|---|---|---|---|
| Marketplace reviewer | Delivery | "Why does an AR tool need contact data?" | Security | High | Scope justification per field; contact data read only for clients with overdue invoices |
| Office manager | Committee | "I won't let a robot email clients" | Automated decisions | High | Every reminder shown with why it was drafted (invoice, days overdue, last contact) and held for approval |
| Other partners | Committee | "Our clients are sensitive" | Change | Medium | A one-paragraph story from design partner 1: the client who paid the day after a polite, approved reminder |

## 4. Re-score Log

| Date | Stakeholder | Change | Trigger |
|---|---|---|---|
| 2026-10-09 | Marketplace reviewer | Dominant → definitive | Contact-data scope request submitted |
| 2026-10-20 | Office manager (committee) | Mobilizer hypothesis held 3 of 5; partner 5 a Friend | Stage 1 design-partner sessions |
```

## What the GTM does with it

The GTM strategy (`gtm-strategy`) cites §2 for the beachhead and adds only the motion decision: consensus is built on a 20-minute product-assisted call where the office manager walks the partners through their own overdue list. It does not copy the committee table.
