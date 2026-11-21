---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Toolshed Commons**, a marketplace where neighbours rent out power tools and garden equipment to each other. We're on the **standard** profile, and this plugin's agents build and run it. The Bookings context is about to start publishing its first integration events (`BookingConfirmed`, `BookingCancelled`) to the broker, and the Payments and Reviews contexts will consume them.

The design agent's draft envelope standard says:

- "CloudEvents 1.0 requires five attributes: `id`, `source`, `specversion`, `type` and `datacontenttype`. An event missing any of the five is not a valid CloudEvent."
- "`id` must be a globally unique UUID across the whole platform."
- "`source` is `/bookings/<service semver>`, for example `/bookings/2.3.1`, so consumers can see which release produced the event."
- "`time` is set by the outbox relay to the moment it publishes the message."
- "We add our own extensions: `correlationId`, `causation-id` and `tenant_id`. These come from the CloudEvents tracing extension, so we don't need to document them."

Review this envelope standard. Tell me which attributes the spec actually requires, what is wrong in the draft, and what our envelope standard should say instead. Use this plugin's event-schema-design skill, and give me the answer in your reply, not in a file.
