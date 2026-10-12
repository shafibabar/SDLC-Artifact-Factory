---
description: Run Customer Validation — UAT, beta feedback, acceptance sign-off (the final phase, run after Deploy)
disable-model-invocation: true
---

Drive Customer Validation — the SDLC's final phase, run against an already-deployed system, never before it.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If no product exists, tell the user to run `/sdlc-start` first and stop. Confirm `phases.deploy.status` is `approved`; if not, tell the user in plain language what the Deploy phase still needs (the output lists it) and that `/sdlc-deploy` finishes it, and stop. A canary tenant or staging environment carrying the release must also exist — this phase is not pre-deployment QA.
2. Check which validation artifacts already exist for this release. Never re-run UAT that already passed and was signed off without an explicit instruction to revise it.
3. Invoke the `requirements-analyst` agent via the Agent tool (`subagent_type: "sdlc-artifact-factory:requirements-analyst"`; its definition is `${CLAUDE_PLUGIN_ROOT}/agents/requirements-analyst.md` — never search the filesystem for it) for its Customer Validation ownership, giving it the MoSCoW Must Haves, the deployed environment details, and (if in scope) the stakeholder map's design-partner cohort. The agent produces the UAT plan and scenarios, runs UAT, designs and operates any beta program, triages feedback, and issues the acceptance sign-off.
4. The sign-off's outcome (full, conditional, or no-go) determines the rollout action. Confirm it has been handed to `platform-engineer` to execute (widen the canary/feature-flag cohort, hold, or roll back) — this command does not execute the rollout itself.
5. When the agent reports completion, ask the user to approve the Customer Validation phase and record it (see **Approvals** below).

## Approvals

Agents stop at approval gates and hand back to you; relay each gate to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Customer Validation phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete customer-validation`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete customer-validation --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
