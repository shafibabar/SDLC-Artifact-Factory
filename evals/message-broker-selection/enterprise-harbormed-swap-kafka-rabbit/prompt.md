---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **HarborMed Labs**, a laboratory-results platform sold to hospital groups. We're on the **enterprise** profile with separate services. Today the `ResultReleased` Domain Event stream runs on Kafka. There is an **audit requirement**: regulators may ask us to reproduce what was released and when, from the event history. A **new consumer**, a Quality Dashboard read model, is planned next quarter and must start from the earliest events. Our platform team wants to cut cost.

Please do the message broker selection review. My requests:

1. **Swap Kafka for RabbitMQ.** It's only a client library change, so confirm that and give me the migration steps.
2. The platform requires **a separate broker cluster per tenant (per hospital group)**. Design for that.
3. Add **Competing Consumers** on the result topic to speed up the Notifications service while keeping each patient's results in order.

Use this plugin's message-broker-selection skill, and give me the answer in your reply, not in a file.
