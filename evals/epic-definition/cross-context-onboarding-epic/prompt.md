---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

We're on the **enterprise** profile for **Roomgrid**, a multi-tenant property-management SaaS for hotel groups (each hotel group is a tenant). I've drafted this epic for the epic list:

"EPIC-7: Onboard a new hotel group — create the tenant, set up single sign-on for their staff, start their subscription billing, provision their data plane in their chosen region, and import their existing reservations from the old system."

To keep things clean I want to split it into four epics, one per service: an Identity Service epic, a Billing Service epic, a Data Plane Provisioning epic and an Import Service epic, so each team owns one. The impact map, functional requirements and NFR specification are approved; you don't need them for this. Please confirm that split, write the replacement epic(s) in your reply (titles, outcome, story titles, size, Bounded Context and anything that needs flagging is enough), and tell me how many sprints each will take. Use this plugin's epic-definition skill.
