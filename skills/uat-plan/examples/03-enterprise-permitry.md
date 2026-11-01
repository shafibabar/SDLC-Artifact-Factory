# Example 3 — Enterprise: UAT, OAT, contractual and regulatory acceptance for council A, each with its own executor, independence level and sign-off line (hardest case)

Self-contained. **Permitry** is a multi-tenant SaaS platform for local councils to receive and decide building and planning permit applications. Each council is a tenant. Release 1 is **council A only**, going live on 1 March. Its eight Musts are the walking skeleton confirmed by MoSCoW: US-40 officers sign in with their own council's accounts · US-11 applicant sees the checklist for their application type · US-70 applicant submits with documents · US-42 applicants see only their own applications (regulatory: personal data, NFR-SEC-01) · US-71 applicant tracks status online (contractual: council A's service agreement, schedule 2) · US-80 officer sees new applications in a queue · US-81 officer marks valid or invalid with missing items · US-82 applicant is told what is missing. The skeleton has a manual cell: operations creates council A's tenant from the runbook. NFRs: RPO 15 min, RTO 2 h, and the service survives losing one availability zone.

## Input

> **User:** "Plan acceptance for council A's go-live. OAT isn't needed: platform-engineer ran DR drills in Deploy. Council A's service manager signs for them. One thing: the pilot found a High on large uploads, so write the exit criteria as 'zero Critical; Highs allowed with a fix plan' so we're covered."

## Working it

- **All five types considered.** UAT, yes. **OAT, yes**: Deploy's drills ran on the pre-production cluster before council A's tenant existed. The tenant-provisioning runbook (the skeleton's manual cell), a restore of council A's data within RPO / RTO, zone failover, and alerting on council A's queue all need their own evidence, from platform-engineer, in their own window. **Contractual, yes**: schedule 2 is a signed acceptance clause, traced to US-71 and UAT-71a, and accepted by council A's contract owner. **Regulatory, yes**: `compliance-design` names the data-protection law and council A's records rules. Evidence is `compliance-verification`'s attestations plus UAT-42a and UAT-42b, accepted by council A's data protection officer. **Alpha / beta**: councils B and C come later, through `beta-program-design`. Not this release.
- **One sign-off line per type.** UAT is accepted by the product owner and council A's service manager; contractual by the contract owner; regulatory by the DPO; OAT by the product owner, on platform-engineer's evidence.
- **Independence per type.** UAT is executed by council A's officers and four applicants from its user panel (level 4). The penetration test behind the regulatory attestation is external (level 5). OAT is run by platform-engineer, who built the mechanism (level 2, within the team), and the plan says so.
- **The user's exit wording is not written in.** A High rule belongs in one place, `acceptance-sign-off`. The plan points there. Whether the upload High can ride on a conditional sign-off is decided at sign-off, against that rule. The plan does not pre-approve it.
- **Per tenant wave.** Release 1 has one tenant, so one wave: officers first on day 1–2, then panel applicants on day 3–4 once the officer queue is proven. The wave structure is written down so councils B and C can reuse it.

## Output — `customer-validation/uat-plan.md`

````markdown
---
name: uat-plan
product: permitry
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2027-01-25
summary: Permitry Release 1 (council A) acceptance: UAT over 8 Musts, OAT, contractual (schedule 2) and regulatory (data protection), each with its own executor and sign-off line.
profile: enterprise
release: Release 1 — Walking Skeleton (council A)
traces_to: ideate/moscow.md; ideate/story-map.md; ideate/acceptance-criteria/*.md; quality/features/*.feature; design/compliance-design.md; council A service agreement schedule 2
---

# UAT Plan — Permitry, Release 1 (council A)

## Acceptance Types in Scope
| Type | In scope | Scope | Executor | Evidence | Sign-off line |
|---|---|---|---|---|---|
| User acceptance (UAT) | yes | The eight Musts | Council A officers; four user-panel applicants | uat-scenario results; EX-1–EX-3 debriefs | Product owner + council A service manager |
| Operational acceptance (OAT) | yes | Tenant provisioning runbook; restore of council A within RPO 15 min / RTO 2 h; one-zone failover; queue alerting | platform-engineer | Runbook run log; timed restore; failover drill; test alert received | Product owner |
| Contractual | yes | Schedule 2: "Applicants can see the status of their application online from the first day of service" | User-panel applicants | UAT-71a result | Council A contract owner |
| Regulatory | yes | Data-protection and records requirements from compliance-design | Officers, applicants; external assessor for the pen test | compliance-verification attestations; UAT-42a, UAT-42b | Council A data protection officer |
| Alpha / beta | no, because councils B and C join in Release 3 via beta-program-design | — | — | — | — |

## Scope Traceability
| Must story | Acceptance criteria | Feature file | UAT scenarios | Risk |
|---|---|---|---|---|
| US-40 Officers sign in with council accounts | AC-US-40 | features/officer-sign-in.feature | UAT-40a | high |
| US-11 Checklist for the application type | AC-US-11 | features/checklist.feature | UAT-11a, UAT-11b | normal |
| US-70 Submit with documents | AC-US-70 | features/submit.feature | UAT-70a, UAT-70b | high: the pilot's upload High |
| US-42 Applicants see only their own applications | AC-US-42 | features/applicant-isolation.feature | UAT-42a, UAT-42b | high: regulatory |
| US-71 Track status online | AC-US-71 | features/status.feature | UAT-71a | high: contractual |
| US-80 Queue of new applications | AC-US-80 | features/queue.feature | UAT-80a | normal |
| US-81 Mark valid or invalid | AC-US-81 | features/validate.feature | UAT-81a, UAT-81b | normal |
| US-82 Applicant told what is missing | AC-US-82 | features/missing-items.feature | UAT-82a | normal |

## Out of Scope
Shoulds US-10, US-12, US-15; Could US-14; every Won't this time, including US-41 (cross-council isolation; it becomes a regulatory Must when council B goes live).

## Roles and Independence
- **Executor:** council A planning officers (3); four applicants from council A's user panel; platform-engineer for OAT
- **UAT lead:** requirements-analyst
- **Accepting authority:** the product owner + council A's service manager (UAT); council A's contract owner (contractual); council A's data protection officer (regulatory)
- **Independence level (ISTQB):** UAT: business or user community · regulatory pen test: external · OAT: within team (platform-engineer built the mechanisms; stated as a limitation)

## Environment
- **Environment:** production, council A tenant on the canary; OAT restore and failover on the staging replica of production configuration
- **Version / digest:** permitry 1.0.0 @ sha256:b19c…
- **Feature flags:** applicant-portal = on for council A's officers (wave 1), then for the four panel accounts (wave 2)
- **Test data:** seeded council A test applications, one per application type, plus a 180 MB drawing set

## Entry Criteria
- [ ] Quality-phase gates passed, including compliance verification (pipeline run #988; attestation set CV-7)
- [ ] Deployed to council A's tenant at the digest that will ship
- [ ] applicant-portal flag scoped per wave
- [ ] Twelve uat-scenarios traced to the eight Musts' acceptance criteria; schedule 2 traced to UAT-71a
- [ ] Pass threshold and defect bar agreed by every accepting party on 2027-02-01, before execution
- [ ] Three charters drafted
- [ ] Officers and panel applicants briefed and booked; platform-engineer booked for the OAT window; DPO and contract owner booked for the decision

## Exit Criteria
- Every scenario has a result: Pass, Fail, Blocked or Not run; Blocked and Not run fail this criterion until run
- Pass threshold: 100% of Must scenarios, including the contractual and regulatory ones
- Open defects: per the defect rule in acceptance-sign-off (the pilot's upload defect is re-tested in UAT-70b and judged there)
- All feedback triaged (feedback-template)
- Exploratory charters run and debriefed: 3 of 3
- Every acceptance type in scope has a result and its signatory's review
- Residual risk evaluated and written in the Completion Summary

## Schedule
| Day | Date | Activity |
|---|---|---|
| 0 | 2027-02-08 | Entry criteria verified; wave 1 briefed |
| 1–2 | 2027-02-09 to 2027-02-10 | Wave 1: officers run UAT-40a, UAT-80a, UAT-81a/b; EX-3 |
| 3–4 | 2027-02-11 to 2027-02-12 | Wave 2: panel applicants run the applicant scenarios; EX-1, EX-2 |
| 1–4 | 2027-02-09 to 2027-02-12 | OAT window on the staging replica: restore, failover, alert, provisioning runbook |
| 5 | 2027-02-15 | Compile results; triage feedback |
| 5–7 | 2027-02-15 to 2027-02-17 | Re-test fixes; regression-check neighbouring scenarios |
| 8 | 2027-02-18 | Acceptance decision with every signatory (acceptance-sign-off) |

## Exploratory Charters
| # | Charter | Time-box | Explorer | Heuristics |
|---|---|---|---|---|
| EX-1 | Explore submitting an application, with an expired session halfway through a 180 MB upload, to discover whether the applicant loses work or sees a half-submitted application | 60 min | Panel applicant | interruptions, boundaries |
| EX-2 | Explore what one applicant can reach, with two panel accounts and copied application links, to discover whether anything of one applicant's shows to the other | 60 min | Panel applicant | saboteur, configuration |
| EX-3 | Explore the officer queue, with applications arriving while an officer is mid-validation, to discover whether two officers can validate the same application | 45 min | Officer | interruptions, CRUD |

## Repeatability
Officers onboarded by the tenant-provisioning runbook alone; note any step that needed engineering help, because councils B and C will follow the same runbook.

## Completion Summary
- **Planned vs run:** [filled after execution, per type]
- **Open defects:** [ … ]
- **Residual risk:** OAT executed by the team that built it; [ … ]
- **Recommendation:** [ … ]
````

## What the weak first draft looked like

```markdown
Acceptance: UAT with council A (service manager signs)
OAT: covered by Deploy DR drills
Exit: zero Critical; Highs allowed with a fix plan
```

Contractual and regulatory acceptance missing for a product with a signed clause and personal data; OAT evidence from before the tenant existed; a defect rule written into the plan and pre-approving a known High; one signatory for four kinds of acceptance; no independence levels; no waves.

## Why this is right at enterprise

| Choice | Reason |
|---|---|
| Four types in scope, each with its own line | ISTQB's forms; Hambling: each acceptance has its own accepting party |
| Contract clause traced to a Must and a scenario | Contractual acceptance checks the contract's words, nothing more |
| Regulatory from compliance-design | The product's scope decides the law; the skill never hard-codes one |
| OAT re-run for this tenant | Evidence must be about what ships, not an earlier cluster |
| Independence stated per type, including the weak one | A known limitation, declared, is reviewable |
| Pointer, not a High rule | The single rule lives in `acceptance-sign-off`; the plan does not pre-decide it |
| Waves written down | Councils B and C reuse the same plan shape |
