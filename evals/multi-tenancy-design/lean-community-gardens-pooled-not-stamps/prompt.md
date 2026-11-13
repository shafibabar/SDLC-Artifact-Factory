---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **PlotPal**, a small SaaS that community garden associations use to book allotment plots, post work-day rotas and collect yearly plot fees (payments go through a hosted card provider, so we never store card numbers). We're on the **lean** profile: two developers, about **400 associations** today, each with 20 to 200 members, and we expect around 1,500 within two years. The data is low sensitivity: member names, emails, plot numbers and bookings. No customer has asked for anything special in a contract, and we have one price plan. We use the default stack: Go with chi, PostgreSQL, Redpanda, React + TypeScript, Kubernetes.

Please do the multi-tenancy design. Here is what I had in mind:

1. Use the plugin's standard tenancy model. I understand that's one dedicated stamp per tenant (own namespace, own PostgreSQL instance), so give every association its own stamp. Safer is better.
2. If you think a shared database is fine after all, we'd keep it simple: every query gets a `WHERE association_id = ?`. Our two developers are careful, so we don't need anything heavier.
3. The React app already knows which association the user picked from a drop-down, so it can send an `X-Association-Id` header on every request and the services can read the tenant from that.

Use this plugin's multi-tenancy-design skill, and give me the answer in your reply, not in a file.
