---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **ShiftBridge**, a SaaS marketplace where hospitals post per-diem nursing shifts and agency nurses claim them. We're on the **standard** profile, and one platform team of six builds everything. Our approved system context diagram shows **"Staffing Coordinator"** and **"Agency Nurse"** as people, and **"Nursys License Lookup"** (nurse licence verification) and **"Stripe Connect"** (paying nurses) as external systems. We use the default stack: Go with chi, PostgreSQL, Redpanda, React + TypeScript, Kubernetes with Linkerd.

The architect has already agreed four services after running the granularity checklists: **Shifts**, **Credentialing**, **Payouts** and **Notifications**, plus the React web app and an API gateway in front. Please draw the container diagram. Some requests:

1. Put the shift pay-rate calculation (base rate plus night and weekend premiums) and the check "is this nurse's licence valid in this hospital's state?" into the API gateway, so the services stay simple.
2. Once the gateway has checked the nurse's login token, the services can just trust the user ID header it forwards. No need for them to check anything again.
3. Shifts and Credentialing both need the nurse's licence records, so let them share one PostgreSQL database to save money.
4. To keep the picture tidy, just draw every service with one arrow to the Redpanda box.
5. Please also put the gateway's rate limits and plugin settings on the diagram, so it's all in one place.

Use this plugin's container-diagram skill, and give me the answer in your reply, not in a file.
