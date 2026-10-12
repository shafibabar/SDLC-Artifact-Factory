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

## What to produce

Before invoking any agent, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" plan customer-validation`. It lists, for this product's scale profile, the artifacts that are **required** (with their canonical paths), the **optional** ones (produce one only when its note applies or the user asks), the ones **skipped** at this profile, and any **guidance** for the phase. Pass that list to every agent you invoke and tell it to produce exactly the required artifacts, the applicable optional ones, and nothing that is skipped. The five methodologies (DDD, Event Storming, TDD, BDD, SOLID) still apply in full; a smaller profile means fewer and shorter artifacts, never a skipped methodology.

## Approvals

Follow the plan's `approval_mode`, unless the user asks for another (they can switch at any time):
- **batch** (lean): let the agents produce the phase's artifacts together, then show the user one summary table and ask for a single review;
- **key-decisions** (standard): stop for approval only at artifacts that change direction (such as the vision, the Context Map, the Container Diagram), and batch the rest into one review;
- **per-artifact** (enterprise): stop for approval after every artifact.

Agents hand back to you at each approval point; relay it to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Customer Validation phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete customer-validation`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete customer-validation --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
