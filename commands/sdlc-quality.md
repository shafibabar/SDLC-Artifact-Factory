---
description: Run the Quality phase — e2e, performance, load, chaos, mutation testing, compliance verification
disable-model-invocation: true
---

Drive the Quality phase of the SDLC Artifact Factory. This is shift-right validation against the running system — it does not gate whether code was written test-first (that was already enforced in Implement); it proves the system holds up under real conditions.

Invoke every agent named below via the Agent tool with `subagent_type: "sdlc-artifact-factory:<agent-name>"`; each agent's definition is `${CLAUDE_PLUGIN_ROOT}/agents/<agent-name>.md` — never search the filesystem for it.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If no product exists, tell the user to run `/sdlc-start` first and stop. Confirm `phases.implement.status` is `approved`; if not, tell the user in plain language what the Implement phase still needs (the output lists it) and that `/sdlc-implement` finishes it, and stop.
2. Check which Quality-phase suites already exist. Do not rebuild approved work unless the user explicitly asks for a revision.
3. Invoke `test-strategist` for the shift-right suites: end-to-end journeys, performance baselines, load/SLO verification, chaos testing, and periodic mutation testing on critical packages.
4. Invoke `security-engineer` for the compliance test suite, vulnerability scanning, and the compliance verification report.
5. When both agents report completion, ask the user to approve the Quality phase and record it (see **Approvals** below), and tell the user the next step is `/sdlc-deploy`.

## Approvals

Agents stop at approval gates and hand back to you; relay each gate to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Quality phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete quality`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete quality --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
