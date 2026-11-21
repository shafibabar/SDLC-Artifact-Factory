---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **SkillForge**, a corporate learning platform: companies assign training courses to staff, track completions and certifications, and export audit-ready training records. We're on the **enterprise** profile with five teams. We have about **2,000 customers on the Standard plan** (mostly 50 to 500 learners each), about **30 on the Enterprise plan** (higher limits and an uptime SLA), and **three customers** (a defence contractor and two banks) whose signed contracts require dedicated infrastructure and customer-managed encryption keys. We use the default stack: Go with chi, PostgreSQL, Redpanda, React + TypeScript, Kubernetes, OpenTofu + Helm. Course videos sit in object storage and there's a search index over course content and learner records.

Please do the multi-tenancy design. Some requests from around the business:

1. Since three customers need dedicated infrastructure anyway, let's put **everyone** on a dedicated stamp. One model for all 2,000+ customers is simpler than two.
2. Our security reviewer flagged the single shared Redpanda cluster on the draft diagram as a cross-tenant leak. Please give every customer its own broker.
3. When a Standard customer cancels, we'll just delete their Kubernetes namespace and that's offboarding done.
4. When a Standard customer upgrades to a dedicated setup, support can handle the move manually through a ticket.
5. Finance wants to know whether the Standard plan makes money per customer. They suggest we just read it off the cloud bill using resource tags.

Use this plugin's multi-tenancy-design skill, and give me the answer in your reply, not in a file.
