---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Seedling**, a subscription box for houseplants run by one small company (one company, no other tenants), about 800 subscribers, two developers. We're on the **lean** profile. The container diagram is approved: **one deployable** (a single Go application) with one PostgreSQL database, containing three modules, **Subscriptions**, **Shipping** and **Notifications**. There are no other services.

Please write the event-driven part of the integration design. My requests:

1. Set up a Redpanda broker with one topic per module, plus a dead-letter topic for each, so the modules talk to each other through events like the big companies do.
2. Shipping has to handle a lot of "box shipped" events around the Monday dispatch. To scale it, add **Competing Consumers** on the topic, partitioned by tenant id, and still keep every subscription's events in order.

Use this plugin's event-driven-patterns skill, and give me the answer in your reply, not in a file.
