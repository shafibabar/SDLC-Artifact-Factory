---
description: Report where the product stands in its SDLC journey
allowed-tools: Read, Glob, Bash(${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py:*), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh:*)
---

Report the product's status in plain language: no jargon, this is read by a PM.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If no product exists, say so and tell the user to run `/sdlc-start`, then stop.
2. Report the product name, its scale profile (lean, standard or enterprise), its current phase, and which phases are approved (and when; mention any phase approved by override and its reason).
3. From `current_phase_check`, report what the current phase still needs: required artifacts not yet written, and artifacts written but not yet approved. Use artifact names a PM recognises, not file paths.
4. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh" "${CLAUDE_PLUGIN_ROOT}/scripts/memory/self_status.py" open-questions --only-open` and `"${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh" "${CLAUDE_PLUGIN_ROOT}/scripts/memory/self_status.py" decisions --limit 3`. Always report any open questions (they need the user's answer) and the 3 most recent decisions for context.
5. Do not invoke any agent and do not change anything. This command only reads and reports.
