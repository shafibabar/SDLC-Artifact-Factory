# Acceptance Types — Choosing What a Release Needs

Self-contained: loadable without `SKILL.md`. Read it when planning acceptance for a release and any type other than user acceptance testing might apply: the product is hosted and run by someone, holds user data, is in a compliance scope, has a customer contract with acceptance clauses, or will go to a beta cohort.

The five forms are the ISTQB acceptance-testing taxonomy (Certified Tester Foundation Level syllabus and glossary). It is a standard, not a book, so it is cited in prose, not in `sources:`. Hambling and van Goethem's *User Acceptance Testing: A Step-by-Step Guide* supplies the business framing around it: acceptance exists to give the accepting party enough confidence to decide, against criteria agreed before execution.

---

## The Selection Test

Ask these in order and keep every "yes":

1. **Will intended users depend on this release to do their work?** Always yes → **UAT**.
2. **Will anyone have to run, restore, upgrade or support it, or does it hold data its users would miss?** → **OAT**.
3. **Does a signed contract state acceptance criteria for this release?** → **Contractual**, for that contract's clauses only. A sales promise or a roadmap commitment is not a contract.
4. **Does `compliance-design` place the product in a regulatory or compliance scope?** → **Regulatory**, for the requirements that scope derives.
5. **Will a cohort use the release in its own context before general release?** → **Alpha / beta**, handed off to `beta-program-design`.

Each type kept gets a row in the plan's **Acceptance Types in Scope** table: scope, executor, evidence, and the sign-off line it feeds. A type left out is written as "not in scope, because …" so a reviewer can see it was considered.

---

## User Acceptance Testing (UAT)

- **Checks:** fitness for use by intended users, in a real or production-like environment.
- **Test basis:** the Must stories' acceptance criteria and feature files, exercised as business scenarios.
- **Executed by:** intended users. Under the solo-operator exception, the product owner (see `./roles-and-independence.md`).
- **Evidence:** `uat-scenario` results (Pass, Fail, Blocked, Not run) and exploratory debriefs.

## Operational Acceptance Testing (OAT)

- **Checks:** that the system can be **operated and supported**, not just used. ISTQB's typical content: backup and restore; install, upgrade and rollback; disaster recovery; user and access management; maintenance tasks; data load and migration; alerting and monitoring; security vulnerability checks; performance.
- **Executed by:** `platform-engineer`, who owns the mechanisms. The requirements-analyst lists the OAT items in the plan and compiles the results; it does not run them.
- **Evidence from existing skills, not new content:**

| OAT item | Evidence | Owning skill |
|---|---|---|
| Restore from backup works within the RPO / RTO | A restore drill on the UAT environment, timed | `disaster-recovery-plan` |
| Rollback to the previous release works | The rollback runbook exercised once | `runbook-authoring`, `canary-deployment` |
| Someone is alerted when it breaks | A test alert fired and received by a named person | `slo-definition` |
| Failover holds (HA products only) | A failover drill against the stated objective | `disaster-recovery-plan` |
| Data migration is complete (migrating products only) | Counts and checksums reconcile | the migration epic's acceptance criteria |

**By profile:**
- **lean:** a **three-line OAT smoke** if the product holds user data: restore works, rollback works, someone gets alerted. Each line is one dated observation. If the product holds no user data and nobody else runs it, OAT is "not in scope" with that reason.
- **standard:** restore, rollback and alerting, each with its evidence; upgrade if the release changes the schema.
- **enterprise:** the full list that applies, including failover per region and migration reconciliation per tenant, in its own OAT window.

## Contractual Acceptance Testing

- **Applies only** when a signed contract states acceptance criteria (a service agreement schedule, a statement of work). Quote the clause, map it to the Must story and scenario that proves it, and name who from the customer accepts it.
- A contract clause with no Must story behind it is an Ideate gap: raise it to the product owner (`moscow-prioritization` adds contractual Musts to the skeleton). Do not write a UAT scenario that invents the rule.
- **Executed by:** users or independent testers; accepted by the contract's named signatory.

## Regulatory Acceptance Testing

- **Checks:** adherence to the laws or frameworks `compliance-design` names for **this** product. Neither the book nor ISTQB says which regulation applies; never hard-code one in the plan's rules.
- **Evidence:** `compliance-verification` attestations (security-engineer), plus any regulation-derived scenario the users run (for example, "an applicant cannot see another applicant's documents").
- **Accepted by:** a named compliance signatory, recorded as its own line on the sign-off. Sometimes a regulator witnesses or audits the results; if so, the plan says so and keeps the evidence retained.

## Alpha and Beta Testing

- **Alpha:** real use at the developer's site. **Beta:** real use at the users' own sites. Both are forms of acceptance testing in ISTQB's sense.
- **This plan does not design the beta.** Cohorts, stages, graduation criteria and the beta agreement belong to `beta-program-design`. The plan names which cohort runs the release's UAT scenarios and points to the beta program for the rest.
- At lean, `beta-program-design` is skipped by `phase-requirements.json`: a lean product has no alpha / beta row unless the user asks for one.

---

## Worked Selection (three products)

| Product | UAT | OAT | Contractual | Regulatory | Alpha / beta |
|---|---|---|---|---|---|
| A makerspace tool-loan tracker (lean, holds member emails) | Yes | Three-line smoke | No contract | Not in a compliance scope | Skipped at lean |
| Physiotherapy appointment software (standard, two pilot clinics) | Yes | Restore, rollback, alerting | No acceptance clauses | Health data handled per its `compliance-design`, verified in Quality; no separate regulatory acceptance this release | Pilot clinics are the design-partner cohort (`beta-program-design`) |
| Council permit platform (enterprise, multi-tenant) | Yes, per tenant | Full, own window | Council A's service agreement clause | Data protection per `compliance-design` | Councils B and C later, via `beta-program-design` |
