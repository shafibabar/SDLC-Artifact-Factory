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

## What to produce

Before invoking any agent, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" plan deploy`. It lists, for this product's scale profile, the artifacts that are **required** (with their canonical paths), the **optional** ones (produce one only when its note applies or the user asks), the ones **skipped** at this profile, and any **guidance** for the phase. Pass that list to every agent you invoke and tell it to produce exactly the required artifacts, the applicable optional ones, and nothing that is skipped. The five methodologies (DDD, Event Storming, TDD, BDD, SOLID) still apply in full; a smaller profile means fewer and shorter artifacts, never a skipped methodology.

## Approvals

Follow the plan's `approval_mode`, unless the user asks for another (they can switch at any time):
- **batch** (lean): let the agents produce the phase's artifacts together, then show the user one summary table and ask for a single review;
- **key-decisions** (standard): stop for approval only at artifacts that change direction (such as the vision, the Context Map, the Container Diagram), and batch the rest into one review;
- **per-artifact** (enterprise): stop for approval after every artifact.

Agents hand back to you at each approval point; relay it to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Deploy phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete deploy`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete deploy --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
