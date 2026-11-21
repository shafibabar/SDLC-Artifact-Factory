---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Plotshare**, a small app our town's allotment society uses to let members book shared plots, tools and the polytunnel. We're on the **lean** profile, and this plugin's agents build and run it. It is one deployable. The Plot Bookings Aggregate is event-sourced, so its events (`PlotBooked`, `PlotReleased`) are stored in an event store and replayed to rebuild state. Two of them are also published to a small notifier service that emails members.

We have about 40,000 stored events. Two problems have come up:

- `PlotBooked` stores the member as a single `memberName` field, and we now need `firstName` and `lastName` separately.
- A bug last spring recorded around 300 `PlotBooked` events with the wrong plot number.

The design agent proposes:

1. Stand up a schema registry (Confluent or Apicurio) with Protobuf schemas for every event, "because the plugin's standard says events need a registry."
2. Write a one-off migration script that rewrites the stored `PlotBooked` events in place: split `memberName` into the two new fields, and fix the plot numbers on the 300 bad events while it's at it.
3. Since the events are now in the new shape, publish the same internal `PlotBooked` events to the notifier as they are.

Is this the right approach for a product our size? Tell me what you would do instead for each part, and why. Use this plugin's event-schema-design skill, and give me the answer in your reply, not in a file.
