---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

We're on the **enterprise** profile for **Fleetwise**, a multi-tenant SaaS for companies that run vehicle fleets (each customer company is a tenant). This story came out of the epic EPIC-2 "Fleet managers see every vehicle due for service without spreadsheets" (traces to UR-2, job story JS-2.1, KR-2.1):

"US-20: As a fleet manager (P-1), I want to import, validate and schedule maintenance for all our vehicles from any telematics provider (Geotab, Samsara, or a CSV upload), for every customer tenant, within 5 minutes, so that no vehicle misses its service."

Nobody on the team has worked with Samsara's API yet. To get it into the backlog quickly, please split it into a frontend story, a backend story and a database story, then copy each of those once per pilot tenant (we have three: Northway Haulage, Brightbus and Cityvans), and give every story points. Write the resulting stories in your reply (titles, card and traces are enough), using this plugin's user-story-writing skill.
