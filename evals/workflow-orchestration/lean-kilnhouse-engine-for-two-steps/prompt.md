---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Kilnhouse**, a booking app for pottery studios. We're on the **lean** profile, so it is a single modular monolith: one deployable, one PostgreSQL database, with modules for Classes, Bookings and Notifications. The only multi-step flow today is: when a student books a class, the Bookings module reserves a seat, and then the Notifications module sends a confirmation email (a failed email must not lose the booking, it should just be retried).

I'd like to be "ready for scale", so I want you to design a **workflow engine with a central orchestrator**, using Netflix Conductor, for this booking flow, with a state machine, compensation for each step and a dashboard of in-flight bookings. Please write the orchestration design.

Use this plugin's workflow-orchestration skill, and give me the answer in your reply, not in a file.
