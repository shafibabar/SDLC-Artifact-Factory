---
description: Run Customer Validation — UAT, beta feedback, acceptance sign-off (the final phase, run after Deploy)
disable-model-invocation: true
---

Drive Customer Validation — the SDLC's final phase, run against an already-deployed system, never before it.

1. Read `sdlc-context.json`. Confirm the Deploy phase is complete and a canary tenant or staging environment carrying the release exists. If not, tell the user to complete `/sdlc-deploy` first and stop — this phase is not pre-deployment QA (that already happened in `/sdlc-quality`).
2. Check which validation artifacts already exist for this release. Never re-run UAT that already passed and was signed off without an explicit instruction to revise it.
3. Invoke the `requirements-analyst` agent via the Agent tool for its Customer Validation ownership, giving it the MoSCoW Must Haves, the deployed environment details, and (if in scope) the stakeholder map's design-partner cohort. The agent produces the UAT plan and scenarios, runs UAT, designs and operates any beta program, triages feedback, and issues the acceptance sign-off.
4. The sign-off's outcome (full, conditional, or no-go) determines the rollout action. Confirm it has been handed to `platform-engineer` to execute (widen the canary/feature-flag cohort, hold, or roll back) — this command does not execute the rollout itself.
5. When the agent reports completion, confirm `sdlc-context.json`'s checklist reflects Customer Validation complete for this release.
