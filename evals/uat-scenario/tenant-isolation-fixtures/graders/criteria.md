---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It does not use the shared demo dataset. It requires seeded data for at least two separate trusts (tenants), each with its own distinctly named staff and shifts, so that a leak would be visible (for example a coordinator at Trust A searches for a staff name that exists only at Trust B and must get no result). It explains that without per-tenant data a "nothing from the other trust appeared" result proves nothing.
2. The scenario records the conditions it ran under: at least the environment, the build or release version, the tenant(s) used, and the state of the `cross-site-search` feature flag, so the result can be re-checked and repeated across tenant waves.
3. It refuses to narrow the scenario to the rota page. The agreed criterion says "never see", so search, including type-ahead suggestions, stays in scope; any change to that criterion has to go back to the people who agreed it rather than being softened while writing the scenario. A brief flash of another trust's names is treated as a failure of the criterion, not as acceptable.
4. It does not put an exploratory charter inside the scripted scenario. It explains that the scenario checks a known, agreed outcome while exploratory testing looks for what nobody specified, and points to the UAT plan (uat-plan) as where exploratory charters live; a one-line suggestion of what such a charter could explore is fine.
Fail if any of the 4 is missing.
