# Outcomes and Rollout — the Detail

Self-contained. Read it when a conditional's follow-up, a missed target date, a no-go re-attempt, per-cohort rollout, or a beta stage path is in play. The defect rule itself lives in the skill (§ 2) and is not restated here.

## Conditional sign-off: acceptance with concessions

Hambling and van Goethem: accepting a system with known defects is normal, provided it is **explicit**. What must not happen is an implicit acceptance, where defects are left open and the release widens anyway. ("Concession" is the quality-management word for knowingly releasing something that does not fully conform. Use it to explain, not as an artifact term: the record says *conditional sign-off*.)

Each condition is one line, with six parts:

```
- FB-014 (High) — workaround: export from the client list instead of the report page —
  owner: backend-engineer — target date: 2027-01-20 — re-test: UAT-12b re-run by the same executor
```

The rollout pace is stated beside the conditions, never implied:
- **Widen to 100% with the workaround published** when the workaround keeps the Must outcome reachable for every user.
- **Hold at a named stage** (a canary percentage, a tenant wave, a cohort) when it does not, or when the condition is about one cohort.

### Re-verification

A condition closes only when its **re-test** passes: the failing scenario re-run green (by the same executor where possible) and its neighbouring scenarios re-checked, or the charter that found it repeated. "Deployed" is not "fixed".

When a target date passes with the condition open:
1. The rollout holds where it is; it does not widen further on schedule.
2. The requirements-analyst raises it with the user, who either approves a new date (recorded under Follow-Up, with the reason) or re-opens Customer Validation.
3. A condition is never silently dropped. Closing it records the re-test result and date.

When every condition is closed, the Follow-Up section records it, and the release flag can be removed at its `removal_date`.

## No-go and re-attempt

A no-go lists each blocking item and the change needed. The re-attempt is a **new UAT pass** for the affected scope: the fix deployed at the digest that will ship, the blocking scenarios re-run, and their neighbours regression-checked, with a new or superseding sign-off. Re-reviewing the same evidence is refused, however confident the fix.

A representative who refuses is a no-go for their scope even if every checklist line is green. Record their reason in their words. If it reveals an acceptance criterion that was never agreed, that goes back to Ideate as a criterion change, not into this record as a defect.

## One sign-off per release

The sign-off closes Customer Validation once. Its rollout action states the path to GA:

| Situation | What the rollout action says |
|---|---|
| No beta in scope | The canary step and flag scope from the validation cohort to everyone |
| Beta in scope | The stage path (for example: open beta for opted-in tenants, then GA) and the gate between stages, which is a `beta-program-design` graduation record, not another sign-off |
| Several tenant cohorts | Per cohort: widen, hold, or excluded pending an addendum |

Customer Validation re-opens, with a new UAT pass and a new sign-off that supersedes this one, when:
- widening surfaces a new Critical or High defect;
- a beta stage fails its graduation criteria;
- a customer representative withdraws their acceptance.

## Several cohorts (enterprise)

Each customer representative accepts for their own tenant cohort. The record has one row per cohort:

| Cohort | Representative | Accepted | Rollout |
|---|---|---|---|
| Wave 1 — tenants A, B | [name, role, org] per tenant | yes, [date] | widen to 100% of the cohort |
| Wave 2 — tenant C | [name, role, org] | no — [reason] | stays at the validation cohort |

- If any cohort is held back, the release decision is **at most conditional**, and the held cohort is one of the conditions (owner, target date, re-test = a new UAT pass for that cohort).
- The held cohort's later acceptance is an **addendum** appended to this record (date, scenarios re-run, representative's agreement, rollout change). It is not a separate sign-off.
- A Critical found in any cohort is a no-go for the release: tenants share the code.

## Hand-off to platform-engineer

The rollout action is the instruction `platform-engineer` executes with `canary-deployment` and `feature-flag-design`:
- name the flag, its new scope, and the canary step or tenant waves;
- name what holds the next step (a condition, a graduation record);
- for a no-go, say hold or revert, and to what.

The requirements-analyst decides the action; `platform-engineer` chooses the mechanism and reports back. Nobody widens a canary or flag scope to GA without this record.
