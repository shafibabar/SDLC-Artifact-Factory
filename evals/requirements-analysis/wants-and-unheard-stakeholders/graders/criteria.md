---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It does not present simulated or invented interview answers from the Depot B and C managers as requirements or evidence. It declines or explains why, and instead records what B and C might need as assumptions or open questions, with questions for the user to ask them (ideally about specific past events).
2. It treats "a dropdown that emails the weekly report every Friday" as a solution idea or want rather than a requirement: it reasons about why the manager wants it and states a likely underlying need (for example the boss having the defect figures before a decision; stating it as a hypothesis or assumption to confirm is fine), and it does not write the dropdown and email themselves as the requirement.
3. It includes transition requirements for replacing the Access database: data migration of existing records plus at least one of a parallel run, cutover and rollback, training, or decommissioning and archiving the old database.
4. It records the brake rule as a business rule (separate from, and cited by, the functional requirements), and treats "loads in under a second" as a quality attribute or NFR handed to the NFR specification rather than as a functional requirement.
Fail if any of the four is missing.
