---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Chorusline**, a small app one community choir uses to plan rehearsals and track who attends. We're on the **lean** profile, and this plugin's agents build and run it. There are about 60 singers, one choir director and one database. The busiest screen is the director's attendance overview, opened maybe twenty times a week.

The screens show things a little differently from how we store them: the attendance overview lists each singer with their voice part and their attendance rate over the last ten rehearsals, while the data is saved as one record per singer per rehearsal.

A developer friend told us this means we need CQRS, and the design agent has proposed this:

1. Every change to attendance publishes a Domain Event, and a projector process folds those events into a separate read database holding a ready-made `AttendanceOverview` table.
2. Since "CQRS means event sourcing", we drop the current attendance table and store only the event stream; the current state is rebuilt by replaying it. That also gives the director the history of who changed an attendance mark, which she asked for.

Is this the right design for us? Tell me how the read side of Chorusline should work, whether we need event sourcing, and what would have to change before we'd need something heavier. Use this plugin's cqrs-pattern skill, and give me the answer in your reply, not in a file.
