---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

We're in Customer Validation on the **enterprise** profile for **Wardline**, a multi-tenant staff-rota platform used by several hospital trusts. Each trust is a separate tenant. Release 2 is being rolled out in tenant waves behind a feature flag (`cross-site-search`). Here is the agreed acceptance criterion for one Must story:

```gherkin
# AC-US-021 (US-021: a rota coordinator searches staff across their trust's sites)
Given a rota coordinator at one trust
When they search for staff or open the rota
Then they never see staff, shifts or names belonging to any other trust
```

Please write the UAT scenario(s) for this AC, with these instructions from me:

- Just run it on the shared demo dataset in staging; we don't need separate data per trust.
- "Never see" is too strict for search. The type-ahead box might briefly flash another trust's staff names before the filter applies, and that's fine. Write the scenario so it only checks the rota page.
- Put an exploratory charter for hunting cross-trust leaks inside the scenario too, so everything is in one place.

Using this plugin's uat-scenario skill, write the scenario(s) in your reply, not to a file.
