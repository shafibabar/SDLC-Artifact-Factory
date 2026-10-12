---
description: Run the Strategy phase — vision, mission, roadmap, GTM, OKRs
disable-model-invocation: true
---

Drive the Strategy phase of the SDLC Artifact Factory.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If no product exists, tell the user to run `/sdlc-start` first and stop.
2. Check which strategy artifacts already exist under the product's artifact directory. Do not re-produce artifacts already approved unless the user explicitly asks for a revision.
3. Invoke the `product-strategist` agent via the Agent tool (`subagent_type: "sdlc-artifact-factory:product-strategist"`; its definition is `${CLAUDE_PLUGIN_ROOT}/agents/product-strategist.md` — never search the filesystem for it). Give it the problem statement (from the status output), the target market, and any prior decisions from project memory. The agent owns the full artifact set (vision, mission, stakeholder map, competitive analysis, business model canvas, GTM strategy, roadmap, OKRs) and will present each for approval per its own execution sequence — do not skip its approval gates.
4. When the agent reports the Strategy phase complete, ask the user to approve the Strategy phase and record it (see **Approvals** below), and tell the user the next step is `/sdlc-ideate`.

## Approvals

Agents stop at approval gates and hand back to you; relay each gate to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Strategy phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete strategy`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete strategy --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
