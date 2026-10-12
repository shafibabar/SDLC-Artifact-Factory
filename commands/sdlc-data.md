---
description: Run the Data phase — pipeline implementation, data quality, product analytics
disable-model-invocation: true
---

Drive the Data phase of the SDLC Artifact Factory.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If no product exists, tell the user to run `/sdlc-start` first and stop. Confirm `phases.implement.status` is `approved`; if not, tell the user in plain language what the Implement phase still needs (the output lists it) and that `/sdlc-implement` finishes it, and stop.
2. Check which pipeline stages and analytics artifacts already exist. Do not rebuild approved work unless the user explicitly asks for a revision.
3. Invoke the `data-engineer` agent via the Agent tool (`subagent_type: "sdlc-artifact-factory:data-engineer"`; its definition is `${CLAUDE_PLUGIN_ROOT}/agents/data-engineer.md` — never search the filesystem for it), giving it the data-architect's pipeline blueprint, lineage design, event schemas, and classification rules, plus the product's OKRs and North Star Metric. The agent implements the pipeline stage workers (test-first, idempotent, DLQ-wired) and produces the data quality rules, metrics instrumentation plan, and dashboard/report content specs.
4. Confirm the dashboard/report content specs have been handed to `ux-architect` for UI specification — data-engineer defines content, it does not design layout.
5. When the agent reports completion, ask the user to approve the Data phase and record it (see **Approvals** below), and tell the user the next step is `/sdlc-quality`.

## Approvals

Agents stop at approval gates and hand back to you; relay each gate to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Data phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete data`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete data --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
