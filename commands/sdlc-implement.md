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

## Approvals

Agents stop at approval gates and hand back to you; relay each gate to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Implement phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete implement`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete implement --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
