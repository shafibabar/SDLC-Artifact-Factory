---
name: acceptance-sign-off-[release-slice]
product: [product name]
release-slice: [name/description]
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: [date]
summary: [one sentence, ≤ 200 chars — the release, the outcome, and what it lets the rollout do]
profile: [lean | standard | enterprise]
traces_to: [customer-validation/uat-plan.md; customer-validation/feedback/*.md; customer-validation/beta-program/*.md]
---

# Acceptance Sign-Off — [release-slice]

## Evidence
- UAT plan completion summary: [path] — [n scenarios: n Pass, n Fail, n Blocked, n Not run; charters n of n]
- Feedback log: [path] — [open defects by severity]
- Beta graduation records: [path, or "beta not in scope"]

## Sign-Off Criteria Checklist

- [ ] Every UAT scenario for a Must story has a result, and none is Blocked or Not run
- [ ] The pass threshold agreed before execution is met
- [ ] Every planned exploratory session ran and was debriefed; its findings triaged
- [ ] Every acceptance type in scope (OAT, contractual, regulatory) has a result, accepted by its signatory
- [ ] Zero open Critical defects
- [ ] Every open High has a fix plan: owner, target date, workaround, re-test, rollout pace
- [ ] All feedback items triaged, scripted and exploratory alike
- [ ] No unaddressed blocking pattern on a Must flow
- [ ] Repeatability: every executor or cohort was set up the same documented way (if more than one)
- [ ] Beta stage graduation records exist for each stage passed (if beta is in scope)
- [ ] Residual risk evaluated and written down

## Acceptance Types
| Type | Result | Accepted by |
|---|---|---|
| User acceptance (UAT) | [summary] | [signatories below] |
| [OAT / contractual / regulatory, or delete] | [result, evidence] | [signatory, role] |

## Sign-Off Authority
- [Name] (product owner) — agreed [date, how]
- [Name, role, company] (customer representative) — agreed [date, how]

## Exception: solo operator
[Delete this section when two parties sign.]
- Executor and accepting authority: [the product owner]
- Independence level (ISTQB): none
- Why no second party: [reason]
- Evidence: [per-scenario screenshot or recording, date, environment, digest, flag state — where kept]
- Borrowed session: [who, which scenarios, date] or "none available, because …"

## Decision: [FULL SIGN-OFF / CONDITIONAL SIGN-OFF / NO-GO]

**Conditions (if conditional):**
- [Issue ID, severity] — workaround: [...] — owner: [...] — target date: [...] — re-test: [...]

**Blocking items (if no-go):**
- [Issue] — required change before re-attempt: [...]

## Residual Risk
[What is knowingly accepted, and by whom: open Medium or Low items, independence level, repeatability gaps]

## Rollout Action
[canary-deployment widen/hold/revert instruction; feature-flag-design scope change]

## Follow-Up
[Each re-test — scenario or charter — its date and who re-runs it; for a no-go, the new UAT pass]
