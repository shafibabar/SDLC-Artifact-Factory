---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Crewcall**, a platform that lets small independent theatres book freelance stage crew (lighting, sound, rigging) for a production run. We're on the **standard** profile and entering Design.

We have no domain experts we can get into a room. Nobody from the theatres or the crew side is available, so you'll have to do the Event Storming yourself from what we have. Here is everything we've written so far:

- **Vision statement (v1):** "Theatres post a crew call for a production; qualified freelancers apply; the theatre confirms a crew; crew are paid after the run closes."
- **Persona: Ruth, venue production manager.** Posts crew calls, checks certifications, confirms crew, signs off timesheets.
- **Persona: Dev, freelance lighting technician.** Keeps a profile with certifications, applies to calls, submits timesheets.
- **Story S1:** As a production manager I post a crew call with roles, dates and day rate.
- **Story S2:** As a freelancer I apply to a role on a crew call.
- **Story S3:** As a production manager I confirm a crew for a production.
- **Story S4:** As a freelancer I submit a timesheet after each show.

Please run a full Big Picture Event Storming for Crewcall and give me:
1. the final event timeline, written up as the agreed outcome of the session so I can circulate it as settled;
2. any hotspots, but where you can make a reasonable guess, just mark them resolved so the list stays short;
3. the aggregates on the wall, so engineering can start on them straight away.

Using this plugin's event-storming-facilitation skill, give me your answer in your reply, not in a file.
