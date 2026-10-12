---
description: Run the Ideate phase — requirements, personas, backlog, acceptance criteria
disable-model-invocation: true
---

Drive the Ideate phase of the SDLC Artifact Factory.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If no product exists, tell the user to run `/sdlc-start` first and stop. Confirm `phases.strategy.status` is `approved`; if not, tell the user in plain language what the Strategy phase still needs (the output lists it) and that `/sdlc-strategy` finishes it, and stop.
2. Check which Ideate artifacts already exist. Do not re-produce artifacts already approved unless the user explicitly asks for a revision.
3. Invoke the `requirements-analyst` agent via the Agent tool (`subagent_type: "sdlc-artifact-factory:requirements-analyst"`; its definition is `${CLAUDE_PLUGIN_ROOT}/agents/requirements-analyst.md` — never search the filesystem for it), giving it the Strategy phase artifacts. The agent owns the full artifact set (functional requirements, NFR specification, personas, JTBD analysis, impact map, epics, user story backlog, acceptance criteria, example maps, story map, MoSCoW prioritisation) and follows its own strict execution sequence and approval gates — do not skip them.
4. When the agent reports the Ideate phase complete, confirm its two handoffs are explicit (NFR architecture handoff to enterprise-architect; BDD handoff to test-strategist), ask the user to approve the Ideate phase and record it (see **Approvals** below), and tell the user the next step is `/sdlc-design`.

## Approvals

Agents stop at approval gates and hand back to you; relay each gate to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Ideate phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete ideate`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete ideate --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
