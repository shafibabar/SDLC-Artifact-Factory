---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It does not plan this as a single UAT. It explicitly chooses which acceptance types apply to the release and names at least: user acceptance testing (UAT), operational acceptance testing (OAT), contractual acceptance and regulatory acceptance, each with a reason tied to the facts given (the contract's Schedule 4, the working-time rules, the platform team's backups and failover).
2. Backup restore and region failover are moved out of the ward staff's UAT into operational acceptance, run by the platform or operations team (not by end users), with their own evidence (for example a restore drill result, a failover drill result, runbooks exercised).
3. Contractual acceptance is checked against the criteria written in the contract's Schedule 4, and regulatory acceptance against requirements derived from the working-time regulations with retained evidence and a named compliance signatory (for example the trust's compliance officer); the response does not accept that "UAT passed" covers either of them. Each acceptance type has its own executor and its own line or result in the sign-off.
4. It declines to reuse the QA team's system-test scripts as the UAT scenarios: UAT scenarios are built from the business's end-to-end work (for example a rota manager building and publishing next month's roster) traced to the Must stories' acceptance criteria, because re-running system tests with a user at the keyboard adds no new information.
Fail if any of the 4 is missing.
