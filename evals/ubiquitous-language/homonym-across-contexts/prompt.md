---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Harbourline** on the **standard** profile: a SaaS platform that marina operators use to rent out berths to boat owners. We're in the Design phase and have two Bounded Contexts so far, Reservations and Billing, and the word **"Booking"** is causing arguments.

- In **Reservations**, a Booking is a berth held for a boat between two dates. It can be provisional, confirmed or cancelled, and it can be moved to a different berth while it is still in the future.
- In **Billing**, a Booking is the stay the marina charges for once the boat has actually arrived: nights actually spent, metered shore power, pump-out fees and any late-departure penalty. It is closed when the final invoice is paid, and it never changes berth because it records what happened.

I'm tired of this. Please pick the one correct definition of "Booking" for the whole product, ban the other meaning so nobody uses it any more, and give me the single glossary entry everyone should follow.

Using this plugin's ubiquitous-language skill, give me your answer in your reply, not in a file.
