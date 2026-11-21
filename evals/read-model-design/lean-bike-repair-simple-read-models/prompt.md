---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Spokewise**, the booking and job-tracking app for one independent bicycle repair shop: two mechanics, about 300 regular customers, one database. We're on the **lean** profile, and this plugin's agents build and run it. The domain model is done: a **Workshop** Bounded Context with `RepairJob`, `Bike` and `Customer` Aggregates, and a **Parts** Bounded Context with `PartOrder`.

The screens we need are:
- the mechanics' **workshop board**: today's repair jobs, each with the bike, the customer's name, the work booked and whether parts are still awaited;
- the customer's **repair status** page: where their bike's job is up to;
- the owner's **weekly parts list**: parts to order, grouped by supplier.

A developer who helps us out has written up the read side like this:

1. "Best practice in CQRS: never query or join the write tables for a read." So every screen gets its own projection: each change publishes a Domain Event, and a projector writes it into a separate read table.
2. Each Bounded Context gets its own `read-models.md` with, for every Read Model, the source events, the projector logic, idempotency handling and a rebuild procedure.

Is this right for us? Tell me how the read side of Spokewise should work, where its Read Models should be written down, and what would have to happen before any screen got a projection. Use this plugin's read-model-design skill, and give me the answer in your reply, not in a file.
