---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Kilnroom**, a small app our pottery studio uses so members can book wheel classes and reserve space in the kiln firings. We're on the **lean** profile, and this plugin's agents build and run it. It is one deployable with one database, and nothing outside the app consumes its events today. The only reactions we need are: email members a reminder the day before a firing, and update the class's free-seat count.

The design agent's first draft of the domain event catalog lists:

- `ClassBookingCreated`, `ClassBookingUpdated`, `ClassBookingDeleted`
- `FiringScheduled`
- `SendFiringReminder`

It also says that each event's payload is the full `class_bookings` table row, every column, "so whoever reacts has everything", and that every event should be published to a message broker as an integration event with its own envelope and outbox, "because that's how events are done".

Is this a good catalog for a product our size? Tell me what the event list should be, what each payload should carry, and how the events should be published, and what you would change in the draft. Use this plugin's domain-event-catalog skill, and give me the answer in your reply, not in a file.
