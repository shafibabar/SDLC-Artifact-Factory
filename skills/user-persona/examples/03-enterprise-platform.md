# Example 3 — An enterprise multi-tenant platform: personas per tenant role, served personas, weighted matrix, retirement (hardest case)

Self-contained. The hardest common case, at the **enterprise** profile: a multi-tenant, multi-region platform (EU and US regions, per-tenant data residency, a 99.95% availability commitment) with two tenant types that work differently, five interfaces, an outside auditor who reads evidence but never configures anything, and people whose records are scanned and who never see the product. The **data steward** and **compliance officer** roles appear because they are *this product's* facts; they are not personas every product needs. Interviews are illustrative, as in example 2.

## Input

> A B2B platform for organisations accountable for sensitive data: 4,000 tenants (60 enterprise, the rest SMB). Lines: **Discover** (find and classify), **Govern** (policy and access reviews), **Prove** (audit evidence). Interfaces: tenant admin console · Discover findings view · Govern access-review queue · Prove evidence workspace · internal operations console (the platform / SRE team).
>
> Stakeholder map §2: EU banks (head of compliance = economic buyer and Mobilizer hypothesis; CISO's team = Blocker likely; data owners = users; procurement) and SMB (IT generalist starts the trial; owner pays).
>
> Evidence: beta sessions with six tenants held by the product owner and sales (notes B-1…B-6); support tickets from the beta; two audit firms piloting Prove (notes A-1, A-2).

## Working it

- **Roles first, per tenant type.** A bank's data owner and an SMB's IT generalist both open the Discover findings view, but on the behavioural variables they differ: the data owner verifies each finding against what she knows of her own systems; the IT generalist accepts findings and wants a short list to act on. Two personas on one interface means choosing **one primary** for it. The data steward (bank data owners) is primary of the findings view; the IT generalist is primary of the tenant admin console, where SMB set-up happens, and **secondary** on findings (a "top ten" summary added for her).
- **One primary per interface, five interfaces, five primaries** is above the "about three" warning, so it was raised with the user. Their answer: the operations console is an internal tool and the access-review queue is Govern's own product line; both stay, and the warning is noted in the artifact. That is the rule working, not being ignored.
- **The auditor reads evidence but never configures anything.** Fully served by the compliance officer's evidence workspace plus a read-only share link: **secondary** of Prove. The ux-architect's question "what about the auditor?" is answered by the type list, not discovered at journey mapping.
- **The CISO's team buys (or blocks) and rarely uses the product**: a **customer** persona, feeding the architecture-pack and trust story.
- **People whose records are scanned never touch the product** but are affected by every classification: a **served** persona. It carries constraints (minimise what is read; never copy content out of region), not screens.
- **Negative persona** from the GTM's disqualifier: single-cloud, single-region organisations wanting a bundled classifier.
- **Retirement.** v1 had an "SMB compliance generalist" persona. Beta notes showed SMB tenants have no compliance role: the IT generalist does it all. Retired, not deleted, and its stories re-pointed.

## Output — the personas artifact (abridged: three of nine persona blocks in full)

```markdown
---
name: user-personas
product: data-accountability-platform
version: 2.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-23
summary: Personas per tenant role across five interfaces: bank data steward and compliance officer, SMB IT generalist, platform operator; auditor secondary, data subjects served.
profile: enterprise
grounding: mixed
authored-by: requirements-analyst (AI)
evidence: interviews: B-1…B-6 (beta tenants), A-1, A-2 (audit firms), held by the product owner and sales; second-hand: beta support tickets
review-by: 2027-03-31
traces_to: strategy/gtm-strategy.md (ICP, two segments); strategy/stakeholder-map.md §2; problem statement
---

# User Personas — Data Accountability Platform

## Persona Set

| Persona | Tenant type | Type | Interface | Grounding | Status |
|---|---|---|---|---|---|
| Devi, data steward (data owner) | EU bank | Primary | Discover findings view | MIXED (8 of 10) | active |
| Maya, compliance officer (head of compliance) | EU bank | Primary | Prove evidence workspace | MIXED (6 of 9) | active |
| Lukas, access reviewer (system owner) | EU bank | Primary | Govern access-review queue | PROTO | active |
| Jo, IT generalist | SMB | Primary; Secondary on findings | Tenant admin console | MIXED (5 of 9) | active |
| Ravi, platform operator | Internal | Primary | Operations console | MIXED (4 of 8) | active |
| External auditor | (bank's auditor) | Secondary | Prove evidence workspace (read-only) | MIXED (3 of 5) | active |
| CISO's team | EU bank | Customer | — | MIXED (2 of 5) | active |
| Data subjects | all | Served | — | PROTO | active |
| Single-region, single-cloud organisations | — | Negative | — | PROTO | active |
| SMB compliance generalist | SMB | — | — | — | retired 2026-09-30 |

**Primary count:** five, above the "about three" signal. Accepted by the user on 2026-10-20: the operations console is internal, and the access-review queue is Govern's own line.

## Behavioural Variables (excerpt)

| Variable | B-1 data owner | B-4 data owner | B-2 head of compliance | B-5 IT generalist | B-6 IT generalist | A-1 auditor |
|---|---|---|---|---|---|---|
| Trust: accepts findings ↔ verifies each against own knowledge | verifies | verifies | samples | accepts | accepts | verifies the evidence chain, not findings |
| Activity: daily in the product ↔ before an audit only | daily | daily | monthly, daily before audit | weekly | weekly | audit window only |
| Skill: knows where data lives ↔ knows the control framework | data | data | framework | neither deeply | neither deeply | framework |
| Motivation: avoid a missed finding ↔ answer a questionnaire fast | avoid miss | avoid miss | avoid audit finding | answer fast | answer fast | defensible opinion |

**Patterns:** bank data owners → Devi; SMB IT generalists → Jo; head of compliance → Maya; auditors → secondary on Prove. **Gap:** no US-region tenant interviewed; recruit one before the US launch.

---

## Persona: Devi, data steward (data owner)

**Type:** Primary · **Interface:** Discover findings view
**Grounding:** MIXED — 8 of 10 load-bearing attributes interview-grounded
**Status:** active

**Role and context:** owns the data in two or three business systems at an EU bank with data in two regions `[B-1, B-4]`
**Distinguishing variables:** verifies every finding · daily in the product · knows where data lives `[B-1, B-4]`

### Goals
- **End goals:** keep a provably complete record of where regulated data lives in her systems `[B-1, B-4]`
- **Experience goals:** never feel the tool knows her data better than she does `[B-4 · 2026-09-12]`
- **Life goals:** be the person compliance trusts, not the one it audits `[assumption]`

### Forces and context
- **Current approach (habit):** a spreadsheet inventory refreshed before each audit by asking system owners `[B-1, B-4]`
- **Primary frustration:** the inventory is stale the week after it is finished, and she cannot prove completeness `[B-1 · 2026-09-08]`
- **Trigger (push):** a sampled audit finds a share nobody listed `[B-4]`
- **Adoption barrier (anxiety):** silent misclassification she cannot check `[B-1, B-4, support tickets]`
- **Trust in automated output:** verifies each finding; needs the reason and evidence beside it and a correct-this control; three wrong findings in a week and she stops using it `[B-4 · 2026-09-12]`
- **Time to first value:** the first scan must find something her spreadsheet missed `[assumption]`

### Job
- **Job statement:** keep a provably complete record of where regulated data lives across her systems

### Validation questions
| Attribute | Ask | Wrong if |
|---|---|---|
| Life goal | "After the last audit, who did you report to and what did they ask?" | Recognition comes from delivery, not compliance |
| First scan must surprise | "When you tried the last discovery tool, what made you keep or drop it?" | Coverage, not surprise, was the deciding factor |

---

## Persona: Jo, IT generalist (SMB)

**Type:** Primary · **Interface:** tenant admin console · Secondary on the Discover findings view (top-ten summary)
**Grounding:** MIXED — 5 of 9 load-bearing attributes interview-grounded
**Status:** active

**Role and context:** the only IT person at a 40–200-staff company; also answers customers' security questionnaires `[B-5, B-6]`

### Goals
- **End goals:** answer a customer's security questionnaire with evidence instead of guesses `[B-5, B-6]`
- **Experience goals:** set it up in an afternoon without reading documentation `[B-6]`

### Forces and context
- **Current approach (habit):** answers from memory and asks around `[B-5]`; non-consumption until a customer asks
- **Trigger (push):** a large prospect's security questionnaire with a deadline `[B-5 · 2026-09-15]`
- **Adoption barrier (anxiety):** a setup that needs a consultant `[assumption]`
- **Trust in automated output:** accepts findings once they look plausible; wants a short list, not a full inventory `[B-5, B-6]`

### Job
- **Job statement:** answer customer security questionnaires with evidence, on deadline

### Validation questions
| Attribute | Ask | Wrong if |
|---|---|---|
| Barrier: needs a consultant | "Last tool you set up alone — where did you get stuck?" | Setup help is welcome; the barrier is price |

---

## Persona: data subjects — Served

**Type:** Served
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from the vision and the security design constraints · no user research
**Status:** active

**Role and context:** customers and employees of tenants whose records are scanned; never see the product `[problem statement]`
**Constraints on the design:** read the minimum needed to classify; never copy content out of the tenant's region; findings show locations, not record contents `[assumption]`

---

[Blocks for Maya, Lukas, Ravi, the external auditor, the CISO's team and the negative persona follow the same template.]

## Persona-Weighted Feature Matrix

| Epic | Devi (×3) | Maya (×3) | Jo (×2) | Ravi (×2) | Auditor (×1) | Data subjects (×1) | Weighted |
|---|---|---|---|---|---|---|---|
| Finding with reason, evidence and correct-this | 3 | 2 | 1 | 0 | 2 | 1 | 20 |
| Evidence export with chain of custody | 1 | 3 | 1 | 0 | 3 | 0 | 17 |
| Afternoon self-serve setup | 0 | 0 | 3 | 1 | 0 | 0 | 8 |
| Per-region isolation dashboard | 0 | 1 | 0 | 3 | 1 | 2 | 12 |

Input to `moscow-prioritization`, not the decision.

## Foundation (excerpt)

| Factoid | Source | Supports |
|---|---|---|
| "I re-check every classification against what I know is in the system" | B-4 · 2026-09-12 | Devi · trust |
| Three of six beta tickets were "finding looks wrong, can't see why" | support tickets | Devi · adoption barrier |
| SMB beta tenants had no compliance role; the IT generalist did it | B-5, B-6 | retirement of "SMB compliance generalist" |

## Lifecycle

- **Review by:** 2027-03-31, and before the US-region launch
- **Reopen when:** a journey map finds a job no persona covers · a tenant type is added · a beta or audit-firm session contradicts an attribute
- **Reuse:** the auditor persona is shared with any future Prove-only product; the bank personas are not reused for SMB
- **Retired personas:** SMB compliance generalist · 2026-09-30 · no such role in SMB tenants (B-5, B-6) · stories re-pointed to Jo

## Version Log

| Version | Date | Change | Trigger |
|---|---|---|---|
| 1.0.0 | 2026-08-20 | First set, PROTO | Ideate start |
| 2.0.0 | 2026-10-20 | SMB compliance generalist retired; auditor added as secondary; tags from B-1…B-6, A-1, A-2 | Beta sessions; ux-architect journey-map review asked "what about the auditor?" |
```

## What enterprise added over standard

| Element | Why here |
|---|---|
| Personas per tenant type on a shared interface | The same screen serves two behaviour patterns; one primary must be chosen |
| Served persona with design constraints | The product acts on people who never use it |
| Weighted matrix | Six personas' needs, scored separately, feed MoSCoW without being pooled |
| Foundation | A reviewer can check which evidence stands behind each persona |
| Retirement and reuse policy | Personas outlive one release; stale ones must be withdrawn visibly |
