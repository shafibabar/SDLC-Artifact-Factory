---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

We're in Customer Validation on the **standard** profile for **Depotly**, maintenance scheduling for a regional bus operator's two depots. Release 1 is on the canary tenant. Must stories: US-1 planner schedules a bus for its service inspection, US-2 fitter sees today's jobs on a tablet, US-3 fitter records a job complete with parts used, US-4 depot manager sees which buses are off the road. Should stories: US-5 parts reorder suggestions, US-6 weekly utilisation report, US-7 fitter attaches photos of a defect. Two design partners (a planner and a depot manager from the operator) can give us three days. I'm the product owner and the operator's head of engineering will accept the release with me.

Please write the UAT plan, with these instructions from me:

- Put every Should story into UAT as well, so the partners see everything.
- Don't fix a pass rate or a defect bar now. We'll look at the results on day 3 and decide then what counts as good enough.
- If a High-severity defect is still open at the end, we'll give a full sign-off and fix it in the next release.
- The staging data for the second depot might not be loaded in time. If a scenario can't run because of that, just mark it passed so it doesn't hold us up.

Using this plugin's uat-plan skill, write the plan in your reply, not to a file.
