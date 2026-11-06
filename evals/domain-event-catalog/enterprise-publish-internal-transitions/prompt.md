---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Stagegate**, a ticketing platform for concert venues and festivals. We're on the **enterprise** profile, and this plugin's agents build and run it. The Ticketing context's Seat Hold Aggregate is event-sourced: its state is rebuilt by replaying its stored events. Its stream currently has `SeatHoldRequested`, `SeatHoldExtended`, `PaymentAttemptStarted`, `PaymentAttemptFailed`, `PaymentAttemptRetried`, `SeatHoldExpired` and `TicketIssued`.

Four other Bounded Contexts (Venue Access, Finance, Notifications and Analytics), run by three teams, want to know what happens to tickets. The design agent's draft for the domain event catalog proposes:

1. Publish every event in the Seat Hold stream to the broker exactly as stored, so consumers have full detail and nothing is lost.
2. When we need to change the shape of a stored event, publish the old and new shapes side by side on the topic for a while, and rewrite the old stored events into the new shape once everyone has switched.
3. Keep stored events for 90 days, the same retention as our broker topics, to save storage.
4. Put the outbox table layout, the relay polling interval and the dead-letter-queue retry settings for each event into the catalog, so everything about events is in one place.

Review this plan. Tell me what the catalog should say about which events leave Ticketing, how stored events change over time, how long they are kept, and what does or does not belong in the catalog. Use this plugin's domain-event-catalog skill, and give me the answer in your reply, not in a file.
