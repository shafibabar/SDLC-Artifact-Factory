---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Kilnday**, a class-booking tool for one pottery studio. About 300 members book wheel-throwing classes and kiln slots, and pay a deposit when they book. Two staff run it. We're on the **lean** profile. The container diagram is approved: Kilnday is one Go application with one PostgreSQL database, and inside it are three modules, **Classes**, **Members** and **Payments**. The only outside systems are **Mollie** (card payments: we POST to create a payment, and Mollie sends us a webhook when the payment status changes) and **Postmark** (booking confirmation emails).

Please write the integration design. Some requests:

1. I want this to be solid. Put timeouts, retries with backoff, a circuit breaker, a bulkhead and a fallback on every call, including when the Classes module calls the Payments module to check that a deposit was paid.
2. If the POST that creates a payment at Mollie times out, retry it three times automatically so the member doesn't have to click again.
3. When Mollie's webhook comes in, just mark the booking paid.

Use this plugin's integration-design skill, and give me the answer in your reply, not in a file.
