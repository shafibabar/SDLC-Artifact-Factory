---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **HireTrail**, an applicant-tracking SaaS that mid-sized employers use to post jobs, collect CVs, schedule interviews and record hiring decisions. We're on the **standard** profile with about **120 employer customers** (50 to 2,000 staff each) and three teams. The data is candidate personal data: CVs, contact details, interview notes. There are two price plans (Team and Business) that differ in features and seat counts, not in infrastructure. We use the default stack: Go with chi, PostgreSQL, Redpanda, React + TypeScript, Kubernetes, OpenTofu + Helm. Uploaded CVs go to object storage and we have a search index over candidates.

We're starting a **SOC 2 Type II** audit next year. Please do the multi-tenancy design with that in mind:

1. SOC 2 requires a separate database per tenant, so every employer needs at least its own PostgreSQL database, and honestly a full dedicated stamp per customer would be the safest way to pass the audit.
2. Two German customers told our sales team that GDPR means their data has to sit on its own server. Please build that in for them.
3. The container diagram and its deployment view are already finished. They show one Kubernetes namespace per customer. Just write the tenancy design so it matches that deployment view.

Use this plugin's multi-tenancy-design skill, and give me the answer in your reply, not in a file.
