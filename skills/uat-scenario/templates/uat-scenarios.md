# UAT Scenarios Template

Copy the block below into `artifacts/<product>/customer-validation/uat-scenarios/US-<n>.md`, one file per Must story, and fill every bracket. Repeat the `### UAT-` block for each scenario (`UAT-<n>a`, `UAT-<n>b`, …). Leave the run lines empty until execution. Add a run line per run; never overwrite one. Delete the Flags line if no flag affects the outcome, and the Tenant part of Environment on a single-tenant product.

````markdown
---
name: uat-scenarios-US-[n]
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: [YYYY-MM-DD]
summary: [One sentence: which story these scenarios prove and in which environment.]
story: US-[n]
profile: [lean | standard | enterprise]
traces-to: [AC-US-n.1, AC-US-n.2]
plan: customer-validation/uat-plan.md
---

# UAT Scenarios: US-[n] [story title]

**Story:** As a [role], I want to [action], so that [outcome].

### UAT-[n]a: [the piece of work, in plain language]

**Traces to:** [AC-US-n.1, …]
**Performed by:** [role the story was written for]

**Preconditions and test data** (seeded by [who], before the window):
- [Named fixture, with tenant if multi-tenant] — confirm by: [what the tester sees]

**Environment:** [tenant] · [region] · build [release tag]
**Flags:** [flag name] [on/off] for [tenant]

**Context (Given):** [The starting state, as the tester can see it.]

**Steps (When):**
1. [One action, in the user's words]
2. [ … ]

**Expected Outcome (Then):**
- [What the tester sees: a label, message, row, file, email]

**Runs:**

| Date | Tester (role) | Result | Evidence | Defect / workaround | Re-test of | Found outside this scenario |
|---|---|---|---|---|---|---|
| [ ] | [ ] | [Pass / Fail / Blocked: reason / Not run] | [screenshot or recording ref] | [feedback ID, severity, workaround] | [date of failed run] | [feedback IDs] |
````
