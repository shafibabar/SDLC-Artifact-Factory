---
description: Tell the user exactly what to run next
allowed-tools: Read, Glob, Bash(${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py:*), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh:*)
---

Tell the user the single next action: one clear recommendation, not a menu.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If no product exists, recommend `/sdlc-start` and stop.
2. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh" "${CLAUDE_PLUGIN_ROOT}/scripts/memory/self_status.py" open-questions --only-open`. If an open question blocks the current phase, the next action is to answer it: name the question.
3. If `needs_reapproval` lists anything, the next action is to review and re-approve those changed artifacts (name them): no later phase can be approved until they are.
4. Otherwise, from `current_phase_check`:
   - if required artifacts are missing, recommend the current phase's command (`/sdlc-strategy` → `/sdlc-ideate` → `/sdlc-design` → `/sdlc-implement` → `/sdlc-data` → `/sdlc-quality` → `/sdlc-deploy` → `/sdlc-validate`) and say which artifacts it will produce;
   - if everything is written but some artifacts are unapproved, recommend reviewing and approving those (name them);
   - if the current phase only awaits the user's phase approval, say so;
   - if the previous phase is approved and nothing in the current one exists yet, recommend the current phase's command.
5. Do not invoke any agent and do not change anything. This command only reads and recommends.
