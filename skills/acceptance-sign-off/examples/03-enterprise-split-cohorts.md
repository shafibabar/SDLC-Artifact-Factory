# Example 3 — Enterprise: one council accepts, another refuses on a contract clause; one sign-off widens one cohort, holds the other, and records the re-attempt as an addendum (hardest case)

Self-contained. **Permitry** is a multi-tenant SaaS platform for local councils to receive and decide building and planning permit applications, at the **enterprise** profile. Council A has been live since Release 1. **Release 2** (automatic validation notices) onboards **council B** and **council C**, each a tenant with its own customer representative. The UAT plan put four acceptance types in scope:
- **UAT**, per council, by officers and a panel of applicants;
- **OAT**, by platform-engineer: restore, zone failover, alerting and the tenant provisioning runbook;
- **regulatory**: applicants' personal data under UK GDPR, which `compliance-design` names; Permitry's data protection officer signs against `compliance-verification` attestations;
- **contractual**: council C's service agreement, clause 4.2: "applicants are notified of a validation decision within two working hours".

## Input

> **User:** "Council B signed. Council C's head of planning says no, because notices go out in a nightly batch and their contract says two hours. Is the whole release a no-go? Or can we ship to C anyway, since it's just a contract thing and everything else is green?"

Completion summary, per type: UAT 18 scenarios, 17 Pass and 1 Fail (UAT-82c, contractual timing at council C, FB-31); 0 Blocked, 0 Not run; charters 3 of 3, which produced FB-33 (Low). OAT: restore met RPO 15 min and RTO 2 h; zone failover passed; the alert fired; the provisioning runbook was exercised for both tenants. Regulatory: the DPIA and access-isolation attestations are current; UAT-42a/b (applicants see only their own) passed in both councils. Repeatability: B and C were both onboarded from the same runbook by different engineers, with no bespoke steps.

## Working it

- **Neither of the user's options.** A representative accepts for **their own** cohort. Council C's refusal holds back council C; it does not make the release a no-go for council B. Shipping to C anyway would turn an internal decision into "acceptance" C never gave, and it would breach C's contract.
- **Defect rule.** No Critical (a Critical anywhere would be a no-go for every tenant, since tenants share the code). FB-31 is High, because it fails a contractual Must at C. So the outcome is **conditional**, with a fix plan (an hourly notice job for tenants whose contract requires it), a workaround (C's officers send the notice by hand from the decision screen), owner, date and re-test. FB-33 (Low) goes to residual risk.
- **One record, not two.** There is one sign-off for Release 2. Council C's later acceptance is an **addendum** to it: the re-run contractual scenario, C's representative's agreement, and the rollout change. It is not a second sign-off.
- **A signatory per type.** The DPO for regulatory, C's contract signatory (the same head of planning) for contractual, and the product owner for OAT on platform-engineer's evidence.

## Output — the reply, and `customer-validation/sign-off/release-2.md`

> Neither. Council C's refusal holds back council C only, so it isn't a no-go for B. But we can't ship to C either: acceptance is theirs to give, and their contract is the yardstick. I've drafted one conditional sign-off. Council B widens to all its officers and applicants. Council C stays at its validation cohort until an hourly notice job is built (backend-engineer, target 3 March). Meanwhile C's officers send notices by hand. Then UAT-82c re-runs with C's officers, and C's head of planning signs an addendum to this same record, not a new sign-off. I need your approval of the 3 March date.

````markdown
---
name: acceptance-sign-off-release-2
product: permitry
release-slice: Release 2 — automatic validation notices (councils B and C)
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2027-02-15
summary: Permitry Release 2 conditionally signed off: council B widens to GA; council C held at its validation cohort pending clause 4.2 two-hour notices (FB-31), re-attempt by addendum.
profile: enterprise
traces_to: customer-validation/uat-plan.md; customer-validation/feedback/2027-02-12.md; compliance/attestations/2027-q1.md
---

# Acceptance Sign-Off — Release 2 — automatic validation notices (councils B and C)

## Evidence
- UAT plan completion summary: customer-validation/uat-plan.md — 18 scenarios: 17 Pass, 1 Fail, 0 Blocked, 0 Not run; charters 3 of 3
- Feedback log: customer-validation/feedback/2027-02-12.md — open: 0 Critical, 1 High (FB-31), 1 Low (FB-33)
- Beta graduation records: beta not in scope

## Sign-Off Criteria Checklist

- [x] Every UAT scenario for a Must story has a result, and none is Blocked or Not run
- [ ] The pass threshold agreed before execution is met — 17 of 18; UAT-82c failed at council C (FB-31)
- [x] Every planned exploratory session ran and was debriefed; its findings triaged — EX-1 to EX-3
- [ ] Every acceptance type in scope (OAT, contractual, regulatory) has a result, accepted by its signatory — contractual (council C) not accepted
- [x] Zero open Critical defects
- [x] Every open High has a fix plan: owner, target date, workaround, re-test, rollout pace — FB-31, below
- [x] All feedback items triaged, scripted and exploratory alike
- [x] No unaddressed blocking pattern on a Must flow
- [x] Repeatability: every executor or cohort was set up the same documented way (if more than one) — same runbook, different engineers
- [x] Beta stage graduation records exist for each stage passed (if beta is in scope) — not in scope
- [x] Residual risk evaluated and written down

## Acceptance Types
| Type | Result | Accepted by |
|---|---|---|
| User acceptance (UAT) | Council B 9 of 9 Pass; council C 8 of 9, UAT-82c Fail | per cohort, below |
| Operational acceptance (OAT) | Restore within RPO 15 min / RTO 2 h; zone failover passed; alert fired; provisioning runbook exercised for B and C (platform-engineer, 2027-02-11) | Ines Duarte, product owner |
| Regulatory (UK GDPR, per compliance-design) | DPIA and access-isolation attestations current; UAT-42a/b Pass in both councils | Tomasz Wilk, data protection officer, Permitry — 2027-02-14 |
| Contractual (council C, clause 4.2) | Not met: notices go out nightly, not within two working hours (FB-31) | not accepted — Ruth Mensah, council C |

## Cohorts
| Cohort | Representative | Accepted | Rollout |
|---|---|---|---|
| Council B | Arjun Patel, development manager, council B | yes, 2027-02-14 | widen to 100% of council B |
| Council C | Ruth Mensah, head of planning, council C | no: "Clause 4.2 is two working hours; a nightly batch breaches it." | stays at the validation cohort |

## Sign-Off Authority
- Ines Duarte (product owner) — agreed 2027-02-15, release review
- Arjun Patel, development manager, council B (customer representative) — agreed 2027-02-14, signed acceptance form
- Ruth Mensah, head of planning, council C (customer representative) — did not accept, 2027-02-14; see Cohorts

## Decision: CONDITIONAL SIGN-OFF

**Conditions (if conditional):**
- FB-31 (High, council C) — workaround: council C officers send the validation notice by hand from the decision screen within two hours — owner: backend-engineer — target date: 2027-03-03 — re-test: UAT-82c re-run by council C officers, UAT-82a/b regression-checked, then Ruth Mensah's acceptance recorded as an addendum

## Residual Risk
- FB-33 (Low): the notice email's footer shows Permitry's support address, not the council's. Accepted by Ines Duarte; Release 3.
- OAT was executed by the team that built the platform (independence: within organisation). Accepted by Ines Duarte.
- Council C's manual workaround depends on officer discipline until 2027-03-03; council C has agreed to run it only for its validation cohort.

## Rollout Action
canary-deployment: council B widens to 100% of its users and its canary terminates. Council C holds at its validation cohort (two officers, applicant panel). feature-flag-design: `validation-notices.v2` on for all of council B; for council C, validation cohort only. The flag is removed only after the council C addendum.

## Follow-Up
- 2027-03-03: hourly notice job deployed for tenants with a two-hour clause; UAT-82c re-run by council C officers; UAT-82a/b regression-checked.
- On a pass: Ruth Mensah's acceptance and council C's rollout change are appended below as an addendum. If the date slips, council C stays held and the new date goes to the user.

## Addendum
[Appended after council C's re-attempt: date, scenarios re-run and results, Ruth Mensah's agreement (date, how), council C's rollout change.]
````

## What the weak first draft looked like

"NO-GO — council C rejected." It held council B back for a contract clause that binds only council C. The opposite draft, "FULL SIGN-OFF, all councils — C's issue is contractual, not functional", recorded acceptance C never gave and shipped a known breach of contract. Both drafts left out the DPO and OAT lines, so regulatory and operational acceptance had no signatory.
