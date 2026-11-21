---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Plotshare**, a small app for one allotment society to manage its waiting list, plot allocations, annual rent and the shared tool shed. We're on the **lean** profile and just entering Design.

We haven't done any Event Storming and I'd rather skip it: we already have a feature list, so classify the subdomains straight from that now. Our feature list has four headings: **Members**, **Plots**, **Money** and **Tool shed**. Just take those four as the subdomains, give each a label, and then each one becomes its own Bounded Context and its own microservice, so the structure is settled in one go.

Features under the headings:
- Members: join the society, join the waiting list, contact details, committee roles.
- Plots: plot map, offer a vacant plot to the next person on the waiting list using the society's priority rules (local residents first, then length of wait, half-plots offered before full plots), plot inspections.
- Money: annual rent invoices, online card payment, a yearly report for the treasurer.
- Tool shed: book the rotavator, report broken tools.

Since we're lean, keep it short. Using this plugin's subdomain-distillation skill, give me your answer in your reply, not in a file.
