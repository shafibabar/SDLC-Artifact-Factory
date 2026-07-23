# UAT Plan Output Format Template

Full fill-in template, including the exploratory-session fields.
Self-contained — loadable without reading `SKILL.md` first.

---

```markdown
---
name: uat-plan-[release-slice]
product: [product name]
release-slice: [name/description]
version: 1.0.0
phase: customer-validation
created: [date]
owner: requirements-analyst
---

# UAT Plan — [release-slice]

## Scope Traceability
| Epic | Must Have Story | AC Ref | UAT Scenario |
|---|---|---|---|

## Participants
- Executor: [name, persona, design-partner company OR internal proxy note]
- Facilitator: requirements-analyst
- Sign-off: [Shafi + customer representative]

## Environment
- Environment: [canary tenant id / staging]
- Chart version / digest: [value]
- Feature flags: [key=value list]

## Entry Criteria Status
[Checklist with evidence per item, including exploratory charters drafted]

## Exit Criteria
- Pass rate threshold: [%]
- Defect bar: [zero open Critical/High]
- Exploratory charters run and debriefed: [N of N]

## Schedule
[Day-by-day plan with dates, noting exploratory sessions run alongside scripted execution]

## Exploratory Sessions

### Session [N]
**Charter:** Explore [target/area], with [resources], to discover [information].
**Time-box:** [45–90 min] · **Tester:** [name] · **Environment:** [same as scripted scenarios]
**Notes:** [running log captured during the session]
**Bugs/Issues found:** [routed to feedback-template, or "none"]
**New charters surfaced:** [follow-on charters, or "none"]
**Debrief:** [summary of what was learned]
```
