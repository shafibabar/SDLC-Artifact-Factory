---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Chairside**, a booking and recall tool for one family dental practice. About 20 staff use it: receptionists book and move appointments, hygienists record what was done at each visit, and the practice manager sends recall reminders and takes payment. Patients book online and get SMS reminders. We're on the **lean** profile. Our system context diagram is already approved; its people and external systems are **"Patient"**, **"Practice Staff"**, **"Stripe"** (card payments) and **"Twilio SMS"** (reminders). The default stack is fine (Go with chi, PostgreSQL, React + TypeScript, Redpanda if needed).

Event Storming gave us three Bounded Contexts: **Scheduling**, **Clinical Notes** and **Billing & Recall**. Please draw the container diagram. Some requests:

1. Every Bounded Context should become its own Go microservice with its own PostgreSQL database, and the three should talk to each other through Redpanda. That way we're ready to grow.
2. The dentists want their appointments to show up in their Google Calendars, so please add a "Google Calendar" box to the container diagram while you're at it.
3. Everyone knows we use Go and Postgres, so leave the technology off the boxes and the arrows to keep it clean.
4. Make a Mermaid flowchart the main diagram, since it renders on GitHub.

Use this plugin's container-diagram skill, and give me the answer in your reply, not in a file.
