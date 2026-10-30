---
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

We're in the Strategy phase of the SDLC Artifact Factory for an enterprise-profile product: a multi-tenant HR platform (EU and US regions, 99.9% availability commitment) with four product lines: **Payroll**, **Time & Attendance**, **Benefits** and **Analytics**. Our company strategy kernel's diagnosis is: "Payroll errors in the first two pay runs after onboarding make customers distrust every other module, so their HR teams keep running parallel spreadsheets." Its crux is "a first payroll that is right without a parallel run."

Each product-line lead now wants to write their own strategy kernel. The Analytics lead says their real problem is different: buyers' data teams refuse to adopt any HR analytics that cannot export into their existing warehouse.

Using this plugin's strategy-kernel guidance, which product lines should get their own strategy kernel, and what do the others get instead? For any line that qualifies, list what its kernel must state about its relationship to the company kernel.
