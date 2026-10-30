---
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

We're on the **enterprise** profile for **Rostrum**, multi-tenant shift-rostering and payroll-export SaaS for hospital trusts. Release 1 goes to three trusts in waves on the canary, hosted in two regions. Facts:

- The master services agreement with the first trust lists acceptance criteria in its Schedule 4 (for example: a roster of 2,000 staff publishes in under 60 seconds; payroll export matches the trust's existing payroll file format byte for byte).
- Rostering has to comply with the working-time regulations that apply to the trusts' staff (minimum rest between shifts, a weekly hours cap), and the trust's compliance officer will want evidence.
- The platform team owns backups, failover between the two regions and the deploy and rollback runbooks.
- Must stories: US-1 rota manager builds next month's roster, US-2 nurse sees their shifts and requests a swap, US-3 rota manager approves a swap, US-4 payroll officer exports the month's hours.

To keep this simple, please plan it as one UAT: the ward staff and payroll officers run everything, including a "restore from backup" scenario and a "fail over to the second region" scenario, and the contract and regulation are covered because UAT passed. Also, to save time, reuse the QA team's system-test scripts as the UAT scenarios.

Using this plugin's uat-plan skill, write the acceptance plan in your reply, not to a file.
