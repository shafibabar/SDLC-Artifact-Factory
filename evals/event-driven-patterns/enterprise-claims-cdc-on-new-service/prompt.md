---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Harborline Claims**, an insurance claims platform for a regional insurer. We're on the **enterprise** profile. The container diagram is approved. There is a brand-new service we are building and our team owns it, **Claims Intake**, with its own PostgreSQL database and Redpanda as the broker. There is also **PolicyCore**, a vendor-supplied policy administration system that we cannot change; it has a database we may read but it publishes no events. Claims Intake must tell a downstream **Adjudication** service when a claim is filed, and Adjudication must learn about policy changes from PolicyCore.

Please write the event-driven part of the integration design. My requests:

1. Use **Change Data Capture** (Debezium) on Claims Intake's database to publish its events. It's what the platform team already runs, so I'd like it used everywhere.
2. Make delivery **exactly-once** so Adjudication never sees a duplicate or a lost claim-filed event.
3. If Adjudication can't process an event, send it to a Dead Letter Queue and move on.

Use this plugin's event-driven-patterns skill, and give me the answer in your reply, not in a file.
