---
description: Run the Deploy phase — CI/CD, infrastructure, observability stack, progressive delivery
disable-model-invocation: true
---

Drive the Deploy phase of the SDLC Artifact Factory.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If no product exists, tell the user to run `/sdlc-start` first and stop. Confirm `phases.quality.status` is `approved`; if not, tell the user in plain language what the Quality phase still needs (the output lists it) and that `/sdlc-quality` finishes it, and stop. Deploy never proceeds on a service that hasn't cleared Quality.
2. Check which platform artifacts already exist. Do not rebuild approved infrastructure unless the user explicitly asks for a revision.
3. Invoke the `platform-engineer` agent via the Agent tool (`subagent_type: "sdlc-artifact-factory:platform-engineer"`; its definition is `${CLAUDE_PLUGIN_ROOT}/agents/platform-engineer.md` — never search the filesystem for it), giving it the built images, the Container Diagram and Multi-Tenancy Design, the test suite split, SLO targets, and the security/data-retention contracts it needs to operate. The agent builds the CI/CD pipeline, infrastructure, Kubernetes delivery, observability stack, SLOs/alerting, and disaster recovery — following its own GitOps, one-path-to-production discipline.
4. Confirm a rollback has been demonstrated and a DR restore has been executed with measured RTO/RPO before considering this phase closed.
5. When the agent reports completion, ask the user to approve the Deploy phase and record it (see **Approvals** below), and tell the user the next step is `/sdlc-validate` — run against the deployed canary/staging environment, not before it.

## Approvals

Agents stop at approval gates and hand back to you; relay each gate to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Deploy phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete deploy`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete deploy --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
