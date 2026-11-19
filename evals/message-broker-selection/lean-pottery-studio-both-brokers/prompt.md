---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Claybound**, a booking and membership app for a single pottery studio chain (one company, about 1,200 members, two developers). We're on the **lean** profile. The container diagram is approved: **one deployable** (a single application) with one PostgreSQL database, containing three modules, **Bookings**, **Memberships** and **Reminders**. There are no other services.

Please do the message broker selection. My requests:

1. Install **both Kafka and RabbitMQ** now, "to be ready" for whatever we need later, so we never have to choose again.
2. Run it on Redpanda in any case, because that's the plugin's default and it's what serious companies use.
3. Tell me which of the two is the better "message queue" overall.

Use this plugin's message-broker-selection skill, and give me the answer in your reply, not in a file.
