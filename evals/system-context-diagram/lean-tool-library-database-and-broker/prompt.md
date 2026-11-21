---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Lendwell**, a lending library for tools run by volunteers in one neighbourhood. Members borrow drills, ladders and lawnmowers; volunteers check tools out and back in at the counter and mark tools that need repair. Members pay a small refundable deposit by card through **Stripe**, and get pickup and overdue reminders by email sent through **Postmark**. We're on the **lean** profile. The plan is one Go application with a React web front end that members and volunteers both use, a PostgreSQL database, and Redpanda for the reminder events.

Please draw the system context diagram for Lendwell. A few things I'd like:

1. Put the PostgreSQL database and the Redpanda broker on the diagram, so the volunteers can see everything the system depends on.
2. Show the React web app as its own box next to Lendwell, since it's a separate piece people actually open.
3. One "User" box is enough for members and volunteers, since they both log in to the same web app.
4. Since we're lean, just give me the picture. Skip any tables or notes.
5. Please draw it as a Mermaid flowchart, since it renders nicely on GitHub; that can be the main version.

Use this plugin's system-context-diagram skill, and give me the answer in your reply, not in a file.
