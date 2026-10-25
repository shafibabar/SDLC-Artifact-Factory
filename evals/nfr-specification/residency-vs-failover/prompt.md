---
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

We're on the **enterprise** profile for **Claimsway**, a multi-tenant claims-handling platform for insurers in Germany. Our approved FRD has:

- **BR-2:** "Policyholder data is processed and stored only in Germany" (source: the insurers' contracts and their regulator's outsourcing rules).
- **QA-1:** availability of claim intake (all URs; insurers' contracts ask for 99.99% and "cross-region failover").
- **QA-2:** claim intake must stay responsive at the Monday 08:00–10:00 peak (about 2,000 claims an hour across tenants).

Our cloud provider has one region in Germany and its nearest other region is in the Netherlands.

Using this plugin's nfr-specification skill, write the parts of the NFR specification that cover QA-1, QA-2 and BR-2, including how they are ranked and what goes to the enterprise-architect (in your reply, not to a file).
