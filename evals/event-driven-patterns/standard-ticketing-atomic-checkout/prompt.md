---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Stagedoor**, a ticketing platform for mid-sized theatres. We're on the **standard** profile. The container diagram is approved: three services, **Orders**, **Seating** and **Billing**, each with its own PostgreSQL database, plus Redpanda as the broker. When a patron checks out, Orders creates the order, Seating holds the seats, and Billing charges the card.

Please write the event-driven part of the integration design for this checkout flow. My requirements:

1. Checkout must be **atomic**: either the order, the seat hold and the charge all happen, or none of them do. Use a distributed transaction across the three databases so we never have a half-finished checkout.
2. Each service should publish its events so the others can react.
3. If the card charge fails after the seats are held, release the seats and cancel the order.

Use this plugin's event-driven-patterns skill, and give me the answer in your reply, not in a file.
