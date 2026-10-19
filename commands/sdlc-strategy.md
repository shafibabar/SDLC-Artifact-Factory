---
description: Run the Strategy phase — vision, mission, GTM, OKRs, roadmap
disable-model-invocation: true
---

Drive the Strategy phase of the SDLC Artifact Factory.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If no product exists, tell the user to run `/sdlc-start` first and stop.
2. Check which strategy artifacts already exist under the product's artifact directory. Do not re-produce artifacts already approved unless the user explicitly asks for a revision.
3. Invoke the `product-strategist` agent via the Agent tool (`subagent_type: "sdlc-artifact-factory:product-strategist"`; its definition is `${CLAUDE_PLUGIN_ROOT}/agents/product-strategist.md` — never search the filesystem for it). Give it the problem statement (from the status output), the target market, and any prior decisions from project memory. The agent owns the full artifact set (vision, mission, stakeholder map, competitive analysis, business model canvas, GTM strategy, OKRs, roadmap) and will present each for approval per its own execution sequence — do not skip its approval gates.
4. When the agent reports the Strategy phase complete, ask the user to approve the Strategy phase and record it (see **Approvals** below), and tell the user the next step is `/sdlc-ideate`.

## What to produce

Before invoking any agent, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" plan strategy`. It lists, for this product's scale profile, the artifacts that are **required** (with their canonical paths), the **optional** ones (produce one only when its note applies or the user asks), the ones **skipped** at this profile, and any **guidance** for the phase. Pass that list to every agent you invoke and tell it to produce exactly the required artifacts, the applicable optional ones, and nothing that is skipped. The five methodologies (DDD, Event Storming, TDD, BDD, SOLID) still apply in full; a smaller profile means fewer and shorter artifacts, never a skipped methodology.

## Approvals

Follow the plan's `approval_mode`, unless the user asks for another (they can switch at any time):
- **batch** (lean): let the agents produce the phase's artifacts together, then show the user one summary table and ask for a single review;
- **key-decisions** (standard): stop for approval only at artifacts that change direction (such as the vision, the Context Map, the Container Diagram), and batch the rest into one review;
- **per-artifact** (enterprise): stop for approval after every artifact.

Agents hand back to you at each approval point; relay it to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Strategy phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete strategy`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete strategy --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
