# Example 3 — An enterprise multi-tenant platform: job map, outcomes ranked per segment, executor / beneficiary / buyer per tenant role (hardest case)

Self-contained. The hardest common case, at the **enterprise** profile: a multi-tenant, multi-region platform (EU and US regions, per-tenant data residency, a 99.95% availability commitment) for organisations accountable for sensitive data, with two tenant types that buy and work differently (60 enterprise banks, about 3,900 SMB tenants). The data-steward and compliance roles are **this product's** facts, not jobs every product has. It shows Ulwick's job map with an outcome per step, a survey large enough for opportunity scores **ranked per segment** (and what a blended average would have hidden), the executor / beneficiary / buyer split per tenant role, non-consumption in one segment, and consumption-chain jobs turned into onboarding requirements. **Illustrative:** the interviews and survey are part of the example.

## Input

> Personas (approved, enterprise): **Devi**, bank data steward, primary of the findings view, job statement "keep a provably complete record of where regulated data lives across her systems"; **Jo**, SMB IT generalist, primary of the tenant admin console, "answer customer security questionnaires with evidence, on deadline"; **Maya**, bank head of compliance, primary of the evidence workspace; external auditor, secondary; CISO's team, customer persona.
>
> Evidence: switch interviews held by the product owner and sales with six beta tenants (B-1…B-6) and two audit firms (A-1, A-2); an in-product survey of outcome importance and satisfaction (banks n = 61 respondents across 38 tenants, SMB n = 151).

## Working it

- **Survey maths is allowed here, per segment.** With 61 and 151 respondents, opportunity scores mean something. They are computed per segment, never blended: blended, the banks' top outcome drops from 15.0 to 8.2 and falls below the SMB one (see `../references/outcomes-and-ranking.md` §4.3).
- **Executor, beneficiary and buyer differ by tenant role.** At a bank, Devi executes J-1, the external auditor and Maya benefit, the CISO's team buys (or blocks). At an SMB, Jo executes **and** buys.
- **SMB non-consumption.** SMB tenants had no inventory at all until a large prospect's security questionnaire arrived. That frames J-2 around the questionnaire deadline.
- **Consumption-chain jobs drive onboarding.** Banks: pass the CISO's architecture review, keep data in region, provision users through SSO. SMB: connect sources without a consultant.
- **The job map is used for J-1 only**, the job the platform's main line serves; J-2 and J-3 carry outcomes without a map.

## Output — the JTBD analysis (abridged: J-1 in full, J-2 and J-3 shortened)

```markdown
---
name: jtbd-analysis
product: data-accountability-platform
version: 2.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-23
summary: Three jobs across bank and SMB tenants; bank target is confirming new sources are classified (Opp 15.0), SMB target is evidenced questionnaire answers (14.3); ranked per segment.
profile: enterprise
evidence: ideate/interviews/snapshots/2026-09-02-b-1.md … 2026-09-22-a-2.md; ideate/interviews/outcome-survey-2026-10.md
ranking: opportunity score (survey: banks n = 61, SMB n = 151), per segment
traces_to: ideate/user-personas.md; strategy/gtm-strategy.md (two segments); strategy/competitive-analysis.md
---

# Jobs To Be Done Analysis — Data Accountability Platform

## Evidence

| Snapshot | Date | Participant | Segment / role | Interviewer | Interview type |
|---|---|---|---|---|---|
| [2026-09-02-b-1] | 2026-09-02 | B-1 | EU bank, data owner | the product owner | switch |
| [2026-09-04-b-2] | 2026-09-04 | B-2 | EU bank, head of compliance | the product owner + sales | switch |
| [2026-09-09-b-4] | 2026-09-09 | B-4 | EU bank, data owner | the product owner | switch |
| [2026-09-15-b-5] | 2026-09-15 | B-5 | SMB, IT generalist | the product owner | switch |
| [2026-09-16-b-6] | 2026-09-16 | B-6 | SMB, IT generalist and owner | the product owner | story-based |
| [2026-09-22-a-1] | 2026-09-22 | A-1 | Audit firm, senior auditor | the product owner | story-based |
| Outcome survey | 2026-10 | 212 respondents | banks 61, SMB 151 | in-product survey | importance / satisfaction |

## Core Jobs

| ID | Job statement (Ulwick) | Executor | Beneficiary | Buyer | Target outcome |
|---|---|---|---|---|---|
| J-1 | Keep a provably complete record of where regulated data lives across the organisation's systems | Devi (bank data steward) | Maya; the external auditor | CISO's team (bank) | O-1.4 (banks) |
| J-2 | Answer customer security questionnaires with evidence, on deadline | Jo (SMB IT generalist) | The SMB's sales lead | Jo / the SMB owner | O-2.1 (SMB) |
| J-3 | Approve a data platform without adding unmanaged risk | CISO's team (bank) | The bank | CISO's team | O-3.1 (banks) |

---

## J-1: A provably complete record of regulated data

**Job statement (Ulwick):** Keep a provably complete record of where regulated data lives across the organisation's systems
**Executor:** Devi · **Beneficiary:** Maya; the external auditor · **Buyer:** CISO's team

### Job spec

- **Functional:** know every location holding regulated data, and prove it to an auditor
- **Emotional:** not be caught out by a share nobody listed [2026-09-09-b-4]
- **Social:** be the steward the auditor trusts without re-sampling [2026-09-22-a-1]
- **Obstacles:** system owners answer inventory requests late or not at all; classification she cannot check [2026-09-02-b-1]
- **Purchase experience:** passes the CISO team's architecture review; data never leaves the tenant's region [2026-09-04-b-2]
- **Use experience:** a new source shows as classified, or not yet, with the reason visible [2026-09-09-b-4]

### What gets fired

| Alternative | Who uses it | Evidence |
|---|---|---|
| Spreadsheet inventory refreshed before each audit by emailing system owners | Banks | [2026-09-02-b-1] [2026-09-09-b-4] |
| A consultancy's annual data-mapping exercise | Banks | [2026-09-04-b-2] |
| Nothing until a customer or auditor asks (non-consumption) | SMB | [2026-09-15-b-5] |

### Big Hire / Little Hire

- **Big Hire:** the CISO's team approves the architecture pack and the auditor accepts the first evidence export [2026-09-04-b-2] [2026-09-22-a-1]
- **Little Hire:** Devi opens the findings view each morning because new sources appear there before anyone emails her [2026-09-09-b-4]

### Forces of progress

| Force | Specific event | Evidence |
|---|---|---|
| Push | A sampled audit found a file share nobody had listed | [2026-09-09-b-4] |
| Pull | "One place I can point the auditor to" | [2026-09-04-b-2] |
| Anxiety | Silent misclassification she cannot check; data copied out of region | [2026-09-02-b-1] [2026-09-04-b-2] |
| Habit | The audit-time spreadsheet and the consultancy's annual report | [2026-09-02-b-1] |

### Job stories (Klement / Intercom)

#### JS-1.1: A new source appears (trigger)

When a team connects a new storage location without telling me, I want to know within a day whether it holds regulated data, so I can apply the handling rules before it spreads.

- **Evidence:** [2026-09-09-b-4]
- **Implied capability:** detect newly connected sources and report classification status per source

#### JS-1.2: The auditor samples (high stakes)

When the auditor picks a system at random, I want to show where its regulated data is and how we know, so I can close the sample without a finding.

- **Evidence:** [2026-09-22-a-1] [2026-09-02-b-1]
- **Implied capability:** per-system evidence with the classification method and date

### Job map and desired outcomes

| ID | Job-map step | Desired-outcome statement (Ulwick) | Evidence |
|---|---|---|---|
| O-1.1 | Define | Minimize the time it takes to decide which systems are in scope for this audit | [2026-09-04-b-2] |
| O-1.2 | Locate | Minimize the likelihood that a storage location is missing from the inventory | [2026-09-09-b-4] |
| O-1.3 | Prepare | Minimize the effort to connect a new source without a change request | [2026-09-02-b-1] |
| O-1.4 | Confirm | Minimize the time it takes to confirm that a newly connected source is fully classified | [2026-09-09-b-4] |
| O-1.5 | Execute | Minimize the likelihood that regulated data is classified as non-regulated | [2026-09-02-b-1] |
| O-1.6 | Monitor | Minimize the time between a regulated file appearing and the steward knowing | [2026-09-09-b-4] |
| O-1.7 | Modify | Minimize the effort to correct a wrong classification so that it stays corrected | [2026-09-02-b-1] |
| O-1.8 | Conclude | Minimize the time it takes to hand the auditor evidence they accept | [2026-09-22-a-1] |

**Scores — banks (n = 61)**

| ID | Importance | Satisfaction | Opportunity |
|---|---|---|---|
| O-1.4 | 9.1 | 3.2 | 15.0 |
| O-1.2 | 9.0 | 4.1 | 13.9 |
| O-1.8 | 8.7 | 4.4 | 13.0 |
| O-1.5 | 8.9 | 6.8 | 11.0 |
| O-1.3 | 6.2 | 5.9 | 6.5 |

**Scores — SMB (n = 151)**

| ID | Importance | Satisfaction | Opportunity |
|---|---|---|---|
| O-1.8 | 7.9 | 3.1 | 12.7 |
| O-1.3 | 7.4 | 3.5 | 11.3 |
| O-1.4 | 5.0 | 4.6 | 5.4 |

**Target outcome:** banks O-1.4; SMB O-1.8 (served through J-2). Well served for banks: O-1.5 (importance 8.9, satisfaction 6.8) is important but already met fairly well by their current classifier, so accuracy is table stakes there, not the differentiator.

---

## J-2: Evidenced questionnaire answers on deadline (SMB)

**Job statement (Ulwick):** Answer customer security questionnaires with evidence, on deadline
**Executor:** Jo · **Beneficiary:** the SMB's sales lead · **Buyer:** Jo / the SMB owner

### What gets fired

| Alternative | Who uses it | Evidence |
|---|---|---|
| Answering from memory and asking around (non-consumption of any inventory) | SMB | [2026-09-15-b-5] |

### Big Hire / Little Hire

- **Big Hire:** the first questionnaire answered with evidence before the deadline [2026-09-15-b-5]
- **Little Hire:** [assumption] Jo returns before each new questionnaire, not daily

### Forces of progress

| Force | Specific event | Evidence |
|---|---|---|
| Push | A large prospect's 140-question security questionnaire due in ten days | [2026-09-15-b-5] |
| Pull | Answers she can attach evidence to | [2026-09-16-b-6] |
| Anxiety | A setup that needs a consultant | [2026-09-16-b-6] |
| Habit | Asking colleagues by chat | [2026-09-15-b-5] |

### Job stories (Klement / Intercom)

#### JS-2.1: The questionnaire arrives (trigger)

When a prospect sends a security questionnaire with a deadline, I want to know which answers I can back with evidence, so I can return it on time without guessing.

- **Evidence:** [2026-09-15-b-5]
- **Implied capability:** map questionnaire controls to available evidence

### Desired outcomes

**Scores — SMB (n = 151)**

| ID | Importance | Satisfaction | Opportunity |
|---|---|---|---|
| O-2.1 | 8.6 | 2.9 | 14.3 |

**Scores — banks (n = 61)**

| ID | Importance | Satisfaction | Opportunity |
|---|---|---|---|
| O-2.1 | 4.8 | 6.0 | 4.8 |

O-2.1: Minimize the time it takes to answer a customer security questionnaire with evidence. **Target outcome (SMB).**

---

## J-3: Approve without unmanaged risk (the bank buyer's job)

**Job statement (Ulwick):** Approve a data platform without adding unmanaged risk
**Executor:** CISO's team · **Beneficiary:** the bank · **Buyer:** CISO's team

### What gets fired

| Alternative | Who uses it | Evidence |
|---|---|---|
| Refusing the purchase (no decision) | Banks | [2026-09-04-b-2] |

### Big Hire / Little Hire

- **Big Hire:** the architecture pack answers residency, access and sub-processor questions in one review [2026-09-04-b-2]
- **Little Hire:** [assumption] the quarterly access report needs no follow-up questions

### Forces of progress

| Force | Specific event | Evidence |
|---|---|---|
| Push | The consultancy's annual exercise was out of date within months | [2026-09-04-b-2] |
| Pull | [assumption] continuous evidence instead of an annual report | — |
| Anxiety | Regulated data copied out of region by a vendor | [2026-09-04-b-2] |
| Habit | A known consultancy relationship | [2026-09-04-b-2] |

### Job stories (Klement / Intercom)

#### JS-3.1: The architecture review (trigger)

When a business unit asks to buy a tool that reads regulated data, I want to confirm where that data goes and who can reach it, so I can approve without accepting a risk I cannot see.

- **Evidence:** [2026-09-04-b-2]
- **Implied capability:** a per-tenant architecture pack: regions, sub-processors, access paths

---

## Onboarding Requirements

| ID | Requirement | From |
|---|---|---|
| ONB-1 | Architecture pack (residency, sub-processors, access paths) available before the trial starts | J-3 Big Hire; J-1 purchase experience |
| ONB-2 | Tenant data processed and stored only in the tenant's chosen region, shown in the console | J-1 and J-3 anxiety |
| ONB-3 | Users provisioned through the bank's SSO with SCIM; no local accounts | J-3 consumption chain (install) |
| ONB-4 | SMB: connect the first source in under an hour without a consultant | J-2 anxiety; consumption chain (set up) |
| ONB-5 | Import the bank's existing inventory spreadsheet as the starting record | J-1 habit |
| ONB-6 | Every classification shows its method and date, and can be corrected | J-1 anxiety; O-1.7 |

## Related Jobs

- Respond to a data-subject access request by locating every copy of one person's data (banks; expansion).

## Assumptions to Validate

| Item | Validation question (a specific past event) | Wrong if |
|---|---|---|
| J-2 Little Hire | "Between the last two questionnaires, when did you open any compliance tool?" | Jo uses it weekly: a different Little Hire |
| J-3 pull | "What did the last annual data-mapping report change in what you approved?" | The CISO team never uses it |
| US-region tenants | (no US tenant interviewed) | — recruit one before the US launch |

## Hand-off

- `impact-mapping`: target outcomes O-1.4 (banks) and O-2.1 (SMB), one impact map branch per segment.
- `moscow-prioritization`: outcomes per segment; never one blended ranking.
- `business-model-canvas`: J-1…J-3 and the per-segment targets by ID, one Value Proposition Canvas per segment.
- `competitive-analysis`: annual consultancy exercise and SMB non-consumption added to the alternatives.
- `nfr-specification`: ONB-2 and ONB-3 as residency and identity constraints.

## Version Log

| Version | Date | Change | Trigger |
|---|---|---|---|
| 1.0.0 | 2026-09-25 | First analysis from B-1…B-6, A-1, A-2 | Ideate |
| 2.0.0 | 2026-10-23 | Outcome survey added; ranking moved from comparison to per-segment scores; blended table removed | Survey sample reached both segments |
```

## Why this is the enterprise shape

| Choice | Reason |
|---|---|
| Job map for J-1 | Eight steps make sure the outcomes cover the whole job, not just the visible middle |
| Two score tables per outcome set | A blended average would put the SMB outcome first and hide the banks' target |
| Version 1.0 ranked by comparison, 2.0 by score | The method follows the sample: comparison at eight interviews, scores only once the survey existed |
| J-3 as its own job | The bank buyer's job (approve without unmanaged risk) is not Devi's; it drives the Big Hire |
| Onboarding requirements from consumption-chain jobs | Residency, SSO and a no-consultant setup decide adoption as much as any feature |
