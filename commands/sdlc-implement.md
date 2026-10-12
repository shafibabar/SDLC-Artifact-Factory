---
description: Run the Implement phase — test standards, backend, frontend, security controls, all test-first
disable-model-invocation: true
---

Drive the Implement phase of the SDLC Artifact Factory.

Invoke every agent named below via the Agent tool with `subagent_type: "sdlc-artifact-factory:<agent-name>"`; each agent's definition is `${CLAUDE_PLUGIN_ROOT}/agents/<agent-name>.md` — never search the filesystem for it.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If no product exists, tell the user to run `/sdlc-start` first and stop. Confirm `phases.design.status` is `approved`; if not, tell the user in plain language what the Design phase still needs (the output lists it) and that `/sdlc-design` finishes it, and stop.
2. Check which services and test standards already exist. Do not regenerate approved work unless the user explicitly asks for a revision.
3. **Invoke `test-strategist` first**, to establish the test strategy, the Test Pyramid targets, and the BDD feature files from the Ideate phase's Gherkin acceptance criteria. This must exist before test-first implementation can begin.
4. **Invoke `backend-engineer`, `frontend-engineer`, and `security-engineer`**, each given the relevant Design phase artifacts and the test standards from step 3. Every one of these agents writes the failing test before the implementation, without exception — this is enforced by the `tdd-gate` hook once built, and is non-negotiable regardless.
5. Confirm the shared OpenAPI contract has not drifted between backend-engineer and frontend-engineer (both generate from the same `enterprise-architect`-owned contract).
6. When all agents report completion, ask the user to approve the Implement phase and record it (see **Approvals** below), and tell the user the next step is `/sdlc-data`.

## What to produce

Before invoking any agent, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" plan implement`. It lists, for this product's scale profile, the artifacts that are **required** (with their canonical paths), the **optional** ones (produce one only when its note applies or the user asks), the ones **skipped** at this profile, and any **guidance** for the phase. Pass that list to every agent you invoke and tell it to produce exactly the required artifacts, the applicable optional ones, and nothing that is skipped. The five methodologies (DDD, Event Storming, TDD, BDD, SOLID) still apply in full; a smaller profile means fewer and shorter artifacts, never a skipped methodology.

## Approvals

Follow the plan's `approval_mode`, unless the user asks for another (they can switch at any time):
- **batch** (lean): let the agents produce the phase's artifacts together, then show the user one summary table and ask for a single review;
- **key-decisions** (standard): stop for approval only at artifacts that change direction (such as the vision, the Context Map, the Container Diagram), and batch the rest into one review;
- **per-artifact** (enterprise): stop for approval after every artifact.

Agents hand back to you at each approval point; relay it to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Implement phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete implement`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete implement --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
