---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

We're in the Strategy phase of the SDLC Artifact Factory (standard profile) for **Shiftbay**, a scheduling product for veterinary clinics. I'm the product owner; the plugin's AI agents draft the artifacts and write the code. Here is part of our draft stakeholder map:

| Stakeholder | Power (1–3) | Interest (1–3) | Quadrant |
|---|---|---|---|
| The product owner | 3 | 3 | Manage Closely |
| Practice-management vendor's API review team (approves our integration and any new data scopes) | 3 | 1 | Monitor |
| Design-partner clinic managers (4 clinics) | 2 | 3 | Keep Informed |

| Decision | Responsible | Accountable | Consulted | Informed |
|---|---|---|---|---|
| Release gate | test-strategist agent | The product owner, test-strategist agent | Clinic data-protection lead | Design partners |
| Data scopes requested from the vendor API | backend-engineer agent | backend-engineer agent | API review team | Design partners |

Note: the clinic data-protection lead and the API review team can each refuse to let a release go live.

Using this plugin's stakeholder-mapping guidance, review these two tables and rewrite them.
