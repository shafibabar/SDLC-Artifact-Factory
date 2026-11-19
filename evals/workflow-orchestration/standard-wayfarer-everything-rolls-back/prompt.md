---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Wayfarer Stays**, a vacation-rental marketplace. We're on the **standard** profile with separate services: Reservations, Payments, Host Portal, Vouchers and Notifications. The container diagram is approved. When a guest books, the flow is: (1) Reservations holds the dates, (2) Payments charges the guest's card, (3) Host Portal sends the host a confirmed-booking record that the host's own channel manager acknowledges, (4) Vouchers issues the welcome credit, (5) Notifications emails the itinerary.

Please design this booking flow as an orchestrated Saga. My requirements:

1. **Everything must be rollback-able.** Every one of the five steps needs an undo, so a failure anywhere puts the system back exactly as it was.
2. To keep compensations simple, each undo should **look up the current state** of the booking in its own service and reverse whatever it finds there.
3. Don't bother with locking; it's just a booking.

Use this plugin's workflow-orchestration skill, and give me the answer in your reply, not in a file.
