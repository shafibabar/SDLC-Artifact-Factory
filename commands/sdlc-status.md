---
description: Report current position in the factory build or in a product's SDLC journey
allowed-tools: Read, Glob, Bash(${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh:*)
---

Read `sdlc-context.json` for the still-static sections (`first_product`, `tech_stack`). For the fast-growing sections (build checklist, decisions, open questions), query the SDLC memory engine instead of reading a file in full — see `skills/memory-recall`. Report status in plain language — no jargon, this is read by a PM.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh" "${CLAUDE_PLUGIN_ROOT}/scripts/memory/self_status.py" build-checklist`. **If `all_complete` is false**: report factory build status using `last_completed`, `first_incomplete` (title + status line), and `remaining`. This is the plugin's own construction — read `CLAUDE.md`'s Session Startup rule for what this means.
2. **If `all_complete` is true**: state that the factory is fully built. Then check whether a product has been started (`first_product.status` in `sdlc-context.json`). If no product has started, tell the user to run `/sdlc-start`. If a product is in progress, report what phase-position tracking exists for it today — note plainly if no dedicated per-product phase field exists yet (this is a known gap; a future chunk should add one rather than this command inventing an undocumented convention).
3. Run `self_status.py open-questions --only-open` and `self_status.py decisions --limit 3`; always report any open questions and the 3 most recent decisions for context.
4. Do not invoke any agent. This command only reads and reports.
