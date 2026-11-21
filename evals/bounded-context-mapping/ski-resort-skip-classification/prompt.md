---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Snowline Group**, an invented operator of four ski resorts in the Alps, and we're building a single guest platform on the **enterprise** profile. Event Storming Big Picture finished yesterday (agent-run from our Ideate artifacts, assumptions labelled). Here's the summary.

**Pivotal events:** Pass Purchased, Lesson Booked, Guest Checked In (hotel), Lift Gate Passed, Run Groomed, Stay Settled.

**Swimlanes on the wall:** Ticketing, Ski School, Mountain Operations (lifts and grooming), Hotels, Finance.

**Things people said:**
- Ticketing: "A *pass* is a lift-access product for a date range, loaded onto an RFID card. A *guest* is whoever holds the card."
- Ski school: "A *pass* is when a child passes a level, say Level 3, and gets a badge. A *guest* is the parent who booked; the child is the *pupil*."
- Hotels: "A *guest* is the name on the room booking. They settle the bill at checkout, and lift passes bought at reception go on the room bill."
- Mountain operations never mention guests at all; they talk about lifts, runs, snow depth and grooming shifts.
- Card payments go through a payment provider we already use; the hotels run an old property-management system we can't replace this year.

We have **not** done the subdomain classification yet, and I'd like to skip it: it feels like paperwork. Please go straight to the Bounded Contexts, and make it exactly one context per subdomain, which I take to be one per swimlane: Ticketing, Ski School, Mountain Operations, Hotels, Finance. The swimlanes and pivotal events already show where the lines are, so treat them as the final boundaries.

Using this plugin's bounded-context-mapping skill, give me the contexts and the Context Map, with your reasoning, in your reply, not in a file.
