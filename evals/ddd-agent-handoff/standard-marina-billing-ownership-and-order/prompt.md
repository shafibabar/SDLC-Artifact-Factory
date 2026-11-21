---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Harbourline**, which handles berth bookings for a group of fourteen marinas: boat owners book seasonal or overnight berths, harbour staff log arrivals and departures, and owners pay berth fees and fuel bills. We're on the **standard** profile, and this plugin's agents build and run it. We're about to start the Design phase. The Bounded Contexts we expect are **Berthing**, **Harbour Operations** and **Billing**.

The team has written this work plan for Design, and I'd like it checked before anyone starts:

1. The domain-modelling agent does Event Storming, the Aggregates, the event and command catalogs, and then designs the Read Models for every context, including the Billing statements screen. After that, the architecture agent decides whether Billing uses CQRS at all.
2. The data agent has already started on the events. It has written the `BerthFeeInvoiced` event schema, including what each payload field means (for example, that `amountDue` includes the fuel bill), and the domain-modelling agent has accepted that so it doesn't have to write those meanings again in its own catalog.
3. When we later need to change `BerthFeeInvoiced` in a way that breaks existing consumers, the plan is to publish it as `BerthFeeInvoiced.v2` alongside the old one.
4. The platform agent decides during Design where the API gateway sits in front of the services, and writes its routing configuration at the same time.

For each of the four points, tell me which agent should own that decision or artifact, in which phase, and in what order relative to the others, and what you'd change about the plan. Use this plugin's ddd-agent-handoff skill, and give me the answer in your reply, not in a file.
