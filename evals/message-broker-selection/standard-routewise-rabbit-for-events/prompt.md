---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Routewise**, a delivery-scheduling platform for regional couriers. We're on the **standard** profile: five services (Orders, Dispatch, Tracking, Billing, Notifications), each with its own database. Services publish Domain Events such as `OrderPlaced` and `ParcelDelivered`. Two more things we know: Billing needs to send customer invoice PDFs by email (a job per invoice, nobody ever needs to see a finished job again), and in about a month we want to **build a new Analytics read model from all the events of the last month**.

Please do the message broker selection. My requests:

1. Use **RabbitMQ for everything**, including the domain-event stream, because it's easier to run and "a message queue is a message queue".
2. Tracking events arrive in bursts, so scale the Tracking consumers with **Competing Consumers on the topic** and still keep each parcel's events in order.
3. Use **auto-acknowledge** so consumers don't have to deal with redelivery, and tell me delivery will then be exactly-once.

Use this plugin's message-broker-selection skill, and give me the answer in your reply, not in a file.
