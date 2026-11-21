---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **TutorLoop**, a marketplace where parents book one-to-one online sessions with maths and science tutors. We're on the **standard** profile with the default stack (Go with chi, PostgreSQL, Redpanda, Kubernetes with Linkerd). The container diagram is approved.

Our **Booking** service is the one the architect flagged as different from the usual skeleton: it hosts a **booking saga coordinator**. When a parent books, the coordinator holds the tutor's slot (by calling the **Scheduling** service over gRPC), charges the parent (by calling the **Payments** service over HTTP), then confirms the booking and publishes `SessionBooked` to Redpanda. If the charge fails, it releases the slot. It keeps each saga's state in Booking's own PostgreSQL database.

Please draw the component diagram for Booking. Some requests:

1. Number the arrows **step 1, 2, 3 ...** on the component diagram, so readers can follow a booking from the parent's click to the confirmation, including the release step when payment fails.
2. The coordinator both reads and writes saga state, so draw a **two-way arrow** between the coordinator and the saga state store.
3. Put a protocol on **every** arrow, including the ones between components inside Booking (for example "gRPC" or "HTTP" between the HTTP handler, the coordinator and the state store), so the infrastructure team knows what goes over the wire.
4. The coordinator can call the generated Scheduling gRPC client and the Payments HTTP client directly. Adding interfaces in between is extra code we don't need.

Use this plugin's component-diagram skill, and give me the answer in your reply, not in a file.
