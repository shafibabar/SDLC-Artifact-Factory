# Example 3 (enterprise): Cross-Border Subscription Refund

Self-contained input and output. The point: a multi-tenant product with regulatory and tenant-set rules, many rules signalling a split, open questions that block, and answers folded back one at a time.

## Input

- Product: a billing platform used by many publishers (tenants), selling in several countries. Profile **enterprise**.
- US-42: "As a publisher's support agent (P-3), I want to refund a subscriber's renewal, so that a justified complaint is settled without a finance ticket." Seed example: Lena, at publisher Northwind, refunds a €120 renewal charged 3 days ago.
- `ideate/requirements.md`: BR-11 "A renewal refunded within the buyer's statutory withdrawal window is refunded in full, never in part; the window per country is the table maintained by compliance." BR-12 "An agent may refund alone up to and including the publisher's agent refund limit; each publisher sets its own." BR-13 "Tax is reversed in the same proportion as the amount refunded." NFR-SEC-04: tenant isolation. Compliance table row for this buyer: 14 days (illustrative, not legal advice).
- Round 1 asked Q-1 to Q-4. Product owner, 2026-11-25: "Q-1: above the limit it goes to a publisher finance approver. Q-2: partial refunds are their own story. Q-4: yes, original currency and amount." No reply on Q-3.

## Output: `ideate/example-maps/US-42.md` (after the first replies)

````markdown
---
name: example-map
product: tollgate
story-id: US-42
version: 1.1.0
phase: ideate
owner: requirements-analyst
created: 2026-11-25
summary: Agent refund of a renewal, five rules; not ready until the effect on access (Q-3) is decided.
profile: enterprise
run: agent-run
readiness: not-ready
traces_to: ideate/user-stories.md (US-42); ideate/requirements.md (BR-11, BR-12, BR-13); ideate/nfr-specification.md (NFR-SEC-04)
---

# Example Map: US-42 Support agent refunds a renewal

## Story

As a publisher's support agent (P-3), I want to refund a subscriber's renewal, so that a justified complaint is settled without a finance ticket.

- Seed example: Lena at Northwind refunds a €120 renewal charged 3 days ago.
- Cited rules and targets: BR-11, BR-12, BR-13, NFR-SEC-04

## How This Map Was Made

Agent-run: one agent (requirements-analyst) played all three perspectives in turn; no workshop was held.

- Read: ideate/user-stories.md (US-42); ideate/requirements.md (BR-11 to BR-13); ideate/nfr-specification.md (NFR-SEC-04); ideate/user-personas.md (P-3)

| Perspective | What it raised |
|---|---|
| Customer | Q-1, Q-2, Q-3: over-limit refunds, partial refunds, access afterwards |
| Developer | Q-4, R5: currency, and the same refund sent twice |
| Tester | R2.E3, R4: exactly on the limit, another publisher's subscriber |

## Rules and Examples

### R1: Inside the buyer's withdrawal window the renewal is refunded in full (BR-11)
- Source: ideate/requirements.md (BR-11)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R1.E1 | Happy | The compliance table gives the buyer 14 days; Lena refunds a €120 renewal on day 3 | €120.00 is refunded | ideate/requirements.md (BR-11) |
| R1.E2 | Negative | Same buyer, day 3; Lena enters €60 | The part refund is refused, naming the full amount due | ideate/requirements.md (BR-11) |

### R2: An agent refunds alone only up to the publisher's limit (BR-12)
- Source: ideate/requirements.md (BR-12)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R2.E1 | Happy | Northwind's limit is €150; Lena refunds €120 | The refund is made at once | ideate/requirements.md (BR-12) |
| R2.E2 | Negative | Northwind's limit is €150; Lena refunds €200 | Nothing is paid; it waits for a Northwind finance approver | product owner, 2026-11-25 (Q-1) |
| R2.E3 | Edge | Northwind's limit is €150; Lena refunds €150.00 | The refund is made at once | ideate/requirements.md (BR-12) |

### R3: Tax is reversed in proportion, in the original currency (BR-13)
- Source: ideate/requirements.md (BR-13); product owner, 2026-11-25 (Q-4)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R3.E1 | Happy | €120.00 including €20.00 tax is refunded in full | €120.00 goes back in euros and the credit note shows €20.00 tax | ideate/requirements.md (BR-13) |
| R3.E2 | Negative | The euro has moved 2% against the publisher's dollar books since the charge | The buyer still receives exactly €120.00 | product owner, 2026-11-25 (Q-4) |

### R4: An agent sees and refunds only their own publisher's subscribers
- Source: ideate/nfr-specification.md (NFR-SEC-04)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R4.E1 | Happy | Lena (Northwind) opens Northwind subscriber S-881 | The renewal can be refunded | ideate/nfr-specification.md (NFR-SEC-04) |
| R4.E2 | Negative | Lena opens the reference of a Southgate subscriber, S-204 | She is told no such subscriber exists, and the attempt is recorded | assumption (Q-5) |

### R5: One renewal is refunded at most once
- Source: assumption (Q-6)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R5.E1 | Happy | Renewal R-7 has no refund; Lena refunds it | One refund of €120.00 is paid | assumption (Q-6) |
| R5.E2 | Negative | Lena and Omar both refund R-7 within the same minute | One refund of €120.00 is paid; the second is told it is already refunded | assumption (Q-6) |

## Questions for the Product Owner

| ID | Question | Affects | Why it matters | Recommendation | Status | Answer |
|---|---|---|---|---|---|---|
| Q-1 | What happens above the agent's limit? | R2 | Money paid without approval | A finance approver decides | answered | Goes to a publisher finance approver — product owner, 2026-11-25 |
| Q-2 | Are partial refunds outside the window part of this story? | story | A second calculation and tax case | Separate story | moved | moved to US-58 — agreed by product owner, 2026-11-25 |
| Q-3 | Does a refunded subscriber keep access until the period ends? | story | Changes what the subscriber can read, and may differ by country | Access ends when the refund is made | open | — |
| Q-4 | Is the refund in the original currency and amount? | R3 | Who carries exchange movement | Original currency and amount | answered | Yes — product owner, 2026-11-25 |
| Q-5 | What does an agent see for another publisher's subscriber, and is it recorded? | R4 | Revealing that a subscriber exists leaks tenant data | "No such subscriber", and record it | open | — |
| Q-6 | May a renewal ever be refunded twice, for example after a reversed refund? | R5 | Double payment | Never more than once | open | — |

## Split Check

- Rules: 5 · Open questions: 3
- Decision: split agreed: partial refunds are US-58; approver workflow proposed as its own story if answering Q-1 adds more rules

## Readiness

**Verdict:** Not ready
- Blocking: Q-3, Q-5, Q-6
````

## The next round

The product owner replies, 2026-11-26: "Q-3: ends at once. Q-5 and Q-6: your recommendations."

1. Q-3, Q-5 and Q-6 become `answered`, each with the reply, "product owner" and the date.
2. R4.E2 and R5 change source to `product owner, 2026-11-26 (Q-n)`.
3. Q-3 adds R6, "Access ends when the refund is made", sourced to the reply, with a satisfying and a breaking example (a refund still awaiting approval).
4. Six rules is a split signal: propose moving R2's approval path to its own story and let the product owner decide. If that raises a question, the map stays not ready.
5. Update the counts, verdict, summary and version, validate, and only then present the map for approval.

## What to notice

- The window comes from the compliance table; the map states no legal figure of its own.
- Silence on Q-3 left it open.
- Isolation is sourced to the NFR, but the exact refusal was not, so that outcome is an assumption although the rule is not.
