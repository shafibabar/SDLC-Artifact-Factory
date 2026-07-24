---
name: acceptance-sign-off-[release-slice]
product: [product name]
release-slice: [name/description]
version: 1.0.0
phase: customer-validation
created: [date]
owner: requirements-analyst
---

# Acceptance Sign-Off — [release-slice]

## Sign-Off Criteria Checklist

- [ ] Every UAT scenario tracing to a Must Have story has a recorded result
- [ ] The UAT pass-rate threshold stated in the uat-plan is met
- [ ] Every planned exploratory session has been run and debriefed
- [ ] Zero open Critical severity defects
- [ ] Zero open High severity defects, or each is covered by a documented remediation plan with a target date (conditional path only)
- [ ] All feedback items have been triaged
- [ ] No unaddressed blocking pattern exists
- [ ] Beta program graduation criteria met for the relevant stage (if applicable)

## Sign-Off Authority
- Shafi (product owner)
- [Name, role, company] (customer/design-partner representative)

## Decision: [FULL SIGN-OFF / CONDITIONAL SIGN-OFF / NO-GO]

**Conditions (if conditional):**
- [Issue] — remediation plan: [...] — owner: [...] — target date: [...]

**Blocking items (if no-go):**
- [Issue] — required remediation before re-attempt: [...]

## Rollout Action
[canary-deployment widen/hold/revert instruction; feature-flag-design scope change]

## Follow-Up
[Re-verification plan and date, if conditional or no-go — including any
exploratory charter that needs re-running, not just scripted scenarios]
